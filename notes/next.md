# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 (`RV32E_Zicsr Functional Core`) is complete through `P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening`.
- Phase 4 is complete through `P4-S4: NEMU device support for UART and temporary timer`.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store` and `activate`; leave them alone unless the user explicitly asks.
- Top-level `build/` contains generated AM/NPC images and sweep logs from smoke/regression runs; do not assume it should be committed unless intentionally adding an artifact.

Toolchain/config reminders:

- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because it uses `/bin/echo -e`; use the temporary Makefile/`printf` workaround below unless changing `am-kernels/` is explicitly allowed.
- NEMU native `.config` now enables only UART/timer devices:
  - `CONFIG_DEVICE=y`
  - `CONFIG_HAS_SERIAL=y`, `CONFIG_SERIAL_MMIO=0xa00003f8`
  - `CONFIG_HAS_TIMER=y`, `CONFIG_RTC_MMIO=0xa0000048`
  - keyboard/VGA/audio/disk/sdcard are disabled to avoid SDL/optional device dependencies on macOS.
- `make -C nemu menuconfig` is interactive; do not run it in automation.
- NEMU REF shared object remains `nemu/build/riscv32-nemu-interpreter-so` and exports the CommitEvent APIs used by NPC DiffTest. This session did not rebuild the REF shared object because the current native `.config` targets the executable; existing NPC DiffTest validation still passed against the existing REF `.so`.

P4-S4 completed work:

- Enabled native NEMU UART/timer device support through the existing device framework, not an ad hoc parallel path.
- Updated `nemu/.config` and regenerated `nemu/include/config/auto.conf`/`include/generated/autoconf.h` during build.
- Updated `nemu/src/device/device.c` so SDL is included/polled only when VGA or keyboard is enabled. This lets UART/timer-only native device builds work on this macOS host without SDL headers.
- Updated `nemu/src/device/timer.c` so RTC MMIO reads return deterministic uptime in microseconds from retired instruction count: `g_nr_guest_inst / 100`. This is a Phase 4 temporary model aligned with the 100 MHz AM assumption, not a physical timer.
- Updated AM NEMU platform support:
  - `abstract-machine/am/src/platform/nemu/ioe/timer.c` reads `RTC_ADDR`/`RTC_ADDR + 4` with a stable hi/lo/hi sequence and derives a simple 1900-01-01 RTC from uptime.
  - `abstract-machine/am/src/platform/nemu/ioe/ioe.c` reports UART present.
  - `abstract-machine/scripts/platform/nemu.mk` removed stale `-l .../nemu-log.txt` from `NEMUFLAGS`, because the current NEMU monitor does not accept `-l`.
- Added RV32M integer multiply/divide decode in `nemu/src/isa/riscv32/inst.c` (`mul`, `mulh`, `mulhsu`, `mulhu`, `div`, `divu`, `rem`, `remu`) because current `riscv32-nemu` AM timer workloads are compiled with `-march=rv32im_zicsr` and use division in formatting/time code.

Validated commands and results:

1. NEMU native build:

   ```sh
   make -C nemu
   ```

   Result: passed. The UART/timer-only native executable `nemu/build/riscv32-nemu-interpreter` rebuilt without SDL dependency errors.

2. NEMU `hello` with UART output:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     NEMU_HOME=/Users/venti/Workspace/ai-ysyx/nemu \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=200000 run
   ```

   Result: passed and printed:

   ```text
   Hello, AbstractMachine!
   mainargs = ''.
   NEMU_RESULT status=good state=2 halt_pc=0x800000c4 halt_ret=0 insts=352 limit=200000
   ```

3. NEMU `am-tests` devscan bounded timer smoke:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     NEMU_HOME=/Users/venti/Workspace/ai-ysyx/nemu \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=80000000 mainargs=d run
   ```

   Result: timer progressed and printed:

   ```text
   heap = [%08x, %08x)
   Input device test skipped.
   Loop 10^7 time elapse: 500 ms
   Screen size: 0 x 0
   AM Panic: access nonexist register @ .../abstract-machine/am/src/platform/nemu/ioe/ioe.c:47
   NEMU_RESULT status=bad state=2 halt_pc=0x80000f94 halt_ret=1 insts=58913894 limit=80000000
   ```

   This is acceptable for P4-S4. UART/timer worked; the later panic is from optional device probing that is outside the UART/timer slice.

4. NEMU `am-tests` RTC bounded smoke:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     NEMU_HOME=/Users/venti/Workspace/ai-ysyx/nemu \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=120000000 mainargs=t run
   ```

   Result: printed the first one-second line and then hit the expected instruction limit because `rtc_test()` is intentionally infinite:

   ```text
   1900-1-1 %02d:%02d:%02d GMT (1 second).
   NEMU_RESULT status=limit state=5 halt_pc=0x800010e4 halt_ret=1 insts=120000000 limit=120000000
   ```

   The `%02d` placeholders are due to the current minimal AM printf implementation; do not treat that as a timer bug.

5. NPC `hello` still works:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=200000 run
   ```

   Result: passed and printed `Hello, AbstractMachine!`, ending with:

   ```text
   NPC_RESULT status=good reason=good_trap cycles=465 insts=465 pc=0x800000c4 halted=1 limit=200000 x1=0x800000c0 a0=0x00000000 trap=1
   ```

6. Full NPC directed regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed by Makefile expectations. Some subtests intentionally return BAD/limit to validate failure/debug paths, so raw logs include expected `status=bad`/`status=limit` lines.

7. Full 35-test `cpu-tests` sweep on NPC with NEMU event DiffTest:

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

- NEMU and NPC Phase 4 timers are intentionally temporary retired-instruction models, not physical cycle-based CLINT/RTC devices. The final physical CLINT from `specs/core.md` must wait until device-aware DiffTest/MMIO replay is available.
- NEMU native device support is currently UART/timer-only. Optional keyboard/VGA/audio/disk/sdcard remain disabled for this slice.
- NEMU `am-tests mainargs=d` and NPC `mainargs=d` still panic after the timer/devscan section because optional device IOE entries are not implemented. This is outside the UART/timer scope.
- NEMU/NPC `am-tests mainargs=t` is intentionally infinite after printing periodically; use bounded runs and look for visible output/time progression.
- AM minimal printf currently does not format zero-padded fields such as `%02d`, so RTC output contains literal `%02d` placeholders.
- The current precise trap path is single-cycle and vector-only (`pc = mtvec`); interrupts are still unsupported by design.
- `fence.i` is a visible no-state hook for now; actual icache clearing waits for Phase 7.
- NPC CommitEvent still does not carry memory or CSR access summaries for DiffTest comparison. Store metadata is currently exposed separately only for harness-side UART ordering.
- Event-API DiffTest compares CommitEvent fields. Full CSR state is checked on the fallback reg-copy path and initialized for REF, but CSR details are not in CommitEvent yet.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.
- Keep this through Phase 4: Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C calls. Side-effectful devices must remain explicitly ordered by retirement or another harness/interface protocol.
- M-extension remains out of scope for the NPC core because the target is RV32E_Zicsr. NEMU implements RV32M now only because its `riscv32-nemu` AM target uses `rv32im_zicsr`.
- UART input is intentionally unsupported in Phase 4.

Next work:

Start `P4-S5: Klib completion pass for essential workloads`.

Concrete P4-S5 plan:

1. Audit remaining AM klib/printf gaps hit by `hello`, timer tests, `yield-os`, and nearby AM workloads. Known visible gap: `%02d` formatting is printed literally.
2. Complete only the missing klib/formatting functions needed by essential Phase 4 workloads, keeping changes in `abstract-machine/klib` minimal and compatible with existing style.
3. Validate with existing AM tests rather than inventing new workloads.
4. Preserve current UART/timer behavior on both NEMU and NPC.
5. Re-run NEMU `hello`, bounded NEMU timer smokes, NPC `hello`, NPC directed regression, and full or representative NPC cpu-tests with DiffTest after changes.
6. Update `notes/next.md` with exact pass/fail results and the next P4 entry point.

Relevant files:

- `notes/plan.md`
- `notes/next.md`
- `abstract-machine/klib/src/stdio.c`
- `abstract-machine/klib/src/string.c`
- `abstract-machine/klib/src/stdlib.c`
- `abstract-machine/am/src/platform/nemu/ioe/timer.c`
- `abstract-machine/am/src/platform/nemu/ioe/ioe.c`
- `abstract-machine/scripts/platform/nemu.mk`
- `nemu/.config`
- `nemu/src/device/device.c`
- `nemu/src/device/timer.c`
- `nemu/src/isa/riscv32/inst.c`
- `abstract-machine/am/src/riscv/npc/timer.c`
- `abstract-machine/am/src/riscv/npc/ioe.c`
