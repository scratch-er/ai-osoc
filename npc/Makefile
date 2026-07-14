TOP := NPC
BUILD_DIR := build
OBJ_DIR := $(BUILD_DIR)/obj_dir
BIN := $(BUILD_DIR)/npc
REF_SO ?= ../nemu/build/riscv32-nemu-interpreter-so
VERILATOR ?= verilator
CXXFLAGS += -std=c++17 -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable -Wno-unused-but-set-variable -Wno-sign-compare -O2

RTL_SRCS := $(shell find rtl -name '*.v' | sort)
CPP_SRCS := csrc/main.cpp csrc/memory.cpp csrc/dpi.cpp csrc/difftest.cpp
TRACE ?= 0

VERILATOR_FLAGS := -Wall --cc --exe --build --top-module $(TOP) -Irtl -Mdir $(OBJ_DIR) -o ../npc $(CPP_SRCS) $(RTL_SRCS)
ifeq ($(TRACE),1)
VERILATOR_FLAGS += --trace
endif

.PHONY: all run smoke test-addi test-jalr-ebreak test-lw-sw test-debug test-difftest clean

all: $(BIN)

$(BIN): $(RTL_SRCS) $(CPP_SRCS)
	@mkdir -p $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) -CFLAGS "$(CXXFLAGS)"

run: $(BIN)
	$(BIN) $(ARGS)

smoke: $(BIN)
	@out="$$($(BIN) --max-cycles 8 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=bad cycles=1 pc=0x20000000 halted=1 limit=8 x1=0x00000000 a0=0x00000000 trap=2' >/dev/null

test-addi: $(BIN)
	@out="$$($(BIN) --image tests/bin/addi.bin --max-cycles 8 --expect-x1 0x5 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x00000005 expect=0x00000005 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=bad cycles=4 pc=0x2000000c halted=1 limit=8 x1=0x00000005 a0=0x00000000 trap=2' >/dev/null

test-jalr-ebreak: $(BIN)
	@out="$$($(BIN) --image tests/bin/jalr-ebreak.bin --reset-pc 0x100 --max-cycles 16 --expect-x1 0x102 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_TRAP code=1' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x00000102 expect=0x00000102 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good cycles=5 pc=0x00000120 halted=1 limit=16 x1=0x00000102 a0=0x00000000 trap=1' >/dev/null

test-lw-sw: $(BIN)
	@out="$$($(BIN) --image tests/bin/lw-sw.bin --reset-pc 0x100 --max-cycles 16 --expect-x1 0x2a 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_TRAP code=1' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x0000002a expect=0x0000002a PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good cycles=5 pc=0x00000110 halted=1 limit=16 x1=0x0000002a a0=0x00000000 trap=1' >/dev/null

test-debug: $(BIN)
	@out="$$($(BIN) --image tests/bin/jalr-ebreak.bin --reset-pc 0x100 --max-cycles 2 --expect-x1 0x102 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=limit cycles=2 pc=0x00000118 halted=0 limit=2 x1=0x00000100 a0=0x00000000 trap=3' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_TRACE cycle=1 pc=0x00000104 inst=0x018082e7' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_REGS .*x1 =0x00000100' >/dev/null; \
	out="$$($(BIN) --image tests/bin/lw-sw.bin --reset-pc 0x100 --max-cycles 16 --expect-x1 0x2a --mem-trace 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_MEM w addr=0x00000140 data=0x0000002a' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good cycles=5 pc=0x00000110 halted=1 limit=16 x1=0x0000002a a0=0x00000000 trap=1' >/dev/null

test-difftest: $(BIN)
	@out="$$($(BIN) --image tests/bin/auipc-ebreak.bin --reset-pc 0x80000000 --max-cycles 8 --expect-x1 0x80000000 --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_DIFFTEST status=on' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x80000000 expect=0x80000000 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good cycles=2 pc=0x80000004 halted=1 limit=8 x1=0x80000000 a0=0x00000000 trap=1' >/dev/null; \
	out="$$($(BIN) --image tests/bin/difftest-jalr-ebreak.bin --reset-pc 0x80000000 --max-cycles 16 --expect-x1 0x80000000 --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good cycles=4 pc=0x80000010 halted=1 limit=16 x1=0x80000000 a0=0x00000000 trap=1' >/dev/null; \
	out="$$($(BIN) --image tests/bin/difftest-lw-sw.bin --reset-pc 0x80000000 --max-cycles 16 --expect-x1 0x2a --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good cycles=5 pc=0x80000010 halted=1 limit=16 x1=0x0000002a a0=0x00000000 trap=1' >/dev/null

clean:
	rm -rf $(BUILD_DIR)
