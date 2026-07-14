module RegFile (
  input         clock,
  input  [3:0]  raddr1,
  input  [3:0]  raddr2,
  output [31:0] rdata1,
  output [31:0] rdata2,
  input         wen,
  input  [3:0]  waddr,
  input  [31:0] wdata
);

  reg [31:0] regs [0:15];

  assign rdata1 = (raddr1 == 4'd0) ? 32'd0 : regs[raddr1];
  assign rdata2 = (raddr2 == 4'd0) ? 32'd0 : regs[raddr2];

  always @(posedge clock) begin
    if (wen && waddr != 4'd0) begin
      regs[waddr] <= wdata;
    end
  end

endmodule
