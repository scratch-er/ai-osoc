#include "difftest.h"

#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>

namespace {
constexpr bool DIFFTEST_TO_DUT = false;
constexpr bool DIFFTEST_TO_REF = true;
}

void Difftest::fill_state(CPUState *state, const uint32_t *regs, uint32_t pc,
                          uint32_t mstatus, uint32_t mtvec, uint32_t mepc, uint32_t mcause) {
  std::memset(state, 0, sizeof(*state));
  for (int i = 0; i < 16; i++) {
    state->gpr[i] = regs[i];
  }
  state->gpr[0] = 0;
  state->pc = pc;
  state->mstatus = mstatus;
  state->mtvec = mtvec;
  state->mepc = mepc;
  state->mcause = mcause;
}

bool Difftest::init(const std::string &ref_so, const Memory &memory, uint32_t reset_pc,
                    const uint32_t *regs, uint32_t pc, uint32_t mstatus, uint32_t mtvec,
                    uint32_t mepc, uint32_t mcause) {
  handle_ = dlopen(ref_so.c_str(), RTLD_LAZY);
  if (handle_ == nullptr) {
    std::fprintf(stderr, "difftest dlopen failed: %s\n", dlerror());
    return false;
  }

  ref_memcpy_ = reinterpret_cast<void (*)(uint32_t, void *, size_t, bool)>(dlsym(handle_, "difftest_memcpy"));
  ref_regcpy_ = reinterpret_cast<void (*)(void *, bool)>(dlsym(handle_, "difftest_regcpy"));
  ref_exec_ = reinterpret_cast<void (*)(uint64_t)>(dlsym(handle_, "difftest_exec"));
  ref_step_event_ = reinterpret_cast<void (*)(CommitEvent *)>(dlsym(handle_, "difftest_step_event"));
  ref_get_last_events_ = reinterpret_cast<size_t (*)(CommitEvent *, size_t)>(dlsym(handle_, "difftest_get_last_events"));
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
  fill_state(&dut, regs, pc, mstatus, mtvec, mepc, mcause);
  ref_regcpy_(&dut, DIFFTEST_TO_REF);
  enabled_ = true;
  std::printf("NPC_DIFFTEST status=on ref=%s base=0x%08x size=%u event_api=%u\n",
              ref_so.c_str(), reset_pc, memory.size(), ref_step_event_ != nullptr);
  return true;
}

bool Difftest::step(const CommitEvent &dut_event, const uint32_t *regs, uint32_t pc,
                    uint32_t mstatus, uint32_t mtvec, uint32_t mepc, uint32_t mcause,
                    bool *both_ebreak) {
  if (both_ebreak != nullptr) {
    *both_ebreak = false;
  }
  if (!enabled_) {
    return true;
  }

  if (ref_step_event_ != nullptr) {
    CommitEvent ref_event{};
    ref_step_event_(&ref_event);
    if (ref_event.pc == dut_event.pc && ref_event.inst == dut_event.inst && dut_event.inst == 0x00100073u) {
      if (both_ebreak != nullptr) {
        *both_ebreak = true;
      }
      return true;
    }
    if (ref_event.inst == 0x00100073u || dut_event.inst == 0x00100073u) {
      char ref_buf[160];
      char dut_buf[160];
      commit_event_format(&ref_event, ref_buf, sizeof(ref_buf));
      commit_event_format(&dut_event, dut_buf, sizeof(dut_buf));
      std::printf("DIFFTEST_RESULT status=fail reason=ebreak_mismatch retire=%llu\n",
                  static_cast<unsigned long long>(dut_event.retire));
      std::printf("DIFFTEST_REF %s\n", ref_buf);
      std::printf("DIFFTEST_DUT %s\n", dut_buf);
      return false;
    }
    if (!check_event(ref_event, dut_event)) {
      CPUState ref;
      ref_regcpy_(&ref, DIFFTEST_TO_DUT);
      check_regs(ref, regs, pc, mstatus, mtvec, mepc, mcause);
      return false;
    }
    return true;
  }

  ref_exec_(1);
  CPUState ref;
  ref_regcpy_(&ref, DIFFTEST_TO_DUT);
  return check_regs(ref, regs, pc, mstatus, mtvec, mepc, mcause);
}

bool Difftest::check_event(const CommitEvent &ref, const CommitEvent &dut) const {
  CommitDiff diff{};
  if (commit_event_compare(&ref, &dut, &diff)) {
    return true;
  }
  char ref_buf[160];
  char dut_buf[160];
  commit_event_format(&ref, ref_buf, sizeof(ref_buf));
  commit_event_format(&dut, dut_buf, sizeof(dut_buf));
  std::printf("DIFFTEST_RESULT status=fail reason=commit_mismatch retire=%llu field=%s ref=0x%08x dut=0x%08x\n",
              static_cast<unsigned long long>(dut.retire), diff.field, diff.ref_value, diff.dut_value);
  std::printf("DIFFTEST_REF %s\n", ref_buf);
  std::printf("DIFFTEST_DUT %s\n", dut_buf);
  return false;
}

bool Difftest::check_regs(const CPUState &ref, const uint32_t *regs, uint32_t pc,
                          uint32_t mstatus, uint32_t mtvec, uint32_t mepc, uint32_t mcause) const {
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
  if (ref.mstatus != mstatus) {
    std::printf("NPC_DIFFTEST mismatch mstatus dut=0x%08x ref=0x%08x\n", mstatus, ref.mstatus);
    ok = false;
  }
  if (ref.mtvec != mtvec) {
    std::printf("NPC_DIFFTEST mismatch mtvec dut=0x%08x ref=0x%08x\n", mtvec, ref.mtvec);
    ok = false;
  }
  if (ref.mepc != mepc) {
    std::printf("NPC_DIFFTEST mismatch mepc dut=0x%08x ref=0x%08x\n", mepc, ref.mepc);
    ok = false;
  }
  if (ref.mcause != mcause) {
    std::printf("NPC_DIFFTEST mismatch mcause dut=0x%08x ref=0x%08x\n", mcause, ref.mcause);
    ok = false;
  }
  if (!ok) {
    std::printf("NPC_DIFFTEST status=fail\n");
  }
  return ok;
}

void Difftest::dump_last_ref(size_t n) const {
  if (ref_get_last_events_ == nullptr || n == 0) return;
  std::vector<CommitEvent> events(n);
  size_t count = ref_get_last_events_(events.data(), n);
  std::printf("REF_LAST_BEGIN count=%zu\n", count);
  for (size_t i = 0; i < count; i++) {
    char buf[160];
    commit_event_format(&events[i], buf, sizeof(buf));
    std::printf("REF_LAST %s\n", buf);
  }
  std::printf("REF_LAST_END\n");
}
