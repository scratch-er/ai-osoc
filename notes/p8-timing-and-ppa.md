# Phase 8 Timing and PPA Notes

This note records the Linux-only P8-S2 synthesis/STA/performance baseline and the small targeted optimization attempted in this session.

## Scope

STA and PPA measurements here target the SoC-connectable physical top, not the Verilator-only local-memory harness:

- Top: `npc/rtl/NPC.v`
- Mode: `NPC_DEBUG=0` / no `+define+NPC_DEBUG`
- Physical RTL list excludes `npc/rtl/bus/LocalAxiSlave.v` and `npc/rtl/bus/MemIf.v`.
- `NPC_LOCAL_AXI` is only defined for Verilator simulation through `npc/Makefile`; it is not used by the PPA synthesis command.
- Clock port: `clock`
- Frequency target used for these first measurements: `100 MHz`
- PDK: `icsprout55`

The current `yosys-sta/scripts/yosys.tcl` was adjusted to accept `VERILOG_INCLUDE_DIRS` so project RTL includes such as `include/npc_defines.vh` can be found without rewriting RTL include paths.

## Tool versions

Observed during P8-S2 on Linux:

```text
Yosys 0.67 (git sha1 2d1509d1b, RelWithDebInfo, GNU /usr/bin/g++ 15.3.0)
iEDA from /home/venti/.nix-profile/bin/iEDA
```

The older Yosys 0.45 on this host did not provide the `clockgate` command used by `yosys-sta/scripts/yosys.tcl`; the user upgraded Yosys and the flow then ran successfully.

## Physical synthesis and STA command

`npc/Makefile` now wraps the physical `yosys-sta` flow. The target keeps the STA RTL list explicit so synthesis uses the SoC-connectable `NPC_DEBUG=0` core and excludes the Verilator-only local-memory harness.

Single frequency:

```sh
make -C npc sta \
  STA_O=../build/p8-s2-ppa/npc-sta \
  CLK_FREQ_MHZ=540
```

Frequency sweep:

```sh
make -C npc sta-sweep \
  STA_O=../build/p8-s2-ppa/npc-sta-sweep \
  STA_FREQS="100 300 500 530 540 550 560 600 700"
```

Important Makefile parameters:

- `YOSYS_STA_DIR`: default `../yosys-sta`
- `STA_PDK`: default `icsprout55`
- `CLK_FREQ_MHZ`: single-run target frequency
- `STA_O`: output root
- `STA_FREQS`: space-separated sweep target frequencies

## STA frequency sweep

The current optimized physical top was swept with `icsprout55` at `build/p8-s2-ppa/npc-sta-sweep/`.

| Target MHz | Worst setup slack | Path delay | Required | Reported Fmax | Worst endpoint |
| ---: | ---: | ---: | ---: | ---: | --- |
| 100 | 8.149 ns | 1.799 ns | 9.948 ns | 540.333 MHz | `u_core.u_regfile.regs[7]_29__reg_p:D` |
| 300 | 1.482 ns | 1.799 ns | 3.281 ns | 540.333 MHz | `u_core.u_regfile.regs[7]_29__reg_p:D` |
| 500 | 0.149 ns | 1.799 ns | 1.948 ns | 540.333 MHz | `u_core.u_regfile.regs[7]_29__reg_p:D` |
| 530 | 0.035 ns | 1.799 ns | 1.834 ns | 540.333 MHz | `u_core.u_regfile.regs[7]_29__reg_p:D` |
| 540 | 0.000 ns | 1.799 ns | 1.799 ns | 540.333 MHz | `u_core.u_regfile.regs[7]_29__reg_p:D` |
| 550 | -0.033 ns | 1.799 ns | 1.766 ns | 540.333 MHz | `u_core.u_regfile.regs[7]_29__reg_p:D` |
| 560 | -0.066 ns | 1.799 ns | 1.733 ns | 540.333 MHz | `u_core.u_regfile.regs[7]_29__reg_p:D` |
| 600 | -0.185 ns | 1.799 ns | 1.614 ns | 540.333 MHz | `u_core.u_regfile.regs[7]_29__reg_p:D` |
| 700 | -0.423 ns | 1.799 ns | 1.376 ns | 540.333 MHz | `u_core.u_regfile.regs[7]_29__reg_p:D` |

The current clean passing target is `540 MHz`; `550 MHz` fails setup by about `33 ps`. The report's Fmax estimate is stable at `540.333 MHz` across the sweep.

Synthesis result for the swept optimized top:

```text
synth_check: Found and reported 0 problems.
Chip area: 22755.600000
Sequential area: 8001.840000 (35.16%)
DFFQX1H7L: 1299
ICGX0P5H7L: 15
```

Worst setup path at `700 MHz` starts from a synthesized register related to `commit_inst_17__reg_p_D_DFFQX1H7L_D` and ends at `u_core.u_regfile.regs[7]_29__reg_p:D`. The data path is mostly mux/buffer/control logic feeding the register-file write port; the report includes generated net names containing `commit_*` and `debug_*` because they originate from internal observation wires, but Yosys removed many unused observation wires during optimization. The remaining critical endpoint is still a real physical register-file write flop.

The iEDA power report uses `report_power -toggle 0.1` and reported zero switch power for many unloaded top-level SoC interface nets. Treat the power number as an early relative estimate, not signoff power.

## Performance baseline

Performance baseline was run with the debug/DiffTest simulator (`NPC_DEBUG=1`) so the existing stable `NPC_RESULT`, `NPC_ICACHE`, and `NEMU_RESULT` lines can be used.

Build/reset command used before runs:

```sh
ROOT=/host/Workspace/ai-ysyx
REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so"
make -C "$ROOT/npc" clean
make -C "$ROOT/npc" REF_SO="$REF"
```

Representative workload results:

| Workload | Status | Cycles | Insts | Hit rate | AMAT x1000 | Notes |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `hello` | good trap | 2116 | 465 | 638 | 3167 | Printed `Hello, AbstractMachine!` |
| `cpu-tests/sum` | good trap | 1532 | 528 | 979 | 1125 | DiffTest good |
| `cpu-tests/string` | good trap | 4260 | 1449 | 951 | 1289 | DiffTest good |
| `cpu-tests/crc32` | good trap | 67892 | 18163 | 740 | 2557 | DiffTest good |
| `cpu-tests/quick-sort` | good trap | 11854 | 3041 | 758 | 2446 | DiffTest good |
| `cpu-tests/matrix-mul` | good trap | 543774 | 131726 | 660 | 3034 | DiffTest good |
| `coremark` default | bounded | 120000000 | 37471468 | 845 | 1924 | Default `ITERATIONS=1000`; did not finish within 120M cycles |
| `rt-thread-am` | good trap | 1816964 | 511842 | 838 | 1971 | Reached scripted shell `halt` |

CoreMark caveat: `am-kernels/benchmarks/coremark/include/core_portme.h` hard-defines `ITERATIONS 1000`, so command-line attempts with `XCFLAGS=-DITERATIONS=1` or `CFLAGS+=-DITERATIONS=1` did not produce a terminating short run without modifying benchmark sources. Because `am-kernels/` should not be modified unless explicitly requested, P8-S2 records the bounded default CoreMark run as the baseline.

## Targeted optimization

Observation: after P8-S1, spec mode hid debug/commit ports from the top-level, but `npc/rtl/NPC.v` still reduced all internal `debug_*`/`commit_*` wires into `unused_debug` under `NPC_DEBUG=0`. That forced logic related to debug/commit observations to remain live in the physical spec-mode netlist.

Change made:

- `npc/rtl/NPC.v`: removed the `unused_debug` reduction in `NPC_DEBUG=0`; wrapped those internal wires with Verilator `UNUSED` lint pragmas instead.
- `npc/rtl/NPC.v`: wrapped `LocalAxiSlave` wires, muxing, and instance in `NPC_LOCAL_AXI` so the Verilator-only local AXI simulation slave is not part of the physical SoC synthesis target.
- `npc/Makefile`: passes `+define+NPC_LOCAL_AXI` to Verilator builds so existing simulation behavior is unchanged.

Optimized synthesis command used the same physical RTL list and output root `build/p8-s2-ppa/opt-no-debug-reduce`.

Optimized synthesis result:

```text
Cells: 9397
Chip area: 22755.600000
Sequential area: 8001.840000 (35.16%)
DFFQX1H7L: 1299
ICGX0P5H7L: 15
```

Comparison:

| Metric | Baseline | Optimized | Delta |
| --- | ---: | ---: | ---: |
| Cells | 9311 | 9397 | +86 |
| Area | 22867.040000 | 22755.600000 | -111.440000 (-0.49%) |
| Sequential area | 8001.840000 | 8001.840000 | 0 |
| Worst core path delay | 1.619 ns | 1.799 ns | +0.180 ns |
| Worst core slack @ 100 MHz | 8.334 ns | 8.149 ns | -0.185 ns |
| Reported core Fmax | 600.118 MHz | 540.333 MHz | -59.785 MHz |
| iEDA total power estimate | 3.65956 W | 2.9042 W | -0.75536 W |

Interpretation: this is a small area/power cleanup for spec-mode physical synthesis, with still-large positive timing slack at 100 MHz but a lower reported maximum-frequency estimate. The cleanup is worth keeping because it removes non-physical Verilator-only local AXI logic from synthesis and avoids preserving spec-mode debug fanout that cannot connect to the SoC top.

## Validation after optimization

1. Spec-mode smoke:

```sh
make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke
```

Result: passed. Output included `SPEC` and `NPC_SPEC_RESULT status=good reason=uart_eot cycles=61 limit=400`.

2. Physical optimized synthesis/STA:

```sh
VERILOG_INCLUDE_DIRS="$ROOT/npc/rtl" make -C "$ROOT/yosys-sta" syn ... O="$ROOT/build/p8-s2-ppa/opt-no-debug-reduce" CLK_FREQ_MHZ=100
make -C yosys-sta sta DESIGN=NPC PDK=icsprout55 O=/host/Workspace/ai-ysyx/build/p8-s2-ppa/opt-no-debug-reduce CLK_PORT_NAME=clock CLK_FREQ_MHZ=100
```

Result: synthesis and STA completed.

3. Debug-mode directed regression:

```sh
make -C npc clean && make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest \
  test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

Result: passed. Representative checks included `test-clint`, `test-icache`, `test-fencei`, and all access-fault subtests with NEMU event DiffTest.

## Remaining caveats for P8-S3

- The baseline and optimized STA use a simple SDC that only creates the core clock. No input/output delays are modeled for the SoC AXI boundary yet.
- iEDA reports many no-driver/no-load messages for top-level SoC-facing ports because this is a standalone core-top STA, not full SoC STA.
- CoreMark default run is bounded rather than terminating due to `ITERATIONS=1000`; do not modify `am-kernels/` unless the user explicitly requests it.
- P8-S3 should run the final practical regression and update this note if more optimization is attempted.
