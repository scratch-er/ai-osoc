module Ifu (
  input  [31:0] pc,
  output [31:0] inst
);

  assign inst = 32'h0000_0013; // addi x0, x0, 0

endmodule
