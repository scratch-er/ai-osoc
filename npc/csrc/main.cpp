#include "VNPC.h"

#include "memory.h"
#include "difftest.h"

#include <debug/commit_event.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

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
  std::string difftest_ref;
  std::string exec_script;
  std::string script_file;
  uint64_t max_cycles = 100;
  uint32_t reset_pc = 0x20000000u;
  bool wave = false;
  bool check_x1 = false;
  uint32_t expect_x1 = 0;
  bool dump_trace = false;
  bool dump_regs = false;
  bool mem_trace = false;
  size_t ring_size = 64;
};

struct RunResult {
  std::string status = "stop";
  std::string reason = "none";
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

uint32_t debug_reg(const VNPC &top, int idx) {
  return top.debug_regs_flat[idx];
}

bool is_clint_addr(uint32_t addr) {
  return addr >= 0x02000000u && addr < 0x02010000u;
}

bool is_mmio_addr(uint32_t addr) {
  return addr == 0x10000000u || is_clint_addr(addr);
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

std::array<uint32_t, 16> debug_regs(const VNPC &top) {
  std::array<uint32_t, 16> regs{};
  for (int i = 0; i < 16; i++) {
    regs[i] = debug_reg(top, i);
  }
  return regs;
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

class CommitRing {
public:
  explicit CommitRing(size_t size) : entries_(std::max<size_t>(size, 1)) {}

  void push(const CommitEvent &ev) {
    entries_[next_] = ev;
    next_ = (next_ + 1) % entries_.size();
    if (count_ < entries_.size()) count_++;
  }

  std::vector<CommitEvent> last(size_t n) const {
    if (n == 0 || n > count_) n = count_;
    std::vector<CommitEvent> out;
    out.reserve(n);
    size_t first = (next_ + entries_.size() - n) % entries_.size();
    for (size_t i = 0; i < n; i++) {
      out.push_back(entries_[(first + i) % entries_.size()]);
    }
    return out;
  }

  void dump(size_t n) const {
    auto events = last(n);
    std::printf("NPC_LAST_BEGIN count=%zu\n", events.size());
    for (const auto &ev : events) {
      char buf[160];
      commit_event_format(&ev, buf, sizeof(buf));
      std::printf("NPC_LAST %s\n", buf);
    }
    std::printf("NPC_LAST_END\n");
  }

private:
  std::vector<CommitEvent> entries_;
  size_t next_ = 0;
  size_t count_ = 0;
};

class Simulator {
public:
  Simulator(VNPC &top, Memory &memory, const Args &args, Difftest &difftest)
      : top_(top), memory_(memory), args_(args), difftest_(difftest), ring_(args.ring_size) {}

  void reset() {
    cycles_ = 0;
    retire_ = 0;
    pending_mmio_read_ = {};
    memory_.set_time(0);
    top_.reset = 1;
    top_.io_interrupt = 0;
    top_.io_reset_pc = args_.reset_pc;
    eval_cycle();
    eval_cycle();
    top_.reset = 0;
    top_.eval();
  }

  bool load(const std::string &path, uint32_t addr) {
    return memory_.load_image_at(path, addr);
  }

  RunResult step(uint64_t n) {
    RunResult result;
    for (uint64_t i = 0; i < n; i++) {
      if (Verilated::gotFinish()) return {"bad", "host_finish"};
      if (top_.debug_halted) return finish_reason(false);
      if (cycles_ >= args_.max_cycles) return {"limit", "cycle_limit"};
      if (!top_.commit_valid) {
        memory_.clear_mmio_record();
        memory_.set_time(cycles_ + 1);
        eval_cycle();
        pending_mmio_read_ = memory_.mmio_record();
        if (pending_mmio_read_.is_write) {
          pending_mmio_read_ = {};
        }
        cycles_++;
        continue;
      }

      memory_.clear_mmio_record();
      memory_.set_time(cycles_ + 1);
      top_.eval();
      CommitEvent ev = make_event();
      MMIOReplayRecord read_mmio_record = pending_mmio_read_;
      pending_mmio_read_ = {};
      if (!read_mmio_record.valid) {
        read_mmio_record = memory_.mmio_record();
      }
      bool commit_mem_wen = top_.commit_mem_wen;
      bool commit_mem_ren = top_.commit_mem_ren;
      uint32_t commit_mem_addr = top_.commit_mem_addr;
      uint32_t commit_mem_wdata = top_.commit_mem_wdata;
      uint32_t commit_mem_rdata = top_.commit_mem_rdata;
      uint8_t commit_mem_wmask = static_cast<uint8_t>(top_.commit_mem_wmask & 0xf);
      MMIOReplayRecord mmio_record{};
      if (commit_mem_wen && is_mmio_addr(commit_mem_addr)) {
        mmio_record = {true, true, commit_mem_addr, low_contiguous_len(commit_mem_wmask),
                       commit_mem_wmask, commit_mem_wdata, 0};
      } else if (commit_mem_ren && is_clint_addr(commit_mem_addr)) {
        mmio_record = {true, false, commit_mem_addr, load_len_from_inst(top_.commit_inst),
                       0, 0, commit_mem_rdata};
      }
      eval_cycle();
      pending_mmio_read_ = memory_.mmio_record();
      if (pending_mmio_read_.is_write) {
        pending_mmio_read_ = {};
      }
      if (!mmio_record.valid) {
        mmio_record = read_mmio_record;
      }
      cycles_++;
      ring_.push(ev);
      retire_++;
      if (commit_mem_wen) {
        memory_.commit_mmio_write(commit_mem_addr, commit_mem_wdata, commit_mem_wmask);
      }

      if (log_level_ >= 1 || trace_on_) {
        char buf[160];
        commit_event_format(&ev, buf, sizeof(buf));
        std::printf("NPC_TRACE %s\n", buf);
      }

      if (difftest_.enabled()) {
        auto regs = debug_regs(top_);
        bool both_ebreak = false;
        if (!difftest_.step(ev, mmio_record, regs.data(), top_.debug_pc, top_.debug_mstatus,
                            top_.debug_mtvec, top_.debug_mepc, top_.debug_mcause,
                            &both_ebreak)) {
          difftest_.dump_last_ref(8);
          return {"bad", "difftest_mismatch"};
        }
        if (both_ebreak) {
          return debug_reg(top_, 10) == 0 ? RunResult{"good", "good_trap"} : RunResult{"bad", "bad_trap"};
        }
      }

      if (!difftest_.enabled() && ev.inst == 0x00100073u) {
        return debug_reg(top_, 10) == 0 ? RunResult{"good", "good_trap"} : RunResult{"bad", "bad_trap"};
      }
      if (ev.exception && top_.debug_halted) return {"bad", "illegal_inst"};
      if (top_.debug_halted) return finish_reason(false);
      if (breakpoint_hit(top_.debug_pc)) {
        std::printf("NPC_BREAK_HIT pc=0x%08x insts=%llu cycles=%llu\n",
                    top_.debug_pc,
                    static_cast<unsigned long long>(retire_),
                    static_cast<unsigned long long>(cycles_));
        return {"stop", "breakpoint"};
      }
    }
    if (cycles_ >= args_.max_cycles) {
      result.status = "limit";
      result.reason = "cycle_limit";
    } else {
      result.status = "stop";
      result.reason = "step_done";
    }
    return result;
  }

  RunResult run(uint64_t n) {
    return step(n);
  }

  bool add_breakpoint(uint32_t pc) {
    if (breakpoint_hit(pc)) return true;
    if (breakpoints_.size() >= 16) return false;
    breakpoints_.push_back(pc);
    return true;
  }

  bool delete_breakpoint(uint32_t pc) {
    auto it = std::find(breakpoints_.begin(), breakpoints_.end(), pc);
    if (it == breakpoints_.end()) return false;
    breakpoints_.erase(it);
    return true;
  }

  void clear_breakpoints() { breakpoints_.clear(); }

  void list_breakpoints() const {
    std::printf("NPC_BREAK_LIST count=%zu\n", breakpoints_.size());
    for (uint32_t pc : breakpoints_) {
      std::printf("NPC_BREAK addr=0x%08x\n", pc);
    }
  }

  RunResult run_to(uint32_t target_pc) {
    while (true) {
      if (top_.debug_pc == target_pc) return {"stop", "target_pc"};
      RunResult r = step(1);
      if (r.reason != "step_done") return r;
    }
  }

  RunResult run_until_reg(int idx, uint32_t value) {
    while (true) {
      if (idx >= 0 && idx < 16 && debug_reg(top_, idx) == value) return {"stop", "target_reg"};
      RunResult r = step(1);
      if (r.reason != "step_done") return r;
    }
  }

  void dump_last(size_t n) const { ring_.dump(n); }
  void set_log(int level) { log_level_ = level; }
  void set_trace(bool on) { trace_on_ = on; }
  uint64_t cycles() const { return cycles_; }
  uint64_t retired() const { return retire_; }

private:
  bool breakpoint_hit(uint32_t pc) const {
    if (breakpoints_.empty()) return false;
    return std::find(breakpoints_.begin(), breakpoints_.end(), pc) != breakpoints_.end();
  }

  CommitEvent make_event() const {
    CommitEvent ev{};
    ev.retire = retire_ + 1;
    ev.cycle = cycles_;
    ev.pc = top_.commit_pc;
    ev.inst = top_.commit_inst;
    ev.next_pc = top_.commit_next_pc;
    ev.has_wb = top_.commit_wen;
    ev.rd = top_.commit_rd;
    ev.rd_value = top_.commit_wdata;
    ev.exception = top_.commit_exception;
    ev.cause = top_.commit_cause;
    return ev;
  }

  RunResult finish_reason(bool limit) const {
    if (limit) return {"limit", "cycle_limit"};
    if (top_.debug_trap_status == NPC_STATUS_GOOD) return {"good", "good_trap"};
    if (top_.debug_trap_status == NPC_STATUS_BAD) return {"bad", "bad_trap"};
    return {"stop", "halted"};
  }

  void eval_cycle() {
    top_.clock = 0;
    top_.eval();
    sim_time_++;
    top_.clock = 1;
    top_.eval();
    sim_time_++;
  }

  VNPC &top_;
  Memory &memory_;
  const Args &args_;
  Difftest &difftest_;
  CommitRing ring_;
  uint64_t sim_time_ = 0;
  uint64_t cycles_ = 0;
  uint64_t retire_ = 0;
  MMIOReplayRecord pending_mmio_read_{};
  int log_level_ = 0;
  bool trace_on_ = false;
  std::vector<uint32_t> breakpoints_;
};

void usage(const char *prog) {
  std::printf("Usage: %s [--image FILE] [--max-cycles N] [--reset-pc HEX] [--expect-x1 HEX] [--difftest-ref SO] [--wave] [--dump-trace] [--dump-regs] [--mem-trace] [-e COMMANDS] [-f FILE]\n", prog);
}

bool parse_args(int argc, char **argv, Args *args) {
  for (int i = 1; i < argc; i++) {
    if (std::strcmp(argv[i], "--image") == 0 && i + 1 < argc) {
      args->image = argv[++i];
    } else if (std::strcmp(argv[i], "--difftest-ref") == 0 && i + 1 < argc) {
      args->difftest_ref = argv[++i];
    } else if ((std::strcmp(argv[i], "-e") == 0 || std::strcmp(argv[i], "--exec") == 0) && i + 1 < argc) {
      args->exec_script = argv[++i];
    } else if ((std::strcmp(argv[i], "-f") == 0 || std::strcmp(argv[i], "--script") == 0) && i + 1 < argc) {
      args->script_file = argv[++i];
    } else if (std::strcmp(argv[i], "--max-cycles") == 0 && i + 1 < argc) {
      if (!parse_u64(argv[++i], &args->max_cycles)) {
        std::fprintf(stderr, "invalid --max-cycles\n");
        return false;
      }
    } else if (std::strcmp(argv[i], "--ring-size") == 0 && i + 1 < argc) {
      uint64_t value = 0;
      if (!parse_u64(argv[++i], &value)) return false;
      args->ring_size = static_cast<size_t>(value);
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
    } else if (argv[i][0] == '+') {
      // Verilator plusargs are consumed by RTL through $value$plusargs.
    } else {
      std::fprintf(stderr, "unknown argument: %s\n", argv[i]);
      usage(argv[0]);
      return false;
    }
  }
  return true;
}

std::vector<std::string> split_commands(const std::string &script) {
  std::vector<std::string> commands;
  std::string current;
  for (char c : script) {
    if (c == ';' || c == '\n') {
      if (!current.empty()) commands.push_back(current);
      current.clear();
    } else {
      current.push_back(c);
    }
  }
  if (!current.empty()) commands.push_back(current);
  return commands;
}

std::vector<std::string> tokens(const std::string &line) {
  std::istringstream iss(line);
  std::vector<std::string> out;
  std::string tok;
  while (iss >> tok) out.push_back(tok);
  return out;
}

bool parse_u32_token(const std::string &s, uint32_t *value) {
  uint64_t tmp = 0;
  if (!parse_u64(s.c_str(), &tmp)) return false;
  *value = static_cast<uint32_t>(tmp);
  return true;
}

bool execute_command(const std::string &line, Simulator &sim, VNPC &top, Memory &memory, RunResult *last_result) {
  auto t = tokens(line);
  if (t.empty()) return true;
  const std::string &cmd = t[0];
  if (cmd == "exit" || cmd == "quit") return false;
  if (cmd == "load" || cmd == "load_bin") {
    if (t.size() < 2) {
      std::printf("Usage: load <file> [addr]\n");
      return true;
    }
    uint32_t addr = memory.base();
    if (t.size() >= 3 && !parse_u32_token(t[2], &addr)) {
      std::printf("invalid load address: %s\n", t[2].c_str());
      return true;
    }
    sim.load(t[1], addr);
  } else if (cmd == "reset") {
    sim.reset();
  } else if (cmd == "step") {
    uint64_t n = t.size() >= 2 ? std::strtoull(t[1].c_str(), nullptr, 0) : 1;
    *last_result = sim.step(n);
  } else if (cmd == "run") {
    if (t.size() >= 3 && t[1] == "to") {
      uint32_t pc = 0;
      if (parse_u32_token(t[2], &pc)) *last_result = sim.run_to(pc);
    } else if (t.size() >= 5 && t[1] == "until" && t[2] == "reg") {
      int idx = std::strtol(t[3].c_str(), nullptr, 0);
      uint32_t value = 0;
      if (parse_u32_token(t[4], &value)) *last_result = sim.run_until_reg(idx, value);
    } else {
      uint64_t n = t.size() >= 2 ? std::strtoull(t[1].c_str(), nullptr, 0) : UINT64_MAX;
      *last_result = sim.run(n);
    }
  } else if (cmd == "break") {
    if (t.size() < 2) {
      std::printf("Usage: break <addr>\n");
    } else {
      uint32_t pc = 0;
      if (parse_u32_token(t[1], &pc)) {
        bool ok = sim.add_breakpoint(pc);
        std::printf("NPC_BREAK status=%s addr=0x%08x\n", ok ? "set" : "full", pc);
      }
    }
  } else if (cmd == "delete-break") {
    if (t.size() < 2) {
      std::printf("Usage: delete-break <addr>\n");
    } else {
      uint32_t pc = 0;
      if (parse_u32_token(t[1], &pc)) {
        bool ok = sim.delete_breakpoint(pc);
        std::printf("NPC_BREAK status=%s addr=0x%08x\n", ok ? "deleted" : "missing", pc);
      }
    }
  } else if (cmd == "clear-breaks") {
    sim.clear_breakpoints();
    std::printf("NPC_BREAK status=cleared\n");
  } else if (cmd == "list-breaks") {
    sim.list_breakpoints();
  } else if (cmd == "print") {
    if (t.size() >= 2 && t[1] == "pc") {
      std::printf("pc = 0x%08x\n", top.debug_pc);
    } else if (t.size() >= 2 && t[1] == "reg") {
      if (t.size() == 2) dump_regs(top);
      else {
        int idx = std::strtol(t[2].c_str(), nullptr, 0);
        if (idx >= 0 && idx < 16) std::printf("x%d = 0x%08x\n", idx, debug_reg(top, idx));
      }
    } else if (t.size() >= 4 && t[1] == "mem") {
      uint32_t addr = 0;
      uint32_t size = 0;
      if (parse_u32_token(t[2], &addr) && parse_u32_token(t[3], &size)) {
        for (uint32_t off = 0; off < size; off += 4) {
          std::printf("MEM 0x%08x = 0x%08x\n", addr + off, memory.read32(addr + off));
        }
      }
    }
  } else if (cmd == "dump" && t.size() >= 2 && t[1] == "state") {
    std::printf("NPC_STATE pc=0x%08x cycles=%llu retired=%llu halted=%u trap=%u\n",
                top.debug_pc,
                static_cast<unsigned long long>(sim.cycles()),
                static_cast<unsigned long long>(sim.retired()),
                top.debug_halted,
                top.debug_trap_status);
    dump_regs(top);
  } else if (cmd == "last") {
    size_t n = t.size() >= 2 ? static_cast<size_t>(std::strtoull(t[1].c_str(), nullptr, 0)) : 0;
    sim.dump_last(n);
  } else if (cmd == "log") {
    int level = t.size() >= 2 ? std::strtol(t[1].c_str(), nullptr, 0) : 0;
    sim.set_log(level);
  } else if (cmd == "trace") {
    bool on = t.size() >= 2 && t[1] == "on";
    sim.set_trace(on);
  } else {
    std::printf("Unknown command '%s'\n", cmd.c_str());
  }
  return true;
}

std::string read_script_file(const std::string &path) {
  std::ifstream in(path);
  std::ostringstream ss;
  ss << in.rdbuf();
  return ss.str();
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

  Difftest difftest;
  Simulator sim(*top, memory, args, difftest);
  sim.reset();

  if (!args.difftest_ref.empty()) {
    auto regs = debug_regs(*top);
    if (!difftest.init(args.difftest_ref, memory, args.reset_pc, regs.data(), top->debug_pc,
                       top->debug_mstatus, top->debug_mtvec, top->debug_mepc, top->debug_mcause)) {
      std::printf("NPC_RESULT status=bad reason=difftest_init_failed cycles=0 pc=0x%08x\n", top->debug_pc);
      return 1;
    }
  }

  RunResult result;
  bool scripted = !args.exec_script.empty() || !args.script_file.empty();
  if (scripted) {
    std::string script = !args.exec_script.empty() ? args.exec_script : read_script_file(args.script_file);
    for (const auto &cmd : split_commands(script)) {
      if (!execute_command(cmd, sim, *top, memory, &result)) break;
    }
  } else {
    result = sim.run(args.max_cycles);
  }

  bool check_pass = !args.check_x1 || top->debug_x1 == args.expect_x1;
  if (args.check_x1) {
    std::printf("NPC_CHECK x1=0x%08x expect=0x%08x %s\n",
                top->debug_x1,
                args.expect_x1,
                check_pass ? "PASS" : "FAIL");
  }
  if (!check_pass && result.status == "good") {
    result.status = "bad";
    result.reason = "check_failed";
  }
  uint32_t trap_status = result.status == "limit" ? NPC_STATUS_LIMIT :
                         result.reason == "good_trap" ? NPC_STATUS_GOOD :
                         result.reason == "bad_trap" ? NPC_STATUS_BAD : top->debug_trap_status;
  std::printf("NPC_RESULT status=%s reason=%s cycles=%llu insts=%llu pc=0x%08x halted=%u limit=%llu x1=0x%08x a0=0x%08x trap=%u\n",
              result.status.c_str(),
              result.reason.c_str(),
              static_cast<unsigned long long>(sim.cycles()),
              static_cast<unsigned long long>(sim.retired()),
              top->debug_pc,
              top->debug_halted,
              static_cast<unsigned long long>(args.max_cycles),
              top->debug_x1,
              top->debug_a0,
              trap_status);
  std::printf("NPC_CSR mstatus=0x%08x mtvec=0x%08x mepc=0x%08x mcause=0x%08x\n",
              top->debug_mstatus, top->debug_mtvec, top->debug_mepc, top->debug_mcause);

  bool run_pass = check_pass && result.status == "good";
  if (args.dump_trace || !run_pass) {
    sim.dump_last(0);
  }
  if (args.dump_regs || !run_pass) {
    dump_regs(*top);
  }

#if VM_TRACE
  if (tfp) {
    tfp->close();
  }
#endif

  return run_pass ? 0 : 1;
}
