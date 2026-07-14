#include <am.h>
#include <nemu.h>

void __am_timer_init() {
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime) {
  uint32_t hi, lo;
  do {
    hi = inl(RTC_ADDR + 4);
    lo = inl(RTC_ADDR);
  } while (hi != inl(RTC_ADDR + 4));
  uptime->us = ((uint64_t)hi << 32) | lo;
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc) {
  AM_TIMER_UPTIME_T uptime;
  __am_timer_uptime(&uptime);
  uint64_t seconds = uptime.us / 1000000;
  rtc->second = seconds % 60;
  rtc->minute = (seconds / 60) % 60;
  rtc->hour   = (seconds / 3600) % 24;
  rtc->day    = 1;
  rtc->month  = 1;
  rtc->year   = 1900;
}
