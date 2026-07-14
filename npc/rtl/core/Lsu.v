module Lsu (
  input         ren,
  input         wen,
  input  [31:0] addr,
  input  [31:0] wdata,
  output [31:0] rdata
);

  import "DPI-C" function int unsigned pmem_read(input int unsigned addr);
  import "DPI-C" function void pmem_write(input int unsigned addr, input int unsigned data);

  assign rdata = ren ? pmem_read(addr) : 32'd0;

  always @(*) begin
    if (wen) begin
      pmem_write(addr, wdata);
    end
  end

endmodule
