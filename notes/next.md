# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 has started.
- `P2-S1: NPC project skeleton and Verilator harness` is complete enough to hand off to `P2-S2`.
- NPC implementation style is now **Verilog**.
- Repository status before Phase 2 already had untracked `.DS_Store` and `activate`; leave them alone unless the user explicitly asks.
- A git commit has not been made yet because tool policy requires explicit user confirmation before git mutations.

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

Current session completed work:

- Wrote the approved ISA/datapath design note:
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
- Current RTL is intentionally only a P2-S1 skeleton:
  - `Core.v` resets `pc` to `io_reset_pc`, or the `RESET_PC` parameter when `io_reset_pc == 0`.
  - Default reset PC is `0x20000000`.
  - On each cycle after reset, `pc` increments by 4.
  - No real instruction fetch/decode/execute has been implemented yet.
- Harness features now present:
  - `--image FILE` loads a binary blob into host memory at the reset PC base.
  - `--reset-pc HEX` configures reset PC at runtime.
  - `--max-cycles N` limits execution.
  - `--wave` is supported when built with `TRACE=1`.
  - Stable result line: `NPC_RESULT status=... cycles=... pc=... halted=... limit=...`.

Validated commands and current results:

1. NPC deterministic smoke test:

   ```sh
   make -C npc smoke
   ```

   Result:

   ```text
   NPC_RESULT status=limit cycles=8 pc=0x20000020 halted=0 limit=8
   ```

2. NPC image-load and custom reset PC check:

   ```sh
   make -C npc run ARGS="--image tests/hex/empty.hex --reset-pc 0x20000010 --max-cycles 2" || true
   ```

   Result:

   ```text
   NPC_IMAGE path=tests/hex/empty.hex base=0x20000010 size=9
   NPC_RESULT status=limit cycles=2 pc=0x20000018 halted=0 limit=2
   ```

   The `|| true` is currently needed because the simulator returns nonzero on instruction/cycle limit. This is acceptable for ad hoc limit checks; `make -C npc smoke` wraps the expected limit result and exits successfully.

Known caveats:

- NPC does not execute instructions yet; P2-S2 starts the real datapath with `addi`.
- `npc/tests/hex/empty.hex` is just text content for loader plumbing, not an executed hex parser/program. The current loader treats any file as raw bytes.
- `npc/csrc/memory.cpp` allocates host memory and loads images but the RTL does not yet call into it for fetch.
- `npc/csrc/dpi.cpp` contains only a placeholder `npc_trap()` print helper.
- Verilator build output is still somewhat verbose on clean builds, but warnings from third-party headers are suppressed enough to keep logs manageable.
- `make -C npc run` propagates simulator nonzero exit on `status=limit`; keep using `smoke` for the deterministic passing check until real program termination exists.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts. Current normal NEMU trap execution supports the minimal AM `ecall`/`mret` path, but the REF external interrupt API is not implemented.
- The current DiffTest register blob is still `DIFFTEST_REG_SIZE`, i.e. 32 riscv32 GPRs plus PC. CSR state is not included in the DiffTest copy/check contract yet.
- `CONFIG_IQUEUE=y` builds Capstone under `nemu/tools/capstone/repo/` if not already present, because the ring buffer stores disassembled instruction strings. This directory is ignored/generated tooling.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because its generated makefile path uses `/bin/echo -e`; use the temporary `printf` loop above unless changing `am-kernels/` is explicitly allowed.
- `hello-str` reaches serial output but still fails in `abstract-machine/klib/src/stdio.c:17` because klib `printf` is not implemented. Leave this for a later klib/runtime session unless needed immediately.
- M-extension tests remain out of scope because the target core is RV32E_Zicsr.
- `abstract-machine/scripts/riscv32-nemu.mk` still defaults `CROSS_COMPILE := riscv64-linux-gnu-`; continue passing `CROSS_COMPILE=riscv64-elf-` unless the toolchain/default is changed.
- Devices remain disabled; the minimal serial fallback is intentionally not a full device model.

Next work:

Start `P2-S2: Minimal execution datapath (addi)`:

1. Connect `Ifu.v` to a DPI-C instruction fetch path backed by `Memory`.
2. Implement enough decode for `addi` and illegal-instruction fallback.
3. Connect `RegFile.v`, `Idu.v`, `Exu.v`, and writeback through `Core.v`.
4. Keep x0 immutable and test it.
5. Add a tiny raw-binary or generated test program for:
   - `addi x1, x0, imm`
   - `addi x0, x0, imm` proving x0 remains zero
6. Add a simulation-side check or concise trace/result mechanism sufficient for the `addi` test.
7. Re-run `make -C npc smoke` and the new `addi` test.

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
- `npc/rtl/core/Idu.v`
- `npc/rtl/core/RegFile.v`
- `npc/csrc/main.cpp`
- `npc/csrc/memory.cpp`
- `npc/csrc/memory.h`
- `nemu/.config` (generated/ignored local build config)
- `nemu/src/filelist.mk`
- `nemu/src/cpu/difftest/ref.c`
- `nemu/tools/ref-api-smoke.py`
- `nemu/src/isa/riscv32/inst.c`
- `abstract-machine/scripts/riscv32-nemu.mk`
- `abstract-machine/scripts/platform/nemu.mk`
