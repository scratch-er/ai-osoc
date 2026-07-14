module Wbu (
  input  [31:0] alu_result,
  output [31:0] wdata
);

  assign wdata = alu_result;

endmodule
