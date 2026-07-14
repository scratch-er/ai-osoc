AM_SRCS := riscv/npc/start.S \
           riscv/npc/trm.c \
           riscv/npc/ioe.c \
           riscv/npc/timer.c \
           riscv/npc/input.c \
           riscv/npc/cte.c \
           riscv/npc/trap.S \
           platform/dummy/vme.c \
           platform/dummy/mpe.c

CFLAGS    += -fdata-sections -ffunction-sections
LDSCRIPTS += $(AM_HOME)/scripts/linker.ld
LDFLAGS   += --defsym=_pmem_start=0x80000000 --defsym=_entry_offset=0x0
LDFLAGS   += --gc-sections -e _start

MAINARGS_MAX_LEN = 64
MAINARGS_PLACEHOLDER = the_insert-arg_rule_in_Makefile_will_insert_mainargs_here
CFLAGS += -DMAINARGS_MAX_LEN=$(MAINARGS_MAX_LEN) -DMAINARGS_PLACEHOLDER=$(MAINARGS_PLACEHOLDER)

PYTHON ?= python3

insert-arg: image
	@$(PYTHON) $(AM_HOME)/tools/insert-arg.py $(IMAGE).bin $(MAINARGS_MAX_LEN) $(MAINARGS_PLACEHOLDER) "$(mainargs)"

image: image-dep
	@$(OBJDUMP) -d $(IMAGE).elf > $(IMAGE).txt
	@echo + OBJCOPY "->" $(IMAGE_REL).bin
	@$(OBJCOPY) -S --set-section-flags .bss=alloc,contents -O binary $(IMAGE).elf $(IMAGE).bin

NPC_HOME ?= $(abspath $(AM_HOME)/../npc)
NPC_SIM ?= $(NPC_HOME)/build/npc
NPC_RESET_PC ?= 0x80000000
NPC_MAX_CYCLES ?= 100000
NPC_DIFFTEST_REF ?=
NPC_DIFFTEST_ARGS := $(if $(NPC_DIFFTEST_REF),--difftest-ref $(NPC_DIFFTEST_REF),)

run: insert-arg
	@$(MAKE) -s -C $(NPC_HOME)
	@$(NPC_SIM) --image $(IMAGE).bin --reset-pc $(NPC_RESET_PC) --max-cycles $(NPC_MAX_CYCLES) $(NPC_DIFFTEST_ARGS)

.PHONY: insert-arg
