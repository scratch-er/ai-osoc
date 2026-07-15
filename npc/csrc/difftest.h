#ifndef NPC_DIFFTEST_H
#define NPC_DIFFTEST_H

#include "memory.h"

#include <cstddef>
#include <cstdint>
#include <string>

#include <debug/commit_event.h>

class Difftest {
public:
  Difftest() = default;

  bool init(const std::string &ref_so, const Memory &memory, uint32_t reset_pc,
            const uint32_t *regs, uint32_t pc, uint32_t mstatus, uint32_t mtvec,
            uint32_t mepc, uint32_t mcause);
  bool enabled() const { return enabled_; }
  bool step(const CommitEvent &dut_event, const uint32_t *regs, uint32_t pc,
            uint32_t mstatus, uint32_t mtvec, uint32_t mepc, uint32_t mcause,
            bool *both_ebreak);
  void dump_last_ref(size_t n) const;

private:
  struct CPUState {
    uint32_t gpr[32];
    uint32_t pc;
    uint32_t mstatus;
    uint32_t mtvec;
    uint32_t mepc;
    uint32_t mcause;
  };

  bool enabled_ = false;
  void *handle_ = nullptr;
  void (*ref_memcpy_)(uint32_t addr, void *buf, size_t n, bool direction) = nullptr;
  void (*ref_regcpy_)(void *dut, bool direction) = nullptr;
  void (*ref_exec_)(uint64_t n) = nullptr;
  void (*ref_step_event_)(CommitEvent *ev) = nullptr;
  size_t (*ref_get_last_events_)(CommitEvent *buf, size_t max_n) = nullptr;
  void (*ref_init_)(int port) = nullptr;

  static void fill_state(CPUState *state, const uint32_t *regs, uint32_t pc,
                         uint32_t mstatus, uint32_t mtvec, uint32_t mepc, uint32_t mcause);
  bool check_regs(const CPUState &ref, const uint32_t *regs, uint32_t pc,
                  uint32_t mstatus, uint32_t mtvec, uint32_t mepc, uint32_t mcause) const;
  bool check_event(const CommitEvent &ref, const CommitEvent &dut) const;
};

#endif
