`include "include/npc_defines.vh"

module Exu (
  input  [3:0]  alu_op,
  input  [31:0] src1,
  input  [31:0] src2,
  output reg [31:0] result,
  output        equal,
  output        less_signed,
  output        less_unsigned
);

  wire [4:0] shamt = src2[4:0];

  assign equal = src1 == src2;
  assign less_signed = $signed(src1) < $signed(src2);
  assign less_unsigned = src1 < src2;

  always @(*) begin
    case (alu_op)
      `NPC_ALU_ADD:    result = src1 + src2;
      `NPC_ALU_SUB:    result = src1 - src2;
      `NPC_ALU_SLL:    result = src1 << shamt;
      `NPC_ALU_SLT:    result = less_signed ? 32'd1 : 32'd0;
      `NPC_ALU_SLTU:   result = less_unsigned ? 32'd1 : 32'd0;
      `NPC_ALU_XOR:    result = src1 ^ src2;
      `NPC_ALU_SRL:    result = src1 >> shamt;
      `NPC_ALU_SRA:    result = $signed(src1) >>> shamt;
      `NPC_ALU_OR:     result = src1 | src2;
      `NPC_ALU_AND:    result = src1 & src2;
      `NPC_ALU_COPY_B: result = src2;
      default:         result = 32'd0;
    endcase
  end

endmodule
