module Idu (
  input  [31:0] inst,
  output [6:0]  opcode,
  output [4:0]  rd,
  output [2:0]  funct3,
  output [4:0]  rs1,
  output [4:0]  rs2,
  output [6:0]  funct7,
  output [31:0] imm_i,
  output        is_addi,
  output        is_jalr,
  output        is_ebreak,
  output        is_legal
);

  assign opcode = inst[6:0];
  assign rd     = inst[11:7];
  assign funct3 = inst[14:12];
  assign rs1    = inst[19:15];
  assign rs2    = inst[24:20];
  assign funct7 = inst[31:25];
  assign imm_i  = {{20{inst[31]}}, inst[31:20]};

  assign is_addi   = opcode == 7'b0010011 && funct3 == 3'b000;
  assign is_jalr   = opcode == 7'b1100111 && funct3 == 3'b000;
  assign is_ebreak = inst == 32'h0010_0073;
  assign is_legal  = is_addi || is_jalr || is_ebreak;

endmodule
