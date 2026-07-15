# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 (`RV32E_Zicsr Functional Core`) is complete through `P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening`.
- Phase 4 is complete through `P4-S6: CTE validation with existing am-kernels workloads`.
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

P4-S6 completed work:

- Fixed the shared RISC-V AM `Context` layout in `abstract-machine/am/include/arch/riscv.h` to match the trap frame saved by `trap.S`: GPRs first, then `mcause`, `mstatus`, and `mepc`.
- Updated `GPR2`/`GPR3`/`GPR4`/`GPRx` macros to name `a0`/`a1`/`a2` consistently instead of all aliasing `gpr[0]`.
- Implemented RISC-V AM CTE behavior for both `riscv32e-npc` and `riscv32-nemu` AM targets:
  - classify machine `ecall` cause 11 as `EVENT_YIELD` when `GPR1 == -1`, otherwise `EVENT_SYSCALL`;
  - advance `mepc` by 4 after handled `ecall` so `mret` resumes after the trapping instruction;
  - allow `__am_irq_handle()` to return a different `Context *` and make `trap.S` switch `sp` to that returned context;
  - save the trap-frame `sp` slot for completeness;
  - implement `kcontext()` by placing a zeroed `Context` at the top of the kernel stack and using `s0` for `arg`, `s1` for `entry`.
- Added `__am_kcontext_start` trampolines in both `abstract-machine/am/src/riscv/npc/trap.S` and `abstract-machine/am/src/riscv/nemu/trap.S`; the trampoline runs `mv a0, s0; jalr s1`.
- Linked the NPC AM target against `abstract-machine/am/src/riscv/npc/mpe.c` instead of the dummy MPE stub, then implemented the single-core MPE hooks needed by `thread-os`: call the bootstrap entry from `mpe_init()`, report one CPU/current CPU 0, and provide a simple single-core `atomic_xchg()`.
- Validated CTE with the existing `am-kernels/kernels/yield-os` and `am-kernels/kernels/thread-os` workloads. No custom workload was added.

Validated commands and results:

1. Rebuild NEMU REF shared object:

   ```sh
   make -C nemu ISA=riscv32 SHARE=1
   ```

   Result: passed/no-op (`make: Nothing to be done for 'app'.`).

2. Rebuild NEMU native executable:

   ```sh
   make -C nemu
   ```

   Result: passed/no-op (`make: Nothing to be done for 'app'.`).

3. Full NPC directed regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed by Makefile expectations. Some subtests intentionally return BAD/limit to validate failure/debug paths, so raw logs include expected `status=bad`/`status=limit` lines.

4. NPC `hello` with UART and NEMU event DiffTest:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=200000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: passed; printed `Hello, AbstractMachine!`, `mainargs = ''.`, and:

   ```text
   NPC_RESULT status=good reason=good_trap cycles=465 insts=465 pc=0x800000c4 halted=1 limit=200000 x1=0x800000c0 a0=0x00000000 trap=1
   ```

5. NPC `yield-os` CTE smoke with NEMU event DiffTest:

   ```sh
   make -C am-kernels/kernels/yield-os ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=2000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: expected bounded run. It printed `ABAB`, reported no `NPC_DIFFTEST status=fail`, then hit the cycle limit because `yield-os` is intentionally infinite:

   ```text
   NPC_RESULT status=limit reason=cycle_limit cycles=2000000 insts=2000000 ...
   ```

   The command exits nonzero because the AM/NPC run path treats hitting the bound as a failed run, but this is the expected terminal condition for this workload.

6. NPC `thread-os` CTE/MPE smoke with NEMU event DiffTest:

   ```sh
   make -C am-kernels/kernels/thread-os ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=5000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: expected bounded run. It printed repeated `Thread-B on CPU #0`, reported no `NPC_DIFFTEST status=fail`, then hit the cycle limit because `thread-os` is intentionally infinite:

   ```text
   NPC_RESULT status=limit reason=cycle_limit cycles=5000000 insts=5000000 ...
   ```

   With `cpu_count() == 1`, the scheduler selects the subset of tasks whose index modulo CPU count matches CPU 0; after the bootstrap yield it starts at task B and keeps running it because there is no timer interrupt/preemption in Phase 4.

7. NEMU `yield-os` CTE smoke:

   ```sh
   make -C am-kernels/kernels/yield-os ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     NEMU_HOME=/Users/venti/Workspace/ai-ysyx/nemu \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=2000000 run
   ```

   Result: expected bounded run. It printed `ABAB`, then hit the instruction limit because `yield-os` is intentionally infinite:

   ```text
   NEMU_RESULT status=limit state=5 halt_pc=0x80000098 halt_ret=1 insts=2000000 limit=2000000
   ```

   The command exits nonzero because the AM/NEMU run path treats hitting the bound as a failed run, but this is the expected terminal condition for this workload.

8. NPC `am-tests mainargs=d` with timer/UART and NEMU event DiffTest:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=80000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so mainargs=d run
   ```

   Result: same expected Phase 4 status as before. DiffTest ran through UART/timer with no mismatch, printed `Loop 10^7 time elapse: 500 ms`, then panicked on optional/unimplemented IOE register probing:

   ```text
   AM Panic: access nonexist register @ .../abstract-machine/am/src/riscv/npc/ioe.c:26
   NPC_RESULT status=bad reason=bad_trap cycles=50013020 insts=50013020 pc=0x800010a4 ...
   ```

9. NPC `am-tests mainargs=t` with timer/UART and NEMU event DiffTest:

   ```sh
   make -C am-kernels/tests/am-tests ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=120000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so mainargs=t run
   ```

   Result: same expected Phase 4 status as before. Printed `1900-1-1 00:00:01 GMT (1 second).`, then hit the cycle limit because the RTC test is intentionally infinite:

   ```text
   NPC_RESULT status=limit reason=cycle_limit cycles=120000000 insts=120000000 ...
   ```

10. NEMU `hello` with UART output:

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

11. Full 35-test `cpu-tests` sweep on NPC with NEMU event DiffTest:

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
- NEMU/NPC `am-tests mainargs=d` still panic after the timer/devscan section because optional device IOE entries are not implemented. This is outside the UART/timer/CTE scope.
- NEMU/NPC `am-tests mainargs=t` is intentionally infinite after printing periodically; use bounded runs and look for visible output/time progression.
- NEMU/NPC `yield-os` is intentionally infinite; use bounded runs and look for alternating output (`ABAB...`) plus no DiffTest mismatch.
- NPC `thread-os` is intentionally infinite; in the current single-core/no-interrupt Phase 4 setup, use bounded runs and look for `Thread-B on CPU #0` plus no DiffTest mismatch. It does not preemptively rotate among all tasks because timer interrupts are still unsupported.
- The current precise trap path is single-cycle and vector-only (`pc = mtvec`); interrupts are still unsupported by design.
- `fence.i` is a visible no-state hook for now; actual icache clearing waits for Phase 7.
- NPC CommitEvent still does not carry memory or CSR access summaries for DiffTest comparison. Store metadata is currently exposed separately only for harness-side UART ordering.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.
- Keep this through Phase 4/5: Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C calls. Side-effectful devices must remain explicitly ordered by retirement or another harness/interface protocol.
- M-extension remains out of scope for the NPC core because the target is RV32E_Zicsr. NEMU implements RV32M only because its `riscv32-nemu` AM target uses `rv32im_zicsr`.
- UART input is intentionally unsupported in Phase 4.

P4-S7 completed work:

- Fixed RT-Thread AM generated config on macOS by replacing the GNU `sed -i` assumption in `rt-thread-am/bsp/abstract-machine/Makefile` with a portable `awk` insertion for `#include "extra.h"`.
- Added the RT-Thread freestanding extension include path and pre-included `sys/types.h` from the BSP Makefile so the selected RT-Thread configuration can compile without host libc headers.
- Made `rt-thread-am/bsp/abstract-machine/integrate-am-apps.py` skip optional AM apps that are missing or fail to build. Current `make init` skips `snake` because its AM-app build includes unavailable `<stdlib.h>`, and skips missing `fceux-am`.
- Added minimal freestanding compatibility headers under `rt-thread-am/components/libc/compilers/common/extension/`: `ctype.h`, `errno.h`, `fcntl.h`, `limits.h`, `stdio.h`, `stdlib.h`, `string.h`, `time.h`, and `wchar.h`.
- Updated `rt-thread-am/components/libc/compilers/common/extension/sys/errno.h` so GCC/freestanding builds get POSIX errno constants and `errno` maps to RT-Thread's `_rt_errno()` storage.
- Implemented `rt-thread-am/bsp/abstract-machine/src/context.c`:
  - `rt_hw_stack_init()` creates a `kcontext()` and stores `tentry`, `parameter`, and `texit` in the new thread's own stack area;
  - `rt_hw_context_switch_to()` and `rt_hw_context_switch()` use AM `yield()` and the CTE event handler to return the target `Context *`, saving the outgoing context through `from` when needed;
  - `rt_hw_context_switch_interrupt()` still asserts because Phase 4 has no timer interrupts.
- Fixed `rt-thread-am/bsp/abstract-machine/src/interrupt.c` prototypes to match RT-Thread UP declarations: `rt_hw_interrupt_disable()` returns the old enable state and `rt_hw_interrupt_enable(level)` restores based on that state.
- Reduced `rt-thread-am/bsp/abstract-machine/src/uart.c` from broad `rtdevice.h` to the serial driver headers needed for console registration.
- Clamped the NEMU RT-Thread heap end in `rt-thread-am/bsp/abstract-machine/src/init.c` to `0x82000000` for `ARCH=riscv32-nemu`, matching the current native NEMU memory `[0x80000000, 0x81ffffff]`. Without this, RT-Thread allocated past NEMU's real memory because AM's NEMU header still declares 128 MiB.

Validated P4-S7 commands and results:

1. Initialize generated RT-Thread AM files:

   ```sh
   make init ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf-
   ```

   Result: passed. It generated `rtconfig.h` and `files.mk`. During AM app integration it skipped `snake` and missing `fceux-am`, but kept `hello`, `microbench`, and `typing-game` integrated.

2. NEMU RT-Thread AM smoke:

   ```sh
   make ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     NEMU_HOME=/Users/venti/Workspace/ai-ysyx/nemu \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=5000000 run
   ```

   Result: expected bounded run. It printed:

   ```text
   am-apps.data.size = 1772, am-apps.bss.size = 44244
   heap: [0x80043000 - 0x82000000]
   - RT -     Thread Operating System
   5.0.1 build Jul 15 2026 11:37:52
   Hello RISC-V!
   msh />help
   RT-Thread shell commands:
   ...
   msh />utest_list
   [I/utest] Commands list :
   msh />
   NEMU_RESULT status=limit state=5 halt_pc=0x80013128 halt_ret=1 insts=5000000 limit=5000000
   ```

   The command exits nonzero only because NEMU reports the configured instruction limit after RT-Thread reaches idle/shell; this is expected for this smoke because RT-Thread does not terminate by design and UART RX is scripted/noninteractive.

Known P4-S7 caveats:

- `rt_hw_context_switch_interrupt()` remains unsupported by design for Phase 4; timer interrupts/preemptive scheduling are still out of scope.
- `rt-thread-am` now reaches the required NEMU smoke milestone, but NPC RT-Thread has not been run yet.
- RT-Thread AM app integration is partial: `hello`, `microbench`, and `typing-game` are integrated; `snake` fails its separate AM build due to missing `<stdlib.h>` in that AM app path, and `fceux-am` is absent. This is not a blocker for the RT-Thread boot smoke.
- AM's NEMU platform still declares a stale 128 MiB `PMEM_END`, while the current NEMU native build exposes 32 MiB. P4-S7 clamps only RT-Thread's NEMU heap; a broader AM/NEMU memory-size cleanup can be considered separately.

P5-S1 completed work:

- Chose the NEMU memory-map direction: keep NEMU as an independent region-based reference and use ordered DiffTest replay only for side-effectful/nondeterministic devices, not for all DUT bus transactions.
- Refactored NEMU physical memory simulation from direct `CONFIG_MBASE`/`CONFIG_MSIZE` pointer arithmetic to a small compile-time `MemRegion` table in `nemu/src/memory/paddr.c`.
- Added memory-region attributes requested for future SoC maps:
  - `loadable`: simulation image/DiffTest injection may copy bytes into the region;
  - `writable`: core stores may modify the region.
- Added `paddr_is_backed()`, `paddr_is_loadable()`, `paddr_memcpy_to_guest()`, and `paddr_memcpy_from_guest()` in `nemu/include/memory/paddr.h` / `nemu/src/memory/paddr.c`.
- Updated NEMU native image loading, TARGET_AM image loading, built-in ISA images, and REF `difftest_memcpy()` to use the new checked copy helpers instead of raw `memcpy(guest_to_host(...))`.
- Added a compile-time Kconfig memory-map scheme choice in `nemu/src/memory/Kconfig`:
  - `MEM_SCHEME_LEGACY`: default single loadable/writable RAM using `CONFIG_MBASE`/`CONFIG_MSIZE`;
  - `MEM_SCHEME_NPC`: NPC simulation map placeholder, currently a 16 MiB loadable/writable region at `CONFIG_MBASE` to match NPC DiffTest image copying.
- Synchronized `nemu/.config` so `CONFIG_MEM_SCHEME_LEGACY=y` is explicit.

Validated P5-S1 commands and results:

1. Rebuild NEMU native executable and REF shared object:

   ```sh
   make -C nemu
   make -C nemu ISA=riscv32 SHARE=1
   ```

   Result: passed/no-op after the final config sync (`make: Nothing to be done for 'app'.`). Earlier rebuilds compiled `src/memory/paddr.c` and linked both outputs successfully.

2. NEMU `hello` smoke:

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

3. NPC `hello` with NEMU event DiffTest:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=200000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: passed; printed `Hello, AbstractMachine!` and:

   ```text
   NPC_RESULT status=good reason=good_trap cycles=465 insts=465 pc=0x800000c4 halted=1 limit=200000 x1=0x800000c0 a0=0x00000000 trap=1
   ```

4. Full NPC directed regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed by Makefile expectations. Some raw output intentionally contains expected `status=bad`, `status=limit`, and check-fail snippets for negative/debug-path tests.

5. Full 35-test `cpu-tests` sweep on NPC with NEMU event DiffTest:

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

Known P5-S1 caveats:

- The region table currently has one region in each scheme; it is now structurally ready for multiple regions, but no ROM/non-loadable/non-writable directed test has been added yet.
- `MEM_SCHEME_NPC` is present but not selected by the checked-in `.config`; select it with Kconfig and rebuild when the NPC/NEMU map mismatch must be exercised directly.
- NEMU `paddr.c` still contains the temporary NPC UART/CLINT fallback aliases from Phase 4. They should move into device/MMIO or platform-specific code in the next MMIO replay/device cleanup slice.
- `paddr_memcpy_to_guest()` currently requires a copied range to fit within one region. That is fine for current binary loading and DiffTest image injection, but future ELF/multi-region loading should copy chunk-by-chunk across loadable regions.

P4-S8 / RT-Thread NPC DiffTest follow-up completed work:

- Committed the NEMU memory-region refactor as:

  ```text
  a007e71 Refactor NEMU physical memory regions
  ```

- Re-ran RT-Thread on NPC with NEMU DiffTest and reproduced the first blocker: RT-Thread allocated up to the AM-declared 128 MiB NPC heap end (`0x88000000`), while the NPC simulation memory was only 16 MiB. The first failure was an out-of-bounds write near `0x87fffff0`, followed by a NEMU reference MMIO/out-of-bound abort.
- Fixed the NPC simulation memory size in `npc/csrc/memory.h` from 16 MiB to 128 MiB so it matches `abstract-machine/am/src/riscv/npc/trm.c` (`PMEM_SIZE = 128 * 1024 * 1024`) and the NEMU reference memory size used by the current `.config` after local config sync.
- Added an RT-Thread BSP shell command `halt` in `rt-thread-am/bsp/abstract-machine/src/halt.c`. It executes `ebreak` with `a0 = 0`.
- Appended `halt` to the fixed UART input script in `rt-thread-am/bsp/abstract-machine/src/uart.c`, after `utest_list`.
- Updated NPC harness/DiffTest termination semantics for `ebreak`: the RTL still treats `ebreak` as a physical breakpoint/trap, while the C++ harness terminates simulation when the retired DUT and REF instructions are both `ebreak` at the same PC. If only one side retires `ebreak`, or the PCs differ, DiffTest reports `ebreak_mismatch`.
- Validated RT-Thread on NPC with NEMU event DiffTest. The run reaches the RT-Thread banner, shell command output, `memtrace`, `memcheck`, `utest_list`, then `halt`, and exits with `NPC_RESULT status=good reason=good_trap`.

Validated RT-Thread NPC DiffTest command:

```sh
make ARCH=riscv32e-npc \
  AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-elf- \
  NPC_MAX_CYCLES=5000000 \
  NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so \
  run
```

Run it from:

```sh
/Users/venti/Workspace/ai-ysyx/rt-thread-am/bsp/abstract-machine
```

Expected result:

- The command exits zero.
- Treat the run as successful if output contains:
  - `NPC_DIFFTEST status=on`
  - RT-Thread banner (`Thread Operating System`)
  - `Hello RISC-V!`
  - `msh />help`
  - `msh />utest_list`
  - `msh />halt`
  - `NEMU_RESULT status=good`
  - final `NPC_RESULT status=good reason=good_trap`
- Treat it as failed if output contains `NPC_DIFFTEST status=fail`, `difftest_mismatch`, `ebreak_mismatch`, assertion failures, host aborts, out-of-bounds memory messages, or `NPC_RESULT status=limit`.

Additional validation after the memory-size change:

1. NEMU `hello` smoke passed with 128 MiB memory:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32-nemu \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     NEMU_HOME=/Users/venti/Workspace/ai-ysyx/nemu \
     CROSS_COMPILE=riscv64-elf- NEMU_MAX_INSTS=200000 run
   ```

   Result included:

   ```text
   NEMU_RESULT status=good state=2 halt_pc=0x800000c4 halt_ret=0 insts=352 limit=200000
   ```

2. NPC `hello` with NEMU DiffTest passed:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=200000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result included:

   ```text
   NPC_RESULT status=good reason=good_trap cycles=465 insts=465 pc=0x800000c4 halted=1 limit=200000 x1=0x800000c0 a0=0x00000000 trap=1
   ```

3. Full NPC directed regression passed by Makefile expectations:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

Next work:

Continue with `P5-S2: device-aware MMIO cleanup and replay groundwork`.

Concrete P5-S2 plan:

1. Move the temporary NPC UART/CLINT address handling out of generic `paddr.c` into a platform/device helper or proper MMIO maps.
2. Define the ordered MMIO replay contract for UART/timer/CLINT reads/writes without replaying all RAM bus transactions.
3. Add directed tests for non-writable/loadable region behavior, either by temporarily selecting a scheme with a ROM-like region or by a narrow unit-style memory test.
4. Re-run NEMU `hello`, NPC `hello` with DiffTest, RT-Thread NPC DiffTest, NPC directed regression, and the 35 `cpu-tests` sweep.

Relevant files:

- `notes/plan.md`
- `notes/next.md`
- `nemu/src/memory/paddr.c`
- `nemu/include/memory/paddr.h`
- `nemu/src/memory/Kconfig`
- `nemu/src/monitor/monitor.c`
- `nemu/src/cpu/difftest/ref.c`
- `nemu/src/device/io/mmio.c`
- `nemu/src/device/io/map.c`
- `npc/csrc/difftest.cpp`
- `npc/csrc/memory.cpp`
- `npc/csrc/memory.h`
