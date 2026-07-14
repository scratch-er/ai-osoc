module Lsu (
  input  [31:0] addr,
  input  [31:0] wdata,
  output [31:0] rdata
);

  wire unused = |{addr, wdata};
  assign rdata = 32'd0;

endmodule
