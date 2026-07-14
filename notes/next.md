# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 is complete through `P3-S3: System instructions, CSR file, and precise trap entry`.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store` and `activate`; leave them alone unless the user explicitly asks.
- Top-level `build/` contains generated AM/NPC images from smoke runs; do not assume it should be committed unless intentionally adding an artifact.

Toolchain/config reminders:

- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- Devices remain disabled because native NEMU device build on this macOS environment failed earlier on missing `SDL2/SDL.h`.
- NEMU REF shared object remains `nemu/build/riscv32-nemu-interpreter-so` and exports the CommitEvent APIs used by NPC DiffTest.
- The REF shared object was rebuilt this session with `make -C nemu SHARE=1` after expanding the RISC-V DiffTest register-copy contract to include implemented CSR state.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because it uses `/bin/echo -e`; use the temporary Makefile/`printf` workaround below unless changing `am-kernels/` is explicitly allowed.

P3-S3 completed work:

- Added a real `npc/rtl/core/Csr.v` for the required M-mode CSRs only:
  - `mvendorid` (`0xf11`) and `marchid` (`0xf12`) read as 0 and are read-only.
  - `mstatus` reads as `0x00001800` (MPP=M) and writes preserve that value.
  - `mtvec`, `mepc`, and `mcause` are implemented; `mtvec`/`mepc` writes mask low two bits.
- Extended `npc/rtl/core/Idu.v` and `npc/rtl/include/npc_defines.vh` for:
  - Zicsr: `csrrw`, `csrrs`, `csrrc`, `csrrwi`, `csrrsi`, `csrrci`.
  - System instructions: `ecall`, architectural `ebreak`, `mret`, `wfi`, `fence`, and `fence.i`.
  - Illegal CSR addresses and illegal writes to read-only CSRs.
- Updated `npc/rtl/core/Core.v`/`npc/rtl/NPC.v` for precise trap entry:
  - illegal instruction -> cause 2,
  - instruction target misalignment -> cause 0,
  - load address misalignment -> cause 4,
  - store address misalignment -> cause 6,
  - `ecall` -> cause 11,
  - architectural `ebreak` -> cause 3 when `mtvec != 0`,
  - trap entry writes `mepc = faulting pc`, `mcause = cause`, and sets `pc = mtvec`.
  - `mret` returns to `mepc`.
  - Harness `ebreak` GOOD/BAD termination is preserved when `mtvec == 0`, so existing tiny tests and AM `halt()` still work.
- Updated NPC harness output and DiffTest:
  - `NPC_CSR mstatus=... mtvec=... mepc=... mcause=...` is printed after `NPC_RESULT`.
  - NPC DiffTest initializes/checks implemented CSR state for the fallback reg-copy path.
  - With the NEMU REF event API, DiffTest still compares CommitEvents and avoids false PC mismatches after REF reaches its `ebreak` halt convention.
- Updated NEMU REF support:
  - `nemu/include/difftest-def.h` now copies RISC-V GPRs + PC + `mstatus`/`mtvec`/`mepc`/`mcause`.
  - `nemu/src/isa/riscv32/init.c` initializes `mstatus` to `0x00001800`.
  - `nemu/src/isa/riscv32/inst.c` reads `mvendorid`/`marchid`, masks `mtvec`/`mepc`, and keeps `mstatus` MPP=M.
- Added directed raw binary tests:
  - `npc/tests/bin/csr-basic.bin`
  - `npc/tests/bin/ecall-trap.bin`
  - `npc/tests/bin/illegal-mret.bin`
  - `npc/tests/bin/sys-nop.bin`
  - `npc/tests/bin/csr-readonly-illegal.bin`
- Added `make -C npc test-csr-trap` and included it in the documented regression command.
- Updated `npc/README.md` and `notes/plan.md` for P3-S3 status.

Validated commands and results:

1. Rebuilt the NEMU REF shared object after CSR/DiffTest changes:

   ```sh
   make -C nemu SHARE=1
   ```

   Result: passed; output path remains `nemu/build/riscv32-nemu-interpreter-so`.

2. Full current NPC regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed.

3. Focused AM cpu-tests through NPC:

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
   - `dummy`: `cycles=13`, good trap.
   - `add`: `cycles=1109`, good trap.
   - `shift`: `cycles=438`, good trap.
   - `bit`: `cycles=309`, good trap.
   - `load-store`: `cycles=484`, good trap.
   - `movsx`: `cycles=117`, good trap.
   - `if-else`: `cycles=352`, good trap.
   - `switch`: `cycles=255`, good trap.
   - `unalign`: `cycles=220`, good trap.

Known caveats:

- The current precise trap path is single-cycle and vector-only (`pc = mtvec`); interrupts are still unsupported by design.
- `fence.i` is a visible no-state hook for now; actual icache clearing waits for Phase 7.
- NPC CommitEvent still does not carry memory or CSR access summaries; `--mem-trace` still prints immediate memory read/write lines.
- Event-API DiffTest compares CommitEvent fields. Full CSR state is checked on the fallback reg-copy path and initialized for REF, but CSR details are not in CommitEvent yet.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.
- Keep this through Phase 3 and Phase 4: Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C calls. Do not model side-effectful emulated memory/peripherals as combinational DPI-C reads/writes; make side effects explicit, preferably clocked or otherwise ordered by the harness/interface.
- M-extension tests remain out of scope because the target core is RV32E_Zicsr.
- Previously observed broader cpu-test caveats still stand unless re-run:
  - `hello-str` and `string` reach a BAD trap with `a0=1`, likely runtime/klib/string/printf related.
  - `matrix-mul` and `narcissistic` hit `NPC_MAX_CYCLES=100000` during exploratory runs and need a larger limit before judging functionality.

Next work:

Start `P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening`:

1. Run the non-M-extension cpu-tests progressively through `ARCH=riscv32e-npc` using the temporary Makefile/`printf` workaround.
2. Fix only bugs exposed by that sweep; do not add unrelated devices or optional ISA features.
3. Consider extending CommitEvent with CSR/memory summaries only if DiffTest needs them for new failures.
4. Keep M-extension tests out of scope.
5. Record pass/fail status and any runtime/klib blockers separately before moving to Phase 4.

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
- `npc/rtl/core/Csr.v`
- `npc/csrc/main.cpp`
- `npc/csrc/difftest.cpp`
- `npc/csrc/difftest.h`
- `nemu/include/difftest-def.h`
- `nemu/src/isa/riscv32/init.c`
- `nemu/src/isa/riscv32/inst.c`
- `abstract-machine/scripts/platform/npc.mk`
