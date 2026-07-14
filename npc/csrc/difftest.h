#ifndef NPC_DIFFTEST_H
#define NPC_DIFFTEST_H

#include "memory.h"

#include <cstddef>
#include <cstdint>
#include <string>

class Difftest {
public:
  Difftest() = default;

  bool init(const std::string &ref_so, const Memory &memory, uint32_t reset_pc,
            const uint32_t *regs, uint32_t pc);
  bool enabled() const { return enabled_; }
  bool step(const uint32_t *regs, uint32_t pc);

private:
  struct CPUState {
    uint32_t gpr[32];
    uint32_t pc;
  };

  bool enabled_ = false;
  void *handle_ = nullptr;
  void (*ref_memcpy_)(uint32_t addr, void *buf, size_t n, bool direction) = nullptr;
  void (*ref_regcpy_)(void *dut, bool direction) = nullptr;
  void (*ref_exec_)(uint64_t n) = nullptr;
  void (*ref_init_)(int port) = nullptr;

  static void fill_state(CPUState *state, const uint32_t *regs, uint32_t pc);
  bool check_regs(const CPUState &ref, const uint32_t *regs, uint32_t pc) const;
};

#endif
