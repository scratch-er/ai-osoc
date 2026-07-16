`include "include/npc_defines.vh"

module NPC #(
  parameter RESET_PC = `NPC_RESET_PC,
  parameter LOCAL_AXI = 0
) (
  input         clock,
  input         reset,
  input         io_interrupt,
`ifdef NPC_DEBUG
  input  [31:0] io_reset_pc,
`endif
  input         io_master_awready,
  output        io_master_awvalid,
  output [31:0] io_master_awaddr,
  output [3:0]  io_master_awid,
  output [7:0]  io_master_awlen,
  output [2:0]  io_master_awsize,
  output [1:0]  io_master_awburst,
  input         io_master_wready,
  output        io_master_wvalid,
  output [31:0] io_master_wdata,
  output [3:0]  io_master_wstrb,
  output        io_master_wlast,
  output        io_master_bready,
  input         io_master_bvalid,
  input  [1:0]  io_master_bresp,
  input  [3:0]  io_master_bid,
  input         io_master_arready,
  output        io_master_arvalid,
  output [31:0] io_master_araddr,
  output [3:0]  io_master_arid,
  output [7:0]  io_master_arlen,
  output [2:0]  io_master_arsize,
  output [1:0]  io_master_arburst,
  output        io_master_rready,
  input         io_master_rvalid,
  input  [1:0]  io_master_rresp,
  input  [31:0] io_master_rdata,
  input         io_master_rlast,
  input  [3:0]  io_master_rid,
  output        io_slave_awready,
  input         io_slave_awvalid,
  input  [31:0] io_slave_awaddr,
  input  [3:0]  io_slave_awid,
  input  [7:0]  io_slave_awlen,
  input  [2:0]  io_slave_awsize,
  input  [1:0]  io_slave_awburst,
  output        io_slave_wready,
  input         io_slave_wvalid,
  input  [31:0] io_slave_wdata,
  input  [3:0]  io_slave_wstrb,
  input         io_slave_wlast,
  input         io_slave_bready,
  output        io_slave_bvalid,
  output [1:0]  io_slave_bresp,
  output [3:0]  io_slave_bid,
  output        io_slave_arready,
  input         io_slave_arvalid,
  input  [31:0] io_slave_araddr,
  input  [3:0]  io_slave_arid,
  input  [7:0]  io_slave_arlen,
  input  [2:0]  io_slave_arsize,
  input  [1:0]  io_slave_arburst,
  input         io_slave_rready,
  output        io_slave_rvalid,
  output [1:0]  io_slave_rresp,
  output [31:0] io_slave_rdata,
  output        io_slave_rlast,
  output [3:0]  io_slave_rid
`ifdef NPC_DEBUG
  ,
  output [31:0] debug_pc,
  output        debug_halted,
  output [31:0] debug_x1,
  output [31:0] debug_a0,
  output [1:0]  debug_trap_status,
  output [31:0] debug_inst,
  output [31:0] debug_mstatus,
  output [31:0] debug_mtvec,
  output [31:0] debug_mepc,
  output [31:0] debug_mcause,
  output [511:0] debug_regs_flat,
  output [63:0] debug_icache_accesses,
  output [63:0] debug_icache_hits,
  output [63:0] debug_icache_misses,
  output [63:0] debug_icache_miss_wait_cycles,
  output [63:0] debug_icache_refill_beats,
  output        commit_valid,
  output [31:0] commit_pc,
  output [31:0] commit_inst,
  output [31:0] commit_next_pc,
  output        commit_wen,
  output [4:0]  commit_rd,
  output [31:0] commit_wdata,
  output        commit_exception,
  output [31:0] commit_cause,
  output        commit_mem_wen,
  output        commit_mem_ren,
  output [31:0] commit_mem_addr,
  output [31:0] commit_mem_wdata,
  output [3:0]  commit_mem_wmask,
  output [31:0] commit_mem_rdata
`endif
);

  wire core_awready;
  wire core_wready;
  wire core_bvalid;
  wire [1:0] core_bresp;
  wire [3:0] core_bid;
  wire core_arready;
  wire core_rvalid;
  wire [1:0] core_rresp;
  wire [31:0] core_rdata;
  wire core_rlast;
  wire [3:0] core_rid;

`ifdef NPC_LOCAL_AXI
  wire local_awready;
  wire local_wready;
  wire local_bvalid;
  wire [1:0] local_bresp;
  wire [3:0] local_bid;
  wire local_arready;
  wire local_rvalid;
  wire [1:0] local_rresp;
  wire [31:0] local_rdata;
  wire local_rlast;
  wire [3:0] local_rid;
`endif

`ifndef NPC_DEBUG
  /* verilator lint_off UNUSED */
  wire [31:0] debug_pc;
  wire        debug_halted;
  wire [31:0] debug_x1;
  wire [31:0] debug_a0;
  wire [1:0]  debug_trap_status;
  wire [31:0] debug_inst;
  wire [31:0] debug_mstatus;
  wire [31:0] debug_mtvec;
  wire [31:0] debug_mepc;
  wire [31:0] debug_mcause;
  wire [511:0] debug_regs_flat;
  wire [63:0] debug_icache_accesses;
  wire [63:0] debug_icache_hits;
  wire [63:0] debug_icache_misses;
  wire [63:0] debug_icache_miss_wait_cycles;
  wire [63:0] debug_icache_refill_beats;
  wire        commit_valid;
  wire [31:0] commit_pc;
  wire [31:0] commit_inst;
  wire [31:0] commit_next_pc;
  wire        commit_wen;
  wire [4:0]  commit_rd;
  wire [31:0] commit_wdata;
  wire        commit_exception;
  wire [31:0] commit_cause;
  wire        commit_mem_wen;
  wire        commit_mem_ren;
  wire [31:0] commit_mem_addr;
  wire [31:0] commit_mem_wdata;
  wire [3:0]  commit_mem_wmask;
  wire [31:0] commit_mem_rdata;
  /* verilator lint_on UNUSED */
`endif

`ifdef NPC_DEBUG
  wire [31:0] core_reset_pc = io_reset_pc;
`else
  wire [31:0] core_reset_pc = 32'd0;
`endif

  wire unused_inputs = |{io_interrupt,
                         io_master_awready, io_master_wready, io_master_bvalid,
                         io_master_bresp, io_master_bid, io_master_arready,
                         io_master_rvalid, io_master_rresp, io_master_rdata,
                         io_master_rlast, io_master_rid,
                         io_slave_awvalid, io_slave_awaddr, io_slave_awid,
                         io_slave_awlen, io_slave_awsize, io_slave_awburst,
                         io_slave_wvalid, io_slave_wdata, io_slave_wstrb,
                         io_slave_wlast, io_slave_bready, io_slave_arvalid,
                         io_slave_araddr, io_slave_arid, io_slave_arlen,
                         io_slave_arsize, io_slave_arburst, io_slave_rready};

  assign io_slave_awready = 1'b0;
  assign io_slave_wready = 1'b0;
  assign io_slave_bvalid = 1'b0;
  assign io_slave_bresp = 2'b00;
  assign io_slave_bid = 4'd0;
  assign io_slave_arready = 1'b0;
  assign io_slave_rvalid = 1'b0;
  assign io_slave_rresp = 2'b00;
  assign io_slave_rdata = 32'd0;
  assign io_slave_rlast = 1'b0;
  assign io_slave_rid = 4'd0;

`ifdef NPC_LOCAL_AXI
  assign core_awready = (LOCAL_AXI != 0) ? local_awready : io_master_awready;
  assign core_wready = (LOCAL_AXI != 0) ? local_wready : io_master_wready;
  assign core_bvalid = (LOCAL_AXI != 0) ? local_bvalid : io_master_bvalid;
  assign core_bresp = (LOCAL_AXI != 0) ? local_bresp : io_master_bresp;
  assign core_bid = (LOCAL_AXI != 0) ? local_bid : io_master_bid;
  assign core_arready = (LOCAL_AXI != 0) ? local_arready : io_master_arready;
  assign core_rvalid = (LOCAL_AXI != 0) ? local_rvalid : io_master_rvalid;
  assign core_rresp = (LOCAL_AXI != 0) ? local_rresp : io_master_rresp;
  assign core_rdata = (LOCAL_AXI != 0) ? local_rdata : io_master_rdata;
  assign core_rlast = (LOCAL_AXI != 0) ? local_rlast : io_master_rlast;
  assign core_rid = (LOCAL_AXI != 0) ? local_rid : io_master_rid;
`else
  assign core_awready = io_master_awready;
  assign core_wready = io_master_wready;
  assign core_bvalid = io_master_bvalid;
  assign core_bresp = io_master_bresp;
  assign core_bid = io_master_bid;
  assign core_arready = io_master_arready;
  assign core_rvalid = io_master_rvalid;
  assign core_rresp = io_master_rresp;
  assign core_rdata = io_master_rdata;
  assign core_rlast = io_master_rlast;
  assign core_rid = io_master_rid;
`endif

  Core #(
    .RESET_PC(RESET_PC)
  ) u_core (
    .clock(clock),
    .reset(reset),
    .reset_pc(core_reset_pc),
    .debug_pc(debug_pc),
    .debug_halted(debug_halted),
    .debug_x1(debug_x1),
    .debug_a0(debug_a0),
    .debug_trap_status(debug_trap_status),
    .debug_inst(debug_inst),
    .debug_mstatus(debug_mstatus),
    .debug_mtvec(debug_mtvec),
    .debug_mepc(debug_mepc),
    .debug_mcause(debug_mcause),
    .debug_regs_flat(debug_regs_flat),
    .debug_icache_accesses(debug_icache_accesses),
    .debug_icache_hits(debug_icache_hits),
    .debug_icache_misses(debug_icache_misses),
    .debug_icache_miss_wait_cycles(debug_icache_miss_wait_cycles),
    .debug_icache_refill_beats(debug_icache_refill_beats),
    .commit_valid(commit_valid),
    .commit_pc(commit_pc),
    .commit_inst(commit_inst),
    .commit_next_pc(commit_next_pc),
    .commit_wen(commit_wen),
    .commit_rd(commit_rd),
    .commit_wdata(commit_wdata),
    .commit_exception(commit_exception),
    .commit_cause(commit_cause),
    .commit_mem_wen(commit_mem_wen),
    .commit_mem_ren(commit_mem_ren),
    .commit_mem_addr(commit_mem_addr),
    .commit_mem_wdata(commit_mem_wdata),
    .commit_mem_wmask(commit_mem_wmask),
    .commit_mem_rdata(commit_mem_rdata),
    .axi_awready(core_awready),
    .axi_awvalid(io_master_awvalid),
    .axi_awaddr(io_master_awaddr),
    .axi_awid(io_master_awid),
    .axi_awlen(io_master_awlen),
    .axi_awsize(io_master_awsize),
    .axi_awburst(io_master_awburst),
    .axi_wready(core_wready),
    .axi_wvalid(io_master_wvalid),
    .axi_wdata(io_master_wdata),
    .axi_wstrb(io_master_wstrb),
    .axi_wlast(io_master_wlast),
    .axi_bready(io_master_bready),
    .axi_bvalid(core_bvalid),
    .axi_bresp(core_bresp),
    .axi_bid(core_bid),
    .axi_arready(core_arready),
    .axi_arvalid(io_master_arvalid),
    .axi_araddr(io_master_araddr),
    .axi_arid(io_master_arid),
    .axi_arlen(io_master_arlen),
    .axi_arsize(io_master_arsize),
    .axi_arburst(io_master_arburst),
    .axi_rready(io_master_rready),
    .axi_rvalid(core_rvalid),
    .axi_rresp(core_rresp),
    .axi_rdata(core_rdata),
    .axi_rlast(core_rlast),
    .axi_rid(core_rid)
  );

`ifdef NPC_LOCAL_AXI
  LocalAxiSlave u_local_axi (
    .clock(clock),
    .reset(reset || (LOCAL_AXI == 0)),
    .axi_awready(local_awready),
    .axi_awvalid(io_master_awvalid),
    .axi_awaddr(io_master_awaddr),
    .axi_awid(io_master_awid),
    .axi_awlen(io_master_awlen),
    .axi_awsize(io_master_awsize),
    .axi_awburst(io_master_awburst),
    .axi_wready(local_wready),
    .axi_wvalid(io_master_wvalid),
    .axi_wdata(io_master_wdata),
    .axi_wstrb(io_master_wstrb),
    .axi_wlast(io_master_wlast),
    .axi_bready(io_master_bready),
    .axi_bvalid(local_bvalid),
    .axi_bresp(local_bresp),
    .axi_bid(local_bid),
    .axi_arready(local_arready),
    .axi_arvalid(io_master_arvalid),
    .axi_araddr(io_master_araddr),
    .axi_arid(io_master_arid),
    .axi_arlen(io_master_arlen),
    .axi_arsize(io_master_arsize),
    .axi_arburst(io_master_arburst),
    .axi_rready(io_master_rready),
    .axi_rvalid(local_rvalid),
    .axi_rresp(local_rresp),
    .axi_rdata(local_rdata),
    .axi_rlast(local_rlast),
    .axi_rid(local_rid)
  );
`endif

endmodule
