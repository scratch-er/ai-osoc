`include "include/npc_defines.vh"

module Core #(
  parameter RESET_PC = `NPC_RESET_PC
) (
  input         clock,
  input         reset,
  input  [31:0] reset_pc,
  output [31:0] debug_pc,
  output        debug_halted
);

  wire [31:0] reset_vector = (reset_pc == 32'd0) ? RESET_PC : reset_pc;

  reg [31:0] pc;
  reg        halted;

  assign debug_pc = pc;
  assign debug_halted = halted;

  always @(posedge clock) begin
    if (reset) begin
      pc <= reset_vector;
      halted <= 1'b0;
    end else if (!halted) begin
      pc <= pc + 32'd4;
    end
  end

endmodule
