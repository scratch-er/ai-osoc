AM_SRCS := riscv/npc/start.S \
           riscv/ysyxsoc/trm.c \
           platform/dummy/ioe.c \
           platform/dummy/cte.c \
           platform/dummy/vme.c \
           platform/dummy/mpe.c

CFLAGS    += -fdata-sections -ffunction-sections
LDSCRIPTS += $(AM_HOME)/scripts/ysyxsoc-linker.ld
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
NPC_SOC_SIM ?= $(NPC_HOME)/build/soc/npc-soc
NPC_MAX_CYCLES ?= 2000000
NPC_DIFFTEST_REF ?=
NPC_DIFFTEST_ARGS := $(if $(NPC_DIFFTEST_REF),--difftest-ref $(NPC_DIFFTEST_REF),)

run: insert-arg
	@$(MAKE) -s -C $(NPC_HOME) soc
	@$(NPC_SOC_SIM) --image $(IMAGE).bin --reset-pc 0x20000000 --max-cycles $(NPC_MAX_CYCLES) $(NPC_DIFFTEST_ARGS)

.PHONY: insert-arg
