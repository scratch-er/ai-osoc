# Project Plan

This plan is based on `notes/lecture-note-summary.md`, selected full lecture notes, and `specs/core.md`. The goal is not to mechanically complete every lecture exercise, but to build and optimize a maintainable RV32E_Zicsr processor core and the minimum emulator/runtime infrastructure needed to validate it.

## Scope and Decisions

### What to do

- Build a usable RV32E_Zicsr single-core processor core (`npc/`) targeting the core specification in `specs/core.md`.
- Maintain NEMU as the reference emulator and DiffTest reference, with enough RV32 support, devices, traps, and batch-friendly interfaces for automated experiments.
- Support essential workloads and validation targets:
  - `cpu-tests`
  - `hello`
  - `coremark`
  - `rt-thread-am`
- Support the required machine features:
  - M-mode only
  - RV32E integer instruction subset plus Zicsr needed by the spec
  - `ecall`, `ebreak`, `mret`, `wfi` (`wfi` as nop)
  - required CSRs: `mvendorid`, `marchid`, `mepc`, `mtvec`, `mcause`, `mstatus`
  - illegal CSR access as illegal-instruction exception
  - no virtual memory, no PMP/PMA, no interrupts
  - CLINT timer registers `mtime`/`mtimeh`, no interrupt behavior
  - AXI4 master interface, reserved slave interface hardwired inactive
  - direct-mapped 8-instruction flip-flop instruction cache, 16-byte line, burst refill, `fence.i` clears icache
  - performance counters sufficient to calculate icache AMAT and guide optimization
- Use the lecture notes as engineering guidance for phases: NEMU/AM foundation, NPC RTL, infrastructure, bus/SoC integration, cache, performance, and optional pipeline work.
- Keep notes under `notes/` updated across sessions, especially `notes/next.md` at session end.

### What not to do

- Do not spend time on PA0/Linux/Vim/Git beginner exercises unless they unblock the project.
- Do not write PA lab reports or solve educational reflection questions unless they directly improve the core design.
- Do not implement optional applications or peripherals only for demonstration value, such as PS/2, VGA, audio, PAL/FCEUX graphics, or game ports, unless later required for validation.
- Do not implement Nanos-lite, Navy apps, virtual memory, user mode, paging, full multitasking, or Linux-style OS support for this spec.
- Do not implement full RISC-V privileged architecture, S/U modes, PMP/PMA, interrupts, `mtimecmp` interrupt behavior, or all CSRs.
- Do not optimize blindly; collect counters and compare against baselines first.

### What to do differently from the lecture notes

- Replace fragile human-oriented monitor interaction with AI-friendly automated commands that build, run, stop on events, emit structured logs, and support trace filtering.
- Prefer reproducible one-command experiments over manual debugger sessions. Keep sdb-like functions useful, but make batch mode the default for tests.
- Treat NEMU primarily as a reference model and experiment harness, not as the final deliverable.
- Implement only spec-required CSR/exception behavior, not every CSR or privilege detail from the PA/C-stage notes.
- Use `specs/core.md` as the final authority for target ISA, reset address, CLINT behavior, cache shape, and top-level ports, even when lecture notes use older `minirv`, RV32IM, or ysyxSoC-specific defaults.
- Use UART and CLINT/timer because they are essential; postpone or skip display/input/audio devices.
- Use quantitative PPA/performance records for each major architectural step.

## Phase 0: Repository Baseline and Planning

Goal: establish the project plan, inventory current code, and identify missing project directories or stale assumptions.

Tasks:

1. Read `notes/lecture-note-summary.md`, selected lecture notes, and `specs/core.md`.
2. Create this plan in `notes/plan.md`.
3. Create/update `notes/next.md` with the current state and next session entry point.
4. Inspect whether `npc/` already exists; if absent, plan its creation and build style after checking available tools.
5. Record baseline repository status before code work.

Exit criteria:

- `notes/plan.md` exists with phase-level plan and scope decisions.
- `notes/next.md` points to the first implementation task.

## Phase 1: NEMU and AM Foundation

Goal: make the software reference stack capable of compiling, running, and checking basic RV32 workloads in automated mode. NEMU starts from the lecture-note skeleton state; NPC does not exist yet, so this phase should stop at a stable emulator/reference stack and avoid NPC-specific implementation except for recording future requirements.

Relevant lecture guidance:

- PA1 simple debugger and expression/watchpoint infrastructure.
- PA2 instruction execution, AM runtime, tracing, IOE, DiffTest.
- PA3 trap handling for `ecall`/CTE concepts.
- NEMU ISA API reference.

Session division principles:

- Each session should leave a buildable and runnable state, or clearly record the exact blocker in `notes/next.md`.
- A session should pass only compact information across the boundary: commands, current pass/fail status, changed files, and the next concrete entry point. Avoid leaving half-designed instruction semantics or large debug traces only in context.
- Keep NEMU-centered work separate from later NPC work. Phase 1 may prepare DiffTest REF APIs for NPC, but should not depend on an `npc/` directory.
- Prefer finishing one validation slice per session over touching many incomplete subsystems.

Sessions:

1. **P1-S1: Baseline NEMU bring-up and command inventory**
   - Inspect current `nemu/`, `abstract-machine/`, and toolchain state.
   - Configure/build NEMU for riscv32 from the initialized skeleton.
   - Run the default built-in image or smallest available test to confirm the current failure point.
   - Record exact build/run commands, current config, and the first missing implementation item.
   - Exit when NEMU can be built and invoked reproducibly, even if guest execution still fails at a known missing feature.

2. **P1-S2: Minimal execution path for AM `dummy`**
   - Implement only the instruction and trap pieces needed to run the simplest AM `dummy`/TRM workload.
   - Keep decoding and execution changes small and tested incrementally.
   - Ensure `halt()`/`nemu_trap` style termination produces a clear pass/fail result.
   - Record implemented instructions and any deliberate omissions.
   - Exit when `dummy` can run non-interactively to a deterministic result.

3. **P1-S3: CPU-test instruction coverage slice**
   - Use `am-kernels/tests/cpu-tests` as the driver for adding common RV32 integer instructions.
   - Add instructions in small groups based on failing tests, not by blindly implementing the whole ISA.
   - Keep RV32E constraints in mind for later NPC, but allow NEMU to remain a RV32 reference if that is how the framework is structured.
   - Record the tested subset and remaining failing tests.
   - Exit when a representative base set of cpu-tests passes and failures are narrow enough for the next session.

4. **P1-S4: Batch mode and concise result reporting**
   - Make the NEMU run path suitable for AI-driven automation: load image, run without manual monitor commands, stop on trap/error/limit, and print concise structured status.
   - Preserve the interactive monitor if already present, but make batch execution the default path used by AM runs.
   - Add or document a cycle/instruction limit mechanism to avoid infinite hangs during regressions.
   - Exit when `dummy` and selected cpu-tests can be run by one command each with machine-readable pass/fail output.

5. **P1-S5: Essential tracing for failures**
   - Add or verify itrace plus a small instruction ring buffer for the failing window.
   - Add mtrace behind a filter or config switch for load/store debugging.
   - Add ftrace only if ELF symbol plumbing is already nearby; otherwise record it as optional and do not block the phase.
   - Ensure traces stay off or compact by default so normal regression output is not too verbose.
   - Exit when a failing test can produce enough bounded trace context to debug the next failure without manual stepping.

6. **P1-S6: DiffTest REF shared object preparation**
   - Build or repair the NEMU shared-object reference target.
   - Verify the required REF APIs: memory copy, register copy, execution step, and architecture state access needed by later NPC DiffTest.
   - Include implemented CSR state only to the extent needed by Phase 1/early NPC comparison; postpone full spec-required CSR behavior to later phases if not needed yet.
   - Add a small host-side sanity check if the framework already supports one; otherwise document the build command and exported API status.
   - Exit when the REF library builds reproducibly and its API gaps are explicitly listed.

7. **P1-S7: AM workload integration and `hello` smoke test**
   - Ensure AM workloads build for `riscv32-nemu` with the batch run path.
   - Run `dummy`, selected cpu-tests, and `hello` through AM commands.
   - Implement/verify the NEMU trap path needed by AM workloads before `hello`, including M-mode `ecall` dispatch to `mtvec`, `mepc`, and `mcause` if the workload/runtime uses it.
   - Fix only NEMU/AM issues required for serial output and basic TRM/IOE behavior; defer optional devices.
   - Record the exact workload commands and observed output.
   - Exit when `hello` reaches expected serial output or a narrow, documented device/runtime blocker remains.

8. **P1-S8: Phase closeout and handoff to NPC creation**
   - Re-run the standard Phase 1 smoke set: `dummy`, selected cpu-tests, `hello`, and REF shared-object build.
   - Update `notes/next.md` with the stable commands, pass/fail table, known caveats, and the first Phase 2 task.
   - Keep the handoff compact: do not paste long traces; reference log files or reproduction commands instead.
   - Exit when NEMU can serve as the automated software reference stack for starting `npc/` from scratch.

Phase 1 exit criteria:

- NEMU can run selected tests non-interactively and report pass/fail.
- NEMU shared-object REF is buildable for NPC DiffTest.
- `dummy`, representative `cpu-tests`, and `hello` have current recorded commands and status.
- `notes/next.md` contains a compact handoff for creating the initial NPC project.

## Phase 2: Initial NPC RTL and Simulation Harness

Goal: create a Verilog-based, maintainable single-cycle NPC skeleton and Verilator harness that can execute tiny programs to `ebreak`, then hand off to Phase 3 for full RV32E_Zicsr functionality.

Relevant lecture guidance:

- D4 modular RTL minirv processor:
  - divide the design into IFU, IDU, EXU, LSU, WBU-style modules or similarly clear boundaries;
  - start from `addi`, then `jalr`, then `ebreak` via DPI-C;
  - use C++/DPI-C memory instead of an RTL memory array for early simulation;
  - add program image loading, AM `halt()` through `ebreak`, and HIT GOOD/BAD reporting.
- C2 RV32E single-cycle NPC infrastructure:
  - build NPC-side debugging infrastructure before adding many instructions;
  - add register/memory inspection hooks, concise trace support, and DiffTest early;
  - use NEMU as REF because RV32E programs can run on the existing RV32 NEMU reference.
- `specs/core.md`:
  - target ISA is RV32E_Zicsr;
  - reset address is configurable, default `0x20000000`;
  - final top-level interface must match the AXI-oriented spec, but Phase 2 may use a simpler DPI-C memory boundary while preserving interfaces that can later become bus/AXI requests.

Implementation style decision:

- Use **Verilog** for NPC. Chisel remains possible later, but Verilog is the default for Phase 2 because it is simpler to inspect, has broader AI training coverage, and avoids generator-layer debugging during initial bring-up.

Sessions:

1. **P2-S1: NPC project skeleton and Verilator harness**
   - Create `npc/` with Verilog RTL, C++ simulation, Makefile/scripts, and a small tests directory.
   - Add a top module with clock/reset, configurable reset PC parameter, and minimal simulation-visible state.
   - Add a Verilator harness with:
     - image loading at a configurable base address;
     - cycle/instruction limit;
     - optional waveform switch;
     - stable machine-readable result lines, e.g. `NPC_RESULT status=...`.
   - Add a tiny hand-written binary or hex test mechanism before depending on AM.
   - Exit when `make` can build the simulator and a reset/empty-run smoke test behaves deterministically.

2. **P2-S2: Minimal execution datapath (`addi`)**
   - Implement the first simple single-cycle datapath: PC, RV32E register file with 16 GPRs, instruction fetch, immediate decode, ALU add, writeback, and `pc + 4`.
   - Use DPI-C/C++ memory reads for instruction fetch, following D4's early-memory approach.
   - Add a small `addi` test that checks x0 immutability and a nonzero register result through a simulation-side check or trace.
   - Keep module boundaries explicit enough to evolve into IFU/IDU/EXU/WBU.
   - Exit when the `addi` test passes without manual waveform inspection.

3. **P2-S3: Control flow and trap termination (`jalr`, `ebreak`)**
   - Implement `jalr` and PC redirection.
   - Implement `ebreak` detection and DPI-C trap reporting to the C++ harness.
   - Report HIT GOOD/BAD style status using a simple convention, such as checking the value in `a0`/`x10` when `ebreak` retires.
   - Add a small hand-built program that uses `addi`, `jalr`, and `ebreak` and terminates automatically.
   - Exit when the simulator can run until program-controlled `ebreak` and emit `NPC_RESULT status=good`.

4. **P2-S4: DPI-C data memory path and tiny load/store subset**
   - Replace any remaining top-level ad hoc memory wiring with DPI-C `pmem_read()`/`pmem_write()` for both instruction fetch and data access.
   - Implement enough load/store behavior to validate the memory path, starting with word-aligned `lw`/`sw` and byte-mask plumbing if needed.
   - Keep the DPI memory functions 32-bit aligned internally, matching D4's advice so later bus work does not require a full rewrite.
   - Add a tiny memory test that writes, reads, and terminates via `ebreak`.
   - Exit when a hand-written memory program passes with concise output.

5. **P2-S5: NPC debug infrastructure baseline**
   - Add minimal non-interactive debug hooks before broad ISA work:
     - register dump on failure;
     - bounded recent-PC/instruction trace;
     - memory access trace switch or compile/runtime flag;
     - optional single-step harness mode if cheap.
   - Avoid a full human-oriented sdb unless it directly helps automation.
   - Keep normal passing output concise.
   - Exit when an injected wrong result or illegal/hanging test produces enough bounded context to debug without opening a waveform first.

6. **P2-S6: Early DiffTest hookup against NEMU REF**
   - Link the NPC simulator with `nemu/build/riscv32-nemu-interpreter-so`.
   - Reuse the Phase 1 REF APIs: `difftest_memcpy`, `difftest_regcpy`, and `difftest_exec`.
   - Define the initial comparison contract as PC plus the architectural RV32E-visible GPR subset; ignore x16-x31 or require them to remain zero/unused for RV32E tests.
   - Add command-line switches to enable/disable DiffTest and to initialize REF memory/register state from the NPC run.
   - Inject a temporary `addi` bug only during validation, then remove it, to confirm DiffTest reports mismatches.
   - Exit when the tiny `addi`/`jalr`/`ebreak` programs pass with DiffTest enabled and a deliberate mismatch is caught.

7. **P2-S6.5: CommitEvent-based control/debug interface**
   - Add a shared C-compatible `CommitEvent` format for retired-instruction history and DiffTest comparison.
   - Refactor NEMU's monitor into a scriptable dispatcher with `-e`/`-f`, while preserving interactive commands and old aliases.
   - Expose NEMU REF event-step APIs so NPC DiffTest can compare CommitEvent sequences rather than only full architectural state.
   - Add an NPC command shell with `load`, `reset`, `step`, `run`, `run to`, `run until reg`, `print`, `dump state`, `last`, small PC breakpoint commands, `log`, and `trace` basics.
   - Keep passing output concise and dump bounded recent events/registers on failure.
   - Exit when NEMU script mode, NPC shell runs, and event-based DiffTest tiny tests pass.

8. **P2-S7: Minimal AM `riscv32e-npc` run path** — completed
   - Added the missing one-command NPC run path in `abstract-machine/scripts/platform/npc.mk`.
   - Implemented NPC AM `halt()` with `ebreak`, passing the result code through `a0` for the current harness convention.
   - Added `jal` to the tiny NPC subset because AM startup uses it before reaching `_trm_init()`/`halt()`.
   - Validated AM `dummy` through `ARCH=riscv32e-npc`; broader cpu-tests remain Phase 3 work because the RTL intentionally supports only a small instruction subset.

9. **P2-S8: Phase 2 closeout and Phase 3 handoff**
   - Re-run all Phase 2 checks: harness smoke, `addi`, control-flow/trap, memory test, DiffTest tiny tests, and AM `dummy` if available.
   - Update `notes/next.md` with exact commands, pass/fail status, known limitations, and the first Phase 3 instruction group to implement.
   - Keep the handoff focused: no broad RV32E implementation in this phase unless it is necessary to make the Phase 2 harness trustworthy.
   - Exit when the NPC skeleton is stable enough for Phase 3 RV32E_Zicsr expansion.

Phase 2 exit criteria:

- `npc/` exists and builds with Verilator from one command.
- The simulator can load an image, enforce a limit, optionally dump waves, and emit machine-readable `NPC_RESULT` lines.
- A minimal single-cycle Verilog datapath executes tiny programs through `addi`, `jalr`, `ebreak`, and a small aligned memory-access subset.
- DPI-C memory and trap hooks are in place.
- Basic failure-oriented traces/register dumps exist and stay concise by default.
- Early DiffTest against the NEMU REF shared object works for the implemented tiny subset.
- AM `riscv32e-npc` has an initial run path or a precisely documented blocker for Phase 3.

## Phase 3: RV32E_Zicsr Functional Core

Goal: implement the full functional ISA subset required by `specs/core.md` before performance work, while refactoring the Phase 2 single-cycle skeleton just enough that later AXI, icache, and optional pipeline work do not require another rewrite.

Relevant lecture guidance:

- C2 RV32E implementation.
- C5 CSR and exception handling.
- RISC-V manual via lecture references.
- B1 bus/AXI and B5 pipeline notes as forward-compatibility constraints, not as Phase 3 implementation scope.

Current skeleton constraints to address early:

- `Core.v` currently wires one-bit-per-instruction decode (`is_addi`, `is_lw`, etc.) directly into PC, LSU, and writeback decisions. Phase 3 should replace this with compact IDU control signals (`alu_op`, `branch_op`, `mem_size`, `wb_sel`, `csr_cmd`, `sys_cmd`, `illegal`) before broadening instruction coverage.
- `Exu.v` is only an adder and `Wbu.v` only forwards ALU/load data. Add explicit ALU/compare/writeback selection now, but keep it single-cycle and simple.
- `Lsu.v` and the C++ memory path only support aligned 32-bit `lw`/`sw` and no byte strobes or access-fault signal. Add byte/halfword load-store formatting, alignment checks, and a DPI memory return status/strobe interface; this same shape should later map directly to AXI `WSTRB`/response handling.
- `Ifu.v` is a combinational DPI read. Add explicit instruction alignment/access-fault signals and keep a `fence_i`/flush hook, but defer icache storage and burst refill to Phase 7.
- Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C calls. Phase 3/4 DPI memory and peripheral models must not rely on side effects from combinational DPI-C reads/writes; model side effects through explicit ordered/clocked operations or a harness protocol.
- `NPC.v` top ports are still simulation/debug oriented and do not match the final AXI spec. Do not switch the top-level to AXI in Phase 3, but introduce internal request/response-style IFU/LSU boundaries so Phase 5 can replace DPI memory with AXI without changing decode/execute.
- CommitEvent currently lacks memory and CSR details and NEMU writeback inference is opcode-based. Extend retire metadata only as needed for reliable DiffTest of new instructions and CSR/trap behavior.

Sessions:

1. **P3-S1: Decode/control refactor and first cpu-test beyond dummy** — completed
   - Refactored `Idu.v` to emit compact control signals and all immediate formats (`I/S/B/U/J`) plus CSR address/uimm placeholders instead of one `is_*` wire per instruction.
   - Kept existing `addi`, `auipc`, `jal`, `jalr`, `lw`, `sw`, and `ebreak` behavior passing.
   - Added `lui`, the remaining I-type ALU ops, R-type ALU/compare/shift ops, and the B-type branch control needed by the first compiled cpu-test slice.
   - Preserved RV32E illegal checks for referenced x16-x31 with a directed illegal-register test.
   - Exit status: full NPC regression passes, `test-difftest` covers the new ALU directed test, and AM `dummy`, `add`, and `shift` pass through `ARCH=riscv32e-npc`.

2. **P3-S2: Branches and byte/halfword memory operations** — completed
   - Extended `Idu.v`, `Core.v`, `Lsu.v`, and the C++ memory backend for `lb`, `lh`, `lbu`, `lhu`, `sb`, `sh`, and masked byte/halfword stores while preserving `lw`/`sw`.
   - Added branch target, load-address, and store-address alignment checks that report exception causes in `CommitEvent` and halt BAD for now, pending P3-S3 precise trap entry.
   - Added directed binaries and `test-mem-size` for byte/halfword load-store formatting plus branch/load/store misalignment causes.
   - Exit status: full NPC regression including `test-mem-size` passes; AM `dummy`, `add`, `shift`, `bit`, `load-store`, `movsx`, `if-else`, `switch`, and `unalign` pass through `ARCH=riscv32e-npc`.

3. **P3-S3: System instructions, CSR file, and precise trap entry** — completed
   - Added `Csr.v` for `mvendorid`, `marchid`, `mstatus`, `mtvec`, `mepc`, and `mcause` only.
   - Implemented Zicsr operations with read/write suppression rules and illegal writes to read-only CSRs.
   - Converted `ecall`, architectural `ebreak`, illegal instruction, and misaligned instruction/load/store into precise trap entry when `mtvec` is nonzero, while preserving harness-controlled `ebreak` test termination when `mtvec == 0`.
   - Implemented `mret`, `wfi` as nop, `fence` as nop, and `fence.i` as a visible no-state hook.
   - Exit status: directed `test-csr-trap` passes, NEMU REF shared-object DiffTest is rebuilt with implemented CSR state in the register copy contract, and the full NPC regression plus the focused AM cpu-tests subset pass.

4. **P3-S4: Progressive RV32E cpu-tests regression and DiffTest hardening** — completed
   - Ran the full cpu-tests source set through `ARCH=riscv32e-npc` with `NPC_MAX_CYCLES=2000000`.
   - Confirmed multiply/division workloads pass when built for RV32E because AM/libgcc supplies software helper routines; no RTL M-extension was added.
   - Implemented the missing AM klib string/memory routines and minimal `printf`/`sprintf`/`snprintf` formatting needed by `hello-str` and `string`.
   - Added optional `NPC_DIFFTEST_REF` plumbing to the AM NPC run path and reran the full cpu-tests sweep with NEMU event DiffTest enabled.
   - Exit status: all 35 cpu-tests pass on NPC and pass with DiffTest enabled; P3 exit criteria are met.

Exit criteria:

- RV32E-targeted `cpu-tests` pass on NPC with DiffTest enabled where practical.
- Required CSR/trap behavior has directed tests and current pass/fail status.
- The internal IFU/LSU/control interfaces are ready to evolve toward AXI/icache and an optional pipeline without another decode/datapath rewrite.

## Phase 4: AM Runtime and Essential Workloads

Goal: make the essential AM runtime path work on both NPC and NEMU with UART and CLINT/timer support, then use existing AM workloads to validate the foundation before broader CTE/RT-Thread work.

Relevant references:

- `specs/abstract-machine/README.md`:
  - port TRM, UART, uptime timer, CTE, klib, and build-system support for `riscv32e-npc`;
  - assume the NPC platform frequency is 100 MHz for AM time conversion;
  - AM already has a built-in libc layer, klib, to complete; implementation can be copied/adapted from Sonnet libc (`https://gitlink.org.cn/foobat/sonnet-libc`) when needed.
- `specs/abstract-machine/specifications.md`:
  - TRM: `putch()`, `halt()`, heap, and `mainargs` contract;
  - IOE: `ioe_init()`, `ioe_read()`, `ioe_write()`, especially UART and timer abstract registers;
  - CTE: `cte_init()`, `yield()`, `kcontext()`, event dispatch, and context lifetime rules.
- PA2.3 / PA2.5:
  - AM runtime, klib, IOE abstraction, UART output, timer/RTC tests, and NEMU's device framework.
- PA3.1 and PA4.1:
  - exception/trap control flow and CTE validation using existing AM workloads such as `yield-os`.
- D5:
  - early NPC simulation may model UART/timer through DPI-C/MMIO before real bus devices exist;
  - UART address can be `0x10000000`.
- C5:
  - RT-Thread requires CSR access, `ecall`, `mret`, simple exception handling, CTE, and careful debugging, but RT-Thread is not the immediate Phase 4 implementation target until UART/CLINT are stable.
- `specs/core.md`:
  - `ebreak` is a real breakpoint exception architecturally;
  - no interrupts are supported, and built-in CLINT only provides `mtime`/`mtimeh` ticking once per core cycle.

Phase decisions and constraints:

- For this phase, only make **UART output** and a **temporary DiffTest-friendly timer** work first. Do not expand scope into optional devices, new custom workloads, preemptive timer interrupts, physical cycle-accurate CLINT, or full RT-Thread debugging until these basics are stable.
- UART input is out of scope in Phase 4. No Phase 4 workload is expected to need UART RX.
- `ebreak` simulation termination is a harness policy: after an `ebreak` instruction has retired, the simulator detects that retired event and stops/reports the result. Termination does not happen inside an AM trap handler.
- NPC must still keep architectural `ebreak` exception state correct enough for later CTE/RT-Thread work, but Phase 4 should not invent a custom AM termination trap handler.
- Use existing `am-kernels` workloads for CTE testing, especially `yield-os` and related tests. Do not create a new CTE workload unless existing workloads are unavailable or cannot isolate a confirmed bug.
- NEMU may be modified to support devices. Prefer its existing device framework rather than ad hoc device paths, so NEMU remains useful as a reference and AM target for UART/timer/CTE tests.
- Phase 4 timer decision: use a temporary simulation timer/CLINT model whose `mtime`/`mtimeh` advance deterministically by retired-instruction count, so current DiffTest remains usable. This is intentionally not the final physical CLINT behavior.
- The real physical CLINT from `specs/core.md` increments once per core cycle. Implementing that requires device-aware DiffTest first: REF peripherals off, DUT MMIO input capture, and replay of captured MMIO read values to REF. Schedule that refactor before physical CLINT integration, not in early Phase 4.
- Keep side effects out of unordered combinational DPI reads/writes. UART output and timer reads in NPC should be ordered through retired memory operations or another explicit harness protocol so Verilator evaluation order cannot duplicate, drop, or reorder device effects.
- Treat `rt-thread-am` as a later debugging-heavy consumer of the AM/CTE/device foundation. Expect issues in NPC RTL, NEMU device/reference behavior, AM CTE/trap assembly, klib, linker/startup files, and RT-Thread AM build glue, but do not start broad RT-Thread debugging before UART and the temporary timer are working.
- Avoid optional PA devices and applications. No keyboard, VGA, audio, PS/2, Nanos-lite, Navy, VME, user mode, or interrupts unless the user explicitly revises the scope.

Sessions:

1. **P4-S1: AM/NEMU/NPC device audit and baselines** — completed
   - Inspected current `riscv32e-npc` AM files, NPC MMIO/memory path, NEMU device configuration/framework, linker scripts, startup/trap code, and relevant `am-kernels` test entry points.
   - Re-ran the known-good Phase 3 checks: NPC regression and full cpu-tests with DiffTest, using the commands in `notes/next.md`.
   - Identified the current UART and CLINT/timer gaps in both NPC and NEMU: missing AM `putch()`, IOE stubs, device mapping, build config, and run commands.
   - Recorded the exact first failing commands for `hello`, AM timer/devscan tests, and NEMU smoke attempts in `notes/next.md`.
   - Exit status: Phase 3 directed regression and all 35 cpu-tests with DiffTest still pass; NPC `hello` terminates good but prints nothing because `putch()` is empty; AM timer/devscan are bounded failures; NEMU `hello` passes only when overriding the stale `-l` run flag.

2. **P4-S2: NPC ordered UART MMIO and AM `putch()`** — completed
   - Added NPC simulation UART output at `0x10000000`; writes are captured from retired store metadata and emitted by the C++ harness after the instruction commits, avoiding combinational DPI side effects.
   - Updated `abstract-machine/am/src/riscv/npc/trm.c` `putch()` to write to the UART MMIO address.
   - Updated NPC AM IOE UART config/TX so `AM_UART_CONFIG` reports present and `AM_UART_TX` calls `putch()`.
   - Validated `am-kernels/kernels/hello` on `ARCH=riscv32e-npc`: it visibly prints `Hello, AbstractMachine!` and ends with a good `NPC_RESULT`.
   - Re-ran the NPC directed regression and full 35-test cpu-tests sweep with NEMU event DiffTest; all passed.
   - Exit status: P4-S2 is complete; `am-tests mainargs=d` now prints through UART but remains bounded by the still-stubbed timer, which is the next P4-S3 task.

3. **P4-S3: Temporary retired-instruction timer and AM IOE timer** — completed
   - Added a Phase 4 simulation CLINT model in the NPC harness: `mtime`/`mtimeh` are exposed at `0x0200bff8`/`0x0200bffc` and advance deterministically by retired instruction count rather than by physical core cycles.
   - Kept CLINT writes and other CLINT reads side-effect-free/ignored; no interrupt behavior was added.
   - Updated `abstract-machine/am/src/riscv/npc/timer.c` to read `mtime` robustly and convert ticks to microseconds using the 100 MHz AM platform assumption.
   - Validated `am-tests mainargs=d` as a bounded timer/devscan smoke: it prints `Loop 10^7 time elapse: 500 ms` before later optional device probing reaches the existing nonimplemented-device panic.
   - Validated `am-tests mainargs=t` as a bounded RTC smoke: it prints the first one-second line before the intentionally infinite RTC loop hits the cycle limit.
   - Re-ran the NPC build, AM `hello`, directed NPC regression, and the full 35-test cpu-tests sweep with NEMU event DiffTest; all required regressions passed.
   - Exit status: P4-S3 is complete; the timer remains a temporary retired-instruction model, not the final physical cycle-based CLINT.

4. **P4-S4: NEMU device support for UART and temporary timer** — completed
   - Enabled NEMU native device support for UART and timer only, with keyboard/VGA/audio/disk disabled so macOS builds do not require SDL for this slice.
   - Kept UART/timer on NEMU's existing MMIO device framework at `0xa00003f8` and `0xa0000048`.
   - Made the NEMU RTC timer deterministic for this phase by deriving microseconds from retired instruction count (`g_nr_guest_inst / 100`), matching the temporary 100 MHz timing model used by AM timer tests.
   - Updated AM's NEMU platform timer implementation to read the RTC MMIO pair and report a simple 1900-01-01 RTC derived from uptime.
   - Removed the stale `-l` flag from the AM NEMU run path because the current NEMU monitor does not support it.
   - Added NEMU RV32M integer multiply/divide decode support needed by current `riscv32-nemu` AM timer workloads compiled with `-march=rv32im_zicsr`.
   - Exit status: NEMU `hello` prints through UART and exits good; NEMU devscan/RTC timer smokes show timer progression with bounded/expected terminal statuses; NPC directed regression and all 35 cpu-tests with NEMU event DiffTest still pass.

5. **P4-S5: Klib completion pass for essential workloads**
   - Audit remaining klib gaps hit by `hello`, timer tests, `yield-os`, and nearby AM workloads.
   - Complete missing klib functions by copying/adapting from Sonnet libc where suitable, while keeping code style compatible with `abstract-machine/klib`.
   - Validate with existing AM tests rather than inventing a new klib workload.
   - Exit when essential AM workloads no longer fail because of missing libc/klib routines.

6. **P4-S6: CTE validation with existing `am-kernels` workloads**
   - Audit existing Phase 3 trap/CSR behavior against AM CTE needs: `ecall`, `ebreak`, `mret`, `mtvec`, `mepc`, `mcause`, `mstatus`, and register save/restore expectations.
   - Implement or repair the `riscv32e-npc` CTE assembly/C glue only as needed by existing AM workloads: context structure, trap vector installation, trap frame save/restore, `yield()`, event classification, handler call/return, and `kcontext()`.
   - Use existing `am-kernels` CTE workloads such as `yield-os` for validation; do not create a new custom CTE test.
   - Use DiffTest and bounded commit/trace dumps for mismatches around trap entry/return.
   - Exit when the selected existing CTE workload passes or reaches a narrow documented blocker.

7. **P4-S7: Workload regression and Phase 4 closeout**
   - Re-run the Phase 4 standard set:
     - NPC directed regression;
     - full or representative cpu-tests with DiffTest;
     - `hello` with NPC UART output;
     - AM timer test on NPC CLINT;
     - matching UART/timer smoke tests on NEMU devices where available;
     - existing CTE workload such as `yield-os` if CTE work was reached.
   - Update `npc/README.md` and relevant notes with current run commands only if commands or user-facing flags changed.
   - Update `notes/next.md` with pass/fail table, exact commands, known caveats, and the next entry point.
   - Keep generated logs/images out of commits unless they are intentionally part of the project record.
   - Exit when a new session can reproduce the Phase 4 UART/CLINT state from notes alone.

Phase 4 exit criteria:

- NPC UART output at `0x10000000` is implemented with deterministic side effects, and `hello` prints visibly; UART input remains intentionally unsupported.
- NPC AM IOE timer support works using the temporary retired-instruction-based `mtime`/`mtimeh` source and the 100 MHz platform assumption; no timer interrupt behavior is introduced.
- NEMU has UART/temporary-timer support through its existing device framework or a narrow documented blocker.
- `ebreak`-based simulation termination is documented as retired-instruction detection in the harness, not AM trap-handler termination.
- Essential klib gaps found by the selected workloads are completed, using Sonnet libc as an allowed source when useful.
- Existing AM CTE workload validation, such as `yield-os`, is planned for when UART/temporary timer are stable; if reached in this phase, it has current pass/fail status.
- The temporary timer workaround and the need for later MMIO replay DiffTest before physical CLINT are recorded.
- Phase 3 cpu-tests and directed NPC regressions still pass after AM/runtime/device changes.

## Phase 5: System Bus, AXI4 Integration, and Device-Aware DiffTest

Goal: replace ideal DPI memory assumptions with bus-oriented memory/device access matching the top-level spec, and refactor DiffTest so real MMIO devices can be tested without forcing REF and DUT peripheral timing to match.

Relevant lecture guidance:

- B1 bus, SimpleBus, AXI4-Lite/AXI concepts.
- D6 ysyxSoC connection cautions.
- `specs/core.md` top module AXI master/slave ports.

Tasks:

1. Refactor IFU/LSU around valid/ready-style request/response interfaces if not already done.
2. Add a simple internal bus abstraction that can evolve from simulation memory to AXI master.
3. Implement aligned little-endian memory accesses; raise misaligned exceptions on unaligned accesses.
4. Extend retired instruction / CommitEvent metadata to describe MMIO accesses: address, size, write data, write mask, read value, exception/access-fault status, and whether the access is normal memory or MMIO.
5. Refactor DiffTest for peripherals before implementing physical CLINT:
   - run REF with peripherals disabled or side effects suppressed;
   - capture all DUT MMIO input values, especially MMIO read return values;
   - replay captured MMIO read values into REF at the matching retired instruction;
   - validate or suppress MMIO write side effects so UART output is not duplicated;
   - continue comparing PC/GPR/CSR and exception behavior at retirement.
6. Implement AXI master channels with 32-bit data width and required response handling.
7. Hardwire reserved AXI slave outputs to zero and ignore reserved inputs.
8. Keep the temporary retired-instruction timer from Phase 4 until device-aware DiffTest replay is working; do not replace it with physical CLINT earlier.
9. Treat AXI `SLVERR`/`DECERR` as access faults.
10. Add tests with deterministic and delayed memory responses to validate handshakes.

Exit criteria:

- Core can run previous tests through bus/AXI-facing memory model.
- Device-aware DiffTest can replay DUT MMIO reads into REF with REF peripherals disabled/suppressed.
- UART MMIO writes do not produce duplicate REF/DUT host output during DiffTest.
- Misalignment and bus error exceptions are tested.
- Top-level ports match `specs/core.md`.

## Phase 6: Physical Built-in CLINT, UART Path, and RT-Thread Stability

Goal: replace the Phase 4 temporary timer with the spec-required physical built-in CLINT after device-aware DiffTest replay exists, then solidify required runtime-device and OS-level workload behavior.

Relevant lecture guidance:

- D5 NPC I/O.
- C5 RT-Thread.
- B1 AXI CLINT notes, adapted to built-in CLINT requirement.

Prerequisite:

- Phase 5 device-aware DiffTest replay is working. Do not implement the physical cycle-based CLINT before this, because `mtime` reads are MMIO inputs that otherwise make REF/DUT comparison depend on mismatched peripheral timing.

Tasks:

1. Replace the temporary retired-instruction timer with physical CLINT `mtime`/`mtimeh` incrementing once per core cycle.
2. Ignore writes/reads to `mtimecmp`, `mtimecmph`, `msip` as specified: no effect, no error, read undefined.
3. Update AM timer code if needed to read `mtime`/`mtimeh` robustly as 64-bit time.
4. Keep interrupt behavior disabled; do not generate timer interrupts.
5. Keep UART output support in simulation/SoC path sufficient for `hello` and RT-Thread console output; UART input remains deferred until a workload requires it.
6. Re-run `hello`, timer test, CTE workloads such as `yield-os`, and `rt-thread-am` after bus/physical CLINT integration.

Exit criteria:

- CLINT behavior matches `specs/core.md` and increments by core cycle.
- Device-aware DiffTest remains usable with physical CLINT MMIO reads replayed from DUT to REF.
- Essential UART/timer/CTE workloads still pass.

## Phase 7: Instruction Cache and `fence.i`

Goal: implement the spec-required instruction cache and validate both function and performance counters.

Relevant lecture guidance:

- B4 performance counters, icache, AMAT, formal verification, burst refill.
- B5 `fence.i` pipeline caution for future pipeline phase.

Tasks:

1. Implement a flip-flop direct-mapped icache:
   - capacity: 8 instructions / 32 bytes
   - line size: 16 bytes / 4 instructions
   - associativity: 1
   - all instruction-fetchable addresses treated cacheable
2. Implement AXI burst refill for 16-byte cache lines over 32-bit data bus.
3. Implement `fence.i` as icache clear.
4. Add performance counters for icache AMAT:
   - accesses
   - hits
   - misses
   - miss wait cycles / total miss time
   - refill beats
5. Validate cache functionality against uncached fetch behavior.
6. Where practical, add a small formal or randomized test for icache correctness under delayed AXI responses.
7. Compare RTL miss counts with a simple `cachesim` if the trace flow is available.

Exit criteria:

- All previous functional tests pass with icache enabled.
- `fence.i` invalidates cached instructions.
- AMAT counters are emitted and internally consistent.

## Phase 8: Performance Measurement and PPA Baselines

Goal: quantify the design before optimization and keep results reproducible.

Relevant lecture guidance:

- B4 performance evaluation and Amdahl's law.
- PA5 profiling mindset.

Tasks:

1. Add a standard performance report emitted by simulation or scripts:
   - cycles
   - retired instructions
   - IPC
   - instruction class counts
   - IFU/LSU wait cycles
   - icache AMAT counters
2. Run `coremark` and selected smaller workloads under reproducible commands.
3. Record results in notes with commit/hash, command, config, and observed counters.
4. Run synthesis/timing/area estimation if the required toolchain is available.
5. Use Amdahl's law and counters to decide the next optimization target.

Exit criteria:

- A baseline table exists in notes.
- At least `hello`, `cpu-tests`, `coremark`, and `rt-thread-am` have recorded status.

## Phase 9: Optional Pipeline and Targeted Optimizations

Goal: improve performance only after the non-pipelined/bus/cache design is correct and measured.

Relevant lecture guidance:

- B5 pipeline processor, hazards, forwarding, branch prediction, pipeline `fence.i`.

Tasks:

1. Decide from counters whether pipeline work is worth doing under current constraints.
2. If yes, introduce a simple pipeline using existing valid/ready stage boundaries.
3. Start with conservative hazard handling:
   - stall for RAW hazards
   - flush on control-flow changes and exceptions
   - precise exception state for required exceptions
4. Add forwarding only after measuring RAW-stall impact.
5. Keep branch prediction simple unless counters show it matters.
6. Ensure `fence.i` flushes younger fetched/decode-stage instructions after clearing icache.
7. Use DiffTest at retirement and targeted random/fuzz tests for hazard sequences.

Exit criteria:

- Pipelined version passes the same functional suite as baseline.
- Performance gain is measured and justified against area/frequency cost.

## Phase 10: Final Integration and Documentation

Goal: make the project maintainable for future sessions and review.

Tasks:

1. Keep `notes/next.md` updated at every session boundary.
2. Maintain concise design notes for:
   - ISA/CSR choices
   - exception behavior
   - bus/AXI design
   - CLINT behavior
   - icache and performance counters
3. Keep build/run commands current.
4. Remove stale comments and dead debug paths before considering work complete.
5. Run the standard regression suite before finalizing major changes.

Exit criteria:

- A new session can continue from notes without relying on hidden memory.
- Standard workloads and checks have current recorded results.
