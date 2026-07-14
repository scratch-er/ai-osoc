# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 (`RV32E_Zicsr Functional Core`) is complete through `P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening`.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store` and `activate`; leave them alone unless the user explicitly asks.
- Top-level `build/` contains generated AM/NPC images and sweep logs from smoke/regression runs; do not assume it should be committed unless intentionally adding an artifact.

Toolchain/config reminders:

- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- Devices remain disabled because native NEMU device build on this macOS environment failed earlier on missing `SDL2/SDL.h`.
- NEMU REF shared object remains `nemu/build/riscv32-nemu-interpreter-so` and exports the CommitEvent APIs used by NPC DiffTest.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because it uses `/bin/echo -e`; use the temporary Makefile/`printf` workaround below unless changing `am-kernels/` is explicitly allowed.

P3-S4 completed work:

- Ran the full `am-kernels/tests/cpu-tests/tests/*.c` source set through `ARCH=riscv32e-npc` with `NPC_MAX_CYCLES=2000000`.
- Confirmed the multiply/division-related workloads pass when built correctly for RV32E:
  - `div` passed (`cycles=16488`).
  - `mul-longlong` passed (`cycles=6333`).
  - No RTL M-extension was added; AM/libgcc software helpers implement the operations.
- Fixed the remaining cpu-test failures by implementing the missing AM klib pieces in `abstract-machine/klib/src/`:
  - `string.c`: `strlen`, `strcpy`, `strncpy`, `strcat`, `strcmp`, `strncmp`, `memset`, `memmove`, `memcpy`, `memcmp`.
  - `stdio.c`: minimal `printf`, `sprintf`, `snprintf`, `vsprintf`, `vsnprintf` with `%s`, `%d`, `%u`, `%x`, `%p`, `%c`, and `%%` support.
- Added optional DiffTest plumbing to AM's NPC run path:
  - `abstract-machine/scripts/platform/npc.mk` accepts `NPC_DIFFTEST_REF=/path/to/ref.so` and passes `--difftest-ref` to `npc/build/npc`.
- Updated `npc/README.md` and `notes/plan.md` to mark Phase 3 complete through P3-S4.

Validated commands and results:

1. Full NPC regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed.

2. Full cpu-tests sweep on NPC without DiffTest:

   ```sh
   ROOT=/Users/venti/Workspace/ai-ysyx
   TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
   for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
     tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
     printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
     make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=2000000 run
     status=$?
     rm -f "$tmp"
     if [ $status -ne 0 ]; then exit $status; fi
   done
   ```

   Result: all 35 cpu-tests passed.

3. Full cpu-tests sweep on NPC with NEMU event DiffTest:

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

Full cpu-test pass list from the DiffTest sweep:

- `add`, `add-longlong`, `bit`, `bubble-sort`, `crc32`, `div`, `dummy`, `fact`, `fib`, `goldbach`, `hello-str`, `if-else`, `leap-year`, `load-store`, `matrix-mul`, `max`, `mersenne`, `min3`, `mov-c`, `movsx`, `mul-longlong`, `narcissistic`, `pascal`, `prime`, `quick-sort`, `recursion`, `select-sort`, `shift`, `string`, `sub-longlong`, `sum`, `switch`, `to-lower-case`, `unalign`, `wanshu`.

Selected cycle counts from the final DiffTest sweep:

- `dummy`: 13
- `add`: 1109
- `div`: 16488
- `mul-longlong`: 6333
- `matrix-mul`: 132126
- `narcissistic`: 132630
- `hello-str`: 1677
- `string`: 1449

Known caveats:

- The current precise trap path is single-cycle and vector-only (`pc = mtvec`); interrupts are still unsupported by design.
- `fence.i` is a visible no-state hook for now; actual icache clearing waits for Phase 7.
- NPC CommitEvent still does not carry memory or CSR access summaries; `--mem-trace` still prints immediate memory read/write lines.
- Event-API DiffTest compares CommitEvent fields. Full CSR state is checked on the fallback reg-copy path and initialized for REF, but CSR details are not in CommitEvent yet.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.
- Keep this through Phase 4: Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C calls. Do not model side-effectful emulated memory/peripherals as combinational DPI-C reads/writes; make side effects explicit, preferably clocked or otherwise ordered by the harness/interface.
- M-extension tests remain out of scope because the target core is RV32E_Zicsr.
- `putch()` for `riscv32e-npc` is still empty and UART output is not implemented yet; cpu-tests pass because they validate via traps/assertions, not visible console output.

Next work:

Phase 4 (`AM Runtime and Essential Workloads`) has now been revised again in `notes/plan.md` for user review. Before implementing, let the user revise the plan.

Important planning decisions now recorded:

1. Phase 4 should implement UART output and a temporary DiffTest-friendly timer first; defer broad RT-Thread debugging until those basics are stable.
2. UART input is out of scope for Phase 4 because no Phase 4 workload needs it.
3. NPC UART output remains planned at `0x10000000`, with side effects ordered outside unordered combinational DPI reads/writes.
4. Phase 4 timer support should expose `mtime`/`mtimeh` but advance deterministically by retired-instruction count, not physical core cycles, so current DiffTest remains usable; convert it by AM with the 100 MHz assumption and do not add timer interrupts.
5. NEMU may be modified to support UART/temporary timer devices, preferably through its existing device framework.
6. Simulation termination on `ebreak` happens in the harness when detecting that an `ebreak` retired, not in an AM trap handler.
7. Use existing `am-kernels` workloads such as `yield-os` for CTE validation; do not create a custom CTE workload unless existing tests cannot isolate a confirmed bug.
8. AM klib can be completed by copying/adapting Sonnet libc (`https://gitlink.org.cn/foobat/sonnet-libc`) when needed.
9. Proper physical CLINT must wait until Phase 5 device-aware DiffTest replay is implemented: REF peripherals off/suppressed, DUT MMIO read values captured, and those MMIO inputs replayed to REF.

After review, start with `P4-S1: AM/NEMU/NPC device audit and baselines`, then proceed to NPC UART/hello.

Relevant files:

- `notes/plan.md`
- `notes/next.md`
- `npc/README.md`
- `npc/Makefile`
- `npc/csrc/main.cpp`
- `npc/csrc/memory.cpp`
- `npc/csrc/dpi.cpp`
- `npc/csrc/difftest.cpp`
- `npc/rtl/NPC.v`
- `npc/rtl/core/Core.v`
- `abstract-machine/scripts/platform/npc.mk`
- `abstract-machine/am/src/riscv/npc/trm.c`
- `abstract-machine/klib/src/string.c`
- `abstract-machine/klib/src/stdio.c`
