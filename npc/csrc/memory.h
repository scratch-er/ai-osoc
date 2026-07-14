#ifndef NPC_MEMORY_H
#define NPC_MEMORY_H

#include <cstdint>
#include <string>

class Memory {
public:
  explicit Memory(uint32_t base_addr = 0x20000000u, uint32_t size = 16u * 1024u * 1024u);

  bool load_image(const std::string &path);
  uint32_t base() const { return base_addr_; }
  uint32_t size() const { return static_cast<uint32_t>(data_size_); }
  bool contains(uint32_t addr, uint32_t len) const;

private:
  uint32_t base_addr_;
  uint32_t data_size_;
  uint8_t *data_;
};

#endif
