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

#define COMMIT_EVENT_RING_SIZE 64
static CommitEvent commit_ring[COMMIT_EVENT_RING_SIZE];
static size_t commit_ring_next = 0;
static size_t commit_ring_count = 0;

void commit_event_record(const CommitEvent *ev) {
  commit_ring[commit_ring_next] = *ev;
  commit_ring_next = (commit_ring_next + 1) % COMMIT_EVENT_RING_SIZE;
  if (commit_ring_count < COMMIT_EVENT_RING_SIZE) commit_ring_count ++;
}

void commit_event_dump_last(size_t n) {
  if (commit_ring_count == 0) return;
  if (n == 0 || n > commit_ring_count) n = commit_ring_count;
  size_t first = (commit_ring_next + COMMIT_EVENT_RING_SIZE - n) % COMMIT_EVENT_RING_SIZE;
  printf("NEMU_LAST_BEGIN count=%zu\n", n);
  for (size_t i = 0; i < n; i ++) {
    size_t idx = (first + i) % COMMIT_EVENT_RING_SIZE;
    char buf[160];
    commit_event_format(&commit_ring[idx], buf, sizeof(buf));
    printf("NEMU_LAST %s\n", buf);
  }
  printf("NEMU_LAST_END\n");
}

bool commit_event_get_last(CommitEvent *ev) {
  if (commit_ring_count == 0) return false;
  size_t idx = (commit_ring_next + COMMIT_EVENT_RING_SIZE - 1) % COMMIT_EVENT_RING_SIZE;
  *ev = commit_ring[idx];
  return true;
}

size_t commit_event_copy_last(CommitEvent *buf, size_t max_n) {
  size_t n = commit_ring_count < max_n ? commit_ring_count : max_n;
  size_t first = (commit_ring_next + COMMIT_EVENT_RING_SIZE - n) % COMMIT_EVENT_RING_SIZE;
  for (size_t i = 0; i < n; i ++) {
    buf[i] = commit_ring[(first + i) % COMMIT_EVENT_RING_SIZE];
  }
  return n;
}

int is_exit_status_bad() {
  int good = (nemu_state.state == NEMU_END && nemu_state.halt_ret == 0) ||
    (nemu_state.state == NEMU_QUIT);
  return !good;
}
