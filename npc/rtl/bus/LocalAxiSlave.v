module LocalAxiSlave (
  input         clock,
  input         reset,
  output        axi_awready,
  input         axi_awvalid,
  input  [31:0] axi_awaddr,
  input  [3:0]  axi_awid,
  input  [7:0]  axi_awlen,
  input  [2:0]  axi_awsize,
  input  [1:0]  axi_awburst,
  output        axi_wready,
  input         axi_wvalid,
  input  [31:0] axi_wdata,
  input  [3:0]  axi_wstrb,
  input         axi_wlast,
  input         axi_bready,
  output        axi_bvalid,
  output [1:0]  axi_bresp,
  output [3:0]  axi_bid,
  output        axi_arready,
  input         axi_arvalid,
  input  [31:0] axi_araddr,
  input  [3:0]  axi_arid,
  input  [7:0]  axi_arlen,
  input  [2:0]  axi_arsize,
  input  [1:0]  axi_arburst,
  input         axi_rready,
  output        axi_rvalid,
  output [1:0]  axi_rresp,
  output [31:0] axi_rdata,
  output        axi_rlast,
  output [3:0]  axi_rid
);

  import "DPI-C" function int unsigned pmem_read(input int unsigned addr);
  import "DPI-C" function int unsigned pmem_access_ok(input int unsigned addr);
  import "DPI-C" function void pmem_write(input int unsigned addr, input int unsigned data, input byte wmask);

  reg        bvalid_q;
  reg [1:0]  bresp_q;
  reg [3:0]  bid_q;
  reg        rvalid_q;
  reg [1:0]  rresp_q;
  reg [31:0] rdata_q;
  reg [3:0]  rid_q;
  reg        rlast_q;
  reg [31:0] raddr_q;
  reg [7:0]  rlen_q;
  reg [7:0]  rbeat_q;
  reg        have_aw;
  reg [31:0] awaddr_q;
  reg [3:0]  awid_q;

  wire read_fire = axi_arvalid && axi_arready;
  wire read_beat_fire = rvalid_q && axi_rready;
  wire write_addr_fire = axi_awvalid && axi_awready;
  wire write_data_fire = axi_wvalid && axi_wready;
  wire have_write_addr = have_aw || write_addr_fire;
  wire [31:0] write_addr = have_aw ? awaddr_q : axi_awaddr;
  wire [3:0] write_id = have_aw ? awid_q : axi_awid;
  wire [31:0] next_raddr = read_fire ? axi_araddr : (raddr_q + 32'd4);
  wire [7:0] next_rbeat = read_fire ? 8'd0 : (rbeat_q + 8'd1);
  wire next_rlast = next_rbeat == (read_fire ? axi_arlen : rlen_q);
  wire unused = |{axi_awlen, axi_awsize, axi_awburst, axi_wlast, axi_arsize, axi_arburst};

  assign axi_awready = !reset && !bvalid_q && !have_aw;
  assign axi_wready = !reset && !bvalid_q && have_write_addr;
  assign axi_bvalid = bvalid_q;
  assign axi_bresp = bresp_q;
  assign axi_bid = bid_q;

  assign axi_arready = !reset && !rvalid_q;
  assign axi_rvalid = rvalid_q;
  assign axi_rresp = rresp_q;
  assign axi_rdata = rdata_q;
  assign axi_rlast = rlast_q;
  assign axi_rid = rid_q;

  always @(posedge clock) begin
    if (reset) begin
      bvalid_q <= 1'b0;
      bresp_q <= 2'b00;
      bid_q <= 4'd0;
      rvalid_q <= 1'b0;
      rresp_q <= 2'b00;
      rdata_q <= 32'd0;
      rid_q <= 4'd0;
      rlast_q <= 1'b0;
      raddr_q <= 32'd0;
      rlen_q <= 8'd0;
      rbeat_q <= 8'd0;
      have_aw <= 1'b0;
      awaddr_q <= 32'd0;
      awid_q <= 4'd0;
    end else begin
      if (bvalid_q && axi_bready) begin
        bvalid_q <= 1'b0;
      end
      if (read_beat_fire) begin
        rvalid_q <= 1'b0;
      end

      if (read_fire || (read_beat_fire && !rlast_q)) begin
        if (pmem_access_ok(next_raddr) != 0) begin
          rdata_q <= pmem_read(next_raddr);
          rresp_q <= 2'b00;
        end else begin
          rdata_q <= 32'd0;
          rresp_q <= 2'b10;
        end
        rid_q <= read_fire ? axi_arid : rid_q;
        rlast_q <= next_rlast;
        rvalid_q <= 1'b1;
        raddr_q <= next_raddr;
        rlen_q <= read_fire ? axi_arlen : rlen_q;
        rbeat_q <= next_rbeat;
      end

      if (write_addr_fire && !write_data_fire) begin
        have_aw <= 1'b1;
        awaddr_q <= axi_awaddr;
        awid_q <= axi_awid;
      end

      if (write_data_fire) begin
        if (pmem_access_ok(write_addr) != 0) begin
          pmem_write(write_addr, axi_wdata, {4'd0, axi_wstrb});
          bresp_q <= 2'b00;
        end else begin
          bresp_q <= 2'b10;
        end
        bid_q <= write_id;
        bvalid_q <= 1'b1;
        have_aw <= 1'b0;
      end
    end
  end

endmodule
