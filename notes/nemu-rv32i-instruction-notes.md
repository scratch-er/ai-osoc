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
| `lui` | U | opcode `0110111` | `rd = imm_u`. |
| `auipc` | U | opcode `0010111` | `rd = pc + imm_u`. |
| `addi` | I | opcode `0010011`, funct3 `000` | `rd = rs1 + sext(imm12)`; low XLEN bits, overflow ignored. |
| `slti` | I | opcode `0010011`, funct3 `010` | `rd = (signed(rs1) < signed(sext(imm12))) ? 1 : 0`. |
| `sltiu` | I | opcode `0010011`, funct3 `011` | `rd = (rs1 < sext(imm12) as unsigned) ? 1 : 0`; used by `seqz rd, rs` with imm `1`. |
| `xori` | I | opcode `0010011`, funct3 `100` | `rd = rs1 ^ sext(imm12)`. |
| `ori` | I | opcode `0010011`, funct3 `110` | `rd = rs1 | sext(imm12)`. |
| `andi` | I | opcode `0010011`, funct3 `111` | `rd = rs1 & sext(imm12)`. |
| `slli` | I | opcode `0010011`, funct3 `001`, funct7 `0000000` | `rd = rs1 << shamt[4:0]`. |
| `srli` | I | opcode `0010011`, funct3 `101`, funct7 `0000000` | `rd = rs1 >> shamt[4:0]` logically. |
| `srai` | I | opcode `0010011`, funct3 `101`, funct7 `0100000` | `rd = signed(rs1) >> shamt[4:0]`. |
| `lb` | I | opcode `0000011`, funct3 `000` | `rd = sign_extend(mem8[rs1 + sext(imm12)])`. |
| `lh` | I | opcode `0000011`, funct3 `001` | `rd = sign_extend(mem16[rs1 + sext(imm12)])`. |
| `lw` | I | opcode `0000011`, funct3 `010` | `rd = mem32[rs1 + sext(imm12)]`. |
| `lbu` | I | opcode `0000011`, funct3 `100` | `rd = zero_extend(mem8[rs1 + sext(imm12)])`. |
| `lhu` | I | opcode `0000011`, funct3 `101` | `rd = zero_extend(mem16[rs1 + sext(imm12)])`. |
| `sb` | S | opcode `0100011`, funct3 `000` | `mem8[rs1 + sext(simm12)] = rs2[7:0]`. |
| `sh` | S | opcode `0100011`, funct3 `001` | `mem16[rs1 + sext(simm12)] = rs2[15:0]`. |
| `sw` | S | opcode `0100011`, funct3 `010` | `mem32[rs1 + sext(simm12)] = rs2[31:0]`. |
| `add` | R | opcode `0110011`, funct3 `000`, funct7 `0000000` | `rd = rs1 + rs2`; low XLEN bits, overflow ignored. |
| `sub` | R | opcode `0110011`, funct3 `000`, funct7 `0100000` | `rd = rs1 - rs2`; low XLEN bits, overflow ignored. |
| `sll` | R | opcode `0110011`, funct3 `001`, funct7 `0000000` | `rd = rs1 << rs2[4:0]`. |
| `slt` | R | opcode `0110011`, funct3 `010`, funct7 `0000000` | `rd = (signed(rs1) < signed(rs2)) ? 1 : 0`. |
| `sltu` | R | opcode `0110011`, funct3 `011`, funct7 `0000000` | `rd = (rs1 < rs2 as unsigned) ? 1 : 0`. |
| `xor` | R | opcode `0110011`, funct3 `100`, funct7 `0000000` | `rd = rs1 ^ rs2`. |
| `srl` | R | opcode `0110011`, funct3 `101`, funct7 `0000000` | `rd = rs1 >> rs2[4:0]` logically. |
| `sra` | R | opcode `0110011`, funct3 `101`, funct7 `0100000` | `rd = signed(rs1) >> rs2[4:0]`. |
| `or` | R | opcode `0110011`, funct3 `110`, funct7 `0000000` | `rd = rs1 | rs2`. |
| `and` | R | opcode `0110011`, funct3 `111`, funct7 `0000000` | `rd = rs1 & rs2`. |
| `beq` | B | opcode `1100011`, funct3 `000` | if `rs1 == rs2`, `dnpc = pc + bimm`; otherwise fall through. |
| `bne` | B | opcode `1100011`, funct3 `001` | if `rs1 != rs2`, `dnpc = pc + bimm`; otherwise fall through. |
| `blt` | B | opcode `1100011`, funct3 `100` | if `signed(rs1) < signed(rs2)`, `dnpc = pc + bimm`. |
| `bge` | B | opcode `1100011`, funct3 `101` | if `signed(rs1) >= signed(rs2)`, `dnpc = pc + bimm`. |
| `bltu` | B | opcode `1100011`, funct3 `110` | if `rs1 < rs2` unsigned, `dnpc = pc + bimm`. |
| `bgeu` | B | opcode `1100011`, funct3 `111` | if `rs1 >= rs2` unsigned, `dnpc = pc + bimm`. |
| `jal` | J | opcode `1101111` | `rd = pc + 4`; `dnpc = pc + jimm`. |
| `jalr` | I | opcode `1100111`, funct3 `000` | `rd = pc + 4`; `dnpc = (rs1 + sext(imm12)) & ~1`. |
| `ebreak` | N | exact `00100000000100000000000001110011` | terminate NEMU via `NEMUTRAP(pc, a0)`. |

## Passing tests using this slice

Validated command pattern from repository root:

```sh
make -C nemu -j$(sysctl -n hw.ncpu)
source ./activate
cd am-kernels/tests/cpu-tests
for t in dummy add add-longlong bit bubble-sort crc32 fib if-else load-store max min3 mov-c movsx pascal quick-sort select-sort shift sub-longlong sum switch to-lower-case unalign; do
  printf 'NAME = %s\nSRCS = tests/%s.c\ninclude %s/Makefile\n' "$t" "$t" "$AM_HOME" > Makefile.$t
  make -f Makefile.$t ARCH=riscv32-nemu CROSS_COMPILE=riscv64-elf- run
  status=$?
  rm -f Makefile.$t
  [ $status -eq 0 ] || exit $status
done
```

Passing tests:

- Final P1-S3 regression slice passes: `dummy`, `add`, `add-longlong`, `bit`, `bubble-sort`, `crc32`, `fib`, `if-else`, `load-store`, `max`, `min3`, `mov-c`, `movsx`, `pascal`, `quick-sort`, `select-sort`, `shift`, `sub-longlong`, `sum`, `switch`, `to-lower-case`, `unalign`.
- Key instruction additions found by failing tests:
  - `load-store`: first needed `lh` at `0x80000068` (`00041503`), then `lhu`.
  - `movsx`: first needed `lb` at `0x80000090` (`00048503`).
  - `if-else`: first needed `blt` at `0x80000074` (`02e94263`) and `slti` at `0x80000078`.
  - `max`: first needed `bge` at `0x80000084` (`01255463`).
  - `sum`: first needed `lui` at `0x80000054` (`fffff7b7`).
- A broad cpu-test survey after the RV32I slice passed 22 tests and left failures in two categories:
  - M-extension opcodes from `-march=rv32im_zicsr`: `div`, `fact`, `goldbach`, `leap-year`, `matrix-mul`, `mersenne`, `mul-longlong`, `narcissistic`, `prime`, `recursion`, `wanshu`.
  - Device/MMIO dependency with devices disabled: `hello-str`, `string` fail on out-of-bound `0xa00003f8` serial MMIO.

## Current next target

- Phase 1 Session 3 is complete enough for the current objective: representative RV32I cpu-tests pass, and remaining failures are narrow M-extension/device blockers.
- Continue with Phase 1 Session 4: improve batch mode and concise result reporting, including a cycle/instruction limit and machine-readable pass/fail output.
