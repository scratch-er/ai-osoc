# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete through `P2-S7: Minimal AM riscv32e-npc run path`.
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
- P2-S6.5 CommitEvent-based control/debug interface:
  - Added shared C-compatible `CommitEvent` format and helpers in `nemu/include/debug/commit_event.h`.
  - NEMU native records a fixed 64-entry `CommitEvent` ring in `nemu/src/utils/state.c`.
  - NEMU monitor has scriptable `-e/--exec` and `-f/--script` command dispatch while preserving interactive mode and old aliases.
  - NEMU REF shared object exports `difftest_step_event()` and `difftest_get_last_events()`.
  - NPC RTL exposes commit/debug signals from `NPC.v`/`Core.v`.
  - NPC C++ harness has a scriptable shell with `load`, `reset`, `step`, `run`, `run to`, `run until reg`, `print`, `dump state`, `last`, breakpoint commands, `log`, `trace`, and `exit`.
  - NPC uses a configurable `CommitEvent` ring (`--ring-size`, default 64). Failure dumps print `NPC_LAST_BEGIN/END` bounded event history plus `NPC_REGS`.
  - NEMU and NPC both support small fixed-size PC breakpoint tables.
  - NPC DiffTest prefers the REF event API and compares CommitEvent sequence fields.
  - Removed stale NEMU debug/tracing code superseded by CommitEvent history.
  - Updated `nemu/README.md`, `npc/README.md`, and `notes/plan.md`.
- P2-S7 minimal AM `riscv32e-npc` run path:
  - Completed `abstract-machine/scripts/platform/npc.mk` `run` target.
  - Added `PYTHON ?= python3` for `insert-arg` on this macOS environment.
  - `run` now builds `npc/build/npc` through `NPC_HOME ?= $(abspath $(AM_HOME)/../npc)` and invokes it with `--image $(IMAGE).bin --reset-pc 0x80000000 --max-cycles 100000` by default.
  - Implemented `abstract-machine/am/src/riscv/npc/trm.c::halt()` as `mv a0, code; ebreak`, with a fallback infinite loop.
  - Added minimal `jal` support to NPC (`Idu.v` J immediate/decode and `Core.v` next-PC/link writeback) because AM startup uses `jal` to call `_trm_init()`.
  - Updated `npc/README.md` and `notes/plan.md`.

Validated commands and current results:

1. Full current NPC regression command:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-debug test-difftest
   ```

   Result: passed.

2. AM `dummy` through NPC:

   ```sh
   tmp=$(mktemp /tmp/am-dummy.XXXXXX.mk) && \
   printf 'NAME = dummy\nSRCS = /Users/venti/Workspace/ai-ysyx/am-kernels/tests/cpu-tests/tests/dummy.c\ninclude /Users/venti/Workspace/ai-ysyx/abstract-machine/Makefile\n' > "$tmp" && \
   make -f "$tmp" ARCH=riscv32e-npc AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine CROSS_COMPILE=riscv64-elf- run; \
   status=$?; rm -f "$tmp"; exit $status
   ```

   Result: passed with `NPC_RESULT status=good reason=good_trap cycles=13 insts=13 pc=0x80000030 ... a0=0x00000000 trap=1`.

3. NEMU native script-mode smoke from P2-S6.5 remains:

   ```sh
   cd nemu && ./build/riscv32-nemu-interpreter -e 'step 1; last 1; print pc; exit'
   ```

   Last known result: passed; prints one `NEMU_LAST` CommitEvent and `pc = 0x80000004`.

4. NEMU REF API smoke from P2-S6.5 remains:

   ```sh
   cd nemu && python3 tools/ref-api-smoke.py build/riscv32-nemu-interpreter-so --reset-vector 0x80000000
   ```

   Last known result: `REF_API_SMOKE status=pass pc=0x80000004 x0=0x00000000 t0=0x80000000 mem_addr=0x80000100`.

Known caveats:

- NPC currently executes only `addi`, `auipc`, `jal`, `jalr`, aligned `lw`, aligned `sw`, and `ebreak`; all other instructions halt as BAD unsupported/illegal instructions.
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
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS because its generated makefile path uses `/bin/echo -e`; use a temporary Makefile/`printf` workaround unless changing `am-kernels/` is explicitly allowed.
- `hello-str` reaches serial output on NEMU but still fails in `abstract-machine/klib/src/stdio.c:17` because klib `printf` is not implemented. Leave this for a later klib/runtime session unless needed immediately.
- M-extension tests remain out of scope because the target core is RV32E_Zicsr.
- `abstract-machine/scripts/riscv32-nemu.mk` still defaults `CROSS_COMPILE := riscv64-linux-gnu-`; continue passing `CROSS_COMPILE=riscv64-elf-` unless the toolchain/default is changed.
- Devices remain disabled; the minimal serial fallback is intentionally not a full device model.

Next work:

Start `P2-S8: Phase 2 closeout and Phase 3 handoff`:

1. Re-run all Phase 2 checks, including NPC regression and AM `dummy` through `ARCH=riscv32e-npc`.
2. Decide the first Phase 3 RV32E instruction group from the AM dummy binary and likely cpu-test startup needs; likely start with direct calls/returns and integer immediates/loads/stores beyond the tiny subset.
3. Update `notes/next.md` with exact closeout commands and first Phase 3 task.
4. Do not broaden to all cpu-tests until Phase 3 instruction coverage is intentionally underway.

Relevant files:

- `notes/plan.md`
- `notes/next.md`
- `notes/lecture-note-summary.md`
- `notes/nemu-rv32i-instruction-notes.md`
- `notes/npc-datapath-and-isa-plan.md`
- `specs/core.md`
- `specs/abstract-machine/README.md`
- `specs/abstract-machine/specifications.md`
- `specs/lecture-notes/02_C阶段讲义/02_C2.md`
- `specs/lecture-notes/05_D阶段讲义/04_D4.md`
- `nemu/README.md`
- `nemu/include/debug/commit_event.h`
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
- `npc/rtl/core/Idu.v`
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
- `abstract-machine/scripts/riscv32e-npc.mk`
- `abstract-machine/scripts/platform/npc.mk`
- `abstract-machine/am/src/riscv/npc/trm.c`
