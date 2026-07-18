#!/usr/bin/env python3
"""Generate an SRAM load/store validation program for the ysyxSoC flavor.

The program boots from MROM at 0x20000000, uses 0x0f000000..0x0f001fff as
writable SRAM, prints PASS/FAIL through the UART16550 at 0x10000000, and
terminates with ebreak.  It exercises byte/halfword/word stores and loads,
narrow-transfer wstrb behavior, and read-after-write patterns across the full
8KB SRAM window.  Designed to run under DiffTest against NEMU.
"""
import struct
import sys


# RISC-V RV32E instruction encoders (same encoding as RV32I, reg numbers <= 15).
def i_type(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def s_type(imm, rs2, rs1, funct3, opcode):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (
        (imm & 0x1F) << 7) | opcode


def b_type(imm, rs2, rs1, funct3, opcode):
    imm &= 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (
        rs1 << 15) | (funct3 << 12) | (((imm >> 1) & 0xF) << 8) | (
        ((imm >> 11) & 1) << 7) | opcode


def u_type(imm, rd, opcode):
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | opcode


def j_type(imm, rd, opcode):
    imm &= 0x1FFFFF
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (
        ((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | opcode


def r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


# Convenience helpers.
def addi(rd, rs1, imm): return i_type(imm, rs1, 0, rd, 0x13)
def slli(rd, rs1, shamt): return i_type(shamt & 0x1F, rs1, 1, rd, 0x13)
def xori(rd, rs1, imm): return i_type(imm, rs1, 4, rd, 0x13)
def ori(rd, rs1, imm): return i_type(imm, rs1, 6, rd, 0x13)
def andi(rd, rs1, imm): return i_type(imm, rs1, 7, rd, 0x13)
def lui(rd, imm20): return u_type(imm20, rd, 0x37)
def jal(rd, imm): return j_type(imm, rd, 0x6F)
def beq(rs1, rs2, imm): return b_type(imm, rs2, rs1, 0, 0x63)
def bne(rs1, rs2, imm): return b_type(imm, rs2, rs1, 1, 0x63)
def blt(rs1, rs2, imm): return b_type(imm, rs2, rs1, 4, 0x63)
def bge(rs1, rs2, imm): return b_type(imm, rs2, rs1, 5, 0x63)
def or_r(rd, rs1, rs2): return r_type(0, rs2, rs1, 6, rd, 0x33)
def xor_r(rd, rs1, rs2): return r_type(0, rs2, rs1, 4, rd, 0x33)
def lb(rd, imm, rs1): return i_type(imm, rs1, 0, rd, 0x03)
def lh(rd, imm, rs1): return i_type(imm, rs1, 1, rd, 0x03)
def lw(rd, imm, rs1): return i_type(imm, rs1, 2, rd, 0x03)
def lbu(rd, imm, rs1): return i_type(imm, rs1, 4, rd, 0x03)
def lhu(rd, imm, rs1): return i_type(imm, rs1, 5, rd, 0x03)
def sb(rs2, imm, rs1): return s_type(imm, rs2, rs1, 0, 0x23)
def sh(rs2, imm, rs1): return s_type(imm, rs2, rs1, 1, 0x23)
def sw(rs2, imm, rs1): return s_type(imm, rs2, rs1, 2, 0x23)
EBREAK = 0x00100073


# Simple two-pass assembler for branch/jal label resolution.
class Prog:
    def __init__(self):
        self.items = []  # ('i', inst) | ('l', name) | ('b', funct3, rs1, rs2, name) | ('j', rd, name)

    def emit(self, inst):
        self.items.append(('i', inst))

    def label(self, name):
        self.items.append(('l', name))

    def beq(self, rs1, rs2, name): self.items.append(('b', 0, rs1, rs2, name))
    def bne(self, rs1, rs2, name): self.items.append(('b', 1, rs1, rs2, name))
    def blt(self, rs1, rs2, name): self.items.append(('b', 4, rs1, rs2, name))
    def bge(self, rs1, rs2, name): self.items.append(('b', 5, rs1, rs2, name))
    def jal(self, rd, name): self.items.append(('j', rd, name))

    def li(self, rd, value):
        value &= 0xFFFFFFFF
        # 32-bit signed value.
        if value >= 0x80000000:
            value -= 0x100000000
        high = (value + 0x800) >> 12
        low = value & 0xFFF
        self.emit(lui(rd, high & 0xFFFFF))
        self.emit(addi(rd, rd, low))

    def encode(self):
        # First pass: assign label positions.
        labels = {}
        pos = 0
        for kind, *rest in self.items:
            if kind == 'l':
                labels[rest[0]] = pos
            else:
                pos += 4
        # Second pass: emit instructions and resolve branches/jumps.
        out = []
        pos = 0
        for item in self.items:
            kind = item[0]
            if kind == 'l':
                continue
            if kind == 'i':
                out.append(item[1] & 0xFFFFFFFF)
                pos += 4
            elif kind == 'b':
                _, funct3, rs1, rs2, name = item
                imm = labels[name] - pos
                out.append(b_type(imm, rs2, rs1, funct3, 0x63) & 0xFFFFFFFF)
                pos += 4
            elif kind == 'j':
                _, rd, name = item
                imm = labels[name] - pos
                out.append(jal(rd, imm) & 0xFFFFFFFF)
                pos += 4
            else:
                raise ValueError(f"unknown item {item}")
        return out


def emit_print(p, uart_base_reg, char):
    """Emit sb of an immediate char to the UART base register."""
    p.emit(addi(14, 0, ord(char)))
    p.emit(sb(14, 0, uart_base_reg))


def build_program():
    SRAM_BASE = 0x0F000000
    UART_BASE = 0x10000000
    WORDS = 2048  # 8KB / 4

    p = Prog()

    # Register usage:
    # x10 = a0, also used as SRAM base / final exit code.
    # x11 = UART base.
    # x12 = loop index / offset.
    # x13 = loop limit / constant.
    # x14 = temp data / expected.
    # x15 = loaded value.
    p.li(10, SRAM_BASE)
    p.li(11, UART_BASE)

    # ---------- Full 8KB word fill and verify ----------
    p.li(13, WORDS)
    p.emit(addi(12, 0, 0))
    p.label('wf_loop')
    p.emit(slli(14, 12, 16))
    p.emit(or_r(14, 12, 14))
    p.emit(sw(14, 0, 10))
    p.emit(addi(10, 10, 4))
    p.emit(addi(12, 12, 1))
    p.blt(12, 13, 'wf_loop')

    p.li(10, SRAM_BASE)
    p.emit(addi(12, 0, 0))
    p.label('wr_loop')
    p.emit(lw(15, 0, 10))
    p.emit(slli(14, 12, 16))
    p.emit(or_r(14, 12, 14))
    p.bne(15, 14, 'fail')
    p.emit(addi(10, 10, 4))
    p.emit(addi(12, 12, 1))
    p.blt(12, 13, 'wr_loop')

    # ---------- Byte lane / wstrb test ----------
    p.li(10, SRAM_BASE)
    p.emit(addi(14, 0, 0x01)); p.emit(sb(14, 0, 10))
    p.emit(addi(14, 0, 0x12)); p.emit(sb(14, 1, 10))
    p.emit(addi(14, 0, 0x23)); p.emit(sb(14, 2, 10))
    p.emit(addi(14, 0, 0x34)); p.emit(sb(14, 3, 10))
    p.emit(lw(15, 0, 10))
    p.li(14, 0x34231201)
    p.bne(15, 14, 'fail')
    # Overwrite one byte; neighbors must stay intact.
    p.emit(addi(14, 0, 0xAB)); p.emit(sb(14, 1, 10))
    p.emit(lw(15, 0, 10))
    p.li(14, 0x3423AB01)
    p.bne(15, 14, 'fail')

    # ---------- Halfword / wstrb test ----------
    p.li(10, SRAM_BASE)
    p.li(14, 0xABCD); p.emit(sh(14, 0, 10))
    p.li(14, 0xEF01); p.emit(sh(14, 2, 10))
    p.emit(lw(15, 0, 10))
    p.li(14, 0xEF01ABCD)
    p.bne(15, 14, 'fail')
    p.emit(lhu(15, 0, 10))
    p.li(14, 0xABCD)
    p.bne(15, 14, 'fail')
    p.emit(lhu(15, 2, 10))
    p.li(14, 0xEF01)
    p.bne(15, 14, 'fail')
    # Overwrite upper half; lower half stays intact.
    p.li(14, 0x5566); p.emit(sh(14, 2, 10))
    p.emit(lw(15, 0, 10))
    p.li(14, 0x5566ABCD)
    p.bne(15, 14, 'fail')

    # ---------- Sign-extension sanity checks ----------
    p.li(10, SRAM_BASE)
    p.emit(lb(15, 2, 10))   # byte 0x66 -> sign-extended 0x00000066
    p.emit(addi(14, 0, 0x66))
    p.bne(15, 14, 'fail')
    p.emit(lbu(15, 3, 10))  # byte 0x55 -> zero-extended 0x00000055
    p.emit(addi(14, 0, 0x55))
    p.bne(15, 14, 'fail')

    # ---------- PASS ----------
    p.jal(0, 'pass')

    # ---------- FAIL ----------
    p.label('fail')
    p.emit(addi(10, 0, 1))   # a0 = 1
    emit_print(p, 11, 'F')
    emit_print(p, 11, 'A')
    emit_print(p, 11, 'I')
    emit_print(p, 11, 'L')
    emit_print(p, 11, '\n')
    p.emit(EBREAK)

    p.label('pass')
    p.emit(addi(10, 0, 0))   # a0 = 0
    emit_print(p, 11, 'P')
    emit_print(p, 11, 'A')
    emit_print(p, 11, 'S')
    emit_print(p, 11, 'S')
    emit_print(p, 11, '\n')
    p.emit(EBREAK)

    return p.encode()


def main():
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} OUT", file=sys.stderr)
        return 1
    out_path = sys.argv[1]
    insts = build_program()
    with open(out_path, 'wb') as f:
        for inst in insts:
            f.write(struct.pack('<I', inst))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
