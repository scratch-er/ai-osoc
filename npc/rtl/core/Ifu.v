module Ifu (
  input         clock,
  input         reset,
  input         invalidate,
  input         fetch_valid,
  input  [31:0] pc,
  input         bus_ready,
  input  [31:0] bus_rdata,
  input         bus_error,
  output        bus_valid,
  output [31:0] bus_addr,
  output [7:0]  bus_len,
  output        inst_ready,
  output [31:0] inst,
  output        inst_error,
  output [63:0] debug_accesses,
  output [63:0] debug_hits,
  output [63:0] debug_misses,
  output [63:0] debug_miss_wait_cycles,
  output [63:0] debug_refill_beats
);

  localparam S_IDLE   = 1'b0;
  localparam S_REFILL = 1'b1;

  reg        state;
  reg [1:0]  valid_q;
  reg [26:0] tag0_q;
  reg [26:0] tag1_q;
  reg [31:0] data0_0_q;
  reg [31:0] data0_1_q;
  reg [31:0] data0_2_q;
  reg [31:0] data0_3_q;
  reg [31:0] data1_0_q;
  reg [31:0] data1_1_q;
  reg [31:0] data1_2_q;
  reg [31:0] data1_3_q;
  reg        miss_index_q;
  reg [1:0]  miss_offset_q;
  reg [26:0] miss_tag_q;
  reg [31:0] miss_line_addr_q;
  reg [1:0]  refill_beat_q;
  reg [31:0] refill_word0_q;
  reg [31:0] refill_word1_q;
  reg [31:0] refill_word2_q;
  reg [31:0] refill_word3_q;
  reg        refill_error_q;
  reg [63:0] accesses_q;
  reg [63:0] hits_q;
  reg [63:0] misses_q;
  reg [63:0] miss_wait_cycles_q;
  reg [63:0] refill_beats_q;

  wire        index = pc[4];
  wire [1:0]  offset = pc[3:2];
  wire [26:0] tag = pc[31:5];
  wire [31:0] line_addr = {pc[31:4], 4'b0000};
  wire        hit0 = valid_q[0] && tag0_q == tag;
  wire        hit1 = valid_q[1] && tag1_q == tag;
  wire        hit = index ? hit1 : hit0;
  wire [31:0] hit_word0 = (offset == 2'd0) ? data0_0_q :
                          (offset == 2'd1) ? data0_1_q :
                          (offset == 2'd2) ? data0_2_q : data0_3_q;
  wire [31:0] hit_word1 = (offset == 2'd0) ? data1_0_q :
                          (offset == 2'd1) ? data1_1_q :
                          (offset == 2'd2) ? data1_2_q : data1_3_q;
  wire [31:0] hit_word = index ? hit_word1 : hit_word0;
  wire        refill_fire = state == S_REFILL && bus_ready;
  wire        refill_last = refill_fire && refill_beat_q == 2'd3;
  wire        refill_error = refill_error_q || bus_error;
  wire [31:0] refill_word0 = (refill_beat_q == 2'd0 && refill_fire) ? bus_rdata : refill_word0_q;
  wire [31:0] refill_word1 = (refill_beat_q == 2'd1 && refill_fire) ? bus_rdata : refill_word1_q;
  wire [31:0] refill_word2 = (refill_beat_q == 2'd2 && refill_fire) ? bus_rdata : refill_word2_q;
  wire [31:0] refill_word3 = (refill_beat_q == 2'd3 && refill_fire) ? bus_rdata : refill_word3_q;
  wire [31:0] refill_inst = (miss_offset_q == 2'd0) ? refill_word0 :
                            (miss_offset_q == 2'd1) ? refill_word1 :
                            (miss_offset_q == 2'd2) ? refill_word2 : refill_word3;
  wire        unused = |pc[1:0];

  assign bus_valid = state == S_REFILL;
  assign bus_addr = miss_line_addr_q;
  assign bus_len = 8'd3;
  assign inst_ready = (state == S_IDLE && fetch_valid && hit) || refill_last;
  assign inst = (state == S_IDLE && hit) ? hit_word : refill_inst;
  assign inst_error = refill_last && refill_error;
  assign debug_accesses = accesses_q;
  assign debug_hits = hits_q;
  assign debug_misses = misses_q;
  assign debug_miss_wait_cycles = miss_wait_cycles_q;
  assign debug_refill_beats = refill_beats_q;

  always @(posedge clock) begin
    if (reset) begin
      state <= S_IDLE;
      valid_q <= 2'b00;
      tag0_q <= 27'd0;
      tag1_q <= 27'd0;
      data0_0_q <= 32'd0;
      data0_1_q <= 32'd0;
      data0_2_q <= 32'd0;
      data0_3_q <= 32'd0;
      data1_0_q <= 32'd0;
      data1_1_q <= 32'd0;
      data1_2_q <= 32'd0;
      data1_3_q <= 32'd0;
      miss_index_q <= 1'b0;
      miss_offset_q <= 2'd0;
      miss_tag_q <= 27'd0;
      miss_line_addr_q <= 32'd0;
      refill_beat_q <= 2'd0;
      refill_word0_q <= 32'd0;
      refill_word1_q <= 32'd0;
      refill_word2_q <= 32'd0;
      refill_word3_q <= 32'd0;
      refill_error_q <= 1'b0;
      accesses_q <= 64'd0;
      hits_q <= 64'd0;
      misses_q <= 64'd0;
      miss_wait_cycles_q <= 64'd0;
      refill_beats_q <= 64'd0;
    end else begin
      if (invalidate) begin
        valid_q <= 2'b00;
      end

      case (state)
        S_IDLE: begin
          if (fetch_valid) begin
            if (hit) begin
              accesses_q <= accesses_q + 64'd1;
              hits_q <= hits_q + 64'd1;
            end else begin
              accesses_q <= accesses_q + 64'd1;
              misses_q <= misses_q + 64'd1;
              state <= S_REFILL;
              miss_index_q <= index;
              miss_offset_q <= offset;
              miss_tag_q <= tag;
              miss_line_addr_q <= line_addr;
              refill_beat_q <= 2'd0;
              refill_word0_q <= 32'd0;
              refill_word1_q <= 32'd0;
              refill_word2_q <= 32'd0;
              refill_word3_q <= 32'd0;
              refill_error_q <= 1'b0;
            end
          end
        end
        S_REFILL: begin
          miss_wait_cycles_q <= miss_wait_cycles_q + 64'd1;
          if (refill_fire) begin
            refill_beats_q <= refill_beats_q + 64'd1;
            refill_error_q <= refill_error;
            case (refill_beat_q)
              2'd0: refill_word0_q <= bus_rdata;
              2'd1: refill_word1_q <= bus_rdata;
              2'd2: refill_word2_q <= bus_rdata;
              default: refill_word3_q <= bus_rdata;
            endcase
            refill_beat_q <= refill_beat_q + 2'd1;
            if (refill_last) begin
              state <= S_IDLE;
              if (!refill_error) begin
                if (miss_index_q) begin
                  valid_q[1] <= !invalidate;
                  tag1_q <= miss_tag_q;
                  data1_0_q <= refill_word0;
                  data1_1_q <= refill_word1;
                  data1_2_q <= refill_word2;
                  data1_3_q <= refill_word3;
                end else begin
                  valid_q[0] <= !invalidate;
                  tag0_q <= miss_tag_q;
                  data0_0_q <= refill_word0;
                  data0_1_q <= refill_word1;
                  data0_2_q <= refill_word2;
                  data0_3_q <= refill_word3;
                end
              end
            end
          end
        end
      endcase
    end
  end

endmodule
