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

VERILATOR_FLAGS := -Wall --cc --exe --build --top-module $(TOP) -GLOCAL_AXI=1 -Irtl -Mdir $(OBJ_DIR) -o ../npc $(CPP_SRCS) $(RTL_SRCS)
ifeq ($(TRACE),1)
VERILATOR_FLAGS += --trace
endif

.PHONY: all run smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-axi-local test-mem-latency test-access-fault test-rv32e-illegal test-csr-trap test-debug test-difftest test-clint clean

all: $(BIN)

$(BIN): $(RTL_SRCS) $(CPP_SRCS)
	@mkdir -p $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) -CFLAGS "$(CXXFLAGS)"

run: $(BIN)
	$(BIN) $(ARGS)

smoke: $(BIN)
	@out="$$($(BIN) --max-cycles 12 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=bad reason=illegal_inst cycles=4 insts=1 pc=0x20000000 halted=1 limit=12 x1=0x00000000 a0=0x00000000 trap=2' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_LAST R=1 C=3 PC=20000000 I=00000000' >/dev/null

test-addi: $(BIN)
	@out="$$($(BIN) --image tests/bin/addi.bin --max-cycles 24 --expect-x1 0x5 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x00000005 expect=0x00000005 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=bad reason=illegal_inst cycles=16 insts=4 pc=0x2000000c halted=1 limit=24 x1=0x00000005 a0=0x00000000 trap=2' >/dev/null

test-jalr-ebreak: $(BIN)
	@out="$$($(BIN) --image tests/bin/jalr-ebreak.bin --reset-pc 0x100 --max-cycles 32 --expect-x1 0x102 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_TRAP code=1' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x00000102 expect=0x00000102 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=20 insts=5 pc=0x00000120 halted=1 limit=32 x1=0x00000102 a0=0x00000000 trap=1' >/dev/null

test-lw-sw: $(BIN)
	@out="$$($(BIN) --image tests/bin/lw-sw.bin --reset-pc 0x100 --max-cycles 40 --expect-x1 0x2a 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_TRAP code=1' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x0000002a expect=0x0000002a PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=24 insts=5 pc=0x00000110 halted=1 limit=40 x1=0x0000002a a0=0x00000000 trap=1' >/dev/null

test-alu: $(BIN)
	@out="$$($(BIN) --image tests/bin/alu.bin --reset-pc 0x100 --max-cycles 96 --expect-x1 0x12345678 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_TRAP code=1' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x12345678 expect=0x12345678 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=84 insts=21 pc=0x00000150 halted=1 limit=96 x1=0x12345678 a0=0x00000000 trap=1' >/dev/null

test-axi-local: $(BIN)
	@out="$$($(BIN) --image tests/bin/lw-sw.bin --reset-pc 0x100 --max-cycles 40 --expect-x1 0x2a --mem-trace 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_MEM w addr=0x00000140 data=0x0000002a mask=0xf' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_MEM r addr=0x00000140 data=0x0000002a' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x0000002a expect=0x0000002a PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=24 insts=5 pc=0x00000110 halted=1 limit=40 x1=0x0000002a a0=0x00000000 trap=1' >/dev/null

test-mem-latency: test-axi-local

test-access-fault: $(BIN)
	@out="$$($(BIN) --image tests/bin/inst-access-fault.bin --reset-pc 0x80000000 --max-cycles 40 --expect-x1 0x1 --difftest-ref $(REF_SO) --dump-trace 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'CAUSE=1' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap' >/dev/null; \
	out="$$($(BIN) --image tests/bin/load-access-fault.bin --reset-pc 0x80000000 --max-cycles 40 --expect-x1 0x5 --difftest-ref $(REF_SO) --dump-trace 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'CAUSE=5' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap' >/dev/null; \
	out="$$($(BIN) --image tests/bin/store-access-fault.bin --reset-pc 0x80000000 --max-cycles 40 --expect-x1 0x7 --difftest-ref $(REF_SO) --dump-trace 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'CAUSE=7' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap' >/dev/null

test-mem-size: $(BIN)
	@out="$$($(BIN) --image tests/bin/byte-half-memory.bin --reset-pc 0x100 --max-cycles 128 --expect-x1 0xffff7f01 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=78 insts=16 pc=0x0000013c halted=1 limit=128 x1=0xffff7f01 a0=0x00000000 trap=1' >/dev/null; \
	out="$$($(BIN) --image tests/bin/load-misaligned.bin --reset-pc 0x100 --max-cycles 16 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_LAST R=2 C=7 PC=00000104 I=00111083 RD=0 RV=00000000 NPC=00000104 EXC=1 CAUSE=4' >/dev/null; \
	out="$$($(BIN) --image tests/bin/store-misaligned.bin --reset-pc 0x100 --max-cycles 16 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_LAST R=2 C=7 PC=00000104 I=00012123 RD=0 RV=00000000 NPC=00000104 EXC=1 CAUSE=6' >/dev/null; \
	out="$$($(BIN) --image tests/bin/branch-misaligned.bin --reset-pc 0x100 --max-cycles 8 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_LAST R=1 C=3 PC=00000100 I=00000163 RD=0 RV=00000000 NPC=00000100 EXC=1 CAUSE=0' >/dev/null


test-csr-trap: $(BIN)
	@out="$$($(BIN) --image tests/bin/csr-basic.bin --reset-pc 0x100 --max-cycles 64 --expect-x1 0x14c 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=52 insts=13 pc=0x00000130 halted=1 limit=64 x1=0x0000014c a0=0x00000000 trap=1' >/dev/null; \
	out="$$($(BIN) --image tests/bin/ecall-trap.bin --reset-pc 0x100 --max-cycles 64 --expect-x1 0x117 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_CSR mstatus=0x00001800 mtvec=0x00000000 mepc=0x0000010c mcause=0x0000000b' >/dev/null; \
	out="$$($(BIN) --image tests/bin/illegal-mret.bin --reset-pc 0x100 --max-cycles 64 --expect-x1 0x55 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_CSR mstatus=0x00001800 mtvec=0x00000000 mepc=0x00000110 mcause=0x00000002' >/dev/null; \
	out="$$($(BIN) --image tests/bin/sys-nop.bin --reset-pc 0x100 --max-cycles 32 --expect-x1 0x7 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=20 insts=5 pc=0x00000110 halted=1 limit=32 x1=0x00000007 a0=0x00000000 trap=1' >/dev/null; \
	out="$$($(BIN) --image tests/bin/csr-readonly-illegal.bin --reset-pc 0x100 --max-cycles 8 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_LAST R=1 C=3 PC=00000100 I=f1101073 RD=0 RV=00000000 NPC=00000100 EXC=1 CAUSE=2' >/dev/null


test-rv32e-illegal: $(BIN)
	@out="$$($(BIN) --image tests/bin/rv32e-illegal.bin --reset-pc 0x100 --max-cycles 8 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=bad reason=illegal_inst cycles=4 insts=1 pc=0x00000100 halted=1 limit=8 x1=0x00000000 a0=0x00000000 trap=2' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_LAST R=1 C=3 PC=00000100 I=00100813 RD=0 RV=00000000 NPC=00000100 EXC=1 CAUSE=2' >/dev/null

test-debug: $(BIN)
	@out="$$($(BIN) --image tests/bin/jalr-ebreak.bin --reset-pc 0x100 --max-cycles 8 --expect-x1 0x102 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=limit reason=cycle_limit cycles=8 insts=2 pc=0x00000118 halted=0 limit=8 x1=0x00000100 a0=0x00000000 trap=3' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_LAST R=2 C=7 PC=00000104 I=018082e7' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_REGS .*x1 =0x00000100' >/dev/null; \
	out="$$($(BIN) --image tests/bin/lw-sw.bin --reset-pc 0x100 --max-cycles 40 --expect-x1 0x2a --mem-trace 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_MEM w addr=0x00000140 data=0x0000002a' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=24 insts=5 pc=0x00000110 halted=1 limit=40 x1=0x0000002a a0=0x00000000 trap=1' >/dev/null; \
	out="$$($(BIN) --reset-pc 0x100 --max-cycles 32 -e 'load tests/bin/jalr-ebreak.bin 0x100; reset; run 8; dump state; last 2; exit' 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_STATE pc=0x00000118 cycles=8 retired=2 halted=0 trap=0' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_LAST_BEGIN count=2' >/dev/null; \
	out="$$($(BIN) --reset-pc 0x100 --max-cycles 32 -e 'load tests/bin/jalr-ebreak.bin 0x100; break 0x118; reset; run 32; list-breaks; exit' 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_BREAK_HIT pc=0x00000118 insts=2 cycles=8' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=stop reason=breakpoint cycles=8 insts=2 pc=0x00000118 halted=0 limit=32' >/dev/null

test-difftest: $(BIN)
	@out="$$($(BIN) --image tests/bin/auipc-ebreak.bin --reset-pc 0x80000000 --max-cycles 16 --expect-x1 0x80000000 --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_DIFFTEST status=on' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x80000000 expect=0x80000000 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=8 insts=2 pc=0x80000004 halted=1 limit=16 x1=0x80000000 a0=0x00000000 trap=1' >/dev/null; \
	out="$$($(BIN) --image tests/bin/difftest-jalr-ebreak.bin --reset-pc 0x80000000 --max-cycles 24 --expect-x1 0x80000000 --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=16 insts=4 pc=0x80000010 halted=1 limit=24 x1=0x80000000 a0=0x00000000 trap=1' >/dev/null; \
	out="$$($(BIN) --image tests/bin/difftest-lw-sw.bin --reset-pc 0x80000000 --max-cycles 40 --expect-x1 0x2a --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=24 insts=5 pc=0x80000010 halted=1 limit=40 x1=0x0000002a a0=0x00000000 trap=1' >/dev/null; \
	out="$$($(BIN) --image tests/bin/difftest-alu.bin --reset-pc 0x80000000 --max-cycles 96 --expect-x1 0x12345678 --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap cycles=84 insts=21 pc=0x80000050 halted=1 limit=96 x1=0x12345678 a0=0x00000000 trap=1' >/dev/null

test-clint: $(BIN)
	@mkdir -p $(BUILD_DIR)/tests
	@python3 tests/make-clint-bin.py $(BUILD_DIR)/tests/clint.bin
	@out="$$($(BIN) --image $(BUILD_DIR)/tests/clint.bin --reset-pc 0x80000000 --max-cycles 120 --expect-x1 0x1 --difftest-ref $(REF_SO) --mem-trace 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_DIFFTEST status=on' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x00000001 expect=0x00000001 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap' >/dev/null; \
	if printf '%s\n' "$$out" | grep -q 'NPC_MMIO [rw] addr=0x0200'; then exit 1; fi

clean:
	rm -rf $(BUILD_DIR)
