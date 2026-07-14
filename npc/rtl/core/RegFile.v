module RegFile (
  input         clock,
  input         reset,
  input  [3:0]  raddr1,
  input  [3:0]  raddr2,
  output [31:0] rdata1,
  output [31:0] rdata2,
  input         wen,
  input  [3:0]  waddr,
  input  [31:0] wdata,
  output [31:0] debug_x1,
  output [31:0] debug_a0
);

  reg [31:0] regs [0:15];
  integer i;

  assign rdata1 = (raddr1 == 4'd0) ? 32'd0 : regs[raddr1];
  assign rdata2 = (raddr2 == 4'd0) ? 32'd0 : regs[raddr2];
  assign debug_x1 = regs[4'd1];
  assign debug_a0 = regs[4'd10];

  always @(posedge clock) begin
    if (reset) begin
      for (i = 0; i < 16; i = i + 1) begin
        regs[i] <= 32'd0;
      end
    end else if (wen && waddr != 4'd0) begin
      regs[waddr] <= wdata;
    end
  end

endmodule
