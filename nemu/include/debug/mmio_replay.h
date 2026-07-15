#ifndef DEBUG_MMIO_REPLAY_H
#define DEBUG_MMIO_REPLAY_H

#include <stdbool.h>
#include <stdint.h>

typedef struct {
  bool valid;
  bool is_write;
  uint32_t addr;
  uint8_t len;
  uint8_t wmask;
  uint32_t wdata;
  uint32_t rdata;
} MMIOReplayRecord;

#endif
