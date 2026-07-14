TOP := NPC
BUILD_DIR := build
OBJ_DIR := $(BUILD_DIR)/obj_dir
BIN := $(BUILD_DIR)/npc
REF_SO ?= ../nemu/build/riscv32-nemu-interpreter-so
VERILATOR ?= verilator
CXXFLAGS += -std=c++17 -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable -Wno-unused-but-set-variable -Wno-sign-compare -O2 -I$(abspath ../nemu/include)

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
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=bad reason=illegal_inst cycles=1 insts=1 pc=0x20000000 halted=1 limit=8 x1=0x00000000 a0=0x00000000 trap=2' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_LAST R=1 C=0 PC=20000000 I=00000000' >/dev/null

test-addi: $(BIN)
	@out="$$($(BIN) --image tests/bin/addi.bin --max-cycles 8 --expect-x1 0x5 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x00000005 expect=0x00000005 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=bad reason=illegal_inst cycles=4 insts=4 pc=0x2000000c halted=1 limit=8 x1=0x00000005 a0=0x00000000 trap=2' >/dev/null

test-jalr-ebreak: $(BIN)
	@out="$$($(BIN) --image tests/bin/jalr-ebreak.bin --reset-pc 0x100 --max-cycles 16 --expect-x1 0x102 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_TRAP code=1' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x00000102 expect=0x00000102 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=5 insts=5 pc=0x00000120 halted=1 limit=16 x1=0x00000102 a0=0x00000000 trap=1' >/dev/null

test-lw-sw: $(BIN)
	@out="$$($(BIN) --image tests/bin/lw-sw.bin --reset-pc 0x100 --max-cycles 16 --expect-x1 0x2a 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_TRAP code=1' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x0000002a expect=0x0000002a PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=5 insts=5 pc=0x00000110 halted=1 limit=16 x1=0x0000002a a0=0x00000000 trap=1' >/dev/null

test-debug: $(BIN)
	@out="$$($(BIN) --image tests/bin/jalr-ebreak.bin --reset-pc 0x100 --max-cycles 2 --expect-x1 0x102 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=limit reason=cycle_limit cycles=2 insts=2 pc=0x00000118 halted=0 limit=2 x1=0x00000100 a0=0x00000000 trap=3' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_LAST R=2 C=1 PC=00000104 I=018082e7' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_REGS .*x1 =0x00000100' >/dev/null; \
	out="$$($(BIN) --image tests/bin/lw-sw.bin --reset-pc 0x100 --max-cycles 16 --expect-x1 0x2a --mem-trace 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_MEM w addr=0x00000140 data=0x0000002a' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=5 insts=5 pc=0x00000110 halted=1 limit=16 x1=0x0000002a a0=0x00000000 trap=1' >/dev/null; \
	out="$$($(BIN) --reset-pc 0x100 --max-cycles 16 -e 'load tests/bin/jalr-ebreak.bin 0x100; reset; run 2; dump state; last 2; exit' 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_STATE pc=0x00000118 cycles=2 retired=2 halted=0 trap=0' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_LAST_BEGIN count=2' >/dev/null; \
	out="$$($(BIN) --reset-pc 0x100 --max-cycles 16 -e 'load tests/bin/jalr-ebreak.bin 0x100; break 0x118; reset; run 16; list-breaks; exit' 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_BREAK_HIT pc=0x00000118 insts=2 cycles=2' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=stop reason=breakpoint cycles=2 insts=2 pc=0x00000118 halted=0 limit=16' >/dev/null

test-difftest: $(BIN)
	@out="$$($(BIN) --image tests/bin/auipc-ebreak.bin --reset-pc 0x80000000 --max-cycles 8 --expect-x1 0x80000000 --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_DIFFTEST status=on' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x80000000 expect=0x80000000 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=2 insts=2 pc=0x80000004 halted=1 limit=8 x1=0x80000000 a0=0x00000000 trap=1' >/dev/null; \
	out="$$($(BIN) --image tests/bin/difftest-jalr-ebreak.bin --reset-pc 0x80000000 --max-cycles 16 --expect-x1 0x80000000 --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=4 insts=4 pc=0x80000010 halted=1 limit=16 x1=0x80000000 a0=0x00000000 trap=1' >/dev/null; \
	out="$$($(BIN) --image tests/bin/difftest-lw-sw.bin --reset-pc 0x80000000 --max-cycles 16 --expect-x1 0x2a --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=5 insts=5 pc=0x80000010 halted=1 limit=16 x1=0x0000002a a0=0x00000000 trap=1' >/dev/null

clean:
	rm -rf $(BUILD_DIR)
