# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 is complete through `P3-S2: Branches and byte/halfword memory operations`.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store` and `activate`; leave them alone unless the user explicitly asks.
- Top-level `build/` contains generated AM/NPC images from smoke runs; do not assume it should be committed unless intentionally adding an artifact.

Toolchain/config reminders:

- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- Devices remain disabled because native NEMU device build on this macOS environment failed earlier on missing `SDL2/SDL.h`.
- NEMU REF shared object remains `nemu/build/riscv32-nemu-interpreter-so` and exports the CommitEvent APIs used by NPC DiffTest.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because it uses `/bin/echo -e`; use the temporary Makefile/`printf` workaround below unless changing `am-kernels/` is explicitly allowed.

P3-S2 completed work:

- Extended NPC memory instruction coverage:
  - Loads: `lb`, `lh`, `lw`, `lbu`, `lhu`.
  - Stores: `sb`, `sh`, `sw`.
  - `npc/rtl/core/Idu.v` now accepts all RV32I load/store `funct3` values in scope and emits `mem_size` plus `mem_unsigned`.
  - `npc/rtl/core/Lsu.v` now aligns DPI reads to words, formats byte/halfword loads with sign/zero extension, and creates byte masks for `sb`/`sh`/`sw`.
  - `npc/csrc/memory.cpp`/`.h` now support masked 32-bit writes; memory trace lines include `mask=...` for writes.
- Added exception-style checks that still halt BAD until P3-S3 precise traps:
  - Branch/jump target misalignment -> CommitEvent `CAUSE=0`.
  - Load address misalignment -> `CAUSE=4`.
  - Store address misalignment -> `CAUSE=6`.
- Added directed raw binary tests:
  - `npc/tests/bin/byte-half-memory.bin`
  - `npc/tests/bin/load-misaligned.bin`
  - `npc/tests/bin/store-misaligned.bin`
  - `npc/tests/bin/branch-misaligned.bin`
- Added `make -C npc test-mem-size` and included it in the documented regression command.
- Updated `npc/README.md` and `notes/plan.md` for P3-S2 status.

Validated commands and results:

1. Full current NPC regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-debug test-difftest
   ```

   Result: passed.

2. Focused AM cpu-tests through NPC:

   ```sh
   for t in dummy add shift bit load-store movsx if-else switch unalign; do
     tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
     printf 'NAME = %s\nSRCS = /Users/venti/Workspace/ai-ysyx/am-kernels/tests/cpu-tests/tests/%s.c\nINC_PATH += /Users/venti/Workspace/ai-ysyx/am-kernels/tests/cpu-tests/include\ninclude /Users/venti/Workspace/ai-ysyx/abstract-machine/Makefile\n' "$t" "$t" > "$tmp"
     make -f "$tmp" ARCH=riscv32e-npc AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine CROSS_COMPILE=riscv64-elf- run
     status=$?
     rm -f "$tmp"
     if [ $status -ne 0 ]; then exit $status; fi
   done
   ```

   Result: passed.
   - `dummy`: `NPC_RESULT status=good reason=good_trap cycles=13 insts=13 pc=0x80000030 ... a0=0x00000000 trap=1`
   - `add`: `cycles=1109`, good trap.
   - `shift`: `cycles=438`, good trap.
   - `bit`: `cycles=309`, good trap; this was the first P3-S2 repro and now passes.
   - `load-store`: `cycles=484`, good trap.
   - `movsx`: `cycles=117`, good trap.
   - `if-else`: `cycles=352`, good trap.
   - `switch`: `cycles=255`, good trap.
   - `unalign`: `cycles=220`, good trap.

3. Broader exploratory non-M cpu-test sweep found many additional passing tests, but also known non-P3-S2 failures:

   - Passing examples included `add-longlong`, `bubble-sort`, `crc32`, `fact`, `fib`, `goldbach`, `leap-year`, `max`, `mersenne`, `min3`, `mov-c`, `pascal`, `prime`, `quick-sort`, `recursion`, `select-sort`, `sub-longlong`, `sum`, `to-lower-case`, and `wanshu`.
   - `hello-str` and `string` reach a BAD trap with `a0=1`; this is consistent with the old klib/string/printf runtime caveat and should be handled in a later runtime/klib session unless it blocks CSR/trap work.
   - `matrix-mul` and `narcissistic` hit the current `NPC_MAX_CYCLES=100000` limit during exploratory runs; do not treat this as a functional failure until re-run with a larger limit and/or DiffTest.

Known caveats:

- P3-S2 misalignment currently halts BAD with CommitEvent causes; precise architectural trap entry (`mepc`, `mcause`, `mtvec`) is still P3-S3 work.
- `ecall`, architectural `ebreak`, `mret`, `wfi`, `fence`, `fence.i`, and Zicsr are not implemented yet except for the current harness `ebreak` termination convention.
- NPC CommitEvent still does not carry memory access info; `--mem-trace` still prints immediate memory read/write lines.
- Early DiffTest compares CommitEvent fields; CSR state is not compared yet.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.
- Keep this through Phase 3 and Phase 4: Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C calls. Do not model side-effectful emulated memory/peripherals as combinational DPI-C reads/writes; make side effects explicit, preferably clocked or otherwise ordered by the harness/interface.
- M-extension tests remain out of scope because the target core is RV32E_Zicsr.

Next work:

Start `P3-S3: System instructions, CSR file, and precise trap entry`:

1. Add a small CSR module for `mvendorid`, `marchid`, `mstatus`, `mtvec`, `mepc`, and `mcause` only.
2. Decode and implement Zicsr operations with correct read/write suppression and read-only CSR checks.
3. Convert illegal instruction, misaligned instruction/load/store, `ecall`, and architectural `ebreak` from immediate BAD halt into precise trap entry (`mepc`, `mcause`, `pc = mtvec`), while preserving the harness-controlled AM `halt()` convention.
4. Implement `mret`, `wfi` as nop, `fence` as nop, and `fence.i` as a visible no-state hook.
5. Add directed CSR/trap tests before running broader cpu-tests with DiffTest.

Relevant files:

- `notes/plan.md`
- `notes/next.md`
- `notes/npc-datapath-and-isa-plan.md`
- `specs/core.md`
- `npc/Makefile`
- `npc/README.md`
- `npc/rtl/include/npc_defines.vh`
- `npc/rtl/core/Core.v`
- `npc/rtl/core/Idu.v`
- `npc/rtl/core/Lsu.v`
- `npc/rtl/core/Csr.v`
- `npc/csrc/memory.cpp`
- `npc/csrc/memory.h`
- `npc/csrc/main.cpp`
- `npc/csrc/difftest.cpp`
- `abstract-machine/scripts/platform/npc.mk`
