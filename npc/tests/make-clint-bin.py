#!/usr/bin/env python3
import struct
import sys


def i32(x):
    return x & 0xffffffff


def lui(rd, imm20):
    return (imm20 << 12) | (rd << 7) | 0x37


def lw(rd, imm, rs1):
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (2 << 12) | (rd << 7) | 0x03


def sw(rs2, imm, rs1):
    imm &= 0xfff
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((imm & 0x1f) << 7) | 0x23


def sltu(rd, rs1, rs2):
    return (rs2 << 20) | (rs1 << 15) | (3 << 12) | (rd << 7) | 0x33


def sltiu(rd, rs1, imm):
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (3 << 12) | (rd << 7) | 0x13


def land(rd, rs1, rs2):
    return (rs2 << 20) | (rs1 << 15) | (7 << 12) | (rd << 7) | 0x33


prog = [
    lui(2, 0x0200c),     # x2 = 0x0200c000
    lw(3, -8, 2),        # mtime low
    lw(4, -8, 2),        # later mtime low
    sltu(5, 3, 4),       # x5 = mtime advanced
    lui(7, 0x02000),     # x7 = CLINT base
    sw(0, 0, 7),         # ignored msip write, no error
    lw(6, 0, 7),         # ignored read returns zero in this implementation
    sltiu(6, 6, 1),      # x6 = ignored read was zero
    land(1, 5, 6),       # x1 = both checks passed
    0x00100073,          # ebreak
]

out_path = sys.argv[1]
with open(out_path, 'wb') as f:
    for inst in prog:
        f.write(struct.pack('<I', i32(inst)))
