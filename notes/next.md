# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 (`RV32E_Zicsr Functional Core`) is complete through `P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening`.
- Phase 4 is complete through `P4-S3: Temporary retired-instruction timer and AM IOE timer`.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store` and `activate`; leave them alone unless the user explicitly asks.
- Top-level `build/` contains generated AM/NPC images and sweep logs from smoke/regression runs; do not assume it should be committed unless intentionally adding an artifact.

Toolchain/config reminders:

- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because it uses `/bin/echo -e`; use the temporary Makefile/`printf` workaround below unless changing `am-kernels/` is explicitly allowed.
- NEMU REF shared object remains `nemu/build/riscv32-nemu-interpreter-so` and exports the CommitEvent APIs used by NPC DiffTest.
- NEMU `.config` currently has `# CONFIG_DEVICE is not set`. Earlier native device builds on this macOS environment failed on missing `SDL2/SDL.h`; P4-S4 should enable only UART/timer without pulling in graphical SDL dependencies. The user explicitly noted that NEMU device support may require config changes.
- `make -C nemu menuconfig` is interactive; do not run it in automation. During P4-S1 it was accidentally started and then stopped immediately.

P4-S3 completed work:

- Added temporary NPC CLINT/timer MMIO in the C++ harness:
  - `npc/csrc/memory.h`: `Memory::set_time()` stores the current simulation timer value.
  - `npc/csrc/main.cpp`: reset clears timer to 0; each retired instruction updates timer to the retired-instruction count.
  - `npc/csrc/memory.cpp`: reads from `0x0200bff8`/`0x0200bffc` return `mtime`/`mtimeh`; other reads in `0x02000000..0x0200ffff` return 0; CLINT writes are ignored. UART writes remain ordered through `commit_mmio_write()`.
- Updated AM NPC timer support:
  - `abstract-machine/am/src/riscv/npc/timer.c` now reads CLINT `mtime` with a stable hi/lo/hi sequence.
  - Uptime converts ticks to microseconds using `100000000 Hz`.
  - RTC reports a simple 1900-01-01 time derived from uptime seconds.
- Updated `npc/README.md` and `notes/plan.md` for P4-S3 status and timer smoke commands.

Validated commands and results:

1. NPC build:

   ```sh
   make -C npc
   ```

   Result: passed. Verilator build completed.

2. NPC `hello` with UART output still works:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=200000 run
   ```

   Result: passed and printed:

   ```text
   Hello, AbstractMachine!
   mainargs = ''.
   NPC_RESULT status=good reason=good_trap cycles=465 insts=465 pc=0x800000c4 halted=1 limit=200000 x1=0x800000c0 a0=0x00000000 trap=1
   ```

3. NPC `am-tests` devscan bounded timer smoke:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=80000000 mainargs=d run
   ```

   Result: timer progressed and printed:

   ```text
   heap = [%08x, %08x)
   Input device test skipped.
   Loop 10^7 time elapse: 500 ms
   AM Panic: access nonexist register @ .../abstract-machine/am/src/riscv/npc/ioe.c:26
   NPC_RESULT status=bad reason=bad_trap cycles=50005224 ...
   ```

   This is acceptable for P4-S3 because the timer portion works; the later panic is from optional video/storage device probing in `devscan`, not from timer.

4. NPC `am-tests` RTC bounded smoke:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=120000000 mainargs=t run
   ```

   Result: printed the first one-second line, then hit the expected cycle limit because `rtc_test()` is intentionally infinite:

   ```text
   1900-1-1 %02d:%02d:%02d GMT (1 second).
   NPC_RESULT status=limit reason=cycle_limit cycles=120000000 ...
   ```

   The `%02d` placeholders are due to the current minimal AM printf implementation; do not treat that as a timer bug.

5. Full NPC directed regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed by Makefile expectations. Some subtests intentionally return BAD/limit to validate failure/debug paths, so the raw log includes expected `status=bad`/`status=limit` lines.

6. Full 35-test `cpu-tests` sweep on NPC with NEMU event DiffTest:

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

- The P4-S3 timer is intentionally temporary and advances by retired instruction count, not by physical core cycles. The final physical CLINT from `specs/core.md` must wait until device-aware DiffTest/MMIO replay is available.
- The current precise trap path is single-cycle and vector-only (`pc = mtvec`); interrupts are still unsupported by design.
- `fence.i` is a visible no-state hook for now; actual icache clearing waits for Phase 7.
- NPC CommitEvent still does not carry memory or CSR access summaries for DiffTest comparison. Store metadata is currently exposed separately only for harness-side UART ordering.
- Event-API DiffTest compares CommitEvent fields. Full CSR state is checked on the fallback reg-copy path and initialized for REF, but CSR details are not in CommitEvent yet.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.
- Keep this through Phase 4: Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C calls. Side-effectful devices must remain explicitly ordered by retirement or another harness/interface protocol.
- M-extension tests remain out of scope because the target core is RV32E_Zicsr.
- UART input is intentionally unsupported in Phase 4.
- `am-tests mainargs=d` still panics after the timer section because GPU/storage device IOE entries are not implemented for NPC; this is outside P4-S3 timer scope.
- `am-tests mainargs=t` is intentionally infinite after printing periodically; use bounded runs and look for visible output/time progression.
- AM minimal printf currently does not format zero-padded fields such as `%02d`, so RTC output contains literal `%02d` placeholders.

Next work:

Start `P4-S4: NEMU device support for UART and temporary timer`.

Concrete P4-S4 plan:

1. Audit NEMU device framework/config around serial and timer without running interactive `menuconfig`.
2. Enable or repair only UART/timer device support needed by AM `hello`/timer smoke tests, avoiding SDL/graphical devices on macOS.
3. Keep NEMU behavior through its existing device framework, not a parallel ad hoc path.
4. Run NEMU AM `hello` and timer-style workloads with bounded limits and record exact observable behavior.
5. Preserve current NPC P4-S3 behavior and re-run at least `hello`, directed NPC regression, and a representative cpu-tests DiffTest subset after NEMU changes.
6. Update notes with NEMU device commands, any macOS/SDL caveats, and the next P4 entry point.

Relevant files:

- `notes/plan.md`
- `notes/next.md`
- `npc/README.md`
- `npc/csrc/main.cpp`
- `npc/csrc/memory.cpp`
- `npc/csrc/memory.h`
- `abstract-machine/am/src/riscv/npc/timer.c`
- `abstract-machine/am/src/riscv/npc/ioe.c`
- `abstract-machine/am/src/riscv/npc/trm.c`
- `nemu/.config`
- `nemu/src/device/serial.c`
- `nemu/src/device/timer.c`
- `nemu/src/device/Kconfig`
- `abstract-machine/am/src/platform/nemu/ioe/timer.c`
