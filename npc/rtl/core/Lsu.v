`include "include/npc_defines.vh"

module Lsu (
  input         ren,
  input         wen,
  input  [1:0]  size,
  input         load_unsigned,
  input  [31:0] addr,
  input  [31:0] wdata,
  output [31:0] rdata,
  output [31:0] write_addr,
  output [31:0] write_data,
  output [3:0]  write_mask
);

  wire [31:0] aligned_addr = {addr[31:2], 2'b00};
  wire [31:0] raw_rdata;
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

  import "DPI-C" function int unsigned pmem_read(input int unsigned addr);
  import "DPI-C" function void pmem_write(input int unsigned addr, input int unsigned data, input byte wmask);

  assign raw_rdata = ren ? pmem_read(aligned_addr) : 32'd0;
  assign rdata = (size == `NPC_MEM_BYTE) ? (load_unsigned ? {24'd0, load_byte} : {{24{load_byte[7]}}, load_byte}) :
                 (size == `NPC_MEM_HALF) ? (load_unsigned ? {16'd0, load_half} : {{16{load_half[15]}}, load_half}) : raw_rdata;
  assign write_addr = aligned_addr;
  assign write_data = store_wdata;
  assign write_mask = wmask;

  always @(*) begin
    if (wen) begin
      pmem_write(aligned_addr, store_wdata, {4'd0, wmask});
    end
  end

endmodule
