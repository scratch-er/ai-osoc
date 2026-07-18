#!/usr/bin/env python3
# Zero-patch SoC smoke: MROM program that prints "SOC\n" through the UART16550
# (validates MROM instruction fetch and the AXI->APB MMIO store path), then
# spins forever. The harness terminates by cycle limit; pass/fail comes from
# the RTL-printed UART bytes plus the NPC_SOC_RESULT line.
import struct
import sys


def addi(rd, rs1, imm):
    imm &= 0xfff
    return (imm << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x13


def lui(rd, imm20):
    return (imm20 << 12) | (rd << 7) | 0x37


def sw(rs2, rs1, imm):
    imm &= 0xfff
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((imm & 0x1f) << 7) | 0x23


def jal(rd, imm):
    imm &= 0x1fffff
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3ff) << 21) | \
        (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xff) << 12) | (rd << 7) | 0x6f


def main():
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} OUT", file=sys.stderr)
        return 1

    insts = [lui(1, 0x10000)]
    for ch in b"SOC\n":
        insts.append(addi(2, 0, ch))
        insts.append(sw(2, 1, 0))
    insts.append(jal(0, 0))

    with open(sys.argv[1], "wb") as f:
        for inst in insts:
            f.write(struct.pack("<I", inst))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
