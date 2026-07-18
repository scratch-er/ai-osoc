`include "include/npc_defines.vh"

module Lsu (
  input         ren,
  input         wen,
  input  [1:0]  size,
  input         load_unsigned,
  input  [31:0] addr,
  input  [31:0] wdata,
  input         bus_ready,
  input  [31:0] bus_rdata,
  output        bus_valid,
  output        bus_write,
  output [31:0] bus_addr,
  output [31:0] bus_wdata,
  output [3:0]  bus_wmask,
  output [31:0] rdata,
  output [31:0] write_addr,
  output [31:0] write_data,
  output [3:0]  write_mask
);

  wire [31:0] aligned_addr = {addr[31:2], 2'b00};
  wire        is_uart_mmio = (addr[31:16] == 16'h1000);
  wire [31:0] bus_req_addr = is_uart_mmio ? addr : aligned_addr;
  wire [31:0] raw_rdata = bus_ready ? bus_rdata : 32'd0;
  wire [4:0]  byte_shift = {addr[1:0], 3'b000};
  wire [31:0] shifted_rdata = raw_rdata >> byte_shift;
  wire [7:0]  load_byte = shifted_rdata[7:0];
  wire [15:0] load_half = shifted_rdata[15:0];
  wire        unused_shifted = |shifted_rdata[31:16];
  wire [31:0] store_wdata = wdata << byte_shift;
  wire [3:0]  byte_mask = 4'b0001 << addr[1:0];
  wire [3:0]  half_mask = 4'b0011 << {addr[1], 1'b0};
  wire [3:0]  wmask = (size == `NPC_MEM_BYTE) ? byte_mask :
                       (size == `NPC_MEM_HALF) ? half_mask : 4'b1111;

  assign bus_valid = ren || wen;
  assign bus_write = wen;
  assign bus_addr = bus_req_addr;
  assign bus_wdata = store_wdata;
  assign bus_wmask = wmask;
  assign rdata = (size == `NPC_MEM_BYTE) ? (load_unsigned ? {24'd0, load_byte} : {{24{load_byte[7]}}, load_byte}) :
                 (size == `NPC_MEM_HALF) ? (load_unsigned ? {16'd0, load_half} : {{16{load_half[15]}}, load_half}) : raw_rdata;
  assign write_addr = aligned_addr;
  assign write_data = store_wdata;
  assign write_mask = wmask;

endmodule
