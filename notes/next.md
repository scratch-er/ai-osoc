# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 (`RV32E_Zicsr Functional Core`) is complete through `P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening`.
- Phase 4 is complete through `P4-S2: NPC ordered UART MMIO and AM putch()`.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store` and `activate`; leave them alone unless the user explicitly asks.
- Top-level `build/` contains generated AM/NPC images and sweep logs from smoke/regression runs; do not assume it should be committed unless intentionally adding an artifact.

Toolchain/config reminders:

- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because it uses `/bin/echo -e`; use the temporary Makefile/`printf` workaround below unless changing `am-kernels/` is explicitly allowed.
- NEMU REF shared object remains `nemu/build/riscv32-nemu-interpreter-so` and exports the CommitEvent APIs used by NPC DiffTest.
- NEMU `.config` currently has `# CONFIG_DEVICE is not set`. Earlier native device builds on this macOS environment failed on missing `SDL2/SDL.h`; P4 should enable only UART/timer without pulling in graphical SDL dependencies. The user explicitly noted that NEMU device support may require config changes.
- `make -C nemu menuconfig` is interactive; do not run it in automation. During P4-S1 it was accidentally started and then stopped immediately.

P4-S2 completed work:

- Added committed UART output for NPC at MMIO address `0x10000000`:
  - `npc/rtl/core/Lsu.v` exports aligned store address/data/mask metadata.
  - `npc/rtl/core/Core.v` and `npc/rtl/NPC.v` expose committed store metadata through top-level commit ports.
  - `npc/csrc/main.cpp` captures store metadata before the cycle edge and calls `Memory::commit_mmio_write()` after the instruction retires.
  - `npc/csrc/memory.cpp` treats combinational writes to `0x10000000` as non-side-effecting MMIO probes and emits the UART byte only from the ordered commit path.
- Updated AM NPC UART support:
  - `abstract-machine/am/src/riscv/npc/trm.c`: `putch()` writes a byte to `0x10000000`.
  - `abstract-machine/am/src/riscv/npc/ioe.c`: `AM_UART_CONFIG` reports present and `AM_UART_TX` calls `putch()`.
- Updated `npc/README.md` and `notes/plan.md` for P4-S2 status and the AM `hello` command.

Validated commands and results:

1. NPC build:

   ```sh
   make -C npc
   ```

   Result: passed. Verilator emitted existing generated C++ warnings about bitwise `|` on boolean operands; build completed.

2. NPC `hello` with UART output:

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

3. Full NPC directed regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed.

4. Full 35-test `cpu-tests` sweep on NPC with NEMU event DiffTest:

   ```sh
   ROOT=/Users/venti/Workspace/ai-ysyx
   TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
   for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
     tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
     printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
     make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=2000000 NPC_DIFFTEST_REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so" run
     status=$?
     rm -f "$tmp"
     if [ $status -ne 0 ]; then echo "FAILED $t"; exit $status; fi
   done
   ```

   Result: all 35 cpu-tests passed with DiffTest enabled.

5. NPC `am-tests` devscan bounded check:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=200000 mainargs=d run
   ```

   Result: bounded limit, but UART now prints visible text before the timer stub blocks progress:

   ```text
   heap = [%08x, %08x)
   Input device test skipped.
   NPC_RESULT status=limit reason=cycle_limit ...
   ```

Known caveats:

- The current precise trap path is single-cycle and vector-only (`pc = mtvec`); interrupts are still unsupported by design.
- `fence.i` is a visible no-state hook for now; actual icache clearing waits for Phase 7.
- NPC CommitEvent still does not carry memory or CSR access summaries for DiffTest comparison. Store metadata is currently exposed separately only for harness-side UART ordering.
- Event-API DiffTest compares CommitEvent fields. Full CSR state is checked on the fallback reg-copy path and initialized for REF, but CSR details are not in CommitEvent yet.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.
- Keep this through Phase 4: Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C calls. Side-effectful devices must remain explicitly ordered by retirement or another harness/interface protocol.
- M-extension tests remain out of scope because the target core is RV32E_Zicsr.
- UART input is intentionally unsupported in Phase 4.
- `abstract-machine/am/src/riscv/npc/timer.c` still returns zero uptime and fixed RTC; `am-tests mainargs=d` and timer/RTC workloads are expected to hit bounded limits until P4-S3.
- `am-tests` `rtc` is intentionally infinite after printing periodically; use bounded runs and look for visible output/time progression once timer/UART exist.

Next work:

Start `P4-S3: Temporary retired-instruction timer and AM IOE timer`.

Concrete P4-S3 plan:

1. Implement the temporary Phase 4 simulation timer/CLINT model for NPC.
   - Expose `mtime`/`mtimeh` through the CLINT MMIO addresses used by AM.
   - Advance deterministically by retired-instruction count for now, not physical core cycles.
   - Keep side effects ordered; avoid combinational DPI side effects.
2. Update `abstract-machine/am/src/riscv/npc/timer.c` to read the simulated timer and convert to microseconds using the 100 MHz assumption.
3. Keep `mtimecmp`, `mtimecmph`, and `msip` ignored/undefined as planned; do not add interrupts.
4. Run bounded `am-tests` timer/devscan checks and confirm time progresses visibly.
5. Re-run NPC directed regression and at least a representative cpu-tests DiffTest subset; full sweep if feasible.
6. Update notes with the temporary-not-physical timer limitation and exact commands.

Relevant files:

- `notes/plan.md`
- `notes/next.md`
- `npc/README.md`
- `npc/csrc/main.cpp`
- `npc/csrc/memory.cpp`
- `npc/csrc/memory.h`
- `npc/rtl/NPC.v`
- `npc/rtl/core/Core.v`
- `npc/rtl/core/Lsu.v`
- `abstract-machine/am/src/riscv/npc/trm.c`
- `abstract-machine/am/src/riscv/npc/ioe.c`
- `abstract-machine/am/src/riscv/npc/timer.c`
- `nemu/.config`
- `nemu/src/device/serial.c`
- `nemu/src/device/timer.c`
- `nemu/src/device/Kconfig`
