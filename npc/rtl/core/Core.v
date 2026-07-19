`include "include/npc_defines.vh"

module Core #(
  parameter RESET_PC = `NPC_RESET_PC
) (
  input         clock,
  input         reset,
  input  [31:0] reset_pc,
  output [31:0] debug_pc,
  output        debug_halted,
  output [31:0] debug_x1,
  output [31:0] debug_a0,
  output [1:0]  debug_trap_status,
  output [31:0] debug_inst,
  output [31:0] debug_mstatus,
  output [31:0] debug_mtvec,
  output [31:0] debug_mepc,
  output [31:0] debug_mcause,
  output [511:0] debug_regs_flat,
  output [63:0] debug_icache_accesses,
  output [63:0] debug_icache_hits,
  output [63:0] debug_icache_misses,
  output [63:0] debug_icache_miss_wait_cycles,
  output [63:0] debug_icache_refill_beats,
  output        commit_valid,
  output [31:0] commit_pc,
  output [31:0] commit_inst,
  output [31:0] commit_next_pc,
  output        commit_wen,
  output [4:0]  commit_rd,
  output [31:0] commit_wdata,
  output        commit_exception,
  output [31:0] commit_cause,
  output        commit_mem_wen,
  output        commit_mem_ren,
  output [31:0] commit_mem_addr,
  output [31:0] commit_mem_wdata,
  output [3:0]  commit_mem_wmask,
  output [31:0] commit_mem_rdata,
  input         axi_awready,
  output        axi_awvalid,
  output [31:0] axi_awaddr,
  output [3:0]  axi_awid,
  output [7:0]  axi_awlen,
  output [2:0]  axi_awsize,
  output [1:0]  axi_awburst,
  input         axi_wready,
  output        axi_wvalid,
  output [31:0] axi_wdata,
  output [3:0]  axi_wstrb,
  output        axi_wlast,
  output        axi_bready,
  input         axi_bvalid,
  input  [1:0]  axi_bresp,
  input  [3:0]  axi_bid,
  input         axi_arready,
  output        axi_arvalid,
  output [31:0] axi_araddr,
  output [3:0]  axi_arid,
  output [7:0]  axi_arlen,
  output [2:0]  axi_arsize,
  output [1:0]  axi_arburst,
  output        axi_rready,
  input         axi_rvalid,
  input  [1:0]  axi_rresp,
  input  [31:0] axi_rdata,
  input         axi_rlast,
  input  [3:0]  axi_rid
);

  wire [31:0] reset_vector = (reset_pc == 32'd0) ? RESET_PC : reset_pc;

  reg        halted;
  reg [1:0]  trap_status;

  // F stage
  reg [31:0] f_pc;
  reg        ifu_pending;
  reg        drop_fetch_response;

  // F/D boundary
  reg        fd_valid;
  reg [31:0] fd_pc;
  reg [31:0] fd_inst;
  reg        fd_inst_error;

  // D/X boundary
  reg        dx_valid;
  reg [31:0] dx_pc;
  reg [31:0] dx_inst;
  reg        dx_inst_error;
  reg [4:0]  dx_rd;
  reg        dx_writes_rd;
  reg [1:0]  dx_wb_sel;
  reg        dx_mem_ren;
  reg        dx_mem_wen;
  reg [1:0]  dx_mem_size;
  reg        dx_mem_unsigned;
  reg [2:0]  dx_csr_cmd;
  reg [11:0] dx_csr_addr;
  reg [4:0]  dx_csr_uimm;
  reg [31:0] dx_rs1_data;
  reg [31:0] dx_rs2_data;
  reg [31:0] dx_imm;
  reg [3:0]  dx_alu_op;
  reg [2:0]  dx_branch_op;
  reg        dx_src1_pc;
  reg        dx_src2_imm;
  reg        dx_is_jal;
  reg        dx_is_jalr;
  reg        dx_is_mret;
  reg        dx_is_fence_i;
  reg        dx_decode_legal;
  reg        dx_is_ecall;
  reg        dx_is_ebreak;

  // X/W boundary
  reg        xw_valid;
  reg [31:0] xw_pc;
`ifdef NPC_DEBUG
  reg [31:0] xw_inst;
  reg        xw_redirect;
  reg [31:0] xw_redirect_pc;
`endif
  reg        xw_inst_error;
  reg [4:0]  xw_rd;
  reg        xw_writes_rd;
  reg [1:0]  xw_wb_sel;
  reg        xw_mem_ren;
  reg        xw_mem_wen;
  reg [1:0]  xw_mem_size;
  reg        xw_mem_unsigned;
  reg [2:0]  xw_csr_cmd;
  reg [11:0] xw_csr_addr;
  reg [4:0]  xw_csr_uimm;
  reg [31:0] xw_csr_rdata;
  reg [31:0] xw_rs1_data;
  reg [31:0] xw_rs2_data;
  reg [31:0] xw_alu_result;
  reg [31:0] xw_lsu_addr;
  reg        xw_is_mret;
  reg        xw_is_fence_i;
  reg        xw_decode_legal;
  reg        xw_pc_exception;
  reg        xw_mem_misaligned;
  reg        xw_is_ecall;
  reg        xw_is_ebreak;

  // D-stage decode wires (from fd_inst)
  wire [6:0]  opcode;
  wire [4:0]  rd;
  wire [2:0]  funct3;
  wire [4:0]  rs1;
  wire [4:0]  rs2;
  wire [6:0]  funct7;
  wire [31:0] imm_i;
  wire [31:0] imm_s;
  wire [31:0] imm_b;
  wire [31:0] imm_u;
  wire [31:0] imm_j;
  wire [11:0] csr_addr;
  wire [4:0]  csr_uimm;
  wire [3:0]  alu_op;
  wire [2:0]  imm_sel;
  wire [1:0]  wb_sel;
  wire        src1_pc;
  wire        src2_imm;
  wire        mem_ren;
  wire        mem_wen;
  wire [1:0]  mem_size;
  wire        mem_unsigned;
  wire [2:0]  csr_cmd;
  wire [2:0]  sys_cmd;
  wire [2:0]  branch_op;
  wire        reads_rs1;
  wire        reads_rs2;
  wire        writes_rd;
  wire        is_jal;
  wire        is_jalr;
  wire        is_legal;

  // D-stage data path
  wire [31:0] rf_rs1_data;
  wire [31:0] rf_rs2_data;
  wire [31:0] d_rs1_data;
  wire [31:0] d_rs2_data;
  wire [31:0] imm_data;

  // X-stage data path
  wire        x_valid;
  wire [31:0] x_pc;
  wire [31:0] x_rs1_data;
  wire [31:0] x_rs2_data;
  wire [31:0] x_imm;
  wire [31:0] x_imm_b;
  wire [31:0] x_imm_j;
  wire [31:0] x_alu_src1;
  wire [31:0] x_alu_src2;
  wire [31:0] x_alu_result;
  wire [31:0] exu_result;
  wire        x_alu_equal;
  wire        x_alu_less_signed;
  wire        x_alu_less_unsigned;

  // Shared adder in X stage
  wire [31:0] adder_src1;
  wire [31:0] adder_src2;
  wire        adder_sub;
  wire [31:0] adder_result;

  // Branch/jump/LSU computed in X
  wire [31:0] x_lsu_addr;
  wire [31:0] x_jalr_target;
  wire [31:0] x_jal_target;
  wire [31:0] x_branch_target;
  wire        x_branch_taken;
  wire        x_redirect;
  wire [31:0] x_redirect_pc;
  wire        x_pc_exception;
  wire        x_mem_half_misaligned;
  wire        x_mem_word_misaligned;
  wire        x_mem_misaligned;

  // W-stage control/data
  wire [31:0] lsu_rdata;
  wire [31:0] lsu_write_addr;
  wire [31:0] lsu_write_data;
  wire [3:0]  lsu_write_mask;
  wire        lsu_raw_valid;
  wire        lsu_raw_write;
  wire [31:0] lsu_raw_addr;
  wire [31:0] lsu_raw_wdata;
  wire [3:0]  lsu_raw_wmask;
  wire        lsu_raw_ready;
  wire [31:0] lsu_raw_rdata;
  wire        lsu_raw_error;
  wire        lsu_is_clint;
  wire        lsu_arb_valid;
  wire        lsu_arb_ready;
  wire [31:0] lsu_arb_rdata;
  wire        lsu_arb_error;
  wire        clint_ready;
  wire [31:0] clint_rdata;
  wire        clint_error;
  wire        axi_req_valid;
  wire        axi_req_write;
  wire [31:0] axi_req_addr;
  wire [7:0]  axi_req_len;
  wire [31:0] axi_req_wdata;
  wire [3:0]  axi_req_wmask;
  wire        axi_req_ready;
  wire [31:0] axi_req_rdata;
  wire        axi_req_error;

  wire [31:0] csr_rdata;
  wire [31:0] mtvec;
  wire [31:0] mepc;
  wire [31:0] mcause;
  wire [31:0] mstatus;
  wire [31:0] wb_data;

  // -------------------------------------------------------------------------
  // Stage validity
  // -------------------------------------------------------------------------
  assign x_valid = dx_valid;
  assign x_pc = dx_pc;
  assign x_rs1_data = dx_rs1_data;
  assign x_rs2_data = dx_rs2_data;
  assign x_imm = dx_imm;

  // -------------------------------------------------------------------------
  // Decode and immediate extraction in D stage
  // -------------------------------------------------------------------------
  assign imm_data = (imm_sel == `NPC_IMM_S) ? imm_s :
                    (imm_sel == `NPC_IMM_B) ? imm_b :
                    (imm_sel == `NPC_IMM_U) ? imm_u :
                    (imm_sel == `NPC_IMM_J) ? imm_j : imm_i;

  // Branch/jump immediates are extracted from the stored instruction in X.
  // These are pure bit-slicing with no logic delay.
  assign x_imm_b = {{20{dx_inst[31]}}, dx_inst[7], dx_inst[30:25], dx_inst[11:8], 1'b0};
  assign x_imm_j = {{12{dx_inst[31]}}, dx_inst[19:12], dx_inst[20], dx_inst[30:21], 1'b0};

  // -------------------------------------------------------------------------
  // D-stage operand forwarding from W stage
  // -------------------------------------------------------------------------
  assign d_rs1_data = (w_can_forward && w_rs1_match) ? w_forward_data : rf_rs1_data;
  assign d_rs2_data = (w_can_forward && w_rs2_match) ? w_forward_data : rf_rs2_data;

  // -------------------------------------------------------------------------
  // X-stage ALU inputs
  // -------------------------------------------------------------------------
  assign x_alu_src1 = dx_src1_pc ? x_pc : x_rs1_data;
  // Branches must compare rs1 against rs2, not the I-immediate.
  assign x_alu_src2 = (dx_branch_op != `NPC_BR_NONE) ? x_rs2_data :
                      (dx_src2_imm ? x_imm : x_rs2_data);

  // -------------------------------------------------------------------------
  // X-stage shared adder: one 32-bit adder serves ALU ADD/SUB, LSU address,
  // branch target, jal target, and jalr target.  The select signals all come
  // from the registered D/X control word.
  // -------------------------------------------------------------------------
  assign adder_src1 = (dx_branch_op != `NPC_BR_NONE) ? x_pc :
                      (dx_is_jal) ? x_pc :
                      (dx_is_jalr) ? x_rs1_data :
                      (dx_mem_ren || dx_mem_wen) ? x_rs1_data : x_alu_src1;
  assign adder_src2 = (dx_branch_op != `NPC_BR_NONE) ? x_imm_b :
                      (dx_is_jal) ? x_imm_j :
                      (dx_is_jalr) ? x_imm :
                      (dx_mem_ren || dx_mem_wen) ? x_imm : x_alu_src2;
  assign adder_sub = (dx_alu_op == `NPC_ALU_SUB);
  assign adder_result = adder_sub ? (adder_src1 - adder_src2) : (adder_src1 + adder_src2);

  // ALU uses the shared adder for ADD/SUB; other operations come from Exu.
  assign x_alu_result = (dx_alu_op == `NPC_ALU_ADD || dx_alu_op == `NPC_ALU_SUB) ?
                        adder_result : exu_result;

  assign x_lsu_addr = adder_result;
  assign x_branch_target = adder_result;
  assign x_jal_target = adder_result;
  assign x_jalr_target = adder_result & ~32'd1;

  // -------------------------------------------------------------------------
  // Branch comparison and redirect (resolved in X stage)
  // -------------------------------------------------------------------------
  assign x_branch_taken = (dx_branch_op == `NPC_BR_BEQ)  ? x_alu_equal :
                          (dx_branch_op == `NPC_BR_BNE)  ? !x_alu_equal :
                          (dx_branch_op == `NPC_BR_BLT)  ? x_alu_less_signed :
                          (dx_branch_op == `NPC_BR_BGE)  ? !x_alu_less_signed :
                          (dx_branch_op == `NPC_BR_BLTU) ? x_alu_less_unsigned :
                          (dx_branch_op == `NPC_BR_BGEU) ? !x_alu_less_unsigned : 1'b0;
  assign x_redirect = x_valid && (dx_is_mret || dx_is_jalr || dx_is_jal || x_branch_taken);
  assign x_redirect_pc = dx_is_mret ? mepc :
                         (dx_is_jalr ? x_jalr_target :
                          (dx_is_jal ? x_jal_target : x_branch_target));

  // -------------------------------------------------------------------------
  // X-stage exception pre-computation
  // -------------------------------------------------------------------------
  assign x_mem_half_misaligned = dx_mem_size == `NPC_MEM_HALF && x_lsu_addr[0] != 1'b0;
  assign x_mem_word_misaligned = dx_mem_size == `NPC_MEM_WORD && x_lsu_addr[1:0] != 2'b00;
  assign x_mem_misaligned = (dx_mem_ren || dx_mem_wen) && (x_mem_half_misaligned || x_mem_word_misaligned);
  assign x_pc_exception = dx_decode_legal &&
                          ((x_branch_taken && x_branch_target[1:0] != 2'b00) ||
                           (dx_is_jal && x_jal_target[1:0] != 2'b00) ||
                           (dx_is_jalr && x_jalr_target[1:0] != 2'b00));

  // -------------------------------------------------------------------------
  // W-stage control
  // -------------------------------------------------------------------------
  wire        w_base_trap_request = xw_inst_error || !xw_decode_legal || xw_pc_exception ||
                                    xw_mem_misaligned || xw_is_ecall || xw_is_ebreak;
  wire        w_can_complete_no_mem_fault = xw_valid && !xw_inst_error && xw_decode_legal &&
                                            !xw_mem_misaligned && !xw_pc_exception && !xw_is_ecall &&
                                            !(w_base_trap_request && mtvec != 32'd0);
  wire        w_mem_access = w_can_complete_no_mem_fault && (xw_mem_ren || xw_mem_wen);
  wire        w_mem_access_fault = w_mem_access && lsu_raw_ready && lsu_raw_error;
  wire        w_trap_request = w_base_trap_request || w_mem_access_fault;
  wire        w_precise_trap = w_trap_request && mtvec != 32'd0;
  wire        w_bad_without_vector = w_trap_request && mtvec == 32'd0;
  wire        w_complete_inst = w_can_complete_no_mem_fault && !w_mem_access_fault;
  wire        w_mem_ready = !w_mem_access || lsu_raw_ready;
  wire        w_retire_ready = !reset && !halted && xw_valid && w_mem_ready;
  wire        w_wb_wen = w_complete_inst && w_mem_ready && xw_writes_rd &&
                         xw_rd != 5'd0 && !xw_is_mret;
  wire        w_lsu_wen = w_can_complete_no_mem_fault && xw_mem_wen;
  wire [31:0] w_exception_cause = xw_inst_error ? {27'd0, `NPC_EXC_INST_ACCESS_FAULT} :
                                  !xw_decode_legal ? {27'd0, `NPC_EXC_ILLEGAL_INST} :
                                  xw_pc_exception ? {27'd0, `NPC_EXC_INST_ADDR_MISALIGNED} :
                                  (xw_mem_ren && xw_mem_misaligned) ? {27'd0, `NPC_EXC_LOAD_ADDR_MISALIGNED} :
                                  (xw_mem_wen && xw_mem_misaligned) ? {27'd0, `NPC_EXC_STORE_ADDR_MISALIGNED} :
                                  (xw_mem_ren && w_mem_access_fault) ? {27'd0, `NPC_EXC_LOAD_ACCESS_FAULT} :
                                  (xw_mem_wen && w_mem_access_fault) ? {27'd0, `NPC_EXC_STORE_ACCESS_FAULT} :
                                  xw_is_ecall ? {27'd0, `NPC_EXC_ECALL_M} :
                                  xw_is_ebreak ? {27'd0, `NPC_EXC_BREAKPOINT} : 32'd0;
  wire [31:0] w_pc_plus_4 = xw_pc + 32'd4;
  wire [31:0] w_next_pc = w_precise_trap ? mtvec : (w_bad_without_vector ? xw_pc : w_pc_plus_4);
  wire [31:0] w_wb_mux = (xw_wb_sel == `NPC_WB_MEM) ? lsu_rdata :
                         ((xw_wb_sel == `NPC_WB_PC4) ? w_pc_plus_4 :
                          ((xw_wb_sel == `NPC_WB_CSR) ? xw_csr_rdata : xw_alu_result));
  assign wb_data = w_wb_mux;
  wire [31:0] w_forward_data = w_wb_mux;
  wire        w_can_forward = xw_valid && w_wb_wen;
  wire        w_rs1_match = reads_rs1 && xw_rd == rs1;
  wire        w_rs2_match = reads_rs2 && xw_rd == rs2;

  // -------------------------------------------------------------------------
  // Pipeline stall / advancement control
  // -------------------------------------------------------------------------
  wire        w_load_waiting = xw_valid && xw_mem_ren && !w_mem_ready;
  wire        load_use_stall = w_load_waiting && xw_writes_rd && (w_rs1_match || w_rs2_match);
  wire        w_stage_stall = xw_valid && !w_mem_ready;
  wire        x_can_advance = x_valid && !w_stage_stall && (!xw_valid || w_retire_ready);
  wire        d_can_advance = fd_valid && !w_stage_stall && !load_use_stall && (!x_valid || x_can_advance);
  wire        fd_can_accept = !fd_valid || d_can_advance;
  wire        w_redirect = w_retire_ready && (w_precise_trap || w_bad_without_vector ||
                                             (w_complete_inst && xw_is_fence_i));
  wire        redirect = x_redirect || w_redirect;

  // -------------------------------------------------------------------------
  // IFU interface
  // -------------------------------------------------------------------------
  wire        ifu_bus_valid;
  wire [31:0] ifu_bus_addr;
  wire [7:0]  ifu_bus_len;
  wire        ifu_bus_ready;
  wire [31:0] ifu_bus_rdata;
  wire        ifu_bus_error;
  wire        ifu_inst_ready;
  wire [31:0] ifu_inst;
  wire        ifu_inst_error;

  wire        ifu_fetch_valid = !halted && !reset && !fd_valid && !drop_fetch_response && !redirect;
  wire        ifu_invalidate = w_retire_ready && w_complete_inst && xw_is_fence_i;

  // -------------------------------------------------------------------------
  // LSU / CLINT / AXI wiring (now driven from W stage)
  // -------------------------------------------------------------------------
  assign lsu_is_clint = lsu_raw_valid && (lsu_raw_addr[31:16] == 16'h0200);
  assign lsu_arb_valid = lsu_raw_valid && !lsu_is_clint;
  assign lsu_raw_ready = lsu_is_clint ? clint_ready : lsu_arb_ready;
  assign lsu_raw_rdata = lsu_is_clint ? clint_rdata : lsu_arb_rdata;
  assign lsu_raw_error = lsu_is_clint ? clint_error : lsu_arb_error;

  // -------------------------------------------------------------------------
  // Debug / commit outputs (NPC_DEBUG only)
  // -------------------------------------------------------------------------
`ifdef NPC_DEBUG
  assign debug_pc = xw_valid ? xw_pc : (dx_valid ? dx_pc : (fd_valid ? fd_pc : f_pc));
  assign debug_halted = halted;
  assign debug_trap_status = trap_status;
  assign debug_inst = xw_valid ? xw_inst : (dx_valid ? dx_inst : (fd_valid ? fd_inst : 32'd0));
  assign debug_mstatus = mstatus;
  assign debug_mtvec = mtvec;
  assign debug_mepc = mepc;
  assign debug_mcause = mcause;
  assign commit_valid = w_retire_ready;
  assign commit_pc = xw_pc;
  assign commit_inst = xw_inst;
  assign commit_next_pc = xw_redirect ? xw_redirect_pc : w_next_pc;
  assign commit_wen = w_wb_wen;
  assign commit_rd = xw_rd;
  assign commit_wdata = wb_data;
  assign commit_exception = w_bad_without_vector || xw_inst_error || w_mem_access_fault;
  assign commit_cause = w_exception_cause;
  assign commit_mem_wen = w_retire_ready && w_lsu_wen;
  assign commit_mem_ren = w_retire_ready && w_complete_inst && xw_mem_ren;
  assign commit_mem_addr = lsu_write_addr;
  assign commit_mem_wdata = lsu_write_data;
  assign commit_mem_wmask = lsu_write_mask;
  assign commit_mem_rdata = lsu_rdata;
`else
  assign debug_pc = 32'd0;
  assign debug_halted = 1'b0;
  assign debug_trap_status = `NPC_STATUS_RUNNING;
  assign debug_inst = 32'd0;
  assign debug_mstatus = 32'd0;
  assign debug_mtvec = 32'd0;
  assign debug_mepc = 32'd0;
  assign debug_mcause = 32'd0;
  assign commit_valid = 1'b0;
  assign commit_pc = 32'd0;
  assign commit_inst = 32'd0;
  assign commit_next_pc = 32'd0;
  assign commit_wen = 1'b0;
  assign commit_rd = 5'd0;
  assign commit_wdata = 32'd0;
  assign commit_exception = 1'b0;
  assign commit_cause = 32'd0;
  assign commit_mem_wen = 1'b0;
  assign commit_mem_ren = 1'b0;
  assign commit_mem_addr = 32'd0;
  assign commit_mem_wdata = 32'd0;
  assign commit_mem_wmask = 4'd0;
  assign commit_mem_rdata = 32'd0;
`endif

  // -------------------------------------------------------------------------
  // Submodules
  // -------------------------------------------------------------------------
  Ifu u_ifu (
    .clock(clock),
    .reset(reset),
    .invalidate(ifu_invalidate),
    .fetch_valid(ifu_fetch_valid),
    .pc(f_pc),
    .bus_ready(ifu_bus_ready),
    .bus_rdata(ifu_bus_rdata),
    .bus_error(ifu_bus_error),
    .bus_valid(ifu_bus_valid),
    .bus_addr(ifu_bus_addr),
    .bus_len(ifu_bus_len),
    .inst_ready(ifu_inst_ready),
    .inst(ifu_inst),
    .inst_error(ifu_inst_error),
    .debug_accesses(debug_icache_accesses),
    .debug_hits(debug_icache_hits),
    .debug_misses(debug_icache_misses),
    .debug_miss_wait_cycles(debug_icache_miss_wait_cycles),
    .debug_refill_beats(debug_icache_refill_beats)
  );

  Idu u_idu (
    .inst(fd_inst),
    .opcode(opcode),
    .rd(rd),
    .funct3(funct3),
    .rs1(rs1),
    .rs2(rs2),
    .funct7(funct7),
    .imm_i(imm_i),
    .imm_s(imm_s),
    .imm_b(imm_b),
    .imm_u(imm_u),
    .imm_j(imm_j),
    .csr_addr(csr_addr),
    .csr_uimm(csr_uimm),
    .alu_op(alu_op),
    .imm_sel(imm_sel),
    .wb_sel(wb_sel),
    .src1_pc(src1_pc),
    .src2_imm(src2_imm),
    .mem_ren(mem_ren),
    .mem_wen(mem_wen),
    .mem_size(mem_size),
    .mem_unsigned(mem_unsigned),
    .csr_cmd(csr_cmd),
    .sys_cmd(sys_cmd),
    .branch_op(branch_op),
    .reads_rs1(reads_rs1),
    .reads_rs2(reads_rs2),
    .writes_rd(writes_rd),
    .is_jal(is_jal),
    .is_jalr(is_jalr),
    .is_legal(is_legal)
  );

  RegFile u_regfile (
    .clock(clock),
    .reset(reset),
    .raddr1(rs1[3:0]),
    .raddr2(rs2[3:0]),
    .rdata1(rf_rs1_data),
    .rdata2(rf_rs2_data),
    .wen(!reset && !halted && w_wb_wen),
    .waddr(xw_rd[3:0]),
    .wdata(wb_data),
    .debug_x1(debug_x1),
    .debug_a0(debug_a0),
    .debug_regs_flat(debug_regs_flat)
  );

  Exu u_exu (
    .alu_op(dx_alu_op),
    .src1(x_alu_src1),
    .src2(x_alu_src2),
    .result(exu_result),
    .equal(x_alu_equal),
    .less_signed(x_alu_less_signed),
    .less_unsigned(x_alu_less_unsigned)
  );

  Lsu u_lsu (
    .ren(!reset && !halted && w_can_complete_no_mem_fault && xw_mem_ren),
    .wen(!reset && !halted && w_lsu_wen),
    .size(xw_mem_size),
    .load_unsigned(xw_mem_unsigned),
    .addr(xw_lsu_addr),
    .wdata(xw_rs2_data),
    .bus_ready(lsu_raw_ready),
    .bus_rdata(lsu_raw_rdata),
    .bus_valid(lsu_raw_valid),
    .bus_write(lsu_raw_write),
    .bus_addr(lsu_raw_addr),
    .bus_wdata(lsu_raw_wdata),
    .bus_wmask(lsu_raw_wmask),
    .rdata(lsu_rdata),
    .write_addr(lsu_write_addr),
    .write_data(lsu_write_data),
    .write_mask(lsu_write_mask)
  );

  Clint u_clint (
    .clock(clock),
    .reset(reset),
    .valid(lsu_is_clint),
    .write(lsu_raw_write),
    .addr(lsu_raw_addr),
    .wdata(lsu_raw_wdata),
    .wmask(lsu_raw_wmask),
    .ready(clint_ready),
    .rdata(clint_rdata),
    .error(clint_error)
  );

  AxiArbiter u_axi_arbiter (
    .ifu_valid(ifu_bus_valid),
    .ifu_addr(ifu_bus_addr),
    .ifu_len(ifu_bus_len),
    .ifu_ready(ifu_bus_ready),
    .ifu_rdata(ifu_bus_rdata),
    .ifu_error(ifu_bus_error),
    .lsu_valid(lsu_arb_valid),
    .lsu_write(lsu_raw_write),
    .lsu_addr(lsu_raw_addr),
    .lsu_wdata(lsu_raw_wdata),
    .lsu_wmask(lsu_raw_wmask),
    .lsu_ready(lsu_arb_ready),
    .lsu_rdata(lsu_arb_rdata),
    .lsu_error(lsu_arb_error),
    .bus_valid(axi_req_valid),
    .bus_write(axi_req_write),
    .bus_addr(axi_req_addr),
    .bus_len(axi_req_len),
    .bus_wdata(axi_req_wdata),
    .bus_wmask(axi_req_wmask),
    .bus_ready(axi_req_ready),
    .bus_rdata(axi_req_rdata),
    .bus_error(axi_req_error)
  );

  AxiMaster u_axi_master (
    .clock(clock),
    .reset(reset),
    .req_valid(axi_req_valid),
    .req_write(axi_req_write),
    .req_addr(axi_req_addr),
    .req_len(axi_req_len),
    .req_wdata(axi_req_wdata),
    .req_wmask(axi_req_wmask),
    .req_ready(axi_req_ready),
    .req_rdata(axi_req_rdata),
    .req_error(axi_req_error),
    .axi_awready(axi_awready),
    .axi_awvalid(axi_awvalid),
    .axi_awaddr(axi_awaddr),
    .axi_awid(axi_awid),
    .axi_awlen(axi_awlen),
    .axi_awsize(axi_awsize),
    .axi_awburst(axi_awburst),
    .axi_wready(axi_wready),
    .axi_wvalid(axi_wvalid),
    .axi_wdata(axi_wdata),
    .axi_wstrb(axi_wstrb),
    .axi_wlast(axi_wlast),
    .axi_bready(axi_bready),
    .axi_bvalid(axi_bvalid),
    .axi_bresp(axi_bresp),
    .axi_bid(axi_bid),
    .axi_arready(axi_arready),
    .axi_arvalid(axi_arvalid),
    .axi_araddr(axi_araddr),
    .axi_arid(axi_arid),
    .axi_arlen(axi_arlen),
    .axi_arsize(axi_arsize),
    .axi_arburst(axi_arburst),
    .axi_rready(axi_rready),
    .axi_rvalid(axi_rvalid),
    .axi_rresp(axi_rresp),
    .axi_rdata(axi_rdata),
    .axi_rlast(axi_rlast),
    .axi_rid(axi_rid)
  );

  Csr u_csr (
    .clock(clock),
    .reset(reset),
    .addr(x_valid ? dx_csr_addr : xw_csr_addr),
    .cmd(x_valid ? dx_csr_cmd : xw_csr_cmd),
    .rs1_data(x_valid ? x_rs1_data : xw_rs1_data),
    .uimm(x_valid ? dx_csr_uimm : xw_csr_uimm),
    .commit_en(w_retire_ready && w_complete_inst && xw_csr_cmd != `NPC_CSR_NONE),
    .trap_en(w_retire_ready && w_precise_trap),
    .trap_pc(xw_pc),
    .trap_cause(w_exception_cause),
    .rdata(csr_rdata),
    .mtvec(mtvec),
    .mepc(mepc),
    .mcause(mcause),
    .mstatus(mstatus)
  );

  // -------------------------------------------------------------------------
  // Sequential pipeline update
  // -------------------------------------------------------------------------
  always @(posedge clock) begin
    if (reset) begin
      halted <= 1'b0;
      trap_status <= `NPC_STATUS_RUNNING;
      f_pc <= reset_vector;
      ifu_pending <= 1'b0;
      drop_fetch_response <= 1'b0;
      fd_valid <= 1'b0;
      dx_valid <= 1'b0;
      xw_valid <= 1'b0;
    end else begin
      // IFU pending tracking
      if (ifu_inst_ready) begin
        ifu_pending <= 1'b0;
      end else if (ifu_fetch_valid) begin
        ifu_pending <= 1'b1;
      end

      // Redirect: W-stage traps / fence.i have priority over X-stage branches.
      if (w_redirect) begin
        f_pc <= w_next_pc;
        fd_valid <= 1'b0;
        dx_valid <= 1'b0;
        xw_valid <= 1'b0;
        drop_fetch_response <= ifu_pending && !ifu_inst_ready;
      end else if (x_redirect) begin
        f_pc <= x_redirect_pc;
        fd_valid <= 1'b0;
        dx_valid <= 1'b0;
        drop_fetch_response <= ifu_pending && !ifu_inst_ready;
      end else if (ifu_inst_ready && drop_fetch_response) begin
        drop_fetch_response <= 1'b0;
      end else if (ifu_inst_ready && fd_can_accept) begin
        fd_valid <= 1'b1;
        fd_pc <= f_pc;
        fd_inst <= ifu_inst;
        fd_inst_error <= ifu_inst_error;
        f_pc <= f_pc + 32'd4;
      end else if (d_can_advance) begin
        fd_valid <= 1'b0;
      end

      // Halt on bad trap without vector
      if (!halted && w_retire_ready && w_bad_without_vector) begin
        halted <= 1'b1;
        trap_status <= `NPC_STATUS_BAD;
      end

      // D/X boundary update
      if (w_redirect || x_redirect) begin
        dx_valid <= 1'b0;
      end else if (w_stage_stall || load_use_stall) begin
        dx_valid <= dx_valid;
      end else if (d_can_advance) begin
        dx_valid <= 1'b1;
        dx_pc <= fd_pc;
        dx_inst <= fd_inst;
        dx_inst_error <= fd_inst_error;
        dx_rd <= rd;
        dx_writes_rd <= writes_rd;
        dx_wb_sel <= wb_sel;
        dx_mem_ren <= mem_ren;
        dx_mem_wen <= mem_wen;
        dx_mem_size <= mem_size;
        dx_mem_unsigned <= mem_unsigned;
        dx_csr_cmd <= csr_cmd;
        dx_csr_addr <= csr_addr;
        dx_csr_uimm <= csr_uimm;
        dx_rs1_data <= d_rs1_data;
        dx_rs2_data <= d_rs2_data;
        dx_imm <= imm_data;
        dx_alu_op <= alu_op;
        dx_branch_op <= branch_op;
        dx_src1_pc <= src1_pc;
        dx_src2_imm <= src2_imm;
        dx_is_jal <= is_jal;
        dx_is_jalr <= is_jalr;
        dx_is_mret <= sys_cmd == `NPC_SYS_MRET;
        dx_is_fence_i <= sys_cmd == `NPC_SYS_FENCE_I;
        dx_decode_legal <= is_legal && rd_valid && rs1_valid && rs2_valid;
        dx_is_ecall <= sys_cmd == `NPC_SYS_ECALL;
        dx_is_ebreak <= sys_cmd == `NPC_SYS_EBREAK;
      end else if (x_can_advance) begin
        dx_valid <= 1'b0;
      end

      // X/W boundary update
      if (w_redirect) begin
        xw_valid <= 1'b0;
      end else if (w_stage_stall) begin
        xw_valid <= xw_valid;
      end else if (x_can_advance) begin
        xw_valid <= 1'b1;
        xw_pc <= x_pc;
`ifdef NPC_DEBUG
        xw_inst <= dx_inst;
        xw_redirect <= x_redirect;
        xw_redirect_pc <= x_redirect_pc;
`endif
        xw_inst_error <= dx_inst_error;
        xw_rd <= dx_rd;
        xw_writes_rd <= dx_writes_rd;
        xw_wb_sel <= dx_wb_sel;
        xw_mem_ren <= dx_mem_ren;
        xw_mem_wen <= dx_mem_wen;
        xw_mem_size <= dx_mem_size;
        xw_mem_unsigned <= dx_mem_unsigned;
        xw_csr_cmd <= dx_csr_cmd;
        xw_csr_addr <= dx_csr_addr;
        xw_csr_uimm <= dx_csr_uimm;
        xw_csr_rdata <= csr_rdata;
        xw_rs1_data <= x_rs1_data;
        xw_rs2_data <= x_rs2_data;
        xw_alu_result <= x_alu_result;
        xw_lsu_addr <= x_lsu_addr;
        xw_is_mret <= dx_is_mret;
        xw_is_fence_i <= dx_is_fence_i;
        xw_decode_legal <= dx_decode_legal;
        xw_pc_exception <= x_pc_exception;
        xw_mem_misaligned <= x_mem_misaligned;
        xw_is_ecall <= dx_is_ecall;
        xw_is_ebreak <= dx_is_ebreak;
      end else if (w_retire_ready) begin
        xw_valid <= 1'b0;
      end
    end
  end

  // -------------------------------------------------------------------------
  // D-stage decode legality helper
  // -------------------------------------------------------------------------
  wire        rd_is_rv32e = rd[4] == 1'b0;
  wire        rs1_is_rv32e = rs1[4] == 1'b0;
  wire        rs2_is_rv32e = rs2[4] == 1'b0;
  wire        rd_valid = !writes_rd || rd_is_rv32e;
  wire        rs1_valid = !reads_rs1 || rs1_is_rv32e;
  wire        rs2_valid = !reads_rs2 || rs2_is_rv32e;

`ifdef NPC_DEBUG
  wire unused = |{opcode, funct3, funct7, mcause, mstatus, trap_status};
`else
  wire unused = |{opcode, funct3, funct7, mcause, mstatus, trap_status,
                 lsu_write_addr, lsu_write_data, lsu_write_mask, dx_inst[6:0]};
`endif

endmodule
