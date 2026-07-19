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
- Phase 9 (`ysyxSoC Integration and AXI Validation`) is closed through `P9-S6: Phase 9 regression and closeout`.
- Phase 10 (`Pipeline and Targeted Performance Design`) is open after the P10-S10 separate-branch-comparator attempt on Linux. `npc/rtl/core/Core.v` remains at the accepted P10-S8 structure: selected 3-stage elastic in-order pipeline (`F/X/C`) plus IFU direct refill, ALU/branch comparator sharing, and split redirect decision/target state. P10-S8 passed spec smoke, directed/DiffTest regression, RT-Thread, and STA to a clean checked `680 MHz` (`690 MHz` fails by about `15 ps`). P10-S9 tried gating `xc_alu_result` with `wb_sel == NPC_WB_ALU`; it passed functional validation but regressed timing (`680 MHz` slack from `+0.006 ns` to `-0.073 ns`, reported top Fmax about `648.190 MHz`), so the RTL was reverted. P10-S10 tried separating branch comparators from `Exu`; it passed spec smoke, directed/DiffTest regression, and RT-Thread, but regressed PPA (`680 MHz` slack from `+0.006 ns` to `-0.165 ns`, reported top Fmax `611.624 MHz`, area `22528.520000` -> `22562.960000`), so the RTL was reverted and the restored spec smoke passed. See `notes/p10-design-review.md` sections 12 and 13.
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

## Phase 9 Session 3 status

`P9-S3: Debug/commit exposure patch and DiffTest restoration` is complete on the macOS host.

What was added:

- `ysyxSoC.patch` at the repo root routes `io_reset_pc`, `debug_*`, and `commit_*` from the `NPC` BlackBox up through `src/CPU.scala` → `src/SoC.scala` → `src/Top.scala` to the SoC top IO. Regenerate with `git -C ysyxSoC diff -- src/CPU.scala src/SoC.scala src/Top.scala > ysyxSoC.patch`.
- SoC re-elaborated with `NPC_DEBUG=1` ports exposed and post-processed with the macOS BSD sed commands (see the P9-S1 section); `npc/build/soc/ysyxSoCFull.v` is generated by `npc/Makefile`.
- `npc/csrc/soc_main.cpp` now drives `io_reset_pc`, detects retired `ebreak` via `io_debug_commit_inst == 0x00100073`, prints structured `NPC_RESULT`/`NPC_CSR`/`NPC_ICACHE` lines, and supports `--difftest-ref <nemu-so>`.
- `npc/csrc/difftest.cpp` gained a new overload so the SoC harness can pass the MROM image directly to the REF instead of going through the contiguous `Memory` copy path.
- NEMU memory map extended with MROM `0x20000000..0x20000fff` (loadable, not writable) and SRAM `0x0f000000..0x0f001fff` (loadable, writable); NEMU rebuilt with `SHARE=1`.
- `npc/Makefile` gained `test-soc-difftest`, which builds a small icache-burst program and runs it under event DiffTest.

Validation:

- `make -C npc soc-smoke` passes (output contains `SOC` and `NPC_RESULT status=limit reason=cycle_limit`).
- `make -C npc test-soc-difftest` passes: `NPC_DIFFTEST status=on`, `NPC_RESULT status=good reason=good_trap cycles=65 insts=19 pc=0x20000010`, `NPC_ICACHE accesses=19 hits=17 misses=2 refill_beats=8`.
- Existing standalone flows re-verified after the changes: `make -C npc smoke` (`NPC_RESULT status=bad reason=illegal_inst` at the empty-MROM reset vector, exit 0) and `make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke` (`NPC_SPEC_RESULT status=good reason=uart_eot cycles=61`, exit 0). Note `make -C npc clean` removes `build/soc`; rebuild the SoC flavor with `make -C npc soc` or `make -C npc test-soc-difftest`.

Open caveat:

- NEMU `.config` still has `# CONFIG_RVE is not set`; DiffTest may diverge for programs that touch x16-x31. The current icache test only uses x1/x2, so it passes.

## Phase 9 Session 4 status

`P9-S4: SRAM load/store validation (mem-test style)` is complete on the macOS host.

What was added:

- `npc/tests/make-soc-mem-bin.py`: generated RV32E MROM program that boots at `0x20000000`, uses `0x0f000000..0x0f001fff` as writable SRAM, prints `PASS\n` (or `FAIL\n`) through the UART16550 THR at `0x10000000` one byte at a time, and terminates with `ebreak`. It only uses `x0..x15` so the NEMU `# CONFIG_RVE is not set` caveat does not bite.
- The test exercises:
  - full 8KB word fill + word read-back across all 2048 words;
  - byte writes (`sb`) to each lane of a word and word read-back to verify `wstrb` byte-lane behavior and neighbor preservation;
  - halfword writes (`sh`) to both halves, word read-back, and `lhu` verification;
  - read-after-write on every access;
  - sign-extension sanity (`lb`/`lbu`).
- `npc/Makefile` gained `test-soc-mem`, which builds the SoC sim, generates the program, and runs it under event DiffTest with a 500k cycle limit.
- Small regression fix discovered while re-running the existing suite:
  - `npc/csrc/main.cpp`: the `NPC_DEBUG=1` `Simulator::step()` loop now returns `uart_eot` / `uart_expect_seen` after a committed UART MMIO write, matching the `NPC_DEBUG=0` path. Without this, `spec-smoke` terminated on the illegal instruction past the program.
  - `npc/Makefile`: `spec-smoke` now greps for `NPC_RESULT status=good reason=uart_eot` (the line printed by the debug-mode harness) instead of `NPC_SPEC_RESULT`, which is only emitted in the `NPC_DEBUG=0` build.

Validation:

- `make -C npc test-soc-mem` passes: output contains `PASS`, `NPC_DIFFTEST status=on`, and `NPC_RESULT status=good reason=good_trap cycles=98719 insts=26702 pc=0x20000198 a0=0x00000000`.
- SoC smoke re-verified: `make -C npc soc-smoke` (cycle-limit `SOC` smoke) and `make -C npc test-soc-difftest` (icache DiffTest smoke) still pass.
- Standalone regression re-verified after the harness fix:
  - `make -C npc smoke spec-smoke` passes.
  - `make -C npc test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-csr-trap test-rv32e-illegal test-difftest test-clint test-icache test-fencei test-debug test-axi-local test-access-fault` passes.

Open caveats:

- NEMU `.config` still has `# CONFIG_RVE is not set`; keep SoC DiffTest programs inside `x0..x15` until this is fixed.
- The SoC mem-test writes UART bytes one at a time with `sb` because the NEMU NPC-UART replay window is a single byte at `0x10000000`.

## Phase 9 Session 5 status

`P9-S5: AM riscv32e-ysyxsoc runtime and hello/dummy on SoC` is complete on the macOS host.

What was added/fixed:

- `abstract-machine/scripts/riscv32e-ysyxsoc.mk`, `abstract-machine/scripts/platform/ysyxsoc.mk`, `abstract-machine/scripts/ysyxsoc-linker.ld`, and `abstract-machine/am/src/riscv/ysyxsoc/trm.c`: minimal AM platform for ysyxSoC. Text/rodata live in MROM at `0x20000000`; stack/heap live in SRAM at `0x0f000000..0x0f001fff`; `putch()` initializes UART16550 divisor/FIFO/LCR and polls LSR THRE before writing THR; `halt()` exits through `ebreak`.
- `npc/rtl/core/Lsu.v` and `npc/rtl/bus/AxiMaster.v`: preserve UART16550 byte-register low address bits and issue byte-sized UART reads / byte- or halfword-/word-sized UART writes so UART DLL/DLM/FCR/LCR/LSR accesses reach the correct SoC peripheral offsets.
- `npc/csrc/soc_main.cpp`: reconstruct the true MMIO address from the retired load/store instruction and debug register state for DiffTest replay, because the committed bus address may be aligned in local paths and UART byte registers need exact offsets.
- `npc/csrc/memory.cpp`, `nemu/src/device/npc-dev.c`, and `nemu/src/memory/vaddr.c`: extend the NPC UART MMIO window/replay from one byte at `0x10000000` to the UART16550 register window `0x10000000..0x1000001f`.

Validation run before commit:

- `make -C npc soc-smoke test-soc-difftest test-soc-mem` passes. Representative final lines: `SOC` smoke reaches `NPC_RESULT status=limit reason=cycle_limit cycles=2000`; icache SoC DiffTest reaches `NEMU_RESULT status=good` and `NPC_RESULT status=good reason=good_trap cycles=65 insts=19 pc=0x20000010`; SoC SRAM mem-test prints `PASS` and reaches `NPC_RESULT status=good reason=good_trap cycles=98719 insts=26702 pc=0x20000198`.
- Local NPC regression command passes: `make -C npc smoke spec-smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-csr-trap test-rv32e-illegal test-difftest test-clint test-icache test-fencei test-debug test-axi-local test-access-fault`. Note `test-debug` intentionally includes bounded step/breakpoint outputs; the overall make command exited 0.
- AM SoC `dummy` passes with DiffTest using the macOS-compatible temporary Makefile wrapper and `CROSS_COMPILE=riscv64-elf-`: `NEMU_RESULT status=good state=2 halt_pc=0x20000060 halt_ret=0 insts=25` and `NPC_RESULT status=good reason=good_trap cycles=162 insts=25 pc=0x20000060`.
- AM SoC `hello` passes with DiffTest: `Hello, AbstractMachine!` and `mainargs = ''.` are printed through UART16550, followed by `NEMU_RESULT status=good state=2 halt_pc=0x20000108 halt_ret=0 insts=1347` and `NPC_RESULT status=good reason=good_trap cycles=6276 insts=1347 pc=0x20000108`.

Open caveats:

- The current AM `riscv32e-ysyxsoc` platform does not implement an LMA-to-VMA data copy boot path; keep broader AM/cpu-tests with writable globals for a later bootloader/data-relocation task.
- `am-kernels/tests/cpu-tests/Makefile` still uses `/bin/echo -e`, so on macOS use the temporary Makefile/`printf` wrapper for individual cpu-tests.
- The SoC integration still intentionally ignores PSRAM/SDRAM/flash XIP/GPIO/PS2/VGA/ChipLink.

## Phase 9 Session 6 / closeout status

`P9-S6: Phase 9 regression and closeout` is complete on the macOS host (Darwin 25.5.0 arm64, `riscv64-elf-` toolchain). Phase 9 is closed: AXI MROM fetch/refill, SRAM load/store, and UART16550 MMIO output paths are validated before entering Phase 10. No new functional bugs were found during this closeout run.

Validation run in this closeout:

1. SoC/AXI directed regression and memory test:

```sh
make -C npc soc-smoke test-soc-difftest test-soc-mem \
  REF_SO=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

Result: passed. Representative final lines:

- `soc-smoke`: prints `SOC`, `NPC_RESULT status=limit reason=cycle_limit cycles=2000 insts=974 pc=0x20000024`, `NPC_ICACHE accesses=974 hits=971 misses=3 refill_beats=12`.
- `test-soc-difftest`: `NEMU_RESULT status=good state=2 halt_pc=0x20000010 halt_ret=0 insts=19`; `NPC_RESULT status=good reason=good_trap cycles=65 insts=19 pc=0x20000010`; `NPC_ICACHE accesses=19 hits=17 misses=2 refill_beats=8`.
- `test-soc-mem`: prints `PASS`, `NEMU_RESULT status=good state=2 halt_pc=0x20000198 halt_ret=0 insts=26702`; `NPC_RESULT status=good reason=good_trap cycles=98719 insts=26702 pc=0x20000198`; `NPC_ICACHE accesses=26702 hits=22584 misses=4118 refill_beats=16472`.

Memory-test coverage: MROM program at `0x20000000` verifies the whole 8KB SRAM window `0x0f000000..0x0f001fff` with 2048-word fill/readback, byte and halfword `wstrb`, narrow loads/stores, read-after-write checks, and `lb`/`lbu` sign/zero extension. It runs under NEMU event DiffTest.

2. Standalone NPC directed regression:

```sh
make -C npc smoke spec-smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-csr-trap test-rv32e-illegal test-difftest test-clint \
  test-icache test-fencei test-debug test-axi-local test-access-fault \
  REF_SO=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

Result: passed. This includes local AXI memory tracing (`test-axi-local`), CLINT DiffTest/replay (`test-clint`), icache/fence.i, and access-fault DiffTest cases.

3. Full 35-test `cpu-tests` sweep with NEMU event DiffTest:

Result: all 35 passed using the portable macOS temporary-Makefile loop and `CROSS_COMPILE=riscv64-elf-`: `add`, `add-longlong`, `bit`, `bubble-sort`, `crc32`, `div`, `dummy`, `fact`, `fib`, `goldbach`, `hello-str`, `if-else`, `leap-year`, `load-store`, `matrix-mul`, `max`, `mersenne`, `min3`, `mov-c`, `movsx`, `mul-longlong`, `narcissistic`, `pascal`, `prime`, `quick-sort`, `recursion`, `select-sort`, `shift`, `string`, `sub-longlong`, `sum`, `switch`, `to-lower-case`, `unalign`, `wanshu`.

Representative outputs:

- `sum`: `NPC_RESULT status=good reason=good_trap cycles=1532 insts=528`, `NPC_ICACHE ... hit_rate_x1000=979 amat_x1000=1125`.
- `matrix-mul`: `NPC_RESULT status=good reason=good_trap cycles=543774 insts=131726`, `NPC_ICACHE ... hit_rate_x1000=660 amat_x1000=3034`.
- `crc32`: `NPC_RESULT status=good reason=good_trap cycles=67892 insts=18163`, `NPC_ICACHE ... hit_rate_x1000=740 amat_x1000=2557`.

4. Existing workload regression:

- NPC `hello` with NEMU event DiffTest passed: output contains `Hello, AbstractMachine!` and `mainargs = ''.`; `NEMU_RESULT status=good state=2 halt_pc=0x800000c4 halt_ret=0 insts=465`; `NPC_RESULT status=good reason=good_trap cycles=2116 insts=465 pc=0x800000c4`; `NPC_ICACHE ... hit_rate_x1000=638 amat_x1000=3167`.
- AM timer/devscan bounded smoke (`am-tests mainargs=d`) reached the expected cycle limit without DiffTest mismatch: `NPC_RESULT status=limit reason=cycle_limit cycles=80000000 insts=25000215 pc=0x80000a5c`; `NPC_ICACHE ... hit_rate_x1000=999 amat_x1000=1000`. The `make run` target exits nonzero because this workload is intentionally bounded by cycle limit; treat this as expected for this smoke.
- `yield-os` bounded smoke reached the expected cycle limit after printing `AB`: `NPC_RESULT status=limit reason=cycle_limit cycles=2000000 insts=624896`; `NPC_ICACHE ... hit_rate_x1000=999 amat_x1000=1001`. This infinite CTE workload also returns nonzero due to the deliberate bound.
- `thread-os` bounded smoke reached the expected cycle limit after printing eight `Thread-B on CPU #0` lines: `NPC_RESULT status=limit reason=cycle_limit cycles=12000000 insts=3746560`; `NPC_ICACHE ... hit_rate_x1000=999 amat_x1000=1003`. This infinite CTE workload also returns nonzero due to the deliberate bound.
- RT-Thread scripted shell `halt` with NEMU event DiffTest passed: output contains the RT-Thread banner, `Hello RISC-V!`, shell commands through `msh />halt`, `NEMU_RESULT status=good state=2 halt_pc=0x8000022c halt_ret=0 insts=511842`, and `NPC_RESULT status=good reason=good_trap cycles=1816964 insts=511842 pc=0x8001f718`; `NPC_ICACHE ... hit_rate_x1000=838 amat_x1000=1971`.
- CoreMark default `ITERATIONS=1000` remains a bounded performance smoke, not a terminating correctness check at the current budget: it printed `Running CoreMark for 1000 iterations` and reached `NPC_RESULT status=limit reason=cycle_limit cycles=120000000 insts=28427454`; no DiffTest mismatch was reported before the bound.

5. AM SoC workloads:

- `riscv32e-ysyxsoc` `dummy` passed with DiffTest: `NEMU_RESULT status=good state=2 halt_pc=0x20000060 halt_ret=0 insts=25`; `NPC_RESULT status=good reason=good_trap cycles=162 insts=25 pc=0x20000060`.
- `riscv32e-ysyxsoc` `hello` passed with DiffTest: output contains `Hello, AbstractMachine!` and `mainargs = ''.`; `NEMU_RESULT status=good state=2 halt_pc=0x20000108 halt_ret=0 insts=1347`; `NPC_RESULT status=good reason=good_trap cycles=6276 insts=1347 pc=0x20000108`; `NPC_ICACHE ... hit_rate_x1000=815 amat_x1000=2663`.

Current known limitations after closing Phase 9:

- The AM `riscv32e-ysyxsoc` platform still does not implement an LMA-to-VMA data copy boot path; broader SoC `cpu-tests` with writable globals remain a later bootloader/data-relocation task.
- The SoC integration intentionally ignores PSRAM/SDRAM/flash XIP/GPIO/PS2/VGA/ChipLink. PSRAM (`0x80000000`) and SDRAM (`0xa0000000`) stubs must not be accessed in Phase 9 flows.
- Keep `ysyxSoC.patch` at the repo root as the tracked patch for debug/commit exposure. Never commit inside the `ysyxSoC` submodule. Regenerate with `git -C ysyxSoC diff > ../ysyxSoC.patch`; apply on fresh checkouts with `git -C ysyxSoC apply ../ysyxSoC.patch`. The nested `rocket-chip` patch is still re-applied by `make -C ysyxSoC dev-init`.
- `am-kernels/tests/cpu-tests/Makefile` still uses `/bin/echo -e`; on macOS keep using the temporary `printf` Makefile loop for full `cpu-tests` sweeps.
- STA caveat remains: current timing is standalone core-top STA with only a core clock constraint; no SoC AXI input/output delays are modeled yet.
- `ysyxSoC/build/` and `npc/build/` outputs are generated; rebuild on the current platform before trusting binaries after a host switch.

## Phase 10 planning status

Phase 10 has been planned from the spec and current STA evidence. Key facts to preserve for the implementation session:

- Core spec constraints: RV32E_Zicsr, M-mode only, single core, in-order memory, no data cache/interrupts/VM/PMP/PMA, fixed 8-instruction FF icache with 16-byte lines and burst refill, `fence.i` clears icache, built-in CLINT only implements `mtime/mtimeh`.
- STA evidence from `build/p8-s3-close/rerun-sta-20260718`:
  - `NPC-610MHz` passes; `NPC-620MHz` fails.
  - `NPC-620MHz/NPC.rpt` worst setup endpoints are register-file destination flops such as `u_core.u_regfile.regs[2]_23__reg_p:D`, with representative path delay about `1.585 ns`, required about `1.564 ns`, slack about `-0.021 ns`, reported Fmax about `612 MHz`.
  - The path indicates a decode/control/PC/trap/AXI/CLINT/writeback cone feeding regfile write data/enable; this justifies a cut between decode/execute/request construction and precise commit/writeback, not a generic classic pipeline.
  - Register-file clock-gating checks are close at 620 MHz, so track clock-gating paths during P10 STA.
- Selected design: 3-stage elastic in-order `F/X/C` pipeline.
  - `F`: fetch PC and existing `Ifu` icache/refill producer; emits `{pc, inst, inst_error}` into F/X and handles redirects/flushes.
  - `X`: decode, register read, execute, branch target/condition, LSU request construction, CSR read/write inputs, preliminary exception cause; captures a complete commit packet into X/C.
  - `C`: waits for memory responses, performs precise register writeback, CSR/trap update, `fence.i` invalidation, redirect, halt/trap status, and `commit_*`/debug reporting.
- Required first hazards: C-to-X forwarding for pending register writes; conservative load-use stall/backpressure while C holds an incomplete load; redirect flush for branch/JAL/JALR/trap/`mret`; retirement-time `fence.i` invalidation.
- Area/PPA discipline:
  - Compare against P8-S3 physical baseline: chip area `22685.320000`, sequential area `8001.840000`, and `1299` DFFs as recorded in `notes/p8-timing-and-ppa.md`.
  - Keep the initial design to F/X and X/C packet registers plus necessary precise-commit control. Do not add a decode stage, branch predictor, prefetch queue, scoreboard, multi-outstanding memory, or data cache without measurement.
  - Judge success by performance per area: Fmax-only wins that add large mux/register overhead or worsen CPI need evidence.
- Rejected unless later measurement justifies them:
  - 4-stage `F/D/X/C`: more timing margin but more forwarding/flush/branch-penalty/area complexity.
  - Minimal writeback retiming: lower risk but likely does not improve CPI because it still does not overlap fetch and execute.

## Phase 10 Session 2 status

`P10-S2: Implement and smoke test` is complete on the macOS host (`CROSS_COMPILE=riscv64-elf-`). Per user request, this session intentionally skipped ysyxSoC connection tests and STA/PPA.

What changed:

- `npc/rtl/core/Core.v` was refactored from the previous single-instruction `inst_q/inst_valid` controller into explicit `F/X` and `X/C` pipeline state while keeping the `Core` port list and existing submodule interfaces stable.
- F stage now owns `f_pc`, uses the existing `Ifu` as the fetch/cache producer, captures `{pc, inst, inst_error}` into `F/X`, and flushes/drops younger fetch responses on C-stage redirects.
- X stage decodes, reads the async `RegFile`, applies C-to-X forwarding, computes branch/JAL/JALR targets, ALU result, LSU address/store data, CSR read data, and preliminary legality/exception metadata.
- C stage waits for LSU/CLINT/AXI memory completion, performs the single architectural update point (regfile writeback, CSR commit/trap update, `fence.i` invalidation, redirect, halt/trap status, and `commit_*` reporting), and backpressures younger stages while stalled.
- Conservative load-use stalling is implemented while C holds an incomplete load. C-to-X forwarding covers pending non-load writes and loads once the C-stage data is ready.
- `npc/Makefile` `test-debug` was updated for the new pipeline's startup/redirect timing: the scripted 2-retire debug checkpoints now use `run 10` / `--max-cycles 10` instead of the old single-instruction-controller 8-cycle assumption. Functional expectations are unchanged.

Validation completed:

1. P10-S2 directed and local standalone regression passed:

```sh
make -C npc smoke spec-smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-access-fault \
  test-clint test-icache test-fencei test-debug test-difftest test-axi-local
```

Representative results:

- `spec-smoke`: printed `SPEC`, `NPC_RESULT status=good reason=uart_eot cycles=54 insts=13`.
- `test-jalr-ebreak`: `NPC_RESULT status=good reason=good_trap cycles=27 insts=5 pc=0x00000120 x1=0x00000102`.
- `test-lw-sw`: `NPC_RESULT status=good reason=good_trap cycles=24 insts=5 x1=0x0000002a`.
- `test-clint`: `NPC_RESULT status=good reason=good_trap cycles=64 insts=19`, with DiffTest enabled and `NPC_ICACHE accesses=19 hits=14 misses=5`.
- `test-icache`: `NPC_RESULT status=good reason=good_trap cycles=56 insts=19`, `NPC_ICACHE accesses=19 hits=17 misses=2`.
- `test-fencei`: `NPC_RESULT status=good reason=good_trap cycles=49 insts=9`, `NPC_ICACHE accesses=9 hits=4 misses=5`.

2. AM `hello` passed with NEMU event DiffTest:

```sh
make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=2000000 \
  NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Output contained `Hello, AbstractMachine!` and `mainargs = ''.`; final lines included `NEMU_RESULT status=good ... insts=465` and `NPC_RESULT status=good reason=good_trap cycles=1985 insts=465 pc=0x800000c4`.

3. Full 35-test `cpu-tests` sweep passed with NEMU event DiffTest using the portable temporary-Makefile loop:

`add`, `add-longlong`, `bit`, `bubble-sort`, `crc32`, `div`, `dummy`, `fact`, `fib`, `goldbach`, `hello-str`, `if-else`, `leap-year`, `load-store`, `matrix-mul`, `max`, `mersenne`, `min3`, `mov-c`, `movsx`, `mul-longlong`, `narcissistic`, `pascal`, `prime`, `quick-sort`, `recursion`, `select-sort`, `shift`, `string`, `sub-longlong`, `sum`, `switch`, `to-lower-case`, `unalign`, `wanshu`.

Representative P10-S2 cycles vs P8-S3 baseline:

- `sum`: `cycles=1423`, `insts=528` (P8-S3 baseline `1532`).
- `string`: `cycles=3999`, `insts=1449` (P8-S3 baseline `4260`).
- `crc32`: `cycles=62105`, `insts=18163` (P8-S3 baseline `67892`).
- `quick-sort`: `cycles=11126`, `insts=3041` (P8-S3 baseline `11854`).
- `matrix-mul`: `cycles=519625`, `insts=131726` (P8-S3 baseline `543774`).

4. RT-Thread scripted shell `halt` passed with NEMU event DiffTest:

```sh
make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Final lines included `NEMU_RESULT status=good state=2 halt_pc=0x8000022c halt_ret=0 insts=511842` and `NPC_RESULT status=good reason=good_trap cycles=1724877 insts=511842 pc=0x8001f718`; `NPC_ICACHE accesses=511842 hits=428931 misses=82911 hit_rate_x1000=838 amat_x1000=2019`.

Current working tree notes:

- Intended source changes from this session: `npc/rtl/core/Core.v`, `npc/Makefile`, and `notes/next.md` / `notes/plan.md` if updated.
- `ysyxSoC` still appears modified as a submodule from previous P9 work; do not commit inside it and keep using the root `ysyxSoC.patch` workflow.
- Top-level untracked `kimi-debug-session_-20260718-152953.zip` and `kimi-export-session_-20260718-152956.md` are user/session artifacts; leave them alone unless the user explicitly asks.

## Next steps

1. Let the user revise the P10-S2 changes, then the user will make the commit. Do not commit automatically.
2. If continuing to `P10-S3`, run physical STA/PPA on the Linux toolchain and compare against the P8-S3 baseline (`area=22685.320000`, sequential area `8001.840000`, `1299` DFFs, 610 MHz pass / 620 MHz fail).
3. In P10-S3, optimize only from measurements: possible knobs are IFU hit path, C-stage regfile write-enable/data fanout, branch redirect penalty, load-result forwarding, and X/C packet bit trimming. Track area/reg-count/CPI alongside Fmax.
4. P10-S4 remains final full regression and closeout, including SoC `test-soc-difftest`, `test-soc-mem`, and AM `riscv32e-ysyxsoc` `dummy`/`hello` that were intentionally skipped in this P10-S2 session.
5. Do not commit inside the `ysyxSoC` submodule. Keep using the root `ysyxSoC.patch` workflow for SoC debug/commit exposure.

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

## Phase 10 Session 3 status

`P10-S3: Optimize timing and area` is complete on the Linux host.

What changed:

- `npc/rtl/core/Core.v`: removed the IFU-to-X/C direct-response bypass (`x_direct_valid`). Fetch responses now always enter the `F/X` register before decode/execute. This cuts the measured critical path from the IFU hit/refill data/tag cone through decode/regfile/ALU/next-PC logic into the `X/C` packet registers.
- `npc/Makefile`: widened tight single-instruction trap test cycle limits from 8 to 12 where the extra fetch-register transfer cycle is visible (`branch-misaligned`, `csr-readonly-illegal`, `rv32e-illegal`). Functional expectations are unchanged.
- `npc/Makefile`: `spec-smoke` now accepts both `NPC_RESULT ... uart_eot` and the spec-mode `NPC_SPEC_RESULT ... uart_eot` line.
- `npc/rtl/core/Core.v`: included `xc_inst` in the spec-mode unused reduction to keep `NPC_DEBUG=0` Verilator lint clean.
- `npc/rtl/core/Ifu.v`: wrapped the 64-bit icache performance counters (`accesses`, `hits`, `misses`, `miss_wait_cycles`, `refill_beats`) in `NPC_DEBUG`. Debug/DiffTest simulation still reports the counters, while `NPC_DEBUG=0` physical synthesis drops the unused counter flops and adders.
- Measured and rejected an attempted physical-only `xc_inst` packet trim: it reduced area to about `24200` but moved the 600 MHz path to about `-0.105 ns`, so `xc_inst` remains registered in physical mode.

Measured STA/PPA:

- P10-S2 pipeline Linux baseline (`build/p10-s3-baseline/pipeline`):
  - area `25971.120000`
  - `1625` DFFs
  - worst path endpoint examples: `u_core.xc_alu_result_0__reg_p:D`, `u_core.xc_normal_next_pc_*__reg_p:D`
  - worst path delay `2.182 ns`, reported Fmax about `449.147 MHz`
  - `500 MHz` failed by `-0.226 ns`
- P10-S3 optimized (`build/p10-s3-no-direct/pipeline`):
  - area `25376.400000` (`-594.720000`, `-2.29%` vs P10-S2 pipeline)
  - `1633` DFFs (`+8`)
  - worst path endpoint `u_core.xc_normal_next_pc_5__reg_p:D`
  - worst path delay `1.558 ns`, reported Fmax `623.649 MHz`
  - clean checked `600 MHz` (`+0.063 ns`), first failing checked `650 MHz` (`-0.065 ns`)
- P10-S3 area-counter-gate (`build/p10-s3-area-counter-gate/pipeline`):
  - area `24273.200000` (`-1103.200000`, `-4.35%` vs no-direct; `-1697.920000`, `-6.54%` vs P10-S2 pipeline)
  - `1603` DFFs (`-30` vs no-direct; `-22` vs P10-S2 pipeline)
  - worst path endpoint `u_core.xc_normal_next_pc_7__reg_p:D`
  - worst path delay `1.730 ns`, reported Fmax `562.903 MHz`
  - clean checked `560 MHz` (`+0.008 ns`), `600 MHz` fails by about `-0.111 ns`
  - Interpretation: keep this as the current area-optimized point because it removes physical-only debug counters and gives a larger area reduction. The tradeoff is lower Fmax than no-direct, but still above the original P10-S2 pipeline Fmax. Do not compare this directly against the P8-S3 single-cycle 610 MHz point without also accounting for the P10 pipeline CPI/area changes.

Performance tradeoff:

- `hello` with NEMU event DiffTest: `NPC_RESULT status=good reason=good_trap cycles=2153 insts=465`; this is slower than P10-S2 (`1985`) and slightly slower than P8-S3 (`2116`). `NPC_ICACHE accesses=465 hits=297 misses=168 miss_wait_cycles=1012 hit_rate_x1000=638 amat_x1000=3176`.
- RT-Thread scripted `halt` with NEMU event DiffTest: `NPC_RESULT status=good reason=good_trap cycles=1807788 insts=511842`; this is slower than P10-S2 (`1724877`) but still slightly better than P8-S3 (`1816964`). `NPC_ICACHE accesses=511842 hits=428931 misses=82911 miss_wait_cycles=521844 hit_rate_x1000=838 amat_x1000=2019`.
- Interpretation: the change is kept for now because it simultaneously removes the measured timing bottleneck and reduces area, but it costs a fetch-transfer cycle. If later workload CPI dominates, revisit with a better registered fast path rather than restoring the unregistered IFU-to-X/C bypass.

Validation completed:

1. Rebuilt the stale macOS NEMU REF for Linux using the documented `notes/platform-linux.md` sequence. `nemu/build/riscv32-nemu-interpreter-so` is now a Linux/aarch64 shared object again.
2. Refreshed RT-Thread AM generated paths with `make -C rt-thread-am/bsp/abstract-machine init` after `files.mk` still contained old `/Users/venti/...` paths.
3. Directed local/DiffTest checks passed after rebuilding debug mode:

```sh
make -C npc smoke spec-smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-access-fault \
  test-clint test-icache test-fencei test-debug test-difftest test-axi-local \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

A later rerun of the DiffTest-backed tail (`test-access-fault test-clint test-difftest`) passed after the NEMU REF rebuild; the full directed run passed through those same checks when the valid REF was present.

After the area-counter-gate change, the same directed command was rerun and passed. The debug `NPC_ICACHE` lines still reported non-zero counters in `NPC_DEBUG=1` simulation, confirming that only the physical `NPC_DEBUG=0` counter flops were removed.

4. Spec-mode smoke passed:

```sh
make -C npc NPC_DEBUG=0 spec-smoke
```

Output included `SPEC` and `NPC_SPEC_RESULT status=good reason=uart_eot cycles=57 limit=400`.

5. AM `hello` passed with NEMU event DiffTest:

```sh
make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
  AM_HOME=/host/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-linux-gnu- NPC_MAX_CYCLES=2000000 \
  NPC_DIFFTEST_REF=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

6. RT-Thread scripted shell `halt` passed with NEMU event DiffTest after rebuilding NPC in default debug mode:

```sh
make -C npc clean && make -C npc REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
  AM_HOME=/host/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-linux-gnu- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

## Phase 10 Session 4 status

`P10-S4: Regression, PPA check, and optimization note update` is complete on the Linux host. This is not a Phase 10 closeout; the current P10-S3 area-counter-gate RTL point is validated and measured, but more timing/area/CPI optimization remains.

Validation completed:

1. Default NPC directed/DiffTest regression passed after a clean debug rebuild:

```sh
make -C npc clean && make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest \
  test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

Representative final lines include `test-clint` `NPC_RESULT status=good reason=good_trap cycles=69 insts=19`, `test-icache` `cycles=58 insts=19`, and `test-fencei` `cycles=54 insts=9`.

2. Spec-mode smoke passed:

```sh
make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke
```

Output included `SPEC` and `NPC_SPEC_RESULT status=good reason=uart_eot cycles=57 limit=400`.

3. Full 35-test `cpu-tests` sweep with NEMU event DiffTest passed using Linux `CROSS_COMPILE=riscv64-linux-gnu-` and logs under `build/p10-close-tests/`:

`add`, `add-longlong`, `bit`, `bubble-sort`, `crc32`, `div`, `dummy`, `fact`, `fib`, `goldbach`, `hello-str`, `if-else`, `leap-year`, `load-store`, `matrix-mul`, `max`, `mersenne`, `min3`, `mov-c`, `movsx`, `mul-longlong`, `narcissistic`, `pascal`, `prime`, `quick-sort`, `recursion`, `select-sort`, `shift`, `string`, `sub-longlong`, `sum`, `switch`, `to-lower-case`, `unalign`, `wanshu`.

Representative counters:

- `sum`: `NPC_RESULT status=good reason=good_trap cycles=1434 insts=528`; `NPC_ICACHE ... hit_rate_x1000=979 amat_x1000=1132`.
- `string`: `cycles=4069 insts=1449`; `hit_rate_x1000=951 amat_x1000=1310`.
- `crc32`: `cycles=66820 insts=18163`; `hit_rate_x1000=740 amat_x1000=2586`.
- `quick-sort`: `cycles=11859 insts=3041`; `hit_rate_x1000=758 amat_x1000=2531`.
- `matrix-mul`: `cycles=564293 insts=131726`; `hit_rate_x1000=660 amat_x1000=3055`.

4. Required workloads passed / bounded as expected:

- AM `hello`: printed `Hello, AbstractMachine!`; `NEMU_RESULT status=good ... insts=465`; `NPC_RESULT status=good reason=good_trap cycles=2153 insts=465`; `NPC_ICACHE ... hit_rate_x1000=638 amat_x1000=3176`.
- RT-Thread scripted shell `halt`: output included `msh />halt`; `NEMU_RESULT status=good ... insts=511842`; `NPC_RESULT status=good reason=good_trap cycles=1807788 insts=511842`; `NPC_ICACHE ... hit_rate_x1000=838 amat_x1000=2019`.
- CoreMark default `ITERATIONS=1000`: bounded performance smoke only, reached `NPC_RESULT status=limit reason=cycle_limit cycles=120000000 insts=27877841`; `NPC_ICACHE ... hit_rate_x1000=676 amat_x1000=2991`.

5. SoC regression passed:

```sh
make -C npc soc-smoke test-soc-difftest test-soc-mem \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

Representative results:

- `soc-smoke`: printed `SOC`, then expected cycle limit: `NPC_RESULT status=limit reason=cycle_limit cycles=2000 insts=653`.
- `test-soc-difftest`: `NEMU_RESULT status=good ... insts=19`; `NPC_RESULT status=good reason=good_trap cycles=73 insts=19 pc=0x20000010`; `NPC_ICACHE ... hit_rate_x1000=894 amat_x1000=1947`.
- `test-soc-mem`: printed `PASS`; `NEMU_RESULT status=good ... insts=26702`; `NPC_RESULT status=good reason=good_trap cycles=98706 insts=26702 pc=0x20000198`; `NPC_ICACHE ... hit_rate_x1000=845 amat_x1000=2388`.

6. AM SoC workloads passed with DiffTest:

- `riscv32e-ysyxsoc` `dummy`: `NEMU_RESULT status=good state=2 halt_pc=0x20000060 halt_ret=0 insts=25`; `NPC_RESULT status=good reason=good_trap cycles=162 insts=25 pc=0x20000060`; `NPC_ICACHE ... hit_rate_x1000=640 amat_x1000=4480`.
- `riscv32e-ysyxsoc` `hello`: printed `Hello, AbstractMachine!` and `mainargs = ''.`; `NEMU_RESULT status=good state=2 halt_pc=0x20000108 halt_ret=0 insts=1344`; `NPC_RESULT status=good reason=good_trap cycles=6298 insts=1344 pc=0x20000108`; `NPC_ICACHE ... hit_rate_x1000=814 amat_x1000=2786`.

PPA / timing recheck:

- Output root: `build/p10-close-ppa/final-phys/`.
- Current measured point: P10-S3 area-counter-gate physical RTL (`NPC_DEBUG=0`, physical top, `icsprout55`).
- Area: `24273.200000`.
- Sequential area: `9874.480000` (`40.68%`).
- DFFs: `1603`; ICGs: `17`.
- Reported Fmax: `562.903 MHz`.
- Checked sweep:
  - `560 MHz`: slack `+0.008 ns`.
  - `562 MHz`: slack `+0.002 ns`.
  - `563 MHz`: slack `-0.001 ns`.
  - `570 MHz`: slack `-0.023 ns`.
  - `600 MHz`: slack `-0.111 ns`.
- Worst endpoint: `u_core.xc_normal_next_pc_7__reg_p:D`; worst path delay `1.730 ns`.
- iEDA power remains a rough toggle-based standalone estimate; for example `560 MHz` reported `1.58286 W`, `600 MHz` `1.64676 W`, and `1100 MHz` `2.44051 W`. Treat this like the P8 note: useful only as a relative early estimate because many SoC-facing nets are unloaded/no-load in standalone STA.

Timing/area optimization record:

- Initial P10-S2 pipeline STA on Linux exposed a timing-hostile unregistered IFU direct-response path: IFU hit/refill data and tag comparison fed directly through decode/regfile/ALU/next-PC logic into `X/C` packet registers such as `xc_alu_result` and `xc_normal_next_pc`. That point had area `25971.120000`, `1625` DFFs, worst path delay about `2.182 ns`, reported Fmax about `449.147 MHz`, and failed `500 MHz` by `-0.226 ns`.
- Timing optimization: remove the IFU-to-X/C direct-response bypass (`x_direct_valid`) so every fetch response is captured in the `F/X` register before decode/execute. This cut the critical IFU->X/C cone and moved the optimized point to area `25376.400000`, `1633` DFFs, worst path delay `1.558 ns`, reported Fmax `623.649 MHz`, clean checked `600 MHz`, first failing checked `650 MHz`.
- Area optimization: wrap the 64-bit icache performance counters in `NPC_DEBUG` so physical `NPC_DEBUG=0` synthesis drops debug-only counter flops/adders while debug simulation still prints `NPC_ICACHE`. This reduced area to `24273.200000` and DFFs to `1603`, at the cost of settling at the current reported Fmax `562.903 MHz`.
- Rejected optimization: physical-only `xc_inst` packet trimming reduced area to about `24200`, but worsened the 600 MHz timing path to about `-0.105 ns`, so `xc_inst` remains registered in physical mode.

Comparison / interpretation:

- Against P8-S3 single-cycle-like baseline: area increased `22685.320000 -> 24273.200000` (`+1587.88`, about `+7.0%`), sequential area increased `8001.840000 -> 9874.480000`, DFFs increased `1299 -> 1603`, and standalone Fmax decreased from reported `614.531 MHz` to `562.903 MHz`.
- Workload CPI is mixed after the P10-S3 area/timing changes: RT-Thread is still slightly better than P8-S3 (`1807788` vs `1816964` cycles), but `hello` and several representative `cpu-tests` are not a clear win versus P8-S3.
- Do not close P10 from this point. Continue optimizing from measured bottlenecks: next-PC/X-C packet timing, CPI lost to the registered fetch path, branch/redirect penalty, load-use behavior, and physical-only state/fanout.

Current working tree notes:

- Intended P10 source changes include `npc/rtl/core/Core.v`, `npc/rtl/core/Ifu.v`, `npc/Makefile`, `notes/plan.md`, and `notes/next.md`.
- Generated outputs under `npc/build/`, `build/p10-close-tests/`, and `build/p10-close-ppa/` should not be committed unless explicitly desired.
- `ysyxSoC` still appears modified as a submodule from prior P9 work; do not commit inside it. Keep using the root `ysyxSoC.patch` workflow.

Next steps:

1. Commit the validated P10 pipeline/timing-area checkpoint now, per user request.
2. Continue P10 optimization after the commit. Start from measured bottlenecks: next-PC/X-C packet timing, CPI lost to the registered fetch path, branch/redirect penalty, load-use behavior, and physical-only state/fanout.

## Phase 10 Session 5: STA-driven area and timing optimization

Date: 2026-07-19
Platform: Linux

### Starting point

P10-S3 area-counter-gate pipeline point (committed/validated in P10-S4):
- Area `24273.200000`, DFFs `1603`, ICGs `17`
- Fmax `562.903 MHz` under `icsprout55` with `DELAY 4`
- Clean checked target `560 MHz` (`+0.008 ns`)
- Critical path: `F/X inst register -> regfile read -> branch compare -> xc_normal_next_pc register`
- Workload CPI mixed vs P8 single-cycle; RT-Thread still slightly better

### Comparison baseline

| Design | Area | DFFs | ICGs | Fmax | Clean target | Notes |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| P8-S3 single-cycle | 22685.32 | 1299 | 15 | 614.531 MHz | 610 MHz | Pre-pipeline |
| P10-S2 pipeline | 25971.12 | 1625 | 15 | 449.147 MHz | - | Unregistered IFU->X/C path |
| P10-S3 no-direct | 25376.40 | 1633 | 15 | 623.649 MHz | 600 MHz | Registered IFU response |
| P10-S3 area-counter-gate | 24273.20 | 1603 | 17 | 562.903 MHz | 560 MHz | Debug counters gated |
| **P10-S5 optimized** | **24124.52** | **1603** | **17** | **579.331 MHz** | **570 MHz** | This session |

### STA analysis

Fresh sweep of the P10-S4 point confirmed the critical path is the X-stage next-PC computation:
- Launch: `u_core.ifu_inst_*__MUX2X0P5H7L_B_Y_DFFQX1H7L_D:CK` (F/X instruction register)
- Capture: `u_core.xc_normal_next_pc_*__reg_p:D` (X/C next-PC register)
- Path delay `1.730 ns` at `560 MHz`
- Largest segments: regfile read address buffering + read mux (~0.77 ns), branch comparison (~0.59 ns), next-PC final mux (~0.24 ns)

Second-worst paths have large positive slack, so the next-PC/ALU path is the only real bottleneck.

Rejected experiment: removing the explicit x0 mux in `RegFile.v` (`assign rdata = regs[raddr]`) worsened both area and timing (area `24321.64`, Fmax `543.0 MHz`), so it was reverted.

### Implemented optimizations

1. **Remove `xc_inst` register in `NPC_DEBUG=0`**
   - Wrapped declaration and assignment in `` `ifdef NPC_DEBUG ``
   - Removed `xc_inst` from the spec-mode unused reduction
   - Result: area `24273.20 -> 24120.88`, Fmax `562.9 -> 576.7 MHz`
   - Functional validation passed; the register had non-zero physical fanout that synthesis could not fully eliminate

2. **Qualify `c_wb_wen` with `xc_rd != 0` and simplify forwarding match**
   - Since `xc_rd` is never zero when writeback is real (x0 writes are suppressed at the register file), including `xc_rd != 0` in `c_wb_wen` lets the forwarding dependency check drop its explicit `rs1/rs2 != 0` term
   - Result: area essentially unchanged (`24120.88 -> 24124.52`), Fmax `576.7 -> 579.3 MHz`
   - Critical path moved from `xc_normal_next_pc` to `xc_alu_result_31`

### Combined PPA result

| Metric | P10-S4 | P10-S5 | Delta |
| --- | ---: | ---: | ---: |
| Area | 24273.20 | 24124.52 | -148.68 (-0.61%) |
| DFFs | 1603 | 1603 | 0 |
| ICGs | 17 | 17 | 0 |
| Fmax | 562.903 MHz | 579.331 MHz | +16.428 MHz (+2.92%) |
| Clean target | 560 MHz | 570 MHz | +10 MHz |
| Slack @ 570 MHz | -0.023 ns | +0.028 ns | +0.051 ns |

Synthesis command used:

```sh
make -C npc sta STA_O=../build/p10-optimize/final-570 CLK_FREQ_MHZ=570
```

### Validation completed

1. Debug-mode directed/DiffTest regression passed:

```sh
make -C npc clean && make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest \
  test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

2. Spec-mode smoke passed (`NPC_DEBUG=0`):

```sh
make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke
```

Output included `NPC_SPEC_RESULT status=good reason=uart_eot cycles=57 limit=400`.

3. Full 35-test `cpu-tests` sweep passed with NEMU event DiffTest.

4. RT-Thread scripted shell `halt` passed:

```sh
make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
  AM_HOME=/host/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-linux-gnu- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Result: `NEMU_RESULT status=good ... insts=511842`; `NPC_RESULT status=good reason=good_trap cycles=1807788 insts=511842`.

5. AM `hello` passed: printed `Hello, AbstractMachine!`, `NPC_RESULT status=good reason=good_trap cycles=2153 insts=465`.

6. SoC regression passed:

```sh
make -C npc soc-smoke test-soc-difftest test-soc-mem \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

### Files modified

- `npc/rtl/core/Core.v`

No changes to `npc/rtl/core/RegFile.v` (x0-mux experiment reverted).

### Next steps

1. The remaining bottleneck is the X-stage path from F/X instruction register through regfile read and ALU/branch to the X/C registers. The biggest segment is the regfile read (~0.77 ns) followed by the ALU/branch computation (~0.59-1.0 ns).
2. The highest-impact next optimization is to move the register-file read into the F/X stage:
   - Read `rs1`/`rs2` from the register file using `fx_inst` in the F/X stage
   - Register the read values as `fx_rs1_data`/`fx_rs2_data`
   - Forward from the C stage to the F/X stage instead of the X stage
   - Adjust load-use stall detection to cover the new read timing
   - This removes the regfile-read delay from both the ALU and next-PC critical paths and should push Fmax well above 600 MHz, at the cost of 64 extra F/X register bits and more complex hazard logic.
3. Continue measuring CPI after each major pipeline change; if CPI regressions dominate, revisit the fetch/direct path or add a small instruction queue.
4. Re-evaluate area after the regfile-read move; look for further reductions in unused physical-only state and X/C register width.

## Phase 10 Session 6: Design review and structured optimization

Date: 2026-07-19
Platform: Linux

### Starting point

P10-S5 optimized pipeline point:
- Area `24124.52`, DFFs `1603`, ICGs `17`
- Fmax `579.331 MHz` under `icsprout55`
- Clean checked target `570 MHz`
- Critical path: F/X instruction register → decode → regfile read → forwarding mux → branch compare → `xc_normal_next_pc`

### Feedback addressed

Previous P10-S5 optimization was report-driven: small edits to `xc_inst` gating and forwarding-match qualification gave only modest gains. The user's feedback requested a deeper, module-by-module review of the RTL rather than random critical-path edits.

A full design review was written to `notes/p10-design-review.md`. Key findings:

1. **`Wbu.v` is dead logic** — just `assign wdata = alu_result`; should be removed.
2. **The dominant timing bottleneck is the X-stage register-file read**. Moving the read into the F/X stage removes ~0.77 ns from the ALU/branch critical path.
3. **The X/C packet is bloated**: `xc_normal_next_pc` (32 flops), `xc_rs1_data`/`xc_rs2_data` (64 flops), `xc_lsu_addr` (32 flops), `xc_csr_rdata` (32 flops) are stored for every instruction but not all are needed for every instruction.
4. **IFU refill-word shadow registers** (`refill_word*_q`, 128 flops) can be eliminated by writing cache data directly per beat.
5. **CPI losses** include the registered-IFU-response bubble, branch redirect bubble, load-use stall, and LSU-priority arbitration.

### Optimization plan

1. **Step 1 — remove `Wbu.v`**: route `wb_data` directly from the `Core.v` writeback mux.
2. **Step 2 — move regfile read to F/X**:
   - Add `fx_rs1_data`/`fx_rs2_data` registers.
   - Read `RegFile` using `fx_inst` decode in the F/X stage.
   - Forward from C stage to F/X, and handle X→F/X forwarding / stall for same-cycle producer-in-X hazards.
   - Adjust load-use stall to operate on F/X operands.
3. **Step 3 — reduce X/C packet size** after timing is fixed (e.g., remove/recompute `xc_normal_next_pc`).
4. **Step 4 — IFU refill shadow-register removal**.
5. **Step 5 — CPI improvements** (prefetch buffer, arbitration policy) only after PPA targets are met.

### Validation plan

After each RTL change:
1. `make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke`
2. Directed debug/DiffTest regression including `test-clint test-icache test-fencei test-access-fault`.
3. Full `cpu-tests` sweep.
4. RT-Thread scripted `halt`.
5. STA frequency sweep to measure area/timing impact.

### Notes

- Do not modify `ysyxSoC/` or `am-kernels/`.
- Keep changes minimal and validated per step; do not stack unverified optimizations.

## Phase 10 Session 6 (continued): 4-stage experiment, revert, and revised plan

Date: 2026-07-19
Platform: Linux

### 4-stage F/D/X/C experiment

Following the design review, the first structural timing optimization attempted was to add a Decode/Register-Read stage between F and X, creating a 4-stage pipeline `F/D/X/C`:

- Added `fx_rs1_data`/`fx_rs2_data` registers.
- Moved `Idu` decode and `RegFile` read into the new D stage.
- Kept X stage as ALU/branch/LSU-address.
- Forwarded C-stage writeback to D stage.
- Added `x_to_d_forward` for an instruction in X producing a result consumed by the instruction in D.
- Adjusted load-use stall, redirect, and fetch-accept logic for the extra stage.

**Area/timing result (P10-S6 4-stage)**:

| Metric | 3-stage baseline (P10-S5) | 4-stage | Delta |
| --- | ---: | ---: | ---: |
| Area | 24124.52 | 25665.08 | +1540.56 (+6.4%) |
| DFFs | 1603 | ~1700 | +~100 |
| Fmax | 579.331 MHz | 807.796 MHz | +228.5 MHz (+39%) |
| Clean target | 570 MHz | ~760–780 MHz | +~200 MHz |

**CPI result**: CPI regressed enough that wall-clock time per instruction worsened despite the large frequency gain. The extra stage inserted a bubble on taken branches/jumps and complicated the hazard logic. `cpu-tests` at the default 100k cycle limit failed three tests that passed on the 3-stage; at 500k only `matrix-mul` still failed because its instruction count exceeded the expanded limit.

**Decision**: revert the 4-stage pipeline. Frequency gains are meaningless when CPI regresses proportionally or more. The correct path is module-level optimizations that do not inflate the branch/misprediction bubble.

### Reverted 3-stage baseline

`npc/rtl/core/Core.v` was restored to the P10-S5 3-stage version (commit `75c8ccc`) with two intentional changes retained:

1. `Wbu.v` remains removed: `assign wb_data = c_wb_mux;` in `Core.v`.
2. The `ifu_valid` deadlock fix remains: `.ifu_valid(ifu_bus_valid)` in the `AxiArbiter` instantiation.

`npc/rtl/core/Wbu.v` is deleted. `npc/Makefile` `test-debug` expectations were restored to the 3-stage timing (`--expect-x1 0x100`, `insts=1`, `pc=0x104 retired=1`).

**Validation after revert**:
- Directed debug/DiffTest regression passes.
- `cpu-tests` at 100k fails the same three tests the 4-stage failed (`narcissistic`, `prime`, `matrix-mul`), confirming the failures are due to cycle limits, not the 4-stage logic.
- `cpu-tests` at 500k passes all except `matrix-mul` (116,715 instructions, needs >600k cycles).
- SoC regression (`soc-smoke`, `test-soc-difftest`, `test-soc-mem`) passes.

**STA baseline after revert** (full sweep completed):

| Frequency | Worst slack | Status |
| ---: | ---: | --- |
| 100 MHz | +8.178 ns | pass |
| 300 MHz | +1.511 ns | pass |
| 500 MHz | +0.178 ns | pass |
| 560 MHz | -0.037 ns | fail |
| 580 MHz | -0.098 ns | fail |
| 600 MHz | -0.156 ns | fail |

- Area: `24119.20` (matches P10-S5 ~24124).
- Critical path: `F/X instruction register → regfile read → forwarding mux → branch compare → xc_normal_next_pc`.
- Path delay: `1.794 ns`.
- Fmax: `548.891 MHz`.
- Clean target: `540 MHz`.

The reverted baseline is close to P10-S5 in area but shows a lower Fmax than the P10-S5 report (~579 MHz). The critical path moved from `xc_alu_result` in P10-S5 to `xc_normal_next_pc` here, likely due to synthesis-tool variation and the small RTL changes retained after the revert. The area match confirms the design is structurally back to the 3-stage baseline; the next optimizations will be measured against this reverted baseline.

### Revised optimization plan (CPI-neutral first)

Instead of adding pipeline stages, attack structural inefficiencies module by module:

1. **Remove IFU refill-word shadow registers** (`npc/rtl/core/Ifu.v`):
   - The four 32-bit `refill_word*_q` registers (128 flops) assemble a cache line before writing it.
   - Write each refill beat directly into the selected cache data register instead.
   - Read the requested instruction from the cache data registers (using `bus_rdata` for the current beat when `miss_offset_q` matches the final beat).
   - Expected impact: ~128 fewer flops, small area win, no CPI change.

2. **Share branch comparator with ALU SLT/SLTU** (`npc/rtl/core/Exu.v` and `Core.v`):
   - `Exu.v` already computes signed/unsigned less-than for `SLT`/`SLTU`.
   - `Core.v` duplicates the same comparison for branches.
   - Export `less_signed`, `less_unsigned`, and `equal` from `Exu.v`; use them for both ALU results and branch-taken logic.
   - Expected impact: removes a separate comparison tree, modest area win, may slightly relax routing.

3. **Review CSR read path** (`npc/rtl/core/Csr.v`):
   - Confirm whether the combinational CSR read mux contributes to any setup path.
   - If it does, consider registering the read result earlier or simplifying the mux.

4. **Revisit X/C packet width** only after the above:
   - `xc_normal_next_pc`, `xc_rs1_data`/`xc_rs2_data`, `xc_lsu_addr`, `xc_csr_rdata` are candidates for specialization or recomputation.
   - Any packet reduction must not add combinational delay to the critical path.

5. **CPI optimizations last** (prefetch buffer, fairer arbitration, branch prediction) once timing and area targets are met.

## Phase 10 Session 7: CPI-neutral structural optimization attempts

The session followed the user's requested discipline: first reason from RTL structure, then make one targeted optimization attempt, validate functionality, measure PPA, and record whether it actually helped.

### Attempt 1: IFU refill shadow-register removal

Implemented in `npc/rtl/core/Ifu.v` before the comparator-sharing work:

- Removed the four 32-bit `refill_word*_q` shadow registers.
- Refill beats now write directly into the selected cache data registers.
- `refill_inst` is formed from already-written cache registers plus current `bus_rdata` for the last requested beat.

Measured result against the reverted 3-stage baseline:

- Area improved from `24119.2` to `22775.2` (`-1344.0`, about `-5.6%`).
- DFF count dropped from `1603` to `1475`, exactly matching the 128-flop removal.
- 620 MHz slack improved from about `-0.210 ns` to about `-0.060 ns`, but 620 MHz still did not close.

Decision: keep this change. It is a real structural area win and does not introduce a CPI-cost mechanism.

### Attempt 2: comparator sharing between branch logic and ALU

Implemented in `npc/rtl/core/Exu.v` and `npc/rtl/core/Core.v`:

- `Exu.v` exports `equal`, `less_signed`, and `less_unsigned`.
- `SLT`/`SLTU` use the exported less-than facts.
- `Core.v` branch-taken logic uses the same facts for `BEQ`/`BNE`/`BLT`/`BGE`/`BLTU`/`BGEU`.
- Important fix: branch instructions must force `alu_src2 = x_rs2_data`; otherwise the shared comparison would compare `rs1` against the B-immediate because branch decode normally marks `src2_imm`.

Validation after the fix:

```sh
make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke
make -C npc clean && make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest \
  test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

Both passed.

PPA command:

```sh
make -C npc sta-sweep \
  STA_O=../build/p10-s7-compare-share/ppa \
  STA_LOG_DIR=../build/p10-s7-compare-share/logs \
  STA_FREQS="560 570 580 600 620 640"
```

Measured result against P10-S6 IFU point:

| Metric | P10-S6 IFU | P10-S7 comparator sharing | Delta |
| --- | ---: | ---: | ---: |
| Area | `22775.200000` | `22547.280000` | `-227.920000` (`-1.0%`) |
| Sequential area | `9086.000000` | `9086.000000` | `0` |
| `DFFQX1H7L` | `1475` | `1475` | `0` |
| Clean checked target | `580 MHz` | `570 MHz` | `-10 MHz` |
| 580 MHz worst slack | `+0.052 ns` | `-0.010 ns` | `-0.062 ns` |
| 600 MHz worst slack | `-0.006 ns` | `-0.068 ns` | `-0.062 ns` |
| 620 MHz worst slack | `-0.060 ns` | `-0.122 ns` | `-0.062 ns` |
| 640 MHz worst slack | `-0.110 ns` | `-0.172 ns` | `-0.062 ns` |

Interpretation: comparator sharing is an area win but not a timing win. The likely structural reason is that sharing forces branch comparison behind the ALU operand-select mux and gives the comparator a broader fanout context; the old duplicated branch comparator was wasteful but sat directly on `x_rs1_data/x_rs2_data`.

### Attempt 3: split redirect decision from redirect target

Implemented in `npc/rtl/core/Core.v` after user review:

- Replaced `xc_normal_next_pc` with `xc_redirect` plus `xc_redirect_pc`.
- C stage now computes sequential `pc+4` from `xc_pc` and selects `xc_redirect_pc` only when `xc_redirect` is set.
- `redirect` now uses the explicit `xc_redirect` control bit instead of a full-width `c_next_pc != c_pc_plus_4` comparison.

Why this was chosen: P10-S7 STA showed the worst endpoint at `xc_normal_next_pc_*`; the old RTL forced branch-taken control into a 32-bit target-vs-`pc+4` mux. The target does not depend on the comparison, only the decision does, so splitting the decision and target is a structural hardware optimization rather than random endpoint editing.

Validation passed:

```sh
make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke
make -C npc clean && make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest \
  test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
  AM_HOME=/host/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-linux-gnu- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Representative results:

- Spec smoke: `NPC_SPEC_RESULT status=good reason=uart_eot cycles=57 limit=400`.
- RT-Thread: `NPC_RESULT status=good reason=good_trap cycles=1807800 insts=511842`.

PPA result against P10-S7 comparator sharing:

| Metric | P10-S7 | P10-S8 redirect split | Delta |
| --- | ---: | ---: | ---: |
| Area | `22547.280000` | `22528.520000` | `-18.760000` (`-0.08%`) |
| `DFFQX1H7L` | `1475` | `1476` | `+1` |
| Clean checked target | `570 MHz` | `680 MHz` | `+110 MHz` |
| 580 MHz worst slack | `-0.010 ns` | `+0.260 ns` | `+0.270 ns` |
| 640 MHz worst slack | `-0.172 ns` | `+0.098 ns` | `+0.270 ns` |
| 680 MHz worst slack | not checked | `+0.006 ns` | — |
| 690 MHz worst slack | not checked | `-0.015 ns` | — |

Decision pending user revision: keep P10-S8 unless the user objects. This attempt is successful: it improved timing substantially, slightly reduced area, and did not change the pipeline/CPI policy.

### Immediate next action

Stop for user revision, as requested. If the user approves continuing, do not immediately make another random STA-driven edit. Re-open the module-level review in `notes/p10-design-review.md` and pick the next optimization by hardware structure. Good candidates after P10-S8:

- Area-oriented X/C packet specialization (`xc_rs1_data` only needed for CSR source, `xc_rs2_data` only for store data), but avoid adding new X-stage mux delay.
- CPI-oriented fetch buffering or AXI arbitration, but only after estimating whether CPI gain offsets area/timing cost.
- Re-check current STA endpoints first: after P10-S8 the worst max endpoint is `xc_alu_result_20__reg_p:D` at `1.419 ns`, not the removed `xc_normal_next_pc` path.

`notes/p10-design-review.md` contains the full module-by-module hardware-mapping analysis and all three attempt results.


## Phase 10 Session 9: 4-stage IF-ID-EX-WB pipeline with shared adder and redirect-state reduction

Date: 2026-07-19
Platform: Linux

### Starting point

P10-S8 3-stage pipeline point:
- Area `22528.520000`, DFFs `1476`, ICGs `17`
- Clean checked target `680 MHz` under `icsprout55`
- Critical path: F/X instruction register → RegFile read → forwarding mux → ALU → `xc_alu_result`

### Analysis and optimization rationale

The previous optimizations only shaved small delays because the fundamental problem was structural: the X stage contained decode, register-file read, operand forwarding, ALU, branch comparison, target selection, LSU address, and CSR read all in one cycle. The register-file read plus ALU formed a ~1.4 ns combinational chain.

To make a large timing improvement, the chain must be cut by a pipeline register. The chosen approach is a clean **4-stage IF-ID-EX-WB pipeline**:

- **F**: fetch (unchanged IFU interface).
- **D**: decode `fd_inst`, read the register file, apply W→D operand forwarding, capture operands and control into the D/X boundary.
- **X**: execute — ALU, branch/jump comparison and target selection, LSU address, CSR read. Branches/jumps/`mret` redirect from this stage.
- **W**: memory access, writeback mux, CSR commit, trap handling, register-file write. Traps and `fence.i` redirect from this stage.

Key structural decisions:

1. **Branch/jump resolved in X, not D.** Resolving in D would require forwarding an X-stage ALU result back into D in the same cycle, recreating a long path. Resolving in X keeps D short and still gives only a 1-cycle taken-branch penalty (the instruction in D is flushed).
2. **Single shared adder in X.** The previous design had separate adders for ALU ADD/SUB, LSU address, `jalr_target`, `jal_target`, and `branch_target`. All of these are produced in X, so they share one 32-bit adder with input muxing. The comparator shares the same input mux.
3. **Remove redirect state from the spec-mode X/W packet.** Because branches/jumps redirect in X, the target is consumed immediately. `xw_redirect` and `xw_redirect_pc` are kept only in `NPC_DEBUG=1` for DiffTest/debug output; `NPC_DEBUG=0` synthesis drops them.

### Implementation

Changed `npc/rtl/core/Core.v` only:
- Added F/D and D/X register sets; renamed X/C to X/W.
- Moved `Idu` decode and `RegFile` read to D stage.
- Added W→D operand forwarding and W-stage load-use stall detection.
- Implemented shared adder and target selection in X.
- Moved branch/jump/`mret` redirect to X; traps/`fence.i` redirect remain in W.
- Updated debug/commit outputs to use `xw_redirect`/`xw_redirect_pc` for `commit_next_pc`.

No functional changes to `Ifu.v`, `Idu.v`, `Exu.v`, `RegFile.v`, `Csr.v`, `Lsu.v`, `Clint.v`, `AxiArbiter.v`, `AxiMaster.v`, or `NPC.v`.

### Bugs fixed during validation

1. `x_redirect` was not gated by `x_valid`. After a redirect, stale D/X control bits kept `x_redirect` asserted for extra cycles, deadlocking fetch.
2. Branch comparison used `dx_src2_imm`, which is `1` for branches, causing the comparator to compare `rs1` against the I-immediate instead of `rs2`. Forced `x_alu_src2 = x_rs2_data` for branch instructions.
3. `commit_next_pc` initially used only `w_next_pc`, which is `pc+4` for non-trap instructions. DiffTest requires the actual redirect target for branches/jumps, so `xw_redirect`/`xw_redirect_pc` were restored (debug-only).

### Validation completed

1. Spec-mode smoke passed:
   ```sh
   make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke
   ```
   Result: `NPC_SPEC_RESULT status=good reason=uart_eot cycles=63 limit=400`.

2. Full directed debug/DiffTest regression passed:
   ```sh
   make -C npc clean && make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
     test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest \
     test-clint test-icache test-fencei test-access-fault \
     REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
   ```

3. Full 35-test `cpu-tests` sweep with NEMU event DiffTest passed:
   - `add`, `add-longlong`, `bit`, `bubble-sort`, `crc32`, `div`, `dummy`, `fact`, `fib`, `goldbach`, `hello-str`, `if-else`, `leap-year`, `load-store`, `matrix-mul`, `max`, `mersenne`, `min3`, `mov-c`, `movsx`, `mul-longlong`, `narcissistic`, `pascal`, `prime`, `quick-sort`, `recursion`, `select-sort`, `shift`, `string`, `sub-longlong`, `sum`, `switch`, `to-lower-case`, `unalign`, `wanshu`.

4. RT-Thread scripted shell `halt` passed with NEMU event DiffTest:
   ```sh
   make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
     AM_HOME=/host/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-linux-gnu- NPC_MAX_CYCLES=12000000 \
     NPC_DIFFTEST_REF=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```
   Result: `NEMU_RESULT status=good ... insts=511842`; `NPC_RESULT status=good reason=good_trap cycles=1955726 insts=511842`.

5. SoC regression passed:
   ```sh
   make -C npc soc-smoke test-soc-difftest test-soc-mem \
     REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
   ```

### PPA / timing result

Synthesis/STA command:
```sh
make -C npc sta-sweep \
  STA_O=../build/p10-4stage/ppa \
  STA_LOG_DIR=../build/p10-4stage/logs \
  STA_FREQS="600 650 700 750 760 770 780 790 800 850"
```

| Frequency | Worst slack | Worst endpoint | Reported Fmax |
| ---: | ---: | --- | ---: |
| 600 MHz | +0.378 ns | `u_core.f_pc_27__reg_p:D` | 776.410 MHz |
| 650 MHz | +0.250 ns | `u_core.f_pc_27__reg_p:D` | 776.410 MHz |
| 700 MHz | +0.140 ns | `u_core.f_pc_27__reg_p:D` | 776.410 MHz |
| 750 MHz | +0.045 ns | `u_core.f_pc_27__reg_p:D` | 776.410 MHz |
| 760 MHz | +0.027 ns | `u_core.f_pc_27__reg_p:D` | 776.410 MHz |
| 770 MHz | +0.010 ns | `u_core.f_pc_27__reg_p:D` | 776.410 MHz |
| 780 MHz | −0.006 ns | `u_core.f_pc_27__reg_p:D` | 776.410 MHz |
| 790 MHz | −0.023 ns | `u_core.f_pc_27__reg_p:D` | 776.410 MHz |
| 800 MHz | −0.038 ns | `u_core.f_pc_27__reg_p:D` | 776.410 MHz |
| 850 MHz | −0.112 ns | `u_core.f_pc_27__reg_p:D` | 776.410 MHz |

Synthesis result at 600 MHz:
```text
Chip area: 22122.240000
Sequential area: not separately extracted in this run
DFFQX1H7L: 1629
ICGX0P5H7L: 19
```

Comparison against P10-S8:

| Metric | P10-S8 | P10-S9 4-stage | Delta |
| --- | ---: | ---: | ---: |
| Area | `22528.520000` | `22122.240000` | −406.28 (−1.80%) |
| DFFs | `1476` | `1629` | +153 (+10.4%) |
| ICGs | `17` | `19` | +2 |
| Clean target | `680 MHz` | `770 MHz` | +90 MHz (+13.2%) |
| First failing | `690 MHz` | `780 MHz` | +90 MHz |
| Worst path delay | ~1.47 ns (X→C) | 1.243 ns (X→F redirect) | −0.23 ns |

### CPI / wall-clock trade-off

The extra pipeline stage adds some CPI:

| Workload | P10-S8 cycles | P10-S9 cycles | Δ cycles | Δ wall-clock @ new Fmax |
| --- | ---: | ---: | ---: | ---: |
| `cpu-tests/sum` | 1434 | 1640 | +14.4% | +1.0% |
| `cpu-tests/string` | 4069 | 4541 | +11.6% | −1.7% |
| `cpu-tests/matrix-mul` | 564293 | 570451 | +1.1% | −10.7% |
| `cpu-tests/crc32` | 66820 | 68459 | +2.5% | −8.6% |
| `cpu-tests/quick-sort` | 11859 | 12547 | +5.8% | −5.9% |
| RT-Thread | 1807800 | 1955726 | +8.2% | −4.4% |

For small programs the branch/fetch bubbles dominate, so wall-clock is flat or slightly worse. For larger programs the frequency gain dominates, so wall-clock improves by 4–11%.

### Interpretation: is this attempt successful?

Yes, with caveats.

- **Timing**: success. Clean target improved from `680 MHz` to `770 MHz`. The shared adder and pipeline split did cut the old critical path.
- **Area**: success. Total area decreased despite 153 extra DFFs for the new D/X boundary, because the shared adder removed four separate adder trees and the redirect state was removed from the spec-mode packet.
- **CPI**: mixed. Small programs regressed; large programs improved in wall-clock.
- **Structural insight**: the new critical path is the X→F redirect path (`D/X register → shared adder/branch comparator → f_pc`). This is the unavoidable cost of resolving branches in X and updating fetch in the same cycle. Further timing gains would require branch prediction/speculation to break that combinational path, or accepting a 2-cycle branch penalty by resolving branches later.

### Files modified

- `npc/rtl/core/Core.v`
- `notes/next.md` (this entry)

### Next steps

1. Decide whether to keep the 4-stage point or revert to P10-S8. The 4-stage point is better in raw Fmax and area, but CPI regresses for small programs.
2. If kept, the next timing bottleneck is the X→F redirect path. Options:
   - Add a small branch target buffer / next-PC predictor to break the combinational redirect path.
   - Explore whether resolving branches in D with a forwarded X result can be made faster.
3. Area opportunities remaining: X/W packet specialization (e.g. `xw_rs1_data` only for CSR), but measure each change.
4. CPI opportunities: fetch buffering, fairer IFU/LSU arbitration, but only after deciding the pipeline organization.
