`include "include/npc_defines.vh"

module Csr (
  input         clock,
  input         reset,
  input  [11:0] addr,
  input  [2:0]  cmd,
  input  [31:0] rs1_data,
  input  [4:0]  uimm,
  input         commit_en,
  input         trap_en,
  input  [31:0] trap_pc,
  input  [31:0] trap_cause,
  output [31:0] rdata,
  output [31:0] mtvec,
  output [31:0] mepc,
  output [31:0] mcause,
  output [31:0] mstatus
);

  reg [31:0] mtvec_r;
  reg [31:0] mepc_r;
  reg [31:0] mcause_r;

  wire [31:0] mstatus_value = 32'h0000_1800;
  wire [31:0] csr_old = (addr == 12'hf11) ? 32'd0 :
                         (addr == 12'hf12) ? 32'd0 :
                         (addr == 12'h300) ? mstatus_value :
                         (addr == 12'h305) ? mtvec_r :
                         (addr == 12'h341) ? mepc_r :
                         (addr == 12'h342) ? mcause_r : 32'd0;
  wire [31:0] csr_src = (cmd == `NPC_CSR_RWI || cmd == `NPC_CSR_RSI || cmd == `NPC_CSR_RCI) ? {27'd0, uimm} : rs1_data;
  wire        csr_write_en = cmd == `NPC_CSR_RW || cmd == `NPC_CSR_RWI ||
                             ((cmd == `NPC_CSR_RS || cmd == `NPC_CSR_RC) && rs1_data != 32'd0) ||
                             ((cmd == `NPC_CSR_RSI || cmd == `NPC_CSR_RCI) && uimm != 5'd0);
  wire [31:0] csr_next = (cmd == `NPC_CSR_RW || cmd == `NPC_CSR_RWI) ? csr_src :
                         (cmd == `NPC_CSR_RS || cmd == `NPC_CSR_RSI) ? (csr_old | csr_src) :
                         (cmd == `NPC_CSR_RC || cmd == `NPC_CSR_RCI) ? (csr_old & ~csr_src) : csr_old;
  wire        unused = |trap_pc[1:0];

  assign rdata = csr_old;
  assign mtvec = mtvec_r;
  assign mepc = mepc_r;
  assign mcause = mcause_r;
  assign mstatus = mstatus_value;

  always @(posedge clock) begin
    if (reset) begin
      mtvec_r <= 32'd0;
      mepc_r <= 32'd0;
      mcause_r <= 32'd0;
    end else if (trap_en) begin
      mepc_r <= {trap_pc[31:2], 2'b00};
      mcause_r <= trap_cause;
    end else if (commit_en && csr_write_en) begin
      case (addr)
        12'h305: mtvec_r <= {csr_next[31:2], 2'b00};
        12'h341: mepc_r <= {csr_next[31:2], 2'b00};
        12'h342: mcause_r <= csr_next;
        default: begin end
      endcase
    end
  end

endmodule
