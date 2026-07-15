# Next Session

Current state:

- Phase 1 (`NEMU and AM Foundation`) is closed through Session 8.
- Phase 2 is complete.
- Phase 3 (`RV32E_Zicsr Functional Core`) is complete through `P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening`.
- Phase 4 is complete and closed through `P4-S9: Workload regression and Phase 4 closeout`.
- Phase 5 has started:
  - `P5-S1: NEMU memory-region groundwork` was completed and committed as `a007e71 Refactor NEMU physical memory regions`.
  - `P5-S2: Device/MMIO cleanup and replay contract` is complete.
  - `P5-S3: NPC internal bus request/response boundary` is complete.
  - `P5-S4: AXI4 master shell and local simulation AXI slave` is complete and waiting for user review before commit.
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
- NEMU REF shared object is `nemu/build/riscv32-nemu-interpreter-so` and exports the CommitEvent/MMIO replay APIs used by NPC DiffTest.

## P5-S4 status: AXI4 master shell and local simulation AXI slave

P5-S4 implementation is complete and waiting for user review before commit.

What changed:

- Added `npc/rtl/bus/AxiMaster.v`:
  - Single-beat 32-bit AXI4 read/write master shell.
  - Drives AW/W/B and AR/R valid/ready handshakes.
  - Uses fixed ID 0, `len=0`, `size=3'b010`, `burst=INCR`.
  - Exposes a simple request/response interface (`req_valid/write/addr/wdata/wmask`, `req_ready/rdata`) to the core.
- Added `npc/rtl/bus/AxiArbiter.v`:
  - Arbitrates the IFU and LSU request/response interfaces onto one AXI master request stream.
  - Gives LSU priority over IFU so data accesses complete before the next instruction fetch when both are pending.
- Added `npc/rtl/bus/LocalAxiSlave.v`:
  - Local simulation AXI slave model used by Verilator builds.
  - Bridges AXI single-beat reads/writes to the existing DPI memory/device functions.
  - Preserves ordered UART output through the existing retired-store commit path; the slave only records the MMIO write.
- Updated `npc/rtl/NPC.v`:
  - Top module now exposes the AXI master ports listed in `specs/core.md`.
  - Reserved AXI slave outputs are hardwired inactive/zero and reserved inputs are ignored.
  - `LOCAL_AXI` parameter defaults to `0` for external integration semantics; the NPC Verilator Makefile passes `-GLOCAL_AXI=1` to enable the local simulation slave.
- Updated `npc/rtl/core/Core.v`:
  - IFU fetches and LSU data accesses now go through `AxiArbiter` and `AxiMaster`.
  - Added an instruction fetch hold register (`inst_q`/`inst_valid`) so nonzero AXI fetch latency does not repeatedly decode/execute stale or invalid instructions.
  - Retirement, writeback, CSR/trap updates, and PC updates now wait for a valid fetched instruction and memory completion.
- Updated `npc/Makefile`:
  - Verilator build passes `-GLOCAL_AXI=1`.
  - Directed checks were updated for full IFU+LSU AXI latency.
  - `test-axi-local` checks local AXI RAM read/write behavior using `lw-sw.bin --mem-trace`; `test-mem-latency` is kept as an alias for compatibility with the previous P5-S3 target name.

Validated in P5-S4:

1. Rebuilt NPC after a clean:

   ```sh
   make -C npc clean && make -C npc
   ```

   Result: passed. Verilator still emits existing generated C++ `-Wbitwise-instead-of-logical` warnings from decode-table expressions, but build succeeds.

2. NPC directed regression through full IFU+LSU AXI local path:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-axi-local test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed by Makefile expectations. Some negative/debug subtests intentionally print `status=bad`, `status=limit`, or `NPC_CHECK ... FAIL` before their expected grep checks.

3. Full 35-test `cpu-tests` sweep on NPC with NEMU event DiffTest:

   ```sh
   ROOT=/Users/venti/Workspace/ai-ysyx
   TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
   REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so"
   for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
     tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
     printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
     make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=8000000 NPC_DIFFTEST_REF="$REF" run >/tmp/p5-s4-cputest-$t.log 2>&1
     status=$?
     rm -f "$tmp"
     if [ $status -ne 0 ]; then echo "FAILED $t"; tail -80 /tmp/p5-s4-cputest-$t.log; exit $status; fi
     echo "PASS $t"
   done
   ```

   Result: all 35 tests passed.

4. NPC `hello` with NEMU DiffTest:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=800000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: exit code 0. Output contained `Hello, AbstractMachine!`, `NEMU_RESULT status=good`, and `NPC_RESULT status=good reason=good_trap cycles=2038 insts=465 pc=0x800000c4 ...`.

5. RT-Thread AM on NPC with NEMU DiffTest:

   ```sh
   make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=12000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: exit code 0. Output contained the RT-Thread banner, `Hello RISC-V!`, scripted shell commands through `msh />halt`, `NEMU_RESULT status=good`, and `NPC_RESULT status=good reason=good_trap cycles=2343298 insts=511954 ...`.

Known caveats after P5-S4:

- AXI support is currently single-beat 32-bit aligned transactions. Burst reads for icache refill remain later cache/AXI work.
- The local AXI slave currently returns OKAY and does not yet model `SLVERR`/`DECERR`; access-fault handling remains P5-S5 work.
- IFU and LSU now both use the AXI-facing path in simulation, but there is still no instruction cache, so every instruction fetch costs an AXI read transaction.
- The reserved AXI slave interface is hardwired inactive/zero as required by `specs/core.md`.
- CLINT implements the `specs/clint.rst` address window but still uses the temporary retired-instruction timer source. Physical cycle-based CLINT remains Phase 6 work.
- `am-tests mainargs=d` still panics after the required timer/devscan section due to optional IOE registers; this remains outside scope.
- `am-tests mainargs=t` is intentionally bounded by cycle limit.
- NEMU native device support is still UART/timer plus the temporary NPC-compatible UART/CLINT aliases.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.

Next work: after user review and commit, proceed to `P5-S5: DiffTest with bus/MMIO access faults`.

Relevant files for next session:

- `notes/plan.md`
- `notes/next.md`
- `npc/rtl/NPC.v`
- `npc/rtl/core/Core.v`
- `npc/rtl/core/Ifu.v`
- `npc/rtl/core/Lsu.v`
- `npc/rtl/bus/AxiMaster.v`
- `npc/rtl/bus/AxiArbiter.v`
- `npc/rtl/bus/LocalAxiSlave.v`
- `npc/rtl/bus/MemIf.v`
- `npc/Makefile`
- `npc/csrc/main.cpp`
- `npc/csrc/memory.cpp`
- `npc/csrc/difftest.cpp`
- `nemu/include/debug/mmio_replay.h`
