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
  output [1:0]  debug_trap_status,
  output [31:0] debug_inst,
  output [31:0] debug_mstatus,
  output [31:0] debug_mtvec,
  output [31:0] debug_mepc,
  output [31:0] debug_mcause,
  output [511:0] debug_regs_flat,
  output        commit_valid,
  output [31:0] commit_pc,
  output [31:0] commit_inst,
  output [31:0] commit_next_pc,
  output        commit_wen,
  output [4:0]  commit_rd,
  output [31:0] commit_wdata,
  output        commit_exception,
  output [31:0] commit_cause,
  output        commit_mem_wen,
  output [31:0] commit_mem_addr,
  output [31:0] commit_mem_wdata,
  output [3:0]  commit_mem_wmask
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
    .debug_trap_status(debug_trap_status),
    .debug_inst(debug_inst),
    .debug_mstatus(debug_mstatus),
    .debug_mtvec(debug_mtvec),
    .debug_mepc(debug_mepc),
    .debug_mcause(debug_mcause),
    .debug_regs_flat(debug_regs_flat),
    .commit_valid(commit_valid),
    .commit_pc(commit_pc),
    .commit_inst(commit_inst),
    .commit_next_pc(commit_next_pc),
    .commit_wen(commit_wen),
    .commit_rd(commit_rd),
    .commit_wdata(commit_wdata),
    .commit_exception(commit_exception),
    .commit_cause(commit_cause),
    .commit_mem_wen(commit_mem_wen),
    .commit_mem_addr(commit_mem_addr),
    .commit_mem_wdata(commit_mem_wdata),
    .commit_mem_wmask(commit_mem_wmask)
  );

endmodule
