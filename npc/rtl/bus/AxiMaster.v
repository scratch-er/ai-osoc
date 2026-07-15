module AxiMaster (
  input         clock,
  input         reset,
  input         req_valid,
  input         req_write,
  input  [31:0] req_addr,
  input  [7:0]  req_len,
  input  [31:0] req_wdata,
  input  [3:0]  req_wmask,
  output        req_ready,
  output [31:0] req_rdata,
  output        req_error,

  input         axi_awready,
  output        axi_awvalid,
  output [31:0] axi_awaddr,
  output [3:0]  axi_awid,
  output [7:0]  axi_awlen,
  output [2:0]  axi_awsize,
  output [1:0]  axi_awburst,
  input         axi_wready,
  output        axi_wvalid,
  output [31:0] axi_wdata,
  output [3:0]  axi_wstrb,
  output        axi_wlast,
  output        axi_bready,
  input         axi_bvalid,
  input  [1:0]  axi_bresp,
  input  [3:0]  axi_bid,
  input         axi_arready,
  output        axi_arvalid,
  output [31:0] axi_araddr,
  output [3:0]  axi_arid,
  output [7:0]  axi_arlen,
  output [2:0]  axi_arsize,
  output [1:0]  axi_arburst,
  output        axi_rready,
  input         axi_rvalid,
  input  [1:0]  axi_rresp,
  input  [31:0] axi_rdata,
  input         axi_rlast,
  input  [3:0]  axi_rid
);

  localparam S_IDLE       = 3'd0;
  localparam S_READ_ADDR  = 3'd1;
  localparam S_READ_DATA  = 3'd2;
  localparam S_WRITE_REQ  = 3'd3;
  localparam S_WRITE_RESP = 3'd4;

  reg [2:0]  state;
  reg [31:0] addr_q;
  reg [7:0]  len_q;
  reg [7:0]  read_beat_q;
  reg [31:0] wdata_q;
  reg [3:0]  wmask_q;
  reg [31:0] rdata_q;
  reg        read_error_q;
  reg        aw_done;
  reg        w_done;

  wire start_read = state == S_IDLE && req_valid && !req_write;
  wire start_write = state == S_IDLE && req_valid && req_write;
  wire read_fire = state == S_READ_DATA && axi_rvalid;
  wire read_last = read_fire && (axi_rlast || read_beat_q == len_q);
  wire write_done = state == S_WRITE_RESP && axi_bvalid;
  wire aw_fire = axi_awvalid && axi_awready;
  wire w_fire = axi_wvalid && axi_wready;
  wire unused = |{axi_bid, axi_rid};

  assign req_ready = read_fire || write_done;
  assign req_rdata = read_fire ? axi_rdata : rdata_q;
  assign req_error = (read_fire && (read_error_q || axi_rresp != 2'b00)) ||
                     (write_done && axi_bresp != 2'b00);

  assign axi_awvalid = state == S_WRITE_REQ && !aw_done;
  assign axi_awaddr = addr_q;
  assign axi_awid = 4'd0;
  assign axi_awlen = 8'd0;
  assign axi_awsize = 3'b010;
  assign axi_awburst = 2'b01;
  assign axi_wvalid = state == S_WRITE_REQ && !w_done;
  assign axi_wdata = wdata_q;
  assign axi_wstrb = wmask_q;
  assign axi_wlast = 1'b1;
  assign axi_bready = state == S_WRITE_RESP;

  assign axi_arvalid = state == S_READ_ADDR;
  assign axi_araddr = addr_q;
  assign axi_arid = 4'd0;
  assign axi_arlen = len_q;
  assign axi_arsize = 3'b010;
  assign axi_arburst = 2'b01;
  assign axi_rready = state == S_READ_DATA;

  always @(posedge clock) begin
    if (reset) begin
      state <= S_IDLE;
      addr_q <= 32'd0;
      len_q <= 8'd0;
      read_beat_q <= 8'd0;
      wdata_q <= 32'd0;
      wmask_q <= 4'd0;
      rdata_q <= 32'd0;
      read_error_q <= 1'b0;
      aw_done <= 1'b0;
      w_done <= 1'b0;
    end else begin
      case (state)
        S_IDLE: begin
          aw_done <= 1'b0;
          w_done <= 1'b0;
          read_beat_q <= 8'd0;
          read_error_q <= 1'b0;
          if (start_read || start_write) begin
            addr_q <= req_addr;
            len_q <= start_read ? req_len : 8'd0;
            wdata_q <= req_wdata;
            wmask_q <= req_wmask;
            state <= start_write ? S_WRITE_REQ : S_READ_ADDR;
          end
        end
        S_READ_ADDR: begin
          if (axi_arready) begin
            state <= S_READ_DATA;
          end
        end
        S_READ_DATA: begin
          if (read_fire) begin
            rdata_q <= axi_rdata;
            read_error_q <= read_error_q || (axi_rresp != 2'b00);
            read_beat_q <= read_beat_q + 8'd1;
            if (read_last) begin
              state <= S_IDLE;
            end
          end
        end
        S_WRITE_REQ: begin
          if (aw_fire) begin
            aw_done <= 1'b1;
          end
          if (w_fire) begin
            w_done <= 1'b1;
          end
          if ((aw_done || aw_fire) && (w_done || w_fire)) begin
            state <= S_WRITE_RESP;
          end
        end
        S_WRITE_RESP: begin
          if (axi_bvalid) begin
            state <= S_IDLE;
          end
        end
        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule
