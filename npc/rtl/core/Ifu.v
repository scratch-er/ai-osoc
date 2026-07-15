module Ifu (
  input  [31:0] pc,
  input         bus_ready,
  input  [31:0] bus_rdata,
  output        bus_valid,
  output [31:0] bus_addr,
  output [31:0] inst
);

  assign bus_valid = 1'b1;
  assign bus_addr = pc;
  assign inst = bus_ready ? bus_rdata : 32'd0;

endmodule
