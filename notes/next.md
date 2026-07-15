# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 (`RV32E_Zicsr Functional Core`) is complete through `P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening`.
- Phase 4 is complete through `P4-S5: Klib/DiffTest completion for UART and timer workloads`.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store`, `activate`, and top-level `.gitignore`; leave them alone unless the user explicitly asks.
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

P4-S5 completed work:

- Replaced the small AM `stdio.c` formatter with a Sonnet-libc-derived/adapted implementation supporting the formatting needed by timer/UART workloads, including `%02d`, width, sign flags, `l`/`ll` integer length modifiers, `%u`, `%x`/`%X`, `%p`, and `%o`.
- Added the remaining Sonnet-libc-derived klib pieces needed for a usable libc subset instead of leaving them as stubs:
  - new `abstract-machine/klib/src/ctype.c` implements `is*()` predicates plus `tolower()`/`toupper()`;
  - `abstract-machine/klib/src/stdlib.c` now implements `atol`, `atoll`, `strtol`, `strtoll`, `strtoul`, `strtoull`, heap-backed `malloc`, `free`, `exit`, and `abort`;
  - `abstract-machine/klib/include/klib.h` declares the added libc APIs and `RAND_MAX`.
- Added NEMU REF aliases for NPC MMIO addresses so event DiffTest can execute NPC AM UART/timer workloads:
  - UART TX at `0x10000000` is accepted without duplicating host output when NEMU is used as REF.
  - NPC CLINT window `0x02000000..0x0200ffff` is accepted.
  - `mtime`/`mtimeh` at `0x0200bff8`/`0x0200bffc` return deterministic retired-instruction ticks matching the NPC temporary timer model.
- Adjusted the NPC harness to set the temporary timer value for the next retiring instruction before combinational evaluation, so MMIO load commit data matches the NEMU REF event at retirement.
- Rebuilt both NEMU native executable and NEMU REF shared object after the REF alias change.
- Confirmed UART and timer workloads now run under NPC event DiffTest without mismatch. Expected terminal failures remain only from optional devices or intentional bounded infinite RTC loops.

Validated commands and results:

1. Rebuild NEMU REF shared object:

   ```sh
   make -C nemu ISA=riscv32 SHARE=1
   ```

   Result: passed; rebuilt `nemu/build/riscv32-nemu-interpreter-so`.

2. Rebuild NPC simulator:

   ```sh
   make -C npc
   ```

   Result: passed.

3. NPC `hello` with UART and NEMU event DiffTest:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=200000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: passed; printed:

   ```text
   Hello, AbstractMachine!
   mainargs = ''.
   NPC_RESULT status=good reason=good_trap cycles=465 insts=465 pc=0x800000c4 halted=1 limit=200000 x1=0x800000c0 a0=0x00000000 trap=1
   ```

4. NPC `am-tests mainargs=d` with timer/UART and NEMU event DiffTest:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=80000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so mainargs=d run
   ```

   Result: DiffTest ran through the UART/timer section with no mismatch, printed:

   ```text
   heap = [8009e000, 88000000)
   Input device test skipped.
   Loop 10^7 time elapse: 500 ms
   AM Panic: access nonexist register @ .../abstract-machine/am/src/riscv/npc/ioe.c:26
   NEMU_RESULT status=bad state=2 halt_pc=0x800010a4 halt_ret=1 insts=50013020 limit=0
   NPC_RESULT status=bad reason=bad_trap cycles=50013020 insts=50013020 pc=0x800010a4 halted=1 limit=80000000 ...
   ```

   The final BAD trap is expected for this slice: optional device probing after timer/devscan still reaches an unimplemented IOE register. UART/timer DiffTest itself works.

5. NPC `am-tests mainargs=t` with timer/UART and NEMU event DiffTest:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=120000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so mainargs=t run
   ```

   Result: DiffTest ran with no mismatch until the expected bound on the intentionally infinite RTC test; printed:

   ```text
   1900-1-1 00:00:01 GMT (1 second).
   NPC_RESULT status=limit reason=cycle_limit cycles=120000000 insts=120000000 ...
   ```

6. NEMU native build:

   ```sh
   make -C nemu
   ```

   Result: passed.

7. NEMU `hello` with UART output:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     NEMU_HOME=/Users/venti/Workspace/ai-ysyx/nemu \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=200000 run
   ```

   Result: passed; printed `Hello, AbstractMachine!` and:

   ```text
   NEMU_RESULT status=good state=2 halt_pc=0x800000c4 halt_ret=0 insts=352 limit=200000
   ```

8. NEMU `am-tests mainargs=t` bounded RTC smoke:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     NEMU_HOME=/Users/venti/Workspace/ai-ysyx/nemu \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=120000000 mainargs=t run
   ```

   Result: printed `1900-1-1 00:00:01 GMT (1 second).` and hit the expected instruction limit because `rtc_test()` is intentionally infinite:

   ```text
   NEMU_RESULT status=limit state=5 halt_pc=0x8000009c halt_ret=1 insts=120000000 limit=120000000
   ```

9. Full NPC directed regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed by Makefile expectations. Some subtests intentionally return BAD/limit to validate failure/debug paths, so raw logs include expected `status=bad`/`status=limit` lines.

10. Full 35-test `cpu-tests` sweep on NPC with NEMU event DiffTest:

   ```sh
   ROOT=/Users/venti/Workspace/ai-ysyx
   TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
   for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
     tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
     printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
     make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=2000000 NPC_DIFFTEST_REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so" run >/tmp/npc-cputest-$t.log 2>&1
     status=$?
     rm -f "$tmp"
     if [ $status -ne 0 ]; then echo "FAILED $t"; tail -80 /tmp/npc-cputest-$t.log; exit $status; fi
     echo "PASS $t"
   done
   ```

   Result: all 35 cpu-tests passed with DiffTest enabled.

Known caveats:

- NEMU and NPC Phase 4 timers are still temporary retired-instruction models, not physical cycle-based CLINT/RTC devices. The final physical CLINT from `specs/core.md` must wait until device-aware DiffTest/MMIO replay is available.
- NEMU REF now has narrow NPC MMIO aliases only to keep Phase 4 event DiffTest usable for UART/timer workloads. This is not the final Phase 5 device-aware MMIO replay design.
- NEMU native device support is currently UART/timer-only. Optional keyboard/VGA/audio/disk/sdcard remain disabled for this slice.
- NEMU/NPC `am-tests mainargs=d` still panic after the timer/devscan section because optional device IOE entries are not implemented. This is outside the UART/timer scope.
- NEMU/NPC `am-tests mainargs=t` is intentionally infinite after printing periodically; use bounded runs and look for visible output/time progression.
- The current precise trap path is single-cycle and vector-only (`pc = mtvec`); interrupts are still unsupported by design.
- `fence.i` is a visible no-state hook for now; actual icache clearing waits for Phase 7.
- NPC CommitEvent still does not carry memory or CSR access summaries for DiffTest comparison. Store metadata is currently exposed separately only for harness-side UART ordering.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.
- Keep this through Phase 4/5: Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C calls. Side-effectful devices must remain explicitly ordered by retirement or another harness/interface protocol.
- M-extension remains out of scope for the NPC core because the target is RV32E_Zicsr. NEMU implements RV32M only because its `riscv32-nemu` AM target uses `rv32im_zicsr`.
- UART input is intentionally unsupported in Phase 4.

Next work:

Start `P4-S6: CTE validation with existing am-kernels workloads`.

Concrete P4-S6 plan:

1. Audit the current `riscv32e-npc` AM CTE files and existing `yield-os` workload entry points.
2. Implement or repair only the CTE pieces needed by existing workloads: trap vector install, trap frame save/restore, `yield()`, event classification, handler return, and `kcontext()` if required.
3. Validate with existing `am-kernels/kernels/yield-os`, not a custom workload.
4. Keep current UART/timer DiffTest behavior intact; rerun the focused UART/timer DiffTest smokes after CTE changes.
5. Re-run NPC directed regression and full or representative cpu-tests with DiffTest after changes.
6. Update `notes/next.md` with exact pass/fail results and the next P4 entry point.

Relevant files:

- `notes/plan.md`
- `notes/next.md`
- `abstract-machine/klib/src/stdio.c`
- `nemu/src/memory/paddr.c`
- `npc/csrc/main.cpp`
- `abstract-machine/am/src/riscv/npc/cte.c`
- `abstract-machine/am/src/riscv/npc/trap.S`
- `abstract-machine/am/src/riscv/npc/context.c`
- `abstract-machine/am/src/riscv/npc/timer.c`
- `abstract-machine/am/src/riscv/npc/ioe.c`
- `am-kernels/kernels/yield-os/Makefile`
