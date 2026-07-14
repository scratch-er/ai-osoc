#include "VNPC.h"

#include "memory.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <array>
#include <memory>
#include <string>

#if VM_TRACE
#include "verilated_vcd_c.h"
#endif

#include "verilated.h"

namespace {

constexpr uint32_t NPC_STATUS_RUNNING = 0;
constexpr uint32_t NPC_STATUS_GOOD = 1;
constexpr uint32_t NPC_STATUS_BAD = 2;
constexpr uint32_t NPC_STATUS_LIMIT = 3;

constexpr size_t TRACE_DEPTH = 8;

struct TraceEntry {
  uint64_t cycle = 0;
  uint32_t pc = 0;
  uint32_t inst = 0;
};

struct Args {
  std::string image;
  uint64_t max_cycles = 100;
  uint32_t reset_pc = 0x20000000u;
  bool wave = false;
  bool check_x1 = false;
  uint32_t expect_x1 = 0;
  bool dump_trace = false;
  bool dump_regs = false;
  bool mem_trace = false;
};

void usage(const char *prog) {
  std::printf("Usage: %s [--image FILE] [--max-cycles N] [--reset-pc HEX] [--expect-x1 HEX] [--wave] [--dump-trace] [--dump-regs] [--mem-trace]\n", prog);
}

bool parse_u64(const char *s, uint64_t *value) {
  char *end = nullptr;
  unsigned long long v = std::strtoull(s, &end, 0);
  if (end == s || *end != '\0') {
    return false;
  }
  *value = static_cast<uint64_t>(v);
  return true;
}

uint32_t debug_reg(const VNPC &top, int idx) {
  return top.debug_regs_flat[idx];
}

void dump_regs(const VNPC &top) {
  for (int row = 0; row < 4; row++) {
    int base = row * 4;
    std::printf("NPC_REGS x%-2d=0x%08x x%-2d=0x%08x x%-2d=0x%08x x%-2d=0x%08x\n",
                base, debug_reg(top, base),
                base + 1, debug_reg(top, base + 1),
                base + 2, debug_reg(top, base + 2),
                base + 3, debug_reg(top, base + 3));
  }
}

void dump_trace(const std::array<TraceEntry, TRACE_DEPTH> &trace, size_t trace_count) {
  size_t count = trace_count < TRACE_DEPTH ? trace_count : TRACE_DEPTH;
  size_t start = trace_count >= TRACE_DEPTH ? trace_count % TRACE_DEPTH : 0;
  for (size_t i = 0; i < count; i++) {
    const TraceEntry &entry = trace[(start + i) % TRACE_DEPTH];
    std::printf("NPC_TRACE cycle=%llu pc=0x%08x inst=0x%08x\n",
                static_cast<unsigned long long>(entry.cycle),
                entry.pc,
                entry.inst);
  }
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
    } else if (std::strcmp(argv[i], "--reset-pc") == 0 && i + 1 < argc) {
      uint64_t value = 0;
      if (!parse_u64(argv[++i], &value)) {
        std::fprintf(stderr, "invalid --reset-pc\n");
        return false;
      }
      args->reset_pc = static_cast<uint32_t>(value);
    } else if (std::strcmp(argv[i], "--expect-x1") == 0 && i + 1 < argc) {
      uint64_t value = 0;
      if (!parse_u64(argv[++i], &value)) {
        std::fprintf(stderr, "invalid --expect-x1\n");
        return false;
      }
      args->check_x1 = true;
      args->expect_x1 = static_cast<uint32_t>(value);
    } else if (std::strcmp(argv[i], "--wave") == 0) {
      args->wave = true;
    } else if (std::strcmp(argv[i], "--dump-trace") == 0) {
      args->dump_trace = true;
    } else if (std::strcmp(argv[i], "--dump-regs") == 0) {
      args->dump_regs = true;
    } else if (std::strcmp(argv[i], "--mem-trace") == 0) {
      args->mem_trace = true;
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

} // namespace

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  Args args;
  if (!parse_args(argc, argv, &args)) {
    return 2;
  }

  Memory memory(args.reset_pc);
  memory.set_trace(args.mem_trace);
  set_pmem(&memory);
  if (!memory.load_image(args.image)) {
    std::printf("NPC_RESULT status=bad reason=image_load_failed cycles=0 pc=0x%08x\n", args.reset_pc);
    return 1;
  }

  auto top = std::make_unique<VNPC>();

#if VM_TRACE
  std::unique_ptr<VerilatedVcdC> tfp;
  if (args.wave) {
    Verilated::traceEverOn(true);
    tfp = std::make_unique<VerilatedVcdC>();
    top->trace(tfp.get(), 99);
    tfp->open("build/wave.vcd");
  }
#endif

  uint64_t sim_time = 0;
  auto eval_cycle = [&]() {
    top->clock = 0;
    top->eval();
#if VM_TRACE
    if (args.wave && tfp) tfp->dump(sim_time);
#endif
    sim_time++;
    top->clock = 1;
    top->eval();
#if VM_TRACE
    if (args.wave && tfp) tfp->dump(sim_time);
#endif
    sim_time++;
  };

  top->reset = 1;
  top->io_interrupt = 0;
  top->io_reset_pc = args.reset_pc;
  eval_cycle();
  eval_cycle();
  top->reset = 0;

  std::array<TraceEntry, TRACE_DEPTH> trace;
  size_t trace_count = 0;
  uint64_t cycles = 0;
  while (!Verilated::gotFinish() && !top->debug_halted && cycles < args.max_cycles) {
    trace[trace_count % TRACE_DEPTH] = TraceEntry{cycles, top->debug_pc, top->debug_inst};
    trace_count++;
    eval_cycle();
    cycles++;
  }

  bool limit = !top->debug_halted && cycles >= args.max_cycles;
  bool check_pass = !args.check_x1 || top->debug_x1 == args.expect_x1;
  uint32_t trap_status = limit ? NPC_STATUS_LIMIT : top->debug_trap_status;
  bool trap_pass = trap_status == NPC_STATUS_GOOD;
  bool run_pass = check_pass && trap_pass;
  const char *status = "bad";
  if (limit) {
    status = "limit";
  } else if (run_pass) {
    status = "good";
  }
  if (args.check_x1) {
    std::printf("NPC_CHECK x1=0x%08x expect=0x%08x %s\n",
                top->debug_x1,
                args.expect_x1,
                check_pass ? "PASS" : "FAIL");
  }
  std::printf("NPC_RESULT status=%s cycles=%llu pc=0x%08x halted=%u limit=%llu x1=0x%08x a0=0x%08x trap=%u\n",
              status,
              static_cast<unsigned long long>(cycles),
              top->debug_pc,
              top->debug_halted,
              static_cast<unsigned long long>(args.max_cycles),
              top->debug_x1,
              top->debug_a0,
              trap_status);
  bool dump_on_failure = !run_pass;
  if (args.dump_trace || dump_on_failure) {
    dump_trace(trace, trace_count);
  }
  if (args.dump_regs || dump_on_failure) {
    dump_regs(*top);
  }

#if VM_TRACE
  if (tfp) {
    tfp->close();
  }
#endif

  return run_pass ? 0 : 1;
}
