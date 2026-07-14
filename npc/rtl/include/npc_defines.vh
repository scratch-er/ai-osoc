`ifndef NPC_DEFINES_VH
`define NPC_DEFINES_VH

`define NPC_RESET_PC 32'h2000_0000

`define NPC_STATUS_RUNNING 2'd0
`define NPC_STATUS_GOOD    2'd1
`define NPC_STATUS_BAD     2'd2
`define NPC_STATUS_LIMIT   2'd3

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
