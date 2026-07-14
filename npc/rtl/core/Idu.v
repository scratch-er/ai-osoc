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
  output [1:0]  mem_size,
  output        mem_unsigned,
  output [2:0]  csr_cmd,
  output [2:0]  sys_cmd,
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
  wire is_fence_op;
  wire is_system;
  wire is_csr;
  wire is_ecall;
  wire is_ebreak;
  wire is_mret;
  wire is_wfi;
  wire is_fence;
  wire is_fence_i;
  wire csr_known;
  wire csr_read_only;
  wire csr_writes;
  wire csr_legal;
  wire system_legal;
  wire load_legal;
  wire store_legal;
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
  assign is_load   = opcode == 7'b0000011;
  assign is_store  = opcode == 7'b0100011;
  assign is_branch = opcode == 7'b1100011;
  assign is_op_imm = opcode == 7'b0010011;
  assign is_op       = opcode == 7'b0110011;
  assign is_fence_op = opcode == 7'b0001111;
  assign is_system   = opcode == 7'b1110011;
  assign is_csr      = is_system && funct3 != 3'b000;
  assign is_ecall    = inst == 32'h0000_0073;
  assign is_ebreak   = inst == 32'h0010_0073;
  assign is_mret     = inst == 32'h3020_0073;
  assign is_wfi      = inst == 32'h1050_0073;
  assign is_fence    = is_fence_op && funct3 == 3'b000;
  assign is_fence_i  = is_fence_op && funct3 == 3'b001;

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
  assign load_legal = is_load && (funct3 == 3'b000 || funct3 == 3'b001 || funct3 == 3'b010 ||
                                  funct3 == 3'b100 || funct3 == 3'b101);
  assign store_legal = is_store && (funct3 == 3'b000 || funct3 == 3'b001 || funct3 == 3'b010);
  assign csr_known = csr_addr == 12'hf11 || csr_addr == 12'hf12 || csr_addr == 12'h300 ||
                     csr_addr == 12'h305 || csr_addr == 12'h341 || csr_addr == 12'h342;
  assign csr_read_only = csr_addr == 12'hf11 || csr_addr == 12'hf12;
  assign csr_writes = (funct3 == 3'b001 || funct3 == 3'b101) ||
                      ((funct3 == 3'b010 || funct3 == 3'b011) && rs1 != 5'd0) ||
                      ((funct3 == 3'b110 || funct3 == 3'b111) && csr_uimm != 5'd0);
  assign csr_legal = is_csr && csr_known && !(csr_read_only && csr_writes) &&
                     (funct3 == 3'b001 || funct3 == 3'b010 || funct3 == 3'b011 ||
                      funct3 == 3'b101 || funct3 == 3'b110 || funct3 == 3'b111);
  assign system_legal = is_ecall || is_ebreak || is_mret || is_wfi || csr_legal;
  assign is_legal = is_lui || is_auipc || is_jal || is_jalr || load_legal || store_legal ||
                    is_branch_legal || op_imm_legal || op_legal || system_legal || is_fence || is_fence_i;

  assign reads_rs1 = is_jalr || is_load || is_store || is_branch || is_op_imm || is_op ||
                     (is_csr && (funct3 == 3'b001 || funct3 == 3'b010 || funct3 == 3'b011));
  assign reads_rs2 = is_store || is_branch || is_op;
  assign writes_rd = is_lui || is_auipc || is_jal || is_jalr || is_load || is_op_imm || is_op || is_csr;
  assign mem_ren = load_legal;
  assign mem_wen = store_legal;
  assign mem_size = (funct3[1:0] == 2'b00) ? `NPC_MEM_BYTE :
                    (funct3[1:0] == 2'b01) ? `NPC_MEM_HALF : `NPC_MEM_WORD;
  assign mem_unsigned = funct3[2];
  assign csr_cmd = !is_csr ? `NPC_CSR_NONE :
                   (funct3 == 3'b001) ? `NPC_CSR_RW :
                   (funct3 == 3'b010) ? `NPC_CSR_RS :
                   (funct3 == 3'b011) ? `NPC_CSR_RC :
                   (funct3 == 3'b101) ? `NPC_CSR_RWI :
                   (funct3 == 3'b110) ? `NPC_CSR_RSI : `NPC_CSR_RCI;
  assign sys_cmd = is_ecall ? `NPC_SYS_ECALL :
                   is_ebreak ? `NPC_SYS_EBREAK :
                   is_mret ? `NPC_SYS_MRET :
                   is_wfi ? `NPC_SYS_WFI :
                   is_fence ? `NPC_SYS_FENCE :
                   is_fence_i ? `NPC_SYS_FENCE_I : `NPC_SYS_NONE;
  assign branch_op = !is_branch ? `NPC_BR_NONE :
                     (funct3 == 3'b000) ? `NPC_BR_BEQ :
                     (funct3 == 3'b001) ? `NPC_BR_BNE :
                     (funct3 == 3'b100) ? `NPC_BR_BLT :
                     (funct3 == 3'b101) ? `NPC_BR_BGE :
                     (funct3 == 3'b110) ? `NPC_BR_BLTU : `NPC_BR_BGEU;
  assign src1_pc = is_auipc;
  assign src2_imm = !is_op;
  assign wb_sel = is_load ? `NPC_WB_MEM : (is_csr ? `NPC_WB_CSR : ((is_jal || is_jalr) ? `NPC_WB_PC4 : `NPC_WB_ALU));
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
