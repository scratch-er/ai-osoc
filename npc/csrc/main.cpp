#include "VNPC.h"

#include "memory.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
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

struct Args {
  std::string image;
  uint64_t max_cycles = 100;
  uint32_t reset_pc = 0x20000000u;
  bool wave = false;
  bool check_x1 = false;
  uint32_t expect_x1 = 0;
};

void usage(const char *prog) {
  std::printf("Usage: %s [--image FILE] [--max-cycles N] [--reset-pc HEX] [--expect-x1 HEX] [--wave]\n", prog);
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

  uint64_t cycles = 0;
  while (!Verilated::gotFinish() && !top->debug_halted && cycles < args.max_cycles) {
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

#if VM_TRACE
  if (tfp) {
    tfp->close();
  }
#endif

  return run_pass ? 0 : 1;
}
