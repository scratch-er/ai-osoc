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


def lxor(rd, rs1, rs2):
    return (rs2 << 20) | (rs1 << 15) | (4 << 12) | (rd << 7) | 0x33


prog = [
    lui(2, 0x0200c),     # x2 = 0x0200c000
    lw(3, -4, 2),        # mtime high before low read
    lw(4, -8, 2),        # mtime low
    lw(5, -4, 2),        # mtime high after low read
    lxor(13, 3, 5),      # x13 = high words differed
    sltiu(13, 13, 1),    # x13 = high was stable across low read
    lw(6, -8, 2),        # later mtime low
    lw(7, -4, 2),        # later mtime high
    lxor(14, 5, 7),      # x14 = high words differed
    sltiu(14, 14, 1),    # x14 = high remained stable in short smoke
    sltu(8, 4, 6),       # x8 = low word advanced
    lui(12, 0x02000),    # x12 = CLINT base
    sw(0, 0, 12),        # ignored msip write, no error
    lw(9, 0, 12),        # ignored read returns zero in this implementation
    sltiu(9, 9, 1),      # x9 = ignored read was zero
    land(1, 8, 13),      # x1 = low advanced and hi/lo/hi was stable
    land(1, 1, 14),
    land(1, 1, 9),
    0x00100073,          # ebreak
]

out_path = sys.argv[1]
with open(out_path, 'wb') as f:
    for inst in prog:
        f.write(struct.pack('<I', i32(inst)))
