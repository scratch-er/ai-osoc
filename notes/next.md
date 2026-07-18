# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 (`RV32E_Zicsr Functional Core`) is complete through `P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening`.
- Phase 4 is complete and closed through `P4-S9: Workload regression and Phase 4 closeout`.
- Phase 5 is closed through `P5-S6: Full Phase 5 regression and closeout`.
- Phase 6 (`Physical Built-in CLINT, UART Path, and RT-Thread Stability`) is closed and committed:
  - `8170098 Implement physical CLINT`
  - `84d258d Validate physical CLINT workloads`
- Phase 7 (`Instruction Cache and fence.i`) is complete through `P7-S3: Linux migration, final exit check, and Phase 8 preparation`.
- Phase 8 (`Linux PPA, Optimization, and Spec-Interface Readiness`) is complete through `P8-S3: Closing P8` (validated on Linux; not yet committed — ask the user before any git commit).
- **Phase 9 was re-planned per user request:** connecting to ysyxSoC (deferred since Phase 5) is now the new `Phase 9: ysyxSoC Integration and AXI Validation` in `notes/plan.md`; the optional pipeline phase became Phase 10 and final integration became Phase 11. `P9-S1: ysyxSoC elaboration bring-up` and `P9-S2: SoC Verilator harness and MROM/UART smoke` are complete on the macOS host (see the P9-S1/P9-S2 sections below). Next session: `P9-S3: Debug/commit exposure patch and DiffTest restoration`.
- Do not modify `AGENTS.md` — it is project-supplied and owned by the user. Record project conventions (such as the `ysyxSoC.patch` workflow) in `notes/` only; the user explicitly reverted an `AGENTS.md` edit for this.
- The project must remain portable across macOS and Linux. At the start of each future session, detect the current platform and choose commands/toolchain settings from the matching platform note; do not assume either macOS or Linux globally.
- Platform notes were split out:
  - `notes/platform-macos.md`: macOS paths/toolchain/workarounds from the previous host.
  - `notes/platform-linux.md`: Linux host/toolchain/rebuild steps and P7 Linux validation results.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store`, `activate`, and top-level `.gitignore`; leave them alone unless the user explicitly asks. Current `git status --short` still shows untracked top-level `.gitignore` plus user/environment changes to `.gitmodules` and `yosys-sta`.
- Top-level `build/` contains generated AM/NPC images, logs, and the ignored temporary `build/sonnet-libc-src` clone used as the Sonnet libc source reference; do not commit generated artifacts unless explicitly requested.

Toolchain/config reminders:

- Choose `CROSS_COMPILE` per host:
  - Linux/AOSC host from P7-S3: `CROSS_COMPILE=riscv64-linux-gnu-`.
  - Previous macOS host: `CROSS_COMPILE=riscv64-elf-`.
- Current Linux host has `verilator`, `yosys`, `iEDA`, `perf`, `clang`/`clang++`, `scons`, and `riscv64-linux-gnu-gcc` available; see `notes/platform-linux.md` for versions. Re-check availability on any future host.
- `am-kernels/tests/cpu-tests/Makefile` uses `/bin/echo -e`; this is OK on Linux but not portable to macOS. Prefer the portable temporary-Makefile/`printf` loop unless intentionally testing the wrapper itself.
- NEMU shared REF `.config` currently needs:
  - `CONFIG_TARGET_SHARE=y`
  - `CONFIG_DEVICE=y`
  - `CONFIG_HAS_SERIAL=y`, `CONFIG_SERIAL_MMIO=0xa00003f8`
  - `CONFIG_HAS_TIMER=y`, `CONFIG_RTC_MMIO=0xa0000048`
  - keyboard/VGA/audio/disk/sdcard disabled.
- `nemu/src/device/Kconfig` was adjusted so shared REF builds can keep `CONFIG_DEVICE=y`; this is needed for NPC UART/CLINT MMIO replay symbols in `nemu/build/riscv32-nemu-interpreter-so`.
- Stale generated macOS helpers may reappear after checkout/context switches: rebuild `nemu/tools/fixdep` and `nemu/tools/kconfig` if `Exec format error` appears on Linux.
- `make -C nemu menuconfig` is interactive; do not run it in automation.
- NEMU REF shared object is `nemu/build/riscv32-nemu-interpreter-so` and exports CommitEvent/MMIO replay APIs used by NPC DiffTest.

## Phase 6 closeout status

Phase 6 exit criteria are met.

Implemented CLINT behavior:

- `npc/rtl/core/Clint.v` is a physical RTL CLINT block with a 64-bit `mtime` that resets to zero and increments once per non-reset core clock.
- `npc/rtl/core/Core.v` routes LSU CLINT-window accesses through a combinational bypass before `AxiArbiter`; IFU, `AxiArbiter.v`, and `AxiMaster.v` were left unchanged.
- CLINT decode uses the approved cheap window compare `lsu_raw_addr[31:16] == 16'h0200`, covering `0x02000000..0x0200ffff`.
- `mtime` low/high are exposed at `0x0200bff8`/`0x0200bffc`; other CLINT-window reads return zero and writes have no effect/no error.
- `Core.v`/`NPC.v` expose `commit_mem_ren` and `commit_mem_rdata`.
- `npc/csrc/main.cpp` synthesizes DiffTest MMIO replay records for committed CLINT reads from DUT RTL load data, while UART writes and C++ memory fallback/debug behavior remain available.
- NEMU NPC-device CLINT acceptance covers the full project window `0x02000000..0x0200ffff` for replay compatibility.

Phase 6 validation completed:

1. Strengthened CLINT directed DiffTest smoke:

```sh
make -C npc test-clint
```

Result: passed. Most recent closeout check also passed with:

- `NPC_DIFFTEST status=on`
- `NEMU_RESULT status=good state=2 halt_pc=0x80000048 halt_ret=0 insts=19 limit=0`
- `NPC_CHECK x1=0x00000001 expect=0x00000001 PASS`
- `NPC_RESULT status=good reason=good_trap cycles=76 insts=19 pc=0x80000048 halted=1 limit=120 x1=0x00000001 a0=0x00000000 trap=1`

2. NPC directed regression including strengthened CLINT:

```sh
make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest test-clint
```

Result: passed during P6-S2. Exact-cycle checks still matched the Makefile expectations, including `test-lw-sw` at 24 cycles, `byte-half-memory` at 78 cycles, and DiffTest baseline cycle checks.

3. NPC `hello` with NEMU event DiffTest:

```sh
make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=2000000 \
  NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Result: passed during P6-S2. Output contained `Hello, AbstractMachine!`, `mainargs = ''.`, `NEMU_RESULT status=good`, and `NPC_RESULT status=good reason=good_trap cycles=2038 insts=465 ...`.

4. AM devscan/timer bounded smoke:

```sh
make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=80000000 mainargs=d run
```

Result: expected bounded run, not a failure. It printed `heap = ...` and `Input device test skipped.`, then reached the cycle limit while running the long delay loop inside `timer_test()` before printing the elapsed-time line. The final trace showed the loop counter advancing normally; this smoke remains documented as bounded because the AM devscan test also contains unsupported video/storage paths and an infinite loop.

5. Bounded CTE/yield smoke with NEMU event DiffTest:

```sh
make -C am-kernels/kernels/yield-os ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Result: expected bounded run. Output reached `ABABA` before `NPC_RESULT status=limit reason=cycle_limit cycles=12000000 insts=2307761 ...`; CSR state showed synchronous yield/ecall trap context (`mcause=0x0000000b`). No timer interrupt behavior was observed.

6. Bounded thread smoke with NEMU event DiffTest:

```sh
make -C am-kernels/kernels/thread-os ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Result: expected bounded run. Output printed five ordered `Thread-B on CPU #0` lines before `NPC_RESULT status=limit reason=cycle_limit cycles=12000000 insts=2308142 ...`; CSR state showed synchronous ecall/yield trap context (`mcause=0x0000000b`). No timer interrupt behavior was observed.

7. Full 35-test NPC `cpu-tests` sweep with NEMU event DiffTest:

```sh
ROOT=/Users/venti/Workspace/ai-ysyx
TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so"
for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
  tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
  printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
  make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=8000000 NPC_DIFFTEST_REF="$REF" run >"/tmp/p6-s2-cputest-$t.log" 2>&1
  status=$?
  rm -f "$tmp"
  if [ $status -ne 0 ]; then echo "FAILED $t"; tail -80 "/tmp/p6-s2-cputest-$t.log"; exit $status; fi
  echo "PASS $t"
done
```

Result: all 35 tests passed during P6-S2:

`add`, `add-longlong`, `bit`, `bubble-sort`, `crc32`, `div`, `dummy`, `fact`, `fib`, `goldbach`, `hello-str`, `if-else`, `leap-year`, `load-store`, `matrix-mul`, `max`, `mersenne`, `min3`, `mov-c`, `movsx`, `mul-longlong`, `narcissistic`, `pascal`, `prime`, `quick-sort`, `recursion`, `select-sort`, `shift`, `string`, `sub-longlong`, `sum`, `switch`, `to-lower-case`, `unalign`, `wanshu`.

8. NPC RT-Thread with NEMU event DiffTest:

```sh
make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Result: passed through scripted shell `halt` during P6-S2. Output contained the RT-Thread banner, `Hello RISC-V!`, shell commands through `msh />halt`, `NEMU_RESULT status=good state=2 halt_pc=0x8000022c halt_ret=0 insts=511954 limit=0`, and `NPC_RESULT status=good reason=good_trap cycles=2343292 insts=511954 ...`.

Interpretation / caveats:

- Physical CLINT DiffTest replay is working for the strengthened directed test and required workloads.
- `abstract-machine/am/src/riscv/npc/timer.c` uses the robust `mtimeh/mtime/mtimeh` sequence; the strengthened `test-clint` directly covers the same ordering pattern in a short deterministic smoke.
- A true low-word rollover test is not practical with the current CLINT because `mtime` is reset to zero and there is no debug preload path; waiting for `2^32` core cycles is not feasible. P6-S2 therefore uses a short high-stability check plus monotonic low-word advancement.
- No timer interrupt is generated or expected by spec; observed CTE traps are synchronous `ecall`/yield traps (`mcause=0x0000000b`).
- UART output remained ordered and non-duplicated in `hello`, bounded CTE smokes, and RT-Thread.
- `yield-os`, `thread-os`, and AM devscan/timer are expected bounded runs, not pass/fail terminating programs.

## Phase 7 plan summary

Phase 7 has three sessions in `notes/plan.md`:

1. `P7-S1: Implement icache, fence.i, counters, and smoke tests`
   - Implement the full icache feature in one engineering pass: direct-mapped 32-byte flip-flop icache, 16-byte AXI burst refill, `fence.i` invalidation, AMAT counters, structured output, focused tests, and smoke validation.
2. `P7-S2: Full regression and bug fixing`
   - Run and fix the full practical regression suite: NPC directed tests, full 35-test `cpu-tests` with DiffTest, `hello`, bounded timer/CTE/thread smokes, and RT-Thread with DiffTest.
3. `P7-S3: Re-check Phase 7 exit criteria and plan Phase 8`
   - Confirm final Phase 7 criteria, record commands/results/counters/caveats, update notes, and plan Phase 8 measurement/PPA baselining.

Phase 7 exit criteria:

- All previous functional tests pass with icache enabled.
- `fence.i` invalidates cached instructions.
- Instruction-cache refill uses 16-byte AXI bursts.
- AMAT counters are emitted and internally consistent.
- Phase 8 has reproducible commands and representative counter output to start from.

## Phase 7 Session 1 status

`P7-S1: Implement icache, fence.i, counters, and smoke tests` is implemented and smoke-validated.

Implemented behavior:

- `npc/rtl/core/Ifu.v` is now a stateful direct-mapped flip-flop icache:
  - 32-byte total capacity, 2 lines, 16 bytes per line, 4 RV32 instructions per line.
  - Index is `pc[4]`, word offset is `pc[3:2]`, tag is `pc[31:5]`.
  - All instruction-fetch addresses are treated cacheable.
- IFU misses request a 16-byte AXI INCR read burst with `arlen=3`, `arsize=2`, `arburst=INCR`.
- LSU/data accesses remain single-beat; CLINT LSU-side bypass behavior is unchanged.
- `npc/rtl/bus/AxiArbiter.v` carries IFU read length to `AxiMaster`; LSU length is fixed to zero.
- `npc/rtl/bus/AxiMaster.v` supports multi-beat read responses while preserving single-beat writes.
- `npc/rtl/bus/LocalAxiSlave.v` returns multi-beat local read bursts from DPI memory.
- `fence.i` now invalidates the icache valid bits when the instruction retires successfully.
- `Core.v`/`NPC.v` expose icache counters to Verilator.
- `npc/csrc/main.cpp` prints a structured `NPC_ICACHE` line:
  - `accesses`, `hits`, `misses`, `miss_wait_cycles`, `refill_beats`, `hit_rate_x1000`, `amat_x1000`.
- Added generated directed tests:
  - `npc/tests/make-icache-bin.py`
  - `npc/tests/make-fencei-bin.py`
  - Make targets `test-icache` and `test-fencei`.
- Existing Makefile exact-cycle checks were relaxed where icache timing changes cycles; semantic checks remain for status, register values, trap causes, DiffTest status, and MMIO replay.

P7-S1 validation completed:

1. Focused icache and fence.i tests:

```sh
make -C npc test-icache test-fencei
```

Result: passed.

Representative counters:

- `test-icache`: `NPC_ICACHE accesses=19 hits=17 misses=2 miss_wait_cycles=12 refill_beats=8 hit_rate_x1000=894 amat_x1000=1631`
- `test-fencei`: `NPC_ICACHE accesses=9 hits=4 misses=5 miss_wait_cycles=30 refill_beats=20 hit_rate_x1000=444 amat_x1000=4333`

2. Directed NPC smoke/regression subset:

```sh
make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest test-clint
```

Result: passed after relaxing exact-cycle greps for icache timing. Notable changed cycle counts include `test-lw-sw` now 26 cycles and `byte-half-memory` now 70 cycles. `test-clint` passed with DiffTest and physical CLINT replay; representative counter line: `NPC_ICACHE accesses=19 hits=14 misses=5 miss_wait_cycles=30 refill_beats=20 hit_rate_x1000=736 amat_x1000=2578`.

3. Access-fault directed DiffTest:

```sh
make -C npc test-access-fault
```

Result: passed. The instruction-access-fault subcase needed `--max-cycles 64` instead of 40 because icache refill adds cycles before reaching the final ebreak.

4. NPC `hello` with NEMU event DiffTest:

```sh
make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=2000000 \
  NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Result: passed. Output contained `Hello, AbstractMachine!`, `mainargs = ''.`, `NEMU_RESULT status=good`, and `NPC_RESULT status=good reason=good_trap cycles=2116 insts=465 ...`. Representative counter line: `NPC_ICACHE accesses=465 hits=297 misses=168 miss_wait_cycles=1008 refill_beats=672 hit_rate_x1000=638 amat_x1000=3167`.

## Phase 7 Session 2 status

`P7-S2: Full regression and bug fixing` is complete. No RTL/C++ fixes were required during this session; the full practical regression suite passed or reached the same expected bounded states documented before.

P7-S2 validation completed:

1. NPC directed regression including icache/fence/access-fault/CLINT:

```sh
make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest test-clint test-icache test-fencei test-access-fault
```

Result: passed.

Representative results/counters:

- `test-clint`: `NPC_RESULT status=good reason=good_trap cycles=68 insts=19 pc=0x80000048 ...`; `NPC_ICACHE accesses=19 hits=14 misses=5 miss_wait_cycles=30 refill_beats=20 hit_rate_x1000=736 amat_x1000=2578`.
- `test-icache`: `NPC_RESULT status=good reason=good_trap cycles=50 insts=19 pc=0x20000010 ...`; `NPC_ICACHE accesses=19 hits=17 misses=2 miss_wait_cycles=12 refill_beats=8 hit_rate_x1000=894 amat_x1000=1631`.
- `test-fencei`: `NPC_RESULT status=good reason=good_trap cycles=50 insts=9 pc=0x80000008 ...`; `NPC_ICACHE accesses=9 hits=4 misses=5 miss_wait_cycles=30 refill_beats=20 hit_rate_x1000=444 amat_x1000=4333`.
- Access-fault subtests passed with NEMU event DiffTest; instruction-access-fault still uses the P7-S1 `--max-cycles 64` allowance.

2. Full 35-test NPC `cpu-tests` sweep with NEMU event DiffTest:

```sh
ROOT=/Users/venti/Workspace/ai-ysyx
TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so"
for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
  tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
  printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
  make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=8000000 NPC_DIFFTEST_REF="$REF" run >"/tmp/p7-s2-cputest-$t.log" 2>&1
  status=$?
  rm -f "$tmp"
  if [ $status -ne 0 ]; then echo "FAILED $t"; tail -100 "/tmp/p7-s2-cputest-$t.log"; exit $status; fi
  icache=$(grep 'NPC_ICACHE' "/tmp/p7-s2-cputest-$t.log" | tail -1)
  result=$(grep 'NPC_RESULT' "/tmp/p7-s2-cputest-$t.log" | tail -1)
  echo "PASS $t | $result | $icache"
done
```

Result: all 35 tests passed:

`add`, `add-longlong`, `bit`, `bubble-sort`, `crc32`, `div`, `dummy`, `fact`, `fib`, `goldbach`, `hello-str`, `if-else`, `leap-year`, `load-store`, `matrix-mul`, `max`, `mersenne`, `min3`, `mov-c`, `movsx`, `mul-longlong`, `narcissistic`, `pascal`, `prime`, `quick-sort`, `recursion`, `select-sort`, `shift`, `string`, `sub-longlong`, `sum`, `switch`, `to-lower-case`, `unalign`, `wanshu`.

Representative counter extremes from this sweep:

- `sum`: `NPC_ICACHE accesses=528 hits=517 misses=11 miss_wait_cycles=66 refill_beats=44 hit_rate_x1000=979 amat_x1000=1125`.
- `matrix-mul`: `NPC_RESULT status=good reason=good_trap cycles=545234 insts=132126 ...`; `NPC_ICACHE accesses=132126 hits=87348 misses=44778 miss_wait_cycles=268668 refill_beats=179112 hit_rate_x1000=661 amat_x1000=3033`.
- `string`: `NPC_ICACHE accesses=1449 hits=1379 misses=70 miss_wait_cycles=420 refill_beats=280 hit_rate_x1000=951 amat_x1000=1289`.

3. NPC `hello` with NEMU event DiffTest:

```sh
make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=2000000 \
  NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Result: passed. Output contained `Hello, AbstractMachine!`, `mainargs = ''.`, `NEMU_RESULT status=good`, and `NPC_RESULT status=good reason=good_trap cycles=2116 insts=465 pc=0x800000c4 ...`. Counter line: `NPC_ICACHE accesses=465 hits=297 misses=168 miss_wait_cycles=1008 refill_beats=672 hit_rate_x1000=638 amat_x1000=3167`.

4. AM devscan/timer bounded smoke:

```sh
make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=80000000 mainargs=d run
```

Result: expected bounded run, not a failure. It printed `heap = ...` and `Input device test skipped.`, then reached `NPC_RESULT status=limit reason=cycle_limit cycles=80000000 insts=25000215 pc=0x80000a5c ...` inside the timer delay loop. Counter line: `NPC_ICACHE accesses=25000215 hits=24998806 misses=1409 miss_wait_cycles=8454 refill_beats=5636 hit_rate_x1000=999 amat_x1000=1000`.

5. Bounded CTE/yield smoke with NEMU event DiffTest:

```sh
make -C am-kernels/kernels/yield-os ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Result: expected bounded run. Output reached `ABABABAB` before `NPC_RESULT status=limit reason=cycle_limit cycles=12000000 insts=3749488 ...`; CSR state still showed synchronous yield/ecall trap context (`mcause=0x0000000b`). Counter line: `NPC_ICACHE accesses=3749488 hits=3749151 misses=337 miss_wait_cycles=2022 refill_beats=1348 hit_rate_x1000=999 amat_x1000=1000`.

6. Bounded thread smoke with NEMU event DiffTest:

```sh
make -C am-kernels/kernels/thread-os ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Result: expected bounded run. Output printed eight ordered `Thread-B on CPU #0` lines before `NPC_RESULT status=limit reason=cycle_limit cycles=12000000 insts=3746560 ...`; CSR state still showed synchronous ecall/yield trap context (`mcause=0x0000000b`). Counter line: `NPC_ICACHE accesses=3746560 hits=3744200 misses=2360 miss_wait_cycles=14160 refill_beats=9440 hit_rate_x1000=999 amat_x1000=1003`.

7. NPC RT-Thread with NEMU event DiffTest:

```sh
make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Result: passed through scripted shell `halt`. Output contained the RT-Thread banner, `Hello RISC-V!`, shell commands through `msh />halt`, `NEMU_RESULT status=good state=2 halt_pc=0x8000022c halt_ret=0 insts=511954 limit=0`, and `NPC_RESULT status=good reason=good_trap cycles=1846844 insts=511954 ...`. Counter line: `NPC_ICACHE accesses=511954 hits=424044 misses=87910 miss_wait_cycles=527460 refill_beats=351640 hit_rate_x1000=828 amat_x1000=2030`.

Interpretation / caveats:

- P7-S2 found no functional icache, burst, `fence.i`, counter, CLINT replay, or UART-ordering regression.
- The current user-facing command reference for cache counters is `npc/README.md` section `Instruction-cache counters`. Use the printed `NPC_ICACHE` line; `hit_rate_x1000 / 10` is the percentage hit rate, and `amat_x1000 / 1000` is the reported AMAT in cycles.
- Common-workload hit rates from P7-S2:
  - `hello`: 63.8% (`hit_rate_x1000=638`).
  - `rt-thread-am`: 82.8% (`hit_rate_x1000=828`).
  - AM devscan/timer bounded loop: 99.9% (`hit_rate_x1000=999`).
  - `yield-os` bounded: 99.9% (`hit_rate_x1000=999`).
  - `thread-os` bounded: 99.9% (`hit_rate_x1000=999`).
  - representative `cpu-tests`: `sum` 97.9%, `string` 95.1%, `bubble-sort` 90.2%, `matrix-mul` 66.1%, `crc32` 73.7%, `quick-sort` 74.7%.
- For representative successful local-memory runs, `refill_beats == misses * 4`, matching the 16-byte / 4-instruction burst refill design.
- `yield-os`, `thread-os`, and AM devscan/timer remain expected bounded runs. They retire more instructions and print more visible output within the same cycle budgets after icache because warm loops now hit in the icache.
- `NPC_RESULT` exact cycle counts are not stable compatibility targets after icache; use semantic status, register/trap checks, DiffTest status, and `NPC_ICACHE` consistency instead.
- This P7-S2 closeout commit includes `npc/README.md`, `notes/plan.md`, and `notes/next.md`. The pre-existing untracked top-level `.gitignore` is intentionally left alone.

## Phase 7 Session 3 / Linux closeout status

`P7-S3: Linux migration, final exit check, and Phase 8 preparation` is complete.

Platform migration completed:

- Wrote `notes/platform-macos.md` with previous macOS-specific absolute paths, `riscv64-elf-` toolchain use, `/bin/echo -e` workaround, RT-Thread portability notes, and Mach-O generated-binary caveats.
- Wrote `notes/platform-linux.md` with the current AOSC Linux/aarch64 host, installed tools, `riscv64-linux-gnu-` target compiler, NEMU/NPC Linux rebuild procedure, and P7 Linux validation results.
- Rebuilt stale macOS-generated NEMU helper binaries (`fixdep`, `kconfig`) for Linux.
- Rebuilt NEMU REF as a Linux/aarch64 ELF shared object and rebuilt NPC with Verilator.
- Adjusted `nemu/src/device/Kconfig` so shared REF builds can include `CONFIG_DEVICE=y`, which is required for NPC UART/CLINT MMIO replay support in DiffTest.
- Regenerated `rt-thread-am/bsp/abstract-machine/files.mk` with Linux paths via `make init` after `scons` was installed.

Linux validation completed with `CROSS_COMPILE=riscv64-linux-gnu-`:

1. NPC directed regression including icache/fence/access-fault/CLINT passed:

```sh
make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug \
  test-difftest test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

Representative counters remained consistent:

- `test-clint`: `NPC_ICACHE accesses=19 hits=14 misses=5 miss_wait_cycles=30 refill_beats=20 hit_rate_x1000=736 amat_x1000=2578`.
- `test-icache`: `NPC_ICACHE accesses=19 hits=17 misses=2 miss_wait_cycles=12 refill_beats=8 hit_rate_x1000=894 amat_x1000=1631`.
- `test-fencei`: `NPC_ICACHE accesses=9 hits=4 misses=5 miss_wait_cycles=30 refill_beats=20 hit_rate_x1000=444 amat_x1000=4333`.

2. `hello` passed with NEMU event DiffTest:

- Output contained `Hello, AbstractMachine!` and `mainargs = ''.`
- `NEMU_RESULT status=good state=2 halt_pc=0x800000c4 halt_ret=0 insts=465 limit=0`.
- `NPC_RESULT status=good reason=good_trap cycles=2116 insts=465 pc=0x800000c4 ...`.
- `NPC_ICACHE accesses=465 hits=297 misses=168 miss_wait_cycles=1008 refill_beats=672 hit_rate_x1000=638 amat_x1000=3167`.

3. Full 35-test `cpu-tests` sweep passed with NEMU event DiffTest:

`add`, `add-longlong`, `bit`, `bubble-sort`, `crc32`, `div`, `dummy`, `fact`, `fib`, `goldbach`, `hello-str`, `if-else`, `leap-year`, `load-store`, `matrix-mul`, `max`, `mersenne`, `min3`, `mov-c`, `movsx`, `mul-longlong`, `narcissistic`, `pascal`, `prime`, `quick-sort`, `recursion`, `select-sort`, `shift`, `string`, `sub-longlong`, `sum`, `switch`, `to-lower-case`, `unalign`, `wanshu`.

Representative counters:

- `sum`: `NPC_ICACHE accesses=528 hits=517 misses=11 miss_wait_cycles=66 refill_beats=44 hit_rate_x1000=979 amat_x1000=1125`.
- `matrix-mul`: `NPC_RESULT status=good reason=good_trap cycles=543774 insts=131726 ...`; `NPC_ICACHE accesses=131726 hits=87058 misses=44668 miss_wait_cycles=268008 refill_beats=178672 hit_rate_x1000=660 amat_x1000=3034`.
- `string`: `NPC_ICACHE accesses=1449 hits=1379 misses=70 miss_wait_cycles=420 refill_beats=280 hit_rate_x1000=951 amat_x1000=1289`.

4. AM devscan/timer bounded smoke reached the expected timer-loop limit:

- `NPC_RESULT status=limit reason=cycle_limit cycles=80000000 insts=25000215 pc=0x80000a5c ...`.
- `NPC_ICACHE accesses=25000215 hits=24998806 misses=1409 miss_wait_cycles=8454 refill_beats=5636 hit_rate_x1000=999 amat_x1000=1000`.

5. `yield-os` bounded smoke reached expected cycle limit after `ABABABAB`:

- `NPC_RESULT status=limit reason=cycle_limit cycles=12000000 insts=3749488 pc=0x800000a0 ...`.
- CSR state still showed synchronous ecall/yield trap context: `mcause=0x0000000b`.
- `NPC_ICACHE accesses=3749488 hits=3749151 misses=337 miss_wait_cycles=2022 refill_beats=1348 hit_rate_x1000=999 amat_x1000=1000`.

6. `thread-os` bounded smoke reached expected cycle limit after eight ordered `Thread-B on CPU #0` lines:

- `NPC_RESULT status=limit reason=cycle_limit cycles=12000000 insts=3746560 pc=0x800001a8 ...`.
- CSR state still showed synchronous ecall/yield trap context: `mcause=0x0000000b`.
- `NPC_ICACHE accesses=3746560 hits=3744200 misses=2360 miss_wait_cycles=14160 refill_beats=9440 hit_rate_x1000=999 amat_x1000=1003`.

7. RT-Thread passed through scripted shell `halt` with NEMU event DiffTest:

- Output contained RT-Thread banner, `Hello RISC-V!`, and shell commands through `msh />halt`.
- `NEMU_RESULT status=good state=2 halt_pc=0x8000022c halt_ret=0 insts=511842 limit=0`.
- `NPC_RESULT status=good reason=good_trap cycles=1816964 insts=511842 pc=0x8001f718 ...`.
- `NPC_ICACHE accesses=511842 hits=428931 misses=82911 miss_wait_cycles=497466 refill_beats=331644 hit_rate_x1000=838 amat_x1000=1971`.

Phase 7 exit criteria are met on Linux:

- All previous functional tests pass with icache enabled.
- `fence.i` invalidates cached instructions (`test-fencei` passed).
- Instruction-cache refill uses 16-byte AXI bursts; representative successful runs still have `refill_beats == misses * 4`.
- AMAT counters are emitted and internally consistent.
- Phase 8 has reproducible per-platform commands and representative Linux counter output to start from; macOS commands are kept in `notes/platform-macos.md` and should be revalidated when running on macOS again.

## Phase 8 Session 1 status

`P8-S1: Guard debug ports and add a spec-interface simulation harness` is implemented and validated on Linux. The user asked to review/revise before committing, so do not commit until after their revision.

Implemented behavior:

- `npc/rtl/NPC.v` now uses `NPC_DEBUG`:
  - `NPC_DEBUG=1` exposes the existing Verilator/DiffTest debug interface: `io_reset_pc`, `debug_*`, and `commit_*`.
  - `NPC_DEBUG=0` hides those ports from the top-level interface, leaving the spec ports from `specs/core.md` plus the hardwired-inactive reserved AXI slave outputs.
- The spec-mode simulator reuses the existing simulation code instead of a separate harness stack:
  - `npc/csrc/main.cpp` has compile-time debug/spec paths.
  - `npc/csrc/memory.cpp` still provides image loading and the DPI-backed local AXI memory path; in spec mode, UART writes at `0x10000000` print immediately, UART EOT byte `0x04` terminates the small smoke, and `--uart-expect TEXT` can stop larger workloads after expected UART output.
  - `npc/rtl/bus/LocalAxiSlave.v` remains the local AXI service path for Verilator smoke runs.
- `npc/Makefile` now has `NPC_DEBUG ?= 1` and `RESET_PC ?= 0x20000000`, passes `-DNPC_DEBUG=...` to C++, passes `+define+NPC_DEBUG` to Verilator only in debug mode, passes `-GRESET_PC=$(RESET_PC)`, and adds `spec-smoke`.
- Added `npc/tests/make-spec-uart-bin.py`, generating a reset-PC `0x20000000` program that prints `SPEC\n` to UART and then writes EOT (`0x04`).
- Updated `npc/README.md` with debug/spec build commands.

P8-S1 validation completed:

1. Spec-mode smoke:

```sh
make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke
```

Result: passed. Output included:

- `NPC_IMAGE path=build/tests/spec-uart.bin base=0x20000000 size=52`
- `SPEC`
- `NPC_SPEC_RESULT status=good reason=uart_eot cycles=61 limit=400`

2. Spec-mode AM `hello` UART smoke:

```sh
make -C npc clean && make -C npc NPC_DEBUG=0 RESET_PC=0x80000000
make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
  AM_HOME=/host/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-linux-gnu- image
npc/build/npc --image am-kernels/kernels/hello/build/hello-riscv32e-npc.bin \
  --reset-pc 0x80000000 --max-cycles 2000000 \
  --uart-expect "Hello, AbstractMachine!"
```

Result: passed. Output included `Hello, AbstractMachine!` and `NPC_SPEC_RESULT status=good reason=uart_expect cycles=1217 limit=2000000`.

3. Spec-mode RT-Thread UART smoke:

```sh
make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
  AM_HOME=/host/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-linux-gnu- image
npc/build/npc --image rt-thread-am/bsp/abstract-machine/build/rtthread-riscv32e-npc.bin \
  --reset-pc 0x80000000 --max-cycles 12000000 --uart-expect "msh />"
```

Result: passed. Output included the RT-Thread banner, `Hello RISC-V!`, `msh />`, and `NPC_SPEC_RESULT status=good reason=uart_expect cycles=302371 limit=12000000`.

4. Default debug-mode directed regression with DiffTest:

```sh
make -C npc clean && make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest \
  test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

Result: passed. Representative lines remained consistent:

- `test-clint`: `NPC_RESULT status=good reason=good_trap cycles=68 insts=19 ...`; `NPC_ICACHE accesses=19 hits=14 misses=5 ...`.
- `test-icache`: `NPC_RESULT status=good reason=good_trap cycles=50 insts=19 ...`; `NPC_ICACHE accesses=19 hits=17 misses=2 ...`.
- `test-fencei`: `NPC_RESULT status=good reason=good_trap cycles=50 insts=9 ...`; `NPC_ICACHE accesses=9 hits=4 misses=5 ...`.
- Access-fault subtests passed with NEMU event DiffTest.

5. AM `hello` with NEMU event DiffTest:

```sh
make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
  AM_HOME=/host/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-linux-gnu- NPC_MAX_CYCLES=2000000 \
  NPC_DIFFTEST_REF=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Result: passed. Output contained `Hello, AbstractMachine!`, `mainargs = ''.`, `NEMU_RESULT status=good state=2 halt_pc=0x800000c4 halt_ret=0 insts=465 limit=0`, `NPC_RESULT status=good reason=good_trap cycles=2116 insts=465 ...`, and `NPC_ICACHE accesses=465 hits=297 misses=168 ...`.

## Phase 8 Session 2 status

`P8-S2: Analyze baseline PPA/performance and perform targeted optimization` is implemented and validated on Linux. Do not commit unless the user explicitly asks; the project rule says to commit at session end, but higher-priority runtime instructions require explicit confirmation before git mutations.

Key implementation details:

- PPA/STA now targets the SoC-connectable physical top only:
  - `NPC_DEBUG=0` / no `+define+NPC_DEBUG`.
  - Physical RTL list excludes Verilator-only `npc/rtl/bus/LocalAxiSlave.v` and `npc/rtl/bus/MemIf.v`.
  - `npc/rtl/NPC.v` wraps the local AXI simulation slave, its local wires, and local/core muxing in `NPC_LOCAL_AXI`.
  - `npc/Makefile` passes `+define+NPC_LOCAL_AXI` to Verilator builds so the existing local-memory simulation harness still works.
- `yosys-sta/scripts/yosys.tcl` now supports `VERILOG_INCLUDE_DIRS`, needed for includes such as `include/npc_defines.vh` when synthesizing from `yosys-sta/` with absolute RTL paths.
- Spec-mode hidden debug/commit fanout cleanup:
  - Removed the `unused_debug` reduction that preserved `debug_*`/`commit_*` logic in `NPC_DEBUG=0` physical synthesis.
  - Kept the internal wires for the existing `Core` interface and wrapped them with Verilator `UNUSED` lint pragmas.

PPA/STA recorded in `notes/p8-timing-and-ppa.md`:

- Tooling: Yosys 0.67 and iEDA on Linux. The older Yosys 0.45 lacked the `clockgate` command; after the user upgraded Yosys, synthesis ran.
- `npc/Makefile` now wraps the physical `yosys-sta` flow:
  - `make -C npc sta CLK_FREQ_MHZ=540 STA_O=../build/p8-s2-ppa/npc-sta`
  - `make -C npc sta-sweep STA_O=../build/p8-s2-ppa/npc-sta-sweep STA_FREQS="100 300 500 530 540 550 560 600 700"`
- Current optimized physical sweep under `icsprout55`:
  - area `22755.600000`, sequential area `8001.840000`, `DFFQX1H7L=1299`, `ICGX0P5H7L=15`.
  - worst path delay `1.799 ns`; reported Fmax `540.333 MHz`.
  - clean target: `540 MHz` with slack `0.000 ns`.
  - first failing checked target: `550 MHz` with slack `-0.033 ns`.
  - critical endpoint: `u_core.u_regfile.regs[7]_29__reg_p:D`; path is mostly mux/buffer/control logic feeding the register-file write port.
- Earlier 100 MHz baseline before cleanup remains in the note for comparison, but the actionable STA result is now the Makefile-wrapped frequency sweep.

Performance baseline recorded in `notes/p8-timing-and-ppa.md`:

- `hello`: good trap, `cycles=2116`, `insts=465`, `hit_rate_x1000=638`, `amat_x1000=3167`.
- `cpu-tests/sum`: good trap, `cycles=1532`, `insts=528`, `hit_rate_x1000=979`, `amat_x1000=1125`.
- `cpu-tests/string`: good trap, `cycles=4260`, `insts=1449`, `hit_rate_x1000=951`, `amat_x1000=1289`.
- `cpu-tests/crc32`: good trap, `cycles=67892`, `insts=18163`, `hit_rate_x1000=740`, `amat_x1000=2557`.
- `cpu-tests/quick-sort`: good trap, `cycles=11854`, `insts=3041`, `hit_rate_x1000=758`, `amat_x1000=2446`.
- `cpu-tests/matrix-mul`: good trap, `cycles=543774`, `insts=131726`, `hit_rate_x1000=660`, `amat_x1000=3034`.
- `coremark`: bounded default `ITERATIONS=1000`, reached `cycles=120000000`, `insts=37471468`, `hit_rate_x1000=845`, `amat_x1000=1924`; did not terminate. Do not modify `am-kernels/` unless explicitly asked.
- `rt-thread-am`: good trap through scripted shell `halt`, `cycles=1816964`, `insts=511842`, `hit_rate_x1000=838`, `amat_x1000=1971`.

Validation after optimization:

1. Spec-mode smoke passed:

```sh
make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke
```

Output included `SPEC` and `NPC_SPEC_RESULT status=good reason=uart_eot cycles=61 limit=400`.

2. Optimized physical synthesis and STA completed with output under `build/p8-s2-ppa/opt-no-debug-reduce/NPC-100MHz/`.

3. Debug-mode directed/DiffTest regression passed:

```sh
make -C npc clean && make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest \
  test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

## Phase 8 Session 3 / closeout status

`P8-S3: Closing P8` is implemented and validated on Linux. Do not commit unless the user explicitly asks; higher-priority runtime instructions require explicit confirmation before git mutations.

Final P8-S3 changes:

- `npc/rtl/core/Core.v` now constant-drives hidden debug/commit observation outputs under `NPC_DEBUG=0`, so physical spec-mode synthesis no longer preserves those observation expressions.
- `npc/rtl/core/RegFile.v` now constant-drives `debug_x1`, `debug_a0`, and `debug_regs_flat` under `NPC_DEBUG=0`, removing physical register-file debug fanout.
- A physical-mode register-file reset removal experiment was tried and rejected because STA worsened to roughly `465 MHz` around the checked `580 MHz` target.

Final physical STA under `icsprout55`, output root `build/p8-s3-close/final-phys/`:

- command:

```sh
make -C npc sta-sweep \
  STA_O=../build/p8-s3-close/final-phys \
  STA_LOG_DIR=../build/p8-s3-close/final-phys-logs \
  STA_FREQS="580 600 605 610 620"
```

- area `22685.320000`, sequential area `8001.840000`, `DFFQX1H7L=1299`, `ICGX0P5H7L=15`.
- worst core path delay `1.583 ns`; reported Fmax `614.531 MHz`.
- clean checked target: `610 MHz` with slack `0.012 ns`.
- first failing checked target: `620 MHz` with slack `-0.015 ns`.
- worst endpoint: register-file write flop such as `u_core.u_regfile.regs[3]_1__reg_p:D`.
- Compared with P8-S2 optimized top: area improved by `70.28` and reported Fmax improved from `540.333 MHz` to `614.531 MHz`.

P8-S3 validation completed:

1. Spec-mode smoke passed:

```sh
make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke
```

Output included `SPEC` and `NPC_SPEC_RESULT status=good reason=uart_eot cycles=61 limit=400`.

2. Debug-mode directed/DiffTest regression passed:

```sh
make -C npc clean && make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest \
  test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

Representative final subtest passed with `NEMU_RESULT status=good`, `NPC_CHECK x1=0x00000007 ... PASS`, and `NPC_RESULT status=good reason=good_trap`.

3. Optimized core RT-Thread with NEMU event DiffTest passed:

```sh
make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
  AM_HOME=/host/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-linux-gnu- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Final lines included `NEMU_RESULT status=good state=2 halt_pc=0x8000022c halt_ret=0 insts=511842 limit=0`, `NPC_RESULT status=good reason=good_trap cycles=1816964 insts=511842 pc=0x8001f718 ...`, and `NPC_ICACHE accesses=511842 hits=428931 misses=82911 miss_wait_cycles=497466 refill_beats=331644 hit_rate_x1000=838 amat_x1000=1971`.

Notes updated:

- `notes/p8-timing-and-ppa.md` now contains the P8-S3 final timing cleanup, final sweep table, before/after comparison, validation, and remaining caveats.
- `notes/plan.md` marks `P8-S3: Closing P8` complete and records final STA/validation details.

## Phase 9 Session 1 status

`P9-S1: ysyxSoC elaboration bring-up` is complete on the macOS host (macOS 26.5.2, Darwin 25.5.0 arm64). `ysyxSoC/build/ysyxSoCFull.v` is now reproducibly generated. Do not commit until the user finishes revising.

Environment used:

- Homebrew OpenJDK `17.0.19`; the `ysyxSoC/mill` wrapper reads `.mill-version` (`0.12.4`) and downloads Mill 0.12.4 on first run. `./mill --version` confirms Mill 0.12.4 / Java 17.0.19.
- First `./mill` invocation also resolves all ivy dependencies; subsequent runs are fast.

Exact commands and results:

1. Submodule init and rocket-chip patch (~2.5 min, network required):

```sh
make -C ysyxSoC dev-init
```

Cloned `rocket-chip` at `d0c6b50` plus nested deps (`cde`, `chisel`, `diplomacy`, `hardfloat`, `berkeley-softfloat-3`, `berkeley-testfloat-3`), then applied `patch/rocket-chip.patch` inside `rocket-chip`. Result: exit 0.

2. Elaboration (31s; the plain mill command works — no firtool patch needed, the Chisel-bundled firtool is sufficient):

```sh
cd ysyxSoC && ./mill -i ysyxsoc.runMain ysyx.Elaborate --target-dir build
```

Result: `ysyxSoC/build/ysyxSoCTop.sv` (5444 lines), exit 0. Only deprecation warnings from rocket-chip/Scala.

3. Post-processing per `ysyxSoC/Makefile`, adapted for macOS BSD sed (GNU `sed -i -e` and BRE `\|`/empty alternation do not work with BSD sed):

```sh
cd ysyxSoC
mv build/ysyxSoCTop.sv build/ysyxSoCFull.v
sed -i '' -E 's/_(aw|ar|w|r|b)_(bits_)?/_\1/g' build/ysyxSoCFull.v
sed -i '' '/firrtl_black_box_resource_files.f/, $d' build/ysyxSoCFull.v
```

(On Linux, the original Makefile lines work as-is: `sed -i -e 's/_\(aw\|ar\|w\|r\|b\)_\(\|bits_\)/_\1/g'`.)

Verified contents of `ysyxSoC/build/ysyxSoCFull.v`:

- `ysyx_00000000 cpu` instance (line ~1475) with `io_master_*` AXI4 ports and `io_slave_*` tied inactive by the SoC itself; port names match `specs/core.md` after the sed rename.
- Full fabric present: `AXI4Xbar` x2, `AXI4Fragmenter`, `AXI4ToAPB`, `APBFanout`, `APBUart16550`, `AXI4MROM` (writes trigger `$fatal`), `AXI4RAM` with `mem_2048x32` (8KB SRAM), plus APB SPI/GPIO/Keyboard/VGA and PSRAM/SDRAM stubs, and tops `ysyxSoCASIC` / `ysyxSoCFull` / `ysyxSoCTop`.
- `MROMHelper` module at the end imports `DPI-C function void mrom_read(input int raddr, output int rdata)` — the harness must provide `mrom_read()`.
- Submodule state after dev-init: `git -C ysyxSoC status --short` shows ` m rocket-chip` (expected — `rocket-chip.patch` applied inside the nested submodule, no commit) and untracked `mill`; `build/` and `out/` are gitignored. Nothing was committed inside the submodule.

## Phase 9 Session 2 status

`P9-S2: SoC Verilator harness and MROM/UART smoke` is complete on the macOS host. `make -C npc soc-smoke` passes with one command (exit 0).

What was added:

- `npc/Makefile` SoC flavor: `make -C npc soc` builds `npc/build/soc/npc-soc`; `soc-smoke` runs the smoke and greps the results. The build copies `ysyxSoC/build/ysyxSoCFull.v` to `npc/build/soc/ysyxSoCFull.v` with `sed 's/ysyx_00000000/NPC/g'`, compiles all `ysyxSoC/perip/**/*.v` (include dirs `perip/uart16550/rtl` + `perip/spi/rtl`), the NPC RTL in `NPC_DEBUG=0` spec-port mode **excluding `rtl/bus/LocalAxiSlave.v` and `rtl/bus/MemIf.v`** (local-AXI-only, DPI-bound), and `npc/csrc/soc_main.cpp`. Verilator flags: `--top-module ysyxSoCTop --timescale "1ns/1ns" --no-timing -Wno-fatal --autoflush`; `TRACE=1` adds `--trace` (harness `--wave` writes `build/soc/wave.vcd`). `--autoflush` makes Verilator emit `VL_FFLUSH_MT()` after every `$write`/`$display` (verified in the generated C++ next to the `uart_tfifo.v` `$write("%c", ...)`), so single UART chars appear immediately even if the sim is killed or hits an RTL `$fatal` before exit; per the Verilator spec, the alternative is calling `fflush(stdout)` in the C++ loop.
- `npc/csrc/soc_main.cpp`: standalone harness. `mrom_read()` DPI serves a 4KB MROM image loaded at `0x20000000` (`--image`); offset is `raddr & 0xfff` (AXI4MROM passes the full address with the top 2 bits stripped). `flash_read()` is an `assert(0)` stub (only reachable after SPI flash commands, which we never issue). Result line: `NPC_SOC_RESULT status=... reason=... cycles=... limit=... mrom_reads=...`.
- `npc/tests/make-soc-uart-bin.py`: MROM program writing `SOC\n` to UART16550 THR (`0x10000000`) then `jal x0, 0`. No divisor init needed for <= 16 chars.
- `npc/rtl/bus/AxiMaster.v`: `$display` AXI channel probes guarded by `` `ifdef NPC_TRACE_AXI`` (inert by default; invaluable for SoC AXI debugging — VCD signal aliasing in the generated SoC makes waveform forensics painful).

Key bring-up bug (cost most of the session): **ysyxSoC delays the CPU reset through a 10-stage `SynchronizerShiftReg` (`ysyxSoC/src/SoC.scala:62`: `cpu.module.reset := SynchronizerShiftReg(reset.asBool, 10) || reset.asBool`)**. A short reset pulse is shifted through and re-appears as a spurious mid-run CPU reset ~10 cycles later. Symptom: the core's first icache refill burst was aborted after 3 beats by the spurious reset, the AXI4Fragmenter kept holding the unconsumed 4th beat, the core re-issued ARs the fragmenter could not accept, and the fabric deadlocked (no UART output). Fix: the harness holds reset for 20 cycles (`soc_main.cpp`). With that, the first burst completes cleanly and `SOC\n` is printed.

Validation:

- `make -C npc soc-smoke` from a clean `npc/build/soc`: output contains `SOC` (RTL `$write` from `uart_tfifo.v`) and `NPC_SOC_RESULT status=limit reason=cycle_limit cycles=2000 limit=2000 mrom_reads=12`; exit 0. The AXI trace shows clean 4-beat icache refills through the AXI4Fragmenter and UART word stores with ~3-cycle APB write latency.
- Existing flows re-verified after the change: debug-mode `make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-icache test-fencei` (exit 0) and spec-mode `make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke` (`NPC_SPEC_RESULT status=good reason=uart_eot cycles=61`, exit 0). Note `make -C npc clean` removes `build/soc` too; rebuild with `make -C npc soc-smoke`.
- `npc/README.md` documents the SoC flavor.

Observed SoC facts for later sessions:

- Reset latency: 20 held + 10 shift-register cycles of CPU reset before the first AR (~30 cycles).
- The SoC xbar/fragmenter path to MROM delivers one R beat every 2 cycles; APB (UART) writes complete in ~3 cycles. Word stores (`wstrb=1111`) to the UART16550 THR work; the UART prints the low byte.
- `mrom_reads=12` for the smoke = 3 lines x 4 words (the `jal x0,0` spin hits in icache afterwards).

## Next steps

1. Start `P9-S3: Debug/commit exposure patch and DiffTest restoration` (session 3 of Phase 9 in `notes/plan.md`): create `ysyxSoC.patch` routing the NPC `NPC_DEBUG=1` debug/commit signals and `io_reset_pc` through `src/CPU.scala`, `src/SoC.scala`, `src/Top.scala` to the SoC top; rebuild the SoC flavor with `NPC_DEBUG=1`; restore precise `ebreak` termination, structured `NPC_RESULT` lines, and event DiffTest (add MROM `0x20000000..0x20000fff` + SRAM `0x0f000000..0x0f001fff` regions to NEMU, sync the MROM image into the REF). Verify with the P9-S2 smoke plus a small multi-line program exercising icache burst refill.
2. Never commit inside the `ysyxSoC` submodule; keep tracked-source debug changes as `ysyxSoC.patch` at the repo root (regenerate: `git -C ysyxSoC diff > ../ysyxSoC.patch`; apply on fresh checkouts: `git -C ysyxSoC apply ../ysyxSoC.patch`). Note this diff does not cover the nested `rocket-chip` patch — that one is re-applied by `make -C ysyxSoC dev-init` on fresh clones.
3. If the user wants to persist the P8 closeout, P9-S1, or P9-S2 state, ask before making a git commit. P9-S2 adds tracked files: `npc/csrc/soc_main.cpp`, `npc/tests/make-soc-uart-bin.py`, `npc/Makefile`, `npc/rtl/bus/AxiMaster.v` (guarded probes), `npc/README.md`, and notes.
4. Keep the STA caveat in mind: current timing is standalone core-top STA with only a core clock constraint; no SoC AXI input/output delays are modeled yet.

## Phase 9 planning facts (verified on the macOS host; re-verify on Linux)

P9-S1 confirmed the elaboration-related facts below on macOS: `dev-init`, the plain mill elaborate command (no firtool patch needed), gitignored `build/`, and the `ysyx_00000000 cpu` instance all behave as recorded.

- Java 17.0.19 (Homebrew) and network access are available; `ysyxSoC/mill` wrapper exists (untracked in the submodule); `.mill-version` = 0.12.4. Mill loads `build.sc` but fails until `rocket-chip` is initialized: `make dev-init` runs `git submodule update --init --recursive` and then applies `patch/rocket-chip.patch` inside `rocket-chip`.
- `make verilog` additionally runs `patch/update-firtool.sh` (downloads firtool 1.105.0) and may not work; use the user-provided mill command above instead.
- `ysyxSoC/build/` is gitignored, so elaboration artifacts do not dirty the submodule.
- The generated SoC instantiates `ysyx_00000000 cpu (...)`; rename the module to `NPC` on a copy under our own build directory. `npc/rtl/NPC.v` ports already match `ysyxSoC/spec/cpu-interface.md` exactly; default `RESET_PC` is `0x20000000` (MROM base).
- Address map for this phase: MROM `0x20000000..0x20000fff` (AXI4MROM, DPI `mrom_read`, single-beat reads only, writes trigger a fatal assertion), SRAM `0x0f000000..0x0f001fff` (8KB AXI4RAM), UART16550 `0x10000000` (chars printed by `$write` in `perip/uart16550/rtl/uart_tfifo.v`; more than 16 chars needs divisor init + LSR THRE polling), flash XIP `0x30000000` (unused; `FAST_FLASH` is undefined by default), PSRAM `0x80000000` and SDRAM `0xa0000000` are unimplemented stubs (buses tied to `z`) — never access those windows.
- `AXI4Fragmenter` sits upstream of the MROM/SRAM xbar, so the icache's 16-byte INCR burst refill works unchanged against the single-beat MROM/SRAM slaves.
- Verilator SoC build needs: all `ysyxSoC/perip/**/*.v`, include dirs `perip/uart16550/rtl` + `perip/spi/rtl`, flags `--timescale "1ns/1ns" --no-timing`, C++ DPI `mrom_read()` + `flash_read()` (assert stub), and `Verilated::commandArgs(argc, argv)` before the sim loop.
- `ready-to-run/D-stage/ysyxSoCFull.v` has no MROM (D-stage boots from flash) — not a fallback for our `0x20000000` reset PC.
- Without debug ports the SoC harness cannot see retired `ebreak` or UART bytes (RTL `$write` goes straight to sim stdout): P9-S2 smokes terminate by cycle limit and check stdout; P9-S3 adds the debug/commit exposure patch (`ysyxSoC.patch`) for precise termination and DiffTest.
- NEMU DiffTest restoration needs MROM + SRAM regions (the P5-S1 region table) and MROM image sync to REF; the P5-S2 NPC-UART replay window at `0x10000000` must be checked to cover UART16550 register accesses (including LSR reads).
