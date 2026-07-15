#!/usr/bin/env python3
import struct
import sys


def i32(x):
    return x & 0xffffffff


def addi(rd, rs1, imm):
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x13


def branch(funct3, rs1, rs2, imm):
    imm &= 0x1fff
    return (((imm >> 12) & 0x1) << 31) | (((imm >> 5) & 0x3f) << 25) | \
           (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | \
           (((imm >> 1) & 0xf) << 8) | (((imm >> 11) & 0x1) << 7) | 0x63


prog = [
    addi(1, 0, 0),        # x1 = 0
    addi(2, 0, 8),        # x2 = loop bound
    addi(1, 1, 1),        # loop: x1++
    branch(4, 1, 2, -4),  # blt x1, x2, loop
    0x00100073,           # ebreak
]

out_path = sys.argv[1]
with open(out_path, 'wb') as f:
    for inst in prog:
        f.write(struct.pack('<I', i32(inst)))
