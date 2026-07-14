# NPC

Initial Verilog NPC project for the RV32E_Zicsr core.

Current status: Phase 2 is complete through `P2-S6.5: CommitEvent-based control/debug interface`. The RTL fetches instructions through DPI-C memory, executes RV32E `addi`, `auipc`, aligned `lw`/`sw`, and `jalr`, keeps `x0` immutable, and terminates on `ebreak` with GOOD/BAD status from `a0` (`x10 == 0` means GOOD). Unsupported instructions halt with BAD status.

The C++ Verilator harness now centers debugging around retired-instruction `CommitEvent`s. It has a scriptable command shell, bounded `last [n]` history, stable `NPC_RESULT` lines, and event-sequence DiffTest against the NEMU REF shared object when the REF exports `difftest_step_event()`.

## Commands

Build:

```sh
make -C npc
```

Run the current regression set:

```sh
make -C npc smoke
make -C npc test-addi
make -C npc test-jalr-ebreak
make -C npc test-lw-sw
make -C npc test-debug
make -C npc test-difftest
```

Or all current checks:

```sh
make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-debug test-difftest
```

Run with an optional image, reset PC, cycle limit, optional x1 check, and optional DiffTest REF:

```sh
make -C npc run ARGS="--image path/to/image.bin --reset-pc 0x80000000 --max-cycles 100 --expect-x1 0x5 --difftest-ref ../nemu/build/riscv32-nemu-interpreter-so"
```

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
- `log <level>`: level 1 streams commit events as `NPC_TRACE`
- `trace on` / `trace off`: stream commit events independent of log level
- `exit` / `quit`

## Output Format

The simulator prints stable result lines of the form:

```text
NPC_RESULT status=... reason=... cycles=... insts=... pc=... halted=... limit=... x1=... a0=... trap=...
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

## Waveforms

Waveform generation is still available when building with Verilator tracing:

```sh
make -C npc TRACE=1 run ARGS="--wave --max-cycles 8"
```
