#!/usr/bin/env python3
import struct
import sys


def i32(x):
    return x & 0xffffffff


def addi(rd, rs1, imm):
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x13


def lui(rd, imm20):
    return (imm20 << 12) | (rd << 7) | 0x37


def sw(rs2, imm, rs1):
    imm &= 0xfff
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((imm & 0x1f) << 7) | 0x23


def jal(rd, imm):
    imm &= 0x1fffff
    return (((imm >> 20) & 0x1) << 31) | (((imm >> 1) & 0x3ff) << 21) | \
           (((imm >> 11) & 0x1) << 20) | (((imm >> 12) & 0xff) << 12) | \
           (rd << 7) | 0x6f


PATCH_INST = addi(1, 0, 1)

prog = [
    jal(0, 16),            # 0x80000000: jump to patcher, fetching target line first
    addi(1, 0, 0),         # 0x80000004: target patched to addi x1,x0,1
    0x00100073,            # 0x80000008: ebreak
    addi(0, 0, 0),         # 0x8000000c: padding
    lui(2, 0x80000),       # 0x80000010: x2 = base
    lui(3, PATCH_INST >> 12),
    addi(3, 3, PATCH_INST & 0xfff),
    sw(3, 4, 2),           # patch target instruction at base + 4
    0x0000100f,            # fence.i
    jal(0, -32),           # jump back to target at 0x80000004
]

out_path = sys.argv[1]
with open(out_path, 'wb') as f:
    for inst in prog:
        f.write(struct.pack('<I', i32(inst)))
