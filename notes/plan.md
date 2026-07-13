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

Goal: make the software reference stack capable of compiling, running, and checking basic RV32 workloads in automated mode.

Relevant lecture guidance:

- PA1 simple debugger and expression/watchpoint infrastructure.
- PA2 instruction execution, AM runtime, tracing, IOE, DiffTest.
- PA3 trap handling for `ecall`/CTE concepts.
- NEMU ISA API reference.

Tasks:

1. Build and run existing NEMU for riscv32; document exact commands.
2. Ensure NEMU supports enough RV32 behavior to act as DiffTest REF for RV32E programs.
3. Add/verify batch-friendly run mode: load image, execute to trap/event, emit concise structured result.
4. Add/verify essential traces with filters:
   - itrace / ring buffer for failing windows
   - mtrace for memory problems
   - optional ftrace when ELF symbols are available
5. Implement/refine DiffTest REF APIs if missing: memory copy, register copy, execution step, CSR state needed by NPC comparison.
6. Ensure AM workloads can build for `riscv32-nemu` and later `riscv32e-npc`.
7. Validate with `dummy`, representative `cpu-tests`, and `hello`.

Exit criteria:

- NEMU can run selected tests non-interactively and report pass/fail.
- NEMU shared-object REF is buildable for NPC DiffTest.
- Commands and caveats are recorded in notes.

## Phase 2: Initial NPC RTL and Simulation Harness

Goal: create a minimal, maintainable RTL core and Verilator harness that can execute tiny programs to `ebreak`.

Relevant lecture guidance:

- D4 modular RTL minirv processor.
- C2 RV32E single-cycle NPC infrastructure.

Tasks:

1. Establish `npc/` project structure if absent.
2. Choose RTL implementation style based on existing repository/tooling; prefer simple, explicit modules.
3. Build a Verilator harness with:
   - program image loading
   - cycle limit
   - `ebreak`/trap based termination
   - HIT GOOD/BAD style result
   - optional waveform switch
4. Implement a minimal datapath first: PC, register file, instruction fetch, decode, ALU, writeback.
5. Start with a tiny subset (`addi`, `jalr`, `ebreak`) only to validate the harness.
6. Add DPI-C or equivalent simulation hooks for memory access and trap reporting.
7. Keep reset address configurable; default toward `0x20000000` per `specs/core.md`, while allowing test/SoC-specific overrides.

Exit criteria:

- A small hand-built program executes and stops via `ebreak`.
- Simulation result is machine-readable enough for automated checking.

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
3. Implement Zicsr instructions and only the required CSRs.
4. Implement exception entry behavior for:
   - instruction/load/store address misaligned
   - instruction/load/store access fault
   - illegal instruction
   - breakpoint
   - ecall from M-mode
5. Implement `mret`; implement `wfi` as nop.
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
