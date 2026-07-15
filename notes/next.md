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
  - `P5-S4: AXI4 master shell and local simulation AXI slave` is complete.
  - `P5-S5: DiffTest with bus/MMIO access faults` is complete and waiting for user review before commit.
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

## P5-S5 status: DiffTest with bus/MMIO access faults

P5-S5 implementation is complete and waiting for user review before commit. This work is currently on top of the still-uncommitted P5-S4 changes; do not commit until the user reviews and explicitly asks for the commit.

What changed in P5-S5:

- `npc/rtl/bus/AxiMaster.v` now converts AXI `RRESP`/`BRESP` errors into a simple `req_error` bit.
- `npc/rtl/bus/AxiArbiter.v` now routes that error bit back to the active IFU or LSU request.
- `npc/rtl/core/Core.v` now:
  - latches IFU fetch errors with the fetched instruction word;
  - raises instruction access fault (`mcause=1`) for IFU bus errors;
  - raises load access fault (`mcause=5`) and store/AMO access fault (`mcause=7`) for LSU bus errors;
  - suppresses writeback/memory side effects for access-faulting instructions;
  - still treats access-fault exceptions as normal precise exceptions when `mtvec` is set.
- `npc/rtl/bus/LocalAxiSlave.v` now returns `SLVERR` (`2'b10`) for local simulation accesses outside RAM/UART/CLINT instead of silently returning OKAY.
- `npc/csrc/memory.{h,cpp}` now expose `pmem_access_ok()` to the local AXI slave and keep UART/CLINT as valid local MMIO regions.
- `npc/csrc/main.cpp` no longer stops immediately on a recoverable exception when the core has not halted; this lets access-fault trap handlers run to `ebreak`.
- NEMU REF now has access-fault-aware commit events:
  - `Decode` carries `exception` and `exception_cause`.
  - `vaddr_access_ok()` checks RAM plus the NPC-compatible UART/CLINT aliases.
  - RISC-V instruction fetch/load/store decode raises precise causes 1/5/7 instead of aborting on unbacked addresses.
  - `CommitEvent` suppresses writeback and records `EXC=1 CAUSE={1,5,7}` for these faults.
- Added directed binaries:
  - `npc/tests/bin/inst-access-fault.bin`
  - `npc/tests/bin/load-access-fault.bin`
  - `npc/tests/bin/store-access-fault.bin`
- Added `make -C npc test-access-fault`, which runs the three new access-fault tests under NEMU event DiffTest and checks `CAUSE=1/5/7` plus good-trap completion.

Validated in P5-S5:

1. Rebuilt NEMU native and REF shared object:

   ```sh
   make -C nemu
   make -C nemu SHARE=1
   ```

   Result: both passed. The shared object was rebuilt at `nemu/build/riscv32-nemu-interpreter-so`.

2. Rebuilt NPC through the directed target:

   ```sh
   make -C npc test-access-fault
   ```

   Result: passed. The three new tests show `EXC=1 CAUSE=1`, `EXC=1 CAUSE=5`, and `EXC=1 CAUSE=7` in `NPC_LAST`, and all complete with `NPC_RESULT status=good reason=good_trap` under DiffTest.

3. NPC directed regression through local AXI path:

   ```sh
   make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-axi-local test-access-fault test-rv32e-illegal test-csr-trap test-debug test-difftest
   ```

   Result: passed by Makefile expectations. Some negative/debug subtests intentionally print `status=bad`, `status=limit`, or `NPC_CHECK ... FAIL` before their expected grep checks.

4. Full 35-test `cpu-tests` sweep on NPC with NEMU event DiffTest:

   ```sh
   ROOT=/Users/venti/Workspace/ai-ysyx
   TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
   REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so"
   for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
     tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
     printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
     make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=8000000 NPC_DIFFTEST_REF="$REF" run >/tmp/p5-s5-cputest-$t.log 2>&1
     status=$?
     rm -f "$tmp"
     if [ $status -ne 0 ]; then echo "FAILED $t"; tail -80 /tmp/p5-s5-cputest-$t.log; exit $status; fi
     echo "PASS $t"
   done
   ```

   Result: all 35 tests passed.

5. NPC `hello` with NEMU DiffTest:

   ```sh
   make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=800000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: exit code 0. Output contained `Hello, AbstractMachine!`, `NEMU_RESULT status=good`, and `NPC_RESULT status=good reason=good_trap cycles=2038 insts=465 pc=0x800000c4 ...`.

6. RT-Thread AM on NPC with NEMU DiffTest:

   ```sh
   make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
     AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine \
     CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=12000000 \
     NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
   ```

   Result: exit code 0. Output contained the RT-Thread banner, `Hello RISC-V!`, scripted shell commands through `msh />halt`, `NEMU_RESULT status=good`, and `NPC_RESULT status=good reason=good_trap cycles=2343298 insts=511954 ...`.

Known caveats after P5-S5:

- AXI support is still single-beat 32-bit aligned transactions. Burst reads for icache refill remain later cache/AXI work.
- Local AXI `SLVERR` is modeled for invalid local simulation regions; there is still no richer external AXI error source or `DECERR` distinction.
- IFU and LSU both use the AXI-facing path in simulation, but there is still no instruction cache, so every instruction fetch costs an AXI read transaction.
- The reserved AXI slave interface remains hardwired inactive/zero as required by `specs/core.md`.
- CLINT implements the `specs/clint.rst` address window but still uses the temporary retired-instruction timer source. Physical cycle-based CLINT remains Phase 6 work.
- `am-tests mainargs=d` still panics after the required timer/devscan section due to optional IOE registers; this remains outside scope.
- `am-tests mainargs=t` is intentionally bounded by cycle limit.
- NEMU native device support is still UART/timer plus the temporary NPC-compatible UART/CLINT aliases.
- `difftest_raise_intr()` in the NEMU REF shared object still asserts.

Next work: after user review and commit, proceed to `P5-S6: Full Phase 5 regression and closeout`.

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
- `nemu/include/cpu/decode.h`
- `nemu/include/memory/vaddr.h`
- `nemu/src/cpu/cpu-exec.c`
- `nemu/src/isa/riscv32/inst.c`
- `nemu/src/memory/vaddr.c`
- `nemu/include/debug/mmio_replay.h`
