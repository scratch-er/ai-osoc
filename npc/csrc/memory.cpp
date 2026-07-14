#include "memory.h"

#include <cstdio>
#include <cstring>

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
