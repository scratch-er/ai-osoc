#include "memory.h"

#include <cstdio>
#include <cstring>

namespace {
Memory *pmem = nullptr;
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

bool Memory::load_image(const std::string &path) {
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

  if (image_size < 0 || static_cast<uint32_t>(image_size) > data_size_) {
    std::fprintf(stderr, "image too large: %ld bytes, memory size %u bytes\n", image_size, data_size_);
    std::fclose(fp);
    return false;
  }

  size_t nread = std::fread(data_, 1, static_cast<size_t>(image_size), fp);
  std::fclose(fp);

  if (nread != static_cast<size_t>(image_size)) {
    std::fprintf(stderr, "short read: expected %ld bytes, got %zu bytes\n", image_size, nread);
    return false;
  }

  std::printf("NPC_IMAGE path=%s base=0x%08x size=%ld\n", path.c_str(), base_addr_, image_size);
  return true;
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

uint32_t Memory::read32(uint32_t addr) const {
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

void Memory::write32(uint32_t addr, uint32_t data) {
  if (!contains(addr, 4)) {
    std::fprintf(stderr, "pmem write out of bounds: addr=0x%08x data=0x%08x\n", addr, data);
    return;
  }

  uint32_t off = addr - base_addr_;
  data_[off] = static_cast<uint8_t>(data);
  data_[off + 1] = static_cast<uint8_t>(data >> 8);
  data_[off + 2] = static_cast<uint8_t>(data >> 16);
  data_[off + 3] = static_cast<uint8_t>(data >> 24);
  if (trace_) {
    std::printf("NPC_MEM w addr=0x%08x data=0x%08x\n", addr, data);
  }
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

extern "C" void pmem_write(uint32_t addr, uint32_t data) {
  if (pmem == nullptr) {
    std::fprintf(stderr, "pmem_write called before memory is initialized\n");
    return;
  }
  pmem->write32(addr, data);
}
