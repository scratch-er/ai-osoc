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

#include <utils.h>

NEMUState nemu_state = { .state = NEMU_STOP };
uint64_t nemu_inst_limit = 0;

#ifdef CONFIG_IQUEUE
static char iqueue[CONFIG_IQUEUE_SIZE][128];
static int iqueue_next = 0;
static int iqueue_count = 0;

void trace_inst_record(const char *logbuf) {
  if (CONFIG_IQUEUE_SIZE <= 0) return;
  snprintf(iqueue[iqueue_next], sizeof(iqueue[iqueue_next]), "%s", logbuf);
  iqueue_next = (iqueue_next + 1) % CONFIG_IQUEUE_SIZE;
  if (iqueue_count < CONFIG_IQUEUE_SIZE) iqueue_count ++;
}

void trace_inst_dump(void) {
  if (iqueue_count == 0) return;

  printf("NEMU recent instructions:\n");
  int first = (iqueue_next + CONFIG_IQUEUE_SIZE - iqueue_count) % CONFIG_IQUEUE_SIZE;
  for (int i = 0; i < iqueue_count; i ++) {
    int idx = (first + i) % CONFIG_IQUEUE_SIZE;
    printf("  %s%s\n", i == iqueue_count - 1 ? "--> " : "    ", iqueue[idx]);
  }
}
#endif

#ifdef CONFIG_MTRACE
bool mtrace_enabled(paddr_t addr) {
  return addr >= CONFIG_MTRACE_START && addr <= CONFIG_MTRACE_END;
}
#endif

int is_exit_status_bad() {
  int good = (nemu_state.state == NEMU_END && nemu_state.halt_ret == 0) ||
    (nemu_state.state == NEMU_QUIT);
  return !good;
}
