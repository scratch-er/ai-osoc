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

#include <memory/host.h>
#include <memory/paddr.h>
#include <device/mmio.h>
#include <isa.h>

#define SERIAL_MMIO 0xa00003f8u
#define NPC_UART_MMIO 0x10000000u
#define NPC_CLINT_BASE 0x02000000u
#define NPC_CLINT_END  0x02010000u
#define NPC_MTIME      (NPC_CLINT_BASE + 0xbff8u)
#define NPC_MTIMEH     (NPC_CLINT_BASE + 0xbffcu)

#if   defined(CONFIG_PMEM_MALLOC)
static uint8_t *pmem = NULL;
#else // CONFIG_PMEM_GARRAY
static uint8_t pmem[CONFIG_MSIZE] PG_ALIGN = {};
#endif

uint8_t* guest_to_host(paddr_t paddr) { return pmem + paddr - CONFIG_MBASE; }
paddr_t host_to_guest(uint8_t *haddr) { return haddr - pmem + CONFIG_MBASE; }

static word_t pmem_read(paddr_t addr, int len) {
  word_t ret = host_read(guest_to_host(addr), len);
  return ret;
}

static void pmem_write(paddr_t addr, int len, word_t data) {
  host_write(guest_to_host(addr), len, data);
}

static void out_of_bound(paddr_t addr) {
  panic("address = " FMT_PADDR " is out of bound of pmem [" FMT_PADDR ", " FMT_PADDR "] at pc = " FMT_WORD,
      addr, PMEM_LEFT, PMEM_RIGHT, cpu.pc);
}

void init_mem() {
#if   defined(CONFIG_PMEM_MALLOC)
  pmem = malloc(CONFIG_MSIZE);
  assert(pmem);
#endif
  IFDEF(CONFIG_MEM_RANDOM, memset(pmem, rand(), CONFIG_MSIZE));
  Log("physical memory area [" FMT_PADDR ", " FMT_PADDR "]", PMEM_LEFT, PMEM_RIGHT);
}

word_t paddr_read(paddr_t addr, int len) {
  if (likely(in_pmem(addr))) {
    return pmem_read(addr, len);
  }
  if (addr == NPC_MTIME || addr == NPC_MTIMEH) {
    extern uint64_t g_nr_guest_inst;
    uint64_t ticks = g_nr_guest_inst;
    return addr == NPC_MTIME ? (word_t)ticks : (word_t)(ticks >> 32);
  }
  if (addr >= NPC_CLINT_BASE && addr < NPC_CLINT_END) { return 0; }
#ifdef CONFIG_DEVICE
  return mmio_read(addr, len);
#else
  if ((addr == SERIAL_MMIO || addr == NPC_UART_MMIO) && len == 1) { return 0; }
#endif
  out_of_bound(addr);
  return 0;
}

void paddr_write(paddr_t addr, int len, word_t data) {
  if (likely(in_pmem(addr))) { pmem_write(addr, len, data); return; }
  if (addr >= NPC_CLINT_BASE && addr < NPC_CLINT_END) { return; }
#ifdef CONFIG_DEVICE
  if (addr == NPC_UART_MMIO && len == 1) { return; }
  mmio_write(addr, len, data);
  return;
#else
  if ((addr == SERIAL_MMIO || addr == NPC_UART_MMIO) && len == 1) { putc(data & 0xff, stderr); return; }
#endif
  out_of_bound(addr);
}
