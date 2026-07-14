`include "include/npc_defines.vh"

module NPC #(
  parameter RESET_PC = `NPC_RESET_PC
) (
  input         clock,
  input         reset,
  input         io_interrupt,
  input  [31:0] io_reset_pc,
  output [31:0] debug_pc,
  output        debug_halted,
  output [31:0] debug_x1,
  output [31:0] debug_a0,
  output [1:0]  debug_trap_status
);

  wire unused_interrupt = io_interrupt;

  Core #(
    .RESET_PC(RESET_PC)
  ) u_core (
    .clock(clock),
    .reset(reset),
    .reset_pc(io_reset_pc),
    .debug_pc(debug_pc),
    .debug_halted(debug_halted),
    .debug_x1(debug_x1),
    .debug_a0(debug_a0),
    .debug_trap_status(debug_trap_status)
  );

endmodule
