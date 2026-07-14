# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 has started and is complete through the inserted `P2-S6.5: CommitEvent-based control/debug interface`.
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
  - `CONFIG_MBASE=0x80000000`
  - `CONFIG_MSIZE=0x2000000`
  - `CONFIG_PC_RESET_OFFSET=0`
- The REF shared-object build temporarily copies the share config into `nemu/.config`, runs `tools/kconfig/build/conf -s --syncconfig Kconfig`, builds `build/riscv32-nemu-interpreter-so`, then restores the native `.config` and rebuilds the native executable.
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
- P1-S5 originally added compact instruction/memory tracing; the stale NEMU tracing code was later removed after P2-S6.5 replaced it with CommitEvent history.
- P1-S6: initial NEMU REF shared-object APIs (`difftest_memcpy`, `difftest_regcpy`, `difftest_exec`) and `nemu/tools/ref-api-smoke.py`; `difftest_raise_intr()` still asserts.
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
  - Failure-oriented bounded trace/register dumps and `--mem-trace` existed before P2-S6.5.
- P2-S6 early DiffTest hookup:
  - Added `npc/csrc/difftest.h` and `npc/csrc/difftest.cpp`.
  - Added raw DiffTest binaries:
    - `npc/tests/bin/auipc-ebreak.bin`
    - `npc/tests/bin/difftest-jalr-ebreak.bin`
    - `npc/tests/bin/difftest-lw-sw.bin`
  - Added `make -C npc test-difftest`, using `REF_SO ?= ../nemu/build/riscv32-nemu-interpreter-so`.

Inserted P2-S6.5 completed work:

- Added shared C-compatible `CommitEvent` format and helpers in `nemu/include/debug/commit_event.h`.
- NEMU native now records a fixed 64-entry `CommitEvent` ring in `nemu/src/utils/state.c`.
- NEMU monitor was refactored into a scriptable command dispatcher while preserving interactive mode and old aliases:
  - new CLI: `-e/--exec 'cmd; cmd'`, `-f/--script FILE`
  - commands: `run`, `step`/`si`, `print pc`, `print reg [i]`, `print mem <addr> <size>`, `dump state`, `last [n]`, `exit`/`quit`/`q`
- NEMU REF shared object now exports event APIs:
  - `difftest_step_event(CommitEvent *ev)`
  - `difftest_get_last_events(CommitEvent *buf, size_t max_n)`
- NPC RTL now exposes commit/debug signals from `NPC.v`/`Core.v`:
  - commit valid, PC, instruction, next PC, writeback enable/register/value, exception flag/cause.
- NPC C++ harness now has a scriptable shell:
  - `-e 'load ...; reset; run ...; dump state; last ...; exit'`
  - `-f script-file`
  - commands: `load`, `load_bin`, `reset`, `step`, `run`, `run to`, `run until reg`, `print`, `dump state`, `last`, `log`, `trace`, `exit`.
- NPC uses a configurable `CommitEvent` ring (`--ring-size`, default 64). Failure dumps print `NPC_LAST_BEGIN/END` bounded event history plus `NPC_REGS`.
- NPC DiffTest now prefers the REF event API and compares CommitEvent sequence fields (`pc`, `inst`, `next_pc`, exception/cause, writeback register/value). Full register checks remain fallback/diagnostic context.
- `npc/Makefile` tests were updated for new result lines with `reason=...` and `insts=...`.
- Removed stale NEMU debug/tracing code after confirming it was superseded by CommitEvent history:
  - removed Kconfig `TRACE`/`ITRACE`/`IQUEUE`/`MTRACE` options;
  - removed old disassembly-backed instruction queue and memory trace hooks;
  - removed unused PA-style expression/watchpoint source files from `nemu/src/monitor/sdb/`;
  - removed the stale `--log` file option and default `nemu-log.txt` run argument.
- Updated documentation:
  - `nemu/README.md`
  - `npc/README.md`
  - `notes/plan.md`

Validated commands and current results:

1. Full current NPC regression command:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-debug test-difftest
   ```

   Result: passed.

2. NEMU native script-mode smoke:

   ```sh
   cd nemu && ./build/riscv32-nemu-interpreter -e 'step 1; last 1; print pc; exit'
   ```

   Result: passed; prints one `NEMU_LAST` CommitEvent and `pc = 0x80000004`.

3. NEMU REF API smoke:

   ```sh
   cd nemu && python3 tools/ref-api-smoke.py build/riscv32-nemu-interpreter-so --reset-vector 0x80000000
   ```

   Result: `REF_API_SMOKE status=pass pc=0x80000004 x0=0x00000000 t0=0x80000000 mem_addr=0x80000100`.

4. NPC script-shell example:

   ```sh
   npc/build/npc --reset-pc 0x100 --max-cycles 16 -e 'load npc/tests/bin/jalr-ebreak.bin 0x100; reset; run 2; dump state; last 2; exit'
   ```

   Result: stops after 2 retired instructions, prints `NPC_STATE pc=0x00000118 cycles=2 retired=2 halted=0 trap=0` and two `NPC_LAST` events.

Known caveats:

- NPC currently executes only `addi`, `auipc`, aligned `lw`, aligned `sw`, `jalr`, and `ebreak`; all other instructions halt as BAD unsupported/illegal instructions.
- Memory access remains an early aligned 32-bit happy path. Misalignment, access faults, byte/halfword loads/stores, and byte masks remain later work.
- NPC CommitEvent currently does not carry memory access info; `--mem-trace` still prints immediate memory read/write lines.
- NEMU CommitEvent writeback inference is opcode-based and adequate for the current tiny RV32I subset; it should be refined when CSR/trap behavior becomes central in Phase 3.
- NPC `log 1` and `trace on/off` stream CommitEvent lines, but filter parsing (`branches`, `loads`, `pc range`, etc.) remains future work.
- DiffTest event comparison now includes `ebreak` events; NEMU `next_pc` after `ebreak` is `pc + 4`, so NPC commit next-PC was aligned to that.
- Early DiffTest compares CommitEvent fields; CSR state is not compared yet.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.
- `debug_x1`, `debug_a0`, `debug_trap_status`, `debug_inst`, and `debug_regs_flat` remain temporary harness-visible check signals, now supplemented by explicit commit signals.
- All current `npc/tests/bin/*.bin` files are raw binaries, not hex text parser inputs.
- Verilator build output is still verbose on clean builds.
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
4. Provide a one-command `make ... ARCH=riscv32e-npc run` path that invokes `npc/build/npc` with image, reset PC, and cycle/instruction limit.
5. Start with `dummy`; do not broaden to cpu-tests until Phase 3 instruction coverage exists.
6. Re-run the full current NPC regression command and any new AM/NPC command.

Relevant files:

- `notes/plan.md`
- `notes/next.md`
- `notes/lecture-note-summary.md`
- `notes/nemu-rv32i-instruction-notes.md`
- `notes/npc-datapath-and-isa-plan.md`
- `specs/core.md`
- `nemu/README.md`
- `nemu/include/debug/commit_event.h`
- `nemu/include/utils.h`
- `nemu/src/cpu/cpu-exec.c`
- `nemu/src/cpu/difftest/ref.c`
- `nemu/src/monitor/monitor.c`
- `nemu/src/monitor/sdb/sdb.c`
- `nemu/src/monitor/sdb/sdb.h`
- `nemu/src/utils/state.c`
- `nemu/tools/ref-api-smoke.py`
- `npc/Makefile`
- `npc/README.md`
- `npc/rtl/NPC.v`
- `npc/rtl/core/Core.v`
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
- `abstract-machine/scripts/riscv32-nemu.mk`
- `abstract-machine/scripts/platform/nemu.mk`
