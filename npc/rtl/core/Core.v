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
  output [511:0] debug_regs_flat,
  output        commit_valid,
  output [31:0] commit_pc,
  output [31:0] commit_inst,
  output [31:0] commit_next_pc,
  output        commit_wen,
  output [4:0]  commit_rd,
  output [31:0] commit_wdata,
  output        commit_exception,
  output [31:0] commit_cause
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
  wire [31:0] imm_u;
  wire        is_addi;
  wire        is_auipc;
  wire        is_lw;
  wire        is_sw;
  wire        is_jalr;
  wire        is_ebreak;
  wire        is_legal;
  wire [31:0] rs1_data;
  wire [31:0] rs2_data;
  wire [31:0] alu_result;
  wire [31:0] lsu_addr;
  wire [31:0] lsu_rdata;
  wire [31:0] wb_data;
  wire        rd_is_rv32e = rd[4] == 1'b0;
  wire        rs1_is_rv32e = rs1[4] == 1'b0;
  wire        rs2_is_rv32e = rs2[4] == 1'b0;
  wire        writes_rd = is_addi || is_auipc || is_lw || is_jalr;
  wire        reads_rs2 = is_sw;
  wire        rd_valid = !writes_rd || rd_is_rv32e;
  wire        rs1_valid = (is_ebreak || rs1_is_rv32e);
  wire        rs2_valid = !reads_rs2 || rs2_is_rv32e;
  wire        legal_inst = is_legal && rd_valid && rs1_valid && rs2_valid;
  wire        wb_wen = legal_inst && writes_rd;
  wire        lsu_wen = legal_inst && is_sw;
  wire [31:0] pc_plus_4 = pc + 32'd4;
  wire [31:0] jalr_target = (rs1_data + imm_i) & ~32'd1;
  wire [31:0] next_pc = is_jalr ? jalr_target : pc_plus_4;
  wire [31:0] final_wb_data = is_jalr ? pc_plus_4 : wb_data;
  wire [1:0]  ebreak_status = (debug_a0 == 32'd0) ? `NPC_STATUS_GOOD : `NPC_STATUS_BAD;
  wire        unused = |{opcode, funct3, funct7};

  import "DPI-C" function void npc_trap(input int code);

  assign debug_pc = pc;
  assign debug_halted = halted;
  assign debug_trap_status = trap_status;
  assign debug_inst = inst;
  assign commit_valid = !reset && !halted;
  assign commit_pc = pc;
  assign commit_inst = inst;
  assign commit_next_pc = legal_inst ? next_pc : pc;
  assign commit_wen = wb_wen && rd != 5'd0;
  assign commit_rd = rd;
  assign commit_wdata = final_wb_data;
  assign commit_exception = !legal_inst;
  assign commit_cause = legal_inst ? 32'd0 : 32'd2;

  Ifu u_ifu (
    .pc(fetch_pc),
    .inst(inst)
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
    .imm_u(imm_u),
    .is_addi(is_addi),
    .is_auipc(is_auipc),
    .is_lw(is_lw),
    .is_sw(is_sw),
    .is_jalr(is_jalr),
    .is_ebreak(is_ebreak),
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
    .src1(is_auipc ? pc : rs1_data),
    .src2(is_auipc ? imm_u : imm_i),
    .add_result(alu_result)
  );

  assign lsu_addr = rs1_data + (is_sw ? imm_s : imm_i);

  Lsu u_lsu (
    .ren(!reset && !halted && legal_inst && is_lw),
    .wen(!reset && !halted && lsu_wen),
    .addr(lsu_addr),
    .wdata(rs2_data),
    .rdata(lsu_rdata)
  );

  Wbu u_wbu (
    .alu_result(is_lw ? lsu_rdata : alu_result),
    .wdata(wb_data)
  );

  always @(posedge clock) begin
    if (reset) begin
      pc <= reset_vector;
      halted <= 1'b0;
      trap_status <= `NPC_STATUS_RUNNING;
    end else if (!halted) begin
      if (legal_inst) begin
        if (is_ebreak) begin
          halted <= 1'b1;
          trap_status <= ebreak_status;
          npc_trap({30'd0, ebreak_status});
        end else begin
          pc <= next_pc;
        end
      end else begin
        halted <= 1'b1;
        trap_status <= `NPC_STATUS_BAD;
      end
    end
  end

endmodule
