module AxiArbiter (
  input         ifu_valid,
  input  [31:0] ifu_addr,
  output        ifu_ready,
  output [31:0] ifu_rdata,
  input         lsu_valid,
  input         lsu_write,
  input  [31:0] lsu_addr,
  input  [31:0] lsu_wdata,
  input  [3:0]  lsu_wmask,
  output        lsu_ready,
  output [31:0] lsu_rdata,
  output        bus_valid,
  output        bus_write,
  output [31:0] bus_addr,
  output [31:0] bus_wdata,
  output [3:0]  bus_wmask,
  input         bus_ready,
  input  [31:0] bus_rdata
);

  wire use_lsu = lsu_valid;
  wire use_ifu = !lsu_valid && ifu_valid;

  assign bus_valid = use_lsu || use_ifu;
  assign bus_write = use_lsu && lsu_write;
  assign bus_addr = use_lsu ? lsu_addr : ifu_addr;
  assign bus_wdata = use_lsu ? lsu_wdata : 32'd0;
  assign bus_wmask = use_lsu ? lsu_wmask : 4'd0;

  assign lsu_ready = use_lsu && bus_ready;
  assign lsu_rdata = bus_rdata;
  assign ifu_ready = use_ifu && bus_ready;
  assign ifu_rdata = bus_rdata;

endmodule
