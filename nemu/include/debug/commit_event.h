#ifndef DEBUG_COMMIT_EVENT_H
#define DEBUG_COMMIT_EVENT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct {
  uint64_t retire;
  uint64_t cycle;
  uint32_t pc;
  uint32_t inst;
  uint32_t next_pc;
  uint8_t has_wb;
  uint8_t rd;
  uint32_t rd_value;
  uint8_t exception;
  uint32_t cause;
  uint8_t mem_valid;
  uint8_t mem_is_write;
  uint8_t mem_size;
  uint32_t mem_addr;
  uint32_t mem_wdata;
  uint32_t mem_rdata;
} CommitEvent;

typedef enum {
  COMMIT_DIFF_NONE = 0,
  COMMIT_DIFF_PC,
  COMMIT_DIFF_INST,
  COMMIT_DIFF_NEXT_PC,
  COMMIT_DIFF_EXCEPTION,
  COMMIT_DIFF_CAUSE,
  COMMIT_DIFF_WB_VALID,
  COMMIT_DIFF_WB_REG,
  COMMIT_DIFF_WB_VALUE,
} CommitDiffKind;

typedef struct {
  CommitDiffKind kind;
  char field[24];
  uint32_t ref_value;
  uint32_t dut_value;
} CommitDiff;

static inline void commit_event_format(const CommitEvent *ev, char *buf, size_t size) {
  snprintf(buf, size,
      "R=%llu C=%llu PC=%08x I=%08x RD=%u RV=%08x NPC=%08x EXC=%u CAUSE=%u",
      (unsigned long long)ev->retire,
      (unsigned long long)ev->cycle,
      ev->pc,
      ev->inst,
      ev->has_wb ? ev->rd : 0,
      ev->has_wb ? ev->rd_value : 0,
      ev->next_pc,
      ev->exception,
      ev->cause);
}

static inline bool commit_event_compare(const CommitEvent *ref, const CommitEvent *dut, CommitDiff *diff) {
#define SET_DIFF(k, name, rv, dv) do { \
    if (diff != NULL) { \
      diff->kind = (k); \
      snprintf(diff->field, sizeof(diff->field), "%s", (name)); \
      diff->ref_value = (uint32_t)(rv); \
      diff->dut_value = (uint32_t)(dv); \
    } \
  } while (0)
  if (ref->pc != dut->pc) { SET_DIFF(COMMIT_DIFF_PC, "pc", ref->pc, dut->pc); return false; }
  if (ref->inst != dut->inst) { SET_DIFF(COMMIT_DIFF_INST, "inst", ref->inst, dut->inst); return false; }
  if (ref->next_pc != dut->next_pc) { SET_DIFF(COMMIT_DIFF_NEXT_PC, "next_pc", ref->next_pc, dut->next_pc); return false; }
  if (ref->exception != dut->exception) { SET_DIFF(COMMIT_DIFF_EXCEPTION, "exception", ref->exception, dut->exception); return false; }
  if (ref->exception && ref->cause != dut->cause) { SET_DIFF(COMMIT_DIFF_CAUSE, "cause", ref->cause, dut->cause); return false; }
  if (ref->has_wb != dut->has_wb) { SET_DIFF(COMMIT_DIFF_WB_VALID, "has_wb", ref->has_wb, dut->has_wb); return false; }
  if (ref->has_wb) {
    if (ref->rd != dut->rd) { SET_DIFF(COMMIT_DIFF_WB_REG, "rd", ref->rd, dut->rd); return false; }
    if (ref->rd_value != dut->rd_value) { SET_DIFF(COMMIT_DIFF_WB_VALUE, "rd_value", ref->rd_value, dut->rd_value); return false; }
  }
  if (diff != NULL) {
    diff->kind = COMMIT_DIFF_NONE;
    diff->field[0] = '\0';
    diff->ref_value = 0;
    diff->dut_value = 0;
  }
  return true;
#undef SET_DIFF
}

#endif
