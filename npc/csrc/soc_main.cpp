// Verilator harness for the ysyxSoC simulation flavor (sim top: ysyxSoCTop).
//
// Zero-patch smoke harness: the SoC is simulated unmodified, so the core's
// debug/commit signals are not observable. Termination is by cycle limit and
// pass/fail is judged from this harness's structured NPC_SOC_* lines plus the
// UART16550 bytes that the RTL prints straight to stdout. P9-S3 will add the
// debug/commit exposure patch for precise termination and DiffTest.

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

namespace {

constexpr uint32_t MROM_BASE = 0x20000000u;
constexpr uint32_t MROM_SIZE = 0x1000u;  // 4KB AXI4MROM window

uint8_t g_mrom[MROM_SIZE];
uint64_t g_mrom_reads = 0;
uint64_t g_sim_time = 0;
#if VM_TRACE
VerilatedVcdC *g_tfp = nullptr;
#endif

struct Args {
  std::string image;
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

void usage(const char *prog) {
  std::printf("Usage: %s [--image FILE] [--max-cycles N] [--wave]\n", prog);
}

bool parse_args(int argc, char **argv, Args *args) {
  for (int i = 1; i < argc; i++) {
    if (std::strcmp(argv[i], "--image") == 0 && i + 1 < argc) {
      args->image = argv[++i];
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

bool load_image(const std::string &path) {
  if (path.empty()) {
    return true;
  }
  FILE *fp = std::fopen(path.c_str(), "rb");
  if (fp == nullptr) {
    std::perror(path.c_str());
    return false;
  }
  std::fseek(fp, 0, SEEK_END);
  long image_size = std::ftell(fp);
  std::fseek(fp, 0, SEEK_SET);
  if (image_size < 0 || static_cast<uint64_t>(image_size) > MROM_SIZE) {
    std::fprintf(stderr, "image out of bounds: size=%ld mrom=[0x%08x,+%u)\n",
                 image_size, MROM_BASE, MROM_SIZE);
    std::fclose(fp);
    return false;
  }
  size_t nread = std::fread(g_mrom, 1, static_cast<size_t>(image_size), fp);
  std::fclose(fp);
  if (nread != static_cast<size_t>(image_size)) {
    std::fprintf(stderr, "short read: expected %ld bytes, got %zu bytes\n", image_size, nread);
    return false;
  }
  std::printf("NPC_SOC_IMAGE path=%s base=0x%08x size=%ld\n", path.c_str(), MROM_BASE, image_size);
  return true;
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
  if (!load_image(args.image)) {
    std::printf("NPC_SOC_RESULT status=bad reason=image_load_failed cycles=0 limit=%llu\n",
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
  for (int i = 0; i < 20; i++) {
    eval_cycle(top);
  }
  top.reset = 0;
  top.eval();

  uint64_t cycles = 0;
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
  }

  std::printf("NPC_SOC_RESULT status=%s reason=%s cycles=%llu limit=%llu mrom_reads=%llu\n",
              status, reason,
              static_cast<unsigned long long>(cycles),
              static_cast<unsigned long long>(args.max_cycles),
              static_cast<unsigned long long>(g_mrom_reads));

#if VM_TRACE
  if (tfp) {
    tfp->close();
  }
#endif

  return std::strcmp(status, "bad") == 0 ? 1 : 0;
}
