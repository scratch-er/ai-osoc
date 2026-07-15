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

#include <debug/mmio_replay.h>
#include <device/map.h>
#include <utils.h>

#define NPC_UART_BASE  0x10000000u
#define NPC_CLINT_BASE 0x02000000u
#define NPC_CLINT_SIZE 0x0000c000u
#define NPC_CLINT_MSIP     0x0000u
#define NPC_CLINT_MTIMECMP 0x4000u
#define NPC_CLINT_MTIME    0xbff8u

static uint8_t *npc_uart_base = NULL;
static uint8_t *npc_clint_base = NULL;
static MMIOReplayRecord mmio_replay = {};
static bool mmio_replay_mismatch __attribute__((unused)) = false;

static uint32_t load_le(uint8_t *p, int len) {
  uint32_t data = 0;
  for (int i = 0; i < len; i++) {
    data |= (uint32_t)p[i] << (i * 8);
  }
  return data;
}

static void store_le(uint8_t *p, int len, uint32_t data) {
  for (int i = 0; i < len; i++) {
    p[i] = data >> (i * 8);
  }
}

static bool replay_matches(uint32_t addr, int len, bool is_write, uint32_t data) {
#ifndef CONFIG_TARGET_SHARE
  return false;
#else
  if (!mmio_replay.valid) {
    printf("DIFFTEST_RESULT status=fail reason=unexpected_ref_mmio addr=0x%08x len=%d write=%u\n",
        addr, len, is_write);
    mmio_replay_mismatch = true;
    return false;
  }
  if (mmio_replay.addr != addr || mmio_replay.len != len || mmio_replay.is_write != is_write) {
    printf("DIFFTEST_RESULT status=fail reason=mmio_replay_mismatch ref_addr=0x%08x ref_len=%d ref_write=%u dut_addr=0x%08x dut_len=%u dut_write=%u\n",
        addr, len, is_write, mmio_replay.addr, mmio_replay.len, mmio_replay.is_write);
    mmio_replay_mismatch = true;
    mmio_replay.valid = false;
    return false;
  }
  if (is_write && (mmio_replay.wdata != data)) {
    printf("DIFFTEST_RESULT status=fail reason=mmio_replay_wdata ref=0x%08x dut=0x%08x addr=0x%08x\n",
        data, mmio_replay.wdata, addr);
    mmio_replay_mismatch = true;
    mmio_replay.valid = false;
    return false;
  }
  return true;
#endif
}

static void consume_replay(void) {
#ifdef CONFIG_TARGET_SHARE
  mmio_replay.valid = false;
#endif
}

static void npc_uart_io_handler(uint32_t offset, int len, bool is_write) {
  assert(offset == 0 && len == 1);
  if (is_write) {
    uint32_t data = npc_uart_base[0];
    if (replay_matches(NPC_UART_BASE + offset, len, true, data)) {
      consume_replay();
      return;
    }
#ifndef CONFIG_TARGET_SHARE
    putc(data & 0xff, stderr);
#endif
  } else {
    if (replay_matches(NPC_UART_BASE + offset, len, false, 0)) {
      npc_uart_base[0] = mmio_replay.rdata;
      consume_replay();
      return;
    }
    npc_uart_base[0] = 0;
  }
}

static bool clint_reg_access(uint32_t offset, int len) {
  uint32_t end = offset + len;
  return (offset < NPC_CLINT_MSIP + 4 && end > NPC_CLINT_MSIP) ||
         (offset < NPC_CLINT_MTIMECMP + 8 && end > NPC_CLINT_MTIMECMP) ||
         (offset < NPC_CLINT_MTIME + 8 && end > NPC_CLINT_MTIME);
}

static void update_mtime(void) {
  extern uint64_t g_nr_guest_inst;
  uint64_t ticks = g_nr_guest_inst;
  store_le(npc_clint_base + NPC_CLINT_MTIME, 4, (uint32_t)ticks);
  store_le(npc_clint_base + NPC_CLINT_MTIME + 4, 4, (uint32_t)(ticks >> 32));
}

static void npc_clint_io_handler(uint32_t offset, int len, bool is_write) {
  assert(len >= 1 && len <= 8);
  uint32_t addr = NPC_CLINT_BASE + offset;
  if (!clint_reg_access(offset, len)) {
    if (!is_write) {
      memset(npc_clint_base + offset, 0, len);
    }
    return;
  }

  if (is_write) {
    uint32_t data = load_le(npc_clint_base + offset, len);
    if (replay_matches(addr, len, true, data)) {
      consume_replay();
      return;
    }
    return;
  }

  if (replay_matches(addr, len, false, 0)) {
    store_le(npc_clint_base + offset, len, mmio_replay.rdata);
    consume_replay();
    return;
  }
  update_mtime();
}

void npc_mmio_replay_set(const MMIOReplayRecord *record) {
#ifdef CONFIG_TARGET_SHARE
  assert(record != NULL);
  assert(!mmio_replay.valid);
  mmio_replay = *record;
  mmio_replay_mismatch = false;
#else
  (void)record;
#endif
}

bool npc_mmio_replay_ok(void) {
#ifdef CONFIG_TARGET_SHARE
  if (mmio_replay_mismatch) { return false; }
  if (mmio_replay.valid) {
    printf("DIFFTEST_RESULT status=fail reason=missing_ref_mmio dut_addr=0x%08x dut_len=%u dut_write=%u\n",
        mmio_replay.addr, mmio_replay.len, mmio_replay.is_write);
    mmio_replay.valid = false;
    return false;
  }
#endif
  return true;
}

void init_npc_devices() {
  npc_uart_base = new_space(1);
  add_mmio_map("npc-uart", NPC_UART_BASE, npc_uart_base, 1, npc_uart_io_handler);

  npc_clint_base = new_space(NPC_CLINT_SIZE);
  add_mmio_map("npc-clint", NPC_CLINT_BASE, npc_clint_base, NPC_CLINT_SIZE, npc_clint_io_handler);
}
