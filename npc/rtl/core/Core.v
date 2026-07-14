`include "include/npc_defines.vh"

module Core #(
  parameter RESET_PC = `NPC_RESET_PC
) (
  input         clock,
  input         reset,
  input  [31:0] reset_pc,
  output [31:0] debug_pc,
  output        debug_halted,
  output [31:0] debug_x1
);

  wire [31:0] reset_vector = (reset_pc == 32'd0) ? RESET_PC : reset_pc;

  reg [31:0] pc;
  reg        halted;

  wire [31:0] fetch_pc = reset ? reset_vector : pc;
  wire [31:0] inst;
  wire [6:0]  opcode;
  wire [4:0]  rd;
  wire [2:0]  funct3;
  wire [4:0]  rs1;
  wire [4:0]  rs2;
  wire [6:0]  funct7;
  wire [31:0] imm_i;
  wire        is_addi;
  wire        is_legal;
  wire [31:0] rs1_data;
  wire [31:0] rs2_data;
  wire [31:0] alu_result;
  wire [31:0] wb_data;
  wire        rd_is_rv32e = rd[4] == 1'b0;
  wire        rs1_is_rv32e = rs1[4] == 1'b0;
  wire        addi_wen = is_addi && rd_is_rv32e && rs1_is_rv32e;
  wire        legal_inst = is_legal && rd_is_rv32e && rs1_is_rv32e;
  wire        unused = |{opcode, funct3, rs2, funct7, rs2_data};

  assign debug_pc = pc;
  assign debug_halted = halted;

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
    .is_addi(is_addi),
    .is_legal(is_legal)
  );

  RegFile u_regfile (
    .clock(clock),
    .reset(reset),
    .raddr1(rs1[3:0]),
    .raddr2(rs2[3:0]),
    .rdata1(rs1_data),
    .rdata2(rs2_data),
    .wen(!reset && !halted && addi_wen),
    .waddr(rd[3:0]),
    .wdata(wb_data),
    .debug_x1(debug_x1)
  );

  Exu u_exu (
    .src1(rs1_data),
    .src2(imm_i),
    .add_result(alu_result)
  );

  Wbu u_wbu (
    .alu_result(alu_result),
    .wdata(wb_data)
  );

  always @(posedge clock) begin
    if (reset) begin
      pc <= reset_vector;
      halted <= 1'b0;
    end else if (!halted) begin
      if (legal_inst) begin
        pc <= pc + 32'd4;
      end else begin
        halted <= 1'b1;
      end
    end
  end

endmodule
