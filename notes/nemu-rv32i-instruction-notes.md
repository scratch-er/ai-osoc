# NEMU RV32I Instruction Notes

This note tracks the small RV32I instruction slices implemented in NEMU during Phase 1. It is a working reference for `nemu/src/isa/riscv32/inst.c`, not a complete ISA manual.

References:

- `specs/riscv-isa-manual/src/unpriv/rv32.adoc`
  - immediate formats: lines 163-203
  - integer register-immediate operations: lines 266-287
  - integer register-register operations: lines 334-355
  - unconditional jumps: lines 398-442
  - conditional branches: lines 528-546
  - loads/stores: lines 640-699
- `specs/riscv-isa-manual/src/unpriv/rv32e.adoc`: RV32E uses the same encodings as RV32I, but only x0-x15 are available.

## Immediate formats currently decoded

- I-type: `imm[11:0] = inst[31:20]`, sign-extended.
- U-type: `imm[31:12] = inst[31:12]`, low 12 bits zero.
- S-type: `imm[11:5] = inst[31:25]`, `imm[4:0] = inst[11:7]`, sign-extended.
- B-type: branch byte offset with `imm[12]=inst[31]`, `imm[11]=inst[7]`, `imm[10:5]=inst[30:25]`, `imm[4:1]=inst[11:8]`, `imm[0]=0`, sign-extended.
- J-type: jump byte offset with `imm[20]=inst[31]`, `imm[19:12]=inst[19:12]`, `imm[11]=inst[20]`, `imm[10:1]=inst[30:21]`, `imm[0]=0`, sign-extended.
- R-type: source registers `rs1` and `rs2`, destination `rd`, no immediate.

## Implemented instruction slice

| Instruction | Format | Match fields | Behavior |
| --- | --- | --- | --- |
| `addi` | I | opcode `0010011`, funct3 `000` | `rd = rs1 + sext(imm12)`; low XLEN bits, overflow ignored. |
| `sltiu` | I | opcode `0010011`, funct3 `011` | `rd = (rs1 < sext(imm12) as unsigned) ? 1 : 0`; used by `seqz rd, rs` with imm `1`. |
| `xori` | I | opcode `0010011`, funct3 `100` | `rd = rs1 ^ sext(imm12)`. |
| `andi` | I | opcode `0010011`, funct3 `111` | `rd = rs1 & sext(imm12)`. |
| `slli` | I | opcode `0010011`, funct3 `001`, funct7 `0000000` | `rd = rs1 << shamt[4:0]`. |
| `srli` | I | opcode `0010011`, funct3 `101`, funct7 `0000000` | `rd = rs1 >> shamt[4:0]` logically. |
| `srai` | I | opcode `0010011`, funct3 `101`, funct7 `0100000` | `rd = signed(rs1) >> shamt[4:0]`. |
| `auipc` | U | opcode `0010111` | `rd = pc + imm_u`. |
| `lw` | I | opcode `0000011`, funct3 `010` | `rd = mem32[rs1 + sext(imm12)]`. |
| `lbu` | I | opcode `0000011`, funct3 `100` | `rd = zero_extend(mem8[rs1 + sext(imm12)])`. |
| `sb` | S | opcode `0100011`, funct3 `000` | `mem8[rs1 + sext(simm12)] = rs2[7:0]`. |
| `sh` | S | opcode `0100011`, funct3 `001` | `mem16[rs1 + sext(simm12)] = rs2[15:0]`. |
| `sw` | S | opcode `0100011`, funct3 `010` | `mem32[rs1 + sext(simm12)] = rs2[31:0]`. |
| `add` | R | opcode `0110011`, funct3 `000`, funct7 `0000000` | `rd = rs1 + rs2`; low XLEN bits, overflow ignored. |
| `sub` | R | opcode `0110011`, funct3 `000`, funct7 `0100000` | `rd = rs1 - rs2`; low XLEN bits, overflow ignored. |
| `sll` | R | opcode `0110011`, funct3 `001`, funct7 `0000000` | `rd = rs1 << rs2[4:0]`. |
| `srl` | R | opcode `0110011`, funct3 `101`, funct7 `0000000` | `rd = rs1 >> rs2[4:0]` logically. |
| `sra` | R | opcode `0110011`, funct3 `101`, funct7 `0100000` | `rd = signed(rs1) >> rs2[4:0]`. |
| `sltu` | R | opcode `0110011`, funct3 `011`, funct7 `0000000` | `rd = (rs1 < rs2 as unsigned) ? 1 : 0`. |
| `xor` | R | opcode `0110011`, funct3 `100`, funct7 `0000000` | `rd = rs1 ^ rs2`. |
| `or` | R | opcode `0110011`, funct3 `110`, funct7 `0000000` | `rd = rs1 | rs2`. |
| `and` | R | opcode `0110011`, funct3 `111`, funct7 `0000000` | `rd = rs1 & rs2`. |
| `beq` | B | opcode `1100011`, funct3 `000` | if `rs1 == rs2`, `dnpc = pc + bimm`; otherwise fall through. |
| `bne` | B | opcode `1100011`, funct3 `001` | if `rs1 != rs2`, `dnpc = pc + bimm`; otherwise fall through. |
| `jal` | J | opcode `1101111` | `rd = pc + 4`; `dnpc = pc + jimm`. |
| `jalr` | I | opcode `1100111`, funct3 `000` | `rd = pc + 4`; `dnpc = (rs1 + sext(imm12)) & ~1`. |
| `ebreak` | N | exact `00100000000100000000000001110011` | terminate NEMU via `NEMUTRAP(pc, a0)`. |

## Passing tests using this slice

Validated command pattern from repository root:

```sh
make -C nemu -j$(sysctl -n hw.ncpu)
source ./activate
cd am-kernels/tests/cpu-tests
for t in add add-longlong bit shift; do
  printf 'NAME = %s\nSRCS = tests/%s.c\ninclude %s/Makefile\n' "$t" "$t" "$AM_HOME" > Makefile.$t
  make -f Makefile.$t ARCH=riscv32-nemu CROSS_COMPILE=riscv64-elf- run
  status=$?
  rm -f Makefile.$t
  [ $status -eq 0 ] || exit $status
done
```

Passing tests:

- `dummy`: passed in Phase 1 Session 2.
- `add`: passed after adding B/R-type decode plus `lw/add/sub/sltiu/beq/bne`.
- `add-longlong`: passed after adding `sltu/xor/or`.
- `bit`: passed after adding `xori/andi/slli/srai/sh/sll/and`.
- `shift`: passed after adding `srli/srl/sra`.

## Current next target

- Continue Phase 1 Session 3 with the next small CPU test, likely `load-store` or `mov-c`.
- Add further instructions only when a concrete CPU test fails and the disassembly identifies the missing opcode.
