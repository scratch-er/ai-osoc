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
  import "DPI-C" function void pmem_write(input int unsigned addr, input int unsigned data, input byte wmask);

  reg        bvalid_q;
  reg [3:0]  bid_q;
  reg        rvalid_q;
  reg [31:0] rdata_q;
  reg [3:0]  rid_q;
  reg        have_aw;
  reg [31:0] awaddr_q;
  reg [3:0]  awid_q;

  wire read_fire = axi_arvalid && axi_arready;
  wire write_addr_fire = axi_awvalid && axi_awready;
  wire write_data_fire = axi_wvalid && axi_wready;
  wire have_write_addr = have_aw || write_addr_fire;
  wire [31:0] write_addr = have_aw ? awaddr_q : axi_awaddr;
  wire [3:0] write_id = have_aw ? awid_q : axi_awid;
  wire unused = |{axi_awlen, axi_awsize, axi_awburst, axi_wlast, axi_arlen, axi_arsize, axi_arburst};

  assign axi_awready = !reset && !bvalid_q && !have_aw;
  assign axi_wready = !reset && !bvalid_q && have_write_addr;
  assign axi_bvalid = bvalid_q;
  assign axi_bresp = 2'b00;
  assign axi_bid = bid_q;

  assign axi_arready = !reset && !rvalid_q;
  assign axi_rvalid = rvalid_q;
  assign axi_rresp = 2'b00;
  assign axi_rdata = rdata_q;
  assign axi_rlast = 1'b1;
  assign axi_rid = rid_q;

  always @(posedge clock) begin
    if (reset) begin
      bvalid_q <= 1'b0;
      bid_q <= 4'd0;
      rvalid_q <= 1'b0;
      rdata_q <= 32'd0;
      rid_q <= 4'd0;
      have_aw <= 1'b0;
      awaddr_q <= 32'd0;
      awid_q <= 4'd0;
    end else begin
      if (bvalid_q && axi_bready) begin
        bvalid_q <= 1'b0;
      end
      if (rvalid_q && axi_rready) begin
        rvalid_q <= 1'b0;
      end

      if (read_fire) begin
        rdata_q <= pmem_read(axi_araddr);
        rid_q <= axi_arid;
        rvalid_q <= 1'b1;
      end

      if (write_addr_fire && !write_data_fire) begin
        have_aw <= 1'b1;
        awaddr_q <= axi_awaddr;
        awid_q <= axi_awid;
      end

      if (write_data_fire) begin
        pmem_write(write_addr, axi_wdata, {4'd0, axi_wstrb});
        bid_q <= write_id;
        bvalid_q <= 1'b1;
        have_aw <= 1'b0;
      end
    end
  end

endmodule
