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
  output [1:0]  debug_trap_status
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
  wire        is_addi;
  wire        is_jalr;
  wire        is_ebreak;
  wire        is_legal;
  wire [31:0] rs1_data;
  wire [31:0] rs2_data;
  wire [31:0] alu_result;
  wire [31:0] wb_data;
  wire        rd_is_rv32e = rd[4] == 1'b0;
  wire        rs1_is_rv32e = rs1[4] == 1'b0;
  wire        writes_rd = is_addi || is_jalr;
  wire        rd_valid = !writes_rd || rd_is_rv32e;
  wire        rs1_valid = (is_ebreak || rs1_is_rv32e);
  wire        legal_inst = is_legal && rd_valid && rs1_valid;
  wire        wb_wen = legal_inst && writes_rd;
  wire [31:0] pc_plus_4 = pc + 32'd4;
  wire [31:0] jalr_target = (rs1_data + imm_i) & ~32'd1;
  wire [31:0] next_pc = is_jalr ? jalr_target : pc_plus_4;
  wire [31:0] final_wb_data = is_jalr ? pc_plus_4 : wb_data;
  wire [1:0]  ebreak_status = (debug_a0 == 32'd0) ? `NPC_STATUS_GOOD : `NPC_STATUS_BAD;
  wire        unused = |{opcode, funct3, rs2, funct7, rs2_data, alu_result};

  import "DPI-C" function void npc_trap(input int code);

  assign debug_pc = pc;
  assign debug_halted = halted;
  assign debug_trap_status = trap_status;

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
    .debug_a0(debug_a0)
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
