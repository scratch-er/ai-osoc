#include <am.h>
#include <klib-macros.h>

extern char _heap_start;
int main(const char *args);

#define SRAM_END 0x0f002000u

Area heap = RANGE(&_heap_start, SRAM_END);
static const char mainargs[MAINARGS_MAX_LEN] = TOSTRING(MAINARGS_PLACEHOLDER); // defined in CFLAGS

#define UART_BASE 0x10000000u
#define UART_THR  ((volatile char *)(UART_BASE + 0x0u))
#define UART_DLL  ((volatile char *)(UART_BASE + 0x0u))
#define UART_DLM  ((volatile char *)(UART_BASE + 0x1u))
#define UART_FCR  ((volatile char *)(UART_BASE + 0x2u))
#define UART_LCR  ((volatile char *)(UART_BASE + 0x3u))
#define UART_LSR  ((volatile char *)(UART_BASE + 0x5u))
#define UART_LSR_THRE 0x20u

static void uart_init() {
  *UART_LCR = 0x80; // enable divisor latch access
  *UART_DLL = 0x01;
  *UART_DLM = 0x00;
  *UART_LCR = 0x03; // 8 data bits, no parity, 1 stop bit
  *UART_FCR = 0x07; // enable and clear FIFOs
}

static bool uart_ready() {
  return ((*UART_LSR) & UART_LSR_THRE) != 0;
}

void putch(char ch) {
  while (!uart_ready());
  *UART_THR = ch;
}

void halt(int code) {
  asm volatile("mv a0, %0; ebreak" : : "r"(code));

  // should not reach here
  while (1);
}

void _trm_init() {
  uart_init();
  int ret = main(mainargs);
  halt(ret);
}
