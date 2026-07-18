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

## Phase 4: AM Runtime, CTE, and RT-Thread AM

Goal: make the essential AM runtime path work on both NPC and NEMU with UART, temporary timer, CTE, and `rt-thread-am` support, so the project does not leave Phase 4 until the RT-Thread AM port has at least a reproducible boot/smoke status.

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
  - exception/trap control flow and CTE validation using existing AM workloads such as `yield-os`;
  - RT-Thread AM is built around AM TRM/CTE: heap from TRM, console output through `putch()`, interrupt enable/disable through `iset()`, and context creation/switching through `kcontext()`/`yield()`.
- PA4.1 RT-Thread section:
  - `rt-thread-am/bsp/abstract-machine/src/context.c` must implement `rt_hw_stack_init()`, `rt_hw_context_switch_to()`, and `rt_hw_context_switch()`;
  - thread entry wrapping must preserve `tentry`, `parameter`, and `texit`, preferably in per-thread stack data rather than a shared global;
  - context switch can use `yield()` plus an event handler to save `from` and return `to`;
  - expected success is RT-Thread boot output, built-in shell command output, and finally an idle shell prompt such as `msh />`; lack of UART RX means interactive input is not required.
- D5:
  - early NPC simulation may model UART/timer through DPI-C/MMIO before real bus devices exist;
  - UART address can be `0x10000000`.
- C5:
  - RT-Thread requires CSR access, `ecall`, `mret`, simple exception handling, CTE, and careful debugging;
  - NPC RT-Thread support should be attempted after NEMU/AM CTE works, not postponed past the phase that claims to cover essential workloads.
- `specs/core.md`:
  - `ebreak` is a real breakpoint exception architecturally;
  - no interrupts are supported, and built-in CLINT only provides `mtime`/`mtimeh` ticking once per core cycle.

Phase decisions and constraints:

- For this phase, make **UART output**, a **temporary DiffTest-friendly timer**, AM CTE, and an initial `rt-thread-am` boot/smoke path work. Do not expand scope into optional devices, physical cycle-accurate CLINT, preemptive timer interrupts, Nanos-lite, Navy, or graphical applications.
- UART input remains out of scope. RT-Thread's AM UART shim may feed scripted input if already present, but Phase 4 success must not depend on interactive host input.
- `ebreak` simulation termination is a harness policy: after an `ebreak` instruction has retired, the simulator detects that retired event and stops/reports the result. Termination does not happen inside an AM trap handler.
- NPC must keep architectural `ebreak` exception state correct enough for CTE/RT-Thread work, but Phase 4 should not invent a custom AM termination trap handler.
- Use existing `am-kernels` workloads for CTE testing, especially `yield-os` and `thread-os`, before debugging RT-Thread. Do not create a new CTE workload unless existing workloads are unavailable or cannot isolate a confirmed bug.
- NEMU may be modified to support devices. Prefer its existing device framework rather than ad hoc device paths, so NEMU remains useful as a reference and AM target for UART/timer/CTE/RT-Thread tests.
- Phase 4 timer decision: use a temporary simulation timer/CLINT model whose `mtime`/`mtimeh` advance deterministically by retired-instruction count, so current DiffTest remains usable. This is intentionally not the final physical CLINT behavior.
- The real physical CLINT from `specs/core.md` increments once per core cycle. Implementing that requires device-aware DiffTest first: REF peripherals off, DUT MMIO input capture, and replay of captured MMIO read values to REF. Schedule that refactor before physical CLINT integration, not in Phase 4.
- Keep side effects out of unordered combinational DPI reads/writes. UART output and timer reads in NPC should be ordered through retired memory operations or another explicit harness protocol so Verilator evaluation order cannot duplicate, drop, or reorder device effects.
- Treat RT-Thread as the final Phase 4 consumer of the AM/CTE/device foundation. Expect issues in NPC RTL, NEMU device/reference behavior, AM CTE/trap assembly, klib, linker/startup files, RT-Thread AM build glue, and `rt-thread-am/bsp/abstract-machine/src/context.c`; debug the smallest failing slice first.
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
   - Audit remaining klib gaps hit by `hello`, timer tests, `yield-os`, `thread-os`, and `rt-thread-am`.
   - Complete missing klib functions by copying/adapting from Sonnet libc where suitable, while keeping code style compatible with `abstract-machine/klib`.
   - Validate with existing AM tests rather than inventing a new klib workload.
   - Exit when essential AM and RT-Thread smoke paths no longer fail because of missing libc/klib routines.

6. **P4-S6: CTE validation with existing `am-kernels` workloads** — completed
   - Fixed the shared RISC-V AM `Context` layout to match the trap frame saved by `trap.S`.
   - Implemented RISC-V CTE yield classification, `mepc` advance after `ecall`, trap-handler context switching, and `kcontext()` for both NPC and NEMU AM targets.
   - Added a shared `__am_kcontext_start` assembly trampoline that starts kernel contexts with `a0 = arg` and `jalr entry`.
   - Validated with existing `am-kernels/kernels/yield-os` and `am-kernels/kernels/thread-os`; no custom CTE workload was added.
   - Added the NPC AM MPE glue needed by `thread-os`: `riscv/npc/mpe.c` is now linked for `ARCH=riscv32e-npc`, calls the bootstrap entry on the single simulated CPU, reports `cpu_count() == 1`/`cpu_current() == 0`, and provides a simple single-core `atomic_xchg()`.
   - Exit status: `yield-os` switches between the two contexts and prints `ABAB` under bounded NPC/NEMU runs; `thread-os` enters its thread loop and prints `Thread-B on CPU #0` under a bounded NPC run. These workloads then hit the expected instruction/cycle limits because they are intentionally infinite. NPC runs use NEMU event DiffTest and report no DiffTest failure before the bound.

7. **P4-S7: RT-Thread AM baseline and context implementation** — completed
   - Fixed the RT-Thread AM generated-config path on macOS: `Makefile` now inserts `#include "extra.h"` without GNU `sed -i` assumptions, adds the RT-Thread freestanding extension include path, and pre-includes `sys/types.h` for common POSIX typedefs.
   - Made `integrate-am-apps.py` robust when optional AM apps are missing or fail to build; in the current tree, `snake` is skipped because it includes unavailable `<stdlib.h>` in the AM app build, and missing `fceux-am` is skipped.
   - Added the small freestanding C/POSIX compatibility headers needed by this RT-Thread configuration under `components/libc/compilers/common/extension/`.
   - Implemented AM-backed RT-Thread context creation and cooperative switching in `src/context.c`: `rt_hw_stack_init()` builds a `kcontext()` with stack-resident thread-start arguments, `rt_hw_context_switch_to()`/`rt_hw_context_switch()` use `yield()` and the CTE handler to switch contexts, and interrupt context switching remains unsupported because Phase 4 has no timer interrupts.
   - Corrected `src/interrupt.c` prototypes to match RT-Thread UP declarations and return/restore the old interrupt-enable state.
   - Reduced `src/uart.c` includes to the serial driver dependencies required for console registration, avoiding broad `rtdevice.h` include fallout in the BSP file.
   - Clamped the `riscv32-nemu` RT-Thread heap end to `0x82000000`, matching the current native NEMU physical memory size, instead of trusting AM's stale 128 MiB `PMEM_END` declaration.
   - Exit status: `rt-thread-am` builds and runs on NEMU; it prints the RT-Thread banner, `Hello RISC-V!`, scripted shell commands, and reaches the final `msh />`. The bounded run then hits `NEMU_MAX_INSTS`, which is expected because RT-Thread idles forever without interactive UART input.

8. **P4-S8: RT-Thread AM on NPC and DiffTest-safe smoke**
   - Build/run `rt-thread-am` with `ARCH=riscv32e-npc`, `AM_HOME`, `CROSS_COMPILE=riscv64-elf-`, and a bounded `NPC_MAX_CYCLES`.
   - Fix only issues required for the same RT-Thread AM smoke target reached on NEMU: RV32E build flags, linker/startup assumptions, AM heap boundaries, UART output, CTE context layout, missing klib symbols, or NPC ISA/CSR/trap bugs.
   - Use NEMU event DiffTest when practical, but allow targeted suppression or a documented no-DiffTest run if RT-Thread MMIO/timer behavior hits the current pre-Phase-5 DiffTest limits.
   - Do not add preemptive scheduling, timer interrupts, UART RX, optional shell applications, AM app integration, graphics, storage, or network support in this phase.
   - Exit when NPC reaches the same visible RT-Thread smoke milestone as NEMU, or when the remaining blocker is narrow enough to schedule before Phase 5.

9. **P4-S9: Workload regression and Phase 4 closeout**
   - Re-run the Phase 4 standard set:
     - NPC directed regression;
     - full or representative cpu-tests with DiffTest;
     - NPC/NEMU `hello` UART output;
     - NPC/NEMU timer smokes;
     - NPC/NEMU `yield-os` bounded CTE smoke;
     - NPC `thread-os` bounded CTE/MPE smoke;
     - RT-Thread AM NEMU and NPC smoke commands from P4-S7/P4-S8.
   - Update `npc/README.md`, `rt-thread-am/bsp/abstract-machine` notes if any user-facing commands changed, and `notes/next.md` with pass/fail table, exact commands, known caveats, and the Phase 5 entry point.
   - Keep generated logs/images out of commits unless they are intentionally part of the project record.
   - Exit when a new session can reproduce the Phase 4 UART/timer/CTE/RT-Thread state from notes alone.

Phase 4 exit criteria:

- NPC UART output at `0x10000000` is implemented with deterministic side effects, and `hello` prints visibly; UART input remains intentionally unsupported.
- NPC AM IOE timer support works using the temporary retired-instruction-based `mtime`/`mtimeh` source and the 100 MHz platform assumption; no timer interrupt behavior is introduced.
- NEMU has UART/temporary-timer support through its existing device framework or a narrow documented blocker.
- `ebreak`-based simulation termination is documented as retired-instruction detection in the harness, not AM trap-handler termination.
- Essential klib gaps found by the selected workloads are completed, using Sonnet libc as an allowed source when useful.
- Existing AM CTE workloads, at least `yield-os` and a bounded `thread-os` smoke where practical, have current pass/fail status.
- `rt-thread-am` has current NEMU and NPC smoke commands and status. The minimum successful target is boot/banner/scripted shell output through `msh />`; if not reached, the remaining blocker must be narrow, reproducible, and scheduled before Phase 5.
- The temporary timer workaround and the need for later MMIO replay DiffTest before physical CLINT are recorded.
- Phase 3 cpu-tests and directed NPC regressions still pass after AM/runtime/device/RT-Thread changes.

## Phase 5: System Bus, AXI4 Integration, and Device-Aware DiffTest

Goal: replace the current idealized DPI memory/device assumptions with a bus-oriented memory and device path that matches `specs/core.md`, while making DiffTest robust for real MMIO devices by replaying DUT-observed MMIO inputs into the NEMU reference.

Relevant lecture guidance:

- B1 bus, SimpleBus, AXI4-Lite/AXI concepts.
- D6 ysyxSoC connection cautions.
- `specs/core.md` top module AXI master/slave ports.

Scope decisions:

- Keep Phase 4's temporary retired-instruction timer until device-aware MMIO replay is working.
- Do not switch to the physical cycle-based CLINT in Phase 5; that belongs to Phase 6 after replay exists.
- Do not add interrupts, UART input, optional PA devices, VME, graphics, storage, or SoC integration unless they are needed to validate the bus/DiffTest work.
- Preserve the existing passing workload set throughout the phase: NPC directed tests, 35 cpu-tests with DiffTest, `hello`, timer smokes, CTE workloads, and RT-Thread AM smoke.
- Simulate AXI before `ysyxSoC` integration with a local NPC AXI slave testbench/model in `npc/csrc` or adjacent simulation code. The model should provide RAM, UART MMIO, temporary CLINT/timer MMIO, configurable latency/backpressure, and `SLVERR`/`DECERR` responses, so core AXI behavior can be validated without requiring `ysyxSoC`.

Sessions:

1. **P5-S1: NEMU memory-region groundwork** — completed
   - Refactored NEMU physical memory into a region table with loadable/writable attributes.
   - Added checked guest copy helpers for image loading and DiffTest memory injection.
   - Added Kconfig memory-map scheme selection with legacy and NPC placeholders.
   - Revalidated NEMU `hello`, NPC `hello` with DiffTest, NPC directed regression, and 35 cpu-tests.
   - Remaining caveat: temporary NPC UART/CLINT aliases still live in generic `paddr.c`.

2. **P5-S2: Device/MMIO cleanup and replay contract** — completed, pending user note review/commit
   - Moved temporary NPC UART/CLINT address handling out of generic NEMU `paddr.c` into device/MMIO code.
   - Implemented a lightweight ordered MMIO replay contract outside `CommitEvent`:
     - DUT records the just-retired MMIO access in the NPC harness;
     - DUT passes one optional MMIO replay record to the NEMU REF before stepping the matching REF instruction;
     - REF MMIO callbacks validate matching address/size/direction/data and replay DUT read data;
     - REF shared-object UART output is suppressed so DiffTest does not duplicate DUT host output;
     - normal RAM traffic is not replayed transaction-by-transaction.
   - Added temporary NEMU NPC-compatible devices for UART `0x10000000` and CLINT `0x02000000..0x0200bfff` following `specs/clint.rst` bounds. The timer value remains the Phase 4 retired-instruction model.
   - Revalidated NEMU `hello`, NPC `hello` with DiffTest, RT-Thread NPC DiffTest smoke, NPC directed regression, all 35 cpu-tests, and timer/devscan smokes.

3. **P5-S3: NPC internal bus request/response boundary**
   - Refactor IFU and LSU memory access around explicit request/response style interfaces.
   - Keep behavior functionally equivalent to the current single-cycle/DPI model where possible.
   - Ensure aligned little-endian load/store behavior remains unchanged.
   - Preserve misaligned instruction/load/store exception behavior.
   - Add or update directed tests for delayed responses and backpressure at the internal bus boundary.
   - Re-run Phase 4 standard regressions.

4. **P5-S4: AXI4 master shell and local simulation AXI slave**
   - Implement the top-level AXI4 master port set required by `specs/core.md`.
   - Connect IFU/LSU requests to an AXI-facing adapter in simulation.
   - Add a local NPC AXI slave testbench/model before `ysyxSoC` is available:
     - RAM region, e.g. `0x80000000..0x87ffffff`;
     - UART MMIO, e.g. `0x10000000`;
     - temporary CLINT/timer MMIO, e.g. `0x0200bff8`/`0x0200bffc`;
     - empty/error regions returning `SLVERR` or `DECERR`.
   - Initially support 32-bit aligned single-beat read/write; later extend read bursts for icache refill.
   - Support valid/ready handshakes, response completion, configurable latency, and backpressure.
   - Treat AXI `SLVERR`/`DECERR` as instruction/load/store access faults.
   - Keep the reserved AXI slave interface hardwired inactive/zero and ignore reserved inputs.
   - Keep UART host output ordered by retirement, not by unordered combinational bus probes.
   - Add handshake tests with deterministic and delayed memory responses.

5. **P5-S5: DiffTest with bus/MMIO access faults**
   - Integrate access-fault results from the bus/AXI path into retired instruction metadata.
   - Make DiffTest compare PC/GPR/CSR and exception behavior correctly when DUT sees bus errors.
   - Add tests for instruction access fault, load access fault, and store access fault from simulated AXI error responses.
   - Confirm `ebreak` termination still uses retired-instruction matching and does not mask access-fault behavior.

6. **P5-S6: Full Phase 5 regression and closeout** — completed
   - Re-ran the core bus/DiffTest closeout set after commits through `fe55944 Handle AXI access faults in DiffTest`:
     - `make -C nemu && make -C nemu SHARE=1`: passed.
     - `make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu test-mem-size test-axi-local test-access-fault test-rv32e-illegal test-csr-trap test-debug test-difftest`: passed by Makefile expectations.
     - Full 35-test `cpu-tests` sweep on `ARCH=riscv32e-npc` with NEMU event DiffTest: passed.
     - NPC `hello` with NEMU event DiffTest: passed and printed `Hello, AbstractMachine!`.
     - NPC `rt-thread-am` with NEMU event DiffTest: passed through scripted shell `halt` with `NEMU_RESULT status=good` and `NPC_RESULT status=good`.
     - NPC bounded `yield-os` and `thread-os`: reached expected CTE/thread output before intentional cycle limits.
     - Native NEMU `hello` and native NEMU `rt-thread-am`: passed after the native MMIO access-check fix below.
     - Native NEMU AM devscan/timer smoke reaches expected bounded loop behavior.
   - Fixed the native `ARCH=riscv32-nemu` closeout regression before entering Phase 6:
     - root cause: `vaddr_access_ok()` recognized the NPC-compatible UART/CLINT MMIO aliases used by DiffTest, but not native NEMU UART/RTC MMIO (`CONFIG_SERIAL_MMIO`, `CONFIG_RTC_MMIO`);
     - effect: native UART stores were reported as access faults, and with `mtvec=0` execution fell into an instruction-access-fault loop at `pc=0x00000000`;
     - fix: `nemu/src/memory/vaddr.c` now treats configured native serial/timer MMIO windows as valid accesses when those devices are enabled.
   - Exit status: Phase 5 is closed. The native regression was cleared before Phase 6, so no known regression is being carried across the phase boundary.

Exit criteria:

- The core can run previous functional tests through a bus/AXI-facing memory model. **Met for NPC local AXI path.**
- Top-level ports match `specs/core.md`, including AXI master signals and inactive reserved AXI slave outputs. **Met by `npc/rtl/NPC.v`; reserved slave outputs are hardwired zero/inactive.**
- Misaligned access behavior remains correct, and AXI `SLVERR`/`DECERR` produce the specified access faults. **Met for local `SLVERR` directed tests; external `DECERR` is not separately modeled yet.**
- Device-aware DiffTest can replay DUT-observed MMIO read values into the REF at retirement. **Met for NPC DiffTest workloads.**
- UART MMIO writes do not duplicate host output during DiffTest. **Met in NPC `hello`/RT-Thread smoke.**
- Temporary retired-instruction timer is still documented as temporary and remains in place until Phase 6. **Met.**
- Phase 4 NPC workload set still passes or has documented expected bounded runs. **Met for NPC; native NEMU regressions are tracked as pre-Phase-6 cleanup, not as Phase 6 scope.**

## Phase 6: Physical Built-in CLINT, UART Path, and RT-Thread Stability

Goal: replace the Phase 4 temporary retired-instruction timer with the spec-required physical built-in CLINT after Phase 5 is closed, then validate required runtime-device and OS-level behavior under device-aware DiffTest.

Relevant specs and lecture guidance:

- `specs/core.md`:
  - built-in CLINT only implements `mtime`/`mtimeh` for timing;
  - no interrupt behavior is supported;
  - timer increments by 1 each core cycle;
  - default CLINT window is `0x02000000..0x0200ffff`;
  - reads/writes to `mtimecmp`, `mtimecmph`, and `msip` are ignored with no error and undefined read content.
- `specs/clint.rst`:
  - reference CLINT base is `0x02000000`, bound `0x0200bfff`;
  - register offsets are `msip=0x0`, `mtimecmp=0x4000`, `mtime=0xbff8`;
  - other addresses in the CLINT window are reserved and generate slave error in the reference IP.
- Project decision for this core: follow `specs/core.md` where it is more specific for this project, but keep the `specs/clint.rst` register offsets/window behavior for the implemented CLINT address map.
- D5 NPC I/O, C5 RT-Thread, and B1 AXI/CLINT notes remain relevant.

Prerequisites:

- Phase 5 is closed.
- Phase 5 device-aware MMIO replay remains working; physical `mtime` values must be replayed from DUT reads into the NEMU REF.

Sessions:

1. **P6-S1: Physical CLINT design and implementation** — done.
   - Final approved design is recorded in `notes/clint-implementation-plan.md`.
   - Implemented CLINT as a physical RTL LSU-side combinational bypass before `AxiArbiter` (Position 5), not as a C++ timer, post-arbiter local-device mux, or AXI xbar.
   - Kept IFU, `AxiArbiter.v`, and `AxiMaster.v` unchanged; exact-cycle non-CLINT load/store checks still pass.
   - Preserved ordered MMIO replay records for CLINT reads by replaying committed RTL load data into the NEMU REF.
   - Added `make -C npc test-clint` for directed physical CLINT coverage.
   - Replaced retired-instruction-based `mtime` with a 64-bit physical cycle counter incrementing once per core clock while reset behavior is well-defined.
   - Exposed `mtime` low/high at `0x0200bff8`/`0x0200bffc` through the LSU-side CLINT path.
   - Implemented ignored no-error behavior for CLINT-window writes and unimplemented CLINT reads; ignored/reserved CLINT reads return zero.

2. **P6-S2: Timer/DiffTest/workload validation** — done.
   - Strengthened `make -C npc test-clint` so the generated program performs the AM-style `mtimeh/mtime/mtimeh` read sequence, checks the high word remains stable in the short smoke, checks the low word advances, checks ignored CLINT-window writes/reads, and runs with NEMU event DiffTest replay.
   - Revalidated that committed CLINT reads are replayed from DUT RTL load data into the NEMU REF: the strengthened CLINT test passed with `NPC_DIFFTEST status=on`, `NEMU_RESULT status=good`, and `NPC_RESULT status=good`.
   - Re-ran NPC `hello`, AM timer/devscan smoke, bounded `yield-os`, bounded `thread-os`, full 35-test `cpu-tests` with DiffTest, and NPC `rt-thread-am` with DiffTest.
   - Confirmed no timer interrupt behavior is being generated: CTE workloads only show synchronous `ecall` trap state (`mcause=0x0000000b`) at the bound, and RT-Thread completes scripted `halt` without asynchronous timer-trap evidence.
   - Confirmed UART output remains ordered/non-duplicated in `hello`, bounded CTE smokes, and RT-Thread shell output.
   - Documented expected bounded runs separately from failures in `notes/next.md`.

3. **P6-S3: Phase 6 closeout notes**
   - Update `notes/next.md` with exact commands, pass/fail table, CLINT behavior, and known caveats.
   - Update `notes/plan.md` if Phase 7 prerequisites change.
   - Update user-facing README/BSP notes only if commands or platform-visible timer behavior changed.

Exit criteria:

- CLINT behavior matches `specs/core.md`: `mtime`/`mtimeh` increment once per core cycle, no interrupts, and ignored `msip`/`mtimecmp` accesses have no effect and no error.
- CLINT address offsets follow `specs/clint.rst` for `msip`, `mtimecmp`, and `mtime` within the project CLINT window.
- Device-aware DiffTest remains usable with physical CLINT MMIO reads replayed from DUT to REF.
- Essential UART/timer/CTE workloads still pass or have narrow, reproducible, documented blockers.

## Phase 7: Instruction Cache and `fence.i`

Goal: implement the spec-required instruction cache, validate it against the existing workload suite, and leave enough performance-counter data for Phase 8.

Relevant lecture guidance:

- B4 performance counters, icache, AMAT, formal verification, burst refill.
- B5 `fence.i` pipeline caution for future pipeline phase.

Sessions:

1. **P7-S1: Implement icache, `fence.i`, counters, and smoke tests** — done.
   - Implemented the direct-mapped flip-flop instruction cache:
     - capacity: 8 instructions / 32 bytes;
     - line size: 16 bytes / 4 instructions;
     - associativity: 1;
     - all instruction-fetchable addresses treated cacheable.
   - Added 16-byte AXI burst refill for instruction-cache misses while keeping LSU/data accesses single-beat and leaving CLINT behavior unchanged.
   - Implemented `fence.i` as clearing all icache valid bits at successful retirement.
   - Added AMAT-related counters: accesses, hits, misses, miss wait cycles, and refill beats.
   - Emitted counters in structured `NPC_ICACHE` output near `NPC_RESULT`.
   - Added focused generated `test-icache` and `test-fencei` checks.
   - Smoke validation passed: `make -C npc test-icache test-fencei`, NPC directed smoke/regression subset including `test-clint`, `make -C npc test-access-fault`, and NPC `hello` with NEMU event DiffTest.
   - Exact-cycle Makefile checks were relaxed where icache timing changed cycles; semantic checks remain.

2. **P7-S2: Full regression and bug fixing** — done.
   - Full practical regression with icache enabled completed without requiring RTL/C++ fixes.
   - NPC directed regression passed, including smoke/directed tests, memory-size/misalignment/access-fault/CSR/DiffTest/CLINT tests, and focused `test-icache`/`test-fencei` checks.
   - Full 35-test `cpu-tests` sweep passed with NEMU event DiffTest using the macOS `printf` temporary Makefile workaround.
   - AM/NPC `hello` passed with NEMU event DiffTest and printed the expected output.
   - AM devscan/timer remained an expected bounded run at the timer delay loop, now reaching `cycles=80000000 insts=25000215` with a near-perfect warm-loop icache hit rate.
   - Bounded `yield-os` and `thread-os` remained expected bounded CTE/thread runs, with more visible output than P6 due to faster icache hits (`ABABABAB` and eight `Thread-B on CPU #0` lines before the 12M-cycle limit).
   - RT-Thread passed through scripted shell `halt` with NEMU event DiffTest.
   - UART output remained ordered/non-duplicated, CLINT DiffTest replay still worked, access faults and misalignment behavior remained correct, and `refill_beats == misses * 4` held for representative successful local-memory refills.
   - Exit status: all previous Phase 6 functional tests pass, expected bounded runs remain narrowly documented, no known icache correctness regression remains, and counter output is stable enough for Phase 8.

3. **P7-S3: Linux migration, final exit check, and Phase 8 preparation** — done.
   - Split platform-specific notes into `notes/platform-macos.md` and `notes/platform-linux.md`.
   - Validated the Linux/AOSC aarch64 host using its local target compiler setting, `CROSS_COMPILE=riscv64-linux-gnu-`; macOS remains supported via `notes/platform-macos.md` and its `riscv64-elf-` setting.
   - Rebuilt stale macOS-generated NEMU helpers on Linux, rebuilt the NEMU shared REF and NPC simulator natively, and regenerated RT-Thread AM file metadata with Linux paths.
   - Adjusted `nemu/src/device/Kconfig` so `CONFIG_TARGET_SHARE=y` can still build with `CONFIG_DEVICE=y`; this keeps NPC UART/CLINT MMIO replay support in the DiffTest shared REF and is not Linux-specific.
   - Re-ran the P7 closeout suite on Linux: NPC directed regression, full 35-test `cpu-tests`, `hello`, AM devscan/timer bounded smoke, `yield-os`/`thread-os` bounded smokes, and RT-Thread with DiffTest.
   - Exit status: Phase 7 is closed with Linux validation added; Phase 8 has per-platform notes and representative counter output in `notes/platform-linux.md`, `notes/platform-macos.md`, and `notes/next.md`.

Exit criteria:

- All previous functional tests pass with icache enabled.
- `fence.i` invalidates cached instructions.
- Instruction-cache refill uses 16-byte AXI bursts.
- AMAT counters are emitted and internally consistent.
- Phase 8 has reproducible commands and representative counter output to start from.

## Phase 8: Linux PPA, Optimization, and Spec-Interface Readiness

Goal: make the synthesis target spec-compliant, measure timing/PPA and performance on Linux, perform one measured optimization, and leave a reusable timing/PPA workflow for future pipeline work.

Relevant lecture guidance:

- B4 performance evaluation, icache/AMAT, and Amdahl's law.
- B3/B4 timing/PPA measurement flow.
- PA5 profiling mindset.

Scope decisions:

- P8 timing/PPA is Linux-only because the available iEDA flow is Linux-only in the current environment.
- macOS remains valid for functionality work outside Linux-only PPA tooling.
- Do not add broad emulator/DiffTest infrastructure in P8.
- Use `CROSS_COMPILE=riscv64-linux-gnu-` on the current Linux host.
- Keep VCD generation bounded and optional.

Sessions:

1. **P8-S1: Guard debug ports and add a spec-interface simulation harness** — done.
   - Added `NPC_DEBUG` build mode. The default `NPC_DEBUG=1` preserves the Verilator/DiffTest/debug flow; `NPC_DEBUG=0` hides `io_reset_pc`, `debug_*`, and `commit_*` from `npc/rtl/NPC.v` top-level ports.
   - Kept functional datapath/control logic unchanged and reused the existing C++ simulation code plus `LocalAxiSlave`/DPI memory path for the spec smoke.
   - Added `npc/tests/make-spec-uart-bin.py` and `make -C npc NPC_DEBUG=0 spec-smoke`, which runs a tiny UART program from reset PC `0x20000000` and stops on UART EOT (`0x04`) without using debug/commit ports.
   - Added `RESET_PC` Verilator parameter support in the NPC Makefile and `--uart-expect TEXT` in the simulator so spec mode can run larger AM images at `0x80000000` and stop after expected UART output.
   - Validation completed on Linux: `NPC_DEBUG=0 spec-smoke` printed `SPEC` and `NPC_SPEC_RESULT status=good reason=uart_eot cycles=61`; `hello` in spec mode printed `Hello, AbstractMachine!` and stopped at `NPC_SPEC_RESULT status=good reason=uart_expect cycles=1217`; RT-Thread in spec mode reached `msh />` and stopped at `NPC_SPEC_RESULT status=good reason=uart_expect cycles=302371`; default debug-mode smoke/selected DiffTest checks still passed.

2. **P8-S2: Analyze baseline PPA/performance and perform targeted optimization** — done.
   - Ran Linux Yosys/iEDA physical synthesis and STA against the SoC-connectable `NPC_DEBUG=0` top, excluding Verilator-only `LocalAxiSlave.v`/`MemIf.v` from the PPA RTL list.
   - Recorded the reproducible flow and results in `notes/p8-timing-and-ppa.md`.
   - Baseline at 100 MHz: area `22867.040000`, worst core max path `1.619 ns`, slack `8.334 ns`, reported Fmax `600.118 MHz`, iEDA total power estimate `3.65956 W`.
   - Performance baseline covered `hello`, selected `cpu-tests` (`sum`, `string`, `crc32`, `quick-sort`, `matrix-mul`), bounded default `coremark`, and `rt-thread-am` using debug/DiffTest output lines.
   - Implemented a measured spec-mode cleanup: `NPC_LOCAL_AXI` gates the Verilator-only local AXI slave, and `NPC_DEBUG=0` no longer preserves hidden debug/commit fanout through an `unused_debug` reduction.
   - Optimized result at 100 MHz: area `22755.600000` (-0.49%), worst core max path `1.799 ns`, slack `8.149 ns`, reported Fmax `540.333 MHz`, iEDA total power estimate `2.9042 W`.
   - Validation after optimization passed: `NPC_DEBUG=0 spec-smoke`, optimized physical synthesis/STA, and the debug-mode directed/DiffTest regression through access-fault tests.

3. **P8-S3: Closing P8** — complete on Linux.
   - Re-ran the current physical STA baseline and measured the P8-S2 top at `540 MHz` clean / `550 MHz` failing before the final cleanup.
   - Tried and rejected removing physical-mode register-file reset because it worsened timing to roughly `465 MHz` around the checked `580 MHz` target.
   - Kept the final low-risk physical-mode cleanup: `NPC_DEBUG=0` constant-drives hidden debug/commit outputs in `Core.v`, and `RegFile.v` constant-drives debug register outputs.
   - Final physical STA result: area `22685.320000`, sequential area `8001.840000`, worst path `1.583 ns`, reported Fmax `614.531 MHz`, clean checked target `610 MHz`, first failing checked target `620 MHz` with slack `-0.015 ns`.
   - Final validation passed: `NPC_DEBUG=0 spec-smoke`, debug-mode directed/DiffTest regression through access-fault tests, and optimized-core RT-Thread with NEMU event DiffTest through scripted shell `halt`.
   - Updated `notes/p8-timing-and-ppa.md` with timing/PPA command flow, result table, optimization before/after comparison, warnings, and lessons useful for future pipeline refactoring.

Exit criteria:

- `NPC_DEBUG=0` top-level interface is spec-compliant.
- `NPC_DEBUG=1` debug/DiffTest flow still works.
- Minimal spec-interface harness can run a small program and print UART output.
- Linux timing/PPA baseline is recorded, or a precise blocker is documented.
- At least one optimization is attempted and evaluated with before/after data, or explicitly deferred with measurement-backed evidence.
- `notes/p8-timing-and-ppa.md` explains the flow well enough to repeat after future pipeline refactoring.
- At least `hello`, representative `cpu-tests`, `coremark`, and `rt-thread-am` have recorded status.

## Phase 9: ysyxSoC Integration and AXI Validation

Goal: connect the NPC core to the ysyxSoC simulation environment and validate that the core correctly fetches instructions and performs load/store data accesses through the SoC AXI fabric. This closes the ysyxSoC connection that Phase 5 deliberately deferred. Scope is deliberately minimal: only the work required to test the AXI master interface — MROM instruction fetch, SRAM load/store, and UART16550 output for observability. PSRAM/SDRAM behavior models, flash XIP boot, SPI, GPIO/PS2/VGA, NVBoard, and ChipLink are out of scope.

Relevant lecture guidance:

- B2 (`specs/lecture-notes/03_B阶段讲义/02_B2.md`): ysyxSoC address map, the numbered connection steps, MROM/SRAM/UART16550 usage, `riscv32e-ysyxsoc` AM runtime, and DiffTest restoration with MROM/SRAM in NEMU.
- D6 (`specs/lecture-notes/05_D阶段讲义/06_D6.md`): CPU interface connection, UART16550 initialization/polling, `hello` bring-up.
- `ysyxSoC/spec/cpu-interface.md`: exact top-level port naming; already matched by `npc/rtl/NPC.v` (verified during planning).
- `specs/core.md`: top-level port tables, built-in CLINT (ysyxSoC has no CLINT; the core keeps its internal one), reset address `0x20000000` = MROM base.

Environment facts established during planning (macOS host):

- Java 17.0.19 and network access are available; `ysyxSoC/mill` wrapper exists (untracked) and `.mill-version` is 0.12.4.
- The ysyxSoC submodule is at `df38a4d9`, clean except the untracked `mill` wrapper; the `rocket-chip` submodule is uninitialized. `make dev-init` runs `git submodule update --init --recursive` and applies `patch/rocket-chip.patch` inside `rocket-chip`.
- `make verilog` may not work (it first runs `patch/update-firtool.sh`, which downloads a specific firtool). Use the user-provided command `./mill -i ysyxsoc.runMain ysyx.Elaborate --target-dir build`, then apply the same post-processing as `ysyxSoC/Makefile`: rename `build/ysyxSoCTop.sv` to `build/ysyxSoCFull.v` and run the two `sed` cleanups.
- `ysyxSoC/build/` is gitignored, so elaboration artifacts do not dirty the submodule.
- The generated SoC instantiates `ysyx_00000000 cpu (...)`; rename this module to `NPC` on a copy kept under our own build directory.
- `AXI4MROM` supports only single-beat reads, but the SoC inserts `AXI4Fragmenter` upstream of `xbar2` (MROM/SRAM/APB), so the icache's 16-byte INCR burst refill works unchanged. Writes to MROM trigger a fatal assertion in simulation; tests must never store to the MROM window.
- `perip/psram/psram.v` and `perip/sdram/sdram.v` are unimplemented stubs (buses tied to `z`); the `0x80000000` PSRAM and `0xa0000000` SDRAM windows must never be accessed.
- UART16550 prints characters via `$write` in `perip/uart16550/rtl/uart_tfifo.v`; without divisor initialization at most 16 characters are emitted, so AM `putch()` must initialize the divisor and poll LSR THRE.
- `ready-to-run/D-stage/ysyxSoCFull.v` has no MROM (D-stage boots from flash) and is not a valid fallback for our `0x20000000` reset PC.
- In the SoC simulation, UART output is printed by RTL `$write` straight to the simulator stdout; without debug ports the harness cannot observe retired `ebreak` or UART bytes, so precise termination and DiffTest require exposing the core's commit/debug signals at the SoC top level.

Scope decisions:

- Only validate the AXI master path: MROM instruction fetch (including icache burst refill), SRAM load/store (byte/halfword/word, `wstrb`, narrow transfers), and UART16550 MMIO stores for output. Do not implement PSRAM/SDRAM models, flash XIP, SPI, GPIO, PS/2, VGA, NVBoard, or ChipLink.
- Never commit inside the `ysyxSoC` submodule. Debug-signal changes to tracked ysyxSoC sources are kept as `ysyxSoC.patch` at the repository root (regenerate with `git -C ysyxSoC diff > ../ysyxSoC.patch`; fresh checkouts apply it with `git -C ysyxSoC apply ../ysyxSoC.patch`).
- Keep the existing local-AXI NPC flows (debug and spec modes) working; the SoC simulation is an additional build flavor, not a replacement.
- Reuse the existing harness philosophy: one command per experiment, structured result lines, cycle limits, concise output.

Sessions:

1. **P9-S1: ysyxSoC elaboration bring-up** — completed
   - Run `make -C ysyxSoC dev-init` (submodule plus `patch/rocket-chip.patch`) and elaborate with `cd ysyxSoC && ./mill -i ysyxsoc.runMain ysyx.Elaborate --target-dir build`.
   - Post-process per `ysyxSoC/Makefile` (rename to `build/ysyxSoCFull.v`, apply the two `sed` cleanups).
   - Verify the generated Verilog contains the MROM/SRAM/UART16550/APB fabric and the `ysyx_00000000` CPU instance, and record exact commands, Java/mill versions, and platform quirks in `notes/next.md`.
   - Exit when `ysyxSoC/build/ysyxSoCFull.v` is reproducibly generated; if elaboration fails irrecoverably, record the precise blocker instead of falling back to the MROM-less D-stage file.
   - Exit status: P9-S1 is complete on macOS; `dev-init` + plain mill elaboration + macOS-adapted sed post-processing produced a verified `ysyxSoC/build/ysyxSoCFull.v` (MROM/SRAM/UART16550/APB fabric and `ysyx_00000000 cpu` instance confirmed). Exact commands and BSD-sed adaptations are in `notes/next.md`.

2. **P9-S2: SoC Verilator harness and MROM/UART smoke** — completed
   - Add a SoC build flavor to the NPC flow (reuse `npc/csrc` with a SoC compile-time path, output under `npc/build/soc/`), compiling: all `ysyxSoC/perip/**/*.v`, include dirs `perip/uart16550/rtl` and `perip/spi/rtl`, Verilator flags `--timescale "1ns/1ns" --no-timing`, the elaborated `ysyxSoCFull.v` copied into our build dir with `ysyx_00000000` renamed to `NPC`, and the physical NPC RTL in `NPC_DEBUG=0` spec-port mode (no `NPC_LOCAL_AXI`).
   - The simulation top module is the generated SoC top; add `mrom_read()` (harness image loaded at `0x20000000`) and an `assert(0)` `flash_read()` DPI stub, plus `Verilated::commandArgs(argc, argv)`.
   - Zero-patch smoke tests, terminated by cycle limit with pass/fail from structured harness output and the RTL-printed UART bytes: a tiny MROM program that stores a marker character to UART16550 (validates both fetch and store paths in one go).
   - Exit when the smoke passes with one command.
   - Exit status: complete on macOS. `make -C npc soc-smoke` builds `npc/build/soc/npc-soc` (sim top `ysyxSoCTop`, harness `npc/csrc/soc_main.cpp`) and passes: the MROM program `npc/tests/make-soc-uart-bin.py` prints `SOC` through the UART16550. Key bring-up bug: ysyxSoC delays the CPU reset through a 10-stage `SynchronizerShiftReg` (`ysyxSoC/src/SoC.scala:62`), so the harness must hold reset >= 10 cycles (it uses 20); a 2-cycle reset re-appears as a spurious mid-run reset pulse that desyncs the AXI burst and deadlocks the fabric. Existing debug-mode and spec-mode regressions re-verified clean. Details in `notes/next.md`.

3. **P9-S3: Debug/commit exposure patch and DiffTest restoration**
   - Create `ysyxSoC.patch`: route the NPC `NPC_DEBUG=1` debug/commit observation signals (and `io_reset_pc`) through `src/CPU.scala`, `src/SoC.scala`, and `src/Top.scala` up to the SoC top-level ports; rebuild the SoC flavor with `NPC_DEBUG=1`.
   - Restore precise harness termination on retired `ebreak` and structured `NPC_RESULT` lines in the SoC sim.
   - Restore event DiffTest: add MROM (`0x20000000..0x20000fff`) and SRAM (`0x0f000000..0x0f001fff`) regions to NEMU, sync the MROM image into the REF at init, and verify the NPC-device UART window covers UART16550 register accesses (including LSR reads) for MMIO replay.
   - Document the patch apply/regenerate commands.
   - Exit when the P9-S2 smoke plus a small multi-line program (exercising icache burst refill) pass with precise termination and DiffTest enabled.

4. **P9-S4: SRAM load/store validation (mem-test style)**
   - Add a generated mem-test program (same style as existing `npc/tests/make-*.py` generators) running from MROM with its stack in SRAM: fill and verify the 8KB SRAM window with byte/halfword/word stores and loads, print a short PASS/FAIL marker through UART16550, and terminate via `ebreak`.
   - Cover `wstrb` behavior, narrow transfers, and repeated read-after-write patterns; run with DiffTest.
   - Exit when the mem-test passes on the SoC sim and the existing directed NPC regressions still pass.

5. **P9-S5: AM `riscv32e-ysyxsoc` runtime and `hello`/`dummy` on SoC**
   - Add a minimal AM platform: linker script (text/rodata in MROM, data/stack/heap in SRAM), startup, `putch()` with UART16550 divisor init and LSR THRE polling, `halt()` via `ebreak`, and a one-command run path.
   - Run `cpu-tests/dummy` and `hello` on the SoC sim with DiffTest.
   - Stretch (not required for phase exit): data-segment bootloader (VMA/LMA copy) enabling cpu-tests with writable globals.
   - Exit when `dummy` and `hello` pass with correct UART output.

6. **P9-S6: Phase 9 regression and closeout**
   - Re-run the full existing regression (NPC directed tests, 35 cpu-tests with DiffTest, `hello`, CTE smokes, RT-Thread smoke) to prove the SoC work did not regress local flows.
   - Record exact SoC commands/results, known limitations (PSRAM/SDRAM stub windows, no flash XIP, no GPIO/PS2/VGA), and the patch workflow in `notes/next.md`; update `npc/README.md` for the new build flavor.
   - Exit when a new session can reproduce the SoC integration from notes alone.

Exit criteria:

- ysyxSoC elaborates reproducibly from source with documented commands, and the generated SoC with the renamed NPC instance simulates under Verilator.
- The core fetches instructions from MROM at `0x20000000` through the SoC AXI fabric, including 16-byte icache burst refills.
- Stores to UART16550 MMIO produce visible output, and byte/halfword/word loads/stores to the 8KB SRAM verify correctly under a mem-test.
- `ysyxSoC.patch` at the repo root exposes commit/debug signals for precise `ebreak` termination and DiffTest; no changes are committed inside the ysyxSoC submodule.
- AM `riscv32e-ysyxsoc` runs `dummy` and `hello` on the SoC sim.
- All pre-existing NPC/NEMU regressions still pass.

## Phase 10: Optional Pipeline and Targeted Optimizations

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

## Phase 11: Final Integration and Documentation

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
