# NPC

Initial Verilog NPC project for the RV32E_Zicsr core.

Current status: Phase 8 has started through `P8-S1: Guard debug ports and add a spec-interface simulation harness`. The RTL fetches instructions through a 32-byte direct-mapped flip-flop instruction cache with 16-byte AXI burst refill and `fence.i` invalidation. It executes RV32E `lui`, `auipc`, `jal`, `jalr`, B-type branches with target-alignment checks, `lb`/`lh`/`lw`/`lbu`/`lhu`, `sb`/`sh`/`sw`, the RV32E integer ALU/compare/shift subset, Zicsr for the required M-mode CSRs, `ecall`, architectural `ebreak`, `mret`, `wfi`, `fence`, and `fence.i`. It keeps `x0` immutable, implements precise trap entry when `mtvec` is nonzero, preserves the test-harness `ebreak` GOOD/BAD termination convention when `mtvec == 0`, emits committed UART writes to MMIO address `0x10000000` in debug mode, and implements a physical LSU-side CLINT `mtime`/`mtimeh` block at `0x0200bff8`/`0x0200bffc` that advances once per core clock.

The default `NPC_DEBUG=1` Verilator harness centers debugging around retired-instruction `CommitEvent`s. It has a scriptable command shell, bounded `last [n]` history, stable `NPC_RESULT`/`NPC_CSR`/`NPC_ICACHE` lines, and event-sequence DiffTest against the NEMU REF shared object when the REF exports `difftest_step_event()`. Building with `NPC_DEBUG=0` hides `io_reset_pc`, `debug_*`, and `commit_*` from the top-level interface and reuses the local AXI/DPI memory path for a spec-interface smoke that prints UART writes without using debug ports.

## Commands

Build the default debug/DiffTest simulator:

```sh
make -C npc
```

Build and run the spec-interface UART smoke without top-level debug ports:

```sh
make -C npc clean
make -C npc NPC_DEBUG=0 spec-smoke
```

Run a larger AM image in spec mode by building with the image reset PC and using `--uart-expect` as a UART-output stop condition:

```sh
make -C npc clean
make -C npc NPC_DEBUG=0 RESET_PC=0x80000000
npc/build/npc --image path/to/workload.bin --reset-pc 0x80000000 \
  --max-cycles 12000000 --uart-expect "msh />"
```

Run the current directed regression set:

```sh
make -C npc smoke
make -C npc test-addi
make -C npc test-jalr-ebreak
make -C npc test-lw-sw
make -C npc test-alu
make -C npc test-mem-size
make -C npc test-rv32e-illegal
make -C npc test-csr-trap
make -C npc test-debug
make -C npc test-difftest
make -C npc test-clint
make -C npc test-icache
make -C npc test-fencei
make -C npc test-access-fault
```

Or all current directed checks:

```sh
make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest test-clint test-icache test-fencei test-access-fault
```

Run with an optional image, reset PC, cycle limit, optional x1 check, and optional DiffTest REF:

```sh
make -C npc run ARGS="--image path/to/image.bin --reset-pc 0x80000000 --max-cycles 100 --expect-x1 0x5 --difftest-ref ../nemu/build/riscv32-nemu-interpreter-so"
```

Run the minimal AM `dummy` workload through `ARCH=riscv32e-npc`:

```sh
make -f /tmp/am-dummy.mk ARCH=riscv32e-npc \
  AM_HOME=/path/to/abstract-machine CROSS_COMPILE=riscv64-elf- run
```

Run AM `hello` through the committed UART MMIO path and optional NEMU event DiffTest:

```sh
make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
  AM_HOME=/path/to/abstract-machine CROSS_COMPILE=riscv64-elf- \
  NPC_MAX_CYCLES=2000000 \
  NPC_DIFFTEST_REF=/path/to/nemu/build/riscv32-nemu-interpreter-so run
```

Run the bounded AM timer/devscan smoke through the physical CLINT timer:

```sh
make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
  AM_HOME=/path/to/abstract-machine CROSS_COMPILE=riscv64-elf- \
  NPC_MAX_CYCLES=80000000 mainargs=d run
```

Run RT-Thread through NPC with NEMU event DiffTest:

```sh
make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
  AM_HOME=/path/to/abstract-machine CROSS_COMPILE=riscv64-elf- \
  NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/path/to/nemu/build/riscv32-nemu-interpreter-so run
```

`abstract-machine/scripts/platform/npc.mk` builds `npc/build/npc` automatically and runs it with `--reset-pc 0x80000000`. Override `NPC_HOME`, `NPC_SIM`, `NPC_RESET_PC`, `NPC_MAX_CYCLES`, or `NPC_DIFFTEST_REF` if needed.

## Instruction-cache counters

Every simulator run prints one `NPC_ICACHE` line after `NPC_RESULT` and `NPC_CSR`:

```text
NPC_ICACHE accesses=465 hits=297 misses=168 miss_wait_cycles=1008 refill_beats=672 hit_rate_x1000=638 amat_x1000=3167
```

Use `hit_rate_x1000` for the cache hit rate. Divide it by 10 to get a percentage, or compute `hits / accesses * 100` directly. For the example above, `638` means `63.8%`.

For an AM workload, capture the line with `grep`:

```sh
make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
  AM_HOME=/path/to/abstract-machine CROSS_COMPILE=riscv64-elf- \
  NPC_MAX_CYCLES=2000000 \
  NPC_DIFFTEST_REF=/path/to/nemu/build/riscv32-nemu-interpreter-so run \
  2>&1 | tee /tmp/npc-hello.log | grep 'NPC_ICACHE'
```

For a direct NPC image:

```sh
make -C npc run ARGS="--image path/to/image.bin --reset-pc 0x80000000 --max-cycles 1000000" \
  2>&1 | tee /tmp/npc-image.log | grep 'NPC_ICACHE'
```

Counter meanings:

- `accesses`: accepted IFU fetch requests.
- `hits`: fetch requests served by a valid matching icache line.
- `misses`: fetch requests that trigger a line refill.
- `miss_wait_cycles`: cycles spent waiting for refill completion.
- `refill_beats`: AXI read data beats returned during refill; for successful local-memory refills this should be `misses * 4` because each line is 16 bytes / 4 instructions.
- `hit_rate_x1000`: integer `hits * 1000 / accesses`.
- `amat_x1000`: integer `(accesses + miss_wait_cycles) * 1000 / accesses`, in cycles scaled by 1000.

Use these counters as performance diagnostics. Exact `NPC_RESULT cycles=...` values can change when the cache implementation changes; semantic status, DiffTest status, architectural checks, and counter consistency are the stable regression signals.

## Scriptable Shell

The simulator accepts one-shot command scripts:

```sh
npc/build/npc --reset-pc 0x100 --max-cycles 16 \
  -e 'load npc/tests/bin/jalr-ebreak.bin 0x100; reset; run 2; dump state; last 2; exit'
```

Supported commands in the first slice:

- `load <file> [addr]` / `load_bin <file> [addr]`
- `reset`
- `step [n]`
- `run [n]`
- `run to <addr>`
- `run until reg <i> <value>`
- `print pc`
- `print reg [i]`
- `print mem <addr> <size>`
- `dump state`
- `last [n]`
- `break <addr>`
- `delete-break <addr>`
- `clear-breaks`
- `list-breaks`
- `log <level>`: level 1 streams commit events as `NPC_TRACE`
- `trace on` / `trace off`: stream commit events independent of log level
- `exit` / `quit`

## Output Format

The simulator prints stable result lines of the form:

```text
NPC_RESULT status=... reason=... cycles=... insts=... pc=... halted=... limit=... x1=... a0=... trap=...
NPC_CSR mstatus=... mtvec=... mepc=... mcause=...
```

Failure runs and explicit `last [n]` commands print bounded recent CommitEvents:

```text
NPC_LAST_BEGIN count=2
NPC_LAST R=1 C=0 PC=00000100 I=10000093 RD=1 RV=00000100 NPC=00000104 EXC=0 CAUSE=0
NPC_LAST R=2 C=1 PC=00000104 I=018082e7 RD=5 RV=00000108 NPC=00000118 EXC=0 CAUSE=0
NPC_LAST_END
```

With DiffTest enabled, NPC prefers NEMU's event API:

```text
NPC_DIFFTEST status=on ref=../nemu/build/riscv32-nemu-interpreter-so base=0x80000000 size=16777216 event_api=1
```

On a mismatch it reports the first differing CommitEvent field, the REF/DUT event lines, REF recent history if available, and the normal NPC bounded history/register dump.

## ysyxSoC simulation flavor

The `soc` build flavor simulates the core inside the generated ysyxSoC (`ysyxSoCTop`). It requires the elaborated SoC Verilog at `ysyxSoC/build/ysyxSoCFull.v` (see `notes/next.md` for the elaboration commands); the build copies it to `npc/build/soc/ysyxSoCFull.v` and renames the `ysyx_00000000` CPU black box to `NPC`. The tracked `ysyxSoC.patch` routes `io_reset_pc`, debug registers, commit events, memory retire metadata, and icache counters to the SoC top for precise `ebreak` termination and event DiffTest. Do not commit inside the `ysyxSoC` submodule; regenerate the patch with `git -C ysyxSoC diff > ../ysyxSoC.patch`.

Build and run the MROM/UART smoke (a tiny MROM program prints `SOC` through the UART16550, validating both MROM fetch with icache burst refill and the AXI-to-APB MMIO store path):

```sh
make -C npc soc-smoke
```

Run the SoC icache/DiffTest smoke and the lecture-note-style SRAM memory test:

```sh
make -C npc test-soc-difftest REF_SO=/path/to/nemu/build/riscv32-nemu-interpreter-so
make -C npc test-soc-mem REF_SO=/path/to/nemu/build/riscv32-nemu-interpreter-so
```

`test-soc-mem` boots from MROM at `0x20000000`, verifies the 8KB SRAM window at `0x0f000000..0x0f001fff` with word fill/readback, byte/halfword `wstrb`, narrow loads/stores, read-after-write checks, and sign-extension checks, prints `PASS`, and terminates with a good trap under DiffTest.

Run AM `dummy`/`hello` on the SoC through the `riscv32e-ysyxsoc` platform:

```sh
make -C am-kernels/kernels/hello ARCH=riscv32e-ysyxsoc \
  AM_HOME=/path/to/abstract-machine CROSS_COMPILE=riscv64-elf- \
  NPC_DIFFTEST_REF=/path/to/nemu/build/riscv32-nemu-interpreter-so run
```

The SoC harness (`npc/csrc/soc_main.cpp`) provides the `mrom_read()` DPI (image loaded at `0x20000000`) and an `assert(0)` `flash_read()` stub, and supports `--image`, `--reset-pc`, `--max-cycles`, `--difftest-ref`, and `--wave` (build with `TRACE=1`). The SoC build passes `--autoflush` so the UART16550's single-character `$write` output is flushed immediately instead of sitting in the stdio buffer (important if the sim is killed or stops on an RTL `$fatal` before exit). Note: ysyxSoC delays the CPU reset through a 10-stage `SynchronizerShiftReg`, so the harness holds reset for 20 cycles; a shorter reset re-appears as a spurious mid-run reset pulse.

For AXI-level debugging, building the SoC flavor with `+define+NPC_TRACE_AXI` (add to `SOC_VERILATOR_FLAGS`) enables `$display` probes in `rtl/bus/AxiMaster.v` that log every AR/R/W/B channel event.

## Waveforms

Waveform generation is still available when building with Verilator tracing:

```sh
make -C npc TRACE=1 run ARGS="--wave --max-cycles 8"
```

For the SoC flavor:

```sh
make -C npc TRACE=1 soc
npc/build/soc/npc-soc --image npc/build/soc/tests/soc-uart.bin --max-cycles 200 --wave
```
