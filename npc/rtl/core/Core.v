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

  reg [31:0] f_pc;
  reg        ifu_pending;
  reg        drop_fetch_response;

  reg        fx_valid;
  reg [31:0] fx_pc;
  reg [31:0] fx_inst;
  reg        fx_inst_error;

  reg        xc_valid;
  reg [31:0] xc_pc;
`ifdef NPC_DEBUG
  reg [31:0] xc_inst;
`endif
  reg        xc_inst_error;
  reg [4:0]  xc_rd;
  reg        xc_writes_rd;
  reg [1:0]  xc_wb_sel;
  reg        xc_mem_ren;
  reg        xc_mem_wen;
  reg [1:0]  xc_mem_size;
  reg        xc_mem_unsigned;
  reg [2:0]  xc_csr_cmd;
  reg [11:0] xc_csr_addr;
  reg [4:0]  xc_csr_uimm;
  reg [31:0] xc_csr_rdata;
  reg [31:0] xc_rs1_data;
  reg [31:0] xc_rs2_data;
  reg [31:0] xc_alu_result;
  reg [31:0] xc_lsu_addr;
  reg [31:0] xc_normal_next_pc;
  reg        xc_is_mret;
  reg        xc_is_fence_i;
  reg        xc_decode_legal;
  reg        xc_pc_exception;
  reg        xc_mem_misaligned;
  reg        xc_is_ecall;
  reg        xc_is_ebreak;

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

  wire [31:0] rf_rs1_data;
  wire [31:0] rf_rs2_data;
  wire [31:0] x_rs1_data;
  wire [31:0] x_rs2_data;
  wire [31:0] x_pc;
  wire [31:0] x_inst;
  wire        x_inst_error;
  wire        x_valid;
  wire [31:0] imm_data;
  wire [31:0] alu_src1;
  wire [31:0] alu_src2;
  wire [31:0] alu_result;

  wire        ifu_bus_valid;
  wire [31:0] ifu_bus_addr;
  wire [7:0]  ifu_bus_len;
  wire        ifu_bus_ready;
  wire [31:0] ifu_bus_rdata;
  wire        ifu_bus_error;
  wire        ifu_inst_ready;
  wire [31:0] ifu_inst;
  wire        ifu_inst_error;

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

  assign x_valid = fx_valid;
  assign x_pc = fx_pc;
  assign x_inst = fx_inst;
  assign x_inst_error = fx_inst_error;

  wire        rd_is_rv32e = rd[4] == 1'b0;
  wire        rs1_is_rv32e = rs1[4] == 1'b0;
  wire        rs2_is_rv32e = rs2[4] == 1'b0;
  wire        rd_valid = !writes_rd || rd_is_rv32e;
  wire        rs1_valid = !reads_rs1 || rs1_is_rv32e;
  wire        rs2_valid = !reads_rs2 || rs2_is_rv32e;
  wire        decode_legal = is_legal && rd_valid && rs1_valid && rs2_valid;
  wire        x_is_ecall = sys_cmd == `NPC_SYS_ECALL;
  wire        x_is_ebreak = sys_cmd == `NPC_SYS_EBREAK;
  wire        x_is_mret = sys_cmd == `NPC_SYS_MRET;
  wire        x_is_fence_i = sys_cmd == `NPC_SYS_FENCE_I;
  wire [31:0] x_pc_plus_4 = x_pc + 32'd4;
  wire        branch_taken = (branch_op == `NPC_BR_BEQ)  ? (x_rs1_data == x_rs2_data) :
                             (branch_op == `NPC_BR_BNE)  ? (x_rs1_data != x_rs2_data) :
                             (branch_op == `NPC_BR_BLT)  ? ($signed(x_rs1_data) < $signed(x_rs2_data)) :
                             (branch_op == `NPC_BR_BGE)  ? ($signed(x_rs1_data) >= $signed(x_rs2_data)) :
                             (branch_op == `NPC_BR_BLTU) ? (x_rs1_data < x_rs2_data) :
                             (branch_op == `NPC_BR_BGEU) ? (x_rs1_data >= x_rs2_data) : 1'b0;
  wire [31:0] jalr_target = (x_rs1_data + imm_i) & ~32'd1;
  wire [31:0] jal_target = x_pc + imm_j;
  wire [31:0] branch_target = x_pc + imm_b;
  wire [31:0] x_normal_next_pc = x_is_mret ? mepc :
                                  (is_jalr ? jalr_target :
                                   (is_jal ? jal_target :
                                    (branch_taken ? branch_target : x_pc_plus_4)));
  wire [31:0] x_lsu_addr = x_rs1_data + (mem_wen ? imm_s : imm_i);
  wire        branch_target_misaligned = branch_taken && branch_target[1:0] != 2'b00;
  wire        jal_target_misaligned = is_jal && jal_target[1:0] != 2'b00;
  wire        jalr_target_misaligned = is_jalr && jalr_target[1:0] != 2'b00;
  wire        x_pc_exception = decode_legal && (branch_target_misaligned || jal_target_misaligned || jalr_target_misaligned);
  wire        x_mem_half_misaligned = mem_size == `NPC_MEM_HALF && x_lsu_addr[0] != 1'b0;
  wire        x_mem_word_misaligned = mem_size == `NPC_MEM_WORD && x_lsu_addr[1:0] != 2'b00;
  wire        x_mem_misaligned = (mem_ren || mem_wen) && (x_mem_half_misaligned || x_mem_word_misaligned);

  wire        c_base_trap_request = xc_inst_error || !xc_decode_legal || xc_pc_exception ||
                                    xc_mem_misaligned || xc_is_ecall || xc_is_ebreak;
  wire        c_can_complete_no_mem_fault = xc_valid && !xc_inst_error && xc_decode_legal &&
                                            !xc_mem_misaligned && !xc_pc_exception && !xc_is_ecall &&
                                            !(c_base_trap_request && mtvec != 32'd0);
  wire        c_mem_access = c_can_complete_no_mem_fault && (xc_mem_ren || xc_mem_wen);
  wire        c_mem_access_fault = c_mem_access && lsu_raw_ready && lsu_raw_error;
  wire        c_trap_request = c_base_trap_request || c_mem_access_fault;
  wire        c_precise_trap = c_trap_request && mtvec != 32'd0;
  wire        c_bad_without_vector = c_trap_request && mtvec == 32'd0;
  wire        c_complete_inst = c_can_complete_no_mem_fault && !c_mem_access_fault;
  wire        c_mem_ready = !c_mem_access || lsu_raw_ready;
  wire        c_retire_ready = !reset && !halted && xc_valid && c_mem_ready;
  // Qualify the writeback enable with xc_rd != 0 so that instructions with
  // rd=x0 never forward and never assert the register-file write enable.  This
  // lets the forwarding match drop its explicit rs1/rs2 != 0 term, slightly
  // shortening the dependency-check path.
  wire        c_wb_wen = c_complete_inst && c_mem_ready && xc_writes_rd &&
                         xc_rd != 5'd0 && !xc_is_mret;
  wire        c_lsu_wen = c_can_complete_no_mem_fault && xc_mem_wen;
  wire [31:0] c_exception_cause = xc_inst_error ? {27'd0, `NPC_EXC_INST_ACCESS_FAULT} :
                                  !xc_decode_legal ? {27'd0, `NPC_EXC_ILLEGAL_INST} :
                                  xc_pc_exception ? {27'd0, `NPC_EXC_INST_ADDR_MISALIGNED} :
                                  (xc_mem_ren && xc_mem_misaligned) ? {27'd0, `NPC_EXC_LOAD_ADDR_MISALIGNED} :
                                  (xc_mem_wen && xc_mem_misaligned) ? {27'd0, `NPC_EXC_STORE_ADDR_MISALIGNED} :
                                  (xc_mem_ren && c_mem_access_fault) ? {27'd0, `NPC_EXC_LOAD_ACCESS_FAULT} :
                                  (xc_mem_wen && c_mem_access_fault) ? {27'd0, `NPC_EXC_STORE_ACCESS_FAULT} :
                                  xc_is_ecall ? {27'd0, `NPC_EXC_ECALL_M} :
                                  xc_is_ebreak ? {27'd0, `NPC_EXC_BREAKPOINT} : 32'd0;
  wire [31:0] c_pc_plus_4 = xc_pc + 32'd4;
  wire [31:0] c_next_pc = c_precise_trap ? mtvec : (c_bad_without_vector ? xc_pc : xc_normal_next_pc);
  wire [31:0] c_wb_mux = (xc_wb_sel == `NPC_WB_MEM) ? lsu_rdata :
                         ((xc_wb_sel == `NPC_WB_PC4) ? c_pc_plus_4 :
                          ((xc_wb_sel == `NPC_WB_CSR) ? xc_csr_rdata : xc_alu_result));
  wire [31:0] c_forward_data = c_wb_mux;
  wire        c_can_forward = xc_valid && c_wb_wen;
  wire        c_rs1_match = reads_rs1 && xc_rd == rs1;
  wire        c_rs2_match = reads_rs2 && xc_rd == rs2;
  wire        c_load_waiting = xc_valid && xc_mem_ren && !c_mem_ready;
  wire        load_use_stall = c_load_waiting && xc_writes_rd && (c_rs1_match || c_rs2_match);
  wire        c_stage_stall = xc_valid && !c_mem_ready;
  wire        x_can_advance = x_valid && !c_stage_stall && !load_use_stall && (!xc_valid || c_retire_ready);
  wire        fx_can_accept = !fx_valid || x_can_advance || (c_retire_ready && c_next_pc != c_pc_plus_4);
  wire        redirect = c_retire_ready && (c_precise_trap || c_bad_without_vector || c_next_pc != c_pc_plus_4 || (c_complete_inst && xc_is_fence_i));
  wire        ifu_fetch_valid = !halted && !reset && !fx_valid && !drop_fetch_response && !redirect;
  wire        ifu_invalidate = c_retire_ready && c_complete_inst && xc_is_fence_i;

  assign lsu_is_clint = lsu_raw_valid && (lsu_raw_addr[31:16] == 16'h0200);
  assign lsu_arb_valid = lsu_raw_valid && !lsu_is_clint;
  assign lsu_raw_ready = lsu_is_clint ? clint_ready : lsu_arb_ready;
  assign lsu_raw_rdata = lsu_is_clint ? clint_rdata : lsu_arb_rdata;
  assign lsu_raw_error = lsu_is_clint ? clint_error : lsu_arb_error;

  assign imm_data = (imm_sel == `NPC_IMM_S) ? imm_s :
                    (imm_sel == `NPC_IMM_B) ? imm_b :
                    (imm_sel == `NPC_IMM_U) ? imm_u :
                    (imm_sel == `NPC_IMM_J) ? imm_j : imm_i;
  assign alu_src1 = src1_pc ? x_pc : x_rs1_data;
  assign alu_src2 = src2_imm ? imm_data : x_rs2_data;
  assign x_rs1_data = (c_can_forward && c_rs1_match) ? c_forward_data : rf_rs1_data;
  assign x_rs2_data = (c_can_forward && c_rs2_match) ? c_forward_data : rf_rs2_data;

`ifdef NPC_DEBUG
  assign debug_pc = xc_valid ? xc_pc : (fx_valid ? fx_pc : f_pc);
  assign debug_halted = halted;
  assign debug_trap_status = trap_status;
  assign debug_inst = xc_valid ? xc_inst : (fx_valid ? fx_inst : 32'd0);
  assign debug_mstatus = mstatus;
  assign debug_mtvec = mtvec;
  assign debug_mepc = mepc;
  assign debug_mcause = mcause;
  assign commit_valid = c_retire_ready;
  assign commit_pc = xc_pc;
  assign commit_inst = xc_inst;
  assign commit_next_pc = c_next_pc;
  assign commit_wen = c_wb_wen;
  assign commit_rd = xc_rd;
  assign commit_wdata = wb_data;
  assign commit_exception = c_bad_without_vector || xc_inst_error || c_mem_access_fault;
  assign commit_cause = c_exception_cause;
  assign commit_mem_wen = c_retire_ready && c_lsu_wen;
  assign commit_mem_ren = c_retire_ready && c_complete_inst && xc_mem_ren;
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
    .inst(x_inst),
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
    .wen(!reset && !halted && c_wb_wen),
    .waddr(xc_rd[3:0]),
    .wdata(wb_data),
    .debug_x1(debug_x1),
    .debug_a0(debug_a0),
    .debug_regs_flat(debug_regs_flat)
  );

  Exu u_exu (
    .alu_op(alu_op),
    .src1(alu_src1),
    .src2(alu_src2),
    .result(alu_result)
  );

  Lsu u_lsu (
    .ren(!reset && !halted && c_can_complete_no_mem_fault && xc_mem_ren),
    .wen(!reset && !halted && c_lsu_wen),
    .size(xc_mem_size),
    .load_unsigned(xc_mem_unsigned),
    .addr(xc_lsu_addr),
    .wdata(xc_rs2_data),
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
    .ifu_valid(ifu_bus_valid && !drop_fetch_response),
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
    .addr(x_valid ? csr_addr : xc_csr_addr),
    .cmd(x_valid ? csr_cmd : xc_csr_cmd),
    .rs1_data(x_valid ? x_rs1_data : xc_rs1_data),
    .uimm(x_valid ? csr_uimm : xc_csr_uimm),
    .commit_en(c_retire_ready && c_complete_inst && xc_csr_cmd != `NPC_CSR_NONE),
    .trap_en(c_retire_ready && c_precise_trap),
    .trap_pc(xc_pc),
    .trap_cause(c_exception_cause),
    .rdata(csr_rdata),
    .mtvec(mtvec),
    .mepc(mepc),
    .mcause(mcause),
    .mstatus(mstatus)
  );

  Wbu u_wbu (
    .alu_result(c_wb_mux),
    .wdata(wb_data)
  );

  always @(posedge clock) begin
    if (reset) begin
      halted <= 1'b0;
      trap_status <= `NPC_STATUS_RUNNING;
      f_pc <= reset_vector;
      ifu_pending <= 1'b0;
      drop_fetch_response <= 1'b0;
      fx_valid <= 1'b0;
      xc_valid <= 1'b0;
    end else begin
      if (ifu_inst_ready) begin
        ifu_pending <= 1'b0;
      end else if (ifu_fetch_valid) begin
        ifu_pending <= 1'b1;
      end

      if (redirect) begin
        f_pc <= c_next_pc;
        fx_valid <= 1'b0;
        drop_fetch_response <= ifu_pending && !ifu_inst_ready;
      end else if (ifu_inst_ready && drop_fetch_response) begin
        drop_fetch_response <= 1'b0;
      end else if (ifu_inst_ready && fx_can_accept) begin
        fx_valid <= 1'b1;
        fx_pc <= f_pc;
        fx_inst <= ifu_inst;
        fx_inst_error <= ifu_inst_error;
        f_pc <= f_pc + 32'd4;
      end else if (x_can_advance) begin
        fx_valid <= 1'b0;
      end

      if (!halted && c_retire_ready && c_bad_without_vector) begin
        halted <= 1'b1;
        trap_status <= `NPC_STATUS_BAD;
      end

      if (c_stage_stall || load_use_stall) begin
        xc_valid <= xc_valid;
      end else if (x_can_advance) begin
        xc_valid <= 1'b1;
        xc_pc <= x_pc;
`ifdef NPC_DEBUG
        xc_inst <= x_inst;
`endif
        xc_inst_error <= x_inst_error;
        xc_rd <= rd;
        xc_writes_rd <= writes_rd;
        xc_wb_sel <= wb_sel;
        xc_mem_ren <= mem_ren;
        xc_mem_wen <= mem_wen;
        xc_mem_size <= mem_size;
        xc_mem_unsigned <= mem_unsigned;
        xc_csr_cmd <= csr_cmd;
        xc_csr_addr <= csr_addr;
        xc_csr_uimm <= csr_uimm;
        xc_csr_rdata <= csr_rdata;
        xc_rs1_data <= x_rs1_data;
        xc_rs2_data <= x_rs2_data;
        xc_alu_result <= alu_result;
        xc_lsu_addr <= x_lsu_addr;
        xc_normal_next_pc <= x_normal_next_pc;
        xc_is_mret <= x_is_mret;
        xc_is_fence_i <= x_is_fence_i;
        xc_decode_legal <= decode_legal;
        xc_pc_exception <= x_pc_exception;
        xc_mem_misaligned <= x_mem_misaligned;
        xc_is_ecall <= x_is_ecall;
        xc_is_ebreak <= x_is_ebreak;
      end else if (c_retire_ready) begin
        xc_valid <= 1'b0;
      end

      if (redirect) begin
        if (x_can_advance) begin
          xc_valid <= 1'b0;
        end
      end
    end
  end

`ifdef NPC_DEBUG
  wire unused = |{opcode, funct3, funct7, mcause, mstatus, trap_status};
`else
  wire unused = |{opcode, funct3, funct7, mcause, mstatus, trap_status,
                 lsu_write_addr, lsu_write_data, lsu_write_mask};
`endif

endmodule
