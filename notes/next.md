# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 is complete through `P3-S1: Decode/control refactor and first cpu-test beyond dummy`.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store` and `activate`; leave them alone unless the user explicitly asks.
- Top-level `build/` contains generated AM/NPC images from smoke runs; do not assume it should be committed unless intentionally adding an artifact.

Toolchain/config reminders:

- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- Devices remain disabled because native NEMU device build on this macOS environment failed earlier on missing `SDL2/SDL.h`.
- NEMU REF shared object remains `nemu/build/riscv32-nemu-interpreter-so` and exports the CommitEvent APIs used by NPC DiffTest.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because it uses `/bin/echo -e`; use the temporary Makefile/`printf` workaround below unless changing `am-kernels/` is explicitly allowed.

P3-S1 completed work:

- Refactored NPC decode/control:
  - `npc/rtl/core/Idu.v` now emits compact control signals (`alu_op`, `imm_sel`, `wb_sel`, `branch_op`, `mem_ren`, `mem_wen`, `sys_cmd`, `reads_rs1`, `reads_rs2`, `writes_rd`) plus `I/S/B/U/J` immediates and CSR address/uimm placeholders.
  - `npc/rtl/include/npc_defines.vh` now contains shared ALU, immediate, writeback, branch, and system command constants.
  - `npc/rtl/core/Core.v` now drives PC selection, RV32E register legality checks, writeback, LSU control, CommitEvent metadata, and branch decisions from the compact controls.
  - `npc/rtl/core/Exu.v` now implements ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND/COPY_B.
- Instruction coverage added in this session:
  - `lui`
  - remaining I-type ALU ops: `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`
  - R-type ALU/compare/shift ops: `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and`
  - B-type branches: `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` (added because compiled `add`/`shift` cpu-tests need them). Branch target alignment exceptions are not implemented yet.
- Added directed raw binary tests:
  - `npc/tests/bin/alu.bin`
  - `npc/tests/bin/difftest-alu.bin`
  - `npc/tests/bin/rv32e-illegal.bin`
- Added Makefile targets:
  - `test-alu`
  - `test-rv32e-illegal`
  - extended `test-difftest` with the new ALU directed DiffTest.
- Updated `npc/README.md` and `notes/plan.md` for P3-S1 status.

Validated commands and results:

1. Full current NPC regression:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-rv32e-illegal test-debug test-difftest
   ```

   Result: passed.

2. AM `dummy`, `add`, and `shift` through NPC:

   ```sh
   for t in dummy add shift; do
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
   - `add`: `NPC_RESULT status=good reason=good_trap cycles=1109 insts=1109 pc=0x80000110 ... a0=0x00000000 trap=1`
   - `shift`: `NPC_RESULT status=good reason=good_trap cycles=438 insts=438 pc=0x8000014c ... a0=0x00000000 trap=1`

3. Tried `bit` through the same temporary Makefile workaround.

   Result: expected failure for next session. It stops at unsupported `sh`:

   ```text
   NPC_RESULT status=bad reason=illegal_inst cycles=15 insts=15 pc=0x800000b8 ...
   NPC_LAST R=15 C=14 PC=800000b8 I=00f11023 RD=0 RV=00000000 NPC=800000b8 EXC=1 CAUSE=2
   ```

Known caveats:

- Memory access remains an early aligned 32-bit path. `lb`, `lh`, `lbu`, `lhu`, `sb`, `sh`, byte strobes, misalignment exceptions, and access-fault signaling remain P3-S2 work.
- Branch target alignment checks/exceptions are not implemented yet; P3-S2 should add them with the memory exception work.
- `bit` currently fails because it uses `sh`; this is the best first P3-S2 repro.
- Keep this through Phase 3 and Phase 4: Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C calls. Do not model side-effectful emulated memory/peripherals as combinational DPI-C reads/writes; make side effects explicit, preferably clocked or otherwise ordered by the harness/interface.
- NPC CommitEvent currently does not carry memory access info; `--mem-trace` still prints immediate memory read/write lines.
- Early DiffTest compares CommitEvent fields; CSR state is not compared yet.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.
- `hello-str` reaches serial output on NEMU but still fails in `abstract-machine/klib/src/stdio.c:17` because klib `printf` is not implemented. Leave this for a later klib/runtime session unless needed immediately.
- M-extension tests remain out of scope because the target core is RV32E_Zicsr.

Next work:

Start `P3-S2: Branches and byte/halfword memory operations`:

1. Use the current `bit` failure as the first repro; implement `sh`/`sb` plus byte-enable plumbing in the DPI memory path.
2. Extend LSU/load formatting for `lb`, `lh`, `lbu`, `lhu`, and `lw`, with sign/zero extension.
3. Add alignment checks for branch targets and load/store addresses, reporting BAD illegal/exception-style status for now until P3-S3 precise traps are implemented.
4. Add directed byte/halfword memory tests and extend regression targets.
5. Re-run `dummy`, `add`, `shift`, and then `bit`; try `load-store`/`movsx` after directed tests pass.

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
- `npc/rtl/core/Exu.v`
- `npc/rtl/core/Lsu.v`
- `npc/csrc/memory.cpp`
- `npc/csrc/memory.h`
- `npc/csrc/dpi.cpp`
- `npc/csrc/main.cpp`
- `npc/csrc/difftest.cpp`
- `abstract-machine/scripts/platform/npc.mk`
