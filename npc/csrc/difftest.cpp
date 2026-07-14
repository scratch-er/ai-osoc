#include "difftest.h"

#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>

namespace {
constexpr bool DIFFTEST_TO_DUT = false;
constexpr bool DIFFTEST_TO_REF = true;
}

void Difftest::fill_state(CPUState *state, const uint32_t *regs, uint32_t pc) {
  std::memset(state, 0, sizeof(*state));
  for (int i = 0; i < 16; i++) {
    state->gpr[i] = regs[i];
  }
  state->gpr[0] = 0;
  state->pc = pc;
}

bool Difftest::init(const std::string &ref_so, const Memory &memory, uint32_t reset_pc,
                    const uint32_t *regs, uint32_t pc) {
  handle_ = dlopen(ref_so.c_str(), RTLD_LAZY);
  if (handle_ == nullptr) {
    std::fprintf(stderr, "difftest dlopen failed: %s\n", dlerror());
    return false;
  }

  ref_memcpy_ = reinterpret_cast<void (*)(uint32_t, void *, size_t, bool)>(dlsym(handle_, "difftest_memcpy"));
  ref_regcpy_ = reinterpret_cast<void (*)(void *, bool)>(dlsym(handle_, "difftest_regcpy"));
  ref_exec_ = reinterpret_cast<void (*)(uint64_t)>(dlsym(handle_, "difftest_exec"));
  ref_init_ = reinterpret_cast<void (*)(int)>(dlsym(handle_, "difftest_init"));
  if (ref_memcpy_ == nullptr || ref_regcpy_ == nullptr || ref_exec_ == nullptr || ref_init_ == nullptr) {
    std::fprintf(stderr, "difftest missing required REF symbol\n");
    return false;
  }

  ref_init_(0);

  std::vector<uint8_t> image(memory.size());
  memory.copy_to(image.data(), reset_pc, memory.size());
  ref_memcpy_(reset_pc, image.data(), image.size(), DIFFTEST_TO_REF);

  CPUState dut;
  fill_state(&dut, regs, pc);
  ref_regcpy_(&dut, DIFFTEST_TO_REF);
  enabled_ = true;
  std::printf("NPC_DIFFTEST status=on ref=%s base=0x%08x size=%u\n",
              ref_so.c_str(), reset_pc, memory.size());
  return true;
}

bool Difftest::step(const uint32_t *regs, uint32_t pc) {
  if (!enabled_) {
    return true;
  }

  ref_exec_(1);
  CPUState ref;
  ref_regcpy_(&ref, DIFFTEST_TO_DUT);
  return check_regs(ref, regs, pc);
}

bool Difftest::check_regs(const CPUState &ref, const uint32_t *regs, uint32_t pc) const {
  bool ok = true;
  if (ref.pc != pc) {
    std::printf("NPC_DIFFTEST mismatch pc dut=0x%08x ref=0x%08x\n", pc, ref.pc);
    ok = false;
  }
  for (int i = 0; i < 16; i++) {
    uint32_t dut = (i == 0) ? 0 : regs[i];
    if (ref.gpr[i] != dut) {
      std::printf("NPC_DIFFTEST mismatch x%d dut=0x%08x ref=0x%08x\n", i, dut, ref.gpr[i]);
      ok = false;
    }
  }
  for (int i = 16; i < 32; i++) {
    if (ref.gpr[i] != 0) {
      std::printf("NPC_DIFFTEST mismatch x%d dut=unused ref=0x%08x\n", i, ref.gpr[i]);
      ok = false;
    }
  }
  if (!ok) {
    std::printf("NPC_DIFFTEST status=fail\n");
  }
  return ok;
}
