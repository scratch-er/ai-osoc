`ifndef NPC_DEFINES_VH
`define NPC_DEFINES_VH

`define NPC_RESET_PC 32'h2000_0000

`define NPC_STATUS_RUNNING 2'd0
`define NPC_STATUS_GOOD    2'd1
`define NPC_STATUS_BAD     2'd2
`define NPC_STATUS_LIMIT   2'd3

`define NPC_ALU_ADD  4'd0
`define NPC_ALU_SUB  4'd1
`define NPC_ALU_SLL  4'd2
`define NPC_ALU_SLT  4'd3
`define NPC_ALU_SLTU 4'd4
`define NPC_ALU_XOR  4'd5
`define NPC_ALU_SRL  4'd6
`define NPC_ALU_SRA  4'd7
`define NPC_ALU_OR   4'd8
`define NPC_ALU_AND  4'd9
`define NPC_ALU_COPY_B 4'd10

`define NPC_IMM_I 3'd0
`define NPC_IMM_S 3'd1
`define NPC_IMM_B 3'd2
`define NPC_IMM_U 3'd3
`define NPC_IMM_J 3'd4

`define NPC_WB_ALU 2'd0
`define NPC_WB_MEM 2'd1
`define NPC_WB_PC4 2'd2

`define NPC_BR_NONE 3'd0
`define NPC_BR_BEQ  3'd1
`define NPC_BR_BNE  3'd2
`define NPC_BR_BLT  3'd3
`define NPC_BR_BGE  3'd4
`define NPC_BR_BLTU 3'd5
`define NPC_BR_BGEU 3'd6

`define NPC_MEM_BYTE 2'd0
`define NPC_MEM_HALF 2'd1
`define NPC_MEM_WORD 2'd2

`define NPC_SYS_NONE   2'd0
`define NPC_SYS_EBREAK 2'd1

`define NPC_EXC_NONE                  5'd31
`define NPC_EXC_INST_ADDR_MISALIGNED  5'd0
`define NPC_EXC_INST_ACCESS_FAULT     5'd1
`define NPC_EXC_ILLEGAL_INST          5'd2
`define NPC_EXC_BREAKPOINT            5'd3
`define NPC_EXC_LOAD_ADDR_MISALIGNED  5'd4
`define NPC_EXC_LOAD_ACCESS_FAULT     5'd5
`define NPC_EXC_STORE_ADDR_MISALIGNED 5'd6
`define NPC_EXC_STORE_ACCESS_FAULT    5'd7
`define NPC_EXC_ECALL_M               5'd11

`endif
