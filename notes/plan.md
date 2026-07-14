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
   - Add an NPC command shell with `load`, `reset`, `step`, `run`, `run to`, `run until reg`, `print`, `dump state`, `last`, `log`, and `trace` basics.
   - Keep passing output concise and dump bounded recent events/registers on failure.
   - Exit when NEMU script mode, NPC shell runs, and event-based DiffTest tiny tests pass.

8. **P2-S7: Minimal AM `riscv32e-npc` run path**
   - Inspect existing AM support and add only the missing pieces needed for one-command NPC runs.
   - Provide a `run` target for `ARCH=riscv32e-npc` that invokes the NPC simulator with the built image and a limit.
   - Implement or adjust AM `halt()` for NPC so it uses `ebreak` and passes the result code to the harness.
   - Start with `dummy`; do not broaden to all cpu-tests in this phase unless the tiny core already supports the required instructions.
   - Exit when an AM `dummy`-style workload can be built and run on NPC with automatic GOOD/BAD reporting, or when the remaining blocker is narrowed to missing Phase 3 ISA coverage.

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

Goal: implement the full functional ISA subset required by `specs/core.md` before performance work.

Relevant lecture guidance:

- C2 RV32E implementation.
- C5 CSR and exception handling.
- RISC-V manual via lecture references.

Tasks:

1. Implement RV32E GPR behavior with 16 registers and x0 hardwired to zero.
2. Implement RV32E integer instruction classes needed by compiled workloads:
   - U/J/B/I/R/S formats
   - ALU, compare, shift, branches, jumps, loads, stores
   - `fence` as nop
   - `fence.i` initially as architectural hook, later tied to icache clear
3. Complete Zicsr instructions and only the required CSRs; the minimal `ecall`/`mret` trap path should already exist from Phase 2 if AM workload bring-up needed it.
4. Complete exception entry behavior for:
   - instruction/load/store address misaligned
   - instruction/load/store access fault
   - illegal instruction
   - breakpoint
   - ecall from M-mode
5. Complete `mret`; implement `wfi` as nop.
6. Ensure unimplemented CSRs and illegal encodings raise illegal-instruction exception.
7. Add alignment and access-fault plumbing from memory/bus responses.
8. Integrate DiffTest against NEMU, comparing PC, GPRs, and implemented CSRs at instruction retirement.
9. Run `cpu-tests` progressively and fix instruction bugs before adding more architecture.

Exit criteria:

- RV32E-targeted `cpu-tests` pass on NPC with DiffTest enabled.
- CSR/trap tests for required behavior pass or are documented if not yet available.

## Phase 4: AM Runtime and Essential Workloads

Goal: make normal bare-metal workloads build and run on NPC through AM.

Relevant lecture guidance:

- D4 AM runtime for NPC.
- C2 `riscv32e-npc` AM support.
- D5 UART/timer basics.
- C5 RT-Thread support.

Tasks:

1. Complete/verify `riscv32e-npc` AM target support.
2. Provide `make ... run` style one-command build-and-run flow for NPC.
3. Implement `halt()` using `ebreak` and pass result code to the harness.
4. Add simple UART output at `0x10000000` in the simulation environment first.
5. Add CLINT/timer simulation compatible with later RTL CLINT behavior.
6. Run and validate:
   - `dummy`
   - `hello`
   - broader `cpu-tests`
   - `am-tests` timer test
7. Implement enough CTE/trap behavior to run `rt-thread-am` under M-mode-only assumptions.
8. Keep unsupported PA OS/application features out of scope.

Exit criteria:

- `hello` prints through UART.
- timer test works.
- `rt-thread-am` reaches its expected prompt or documented milestone.

## Phase 5: System Bus and AXI4 Integration

Goal: replace ideal DPI memory assumptions with bus-oriented memory/device access matching the top-level spec.

Relevant lecture guidance:

- B1 bus, SimpleBus, AXI4-Lite/AXI concepts.
- D6 ysyxSoC connection cautions.
- `specs/core.md` top module AXI master/slave ports.

Tasks:

1. Refactor IFU/LSU around valid/ready-style request/response interfaces if not already done.
2. Add a simple internal bus abstraction that can evolve from simulation memory to AXI master.
3. Implement aligned little-endian memory accesses; raise misaligned exceptions on unaligned accesses.
4. Implement AXI master channels with 32-bit data width and required response handling.
5. Hardwire reserved AXI slave outputs to zero and ignore reserved inputs.
6. Map built-in CLINT internally at configurable range, default `0x02000000..0x0200ffff`.
7. Route normal memory/device transactions through AXI master, while CLINT is handled as specified.
8. Treat AXI `SLVERR`/`DECERR` as access faults.
9. Add tests with deterministic and delayed memory responses to validate handshakes.

Exit criteria:

- Core can run previous tests through bus/AXI-facing memory model.
- Misalignment and bus error exceptions are tested.
- Top-level ports match `specs/core.md`.

## Phase 6: Built-in CLINT, UART Path, and RT-Thread Stability

Goal: solidify required runtime devices and OS-level workload behavior.

Relevant lecture guidance:

- D5 NPC I/O.
- C5 RT-Thread.
- B1 AXI CLINT notes, adapted to built-in CLINT requirement.

Tasks:

1. Implement CLINT `mtime`/`mtimeh` incrementing once per core cycle.
2. Ignore writes/reads to `mtimecmp`, `mtimecmph`, `msip` as specified: no effect, no error, read undefined.
3. Update AM timer code if needed to read `mtime`/`mtimeh` robustly as 64-bit time.
4. Keep interrupt behavior disabled; do not generate timer interrupts.
5. Keep UART support in simulation/SoC path sufficient for `hello` and RT-Thread console output.
6. Re-run `hello`, timer test, and `rt-thread-am` after bus/CLINT integration.

Exit criteria:

- CLINT behavior matches `specs/core.md`.
- Essential UART/timer workloads still pass.

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
