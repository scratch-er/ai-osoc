`include "include/npc_defines.vh"

module Idu (
  input  [31:0] inst,
  output [6:0]  opcode,
  output [4:0]  rd,
  output [2:0]  funct3,
  output [4:0]  rs1,
  output [4:0]  rs2,
  output [6:0]  funct7,
  output [31:0] imm_i,
  output [31:0] imm_s,
  output [31:0] imm_b,
  output [31:0] imm_u,
  output [31:0] imm_j,
  output [11:0] csr_addr,
  output [4:0]  csr_uimm,
  output [3:0]  alu_op,
  output [2:0]  imm_sel,
  output [1:0]  wb_sel,
  output        src1_pc,
  output        src2_imm,
  output        mem_ren,
  output        mem_wen,
  output [1:0]  sys_cmd,
  output [2:0]  branch_op,
  output        reads_rs1,
  output        reads_rs2,
  output        writes_rd,
  output        is_jal,
  output        is_jalr,
  output        is_legal
);

  wire is_lui;
  wire is_auipc;
  wire is_op_imm;
  wire is_op;
  wire is_load;
  wire is_store;
  wire is_branch;
  wire is_branch_legal;
  wire is_system;
  wire shamt_high_valid;
  wire op_imm_legal;
  wire op_legal;

  assign opcode = inst[6:0];
  assign rd     = inst[11:7];
  assign funct3 = inst[14:12];
  assign rs1    = inst[19:15];
  assign rs2    = inst[24:20];
  assign funct7 = inst[31:25];
  assign imm_i  = {{20{inst[31]}}, inst[31:20]};
  assign imm_s  = {{20{inst[31]}}, inst[31:25], inst[11:7]};
  assign imm_b  = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
  assign imm_u  = {inst[31:12], 12'b0};
  assign imm_j  = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
  assign csr_addr = inst[31:20];
  assign csr_uimm = inst[19:15];

  assign is_lui    = opcode == 7'b0110111;
  assign is_auipc  = opcode == 7'b0010111;
  assign is_jal    = opcode == 7'b1101111;
  assign is_jalr   = opcode == 7'b1100111 && funct3 == 3'b000;
  assign is_load   = opcode == 7'b0000011 && funct3 == 3'b010;
  assign is_store  = opcode == 7'b0100011 && funct3 == 3'b010;
  assign is_branch = opcode == 7'b1100011;
  assign is_op_imm = opcode == 7'b0010011;
  assign is_op     = opcode == 7'b0110011;
  assign is_system = inst == 32'h0010_0073;

  assign shamt_high_valid = 1'b1;
  assign op_imm_legal = is_op_imm && (
    funct3 == 3'b000 ||
    funct3 == 3'b010 ||
    funct3 == 3'b011 ||
    funct3 == 3'b100 ||
    funct3 == 3'b110 ||
    funct3 == 3'b111 ||
    (funct3 == 3'b001 && funct7 == 7'b0000000 && shamt_high_valid) ||
    (funct3 == 3'b101 && (funct7 == 7'b0000000 || funct7 == 7'b0100000) && shamt_high_valid)
  );
  assign op_legal = is_op && (
    ({funct7, funct3} == {7'b0000000, 3'b000}) ||
    ({funct7, funct3} == {7'b0100000, 3'b000}) ||
    ({funct7, funct3} == {7'b0000000, 3'b001}) ||
    ({funct7, funct3} == {7'b0000000, 3'b010}) ||
    ({funct7, funct3} == {7'b0000000, 3'b011}) ||
    ({funct7, funct3} == {7'b0000000, 3'b100}) ||
    ({funct7, funct3} == {7'b0000000, 3'b101}) ||
    ({funct7, funct3} == {7'b0100000, 3'b101}) ||
    ({funct7, funct3} == {7'b0000000, 3'b110}) ||
    ({funct7, funct3} == {7'b0000000, 3'b111})
  );

  assign is_branch_legal = is_branch && (funct3 == 3'b000 || funct3 == 3'b001 ||
                                          funct3 == 3'b100 || funct3 == 3'b101 ||
                                          funct3 == 3'b110 || funct3 == 3'b111);
  assign is_legal = is_lui || is_auipc || is_jal || is_jalr || is_load || is_store ||
                    is_branch_legal || op_imm_legal || op_legal || is_system;

  assign reads_rs1 = is_jalr || is_load || is_store || is_branch || is_op_imm || is_op;
  assign reads_rs2 = is_store || is_branch || is_op;
  assign writes_rd = is_lui || is_auipc || is_jal || is_jalr || is_load || is_op_imm || is_op;
  assign mem_ren = is_load;
  assign mem_wen = is_store;
  assign sys_cmd = is_system ? `NPC_SYS_EBREAK : `NPC_SYS_NONE;
  assign branch_op = !is_branch ? `NPC_BR_NONE :
                     (funct3 == 3'b000) ? `NPC_BR_BEQ :
                     (funct3 == 3'b001) ? `NPC_BR_BNE :
                     (funct3 == 3'b100) ? `NPC_BR_BLT :
                     (funct3 == 3'b101) ? `NPC_BR_BGE :
                     (funct3 == 3'b110) ? `NPC_BR_BLTU : `NPC_BR_BGEU;
  assign src1_pc = is_auipc;
  assign src2_imm = !is_op;
  assign wb_sel = is_load ? `NPC_WB_MEM : ((is_jal || is_jalr) ? `NPC_WB_PC4 : `NPC_WB_ALU);
  assign imm_sel = is_store ? `NPC_IMM_S : ((is_lui || is_auipc) ? `NPC_IMM_U : (is_jal ? `NPC_IMM_J : `NPC_IMM_I));

  assign alu_op = is_lui ? `NPC_ALU_COPY_B :
                  !(is_op || is_op_imm) ? `NPC_ALU_ADD :
                  (is_op && funct3 == 3'b000 && funct7 == 7'b0100000) ? `NPC_ALU_SUB :
                  (funct3 == 3'b001) ? `NPC_ALU_SLL :
                  (funct3 == 3'b010) ? `NPC_ALU_SLT :
                  (funct3 == 3'b011) ? `NPC_ALU_SLTU :
                  (funct3 == 3'b100) ? `NPC_ALU_XOR :
                  (funct3 == 3'b101 && funct7 == 7'b0100000) ? `NPC_ALU_SRA :
                  (funct3 == 3'b101) ? `NPC_ALU_SRL :
                  (funct3 == 3'b110) ? `NPC_ALU_OR :
                  (funct3 == 3'b111) ? `NPC_ALU_AND : `NPC_ALU_ADD;

endmodule
