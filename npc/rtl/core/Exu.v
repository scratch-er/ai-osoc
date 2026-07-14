`include "include/npc_defines.vh"

module Exu (
  input  [3:0]  alu_op,
  input  [31:0] src1,
  input  [31:0] src2,
  output reg [31:0] result
);

  wire [4:0] shamt = src2[4:0];

  always @(*) begin
    case (alu_op)
      `NPC_ALU_ADD:    result = src1 + src2;
      `NPC_ALU_SUB:    result = src1 - src2;
      `NPC_ALU_SLL:    result = src1 << shamt;
      `NPC_ALU_SLT:    result = ($signed(src1) < $signed(src2)) ? 32'd1 : 32'd0;
      `NPC_ALU_SLTU:   result = (src1 < src2) ? 32'd1 : 32'd0;
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
