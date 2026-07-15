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
- Phase 7 (`Instruction Cache and fence.i`) is complete through `P7-S2: Full regression and bug fixing`.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store`, `activate`, and top-level `.gitignore`; leave them alone unless the user explicitly asks. Current `git status --short` still shows untracked top-level `.gitignore`.
- Top-level `build/` contains generated AM/NPC images, logs, and the ignored temporary `build/sonnet-libc-src` clone used as the Sonnet libc source reference; do not commit generated artifacts unless explicitly requested.

Toolchain/config reminders:

- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because it uses `/bin/echo -e`; use the temporary Makefile/`printf` workaround below unless changing `am-kernels/` is explicitly allowed.
- NEMU native `.config` currently shows:
  - `CONFIG_MBASE=0x80000000`
  - `CONFIG_MSIZE=0x8000000`
  - `CONFIG_PC_RESET_OFFSET=0`
  - `CONFIG_DEVICE=y`
  - `CONFIG_HAS_SERIAL=y`, `CONFIG_SERIAL_MMIO=0xa00003f8`
  - `CONFIG_HAS_TIMER=y`, `CONFIG_RTC_MMIO=0xa0000048`
  - keyboard/VGA/audio/disk/sdcard disabled.
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

## Next steps

1. Start `P7-S3: Re-check Phase 7 exit criteria and plan Phase 8`.
2. In P7-S3, explicitly confirm Phase 7 exit criteria.
3. Produce the Phase 8 measurement/PPA baseline plan, including which workloads to measure, which counters to record, and the exact commands to use.
