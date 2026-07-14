module Exu (
  input  [31:0] src1,
  input  [31:0] src2,
  output [31:0] add_result
);

  assign add_result = src1 + src2;

endmodule
