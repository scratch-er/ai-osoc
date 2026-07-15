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

## Phase 6 status

`P6-S1: Physical CLINT design and implementation` is complete. The final approved CLINT topology is still recorded in `notes/clint-implementation-plan.md`.

Implemented behavior:

- `npc/rtl/core/Clint.v` is a physical RTL CLINT block with a 64-bit `mtime` that resets to zero and increments once per non-reset core clock.
- `npc/rtl/core/Core.v` routes LSU CLINT-window accesses through a combinational bypass before `AxiArbiter`; IFU, `AxiArbiter.v`, and `AxiMaster.v` were left unchanged.
- CLINT decode uses the approved cheap window compare `lsu_raw_addr[31:16] == 16'h0200`, covering `0x02000000..0x0200ffff`.
- `mtime` low/high are exposed at `0x0200bff8`/`0x0200bffc`; other CLINT-window reads return zero and writes have no effect/no error.
- `Core.v`/`NPC.v` now expose `commit_mem_ren` and `commit_mem_rdata`.
- `npc/csrc/main.cpp` synthesizes DiffTest MMIO replay records for committed CLINT reads from DUT RTL load data, while UART writes and C++ memory fallback/debug behavior remain available.
- NEMU NPC-device CLINT acceptance was expanded to the full project window `0x02000000..0x0200ffff` for replay compatibility.
- Added `make -C npc test-clint`, generated by `npc/tests/make-clint-bin.py`, to check ticking `mtime`, ignored no-error CLINT write/read, DiffTest replay, and that CLINT accesses do not hit C++ `Memory` MMIO trace.

Validation completed:

```sh
make -C npc
make -C nemu
make -C nemu SHARE=1
make -C npc test-clint
make -C npc test-lw-sw test-axi-local test-mem-size
make -C npc test-access-fault test-difftest
make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest test-clint
```

Results: all completed successfully. Exact-cycle non-CLINT checks still match their previous greps, including `test-lw-sw` at 24 cycles, `test-axi-local` at 24 cycles, `byte-half-memory` at 78 cycles, and DiffTest baseline cycle checks.

AM timer/devscan bounded smoke was also run:

```sh
make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=80000000 mainargs=d run
```

Result: printed `heap = ...` and `Input device test skipped.`, then hit the expected cycle limit while looping in the device/timer test (`NPC_RESULT status=limit reason=cycle_limit cycles=80000000 insts=15386380 ...`). Recent trace showed timer-derived values changing, so physical CLINT reads are live; this bounded smoke remains a P6-S2 workload-validation item, not a P6-S1 implementation failure.

Next session should start `P6-S2: Timer/DiffTest/workload validation`:

1. Re-run/extend AM timer/devscan with a better bounded pass criterion or a smaller targeted timer workload.
2. Run required workload matrix: NPC `hello`, CTE/yield/thread smokes, full 35-test `cpu-tests` with DiffTest, and NPC `rt-thread-am` with DiffTest.
3. Confirm no timer interrupt is generated and UART output remains ordered/non-duplicated.
4. Document expected bounded runs separately from real failures.

Relevant files for next session:

- `notes/plan.md`
- `notes/next.md`
- `notes/clint-implementation-plan.md`
- `npc/rtl/core/Clint.v`
- `npc/rtl/core/Core.v`
- `npc/rtl/NPC.v`
- `npc/csrc/main.cpp`
- `npc/csrc/memory.cpp`
- `npc/tests/make-clint-bin.py`
- `npc/Makefile`
- `nemu/src/memory/vaddr.c`
- `nemu/src/device/npc-dev.c`
- `abstract-machine/am/src/riscv/npc/timer.c`
