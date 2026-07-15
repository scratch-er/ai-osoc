module MemIf #(
  parameter LATENCY_PLUSARG = 1
) (
  input         clock,
  input         reset,
  input         valid,
  input         write,
  input  [31:0] addr,
  input  [31:0] wdata,
  input  [3:0]  wmask,
  output        ready,
  output [31:0] rdata
);

  import "DPI-C" function int unsigned pmem_read(input int unsigned addr);
  import "DPI-C" function void pmem_write(input int unsigned addr, input int unsigned data, input byte wmask);

  integer latency;
  reg [31:0] pending_rdata;
  reg [31:0] delay_count;
  reg        busy;

  wire zero_latency = latency == 0;
  wire [31:0] direct_rdata = (!write && valid && zero_latency) ? pmem_read(addr) : 32'd0;

  assign ready = zero_latency ? valid : (busy && delay_count == 32'd0);
  assign rdata = zero_latency ? direct_rdata : pending_rdata;

  initial begin
    latency = 0;
    if (LATENCY_PLUSARG != 0) begin
      if (!$value$plusargs("npc_mem_latency=%d", latency)) begin
        latency = 0;
      end
    end
  end

  always @(posedge clock) begin
    if (reset) begin
      busy <= 1'b0;
      delay_count <= 32'd0;
      pending_rdata <= 32'd0;
    end else if (!zero_latency) begin
      if (!busy && valid) begin
        busy <= 1'b1;
        delay_count <= latency[31:0];
        if (write) begin
          pmem_write(addr, wdata, {4'd0, wmask});
          pending_rdata <= 32'd0;
        end else begin
          pending_rdata <= pmem_read(addr);
        end
      end else if (busy && delay_count != 32'd0) begin
        delay_count <= delay_count - 32'd1;
      end else if (busy && delay_count == 32'd0) begin
        busy <= 1'b0;
      end
    end else if (valid && write) begin
      pmem_write(addr, wdata, {4'd0, wmask});
    end
  end

endmodule
