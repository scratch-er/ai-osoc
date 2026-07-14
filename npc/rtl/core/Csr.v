module Csr (
  input         clock,
  input         reset,
  output [31:0] mtvec,
  output [31:0] mepc,
  output [31:0] mcause
);

  wire unused = clock | reset;
  assign mtvec = 32'd0;
  assign mepc = 32'd0;
  assign mcause = 32'd0;

endmodule
