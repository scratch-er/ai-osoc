#include <am.h>

#define CLINT_MMIO 0x02000000ul
#define MTIME_BASE 0xbff8ul
#define PLATFORM_HZ 100000000ull

static uint64_t boot_time = 0;

static uint64_t read_mtime() {
  volatile uint32_t *mtime = (volatile uint32_t *)(CLINT_MMIO + MTIME_BASE);
  uint32_t hi0, lo, hi1;
  do {
    hi0 = mtime[1];
    lo = mtime[0];
    hi1 = mtime[1];
  } while (hi0 != hi1);
  return ((uint64_t)hi1 << 32) | lo;
}

void __am_timer_init() {
  boot_time = read_mtime();
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime) {
  uint64_t ticks = read_mtime() - boot_time;
  uptime->us = ticks * 1000000ull / PLATFORM_HZ;
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc) {
  uint64_t seconds = (read_mtime() - boot_time) / PLATFORM_HZ;
  rtc->second = seconds % 60;
  rtc->minute = (seconds / 60) % 60;
  rtc->hour   = (seconds / 3600) % 24;
  rtc->day    = 1;
  rtc->month  = 1;
  rtc->year   = 1900;
}
