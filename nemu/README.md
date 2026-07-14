# NEMU

NEMU (NJU Emulator) is a simple full-system emulator originally designed for teaching. In this repository it is also used as the software reference model for NPC and DiffTest.

## Current Project Usage

The active configuration is `riscv32` native interpreter with devices disabled. NEMU is used in two ways:

- native executable: `build/riscv32-nemu-interpreter`
- DiffTest reference shared object: `build/riscv32-nemu-interpreter-so`

## Scriptable Monitor

The monitor keeps its interactive command loop, but the command dispatcher is now also scriptable:

```sh
./build/riscv32-nemu-interpreter -e 'step 1; last 1; print pc; exit'
./build/riscv32-nemu-interpreter -f script.nemu
```

Supported automation-oriented commands include:

- `run [n]` / `c`: run instructions (`c` keeps the old continue alias)
- `step [n]` / `si [n]`: step instructions
- `print pc`
- `print reg [i]`
- `print mem <addr> <size>`
- `dump state`
- `last [n]`: print recent retired-instruction `CommitEvent`s
- `break <addr>`: set a PC breakpoint
- `delete-break <addr>`
- `clear-breaks`
- `list-breaks`
- `exit`, `quit`, `q`

Example output:

```text
NEMU_LAST_BEGIN count=1
NEMU_LAST R=1 C=1 PC=80000000 I=00000297 RD=5 RV=80000000 NPC=80000004 EXC=0 CAUSE=0
NEMU_LAST_END
pc = 0x80000004
```

## CommitEvent and DiffTest REF API

NEMU records a fixed-size recent ring of `CommitEvent`s. The shared C-compatible event format lives in:

```text
nemu/include/debug/commit_event.h
```

The REF shared object keeps the existing APIs:

```c
void difftest_memcpy(paddr_t addr, void *buf, size_t n, bool direction);
void difftest_regcpy(void *dut, bool direction);
void difftest_exec(uint64_t n);
void difftest_init(int port);
```

It also exports event-based APIs for NPC:

```c
void difftest_step_event(CommitEvent *ev);
size_t difftest_get_last_events(CommitEvent *buf, size_t max_n);
```

NPC uses these APIs to compare the REF and DUT retired CommitEvent sequence. Full register dumps remain diagnostic context after a mismatch; they are no longer the preferred primary comparison mechanism for new DiffTest work.

The old PA-style trace stack (`TRACE`/`ITRACE`/`IQUEUE`/`MTRACE`), disassembly-backed recent-instruction queue, expression evaluator, and watchpoint skeleton have been removed from this project fork. Use `CommitEvent` history and scripted monitor commands instead.

## REF Smoke Test

```sh
python3 tools/ref-api-smoke.py build/riscv32-nemu-interpreter-so --reset-vector 0x80000000
```

Expected current result:

```text
REF_API_SMOKE status=pass pc=0x80000004 x0=0x00000000 t0=0x80000000 mem_addr=0x80000100
```
