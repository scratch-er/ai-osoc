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

typedef struct {
  const char *name;
  paddr_t base;
  uint32_t size;
  uint8_t *host;
  bool loadable;
  bool writable;
} MemRegion;

#if   defined(CONFIG_PMEM_MALLOC)
static uint8_t *pmem = NULL;
#else // CONFIG_PMEM_GARRAY
static uint8_t pmem[CONFIG_MSIZE] PG_ALIGN = {};
#endif

static MemRegion mem_regions[] = {
#if defined(CONFIG_MEM_SCHEME_NPC)
  { "npc-pmem", CONFIG_MBASE, 0x01000000u, NULL, true, true },
#else
  { "pmem", CONFIG_MBASE, CONFIG_MSIZE, NULL, true, true },
#endif
};

#define NR_MEM_REGION ARRLEN(mem_regions)

static inline bool range_in_region(const MemRegion *region, paddr_t addr, size_t len) {
  paddr_t offset = addr - region->base;
  return offset < region->size && len <= region->size - offset;
}

static inline MemRegion *find_mem_region(paddr_t addr, size_t len) {
  if (likely(range_in_region(&mem_regions[0], addr, len))) { return &mem_regions[0]; }
  for (int i = 1; i < NR_MEM_REGION; i++) {
    if (range_in_region(&mem_regions[i], addr, len)) { return &mem_regions[i]; }
  }
  return NULL;
}

static inline uint8_t *region_guest_to_host(MemRegion *region, paddr_t addr) {
  return region->host + addr - region->base;
}

bool paddr_is_backed(paddr_t addr, size_t len) {
  return find_mem_region(addr, len) != NULL;
}

bool paddr_is_loadable(paddr_t addr, size_t len) {
  MemRegion *region = find_mem_region(addr, len);
  return region != NULL && region->loadable;
}

uint8_t* guest_to_host(paddr_t paddr) {
  MemRegion *region = find_mem_region(paddr, 1);
  Assert(region != NULL, "address = " FMT_PADDR " is not backed by physical memory", paddr);
  return region_guest_to_host(region, paddr);
}

paddr_t host_to_guest(uint8_t *haddr) {
  for (int i = 0; i < NR_MEM_REGION; i++) {
    MemRegion *region = &mem_regions[i];
    if (haddr >= region->host && haddr < region->host + region->size) {
      return region->base + (haddr - region->host);
    }
  }
  panic("host address %p is not backed by physical memory", haddr);
}

void paddr_memcpy_to_guest(paddr_t addr, const void *buf, size_t len, bool require_loadable) {
  paddr_t end = addr + (paddr_t)len - 1;
  MemRegion *region = find_mem_region(addr, len);
  Assert(region != NULL, "load range [" FMT_PADDR ", " FMT_PADDR "] is not backed by physical memory",
      addr, end);
  Assert(!require_loadable || region->loadable,
      "load range [" FMT_PADDR ", " FMT_PADDR "] targets non-loadable memory region '%s'",
      addr, end, region->name);
  memcpy(region_guest_to_host(region, addr), buf, len);
}

void paddr_memcpy_from_guest(void *buf, paddr_t addr, size_t len) {
  paddr_t end = addr + (paddr_t)len - 1;
  MemRegion *region = find_mem_region(addr, len);
  Assert(region != NULL, "copy range [" FMT_PADDR ", " FMT_PADDR "] is not backed by physical memory",
      addr, end);
  memcpy(buf, region_guest_to_host(region, addr), len);
}

static word_t pmem_read(paddr_t addr, int len) {
  MemRegion *region = find_mem_region(addr, len);
  Assert(region != NULL, "address = " FMT_PADDR " is not backed by physical memory", addr);
  return host_read(region_guest_to_host(region, addr), len);
}

static void pmem_write(paddr_t addr, int len, word_t data) {
  MemRegion *region = find_mem_region(addr, len);
  Assert(region != NULL, "address = " FMT_PADDR " is not backed by physical memory", addr);
  Assert(region->writable, "write to non-writable memory region '%s' at " FMT_PADDR " pc = " FMT_WORD,
      region->name, addr, cpu.pc);
  host_write(region_guest_to_host(region, addr), len, data);
}

static void out_of_bound(paddr_t addr) {
  panic("address = " FMT_PADDR " is out of bound of physical memory at pc = " FMT_WORD, addr, cpu.pc);
}

void init_mem() {
#if   defined(CONFIG_PMEM_MALLOC)
  pmem = malloc(CONFIG_MSIZE);
  assert(pmem);
#endif
  mem_regions[0].host = pmem;
  IFDEF(CONFIG_MEM_RANDOM, memset(pmem, rand(), CONFIG_MSIZE));
  for (int i = 0; i < NR_MEM_REGION; i++) {
    Log("physical memory region '%s' [" FMT_PADDR ", " FMT_PADDR "] loadable=%d writable=%d",
        mem_regions[i].name, mem_regions[i].base, mem_regions[i].base + mem_regions[i].size - 1,
        mem_regions[i].loadable, mem_regions[i].writable);
  }
}

word_t paddr_read(paddr_t addr, int len) {
  if (likely(paddr_is_backed(addr, len))) {
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
  if (likely(paddr_is_backed(addr, len))) { pmem_write(addr, len, data); return; }
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
