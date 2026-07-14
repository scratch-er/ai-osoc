/***************************************************************************************
* Copyright (c) 2014-2024 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include <cpu/cpu.h>
#include <cpu/decode.h>
#include <cpu/difftest.h>
#include <locale.h>

CPU_state cpu = {};
uint64_t g_nr_guest_inst = 0;
static uint64_t g_timer = 0; // unit: us

void device_update();

static CommitEvent make_commit_event(Decode *s, vaddr_t dnpc) {
  CommitEvent ev;
  memset(&ev, 0, sizeof(ev));
  ev.retire = g_nr_guest_inst;
  ev.cycle = g_nr_guest_inst;
  ev.pc = s->pc;
  ev.inst = s->isa.inst;
  ev.next_pc = dnpc;
  uint32_t opcode = ev.inst & 0x7f;
  uint32_t rd = (ev.inst >> 7) & 0x1f;
  bool has_wb = false;
  switch (opcode) {
    case 0x37: // lui
    case 0x17: // auipc
    case 0x6f: // jal
    case 0x67: // jalr
    case 0x03: // loads
    case 0x13: // OP-IMM
    case 0x33: // OP
    case 0x73: // CSR/system, refined below
      has_wb = rd != 0;
      break;
    default:
      break;
  }
  if (opcode == 0x73 && ((ev.inst >> 12) & 0x7) == 0) {
    has_wb = false; // ecall/ebreak/mret-like system instructions do not write GPRs
  }
  ev.has_wb = has_wb;
  ev.rd = rd;
  if (has_wb && rd < ARRLEN(cpu.gpr)) {
    ev.rd_value = cpu.gpr[rd];
  }
  if (nemu_state.state == NEMU_ABORT) {
    ev.exception = 1;
    ev.cause = nemu_state.state;
  }
  return ev;
}

static void difftest_after_commit(Decode *_this, vaddr_t dnpc) {
  IFDEF(CONFIG_DIFFTEST, difftest_step(_this->pc, dnpc));
}

static void exec_once(Decode *s, vaddr_t pc) {
  s->pc = pc;
  s->snpc = pc;
  isa_exec_once(s);
  cpu.pc = s->dnpc;
}

static void execute(uint64_t n) {
  Decode s;
  for (;n > 0; n --) {
    if (nemu_inst_limit != 0 && g_nr_guest_inst >= nemu_inst_limit) {
      nemu_state.state = NEMU_LIMIT;
      nemu_state.halt_pc = cpu.pc;
      nemu_state.halt_ret = 1;
      break;
    }
    exec_once(&s, cpu.pc);
    g_nr_guest_inst ++;
    CommitEvent ev = make_commit_event(&s, cpu.pc);
    commit_event_record(&ev);
    difftest_after_commit(&s, cpu.pc);
    if (nemu_state.state != NEMU_RUNNING) break;
    IFDEF(CONFIG_DEVICE, device_update());
  }
}

static void statistic() {
  IFNDEF(CONFIG_TARGET_AM, setlocale(LC_NUMERIC, ""));
#define NUMBERIC_FMT MUXDEF(CONFIG_TARGET_AM, "%", "%'") PRIu64
  Log("host time spent = " NUMBERIC_FMT " us", g_timer);
  Log("total guest instructions = " NUMBERIC_FMT, g_nr_guest_inst);
  if (g_timer > 0) Log("simulation frequency = " NUMBERIC_FMT " inst/s", g_nr_guest_inst * 1000000 / g_timer);
  else Log("Finish running in less than 1 us and can not calculate the simulation frequency");
}

static const char *nemu_result() {
  switch (nemu_state.state) {
    case NEMU_END: return nemu_state.halt_ret == 0 ? "good" : "bad";
    case NEMU_ABORT: return "abort";
    case NEMU_QUIT: return "quit";
    case NEMU_LIMIT: return "limit";
    case NEMU_STOP: return "stop";
    default: return "running";
  }
}

static void report_result() {
  printf("NEMU_RESULT status=%s state=%d halt_pc=" FMT_WORD " halt_ret=%u insts=%" PRIu64 " limit=%" PRIu64 "\n",
      nemu_result(), nemu_state.state, nemu_state.halt_pc, nemu_state.halt_ret,
      g_nr_guest_inst, nemu_inst_limit);
}

void assert_fail_msg() {
  isa_reg_display();
  commit_event_dump_last(0);
  statistic();
}

/* Simulate how the CPU works. */
void cpu_exec(uint64_t n) {
  switch (nemu_state.state) {
    case NEMU_END: case NEMU_ABORT: case NEMU_QUIT:
      printf("Program execution has ended. To restart the program, exit NEMU and run again.\n");
      return;
    default: nemu_state.state = NEMU_RUNNING;
  }

  uint64_t timer_start = get_time();

  execute(n);

  uint64_t timer_end = get_time();
  g_timer += timer_end - timer_start;

  switch (nemu_state.state) {
    case NEMU_RUNNING: nemu_state.state = NEMU_STOP; break;

    case NEMU_END: case NEMU_ABORT:
      Log("nemu: %s at pc = " FMT_WORD,
          (nemu_state.state == NEMU_ABORT ? ANSI_FMT("ABORT", ANSI_FG_RED) :
           (nemu_state.halt_ret == 0 ? ANSI_FMT("HIT GOOD TRAP", ANSI_FG_GREEN) :
            ANSI_FMT("HIT BAD TRAP", ANSI_FG_RED))),
          nemu_state.halt_pc);
      if (nemu_state.state == NEMU_ABORT || nemu_state.halt_ret != 0) {
        commit_event_dump_last(0);
      }
      statistic();
      report_result();
      break;
    case NEMU_LIMIT:
      Log("nemu: instruction limit reached at pc = " FMT_WORD, nemu_state.halt_pc);
      commit_event_dump_last(0);
      statistic();
      report_result();
      break;
    case NEMU_QUIT:
      statistic();
      report_result();
      break;
    case NEMU_STOP:
      report_result();
      break;
  }
}
