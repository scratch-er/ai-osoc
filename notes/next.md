# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 (`RV32E_Zicsr Functional Core`) is complete through `P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening`.
- Phase 4 has started. `P4-S1: AM/NEMU/NPC device audit and baselines` is complete.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store` and `activate`; leave them alone unless the user explicitly asks.
- Top-level `build/` contains generated AM/NPC images and sweep logs from smoke/regression runs; do not assume it should be committed unless intentionally adding an artifact.

Toolchain/config reminders:

- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because it uses `/bin/echo -e`; use the temporary Makefile/`printf` workaround below unless changing `am-kernels/` is explicitly allowed.
- NEMU REF shared object remains `nemu/build/riscv32-nemu-interpreter-so` and exports the CommitEvent APIs used by NPC DiffTest.
- NEMU `.config` currently has `# CONFIG_DEVICE is not set`. Earlier native device builds on this macOS environment failed on missing `SDL2/SDL.h`; P4 should enable only UART/timer without pulling in graphical SDL dependencies.
- `make -C nemu menuconfig` is interactive; do not run it in automation. During P4-S1 it was accidentally started and then stopped immediately.

P4-S1 completed work:

- Audited current AM/NPC/NEMU device-related paths:
  - `abstract-machine/am/src/riscv/npc/trm.c`: `putch()` is empty; `halt()` passes the code in `a0` and executes `ebreak`.
  - `abstract-machine/am/src/riscv/npc/ioe.c`: timer/input handlers are wired, UART config currently reports `present = false`, and there is no UART TX handler.
  - `abstract-machine/am/src/riscv/npc/timer.c`: uptime always returns `0`; RTC is a fixed `1900-0-0 00:00:00`.
  - `abstract-machine/am/src/riscv/npc/cte.c` and `trap.S`: trap vector setup and register save/restore exist, but event classification only returns `EVENT_ERROR`; `kcontext()` is still `NULL`.
  - `npc/csrc/memory.cpp`: only normal PMEM read/write exists; out-of-range accesses report `pmem read/write out of bounds`; no MMIO dispatch yet.
  - `npc/rtl/core/Ifu.v` and `npc/rtl/core/Lsu.v`: still use combinational DPI-C `pmem_read()`/`pmem_write()`.
  - `nemu/src/device/serial.c` and `timer.c`: existing device framework has serial and RTC-style timer maps, currently disabled by `.config`.
  - `abstract-machine/scripts/platform/nemu.mk`: currently passes `-l <log>` in `NEMUFLAGS`, but this NEMU CLI no longer accepts `-l`; override `NEMUFLAGS` for NEMU AM runs until the script is fixed.
- Re-ran Phase 3 baselines:
  - NPC directed regression passed.
  - Full 35-test `cpu-tests` sweep with NEMU event DiffTest passed.
- Captured first Phase 4 baseline behavior:
  - NPC `hello` reaches GOOD trap but prints nothing because `putch()` is empty.
  - NPC `am-tests` `mainargs=t` times out because AM uptime never advances.
  - NPC `am-tests` `mainargs=d` times out in devscan/printing because UART output is not implemented.
  - NEMU `hello` passes when overriding stale `-l` flag with `NEMUFLAGS='-b --max-insts=1000000'`.

Validated commands and results:

1. Full NPC regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed.

2. Full cpu-tests sweep on NPC with NEMU event DiffTest:

   ```sh
   ROOT=/Users/venti/Workspace/ai-ysyx
   TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
   for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
     tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
     printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
     make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=2000000 NPC_DIFFTEST_REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so" run
     status=$?
     rm -f "$tmp"
     if [ $status -ne 0 ]; then exit $status; fi
   done
   ```

   Result: all 35 cpu-tests passed with DiffTest enabled.

3. NPC `hello` baseline:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=200000 run
   ```

   Result: `NPC_RESULT status=good reason=good_trap cycles=387 insts=387`, but no `Hello, AbstractMachine!` text appears because `putch()` is empty.

4. NPC timer baseline failure:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=50000 mainargs=t run
   ```

   Result: expected bounded failure, `NPC_RESULT status=limit reason=cycle_limit`, because `__am_timer_uptime()` returns `0` forever.

5. NPC devscan/printing baseline failure:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=50000 mainargs=d run
   ```

   Result: expected bounded failure, `NPC_RESULT status=limit reason=cycle_limit`, because the workload prints through empty `putch()` and cannot produce visible output yet.

6. NEMU `hello` smoke with stale flag overridden:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NEMUFLAGS='-b --max-insts=1000000' run
   ```

   Result: passed and printed:

   ```text
   Hello, AbstractMachine!
   mainargs = ''.
   NEMU_RESULT status=good ... halt_ret=0 ...
   ```

Known caveats:

- The current precise trap path is single-cycle and vector-only (`pc = mtvec`); interrupts are still unsupported by design.
- `fence.i` is a visible no-state hook for now; actual icache clearing waits for Phase 7.
- NPC CommitEvent still does not carry memory or CSR access summaries; `--mem-trace` still prints immediate memory read/write lines.
- Event-API DiffTest compares CommitEvent fields. Full CSR state is checked on the fallback reg-copy path and initialized for REF, but CSR details are not in CommitEvent yet.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.
- Keep this through Phase 4: Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C calls. Do not model side-effectful emulated memory/peripherals as combinational DPI-C reads/writes; make side effects explicit, preferably clocked or otherwise ordered by the harness/interface.
- M-extension tests remain out of scope because the target core is RV32E_Zicsr.
- `putch()` for `riscv32e-npc` is still empty and UART output is not implemented yet; cpu-tests pass because they validate via traps/assertions, not visible console output.
- `am-tests` `rtc` is intentionally infinite after printing periodically; use bounded runs and look for visible output/time progression once timer/UART exist.

Next work:

Start `P4-S2: NPC ordered UART MMIO and AM putch()`.

Concrete P4-S2 plan:

1. Add NPC simulation UART output at `0x10000000`.
   - Support at least byte writes at offset `0` and word writes/masks that include byte 0.
   - Keep side effects ordered by retired store handling or another explicit harness protocol; avoid relying on unordered combinational DPI-C write side effects.
2. Update `abstract-machine/am/src/riscv/npc/trm.c` `putch()` to write to `0x10000000`.
3. Update `abstract-machine/am/src/riscv/npc/ioe.c` if needed so UART config reports output capability and optional `AM_UART_TX` uses `putch()`.
4. Run NPC `hello` and confirm visible output plus final GOOD `NPC_RESULT`.
5. Re-run NPC directed regression and a small cpu-tests smoke set; if feasible, re-run the full cpu-tests with DiffTest.
6. Update `npc/README.md` only if new user-facing flags or output behavior need documenting.

Relevant files:

- `notes/plan.md`
- `notes/next.md`
- `npc/README.md`
- `npc/Makefile`
- `npc/csrc/main.cpp`
- `npc/csrc/memory.cpp`
- `npc/csrc/memory.h`
- `npc/csrc/dpi.cpp`
- `npc/csrc/difftest.cpp`
- `npc/rtl/NPC.v`
- `npc/rtl/core/Core.v`
- `npc/rtl/core/Lsu.v`
- `abstract-machine/scripts/platform/npc.mk`
- `abstract-machine/scripts/platform/nemu.mk`
- `abstract-machine/am/src/riscv/npc/trm.c`
- `abstract-machine/am/src/riscv/npc/ioe.c`
- `abstract-machine/am/src/riscv/npc/timer.c`
- `abstract-machine/am/src/riscv/npc/cte.c`
- `abstract-machine/am/src/riscv/npc/trap.S`
- `nemu/src/device/serial.c`
- `nemu/src/device/timer.c`
- `nemu/src/device/Kconfig`
