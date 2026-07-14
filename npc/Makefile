TOP := NPC
BUILD_DIR := build
OBJ_DIR := $(BUILD_DIR)/obj_dir
BIN := $(BUILD_DIR)/npc
VERILATOR ?= verilator
CXXFLAGS += -std=c++17 -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable -Wno-unused-but-set-variable -Wno-sign-compare -O2

RTL_SRCS := $(shell find rtl -name '*.v' | sort)
CPP_SRCS := csrc/main.cpp csrc/memory.cpp csrc/dpi.cpp
TRACE ?= 0

VERILATOR_FLAGS := -Wall --cc --exe --build --top-module $(TOP) -Irtl -Mdir $(OBJ_DIR) -o ../npc $(CPP_SRCS) $(RTL_SRCS)
ifeq ($(TRACE),1)
VERILATOR_FLAGS += --trace
endif

.PHONY: all run smoke clean

all: $(BIN)

$(BIN): $(RTL_SRCS) $(CPP_SRCS)
	@mkdir -p $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) -CFLAGS "$(CXXFLAGS)"

run: $(BIN)
	$(BIN) $(ARGS)

smoke: $(BIN)
	@out="$$($(BIN) --max-cycles 8 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=limit cycles=8 pc=0x20000020 halted=0 limit=8' >/dev/null

clean:
	rm -rf $(BUILD_DIR)
