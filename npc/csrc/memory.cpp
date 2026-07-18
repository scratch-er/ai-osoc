#include "memory.h"

#include <cstdio>
#include <cstring>

namespace {
constexpr uint32_t UART_BASE = 0x10000000u;
constexpr uint32_t UART_END = 0x10000020u;
constexpr uint32_t CLINT_BASE = 0x02000000u;
constexpr uint32_t CLINT_END = 0x02010000u;
constexpr uint32_t CLINT_MTIME = CLINT_BASE + 0xbff8u;
constexpr uint32_t CLINT_MTIMEH = CLINT_BASE + 0xbffcu;
Memory *pmem = nullptr;

uint8_t low_contiguous_mask(uint8_t wmask) {
  for (int i = 0; i < 4; i++) {
    if ((wmask & (1u << i)) == 0) {
      return wmask & ((1u << i) - 1u);
    }
  }
  return wmask & 0xf;
}

uint8_t mask_len(uint8_t wmask) {
  uint8_t mask = low_contiguous_mask(wmask);
  uint8_t len = 0;
  while (mask != 0) {
    len++;
    mask >>= 1;
  }
  return len == 0 ? 4 : len;
}
}

Memory::Memory(uint32_t base_addr, uint32_t size)
    : base_addr_(base_addr), data_size_(size), data_(new uint8_t[size]) {
  std::memset(data_, 0, data_size_);
}

bool Memory::contains(uint32_t addr, uint32_t len) const {
  if (addr < base_addr_) {
    return false;
  }
  uint32_t off = addr - base_addr_;
  return off <= data_size_ && len <= data_size_ - off;
}

bool Memory::access_ok(uint32_t addr) const {
  return contains(addr, 4) || (addr >= UART_BASE && addr < UART_END) || (addr >= CLINT_BASE && addr < CLINT_END);
}

bool Memory::load_image(const std::string &path) {
  return load_image_at(path, base_addr_);
}

bool Memory::load_image_at(const std::string &path, uint32_t addr) {
  if (path.empty()) {
    return true;
  }

  FILE *fp = std::fopen(path.c_str(), "rb");
  if (fp == nullptr) {
    std::perror(path.c_str());
    return false;
  }

  std::fseek(fp, 0, SEEK_END);
  long image_size = std::ftell(fp);
  std::fseek(fp, 0, SEEK_SET);

  if (image_size < 0 || !contains(addr, static_cast<uint32_t>(image_size))) {
    std::fprintf(stderr, "image out of bounds: addr=0x%08x size=%ld memory=[0x%08x,+%u)\n",
                 addr, image_size, base_addr_, data_size_);
    std::fclose(fp);
    return false;
  }

  uint32_t off = addr - base_addr_;
  size_t nread = std::fread(data_ + off, 1, static_cast<size_t>(image_size), fp);
  std::fclose(fp);

  if (nread != static_cast<size_t>(image_size)) {
    std::fprintf(stderr, "short read: expected %ld bytes, got %zu bytes\n", image_size, nread);
    return false;
  }

  std::printf("NPC_IMAGE path=%s base=0x%08x size=%ld\n", path.c_str(), addr, image_size);
  return true;
}

void Memory::set_uart_expect(const std::string &text) {
  uart_expect_ = text;
  uart_expect_pos_ = 0;
  uart_expect_seen_ = false;
}

void Memory::copy_to(void *dst, uint32_t addr, uint32_t len) const {
  if (!contains(addr, len)) {
    std::fprintf(stderr, "pmem copy out of bounds: addr=0x%08x len=%u\n", addr, len);
    std::memset(dst, 0, len);
    return;
  }

  uint32_t off = addr - base_addr_;
  std::memcpy(dst, data_ + off, len);
}

uint32_t Memory::read32(uint32_t addr) {
  if (addr == CLINT_MTIME || addr == CLINT_MTIMEH) {
    uint32_t data = (addr == CLINT_MTIME) ? static_cast<uint32_t>(time_)
                                          : static_cast<uint32_t>(time_ >> 32);
    mmio_record_ = {true, false, addr, 4, 0, 0, data};
    if (trace_) {
      std::printf("NPC_MMIO r addr=0x%08x data=0x%08x\n", addr, data);
    }
    return data;
  }
  if (addr >= CLINT_BASE && addr < CLINT_END) {
    mmio_record_ = {true, false, addr, 4, 0, 0, 0};
    if (trace_) {
      std::printf("NPC_MMIO r addr=0x%08x data=0x00000000\n", addr);
    }
    return 0;
  }
  if (!contains(addr, 4)) {
    std::fprintf(stderr, "pmem read out of bounds: addr=0x%08x\n", addr);
    return 0;
  }

  uint32_t off = addr - base_addr_;
  uint32_t data = static_cast<uint32_t>(data_[off]) |
                  (static_cast<uint32_t>(data_[off + 1]) << 8) |
                  (static_cast<uint32_t>(data_[off + 2]) << 16) |
                  (static_cast<uint32_t>(data_[off + 3]) << 24);
  if (trace_) {
    std::printf("NPC_MEM r addr=0x%08x data=0x%08x\n", addr, data);
  }
  return data;
}

void Memory::write32(uint32_t addr, uint32_t data, uint8_t wmask) {
  if ((addr >= UART_BASE && addr < UART_END) || (addr >= CLINT_BASE && addr < CLINT_END)) {
    mmio_record_ = {true, true, addr, mask_len(wmask), static_cast<uint8_t>(wmask & 0xf), data, 0};
#if !NPC_DEBUG
    if (addr == UART_BASE && (wmask & 0x1) != 0) {
      unsigned char ch = static_cast<unsigned char>(data & 0xff);
      if (!uart_expect_seen_ && !uart_expect_.empty()) {
        if (ch == static_cast<unsigned char>(uart_expect_[uart_expect_pos_])) {
          uart_expect_pos_++;
          if (uart_expect_pos_ == uart_expect_.size()) {
            uart_expect_seen_ = true;
          }
        } else {
          uart_expect_pos_ = (ch == static_cast<unsigned char>(uart_expect_[0])) ? 1 : 0;
        }
      }
      if (ch == 0x04) {
        uart_eot_ = true;
      } else {
        std::putchar(ch);
        std::fflush(stdout);
      }
    }
#endif
    if (trace_) {
      std::printf("NPC_MMIO w addr=0x%08x data=0x%08x mask=0x%x\n", addr, data, wmask & 0xf);
    }
    return;
  }
  if (!contains(addr, 4)) {
    std::fprintf(stderr, "pmem write out of bounds: addr=0x%08x data=0x%08x mask=0x%x\n", addr, data, wmask & 0xf);
    return;
  }

  uint32_t off = addr - base_addr_;
  for (int i = 0; i < 4; i++) {
    if ((wmask >> i) & 0x1) {
      data_[off + i] = static_cast<uint8_t>(data >> (i * 8));
    }
  }
  if (trace_) {
    std::printf("NPC_MEM w addr=0x%08x data=0x%08x mask=0x%x\n", addr, data, wmask & 0xf);
  }
}

void Memory::commit_mmio_write(uint32_t addr, uint32_t data, uint8_t wmask) {
  if (addr == UART_BASE && (wmask & 0x1) != 0) {
    unsigned char ch = static_cast<unsigned char>(data & 0xff);
    if (!uart_expect_seen_ && !uart_expect_.empty()) {
      if (ch == static_cast<unsigned char>(uart_expect_[uart_expect_pos_])) {
        uart_expect_pos_++;
        if (uart_expect_pos_ == uart_expect_.size()) {
          uart_expect_seen_ = true;
        }
      } else {
        uart_expect_pos_ = (ch == static_cast<unsigned char>(uart_expect_[0])) ? 1 : 0;
      }
    }
    if (ch == 0x04) {
      uart_eot_ = true;
    } else {
      std::putchar(ch);
      std::fflush(stdout);
    }
  }
}

void Memory::clear_mmio_record() {
  mmio_record_ = {};
}

void set_pmem(Memory *memory) {
  pmem = memory;
}

extern "C" uint32_t pmem_read(uint32_t addr) {
  if (pmem == nullptr) {
    std::fprintf(stderr, "pmem_read called before memory is initialized\n");
    return 0;
  }
  return pmem->read32(addr);
}

extern "C" uint32_t pmem_access_ok(uint32_t addr) {
  if (pmem == nullptr) {
    std::fprintf(stderr, "pmem_access_ok called before memory is initialized\n");
    return 0;
  }
  return pmem->access_ok(addr) ? 1u : 0u;
}

extern "C" void pmem_write(uint32_t addr, uint32_t data, uint8_t wmask) {
  if (pmem == nullptr) {
    std::fprintf(stderr, "pmem_write called before memory is initialized\n");
    return;
  }
  pmem->write32(addr, data, wmask);
}
