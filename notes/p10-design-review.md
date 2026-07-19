# Phase 10 Design Review — Module-by-Module Hardware Mapping

Date: 2026-07-19
Platform: Linux
Starting point: P10-S5 optimized pipeline point (area `24124.52`, Fmax `579.331 MHz`, clean `570 MHz`)

This note records a deliberate, module-by-module review of the current NPC RTL. The goal is to stop report-driven random edits and instead understand what each RTL construct becomes in silicon, where the structural inefficiencies are, and which architectural decisions are worth keeping or changing.

## 1. Current pipeline architecture

The core is a 3-stage elastic in-order pipeline: **F (fetch) / X (execute) / C (commit)**.

- **F stage**: `f_pc`, `ifu_pending`, `drop_fetch_response` plus the `Ifu` cache state machine.
- **F/X boundary**: `fx_valid`, `fx_pc`, `fx_inst`, `fx_inst_error`.
- **X stage**: combinational decode (`Idu`), register-file read (`RegFile`), operand forwarding, ALU (`Exu`), branch comparison, next-PC selection, LSU address generation, CSR read (`Csr`).
- **X/C boundary**: `xc_valid` plus a large packet of registered control/data (`xc_pc`, `xc_alu_result`, `xc_normal_next_pc`, `xc_lsu_addr`, `xc_csr_rdata`, `xc_rs1/rs2_data`, etc.).
- **C stage**: LSU/CLINT/AXI request, writeback mux, trap handling, CSR commit, register-file write.

Key timing path measured by STA (P10-S5): **F/X instruction register → decode (rs1/rs2 extraction) → register-file read address/mux → operand-forwarding mux → branch comparator → `xc_normal_next_pc` register**. The regfile read alone costs ~0.77 ns; the branch/ALU computation adds another ~0.59–1.0 ns.

---

## 2. Module-by-module hardware mapping

### 2.1 `Ifu.v` — instruction fetch unit

**What it really is**: a direct-mapped 2-set, 4-word-per-line icache with a one-hot valid bit per set, 27-bit tags, and a refill state machine.

**Hardware actually instantiated**:
- Storage: `valid_q[1:0]`, `tag0_q/tag1_q[26:0]`, eight 32-bit data registers (`data0_0..3`, `data1_0..3`). Total cache data storage: 2 sets × 4 words × 32 bits = 256 bits of flops, plus 54 tag bits + 2 valid bits.
- Refill state: `state`, `miss_index_q`, `miss_offset_q`, `miss_tag_q`, `miss_line_addr_q`, `refill_beat_q`, four `refill_word*_q` registers (128 bits), `refill_error_q`.
- Performance counters: five 64-bit counters wrapped in `NPC_DEBUG`; they are physically removed in `NPC_DEBUG=0` after the P10-S3 area-counter-gate change.

**Structural observations**:
1. The cache is extremely small (256 bits data) but the tag comparison (`hit0/hit1`) and output mux (`hit_word0/hit_word1/hit_word`) are combinational and directly observed by `Core.v` through `inst_ready`/`inst`. Because the cache is only 2 sets, the tag compare is just two 27-bit comparators — cheap.
2. Refill uses four explicit 32-bit registers to assemble a line before writing the cache. That is 128 flops. An alternative would be to write directly into the selected data register on each beat and use the beat counter to select the write address. That would eliminate the `refill_word*_q` registers entirely, saving ~128 flops and the associated muxes. However, it complicates the cache update logic because the target set/index must be stable during the refill.
3. The miss tag/index/offset/line-address registers capture the request address at miss time. With a direct-write refill, some of these could be reduced, but the tag and index are still needed for the final update.
4. `inst_ready` is combinational: `(state == S_IDLE && fetch_valid && hit) || refill_last`. This means the IFU hit path is a combinational path from `pc` through tag compare, valid check, and output mux to `inst_ready`/`inst`. In the current pipeline this is in the F stage, not the critical X stage, but it does limit how fast the F stage can accept a new PC.

**Verdict**: the refill-word shadow registers are the most obvious area inefficiency. They are functional but not minimal. Revisit after the X-stage timing is fixed.

---

### 2.2 `Idu.v` — instruction decoder

**What it really is**: a pure combinational decoder. It takes 32-bit instruction, extracts fields, and emits control signals.

**Hardware actually instantiated**:
- Field extraction: just wires (`opcode = inst[6:0]`, etc.).
- Immediate generation: five 32-bit sign-extension/rearrangement networks (`imm_i`, `imm_s`, `imm_b`, `imm_u`, `imm_j`). Only one is selected later by the `imm_sel` mux in `Core.v`.
- Instruction classification: a pile of opcode/funct3/funct7 comparisons producing `is_lui`, `is_op_imm`, etc.
- Legal detection: large AND-OR tree over classification signals.
- Control outputs: `alu_op`, `imm_sel`, `wb_sel`, `src1_pc`, `src2_imm`, `mem_ren/wen/size/unsigned`, `csr_cmd`, `sys_cmd`, `branch_op`, `reads_rs1/rs2`, `writes_rd`, `is_jal`, `is_jalr`, `is_legal`.

**Structural observations**:
1. The decoder is purely combinational and lives in the **X stage** because it decodes `x_inst` (the F/X register output). That means decode logic is in series with the register-file read and the ALU/branch path. For most instructions, decode is faster than regfile read, but for branches the comparator cannot start until `rs1`/`rs2` are decoded and the regfile read completes.
2. `alu_op` and `wb_sel` are wide muxes driven by many comparators. They are fast enough relative to the regfile read, but they still consume area and add to the X-stage combinational depth.
3. `is_legal` is a big OR over many terms; it is used only for exception detection (`decode_legal`).
4. The immediate generators are five independent 32-bit networks. In physical mode only one is used per instruction, but all five are computed and then the `imm_sel` mux selects. This is standard and relatively cheap.

**Verdict**: decoder is fine but could be moved to the F/X stage to overlap with register-file read. More importantly, its outputs `rs1`/`rs2`/`rd` are on the critical path only because the regfile read happens in X. If regfile read is moved earlier, decode can stay in X without hurting timing.

---

### 2.3 `RegFile.v` — register file

**What it really is**: 16 × 32-bit registers (RV32E), two read ports, one write port, with explicit x0=0 muxes.

**Hardware actually instantiated**:
- 16 flops × 32 bits = 512 flops for the registers.
- Two 16:1 32-bit read muxes. Because `raddr1/raddr2` are only 4 bits, the mux is small.
- Two comparison gates for x0 zeroing (`raddr1 == 4'd0`, `raddr2 == 4'd0`) and two 32-bit AND muxes to force zero.
- Debug outputs (`debug_x1`, `debug_a0`, `debug_regs_flat`) are tied to zero in `NPC_DEBUG=0`, so synthesis drops them.

**Structural observations**:
1. The read address comes from `rs1[3:0]`/`rs2[3:0]`. Since `rs1`/`rs2` are decoded from `x_inst`, the read cannot start until the F/X instruction register output propagates through the decoder field-extraction wires. Field extraction is just wires, so the real delay is the read mux itself.
2. The x0 zeroing mux (`raddr == 4'd0 ? 0 : regs[raddr]`) adds a 32-bit 2:1 mux after the read mux. In the previous experiment, removing it actually worsened timing and area. The likely reason: the synthesis tool can optimize the x0 case into the read-mux structure; the explicit mux forces an extra level. Keep the current design.
3. The write-enable qualification (`wen && waddr != 4'd0`) is correct and prevents x0 writes.
4. The read is combinational and is the dominant timing contributor in the X stage. This is the standard single-cycle / elastic-pipeline bottleneck.

**Verdict**: keep the x0 mux. The real issue is that the read is in the X stage at all. Move the read to the F/X stage (read registers as soon as the instruction is available in F/X) to remove it from the ALU/branch critical path.

---

### 2.4 `Exu.v` — ALU

**What it really is**: a 32-bit combinational ALU with 11 operations selected by a 4-bit `alu_op`.

**Hardware actually instantiated**:
- One 32-bit adder/subtractor (add/sub share hardware).
- One 32-bit barrel shifter for SLL/SRL/SRA (a 5-bit shift amount gives a 32×32 barrel shifter).
- Two signed/unsigned 32-bit comparators for SLT/SLTU.
- Bitwise XOR/OR/AND networks.
- A 32-bit 11:1 output mux driven by `alu_op`.

**Structural observations**:
1. The barrel shifter is the largest single piece of logic. In a 32-bit datapath it is roughly 32 × (5 levels of 2:1 muxes) = 160 2:1 muxes. SLT/SLTU also need comparators, which reuse the adder's carry-out if synthesized well.
2. The ALU is not currently the critical path; the branch comparator is. The branch comparator in `Core.v` is a separate comparison, not the ALU's SLT result. This duplicates comparison logic. For BLT/BLTU/BGE/BGEU, the branch comparator and ALU SLT/SLTU are essentially the same hardware.
3. `NPC_ALU_COPY_B` is used only for LUI and is just a pass-through of `src2`.

**Verdict**: not the main bottleneck, but there is duplicated comparison hardware. Could generate branch-taken from ALU result for integer comparisons, but that may lengthen the ALU path. Better to keep branch compare separate and focus on moving the regfile read out of X.

---

### 2.5 `Wbu.v` — writeback

**What it really is**: `assign wdata = alu_result`.

**Structural observation**: this module does nothing. It is 32 wires. It adds hierarchy, file count, and mental overhead with zero hardware benefit.

**Verdict**: remove it. Route `wb_data` directly from the writeback mux in `Core.v` to the register file. This is a pure cleanup.

---

### 2.6 `Csr.v` — control/status registers

**What it really is**: three writable CSR flops (`mtvec`, `mepc`, `mcause`), plus combinational read logic and trap handling.

**Hardware actually instantiated**:
- 3 × 32-bit flops for `mtvec_r`, `mepc_r`, `mcause_r`.
- A 6-way combinational read mux (`csr_old`) selecting among read-only zeros, hardwired `mstatus`, and the three CSRs.
- CSR source mux (`csr_src`) selecting `rs1_data` vs. zero-extended `uimm`.
- CSR write-enable logic (`csr_write_en`) and update mux (`csr_next`) for RS/RC/RW.

**Structural observations**:
1. CSR read is combinational and used in the X stage (`csr_rdata` is captured into `xc_csr_rdata` at the X/C boundary). The read mux is small (6 entries) and not on the critical path.
2. CSR write is registered in the C stage (`commit_en && csr_write_en`). The address-based case statement becomes a 3-way write decoder plus the source/update mux.
3. `mstatus` is hardwired to `32'h0000_1800`. That is correct for the spec but the `mstatus_value` wire still drives an output.
4. The `csr_old` mux and `csr_next` update logic are duplicated in a sense: `csr_old` is used for readback, `csr_next` for update. This is unavoidable for read-before-write CSR semantics.

**Verdict**: CSR module is fine. It is small and not on the critical path. No action needed.

---

### 2.7 `Lsu.v` — load/store unit

**What it really is**: a combinational byte/half/word alignment and sign-extension unit for loads, plus a store data/byte-mask generator.

**Hardware actually instantiated**:
- Address alignment (`aligned_addr`).
- UART MMIO address detection (`is_uart_mmio`).
- Variable right shifter for load data (`raw_rdata >> byte_shift`), then byte/half extraction and sign extension.
- Variable left shifter for store data (`wdata << byte_shift`).
- Byte/half mask generation.

**Structural observations**:
1. The load shift and sign-extension are combinational and sit in the C stage (LSU result is captured into `xc_lsu_addr` in X and then used in C, but the actual `lsu_rdata` is combinational from `bus_rdata`). Wait: `lsu_rdata` is combinational in `Lsu`, driven by `bus_rdata`. `lsu_rdata` feeds the writeback mux `c_wb_mux` in `Core.v`, which is also combinational. The writeback mux output feeds `wb_data`, which is registered into the register file on the next cycle. So the C-stage path is `bus_rdata → lsu_rdata → c_wb_mux → wb_data → regfile D input`. This is the C-stage path, but it is not the current critical path.
2. The store shifter and mask generator are combinational and feed `AxiArbiter`/`AxiMaster` in the same cycle. This is fine for memory writes because the AXI write address/data path has its own timing.
3. The `is_uart_mmio` check forces UART MMIO addresses to use unaligned address; all other accesses are word-aligned. This is a small mux.

**Verdict**: LSU is fine. No major inefficiency. The C-stage writeback mux (`c_wb_mux`) is a 4:1 32-bit mux feeding `wb_data`; it is not on the critical X-stage path.

---

### 2.8 `AxiArbiter.v` and `AxiMaster.v` — bus interface

**AxiArbiter**: purely combinational priority mux giving LSU priority over IFU. Tiny.

**AxiMaster**: a simple AXI4-lite-ish state machine with burst-read support for cache refills. It has a handful of state flops and data/error holding registers.

**Structural observations**:
1. The arbiter gives LSU unconditional priority. That is simple and correct, but it means IFU cannot make progress while any LSU transaction is in flight. With the small 2-set cache, IFU misses are frequent; LSU blocking IFU may hurt CPI more than a fair arbiter would.
2. `AxiMaster` supports bursts for cache refill (`len_q` can be 3 for 4 beats). Write transactions are single-beat (`axi_awlen = 0`).
3. The `read_beat_q` counter is 8 bits even though only cache refill uses more than one beat. This is minor area overhead.

**Verdict**: not on the critical path for core timing. The arbitration policy (LSU always wins) may hurt CPI; consider round-robin or IFU-priority-after-pending policies later. Low priority.

---

### 2.9 `Core.v` — top-level pipeline control

This is where most of the architectural decisions live.

**Current X-stage combinational cloud**:
- Decode (`Idu`) produces `rs1/rs2/rd`, control signals, immediates.
- Regfile reads `rf_rs1_data`/`rf_rs2_data`.
- Forwarding muxes select between regfile read and C-stage writeback (`x_rs1_data`, `x_rs2_data`).
- ALU computes `alu_result`.
- Branch comparator computes `branch_taken`.
- Next-PC mux computes `x_normal_next_pc` (mepc → jalr → jal → branch → pc+4).
- LSU address computes `x_lsu_addr`.
- Decode-legal and exception signals compute `x_pc_exception`, `x_mem_misaligned`.
- CSR reads `csr_rdata`.

All of the above must complete in one cycle because the results are captured into the X/C packet registers on the same edge.

**X/C packet register list** (what gets stored for every instruction that enters C):
- `xc_pc`, `xc_inst_error`, `xc_rd`, `xc_writes_rd`, `xc_wb_sel`, `xc_mem_ren/wen/size/unsigned`, `xc_csr_cmd/addr/uimm`, `xc_csr_rdata`, `xc_rs1_data`, `xc_rs2_data`, `xc_alu_result`, `xc_lsu_addr`, `xc_normal_next_pc`, `xc_is_mret`, `xc_is_fence_i`, `xc_decode_legal`, `xc_pc_exception`, `xc_mem_misaligned`, `xc_is_ecall`, `xc_is_ebreak`.
- `xc_inst` is removed in `NPC_DEBUG=0` after P10-S5.

That's roughly 14 × 32-bit registers + many 1-5 bit control registers. This is a large packet, but most of the area is the 32-bit data registers.

**Area inefficiencies in the packet**:
1. `xc_rs1_data` and `xc_rs2_data` are stored for every instruction, but they are only needed for:
   - ALU ops (need both or one operand, but `xc_alu_result` already has the result).
   - Store data (need `xc_rs2_data` for `wdata`).
   - CSR source (need `xc_rs1_data`).
   - Branch compare is already done; `xc_rs1_data`/`xc_rs2_data` are not used in C.
   - Load address is already in `xc_lsu_addr`.
   So `xc_rs1_data` is only used for CSR and `xc_rs2_data` only for store data. They could be narrower or eliminated if those operations carried their operands differently.
2. `xc_lsu_addr` is stored for every instruction but only used by memory ops.
3. `xc_normal_next_pc` is stored for every instruction but only meaningful for taken branches/jumps/mret. For non-control instructions it is just `pc+4`, which could be recomputed in C as `xc_pc + 4`.
4. `xc_csr_rdata` is stored for every instruction but only used when `xc_wb_sel == NPC_WB_CSR`.
5. `xc_alu_result` is stored for every instruction; it is used for most ALU results and for load/store address. It is the dominant data register and is justified.

**Hazard/forwarding logic**:
- Load-use stall: `load_use_stall = c_load_waiting && xc_writes_rd && (c_rs1_match || c_rs2_match)`.
- Forwarding: `x_rs1_data = (c_can_forward && c_rs1_match) ? c_forward_data : rf_rs1_data`.
- The forwarding match `c_rs1_match = reads_rs1 && xc_rd == rs1` is simple, but the forwarded data `c_forward_data` is the writeback mux output `c_wb_mux`, which includes `lsu_rdata`. That means a load result can be forwarded in the same cycle the LSU returns data. This is good for CPI but puts the C-stage writeback mux on the X-stage critical path.

**Branch/redirect handling**:
- Branches are resolved in X. On a taken branch or jump, `redirect` flushes F/X and restarts the F stage at the new PC. This costs at least one bubble (the instruction in F/X is discarded).
- `jalr` target requires a full 32-bit add and clear bit 0. This add is in the critical path.

---

## 3. Architectural decisions review

### 3.1 Decision: 3-stage F/X/C with X-stage regfile read

**Why it was made**: simple elastic pipeline, easy to verify, naturally supports single-cycle forwarding from C to X.

**Is it good?** It is correct and compact, but the X-stage regfile read is the dominant timing bottleneck. The F/X/C organization makes sense, but the placement of the regfile read in X is suboptimal for frequency.

**Alternative**: move regfile read into F/X. The instruction is available in `fx_inst`; decode it there, read the register file, and register the operands as `fx_rs1_data`/`fx_rs2_data`. Then the X stage becomes pure ALU/branch/next-PC. Forwarding must deliver C-stage writeback to F/X instead of X.

**Trade-off**: +64 flops for operand registers, more complex hazard logic (must stall F/X on load-use instead of stalling X), but removes ~0.77 ns of regfile read from the critical path. Should push Fmax well above 600 MHz.

### 3.2 Decision: registered IFU response (removed direct IFU→X/C bypass)

**Why it was made**: the unregistered bypass created a long combinational path from cache hit data through decode/regfile/ALU to the X/C registers.

**Is it good?** Yes for timing. The direct path gave a CPI advantage on cache hits but made the cycle time much worse. The registered response is the right trade-off for PPA.

**Alternative to consider later**: keep the registered response, but add a small prefetch buffer or instruction queue so the F stage can prefetch ahead and hide the one-cycle bubble.

### 3.3 Decision: store `xc_normal_next_pc` for every instruction

**Why it was made**: uniform packet simplifies control.

**Is it good?** It costs 32 flops and a 4-level 32-bit mux in X. For non-control instructions the value is `pc+4`, which is trivially computable in C. For control instructions the mux is needed anyway.

**Alternative**: in C, compute next PC as `xc_pc + 4` unless the instruction is a taken branch/jump/mret. This removes the `xc_normal_next_pc` register and the X-stage next-PC mux, but adds a small control mux in C. Since `xc_is_mret`/`xc_is_fence_i` are already registered, the C-stage mux is small.

**Trade-off**: -32 flops, -4-level 32-bit mux in X, +small mux in C. Likely improves timing and area.

### 3.4 Decision: store `xc_rs1_data` and `xc_rs2_data`

**Why it was made**: uniform packet, used for store data and CSR source.

**Is it good?** `xc_rs1_data` is only needed for CSR write source. `xc_rs2_data` is only needed for store data. Both could be avoided:
- Store data: compute/store the shifted store data in X and register `xc_store_wdata` instead of raw `xc_rs2_data`.
- CSR source: register a separate `xc_csr_rs1_data` only for CSR instructions, or read CSR source from the operand register in F/X.

**Trade-off**: -64 flops general packet, +some specialized flops. Worth doing after moving regfile read to F/X.

### 3.5 Decision: combinational CSR read captured at X/C boundary

**Why it was made**: CSR read result must be available for writeback.

**Is it good?** Fine. The CSR read mux is small and not on the critical path. Could move CSR read to C stage if wanted, but no clear benefit.

### 3.6 Decision: AXI arbiter gives LSU absolute priority

**Why it was made**: simplicity, avoids starvation handling.

**Is it good?** Probably hurts CPI because IFU misses cannot progress while LSU has a transaction. With the tiny cache and high miss rate, this is significant.

**Alternative**: after IFU has a pending miss, give IFU priority over new LSU requests until the refill completes. This reduces instruction-fetch stall at the cost of slightly more complex arbiter.

**Trade-off**: small logic change, potential CPI improvement. Low priority until timing is fixed.

---

## 4. Concrete bottlenecks and optimization candidates

### Timing bottlenecks

1. **Regfile read in X stage** (biggest). Solution: move read to F/X.
2. **Forwarding mux on the critical path**. The C-stage writeback mux output is muxed with regfile read before ALU/branch. If regfile read moves to F/X, forwarding still exists but the mux moves earlier and may be off the critical ALU path.
3. **`x_normal_next_pc` 4-level mux**. Solution: compute in C from `xc_pc` and control signals.
4. **`jalr` target adder**. This is a 32-bit add plus bit-clear. If regfile read moves to F/X, the adder remains but starts from a registered operand, giving more budget.

### Area inefficiencies

1. **IFU refill-word shadow registers** (128 flops). Can be eliminated by writing cache data directly per beat.
2. **X/C packet bloat**:
   - `xc_normal_next_pc` (32 flops) — can recompute in C.
   - `xc_rs1_data`/`xc_rs2_data` (64 flops) — specialize to store/CSR operands.
   - `xc_csr_rdata` (32 flops) — could read CSR in C, but this may add delay; evaluate.
   - `xc_lsu_addr` (32 flops) — only needed for memory; could compute/store only when needed.
3. **`Wbu.v`** — remove, zero area but cleanup.
4. **Performance counters** — already gated in `NPC_DEBUG=0`; good.

### CPI inefficiencies

1. **One-cycle bubble on every fetch** due to registered IFU response. A small prefetch buffer could hide this.
2. **Branch/jump redirect bubble** — one cycle lost per taken branch/jump.
3. **Load-use stall** — one cycle lost per load-to-use dependency.
4. **LSU priority over IFU** — cache refills can be delayed by LSU traffic.

---

## 5. Prioritized optimization plan

### 5.1 Step 1: remove dead `Wbu.v` and route writeback directly

- Delete `npc/rtl/core/Wbu.v`.
- In `Core.v`, replace `u_wbu` instantiation with `assign wb_data = c_wb_mux;`.
- Update Makefile RTL list if any.
- Expected impact: tiny area/timing change, cleaner design.

### 5.2 Step 2: eliminate `xc_normal_next_pc` register (recompute in C)

- Remove `xc_normal_next_pc` register and its assignment.
- In C-stage combinational logic, compute:
  ```
  c_pc_plus_4 = xc_pc + 4
  c_next_pc = c_precise_trap ? mtvec :
              (c_bad_without_vector ? xc_pc :
               (xc_is_mret ? mepc :
                (xc_is_jalr ? xc_jalr_target_reg :
                 (xc_is_jal ? xc_jal_target_reg :
                  (xc_branch_taken_reg ? xc_branch_target_reg : c_pc_plus_4)))))
  ```
- This requires storing branch/jal/jalr targets or recomputing them. Since the immediates are available in `fx_inst`/`xc_pc`, recomputing in C means adding decode/immediate logic in C, which is undesirable.
- Better: store only the *target* registers for branch/jal/jalr when those instructions are taken. But we don't know taken in F/X.
- **Simpler alternative**: keep a smaller control set and compute target in C from `xc_pc` + immediate. The immediate can be extracted from `fx_inst`/`xc_inst` (debug only). In `NPC_DEBUG=0` we don't have `xc_inst` anymore.
- **Practical approach**: store `xc_branch_taken`, `xc_jalr_target`, `xc_jal_target`, `xc_branch_target` only when needed. That's still 4 × 32-bit registers = 128 flops worst case, but we can encode it smarter:
  - Store a 2-bit `xc_branch_taken` / `xc_is_jump` control.
  - Store `xc_target_offset` (21 bits for B-type, 20 bits for J-type, or full 32 bits for jalr).
  - Recompute target in C from `xc_pc + offset`.
- This is getting complex. Maybe the better first step is to keep `xc_normal_next_pc` but reduce its critical-path delay by moving regfile read out of X. Then revisit whether to remove the register.

**Revised Step 2**: move regfile read to F/X first, then decide whether `xc_normal_next_pc` is still worth removing.

### 5.3 Step 2 (real): move register-file read into F/X stage

This is the highest-impact timing optimization.

**Changes in `Core.v`**:
1. Add `fx_rs1_data` and `fx_rs2_data` registers.
2. Decode instruction and read register file in the F/X stage:
   - Use `fx_inst` to drive `Idu` (currently driven by `x_inst = fx_inst`, so this is just a wiring change).
   - `RegFile` read ports are already driven by `rs1/rs2`, which come from `Idu` decoding `x_inst`. Keep this but capture results into `fx_rs1_data`/`fx_rs2_data`.
3. In the X stage, use `fx_rs1_data`/`fx_rs2_data` as operands instead of `rf_rs1_data`/`rf_rs2_data`.
4. Forwarding must now deliver C-stage writeback to F/X instead of X. This means the load-use stall and forwarding logic must be evaluated at the F/X boundary.

**Hazard logic changes**:
- Current load-use stall: when instruction in C is a load and its `xc_rd` matches `rs1`/`rs2` of the instruction in X.
- New load-use stall: when instruction in C is a load and its `xc_rd` matches `rs1`/`rs2` of the instruction in F/X.
- The X stage still needs the operands for ALU/branch, but they are now registered in F/X. If the producer is in C (writeback happening this cycle), the F/X stage must have already forwarded it. If the producer is in X (instruction currently computing in X, not yet in C), then an F/X instruction reading the same register must stall because the result is not yet available.
- This introduces a new **X→F/X forwarding** requirement: an instruction in X (which has computed `alu_result` but not yet moved to C) may need to forward to the instruction in F/X. Currently forwarding only handles C→X. We will need X→F/X forwarding or stall.

This is the main complexity. Let me think it through carefully.

**Pipeline state after move**:
- F: fetch
- F/X: instruction available, operands read from regfile (with forwarding from C and X)
- X: ALU/branch/next-PC/LSU-addr
- X/C: ALU result, control, etc.
- C: memory, writeback, trap

**Producers and consumers**:
- Writeback happens in C. Result is available at end of C cycle.
- Instruction in X computes result during X cycle; result is available at end of X cycle (captured into X/C).
- Instruction in F/X reads regfile during F/X cycle.

**Forwarding cases for F/X reader**:
1. Producer in C (about to write back this cycle): result is `c_wb_mux` (writeback mux output). Forward `c_wb_mux` to F/X operand muxes. This is the current C→X forwarding moved earlier.
2. Producer in X/C (computed last cycle, now in C): same as case 1, it is in C stage.
3. Producer in X (computing this cycle): result is `alu_result` for ALU ops, `x_normal_next_pc` for jumps (but jumps write PC+4 or rd=0 usually), `x_lsu_addr` not a register write. For ALU result, forward `alu_result` from X to F/X.
4. Producer in F/X: read-after-write within same cycle — impossible, must stall or bypass. For simplicity, stall F/X when its `rs1`/`rs2` matches the instruction currently in X and that instruction writes rd.

**Stall logic**:
- `x_producer_rd = rd` (the rd of the instruction currently in X). Actually `xc_rd` is the rd captured at X/C boundary; the instruction in X has decoded `rd`.
- Stall F/X when `reads_rs1 && rs1 == x_rd && x_writes_rd` or same for rs2. This is the same-cycle read-after-write hazard.
- Load-use stall: when instruction in C is load (`xc_mem_ren && !c_mem_ready`) and F/X instruction reads `xc_rd`. This can forward from `lsu_rdata` if memory returns data this cycle, but the address may not be known yet. Safer to stall F/X until load completes.

This is more complex but standard for a 4-stage pipeline (Fetch, Decode/RegRead, Execute, Memory/Writeback). It is essentially turning F/X into a Decode/RegRead stage.

**Expected impact**:
- +64 flops for `fx_rs1_data`/`fx_rs2_data`.
- Critical path becomes F/X operand register → ALU/branch → X/C result register. The regfile read is now in F/X and off the ALU/branch critical path.
- Fmax should improve significantly, likely above 650 MHz.
- CPI may increase slightly due to the extra X→F/X stall case, but the current design already has load-use stalls; the net CPI change depends on workload.

### 5.4 Step 3: reduce X/C packet size

After moving regfile read to F/X:
- Remove `xc_rs1_data`/`xc_rs2_data` or specialize them.
- Evaluate removing `xc_normal_next_pc` by recomputing target in C.
- Evaluate whether `xc_csr_rdata` can be read in C instead of X.

Each of these requires careful functional validation. Do one at a time.

### 5.5 Step 4: IFU refill-word shadow register removal

Rewrite IFU to write cache data registers directly on each refill beat instead of assembling into `refill_word*_q` first. This saves 128 flops and associated muxes.

### 5.6 Step 5: CPI optimizations

After timing and area are acceptable, focus on CPI:
- Small instruction prefetch buffer or queue.
- Branch target buffer or early branch prediction.
- Fairer AXI arbitration.

---

## 6. What NOT to do

- Do not make random mux/register changes based only on endpoint names in STA reports.
- Do not chase small area wins that add critical-path logic (e.g., the rejected `xc_inst` trim that cost timing).
- Do not pipeline further without measuring CPI; frequency gains are meaningless if CPI regresses proportionally.
- Do not modify `ysyxSoC/` or `am-kernels/` unless explicitly asked.

---

## 7. Update after attempted 4-stage pipeline

Following this review, a 4-stage `F/D/X/C` pipeline (move regfile read to F/X) was implemented and measured:

- Frequency improved from ~579 MHz to ~808 MHz (+39%).
- Area increased from 24124.52 to 25665.08 (+6.4%).
- CPI regressed enough that wall-clock time per instruction worsened.
- The extra stage added bubbles on branches/jumps and complicated hazard/forwarding logic.

**Decision**: revert to the 3-stage `F/X/C` pipeline. Adding stages is the wrong first move. The 4-stage experiment validated that frequency without CPI discipline is not a PPA win.

## 8. Revised optimization plan (CPI-neutral first)

Reorder the plan to attack module-level structural inefficiencies before any architectural stage change:

1. **IFU refill-word shadow-register removal** (highest area ROI, no CPI risk):
   - Write each refill beat directly into the selected cache data register.
   - Eliminate `refill_word0_q`..`refill_word3_q` (128 flops).
   - Use the cache data registers + current `bus_rdata` to form `refill_inst`.

2. **Share branch comparator with ALU SLT/SLTU** (`Exu.v` + `Core.v`):
   - Export `less_signed`, `less_unsigned`, `equal` from `Exu.v`.
   - Use them for both ALU `SLT`/`SLTU` results and `branch_taken` in `Core.v`.
   - Removes duplicated comparison hardware.

3. **Review CSR read path** (`Csr.v`):
   - Check whether the combinational CSR read mux is on any setup-critical path.
   - If so, simplify or register the read without changing ISA semantics.

4. **X/C packet reduction** only after timing is stable:
   - Evaluate `xc_normal_next_pc`, `xc_rs1_data`/`xc_rs2_data`, `xc_lsu_addr`, `xc_csr_rdata` specialization.
   - Do not recompute anything on the current critical path.

5. **CPI optimizations last** (prefetch buffer, fairer arbitration, branch prediction) once PPA targets are met.

## 9. IFU refill shadow-register removal result

Step 1 was implemented in `npc/rtl/core/Ifu.v`: refill beats are now written directly into the selected cache data registers, and the old `refill_word0_q`..`refill_word3_q` shadow registers are gone.

Measured against the reverted 3-stage baseline in the same STA flow:

- Area improved from `24119.2` to `22775.2` (`-1344.0`, about `-5.6%`).
- Sequential cells dropped from `1603` to `1475` `DFFQX1H7L`, matching the intended 128-flop removal.
- 620 MHz setup slack improved from about `-0.210 ns` to about `-0.060 ns`, but 620 MHz still did not close.

**Decision**: keep the IFU direct-refill change. It is a real structural area win with no CPI or functional-cost mechanism.

## 10. Comparator-sharing attempt result

Step 2 was implemented as a deliberate module-level attempt in `npc/rtl/core/Exu.v` and `npc/rtl/core/Core.v`:

- `Exu.v` now exports reusable comparison facts: `equal`, `less_signed`, and `less_unsigned`.
- `Exu.v` uses `less_signed`/`less_unsigned` for `SLT`/`SLTU`.
- `Core.v` uses those same facts for `BEQ`/`BNE`/`BLT`/`BGE`/`BLTU`/`BGEU` instead of independently describing another branch comparator.
- Because branch instructions are decoded as `src2_imm` in the ALU path, `Core.v` also selects `x_rs2_data` as `alu_src2` whenever `branch_op != NPC_BR_NONE`; otherwise branch comparisons would compare `rs1` against the B-immediate, which was caught by the first smoke regression.

Why this was tried:

- The old RTL was functionally clear but structurally duplicated comparison hardware: ALU `SLT`/`SLTU` and branch compare described similar operand comparisons separately.
- Sharing comparison facts is CPI-neutral and does not add pipeline stages, stalls, or fetch-policy changes.
- The expected benefit was less comparator logic and possibly shorter branch-control logic.

Functional validation after fixing the branch operand issue:

```sh
make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke
make -C npc clean && make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest \
  test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

Both passed. The directed/DiffTest regression includes branch/jalr, ALU signed/unsigned comparisons, memory, CSR/trap, CLINT, icache, fence.i, and access-fault cases.

PPA command:

```sh
make -C npc sta-sweep \
  STA_O=../build/p10-s7-compare-share/ppa \
  STA_LOG_DIR=../build/p10-s7-compare-share/logs \
  STA_FREQS="560 570 580 600 620 640"
```

Measured result against the P10-S6 IFU point:

| Metric | P10-S6 IFU | P10-S7 comparator sharing | Delta |
| --- | ---: | ---: | ---: |
| Chip area | `22775.200000` | `22547.280000` | `-227.920000` (`-1.0%`) |
| Sequential area | `9086.000000` | `9086.000000` | `0` |
| `DFFQX1H7L` | `1475` | `1475` | `0` |
| Clean checked target | `580 MHz` | `570 MHz` | `-10 MHz` |
| 580 MHz worst slack | `+0.052 ns` | `-0.010 ns` | `-0.062 ns` |
| 600 MHz worst slack | `-0.006 ns` | `-0.068 ns` | `-0.062 ns` |
| 620 MHz worst slack | `-0.060 ns` | `-0.122 ns` | `-0.062 ns` |
| 640 MHz worst slack | `-0.110 ns` | `-0.172 ns` | `-0.062 ns` |

Interpretation:

- The attempt is a real area win: about `1.0%` area reduction with no flop-count change.
- It is **not a timing success**: the clean checked frequency drops from `580 MHz` to `570 MHz`, and the worst slack worsens by about `62 ps` across the checked high-frequency points.
- The likely reason is structural: to reuse the ALU comparator for branches, branch instructions now force the main ALU second operand mux to choose `x_rs2_data`; this puts branch compare behind the ALU operand-select path and gives the shared comparator a broader fanout/use context. The old duplicated branch comparator was wasteful in area, but it let the branch compare sit directly on `x_rs1_data/x_rs2_data` without involving the ALU `src2` mux.

**Decision after user revision**: keep comparator sharing. The user accepted the area/timing trade-off: about `1.0%` lower area at the cost of reducing the clean checked target from `580 MHz` to `570 MHz`. The next optimization should avoid adding more delay to the branch/next-PC critical path; look for area wins outside this path or specialize X/C packet registers without adding X-stage logic.

## 11. Redirect decision/target split result

P10-S8 implemented a focused timing optimization in `npc/rtl/core/Core.v`: split the old `xc_normal_next_pc` register into explicit redirect state:

- `xc_redirect`: one bit saying whether the committed instruction redirects control flow (`mret`, `jalr`, `jal`, or taken branch).
- `xc_redirect_pc`: the target address for redirect-capable instructions.
- C stage now computes `c_normal_next_pc = xc_redirect ? xc_redirect_pc : (xc_pc + 4)`.
- `redirect` now uses the explicit `xc_redirect` bit instead of the old full-width `c_next_pc != c_pc_plus_4` comparison.

Why this was tried:

- The P10-S7 worst path ended at `xc_normal_next_pc_*__reg_p:D`.
- The old RTL described a 32-bit mux selected by `branch_taken`, so the branch comparator sat on a 32-bit next-PC data endpoint.
- The branch target itself does not depend on the comparison; only the decision to use it does. Splitting target and decision moves the branch decision to a one-bit endpoint and removes the unconditional target-vs-`pc+4` X-stage data mux.
- This keeps the 3-stage `F/X/C` architecture and CPI unchanged; it is a structural RTL change, not another pipeline experiment.

Functional validation:

```sh
make -C npc clean && make -C npc NPC_DEBUG=0 spec-smoke
make -C npc clean && make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug test-difftest \
  test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
  AM_HOME=/host/Workspace/ai-ysyx/abstract-machine \
  CROSS_COMPILE=riscv64-linux-gnu- NPC_MAX_CYCLES=12000000 \
  NPC_DIFFTEST_REF=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so run
```

Results:

- Spec smoke passed: `NPC_SPEC_RESULT status=good reason=uart_eot cycles=57 limit=400`.
- Directed/debug regression passed, including branch/jalr, ALU, memory sizes/misalignment, illegal RV32E register checks, CSR/trap, CLINT, icache, fence.i, and access-fault DiffTest cases.
- RT-Thread passed through scripted shell `halt` with DiffTest: `NEMU_RESULT status=good`, `NPC_RESULT status=good reason=good_trap cycles=1807800 insts=511842`, `NPC_ICACHE accesses=511842 hits=428931 misses=82911 ... hit_rate_x1000=838 amat_x1000=2019`.

PPA command:

```sh
make -C npc sta-sweep \
  STA_O=../build/p10-s8-redirect-split/ppa \
  STA_LOG_DIR=../build/p10-s8-redirect-split/logs \
  STA_FREQS="560 570 580 600 620 640"
make -C npc sta-sweep \
  STA_O=../build/p10-s8-redirect-split/ppa \
  STA_LOG_DIR=../build/p10-s8-redirect-split/logs \
  STA_FREQS="680 690 700"
```

Measured result against P10-S7 comparator sharing:

| Metric | P10-S7 comparator sharing | P10-S8 redirect split | Delta |
| --- | ---: | ---: | ---: |
| Chip area | `22547.280000` | `22528.520000` | `-18.760000` (`-0.08%`) |
| Sequential area | `9086.000000` | `9092.160000` | `+6.160000` |
| `DFFQX1H7L` | `1475` | `1476` | `+1` |
| `ICGX0P5H7L` | `17` | `17` | `0` |
| Clean checked target | `570 MHz` | `680 MHz` | `+110 MHz` |
| 580 MHz worst slack | `-0.010 ns` | `+0.260 ns` | `+0.270 ns` |
| 600 MHz worst slack | `-0.068 ns` | `+0.202 ns` | `+0.270 ns` |
| 620 MHz worst slack | `-0.122 ns` | `+0.148 ns` | `+0.270 ns` |
| 640 MHz worst slack | `-0.172 ns` | `+0.098 ns` | `+0.270 ns` |
| 680 MHz worst slack | not checked | `+0.006 ns` | — |
| 690 MHz worst slack | not checked | `-0.015 ns` | — |
| Reported Fmax | `576.746 MHz` at 580 MHz report | `682.840 MHz` | `+106.094 MHz` |

Interpretation:

- This attempt is a clear timing success. The old `xc_normal_next_pc` endpoint disappeared from the top critical list; the new worst endpoint is `xc_alu_result_20__reg_p:D` at `1.419 ns`, with `xc_redirect_reg_p:D` close behind at `1.408 ns`.
- The clean checked target improved from `570 MHz` to `680 MHz`; `690 MHz` fails by about `15 ps`, so the practical limit is around `682.8 MHz` in this STA setup.
- Area also improved slightly despite adding one extra flop. The likely reason is that removing the 32-bit normal-next-PC mux and full-width redirect compare let synthesis simplify more logic than the one additional `xc_redirect` flop costs.
- CPI did not regress in the directed tests. RT-Thread cycle count improved from the previous noted `1816964`/`511842` P8/P10 baseline to `1807800`/`511842`, but treat that as workload noise or side effect of control timing structure unless reproduced across multiple workloads.

**Decision for user revision**: keep the redirect split unless the user objects. It is exactly the kind of structural RTL optimization requested: it comes from understanding what the old RTL became in hardware, improves timing substantially, has near-neutral/slightly better area, and does not change the architecture or CPI policy.
