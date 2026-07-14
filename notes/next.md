# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 has started and is complete through `P2-S6: Early DiffTest hookup against NEMU REF`.
- NPC implementation style is **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store` and `activate`; leave them alone unless the user explicitly asks.

Submodules reported earlier by `git submodule status`:

- `am-kernels` at `76c80f8b5b4fdeeabe1b7caa167953cd64c16545` (`heads/master`)
- `specs/riscv-isa-manual` at `79b241cb6d2f07167366747ae49df94b88ad4d3b` (`riscv-isa-release-79b241c-2026-07-10`)
- `ysyxSoC` at `df38a4d93d1d71e621fe91b106d088bd33af984a` (`heads/ysyx6`)

NEMU/AM current configuration:

- Native NEMU build uses local ignored `nemu/.config` with key settings:
  - `CONFIG_ISA="riscv32"`
  - `CONFIG_TARGET_NATIVE_ELF=y`
  - `# CONFIG_TARGET_AM is not set`
  - `# CONFIG_DEVICE is not set`
  - `# CONFIG_TRACE is not set`
  - `CONFIG_IQUEUE=y`
  - `CONFIG_IQUEUE_SIZE=16`
  - `# CONFIG_MTRACE is not set`
  - `CONFIG_MBASE=0x80000000`
  - `CONFIG_MSIZE=0x2000000`
  - `CONFIG_PC_RESET_OFFSET=0`
- The REF shared-object check temporarily edits `nemu/.config` to `CONFIG_TARGET_SHARE=y`, runs `tools/kconfig/build/conf -s --syncconfig Kconfig`, builds `build/riscv32-nemu-interpreter-so`, then restores the native `.config` and rebuilds the native executable.
- `nemu/build/riscv32-nemu-interpreter-so` existed and passed the REF API smoke test this session.
- Devices remain disabled because native device build on this macOS environment failed earlier on missing `SDL2/SDL.h`.
- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- The installed `riscv64-elf-gcc` is configured `--without-headers`, so local freestanding AM headers were added earlier:
  - `abstract-machine/am/include/stdint.h`
  - `abstract-machine/am/include/stddef.h`
  - `abstract-machine/am/include/stdbool.h`

Important completed changes before Phase 2:

- P1-S2: minimal AM `dummy` path in NEMU and AM Makefile/run fixes.
- P1-S3: representative RV32I cpu-test instruction coverage in NEMU and `notes/nemu-rv32i-instruction-notes.md`.
- P1-S4: `--max-insts` / `NEMU_LIMIT` and stable `NEMU_RESULT status=...` reporting.
- P1-S5: compact instruction queue tracing (`CONFIG_IQUEUE`) and filtered memory tracing (`CONFIG_MTRACE`).
- P1-S6: NEMU REF shared-object APIs (`difftest_memcpy`, `difftest_regcpy`, `difftest_exec`) and `nemu/tools/ref-api-smoke.py`; `difftest_raise_intr()` still asserts.
- P1-S7: minimal M-mode CSR/trap state for AM `ecall`/`mret` plus serial MMIO fallback at `0xa00003f8` with devices off.
- P1-S8: Phase 1 smoke set re-run; decided to start NPC in Verilog.

Phase 2 completed work:

- Wrote `notes/npc-datapath-and-isa-plan.md`.
- Created initial `npc/` project skeleton with Verilog RTL modules, C++ Verilator harness, Makefile, README, and tiny test directories.
- P2-S2 `addi` datapath:
  - DPI-C instruction fetch through `pmem_read()`.
  - 16-register RV32E `RegFile` with hardwired `x0`.
  - `addi` decode/execute/writeback and `pc + 4` stepping.
  - `npc/tests/bin/addi.bin` checks x0 immutability and final `x1 = 5`; it intentionally ends on unsupported `0x00000000` and reports BAD trap after the x1 check passes.
- P2-S3 `jalr`/`ebreak`:
  - `jalr` writes `pc + 4`, redirects to `(rs1 + imm) & ~1`.
  - `ebreak` halts and reports GOOD/BAD from `a0 == 0` through DPI-C `npc_trap(status)`.
  - Unsupported/illegal instructions halt as BAD.
  - `npc/tests/bin/jalr-ebreak.bin` covers control-flow termination at reset PC `0x100`.
- P2-S4 data-memory slice:
  - `Memory::write32()` and DPI-C `pmem_write()` added beside `pmem_read()`.
  - IDU recognizes aligned-word `lw`/`sw`; LSU reads/writes DPI memory.
  - `npc/tests/bin/lw-sw.bin` validates aligned word store/load at reset PC `0x100` with final `x1 = 0x2a`.
- P2-S5 debug baseline:
  - Flattened RV32E debug register bus (`x0..x15`), `debug_inst`, and `debug_trap_status` exposed through RTL top.
  - `main.cpp` maintains an 8-entry `{cycle, pc, inst}` ring.
  - Failure runs print bounded `NPC_TRACE` lines and a 16-register `NPC_REGS` dump; passing runs stay concise.
  - Runtime flags: `--dump-trace`, `--dump-regs`, and `--mem-trace`.
  - `make -C npc test-debug` validates cycle-limit failure context and memory trace output.
- P2-S6 early DiffTest hookup:
  - Added `npc/csrc/difftest.h` and `npc/csrc/difftest.cpp`.
  - `main.cpp` accepts `--difftest-ref SO`, loads the NEMU REF shared object dynamically with `dlopen()`, initializes REF memory/register state, steps REF once per retired NPC instruction, and compares PC plus RV32E-visible `x0..x15`; REF `x16..x31` must remain zero.
  - Added `Memory::copy_to()` to copy the NPC memory image into REF memory.
  - Added minimal `auipc` decode/execute support so DiffTest programs can run at NEMU REF reset base `0x80000000` without hard-coded low addresses.
  - Added raw DiffTest binaries:
    - `npc/tests/bin/auipc-ebreak.bin`
    - `npc/tests/bin/difftest-jalr-ebreak.bin`
    - `npc/tests/bin/difftest-lw-sw.bin`
  - Added `make -C npc test-difftest`, using `REF_SO ?= ../nemu/build/riscv32-nemu-interpreter-so`.
  - Updated `npc/README.md` with current status and DiffTest command usage.

Validated commands and current results:

1. Full current NPC regression command:

   ```sh
   make -C npc smoke && make -C npc test-addi && make -C npc test-jalr-ebreak && make -C npc test-lw-sw && make -C npc test-debug && make -C npc test-difftest
   ```

   Result: all six checks passed this session.

2. NEMU REF API smoke:

   ```sh
   python3 nemu/tools/ref-api-smoke.py nemu/build/riscv32-nemu-interpreter-so --reset-vector 0x80000000
   ```

   Result: `REF_API_SMOKE status=pass pc=0x80000004 x0=0x00000000 t0=0x80000000 mem_addr=0x80000100`.

3. NPC deterministic smoke:

   ```sh
   make -C npc smoke
   ```

   Result: the no-image all-zero instruction at reset PC reports BAD and includes one `NPC_TRACE` line plus a register dump because it is a failure-oriented smoke case.

4. NPC `addi` datapath regression:

   ```sh
   make -C npc test-addi
   ```

   Result: `NPC_CHECK x1=0x00000005 expect=0x00000005 PASS`; final `NPC_RESULT status=bad ... trap=2` because the test intentionally ends on unsupported `0x00000000`.

5. NPC `jalr`/`ebreak` regression:

   ```sh
   make -C npc test-jalr-ebreak
   ```

   Result: `NPC_RESULT status=good cycles=5 pc=0x00000120 halted=1 limit=16 x1=0x00000102 a0=0x00000000 trap=1`.

6. NPC aligned `lw`/`sw` regression:

   ```sh
   make -C npc test-lw-sw
   ```

   Result: `NPC_RESULT status=good cycles=5 pc=0x00000110 halted=1 limit=16 x1=0x0000002a a0=0x00000000 trap=1`.

7. NPC debug regression:

   ```sh
   make -C npc test-debug
   ```

   Result: passed. It checks a short cycle-limit run with trace/register dump and `--mem-trace` on `lw-sw.bin`.

8. NPC early DiffTest regression:

   ```sh
   make -C npc test-difftest
   ```

   Result: passed. It checks:

   - `auipc; ebreak`: `NPC_RESULT status=good cycles=2 pc=0x80000004 ... x1=0x80000000 ... trap=1`.
   - `auipc; jalr; addi a0,0,0; ebreak`: `NPC_RESULT status=good cycles=4 pc=0x80000010 ... x1=0x80000000 ... trap=1`.
   - `auipc; addi; sw; lw; ebreak`: `NPC_RESULT status=good cycles=5 pc=0x80000010 ... x1=0x0000002a ... trap=1`.

Known caveats:

- NPC currently executes only `addi`, `auipc`, aligned `lw`, aligned `sw`, `jalr`, and `ebreak`; all other instructions halt as BAD unsupported/illegal instructions.
- Memory access remains an early aligned 32-bit happy path. Misalignment, access faults, byte/halfword loads/stores, and byte masks remain later work.
- Early DiffTest compares only PC plus RV32E-visible GPRs `x0..x15`; CSR state is not compared yet, and REF `x16..x31` are expected to remain zero for these tiny programs.
- DiffTest currently does not step REF for NPC `ebreak` itself because NPC halts on that instruction; this is acceptable for the current tiny trap-termination tests but should be revisited when trap/CSR retirement semantics become architectural.
- `debug_x1`, `debug_a0`, `debug_trap_status`, `debug_inst`, and `debug_regs_flat` are temporary harness-visible check signals; later DiffTest/register dump support should replace ad hoc debug outputs where appropriate.
- All current `npc/tests/bin/*.bin` files are raw binaries, not hex text parser inputs.
- Verilator build output is still somewhat verbose on clean builds, but warnings are kept clean enough for `-Wall`.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts. Current normal NEMU trap execution supports the minimal AM `ecall`/`mret` path, but the REF external interrupt API is not implemented.
- `CONFIG_IQUEUE=y` builds Capstone under `nemu/tools/capstone/repo/` if not already present, because the ring buffer stores disassembled instruction strings. This directory is ignored/generated tooling.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because its generated makefile path uses `/bin/echo -e`; use the temporary `printf` loop from earlier sessions unless changing `am-kernels/` is explicitly allowed.
- `hello-str` reaches serial output but still fails in `abstract-machine/klib/src/stdio.c:17` because klib `printf` is not implemented. Leave this for a later klib/runtime session unless needed immediately.
- M-extension tests remain out of scope because the target core is RV32E_Zicsr.
- `abstract-machine/scripts/riscv32-nemu.mk` still defaults `CROSS_COMPILE := riscv64-linux-gnu-`; continue passing `CROSS_COMPILE=riscv64-elf-` unless the toolchain/default is changed.
- Devices remain disabled; the minimal serial fallback is intentionally not a full device model.

Next work:

Start `P2-S7: Minimal AM riscv32e-npc run path`:

1. Inspect current AM target/platform support under `abstract-machine/scripts/` and `abstract-machine/am/src/` for how to add a `riscv32e-npc` target with minimal churn.
2. Add only the missing run-path pieces needed to build and run a tiny AM workload on NPC.
3. Make AM `halt()` for NPC use `ebreak` and pass result code through `a0` for the current harness convention.
4. Provide a one-command `make ... ARCH=riscv32e-npc run` path that invokes `npc/build/npc` with image, reset PC, and cycle limit.
5. Start with `dummy`; do not broaden to cpu-tests until Phase 3 instruction coverage exists.
6. Re-run the full current NPC regression command and any new AM/NPC command.

Relevant files:

- `notes/plan.md`
- `notes/next.md`
- `notes/lecture-note-summary.md`
- `notes/nemu-rv32i-instruction-notes.md`
- `notes/npc-datapath-and-isa-plan.md`
- `specs/core.md`
- `npc/Makefile`
- `npc/README.md`
- `npc/rtl/NPC.v`
- `npc/rtl/core/Core.v`
- `npc/rtl/core/Ifu.v`
- `npc/rtl/core/Idu.v`
- `npc/rtl/core/RegFile.v`
- `npc/rtl/core/Lsu.v`
- `npc/csrc/main.cpp`
- `npc/csrc/memory.cpp`
- `npc/csrc/memory.h`
- `npc/csrc/difftest.cpp`
- `npc/csrc/difftest.h`
- `npc/csrc/dpi.cpp`
- `npc/csrc/dpi.h`
- `npc/tests/bin/addi.bin`
- `npc/tests/bin/jalr-ebreak.bin`
- `npc/tests/bin/lw-sw.bin`
- `npc/tests/bin/auipc-ebreak.bin`
- `npc/tests/bin/difftest-jalr-ebreak.bin`
- `npc/tests/bin/difftest-lw-sw.bin`
- `nemu/.config` (generated/ignored local build config)
- `nemu/src/filelist.mk`
- `nemu/src/cpu/difftest/ref.c`
- `nemu/tools/ref-api-smoke.py`
- `nemu/src/isa/riscv32/inst.c`
- `abstract-machine/scripts/riscv32-nemu.mk`
- `abstract-machine/scripts/platform/nemu.mk`
