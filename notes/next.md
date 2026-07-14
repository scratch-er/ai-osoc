# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 has started.
- `P2-S1: NPC project skeleton and Verilator harness` is complete.
- `P2-S2: Minimal execution datapath (addi)` is complete.
- `P2-S3: Control flow and trap termination (jalr, ebreak)` is complete.
- `P2-S4: DPI-C data memory path and tiny load/store subset` is complete.
- `P2-S5: NPC debug infrastructure baseline` is complete.
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
- The REF shared-object check temporarily edits `nemu/.config` to `CONFIG_TARGET_SHARE=y`, runs `tools/kconfig/build/conf -s --syncconfig Kconfig`, builds `build/riscv32-nemu-interpreter-so`, then restores the native `.config` and rebuilds the native executable.
- Devices remain disabled because native device build on this macOS environment failed earlier on missing `SDL2/SDL.h`.
- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- The installed `riscv64-elf-gcc` is configured `--without-headers`, so local freestanding AM headers were added:
  - `abstract-machine/am/include/stdint.h`
  - `abstract-machine/am/include/stddef.h`
  - `abstract-machine/am/include/stdbool.h`

Important completed changes before Phase 2:

- P1-S2:
  - `nemu/src/monitor/monitor.c`: removed the intentional PA skeleton `assert(0)` from `welcome()`.
  - `nemu/src/isa/riscv32/inst.c`: added minimal AM `dummy` execution support (`addi`, `sw`, `jal`, `jalr`, J-type decode).
  - `abstract-machine/Makefile`: fixed library linkage expansion for AM/klib archives.
  - `abstract-machine/scripts/platform/nemu.mk`: run NEMU in batch mode and use `python3` for `insert-arg.py`.
- P1-S3:
  - `nemu/src/isa/riscv32/inst.c`: added common RV32I decode/execution coverage for the representative cpu-test slice: U/I/load/store/R/B instruction groups.
  - Added `notes/nemu-rv32i-instruction-notes.md`.
- P1-S4:
  - Added `--max-insts` / `NEMU_LIMIT` and stable `NEMU_RESULT status=...` reporting.
  - AM `riscv32-nemu` run path now passes `--max-insts=$(NEMU_MAX_INSTS)`.
- P1-S5:
  - Added compact instruction ring buffer (`CONFIG_IQUEUE`) and filtered memory tracing (`CONFIG_MTRACE`).
  - Failure paths dump bounded recent instructions; normal passing runs stay concise.
- P1-S6:
  - `nemu/src/cpu/difftest/ref.c`: implemented REF-side `difftest_memcpy`, `difftest_regcpy`, and `difftest_exec` for the current riscv32 CPU state; `difftest_raise_intr` remains an explicit `assert(0)` gap because trap/CSR behavior is not implemented yet.
  - `nemu/src/filelist.mk`: made the shared-object target omit `src/nemu-main.c`, monitor code, and the interactive engine entry so it can link as a DiffTest REF library without unresolved sdb symbols.
  - Added `nemu/tools/ref-api-smoke.py`, a host-side ctypes smoke test that checks exported symbols, REF initialization, register copy, memory round-trip, and a one-instruction execution step.
- P1-S7:
  - `nemu/src/isa/riscv32/include/isa-def.h` now carries the minimal M-mode CSR state used by AM traps: `mstatus`, `mtvec`, `mepc`, and `mcause`.
  - `nemu/src/isa/riscv32/inst.c` implements the Zicsr instruction forms used by AM trap code, plus M-mode `ecall` and `mret`.
  - `nemu/src/isa/riscv32/system/intr.c` saves `mepc`/`mcause` and dispatches to `mtvec`.
  - `nemu/src/memory/paddr.c` provides a minimal `0xa00003f8` serial MMIO fallback when `CONFIG_DEVICE` is off, enough for AM `putch()`/`hello` output without requiring SDL2-backed devices.
- P1-S8:
  - Re-ran the standard smoke set and confirmed Phase 1 remains green.
  - Decided to start NPC in Verilog.

Phase 2 completed work:

- Wrote the ISA/datapath design note:
  - `notes/npc-datapath-and-isa-plan.md`
- Created initial `npc/` project skeleton:
  - `npc/Makefile`
  - `npc/README.md`
  - `npc/.gitignore`
  - `npc/rtl/NPC.v`
  - `npc/rtl/include/npc_defines.vh`
  - `npc/rtl/core/Core.v`
  - `npc/rtl/core/Ifu.v`
  - `npc/rtl/core/Idu.v`
  - `npc/rtl/core/RegFile.v`
  - `npc/rtl/core/Exu.v`
  - `npc/rtl/core/Lsu.v`
  - `npc/rtl/core/Csr.v`
  - `npc/rtl/core/Wbu.v`
  - `npc/rtl/bus/MemIf.v`
  - `npc/csrc/main.cpp`
  - `npc/csrc/memory.h`
  - `npc/csrc/memory.cpp`
  - `npc/csrc/dpi.h`
  - `npc/csrc/dpi.cpp`
  - `npc/tests/hex/empty.hex`
- Implemented the first minimal NPC execution datapath for `addi`:
  - `Ifu.v` fetches 32-bit little-endian instructions through DPI-C `pmem_read()`.
  - `memory.cpp` owns the host memory image and exports `pmem_read()`.
  - `Idu.v` decodes RV32I/RV32E I-type fields and identifies `addi`.
  - `RegFile.v` provides 16 RV32E GPRs; writes to `x0` are ignored and reads from `x0` return zero.
  - `Core.v` connects IFU/IDU/RegFile/EXU/WBU for `addi`, advances `pc + 4` on legal `addi`, and halts on unsupported instructions.
  - `NPC.v` exposes `debug_x1` for the early harness checker.
  - `main.cpp` stops the simulation when `debug_halted` is asserted, supports `--expect-x1`, and emits `x1=...` in `NPC_RESULT`.
- Added a tiny raw-binary `addi` regression:
  - `npc/tests/bin/addi.bin`
  - program words: `addi x1,x0,7`; `addi x0,x0,9`; `addi x1,x1,-2`; `0x00000000` unsupported-instruction halt.
  - expected final `x1 = 5`, proving immediate add and x0 immutability for this small slice.
- Implemented the P2-S3 control-flow/trap slice:
  - `Idu.v` decodes `jalr` and `ebreak`.
  - `Core.v` writes `pc + 4` for `jalr`, calculates the target as `(rs1 + imm) & ~1`, and redirects the PC.
  - `Core.v` halts on `ebreak`, maps `a0 == 0` to GOOD and nonzero `a0` to BAD, and calls DPI-C `npc_trap(status)`.
  - Unsupported/illegal instructions now halt with BAD trap status rather than being treated as successful termination.
  - `RegFile.v` and `NPC.v` expose `debug_a0` and `debug_trap_status` for the harness.
  - `main.cpp` now derives process/result status from trap status and includes `a0=... trap=...` in `NPC_RESULT`.
  - `dpi.h`/`dpi.cpp` use C linkage for the DPI trap symbol.
- Added a tiny raw-binary `jalr`/`ebreak` regression:
  - `npc/tests/bin/jalr-ebreak.bin`
  - It runs at reset PC `0x100`, uses `addi` to form a `jalr` target, skips BAD-setting instructions, reaches `a0 = 0`, and terminates via `ebreak`.
- Implemented the P2-S4 DPI-C data-memory/load-store slice:
  - `memory.cpp`/`memory.h` now provide `Memory::write32()` and exported DPI-C `pmem_write()` beside `pmem_read()`.
  - `Idu.v` decodes S-type immediates and recognizes aligned-word `lw`/`sw` encodings.
  - `Lsu.v` calls `pmem_read()` only when `ren` is active and calls `pmem_write()` for stores.
  - `Core.v` routes `lw` writeback through LSU read data, routes `sw` writes through LSU, validates RV32E `rs2` for stores, and continues to advance `pc + 4` for memory ops.
  - Misalignment/access-fault behavior is still deliberately postponed; current P2-S4 implements only the tiny aligned happy path.
- Added a tiny raw-binary aligned `lw`/`sw` regression:
  - `npc/tests/bin/lw-sw.bin`
  - program words at reset PC `0x100`: `addi x2,x0,0x100`; `addi x3,x0,0x2a`; `sw x3,0x40(x2)`; `lw x1,0x40(x2)`; `ebreak`.
  - expected final `x1 = 0x2a`, `a0 = 0`, GOOD trap.
- Implemented the P2-S5 debug baseline:
  - `RegFile.v` exposes a flattened RV32E debug register bus (`x0..x15`, with `x0` forced to zero) through `Core.v` and `NPC.v`.
  - `Core.v` exposes the current fetched instruction as `debug_inst`.
  - `main.cpp` maintains an 8-entry recent `{cycle, pc, inst}` ring.
  - Failing runs automatically print bounded `NPC_TRACE` lines and a 16-register `NPC_REGS` dump after the structured `NPC_RESULT` line.
  - Passing runs remain concise by default.
  - Runtime flags were added:
    - `--dump-trace`: print the bounded trace even on passing runs.
    - `--dump-regs`: print the register dump even on passing runs.
    - `--mem-trace`: print `NPC_MEM r/w` lines from DPI memory accesses.
  - Added `make -C npc test-debug` to validate a cycle-limit failure dump and optional memory tracing.

Validated commands and current results:

1. Full current NPC regression command:

   ```sh
   make -C npc smoke && make -C npc test-addi && make -C npc test-jalr-ebreak && make -C npc test-lw-sw && make -C npc test-debug
   ```

   Result: all five checks passed in this session.

2. NPC deterministic smoke test:

   ```sh
   make -C npc smoke
   ```

   Result: the no-image all-zero instruction at reset PC reports BAD and now includes one `NPC_TRACE` line and one `NPC_REGS` dump because it is a failure-oriented smoke case.

3. NPC `addi` datapath regression:

   ```sh
   make -C npc test-addi
   ```

   Result: `NPC_CHECK x1=0x00000005 expect=0x00000005 PASS`; final `NPC_RESULT status=bad ... trap=2` because the test intentionally ends on unsupported `0x00000000`. Failure trace/register dump is expected for this current test shape.

4. NPC `jalr`/`ebreak` regression:

   ```sh
   make -C npc test-jalr-ebreak
   ```

   Result: `NPC_RESULT status=good cycles=5 pc=0x00000120 halted=1 limit=16 x1=0x00000102 a0=0x00000000 trap=1`.

5. NPC aligned `lw`/`sw` regression:

   ```sh
   make -C npc test-lw-sw
   ```

   Result: `NPC_RESULT status=good cycles=5 pc=0x00000110 halted=1 limit=16 x1=0x0000002a a0=0x00000000 trap=1`.

6. NPC debug infrastructure regression:

   ```sh
   make -C npc test-debug
   ```

   Result: passed. It checks:

   - a deliberately short `jalr-ebreak` run reports `NPC_RESULT status=limit ...`, prints recent PCs/instructions, and dumps registers;
   - `--mem-trace` on `lw-sw.bin` prints the expected store line `NPC_MEM w addr=0x00000140 data=0x0000002a` while the program still finishes GOOD.

Known caveats:

- NPC currently executes only `addi`, aligned `lw`, aligned `sw`, `jalr`, and `ebreak`; all other instructions halt as BAD unsupported/illegal instructions.
- P2-S4 memory access is an early aligned 32-bit happy path. Misalignment, access faults, byte/halfword loads/stores, and byte masks remain later work.
- `debug_x1`, `debug_a0`, `debug_trap_status`, `debug_inst`, and `debug_regs_flat` are temporary harness-visible check signals; later DiffTest/register dump support should replace ad hoc debug outputs where appropriate.
- `npc/tests/bin/addi.bin`, `npc/tests/bin/jalr-ebreak.bin`, and `npc/tests/bin/lw-sw.bin` are raw binaries, not hex text parser inputs.
- Verilator build output is still somewhat verbose on clean builds, but warnings are kept clean enough for `-Wall`.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts. Current normal NEMU trap execution supports the minimal AM `ecall`/`mret` path, but the REF external interrupt API is not implemented.
- The current DiffTest register blob is still `DIFFTEST_REG_SIZE`, i.e. 32 riscv32 GPRs plus PC. CSR state is not included in the DiffTest copy/check contract yet.
- `CONFIG_IQUEUE=y` builds Capstone under `nemu/tools/capstone/repo/` if not already present, because the ring buffer stores disassembled instruction strings. This directory is ignored/generated tooling.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because its generated makefile path uses `/bin/echo -e`; use the temporary `printf` loop from earlier sessions unless changing `am-kernels/` is explicitly allowed.
- `hello-str` reaches serial output but still fails in `abstract-machine/klib/src/stdio.c:17` because klib `printf` is not implemented. Leave this for a later klib/runtime session unless needed immediately.
- M-extension tests remain out of scope because the target core is RV32E_Zicsr.
- `abstract-machine/scripts/riscv32-nemu.mk` still defaults `CROSS_COMPILE := riscv64-linux-gnu-`; continue passing `CROSS_COMPILE=riscv64-elf-` unless the toolchain/default is changed.
- Devices remain disabled; the minimal serial fallback is intentionally not a full device model.

Next work:

Start `P2-S6: Early DiffTest hookup against NEMU REF`:

1. Ensure `nemu/build/riscv32-nemu-interpreter-so` is current; rebuild REF shared object if needed using the recorded Phase 1 flow.
2. Link the NPC simulator against the REF shared object or load it dynamically if that keeps normal builds simpler.
3. Add command-line switches to enable DiffTest and initialize REF memory/register state from the loaded NPC image.
4. Define the early comparison contract as PC plus RV32E-visible GPRs `x0..x15`; ignore or assert zero for `x16..x31` in REF during tiny RV32E tests.
5. Step REF once per retired NPC instruction and compare after each step for `addi`, `jalr`, `ebreak`, `lw`, and `sw` tiny programs.
6. Inject a temporary mismatch only during validation, verify DiffTest catches it with concise trace/register context, then remove the mismatch.
7. Re-run `make -C npc smoke`, `make -C npc test-addi`, `make -C npc test-jalr-ebreak`, `make -C npc test-lw-sw`, and `make -C npc test-debug`.

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
- `npc/csrc/dpi.cpp`
- `npc/csrc/dpi.h`
- `npc/tests/bin/addi.bin`
- `npc/tests/bin/jalr-ebreak.bin`
- `npc/tests/bin/lw-sw.bin`
- `nemu/.config` (generated/ignored local build config)
- `nemu/src/filelist.mk`
- `nemu/src/cpu/difftest/ref.c`
- `nemu/tools/ref-api-smoke.py`
- `nemu/src/isa/riscv32/inst.c`
- `abstract-machine/scripts/riscv32-nemu.mk`
- `abstract-machine/scripts/platform/nemu.mk`
