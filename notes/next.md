# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 (`RV32E_Zicsr Functional Core`) is complete through `P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening`.
- Phase 4 is complete and closed through `P4-S9: Workload regression and Phase 4 closeout`.
- Phase 5 is closed through `P5-S6: Full Phase 5 regression and closeout`.
- Phase 5 commits:
  - `a007e71 Refactor NEMU physical memory regions`
  - `e3e3002 Add MMIO replay for NPC DiffTest`
  - `e43f998 Add NPC internal memory request boundary`
  - `a15ed30 Add NPC AXI master simulation path`
  - `fe55944 Handle AXI access faults in DiffTest`
- Additional uncommitted cleanup after P5-S6: `nemu/src/memory/vaddr.c` fixes native NEMU MMIO access checks so native UART/RTC accesses are not mistaken for access faults.
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

## Native NEMU regression cleanup

Fixed before entering Phase 6.

Root cause:

- `nemu/src/memory/vaddr.c:vaddr_access_ok()` had been extended for NPC-compatible MMIO aliases (`0x10000000` UART and `0x02000000..0x0200bfff` CLINT) so NPC DiffTest access-fault replay worked.
- It did not include native NEMU device MMIO (`CONFIG_SERIAL_MMIO=0xa00003f8`, `CONFIG_RTC_MMIO=0xa0000048`).
- Native NEMU `putch()` stores to `0xa00003f8`; the access check treated those stores as invalid, raised store access faults, and with `mtvec=0` execution fell into an instruction-access-fault loop at `pc=0x00000000`.
- RT-Thread native NEMU later aborted for the same underlying native MMIO access-check problem.

Fix:

- `vaddr_access_ok()` now calls a guarded `native_device_access_ok()` helper that accepts enabled native serial/timer MMIO windows:
  - `CONFIG_HAS_SERIAL` / `CONFIG_SERIAL_MMIO`
  - `CONFIG_HAS_TIMER` / `CONFIG_RTC_MMIO`
- NPC-compatible UART/CLINT aliases remain valid for DiffTest replay.

Validated after the fix:

1. Rebuilt native and REF NEMU:

   ```sh
   make -C nemu
   make -C nemu SHARE=1
   ```

   Result: passed. `nemu/build/riscv32-nemu-interpreter` and `nemu/build/riscv32-nemu-interpreter-so` rebuilt.

2. Native NEMU `hello`:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=200000 run
   ```

   Result: passed. Output contained `Hello, AbstractMachine!`, `mainargs = ''.`, and `NEMU_RESULT status=good state=2 halt_pc=0x800000c4 halt_ret=0 insts=352 limit=200000`.

3. Native NEMU RT-Thread:

   ```sh
   make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=1000000 run
   ```

   Result: passed. Output contained the RT-Thread banner, `Hello RISC-V!`, scripted shell commands through `msh />halt`, and `NEMU_RESULT status=good state=2 halt_pc=0x80000234 halt_ret=0 insts=416082 limit=1000000`.

4. NPC directed DiffTest/access-fault smoke:

   ```sh
   make -C npc test-access-fault test-difftest
   ```

   Result: passed.

5. NPC full 35-test `cpu-tests` sweep with NEMU event DiffTest:

   ```sh
   ROOT=/Users/venti/Workspace/ai-ysyx
   TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
   REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so"
   for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
     tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
     printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
     make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=8000000 NPC_DIFFTEST_REF="$REF" run >/tmp/pre-p6-cputest-$t.log 2>&1
     status=$?
     rm -f "$tmp"
     if [ $status -ne 0 ]; then echo "FAILED $t"; tail -80 /tmp/pre-p6-cputest-$t.log; exit $status; fi
     echo "PASS $t"
   done
   ```

   Result: all 35 tests passed.

6. NPC RT-Thread with NEMU DiffTest:

   ```sh
   make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=12000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: passed through scripted shell `halt`; `NEMU_RESULT status=good`, `NPC_RESULT status=good reason=good_trap cycles=2343298 insts=511954 ...`.

7. Native NEMU AM devscan/timer smoke:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=2000000 mainargs=d run || true
   ```

   Result: bounded by instruction limit after printing `heap = ...` and `Input device test skipped.`. This is expected for the current bounded smoke.

## Phase 6 plan

Start Phase 6 with `P6-S1: Physical CLINT design and implementation`.

Current Phase 6 sessions in `notes/plan.md`:

1. `P6-S1: Physical CLINT design and implementation` — merged former S1/S2. Locate temporary timer code, prepare a concrete implementation plan for the RTL/harness boundary and let the user revise it if needed, preserve MMIO replay, add directed CLINT tests, and replace the retired-instruction timer with physical cycle-based `mtime` plus ignored `msip`/`mtimecmp` behavior.
2. `P6-S2: Timer/DiffTest/workload validation` — merged former S3/S4. Revalidate robust AM timer reads, replayed physical `mtime` values, monotonic/rollover-oriented timer tests where practical, and the required workload matrix (`hello`, timer/devscan, CTE, cpu-tests, RT-Thread).
3. `P6-S3: Phase 6 closeout notes` — update notes and user-facing docs only if commands or platform behavior changed.

Spec reminders for Phase 6:

- `specs/core.md`: built-in CLINT only implements `mtime`/`mtimeh`, no interrupts, increments by 1 each core cycle, default window `0x02000000..0x0200ffff`, and `msip`/`mtimecmp` accesses are ignored with no error and undefined read content.
- `specs/clint.rst`: reference offsets are `msip=0x0`, `mtimecmp=0x4000`, and `mtime=0xbff8` under base `0x02000000`; other reserved offsets in the reference IP generate slave error.
- Project decision: follow `specs/core.md` where it is more specific for this core, while retaining `specs/clint.rst` offsets/window behavior for implemented registers.

Relevant files for next session:

- `notes/plan.md`
- `notes/next.md`
- `nemu/src/memory/vaddr.c`
- `abstract-machine/am/src/riscv/npc/timer.c`
- `npc/rtl/NPC.v`
- `npc/rtl/core/Core.v`
- `npc/rtl/bus/LocalAxiSlave.v`
- `npc/csrc/memory.cpp`
- `npc/csrc/difftest.cpp`
- `npc/csrc/main.cpp`
