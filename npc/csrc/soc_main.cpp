// Verilator harness for the ysyxSoC simulation flavor (sim top: ysyxSoCTop).
//
// P9-S3 debug/commit exposure build: the SoC is patched to expose the NPC
// core's debug/commit signals and reset PC at the SoC top. This harness uses
// those signals for precise ebreak termination, event DiffTest, and prints the
// same structured NPC_RESULT line as the standalone NPC harness.

#include "VysyxSoCTop.h"

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>

#include "verilated.h"

#if VM_TRACE
#include "verilated_vcd_c.h"
#endif

#include "difftest.h"
#include <debug/commit_event.h>
#include <debug/mmio_replay.h>

namespace {

constexpr uint32_t MROM_BASE = 0x20000000u;
constexpr uint32_t MROM_SIZE = 0x1000u;  // 4KB AXI4MROM window
constexpr uint32_t DEFAULT_RESET_PC = 0x20000000u;
constexpr uint32_t EBREAK_INST = 0x00100073u;
constexpr uint32_t UART_BASE = 0x10000000u;
constexpr uint32_t CLINT_BASE = 0x02000000u;
constexpr uint32_t CLINT_END = 0x02010000u;

uint8_t g_mrom[MROM_SIZE];
uint64_t g_mrom_reads = 0;
uint64_t g_sim_time = 0;
#if VM_TRACE
VerilatedVcdC *g_tfp = nullptr;
#endif

struct Args {
  std::string image;
  std::string difftest_ref;
  uint32_t reset_pc = DEFAULT_RESET_PC;
  uint64_t max_cycles = 2000;
  bool wave = false;
};

bool parse_u64(const char *s, uint64_t *value) {
  char *end = nullptr;
  unsigned long long v = std::strtoull(s, &end, 0);
  if (end == s || *end != '\0') {
    return false;
  }
  *value = static_cast<uint64_t>(v);
  return true;
}

bool parse_u32(const char *s, uint32_t *value) {
  uint64_t tmp = 0;
  if (!parse_u64(s, &tmp)) return false;
  *value = static_cast<uint32_t>(tmp);
  return true;
}

void usage(const char *prog) {
  std::printf("Usage: %s [--image FILE] [--reset-pc HEX] [--max-cycles N] [--difftest-ref SO] [--wave]\n", prog);
}

bool parse_args(int argc, char **argv, Args *args) {
  for (int i = 1; i < argc; i++) {
    if (std::strcmp(argv[i], "--image") == 0 && i + 1 < argc) {
      args->image = argv[++i];
    } else if (std::strcmp(argv[i], "--difftest-ref") == 0 && i + 1 < argc) {
      args->difftest_ref = argv[++i];
    } else if (std::strcmp(argv[i], "--reset-pc") == 0 && i + 1 < argc) {
      if (!parse_u32(argv[++i], &args->reset_pc)) {
        std::fprintf(stderr, "invalid --reset-pc\n");
        return false;
      }
    } else if (std::strcmp(argv[i], "--max-cycles") == 0 && i + 1 < argc) {
      if (!parse_u64(argv[++i], &args->max_cycles)) {
        std::fprintf(stderr, "invalid --max-cycles\n");
        return false;
      }
    } else if (std::strcmp(argv[i], "--wave") == 0) {
      args->wave = true;
    } else if (std::strcmp(argv[i], "--help") == 0) {
      usage(argv[0]);
      std::exit(0);
    } else {
      std::fprintf(stderr, "unknown argument: %s\n", argv[i]);
      usage(argv[0]);
      return false;
    }
  }
  return true;
}

long load_image_to_mrom(const std::string &path) {
  if (path.empty()) {
    return 0;
  }
  FILE *fp = std::fopen(path.c_str(), "rb");
  if (fp == nullptr) {
    std::perror(path.c_str());
    return -1;
  }
  std::fseek(fp, 0, SEEK_END);
  long image_size = std::ftell(fp);
  std::fseek(fp, 0, SEEK_SET);
  if (image_size < 0 || static_cast<uint64_t>(image_size) > MROM_SIZE) {
    std::fprintf(stderr, "image out of bounds: size=%ld mrom=[0x%08x,+%u)\n",
                 image_size, MROM_BASE, MROM_SIZE);
    std::fclose(fp);
    return -1;
  }
  size_t nread = std::fread(g_mrom, 1, static_cast<size_t>(image_size), fp);
  std::fclose(fp);
  if (nread != static_cast<size_t>(image_size)) {
    std::fprintf(stderr, "short read: expected %ld bytes, got %zu bytes\n", image_size, nread);
    return -1;
  }
  std::printf("NPC_SOC_IMAGE path=%s base=0x%08x size=%ld\n", path.c_str(), MROM_BASE, image_size);
  return image_size;
}

void eval_cycle(VysyxSoCTop &top) {
  top.clock = 0;
  top.eval();
#if VM_TRACE
  if (g_tfp) g_tfp->dump(g_sim_time);
#endif
  g_sim_time++;
  top.clock = 1;
  top.eval();
#if VM_TRACE
  if (g_tfp) g_tfp->dump(g_sim_time);
#endif
  g_sim_time++;
}

uint32_t debug_reg(const VysyxSoCTop &top, int idx) {
  return top.io_debug_regs_flat[idx];
}

bool is_clint_addr(uint32_t addr) {
  return addr >= CLINT_BASE && addr < CLINT_END;
}

bool is_mmio_addr(uint32_t addr) {
  return addr == UART_BASE || is_clint_addr(addr);
}

uint8_t low_contiguous_len(uint8_t wmask) {
  uint8_t len = 0;
  for (int i = 0; i < 4 && ((wmask >> i) & 1u); i++) {
    len++;
  }
  return len == 0 ? 4 : len;
}

uint8_t load_len_from_inst(uint32_t inst) {
  uint32_t funct3 = (inst >> 12) & 0x7u;
  return (funct3 == 0u || funct3 == 4u) ? 1 :
         (funct3 == 1u || funct3 == 5u) ? 2 : 4;
}

CommitEvent make_event(const VysyxSoCTop &top, uint64_t retire, uint64_t cycle) {
  CommitEvent ev{};
  ev.retire = retire;
  ev.cycle = cycle;
  ev.pc = top.io_debug_commit_pc;
  ev.inst = top.io_debug_commit_inst;
  ev.next_pc = top.io_debug_commit_next_pc;
  ev.has_wb = top.io_debug_commit_wen;
  ev.rd = top.io_debug_commit_rd;
  ev.rd_value = top.io_debug_commit_wdata;
  ev.exception = top.io_debug_commit_exception;
  ev.cause = top.io_debug_commit_cause;
  return ev;
}

MMIOReplayRecord make_mmio_record(const VysyxSoCTop &top) {
  bool wen = top.io_debug_commit_mem_wen;
  bool ren = top.io_debug_commit_mem_ren;
  uint32_t addr = top.io_debug_commit_mem_addr;
  uint32_t wdata = top.io_debug_commit_mem_wdata;
  uint8_t wmask = static_cast<uint8_t>(top.io_debug_commit_mem_wmask & 0xfu);
  uint32_t rdata = top.io_debug_commit_mem_rdata;
  uint32_t inst = top.io_debug_commit_inst;

  if (wen && is_mmio_addr(addr)) {
    return {true, true, addr, low_contiguous_len(wmask), wmask, wdata, 0};
  }
  if (ren && is_clint_addr(addr)) {
    return {true, false, addr, load_len_from_inst(inst), 0, 0, rdata};
  }
  return {};
}

}  // namespace

extern "C" void mrom_read(int raddr, int *rdata) {
  // AXI4MROM passes the full address with the top 2 bits stripped; the MROM
  // window is 4KB so the offset is simply the low 12 bits either way.
  uint32_t off = static_cast<uint32_t>(raddr) & (MROM_SIZE - 1u);
  g_mrom_reads++;
  *rdata = static_cast<int>(static_cast<uint32_t>(g_mrom[off]) |
                            (static_cast<uint32_t>(g_mrom[off + 1]) << 8) |
                            (static_cast<uint32_t>(g_mrom[off + 2]) << 16) |
                            (static_cast<uint32_t>(g_mrom[off + 3]) << 24));
}

extern "C" void flash_read(int addr, int *data) {
  (void)data;
  std::fprintf(stderr, "flash_read called unexpectedly: addr=0x%08x (flash XIP is out of scope)\n",
               static_cast<uint32_t>(addr));
  assert(0);
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  Args args;
  if (!parse_args(argc, argv, &args)) {
    return 2;
  }

  long image_size = load_image_to_mrom(args.image);
  if (image_size < 0) {
    std::printf("NPC_RESULT status=bad reason=image_load_failed cycles=0 limit=%llu\n",
                static_cast<unsigned long long>(args.max_cycles));
    return 1;
  }

  VysyxSoCTop top;

#if VM_TRACE
  std::unique_ptr<VerilatedVcdC> tfp;
  if (args.wave) {
    Verilated::traceEverOn(true);
    tfp = std::make_unique<VerilatedVcdC>();
    top.trace(tfp.get(), 99);
    tfp->open("build/soc/wave.vcd");
    g_tfp = tfp.get();
  }
#endif

  // ysyxSoC delays the CPU reset through a 10-stage SynchronizerShiftReg
  // (src/SoC.scala:62), so reset must be held for at least 10 cycles or a
  // spurious reset pulse re-appears mid-run.
  top.reset = 1;
  top.io_reset_pc = args.reset_pc;
  for (int i = 0; i < 20; i++) {
    eval_cycle(top);
  }
  top.reset = 0;
  top.eval();

  Difftest difftest;
  bool difftest_enabled = false;
  if (!args.difftest_ref.empty()) {
    uint32_t regs[16];
    for (int i = 0; i < 16; i++) {
      regs[i] = debug_reg(top, i);
    }
    if (!difftest.init(args.difftest_ref, args.reset_pc, g_mrom, static_cast<size_t>(image_size),
                       regs, top.io_debug_pc, top.io_debug_mstatus, top.io_debug_mtvec,
                       top.io_debug_mepc, top.io_debug_mcause)) {
      std::printf("NPC_RESULT status=bad reason=difftest_init_failed cycles=0 pc=0x%08x\n",
                  top.io_debug_pc);
      return 1;
    }
    difftest_enabled = true;
  }

  uint64_t cycles = 0;
  uint64_t insts = 0;
  const char *status = "limit";
  const char *reason = "cycle_limit";
  while (cycles < args.max_cycles) {
    if (Verilated::gotFinish()) {
      status = "bad";
      reason = "host_finish";
      break;
    }

    eval_cycle(top);
    cycles++;

    if (top.io_debug_commit_valid) {
      insts++;
      CommitEvent ev = make_event(top, insts, cycles);
      MMIOReplayRecord mmio = make_mmio_record(top);

      if (difftest_enabled) {
        uint32_t regs[16];
        for (int i = 0; i < 16; i++) {
          regs[i] = debug_reg(top, i);
        }
        bool both_ebreak = false;
        if (!difftest.step(ev, mmio, regs, top.io_debug_pc, top.io_debug_mstatus,
                           top.io_debug_mtvec, top.io_debug_mepc, top.io_debug_mcause,
                           &both_ebreak)) {
          difftest.dump_last_ref(8);
          status = "bad";
          reason = "difftest_mismatch";
          break;
        }
        if (both_ebreak) {
          status = (top.io_debug_a0 == 0) ? "good" : "bad";
          reason = (top.io_debug_a0 == 0) ? "good_trap" : "bad_trap";
          break;
        }
      }

      if (!difftest_enabled && top.io_debug_commit_inst == EBREAK_INST) {
        status = (top.io_debug_a0 == 0) ? "good" : "bad";
        reason = (top.io_debug_a0 == 0) ? "good_trap" : "bad_trap";
        break;
      }

      if (top.io_debug_commit_exception && top.io_debug_halted) {
        status = "bad";
        reason = "illegal_inst";
        break;
      }
    }

    if (top.io_debug_halted) {
      // Halt without a recognized ebreak (e.g. illegal instruction with mtvec=0).
      status = "bad";
      reason = "illegal_inst";
      break;
    }
  }

  uint64_t accesses = top.io_debug_icache_accesses;
  uint64_t hits = top.io_debug_icache_hits;
  uint64_t misses = top.io_debug_icache_misses;
  uint64_t miss_wait = top.io_debug_icache_miss_wait_cycles;
  uint64_t refill_beats = top.io_debug_icache_refill_beats;
  uint64_t hit_rate_x1000 = accesses == 0 ? 0 : (hits * 1000) / accesses;
  uint64_t amat_x1000 = accesses == 0 ? 0 : ((accesses + miss_wait) * 1000) / accesses;

  std::printf("NPC_RESULT status=%s reason=%s cycles=%llu insts=%llu pc=0x%08x halted=%u limit=%llu x1=0x%08x a0=0x%08x trap=%u\n",
              status, reason,
              static_cast<unsigned long long>(cycles),
              static_cast<unsigned long long>(insts),
              top.io_debug_pc,
              top.io_debug_halted,
              static_cast<unsigned long long>(args.max_cycles),
              top.io_debug_x1,
              top.io_debug_a0,
              top.io_debug_trap_status);
  std::printf("NPC_CSR mstatus=0x%08x mtvec=0x%08x mepc=0x%08x mcause=0x%08x\n",
              top.io_debug_mstatus, top.io_debug_mtvec, top.io_debug_mepc, top.io_debug_mcause);
  std::printf("NPC_ICACHE accesses=%llu hits=%llu misses=%llu miss_wait_cycles=%llu refill_beats=%llu hit_rate_x1000=%llu amat_x1000=%llu\n",
              static_cast<unsigned long long>(accesses),
              static_cast<unsigned long long>(hits),
              static_cast<unsigned long long>(misses),
              static_cast<unsigned long long>(miss_wait),
              static_cast<unsigned long long>(refill_beats),
              static_cast<unsigned long long>(hit_rate_x1000),
              static_cast<unsigned long long>(amat_x1000));

#if VM_TRACE
  if (tfp) {
    tfp->close();
  }
#endif

  return std::strcmp(status, "bad") == 0 ? 1 : 0;
}
