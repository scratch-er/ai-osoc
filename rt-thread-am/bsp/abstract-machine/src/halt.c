#include <rtthread.h>

static int halt(int argc, char **argv) {
  asm volatile("li a0, 0; ebreak");
  while (1) {}
  return 0;
}
MSH_CMD_EXPORT(halt, halt machine with good trap);
