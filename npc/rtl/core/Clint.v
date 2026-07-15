module Clint (
  input         clock,
  input         reset,
  input         valid,
  input         write,
  input  [31:0] addr,
  input  [31:0] wdata,
  input  [3:0]  wmask,
  output        ready,
  output [31:0] rdata,
  output        error
);

  localparam [31:0] CLINT_BASE   = 32'h02000000;
  localparam [31:0] MTIME_ADDR   = CLINT_BASE + 32'h0000bff8;
  localparam [31:0] MTIMEH_ADDR  = CLINT_BASE + 32'h0000bffc;

  reg [63:0] mtime;

  wire unused_inputs = |{valid, write, wdata, wmask};

  assign ready = valid;
  assign error = 1'b0;
  assign rdata = (addr == MTIME_ADDR)  ? mtime[31:0] :
                 (addr == MTIMEH_ADDR) ? mtime[63:32] : 32'd0;

  always @(posedge clock) begin
    if (reset) begin
      mtime <= 64'd0;
    end else begin
      mtime <= mtime + 64'd1;
    end
  end

endmodule
