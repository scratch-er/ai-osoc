module Ifu (
  input  [31:0] pc,
  output [31:0] inst
);

  import "DPI-C" function int unsigned pmem_read(input int unsigned addr);

  assign inst = pmem_read(pc);

endmodule
