#include <am.h>
#include <klib.h>
#include <rtthread.h>

void rt_hw_interrupt_enable(rt_base_t level) {
  iset(level != 0);
}

rt_base_t rt_hw_interrupt_disable(void) {
  rt_base_t old = ienabled() ? 1 : 0;
  iset(0);
  return old;
}
