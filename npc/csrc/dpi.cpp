#include "dpi.h"

#include <cstdio>

extern "C" void npc_trap(int code) {
  std::printf("NPC_TRAP code=%d\n", code);
}
