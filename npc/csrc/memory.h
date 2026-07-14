#ifndef NPC_MEMORY_H
#define NPC_MEMORY_H

#include <cstdint>
#include <string>

class Memory {
public:
  explicit Memory(uint32_t base_addr = 0x20000000u, uint32_t size = 16u * 1024u * 1024u);

  bool load_image(const std::string &path);
  bool load_image_at(const std::string &path, uint32_t addr);
  uint32_t base() const { return base_addr_; }
  uint32_t size() const { return static_cast<uint32_t>(data_size_); }
  bool contains(uint32_t addr, uint32_t len) const;
  void set_trace(bool enable) { trace_ = enable; }
  void set_time(uint64_t time) { time_ = time; }
  void copy_to(void *dst, uint32_t addr, uint32_t len) const;
  uint32_t read32(uint32_t addr) const;
  void write32(uint32_t addr, uint32_t data, uint8_t wmask = 0xf);
  void commit_mmio_write(uint32_t addr, uint32_t data, uint8_t wmask);

private:
  uint32_t base_addr_;
  uint32_t data_size_;
  uint8_t *data_;
  uint64_t time_ = 0;
  bool trace_ = false;
};

void set_pmem(Memory *memory);

extern "C" uint32_t pmem_read(uint32_t addr);

#endif
