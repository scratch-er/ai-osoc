TOP := NPC
BUILD_DIR := build
OBJ_DIR := $(BUILD_DIR)/obj_dir
BIN := $(BUILD_DIR)/npc
REF_SO ?= ../nemu/build/riscv32-nemu-interpreter-so
VERILATOR ?= verilator
NPC_DEBUG ?= 1
RESET_PC ?= 0x20000000
CXXFLAGS += -std=c++17 -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable -Wno-unused-but-set-variable -Wno-sign-compare -O2 -I$(abspath ../nemu/include) -DNPC_DEBUG=$(NPC_DEBUG)

RTL_SRCS := $(shell find rtl -name '*.v' | sort)
STA_RTL_SRCS := \
	$(abspath rtl/NPC.v) \
	$(abspath rtl/core/Core.v) \
	$(abspath rtl/core/Ifu.v) \
	$(abspath rtl/bus/AxiMaster.v) \
	$(abspath rtl/bus/AxiArbiter.v) \
	$(abspath rtl/core/Lsu.v) \
	$(abspath rtl/core/Csr.v) \
	$(abspath rtl/core/Idu.v) \
	$(abspath rtl/core/Exu.v) \
	$(abspath rtl/core/RegFile.v) \
	$(abspath rtl/core/Wbu.v) \
	$(abspath rtl/core/Clint.v)
YOSYS_STA_DIR ?= ../yosys-sta
STA_PDK ?= icsprout55
CLK_FREQ_MHZ ?= 100
STA_O ?= ../build/p8-s2-ppa/npc-sta
STA_FREQS ?= 100 300 500 530 540 550 560 600 700
STA_LOG_DIR ?= ../build/p8-s2-ppa
CPP_SRCS := csrc/main.cpp csrc/memory.cpp csrc/dpi.cpp
TRACE ?= 0

# ysyxSoC simulation flavor (P9): sim top is ysyxSoCTop, the core runs in
# NPC_DEBUG=0 spec-port mode (no NPC_LOCAL_AXI) and is instantiated by the
# generated SoC. Requires ysyxSoC/build/ysyxSoCFull.v (see notes/next.md).
SOC_DIR ?= ../ysyxSoC
SOC_BUILD_DIR := $(BUILD_DIR)/soc
SOC_OBJ_DIR := $(SOC_BUILD_DIR)/obj_dir
SOC_BIN := $(SOC_BUILD_DIR)/npc-soc
SOC_GEN_V := $(SOC_DIR)/build/ysyxSoCFull.v
SOC_V := $(SOC_BUILD_DIR)/ysyxSoCFull.v
SOC_PERIP_SRCS := $(shell find $(SOC_DIR)/perip -name '*.v' | sort)
SOC_RTL_SRCS := $(filter-out rtl/bus/LocalAxiSlave.v rtl/bus/MemIf.v,$(RTL_SRCS))
SOC_CXXFLAGS += -std=c++17 -O2 -Wall -Wextra -Wno-unused-parameter -I$(abspath ../nemu/include)
SOC_LDFLAGS += -ldl
SOC_VERILATOR_FLAGS := --cc --exe --build --top-module ysyxSoCTop \
	--timescale "1ns/1ns" --no-timing -Wno-fatal --autoflush \
	+define+NPC_DEBUG=1 \
	-Irtl -I$(SOC_DIR)/perip/uart16550/rtl -I$(SOC_DIR)/perip/spi/rtl \
	-Mdir $(SOC_OBJ_DIR) -o ../npc-soc \
	csrc/soc_main.cpp csrc/difftest.cpp csrc/memory.cpp $(SOC_V) $(SOC_PERIP_SRCS) $(SOC_RTL_SRCS)
ifeq ($(TRACE),1)
SOC_VERILATOR_FLAGS += --trace
endif

ifeq ($(NPC_DEBUG),1)
CPP_SRCS += csrc/difftest.cpp
VERILATOR_DEBUG_FLAG := +define+NPC_DEBUG
endif
VERILATOR_FLAGS := -Wall --cc --exe --build --top-module $(TOP) -GLOCAL_AXI=1 -GRESET_PC=$(RESET_PC) -Irtl -Mdir $(OBJ_DIR) -o ../npc +define+NPC_LOCAL_AXI $(VERILATOR_DEBUG_FLAG) $(CPP_SRCS) $(RTL_SRCS)
ifeq ($(TRACE),1)
VERILATOR_FLAGS += --trace
endif

.PHONY: all run sta sta-sweep smoke spec-smoke soc soc-smoke test-soc-difftest test-soc-mem test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-axi-local test-mem-latency test-access-fault test-rv32e-illegal test-csr-trap test-debug test-difftest test-clint test-icache test-fencei clean

all: $(BIN)

sta:
	VERILOG_INCLUDE_DIRS=$(abspath rtl) $(MAKE) -C $(YOSYS_STA_DIR) syn sta \
		DESIGN=$(TOP) PDK=$(STA_PDK) O=$(abspath $(STA_O)) \
		CLK_PORT_NAME=clock CLK_FREQ_MHZ=$(CLK_FREQ_MHZ) \
		RTL_FILES="$(STA_RTL_SRCS)"

sta-sweep:
	@mkdir -p $(STA_LOG_DIR)
	@set -e; \
	for f in $(STA_FREQS); do \
		echo "== STA $$f MHz =="; \
		$(MAKE) sta CLK_FREQ_MHZ=$$f > $(STA_LOG_DIR)/npc-sta-$$f.make.log 2>&1; \
	done

$(BIN): $(RTL_SRCS) $(CPP_SRCS)
	@mkdir -p $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) -CFLAGS "$(CXXFLAGS)"

run: $(BIN)
	$(BIN) $(ARGS)

$(SOC_V): $(SOC_GEN_V)
	@mkdir -p $(SOC_BUILD_DIR)
	sed 's/ysyx_00000000/NPC/g' $< > $@

$(SOC_BIN): $(SOC_V) $(SOC_RTL_SRCS) csrc/soc_main.cpp csrc/difftest.cpp
	$(VERILATOR) $(SOC_VERILATOR_FLAGS) -CFLAGS "$(SOC_CXXFLAGS)" -LDFLAGS "$(SOC_LDFLAGS)"

soc: $(SOC_BIN)

soc-smoke: $(SOC_BIN)
	@mkdir -p $(SOC_BUILD_DIR)/tests
	@python3 tests/make-soc-uart-bin.py $(SOC_BUILD_DIR)/tests/soc-uart.bin
	@out="$$($(SOC_BIN) --image $(SOC_BUILD_DIR)/tests/soc-uart.bin --max-cycles 2000 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'SOC' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=limit reason=cycle_limit' >/dev/null

test-soc-difftest: $(SOC_BIN)
	@mkdir -p $(SOC_BUILD_DIR)/tests
	@python3 tests/make-icache-bin.py $(SOC_BUILD_DIR)/tests/soc-icache.bin
	@out="$$($(SOC_BIN) --image $(SOC_BUILD_DIR)/tests/soc-icache.bin --reset-pc 0x20000000 --max-cycles 2000 --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_DIFFTEST status=on' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_ICACHE .*misses=[1-9]' >/dev/null

test-soc-mem: $(SOC_BIN)
	@mkdir -p $(SOC_BUILD_DIR)/tests
	@python3 tests/make-soc-mem-bin.py $(SOC_BUILD_DIR)/tests/soc-mem.bin
	@out="$$($(SOC_BIN) --image $(SOC_BUILD_DIR)/tests/soc-mem.bin --reset-pc 0x20000000 --max-cycles 500000 --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_DIFFTEST status=on' >/dev/null; \
	printf '%s\n' "$$out" | grep 'PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap' >/dev/null

spec-smoke: $(BIN)
	@mkdir -p $(BUILD_DIR)/tests
	@python3 tests/make-spec-uart-bin.py $(BUILD_DIR)/tests/spec-uart.bin
	@out="$$($(BIN) --image $(BUILD_DIR)/tests/spec-uart.bin --max-cycles 400 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'SPEC' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=uart_eot' >/dev/null

smoke: $(BIN)
	@out="$$($(BIN) --max-cycles 12 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=bad reason=illegal_inst' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_LAST R=1 .*PC=20000000 I=00000000' >/dev/null

test-addi: $(BIN)
	@out="$$($(BIN) --image tests/bin/addi.bin --max-cycles 24 --expect-x1 0x5 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x00000005 expect=0x00000005 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=bad reason=illegal_inst .*x1=0x00000005' >/dev/null

test-jalr-ebreak: $(BIN)
	@out="$$($(BIN) --image tests/bin/jalr-ebreak.bin --reset-pc 0x100 --max-cycles 32 --expect-x1 0x102 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_TRAP code=1' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x00000102 expect=0x00000102 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap .*x1=0x00000102' >/dev/null

test-lw-sw: $(BIN)
	@out="$$($(BIN) --image tests/bin/lw-sw.bin --reset-pc 0x100 --max-cycles 40 --expect-x1 0x2a 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_TRAP code=1' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x0000002a expect=0x0000002a PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap .*x1=0x0000002a' >/dev/null

test-alu: $(BIN)
	@out="$$($(BIN) --image tests/bin/alu.bin --reset-pc 0x100 --max-cycles 96 --expect-x1 0x12345678 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_TRAP code=1' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x12345678 expect=0x12345678 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap .*x1=0x12345678' >/dev/null

test-axi-local: $(BIN)
	@out="$$($(BIN) --image tests/bin/lw-sw.bin --reset-pc 0x100 --max-cycles 40 --expect-x1 0x2a --mem-trace 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_MEM w addr=0x00000140 data=0x0000002a mask=0xf' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_MEM r addr=0x00000140 data=0x0000002a' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x0000002a expect=0x0000002a PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap .*x1=0x0000002a' >/dev/null

test-mem-latency: test-axi-local

test-access-fault: $(BIN)
	@out="$$($(BIN) --image tests/bin/inst-access-fault.bin --reset-pc 0x80000000 --max-cycles 64 --expect-x1 0x1 --difftest-ref $(REF_SO) --dump-trace 2>&1)"; \
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
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap .*x1=0xffff7f01' >/dev/null; \
	out="$$($(BIN) --image tests/bin/load-misaligned.bin --reset-pc 0x100 --max-cycles 16 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'PC=00000104 I=00111083 .*EXC=1 CAUSE=4' >/dev/null; \
	out="$$($(BIN) --image tests/bin/store-misaligned.bin --reset-pc 0x100 --max-cycles 16 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'PC=00000104 I=00012123 .*EXC=1 CAUSE=6' >/dev/null; \
	out="$$($(BIN) --image tests/bin/branch-misaligned.bin --reset-pc 0x100 --max-cycles 8 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'PC=00000100 I=00000163 .*EXC=1 CAUSE=0' >/dev/null


test-csr-trap: $(BIN)
	@out="$$($(BIN) --image tests/bin/csr-basic.bin --reset-pc 0x100 --max-cycles 64 --expect-x1 0x14c 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap .*x1=0x0000014c' >/dev/null; \
	out="$$($(BIN) --image tests/bin/ecall-trap.bin --reset-pc 0x100 --max-cycles 64 --expect-x1 0x117 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_CSR mstatus=0x00001800 mtvec=0x00000000 mepc=0x0000010c mcause=0x0000000b' >/dev/null; \
	out="$$($(BIN) --image tests/bin/illegal-mret.bin --reset-pc 0x100 --max-cycles 64 --expect-x1 0x55 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_CSR mstatus=0x00001800 mtvec=0x00000000 mepc=0x00000110 mcause=0x00000002' >/dev/null; \
	out="$$($(BIN) --image tests/bin/sys-nop.bin --reset-pc 0x100 --max-cycles 32 --expect-x1 0x7 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap .*x1=0x00000007' >/dev/null; \
	out="$$($(BIN) --image tests/bin/csr-readonly-illegal.bin --reset-pc 0x100 --max-cycles 8 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'PC=00000100 I=f1101073 .*EXC=1 CAUSE=2' >/dev/null


test-rv32e-illegal: $(BIN)
	@out="$$($(BIN) --image tests/bin/rv32e-illegal.bin --reset-pc 0x100 --max-cycles 8 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=bad reason=illegal_inst' >/dev/null; \
	printf '%s\n' "$$out" | grep 'PC=00000100 I=00100813 .*EXC=1 CAUSE=2' >/dev/null

test-debug: $(BIN)
	@out="$$($(BIN) --image tests/bin/jalr-ebreak.bin --reset-pc 0x100 --max-cycles 8 --expect-x1 0x102 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=limit reason=cycle_limit .*x1=0x00000100' >/dev/null; \
	printf '%s\n' "$$out" | grep 'PC=00000104 I=018082e7' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_REGS .*x1 =0x00000100' >/dev/null; \
	out="$$($(BIN) --image tests/bin/lw-sw.bin --reset-pc 0x100 --max-cycles 40 --expect-x1 0x2a --mem-trace 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_MEM w addr=0x00000140 data=0x0000002a' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap .*x1=0x0000002a' >/dev/null; \
	out="$$($(BIN) --reset-pc 0x100 --max-cycles 32 -e 'load tests/bin/jalr-ebreak.bin 0x100; reset; run 8; dump state; last 2; exit' 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_STATE pc=0x00000118 .*retired=2 halted=0 trap=0' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_LAST_BEGIN count=2' >/dev/null; \
	out="$$($(BIN) --reset-pc 0x100 --max-cycles 32 -e 'load tests/bin/jalr-ebreak.bin 0x100; break 0x118; reset; run 32; list-breaks; exit' 2>&1 || true)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_BREAK_HIT pc=0x00000118 insts=2' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=stop reason=breakpoint .*insts=2 pc=0x00000118 halted=0' >/dev/null

test-difftest: $(BIN)
	@out="$$($(BIN) --image tests/bin/auipc-ebreak.bin --reset-pc 0x80000000 --max-cycles 16 --expect-x1 0x80000000 --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_DIFFTEST status=on' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x80000000 expect=0x80000000 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap .*x1=0x80000000' >/dev/null; \
	out="$$($(BIN) --image tests/bin/difftest-jalr-ebreak.bin --reset-pc 0x80000000 --max-cycles 24 --expect-x1 0x80000000 --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap .*x1=0x80000000' >/dev/null; \
	out="$$($(BIN) --image tests/bin/difftest-lw-sw.bin --reset-pc 0x80000000 --max-cycles 40 --expect-x1 0x2a --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap .*x1=0x0000002a' >/dev/null; \
	out="$$($(BIN) --image tests/bin/difftest-alu.bin --reset-pc 0x80000000 --max-cycles 96 --expect-x1 0x12345678 --difftest-ref $(REF_SO) 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap .*x1=0x12345678' >/dev/null


test-icache: $(BIN)
	@mkdir -p $(BUILD_DIR)/tests
	@python3 tests/make-icache-bin.py $(BUILD_DIR)/tests/icache.bin
	@out="$$($(BIN) --image $(BUILD_DIR)/tests/icache.bin --reset-pc 0x20000000 --max-cycles 160 --expect-x1 0x8 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x00000008 expect=0x00000008 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_ICACHE .*hits=[1-9]' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_ICACHE .*misses=[1-9]' >/dev/null

test-fencei: $(BIN)
	@mkdir -p $(BUILD_DIR)/tests
	@python3 tests/make-fencei-bin.py $(BUILD_DIR)/tests/fencei.bin
	@out="$$($(BIN) --image $(BUILD_DIR)/tests/fencei.bin --reset-pc 0x80000000 --max-cycles 160 --expect-x1 0x1 2>&1)"; \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep 'NPC_CHECK x1=0x00000001 expect=0x00000001 PASS' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_RESULT status=good reason=good_trap' >/dev/null; \
	printf '%s\n' "$$out" | grep 'NPC_ICACHE .*misses=[2-9]' >/dev/null

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
