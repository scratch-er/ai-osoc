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
  output [31:0] commit_mem_addr,
  output [31:0] commit_mem_wdata,
  output [3:0]  commit_mem_wmask
);

  wire [31:0] reset_vector = (reset_pc == 32'd0) ? RESET_PC : reset_pc;

  reg [31:0] pc;
  reg        halted;
  reg [1:0]  trap_status;

  wire [31:0] fetch_pc = reset ? reset_vector : pc;
  wire [31:0] inst;
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
  wire [31:0] rs1_data;
  wire [31:0] rs2_data;
  wire [31:0] imm_data;
  wire [31:0] alu_src1;
  wire [31:0] alu_src2;
  wire [31:0] alu_result;
  wire        ifu_bus_valid;
  wire [31:0] ifu_bus_addr;
  wire        ifu_bus_ready;
  wire [31:0] ifu_bus_rdata;
  wire [31:0] lsu_addr;
  wire [31:0] lsu_rdata;
  wire [31:0] lsu_write_addr;
  wire [31:0] lsu_write_data;
  wire [3:0]  lsu_write_mask;
  wire        lsu_bus_valid;
  wire        lsu_bus_write;
  wire [31:0] lsu_bus_addr;
  wire [31:0] lsu_bus_wdata;
  wire [3:0]  lsu_bus_wmask;
  wire        lsu_bus_ready;
  wire [31:0] lsu_bus_rdata;
  wire [31:0] csr_rdata;
  wire [31:0] mtvec;
  wire [31:0] mepc;
  wire [31:0] mcause;
  wire [31:0] mstatus;
  wire [31:0] wb_data;
  wire        rd_is_rv32e = rd[4] == 1'b0;
  wire        rs1_is_rv32e = rs1[4] == 1'b0;
  wire        rs2_is_rv32e = rs2[4] == 1'b0;
  wire        rd_valid = !writes_rd || rd_is_rv32e;
  wire        rs1_valid = !reads_rs1 || rs1_is_rv32e;
  wire        rs2_valid = !reads_rs2 || rs2_is_rv32e;
  wire        decode_legal = is_legal && rd_valid && rs1_valid && rs2_valid;
  wire        mem_half_misaligned = mem_size == `NPC_MEM_HALF && lsu_addr[0] != 1'b0;
  wire        mem_word_misaligned = mem_size == `NPC_MEM_WORD && lsu_addr[1:0] != 2'b00;
  wire        mem_misaligned = (mem_ren || mem_wen) && (mem_half_misaligned || mem_word_misaligned);
  wire        branch_target_misaligned;
  wire        jal_target_misaligned;
  wire        jalr_target_misaligned;
  wire        pc_exception;
  wire [31:0] exception_cause;
  wire        is_ecall = sys_cmd == `NPC_SYS_ECALL;
  wire        is_ebreak = sys_cmd == `NPC_SYS_EBREAK;
  wire        is_mret = sys_cmd == `NPC_SYS_MRET;
  wire        trap_request;
  wire        precise_trap;
  wire        complete_inst;
  wire        mem_access;
  wire        mem_ready;
  wire        retire_ready;
  wire        wb_wen;
  wire        lsu_wen;
  wire [31:0] pc_plus_4 = pc + 32'd4;
  wire        branch_taken = (branch_op == `NPC_BR_BEQ)  ? (rs1_data == rs2_data) :
                             (branch_op == `NPC_BR_BNE)  ? (rs1_data != rs2_data) :
                             (branch_op == `NPC_BR_BLT)  ? ($signed(rs1_data) < $signed(rs2_data)) :
                             (branch_op == `NPC_BR_BGE)  ? ($signed(rs1_data) >= $signed(rs2_data)) :
                             (branch_op == `NPC_BR_BLTU) ? (rs1_data < rs2_data) :
                             (branch_op == `NPC_BR_BGEU) ? (rs1_data >= rs2_data) : 1'b0;
  wire [31:0] jalr_target = (rs1_data + imm_i) & ~32'd1;
  wire [31:0] jal_target = pc + imm_j;
  wire [31:0] branch_target = pc + imm_b;
  wire [31:0] normal_next_pc = is_mret ? mepc : (is_jalr ? jalr_target : (is_jal ? jal_target : (branch_taken ? branch_target : pc_plus_4)));
  wire [31:0] final_wb_data = wb_data;
  wire        bad_without_vector;
  wire        unused = |{opcode, funct3, funct7, mcause};

  assign branch_target_misaligned = branch_taken && branch_target[1:0] != 2'b00;
  assign jal_target_misaligned = is_jal && jal_target[1:0] != 2'b00;
  assign jalr_target_misaligned = is_jalr && jalr_target[1:0] != 2'b00;
  assign pc_exception = decode_legal && (branch_target_misaligned || jal_target_misaligned || jalr_target_misaligned);
  assign exception_cause = !decode_legal ? {27'd0, `NPC_EXC_ILLEGAL_INST} :
                           pc_exception ? {27'd0, `NPC_EXC_INST_ADDR_MISALIGNED} :
                           (mem_ren && mem_misaligned) ? {27'd0, `NPC_EXC_LOAD_ADDR_MISALIGNED} :
                           (mem_wen && mem_misaligned) ? {27'd0, `NPC_EXC_STORE_ADDR_MISALIGNED} :
                           is_ecall ? {27'd0, `NPC_EXC_ECALL_M} :
                           is_ebreak ? {27'd0, `NPC_EXC_BREAKPOINT} : 32'd0;
  assign trap_request = !decode_legal || pc_exception || mem_misaligned || is_ecall || is_ebreak;
  assign precise_trap = trap_request && mtvec != 32'd0;
  assign bad_without_vector = trap_request && mtvec == 32'd0;
  assign complete_inst = decode_legal && !mem_misaligned && !pc_exception && !is_ecall && !precise_trap;
  assign mem_access = complete_inst && (mem_ren || mem_wen);
  assign mem_ready = !mem_access || lsu_bus_ready;
  assign retire_ready = !reset && !halted && ifu_bus_ready && mem_ready;
  assign wb_wen = complete_inst && mem_ready && writes_rd && !is_mret;
  assign lsu_wen = complete_inst && mem_wen;

  assign imm_data = (imm_sel == `NPC_IMM_S) ? imm_s :
                    (imm_sel == `NPC_IMM_B) ? imm_b :
                    (imm_sel == `NPC_IMM_U) ? imm_u :
                    (imm_sel == `NPC_IMM_J) ? imm_j : imm_i;
  assign alu_src1 = src1_pc ? pc : rs1_data;
  assign alu_src2 = src2_imm ? imm_data : rs2_data;
  assign lsu_addr = rs1_data + (mem_wen ? imm_s : imm_i);

  assign debug_pc = pc;
  assign debug_halted = halted;
  assign debug_trap_status = trap_status;
  assign debug_inst = inst;
  assign debug_mstatus = mstatus;
  assign debug_mtvec = mtvec;
  assign debug_mepc = mepc;
  assign debug_mcause = mcause;
  assign commit_valid = retire_ready;
  assign commit_pc = pc;
  assign commit_inst = inst;
  assign commit_next_pc = precise_trap ? mtvec : (bad_without_vector ? pc : normal_next_pc);
  assign commit_wen = wb_wen && rd != 5'd0;
  assign commit_rd = rd;
  assign commit_wdata = final_wb_data;
  assign commit_exception = bad_without_vector;
  assign commit_cause = exception_cause;
  assign commit_mem_wen = retire_ready && lsu_wen;
  assign commit_mem_addr = lsu_write_addr;
  assign commit_mem_wdata = lsu_write_data;
  assign commit_mem_wmask = lsu_write_mask;

  Ifu u_ifu (
    .pc(fetch_pc),
    .bus_ready(ifu_bus_ready),
    .bus_rdata(ifu_bus_rdata),
    .bus_valid(ifu_bus_valid),
    .bus_addr(ifu_bus_addr),
    .inst(inst)
  );

  MemIf #(
    .LATENCY_PLUSARG(0)
  ) u_ifu_mem (
    .clock(clock),
    .reset(reset),
    .valid(ifu_bus_valid),
    .write(1'b0),
    .addr(ifu_bus_addr),
    .wdata(32'd0),
    .wmask(4'd0),
    .ready(ifu_bus_ready),
    .rdata(ifu_bus_rdata)
  );

  Idu u_idu (
    .inst(inst),
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
    .rdata1(rs1_data),
    .rdata2(rs2_data),
    .wen(!reset && !halted && wb_wen),
    .waddr(rd[3:0]),
    .wdata(final_wb_data),
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
    .ren(!reset && !halted && complete_inst && mem_ren),
    .wen(!reset && !halted && lsu_wen),
    .size(mem_size),
    .load_unsigned(mem_unsigned),
    .addr(lsu_addr),
    .wdata(rs2_data),
    .bus_ready(lsu_bus_ready),
    .bus_rdata(lsu_bus_rdata),
    .bus_valid(lsu_bus_valid),
    .bus_write(lsu_bus_write),
    .bus_addr(lsu_bus_addr),
    .bus_wdata(lsu_bus_wdata),
    .bus_wmask(lsu_bus_wmask),
    .rdata(lsu_rdata),
    .write_addr(lsu_write_addr),
    .write_data(lsu_write_data),
    .write_mask(lsu_write_mask)
  );

  MemIf u_lsu_mem (
    .clock(clock),
    .reset(reset),
    .valid(lsu_bus_valid),
    .write(lsu_bus_write),
    .addr(lsu_bus_addr),
    .wdata(lsu_bus_wdata),
    .wmask(lsu_bus_wmask),
    .ready(lsu_bus_ready),
    .rdata(lsu_bus_rdata)
  );

  Csr u_csr (
    .clock(clock),
    .reset(reset),
    .addr(csr_addr),
    .cmd(csr_cmd),
    .rs1_data(rs1_data),
    .uimm(csr_uimm),
    .commit_en(retire_ready && complete_inst && csr_cmd != `NPC_CSR_NONE),
    .trap_en(retire_ready && precise_trap),
    .trap_pc(pc),
    .trap_cause(exception_cause),
    .rdata(csr_rdata),
    .mtvec(mtvec),
    .mepc(mepc),
    .mcause(mcause),
    .mstatus(mstatus)
  );

  Wbu u_wbu (
    .alu_result((wb_sel == `NPC_WB_MEM) ? lsu_rdata :
                ((wb_sel == `NPC_WB_PC4) ? pc_plus_4 :
                 ((wb_sel == `NPC_WB_CSR) ? csr_rdata : alu_result))),
    .wdata(wb_data)
  );

  always @(posedge clock) begin
    if (reset) begin
      pc <= reset_vector;
      halted <= 1'b0;
      trap_status <= `NPC_STATUS_RUNNING;
    end else if (!halted && ifu_bus_ready && mem_ready) begin
      if (bad_without_vector) begin
        halted <= 1'b1;
        trap_status <= `NPC_STATUS_BAD;
      end else if (precise_trap) begin
        pc <= mtvec;
      end else begin
        pc <= normal_next_pc;
      end
    end
  end

endmodule
