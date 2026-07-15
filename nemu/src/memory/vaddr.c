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

#include <isa.h>
#include <memory/paddr.h>

static bool native_device_access_ok(vaddr_t addr, int len) {
#ifdef CONFIG_HAS_SERIAL
  if (addr >= CONFIG_SERIAL_MMIO && addr + len <= CONFIG_SERIAL_MMIO + 8) { return true; }
#endif
#ifdef CONFIG_HAS_TIMER
  if (addr >= CONFIG_RTC_MMIO && addr + len <= CONFIG_RTC_MMIO + 8) { return true; }
#endif
  return false;
}

bool vaddr_access_ok(vaddr_t addr, int len) {
  return paddr_is_backed(addr, len)
      || native_device_access_ok(addr, len)
      || addr == 0x10000000u
      || (addr >= 0x02000000u && addr + len <= 0x0200c000u);
}

word_t vaddr_ifetch(vaddr_t addr, int len) {
  return paddr_read(addr, len);
}

word_t vaddr_read(vaddr_t addr, int len) {
  return paddr_read(addr, len);
}

void vaddr_write(vaddr_t addr, int len, word_t data) {
  paddr_write(addr, len, data);
}
