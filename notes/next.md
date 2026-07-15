# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 (`RV32E_Zicsr Functional Core`) is complete through `P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening`.
- Phase 4 is complete and closed through `P4-S9: Workload regression and Phase 4 closeout`.
- Phase 5 has started. `P5-S1: NEMU memory-region groundwork` was already completed and committed as `a007e71 Refactor NEMU physical memory regions`.
- Next work is `P5-S2: Device/MMIO cleanup and replay contract`.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store`, `activate`, and top-level `.gitignore`; leave them alone unless the user explicitly asks. Current `git status --short` still shows untracked top-level `.gitignore`.
- Top-level `build/` contains generated AM/NPC images, logs, and the ignored temporary `build/sonnet-libc-src` clone used as the Sonnet libc source reference; do not commit generated artifacts unless explicitly requested.

Toolchain/config reminders:

- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because it uses `/bin/echo -e`; use the temporary Makefile/`printf` workaround below unless changing `am-kernels/` is explicitly allowed.
- NEMU native `.config` enables only UART/timer devices:
  - `CONFIG_DEVICE=y`
  - `CONFIG_HAS_SERIAL=y`, `CONFIG_SERIAL_MMIO=0xa00003f8`
  - `CONFIG_HAS_TIMER=y`, `CONFIG_RTC_MMIO=0xa0000048`
  - keyboard/VGA/audio/disk/sdcard are disabled to avoid SDL/optional device dependencies on macOS.
- `make -C nemu menuconfig` is interactive; do not run it in automation.
- NEMU REF shared object is `nemu/build/riscv32-nemu-interpreter-so` and exports the CommitEvent APIs used by NPC DiffTest.

## Phase 4 closeout status

Phase 4 exit criteria are met:

- NPC UART output at `0x10000000` is implemented with deterministic retired-store side effects; `hello` prints visibly. UART input remains intentionally unsupported.
- NPC AM IOE timer works with the temporary retired-instruction-based `mtime`/`mtimeh` source and the 100 MHz platform assumption. No timer interrupt behavior was added.
- NEMU has UART and temporary timer support through its device framework for the required smokes.
- `ebreak` simulation termination is documented/implemented as retired-instruction matching in the harness, not AM trap-handler termination.
- Essential klib/runtime gaps hit by selected workloads were fixed.
- Existing AM CTE workloads (`yield-os`, bounded `thread-os`) have current pass/fail status.
- `rt-thread-am` reaches the required NEMU and NPC smoke milestones, including scripted shell output through `halt` and good trap termination.
- The temporary timer workaround and need for Phase 5 device-aware MMIO replay before physical CLINT are recorded.
- Directed NPC regressions and the full 35-test cpu-tests sweep still pass with DiffTest.

Validated during P4-S9:

1. Full NPC directed regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed by Makefile expectations. Some subtests intentionally print `status=bad`, `status=limit`, or check-fail snippets for negative/debug-path tests.

2. Full 35-test `cpu-tests` sweep on NPC with NEMU event DiffTest:

   ```sh
   ROOT=/Users/venti/Workspace/ai-ysyx
   TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
   REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so"
   for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
     tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
     printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
     make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=2000000 NPC_DIFFTEST_REF="$REF" run >/tmp/p4-closeout-cputest-$t.log 2>&1
     status=$?
     rm -f "$tmp"
     if [ $status -ne 0 ]; then echo "FAILED $t"; tail -80 /tmp/p4-closeout-cputest-$t.log; exit $status; fi
     echo "PASS $t"
   done
   ```

   Result: all 35 tests passed.

3. NEMU `hello`:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     NEMU_HOME=/Users/venti/Workspace/ai-ysyx/nemu \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=200000 run
   ```

   Result: printed `Hello, AbstractMachine!` and `NEMU_RESULT status=good state=2 halt_pc=0x800000c4 halt_ret=0 insts=352 limit=200000`.

4. NPC `hello` with NEMU DiffTest:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=200000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: printed `Hello, AbstractMachine!`, `NEMU_RESULT status=good`, and `NPC_RESULT status=good reason=good_trap cycles=465 insts=465 pc=0x800000c4 ...`.

5. NPC timer/devscan smoke:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=80000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so mainargs=d run
   ```

   Result: expected nonzero exit after optional-device probing. It printed `Loop 10^7 time elapse: 500 ms`, then `NPC_RESULT status=bad reason=bad_trap cycles=50013020 ...`. No DiffTest mismatch before the expected bad trap.

6. NPC RTC/timer smoke:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=120000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so mainargs=t run
   ```

   Result: expected nonzero exit due to cycle limit. It printed `1900-1-1 00:00:01 GMT (1 second).`, then `NPC_RESULT status=limit reason=cycle_limit cycles=120000000 ...`.

7. NPC `yield-os` CTE smoke:

   ```sh
   make -C am-kernels/kernels/yield-os ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=2000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: expected nonzero exit due to infinite workload/cycle limit. It printed `ABAB` and `NPC_RESULT status=limit reason=cycle_limit cycles=2000000 ...`. No DiffTest failure marker.

8. NEMU `yield-os` CTE smoke:

   ```sh
   make -C am-kernels/kernels/yield-os ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     NEMU_HOME=/Users/venti/Workspace/ai-ysyx/nemu \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=2000000 run
   ```

   Result: expected nonzero exit due to infinite workload/instruction limit. It printed `ABAB` and `NEMU_RESULT status=limit state=5 halt_pc=0x80000098 halt_ret=1 insts=2000000 limit=2000000`.

9. NPC `thread-os` CTE/MPE smoke:

   ```sh
   make -C am-kernels/kernels/thread-os ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=5000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: expected nonzero exit due to infinite workload/cycle limit. It printed repeated `Thread-B on CPU #0` and `NPC_RESULT status=limit reason=cycle_limit cycles=5000000 ...`. No DiffTest failure marker.

10. RT-Thread AM on NEMU:

    ```sh
    cd /Users/venti/Workspace/ai-ysyx/rt-thread-am/bsp/abstract-machine
    make ARCH=riscv32-nemu \
      AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
      NEMU_HOME=/Users/venti/Workspace/ai-ysyx/nemu \
      CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=5000000 run
    ```

    Result: exit code 0. Output contained RT-Thread banner, `Hello RISC-V!`, scripted shell commands through `msh />halt`, and `NEMU_RESULT status=good state=2 halt_pc=0x80000234 halt_ret=0 insts=416082 limit=5000000`.

11. RT-Thread AM on NPC with NEMU DiffTest:

    ```sh
    cd /Users/venti/Workspace/ai-ysyx/rt-thread-am/bsp/abstract-machine
    make ARCH=riscv32e-npc \
      AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
      CROSS_COMPILE=riscv64-elf- \
      NPC_MAX_CYCLES=5000000 \
      NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so \
      run
    ```

    Result: exit code 0. Output contained `NPC_DIFFTEST status=on`, RT-Thread banner, `Hello RISC-V!`, scripted shell commands through `msh />halt`, `NEMU_RESULT status=good`, and `NPC_RESULT status=good reason=good_trap cycles=511954 insts=511954 ...`.

Known caveats after Phase 4:

- NEMU and NPC Phase 4 timers are temporary retired-instruction models, not physical cycle-based CLINT/RTC devices. The final physical CLINT from `specs/core.md` waits for device-aware DiffTest/MMIO replay.
- NEMU REF still has narrow NPC MMIO aliases from Phase 4/P5-S1. These should move into device/MMIO or platform-specific code in P5-S2.
- NEMU native device support is UART/timer-only. Optional keyboard/VGA/audio/disk/sdcard remain disabled.
- `am-tests mainargs=d` still panics after the timer/devscan section because optional IOE entries are not implemented. This is outside the UART/timer/CTE/RT-Thread scope.
- `am-tests mainargs=t`, `yield-os`, and `thread-os` are intentionally infinite; use bounded runs and check visible progress plus absence of DiffTest mismatch.
- NPC `thread-os` stays on `Thread-B on CPU #0` in the current single-core/no-interrupt setup; timer interrupts/preemption remain unsupported by design.
- The current precise trap path is single-cycle and vector-only (`pc = mtvec`); interrupts are unsupported by design.
- `fence.i` is a visible no-state hook for now; actual icache clearing waits for Phase 7.
- NPC CommitEvent still does not carry full memory/MMIO/CSR access summaries for DiffTest comparison. P5-S2 starts fixing this for MMIO replay.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.
- Keep this through Phase 5: Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C calls. Side-effectful devices must remain explicitly ordered by retirement or another harness/interface protocol.
- M-extension remains out of scope for the NPC core because the target is RV32E_Zicsr. NEMU implements RV32M only because its `riscv32-nemu` AM target uses `rv32im_zicsr`.
- UART input is intentionally unsupported.

## P5-S2 status: Device/MMIO cleanup and lightweight replay

P5-S2 implementation is complete and waiting for user note review before commit.

What changed:

- Removed temporary NPC UART/CLINT special cases from generic `nemu/src/memory/paddr.c`; `paddr.c` now falls through to the MMIO framework for unbacked device addresses when `CONFIG_DEVICE=y`.
- Added `nemu/src/device/npc-dev.c` and `nemu/include/debug/mmio_replay.h`:
  - NPC UART MMIO at `0x10000000`.
  - NPC CLINT MMIO at `0x02000000..0x0200bfff`, matching `specs/clint.rst` bound address and register offsets (`msip=0x0`, `mtimecmp=0x4000`, `mtime=0xbff8`).
  - Temporary `mtime` still uses the Phase 4 retired-instruction model, not physical cycles.
  - REF shared-object (`CONFIG_TARGET_SHARE`) mode validates/replays a single pending MMIO access and suppresses duplicate UART output.
- Added a lightweight replay API exported by NEMU REF:
  - `difftest_set_mmio_replay(const MMIOReplayRecord *)`
  - `difftest_mmio_replay_ok()`
- Did **not** add MMIO fields to `CommitEvent`. The replay contract is separate:
  - NPC DUT/harness records a just-retired MMIO access.
  - NPC DiffTest arms the REF replay before stepping the matching REF instruction.
  - REF device callbacks validate matching MMIO and replay DUT read data.
- Updated `npc/csrc/memory.{h,cpp}` and `npc/csrc/main.cpp` to record MMIO reads/writes while preserving retired UART output ordering.
- Updated `npc/csrc/difftest.{h,cpp}` to pass optional MMIO replay records to REF.
- Updated `nemu/scripts/build.mk` so shared-object builds define `CONFIG_TARGET_SHARE`; `cpu-exec.c` now has a REF-share breakpoint stub because monitor code is blacklisted from REF builds.

Validated in P5-S2:

1. NEMU native and REF shared object build:

   ```sh
   make -C nemu
   make -C nemu CONFIG_TARGET_NATIVE_ELF= CONFIG_TARGET_SHARE=y -B
   ```

   Result: both built successfully.

2. NPC directed regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed by Makefile expectations.

3. Full 35-test `cpu-tests` sweep on NPC with NEMU event DiffTest:

   ```sh
   ROOT=/Users/venti/Workspace/ai-ysyx
   TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
   REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so"
   for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
     tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
     printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
     make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=2000000 NPC_DIFFTEST_REF="$REF" run >/tmp/p5-s2-cputest-$t.log 2>&1
     status=$?
     rm -f "$tmp"
     if [ $status -ne 0 ]; then echo "FAILED $t"; tail -80 /tmp/p5-s2-cputest-$t.log; exit $status; fi
     echo "PASS $t"
   done
   ```

   Result: all 35 tests passed.

4. NEMU `hello`:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     NEMU_HOME=/Users/venti/Workspace/ai-ysyx/nemu \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=200000 run
   ```

   Result: printed `Hello, AbstractMachine!` and `NEMU_RESULT status=good state=2 halt_pc=0x800000c4 halt_ret=0 insts=352 limit=200000`.

5. NPC `hello` with NEMU DiffTest:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=200000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: printed `Hello, AbstractMachine!`, `NEMU_RESULT status=good`, and `NPC_RESULT status=good reason=good_trap cycles=465 insts=465 pc=0x800000c4 ...` with no duplicated REF UART output.

6. RT-Thread AM on NPC with NEMU DiffTest:

   ```sh
   make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=5000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: exit code 0. Output contained RT-Thread banner, `Hello RISC-V!`, scripted shell commands through `msh />halt`, `NEMU_RESULT status=good`, and `NPC_RESULT status=good reason=good_trap cycles=511954 insts=511954 ...`.

7. NPC timer/devscan smoke with DiffTest:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=80000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so mainargs=d run
   ```

   Result: expected nonzero exit after optional-device probing. It printed `Loop 10^7 time elapse: 500 ms`, then `NPC_RESULT status=bad reason=bad_trap cycles=50013020 ...`. No DiffTest mismatch before the expected bad trap.

8. NPC RTC/timer smoke with DiffTest:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=120000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so mainargs=t run
   ```

   Result: expected nonzero exit due to cycle limit. It printed `1900-1-1 00:00:01 GMT (1 second).`, then `NPC_RESULT status=limit reason=cycle_limit cycles=120000000 ...`. No DiffTest mismatch.

Known caveats after P5-S2:

- The replay contract is intentionally a one-access-per-retired-instruction mechanism. Current single-cycle NPC instructions only produce at most one architectural MMIO access; revisit if bus/pipeline work can retire instructions with multiple device accesses.
- The NPC harness has a small pending-read workaround because Verilator may evaluate combinational DPI reads for the next instruction before the next harness step begins. This is still kept inside the harness/replay boundary and should be revisited when P5-S3 introduces explicit request/response memory timing.
- CLINT implements the `specs/clint.rst` address window but still uses the temporary retired-instruction timer source. Physical cycle-based CLINT remains Phase 6 work.
- `am-tests mainargs=d` still panics after the required timer/devscan section due to optional IOE registers; this remains outside scope.
- `am-tests mainargs=t` is intentionally bounded by cycle limit.
- NEMU native device support is still UART/timer plus the temporary NPC-compatible UART/CLINT aliases.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.

Next work: `P5-S3: NPC internal bus request/response boundary`.

Relevant files for next session:

- `notes/plan.md`
- `notes/next.md`
- `nemu/include/debug/mmio_replay.h`
- `nemu/src/device/npc-dev.c`
- `nemu/src/memory/paddr.c`
- `nemu/src/cpu/difftest/ref.c`
- `npc/csrc/main.cpp`
- `npc/csrc/memory.cpp`
- `npc/csrc/memory.h`
- `npc/csrc/difftest.cpp`
- `npc/csrc/difftest.h`
- `npc/rtl/core/Ifu.v`
- `npc/rtl/core/Lsu.v`
- `npc/rtl/core/Core.v`
