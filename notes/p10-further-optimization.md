# Phase 10 Further Optimization Opportunities

Date: 2026-07-19
Platform: Linux
Starting point: P10-S9 4-stage F/D/X/W pipeline

## Current state

After the P10-S9 4-stage refactor the core is functionally correct and has better raw timing/area than P10-S8:

| Metric | Value |
| --- | ---: |
| Area | `22122.240000` |
| DFFs | `1629` |
| ICGs | `19` |
| Clean STA target | `770 MHz` |
| First failing STA target | `780 MHz` |
| Worst path delay | `1.243 ns` |
| Worst endpoint | `u_core.f_pc_27__reg_p:D` |

All validation passed: spec smoke, directed debug/DiffTest regression, 35 `cpu-tests`, RT-Thread scripted `halt`, SoC regression.

CPI regressed for small programs but wall-clock improved for large programs because of the frequency gain:

| Workload | P10-S8 cycles | P10-S9 cycles | Δ wall-clock @ 770 MHz vs 680 MHz |
| --- | ---: | ---: | ---: |
| `cpu-tests/sum` | 1434 | 1640 | +1.0% |
| `cpu-tests/string` | 4069 | 4541 | −1.7% |
| `cpu-tests/matrix-mul` | 564293 | 570451 | −10.7% |
| `cpu-tests/crc32` | 66820 | 68459 | −8.6% |
| `cpu-tests/quick-sort` | 11859 | 12547 | −5.9% |
| RT-Thread | 1807800 | 1955726 | −4.4% |

## Why the current critical path is what it is

The 4-stage design resolves branches, jumps, and `mret` in the **X stage**. The taken target must update `f_pc` in the same cycle so the next fetch goes to the right place. That creates a combinational path:

```
D/X register (operand/imm/pc/control)
  → shared-adder input mux
  → 32-bit adder (or subtractor)
  → target mux (mepc / jalr / jal / branch)
  → f_pc register
```

This path is **1.243 ns**, i.e. almost the entire 770 MHz cycle budget. The old X→C ALU path is no longer the bottleneck because the register-file read was moved into D.

The X→F redirect path is structurally unavoidable in any pipeline where:
- branch resolution happens in X, and
- fetch must be redirected in the same cycle.

To push frequency further, that path must be broken.

## Candidate optimizations

### 1. Branch target buffer / next-PC predictor (highest timing impact)

**Idea**: predict the next PC one cycle earlier and compare/update in X only on mispredict.

Implementation sketch:
- Add a small direct-mapped BTB indexed by `fd_pc`.
- Each entry stores a target PC and a valid bit.
- In the F/D stage, look up the BTB with `fd_pc`.
- If hit, use the predicted target as `f_pc_next` for sequential fetch.
- In X stage, when the actual branch/jump target is computed, compare it with the prediction.
- On mispredict, redirect fetch and flush D/X.
- On correct prediction, no redirect is needed; the target was already being fetched.

**Why it helps timing**: the X→F combinational redirect path disappears. `f_pc` can be updated from a registered BTB output or from a simple incrementer. The X-stage adder/comparator only needs to run in time for the **mispredict check**, which can be done later in the cycle because the predicted instruction is already being fetched.

**CPI impact**: correct predictions give zero branch penalty. Mispredictions cost the same 1-cycle penalty as today. For mostly-straight-line or loop code this is a large CPI win.

**Area impact**: a small BTB (e.g. 16 entries × 32 bits = 512 flops) plus tag/comparator logic. Significant area increase.

**Risk**: adds complexity; must be validated with DiffTest because the architectural state is unchanged but the microarchitectural timing changes.

### 2. Resolve branches in D instead of X (alternative timing path)

**Idea**: move the branch comparator into the D stage and redirect from D.

Implementation sketch:
- In D, after register-file read and forwarding, compute `branch_taken`.
- Flush F/D and update `f_pc` from D.
- The X stage no longer handles branch redirect.

**Why it helps timing**: the critical path becomes D→F, which is register-file read + comparator + target mux, but it no longer includes the 32-bit adder (the target can be computed in D with a separate adder or with the ALU-style shared adder, but it sits on the D→F path).

**CPI impact**: branches now have a 1-cycle penalty (flush F). Same as today.

**Area impact**: need a branch adder in D plus forwarding from X to D for branch operands. X→D forwarding creates a combinational path X register → ALU → forwarding mux → D comparator, which may re-create a long path unless stalled.

**Verdict**: less attractive than a BTB because it moves rather than removes the bottleneck, and it complicates forwarding.

### 3. Accept 2-cycle branch penalty and resolve in W

**Idea**: move all redirect (branches/jumps/traps) to W. This is what the original 3-stage did.

**Why it helps timing**: the X→F path disappears entirely. X only computes ALU/LSU/CSR. W computes redirect and flushes F/D/X.

**CPI impact**: every taken branch costs 2 cycles (flush D and X). This is likely worse than the current CPI regression for small programs.

**Verdict**: probably not worth it unless frequency gain is very large and workloads are dominated by large straight-line regions.

### 4. Fetch buffer / prefetch (CPI impact)

**Idea**: add a small FIFO or single-entry buffer after the IFU so the F stage can capture an instruction even when D is stalled.

**Why it helps CPI**: reduces bubbles caused by D/X stalls and refill latency.

**Timing impact**: minimal; the buffer is between IFU and F/D.

**Area impact**: small (32-bit instruction + valid bit).

**Verdict**: low risk, modest CPI gain. Good as a follow-up after the timing bottleneck is addressed.

### 5. Fairer IFU/LSU arbitration (CPI impact)

**Idea**: currently the AXI arbiter gives LSU priority over IFU (`lsu_ready` asserted whenever LSU is valid). This can starve instruction fetch on cache misses when the program does frequent memory operations.

**Why it helps CPI**: better AMAT, fewer fetch stalls.

**Timing/area impact**: small.

**Verdict**: worth measuring after timing is satisfactory.

### 6. X/W packet specialization (area impact)

**Idea**: store only the data actually needed in W:
- `xw_rs1_data` is only needed for CSR commit. Pre-compute `xw_csr_wdata` in X and drop `xw_rs1_data`.
- `xw_rs2_data` is only needed for store data. Could be gated but not easily removed.
- `xw_csr_rdata` is only needed for CSR writeback. Could pre-compute the final CSR writeback value in X for some instructions, but CSRRW needs both old and new CSR values.

**Why it helps area**: removes ~32–64 flops.

**Timing impact**: may add combinational logic in X. Must not touch the X→F redirect path.

**Verdict**: small area win; measure carefully.

### 7. Share the shifter or logic unit (area impact)

**Idea**: the Exu still has a dedicated barrel shifter and separate logic ops. For RV32E, shift amount is only 5 bits. A shared shift/logic unit might save area.

**Why it helps area**: fewer gates.

**Timing impact**: could lengthen the X stage ALU path, but the current bottleneck is X→F redirect, not the ALU path.

**Verdict**: possible after confirming ALU path slack.

## Recommended next experiment

If continuing optimization, start with **candidate 1 (BTB / next-PC prediction)** because it is the only option that directly breaks the current timing bottleneck while also improving CPI.

A minimal first cut:
- 16-entry direct-mapped BTB, no tag (just index by `fd_pc[5:2]`), stores 32-bit target + valid.
- Predict taken for every branch/jump in the BTB; do not predict conditional branches not in BTB.
- On X-stage redirect, update the BTB with the resolved target.
- Mispredict penalty = 1 cycle (same as today).
- Validate with the same regression suite.
- Measure STA at 800 MHz+ and CPI on `cpu-tests` + RT-Thread.

If the BTB adds too much area, reduce to 8 entries or use a simpler return-address stack for jalr only.

## Validation commands to reproduce

Build and single-frequency STA:
```sh
make -C npc clean
make -C npc NPC_DEBUG=0 spec-smoke
make -C npc sta STA_O=../build/p10-4stage/check CLK_FREQ_MHZ=770
```

Frequency sweep:
```sh
make -C npc sta-sweep \
  STA_O=../build/p10-4stage/ppa \
  STA_LOG_DIR=../build/p10-4stage/logs \
  STA_FREQS="700 750 760 770 780 790 800"
```

Directed regression:
```sh
make -C npc clean && make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest \
  test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

Full cpu-tests sweep:
```sh
ROOT=/host/Workspace/ai-ysyx
TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so"
mkdir -p build/p10-cpu-tests
for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
  tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
  printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
  make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" \
    CROSS_COMPILE=riscv64-linux-gnu- NPC_MAX_CYCLES=8000000 NPC_DIFFTEST_REF="$REF" run \
    >"build/p10-cpu-tests/$t.log" 2>&1
  status=$?
  rm -f "$tmp"
  result=$(grep 'NPC_RESULT' "build/p10-cpu-tests/$t.log" | tail -1)
  echo "EXIT=$status $t | $result"
done
```

RT-Thread:
```sh
make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
  AM_HOME=/host/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-linux-gnu- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

SoC regression:
```sh
make -C npc soc-smoke test-soc-difftest test-soc-mem \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

## Static prediction attempt (rejected by measurement)

The first candidate after this note was deliberately changed from BTB to **static prediction only** after user review, because a BTB costs too much area for this design point.

Implementation attempted in `npc/rtl/core/Core.v`:

- Predict backward conditional branches and `jal` in D using `fd_pc + imm_b/imm_j`.
- Carry `dx_pred_taken`/`dx_pred_pc` to X.
- Remove the direct X-stage `x_redirect_pc -> f_pc` update and instead register mispredict/dynamic redirects into X/W for W-stage redirect.
- Keep `jalr` and `mret` as dynamically resolved late redirects.

Why this was tried:

- It directly targets the measured P10-S9 bottleneck (`D/X -> shared adder -> f_pc`) without BTB storage.
- It uses no predictor table and only adds a D-stage target adder plus a few flops.

Validation results before reverting:

- `make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke`: passed with `NPC_SPEC_RESULT status=good reason=uart_eot cycles=63 limit=400`.
- Directed debug/DiffTest regression initially exposed only a debug `commit_next_pc` mismatch for `jal`; after fixing debug commit reporting, all directed tests passed.
- Full 35 `cpu-tests` with NEMU DiffTest passed. Representative cycles:
  - `sum`: `1542` cycles (P10-S9 was `1640`, better CPI)
  - `string`: `4341` cycles (P10-S9 was `4541`, better CPI)
  - `matrix-mul`: `568184` cycles (P10-S9 was `570451`, slightly better CPI)
  - `crc32`: `68186` cycles (P10-S9 was `68459`, slightly better CPI)
  - `quick-sort`: `12515` cycles (P10-S9 was `12547`, slightly better CPI)
- RT-Thread scripted `halt` passed with `NPC_RESULT status=good reason=good_trap cycles=1988529 insts=511842`; this is worse than P10-S9 (`1955726`) because static prediction increased icache misses/AMAT on that workload.

PPA results were bad:

- Static-prediction netlist area at `build/p10-static-predict/ppa/NPC-770MHz/synth_stat.txt`: `23782.640000`, DFFs `1694`, ICGs `19`.
- This is `+1660.400000` area and `+65` DFFs versus P10-S9 (`22122.240000`, `1629` DFFs).
- STA at `770 MHz` failed badly: worst endpoint `u_core.f_pc_28__reg_p:D`, path delay `1.655 ns`, slack `-0.403 ns`, reported Fmax about `587.971 MHz`.
- The new bottleneck became D-stage static target generation/control into `f_pc` and `dx_pred_pc`, so the attempt merely moved the long PC-target path earlier and made it worse.
- The `sta-sweep` wrapper also hit an iEDA report-copy permission abort after generating reports; the reports themselves were usable.

Decision:

- Reverted `npc/rtl/core/Core.v` back to the accepted P10-S9 baseline (`809d40d` content), because the attempt was functionally correct but failed the PPA goal.
- Clean baseline spec smoke after revert passed: `NPC_SPEC_RESULT status=good reason=uart_eot cycles=63 limit=400`.

Conclusion:

- Static prediction without a target buffer is not a good timing optimization for this 4-stage RTL. It needs a D-stage target adder feeding `f_pc`, which synthesizes slower than the original X-stage redirect path.
- The result confirms that the problem is not just branch decision timing; target generation plus the `f_pc` mux is the real issue.
- Do not retry this exact static-prediction structure.

## Decision criteria for next session

Keep the P10-S9 4-stage point if:
- Clean STA target ≥ 770 MHz is acceptable, and
- RT-Thread wall-clock is acceptable (currently −4.4% vs P10-S8).

Avoid BTB unless the user explicitly accepts the area cost.

Avoid the rejected static-prediction design above; it improved some `cpu-tests` cycle counts but regressed area and timing severely.

Revert to P10-S8 only if:
- The CPI regression for small programs is unacceptable, and
- The user prefers the lower-frequency but lower-CPI 3-stage point.
