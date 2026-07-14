# NPC RV32E_Zicsr ISA and Datapath Plan

This note records the approved pre-RTL design plan for the initial NPC processor core. It is based on `specs/core.md`, `specs/riscv-isa-manual/src/unpriv/{rv32.adoc,rv32e.adoc,zicsr.adoc,zifencei.adoc}`, and `specs/riscv-isa-manual/src/priv/machine.adoc`.

## Target ISA and architectural limits

- Implement `RV32E_Zicsr` only.
- XLEN is 32.
- GPR file has `x0..x15`; `x0` is hardwired zero.
- Any instruction encoding that names `x16..x31` in `rd`, `rs1`, or `rs2` is reserved for RV32E and should be handled as illegal instruction in this core.
- M-mode only.
- No interrupts, no virtual memory, no PMP/PMA.
- `fence` is a nop.
- `fence.i` clears the instruction cache once the icache exists; before icache implementation it can be wired as a distinct architectural hook that otherwise advances PC.
- `wfi` is a nop.
- Reset PC default is `0x20000000`.

## Instruction list, encodings, and behavior

Common bit fields:

- `opcode = inst[6:0]`
- `rd = inst[11:7]`
- `funct3 = inst[14:12]`
- `rs1 = inst[19:15]`
- `rs2 = inst[24:20]`
- `funct7 = inst[31:25]`
- All immediates sign-extend from `inst[31]` except CSR immediate `uimm`.
- Normal next PC is `pc + 4` unless a branch/jump/trap changes it.

### U-type

| Instruction | Encoding | Behavior |
|---|---|---|
| `lui` | opcode `0110111`; U imm `inst[31:12] << 12` | `rd = imm_u` |
| `auipc` | opcode `0010111`; U imm `inst[31:12] << 12` | `rd = pc + imm_u` |

### J-type

| Instruction | Encoding | Behavior |
|---|---|---|
| `jal` | opcode `1101111`; J imm `{inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}` | `rd = pc + 4`; target `pc + sext(imm_j)`; raise instruction-address-misaligned if target is not 4-byte aligned |

### I-type jumps

| Instruction | Encoding | Behavior |
|---|---|---|
| `jalr` | opcode `1100111`, funct3 `000` | `rd = pc + 4`; target `(rs1 + sext(imm_i)) & ~1`; raise instruction-address-misaligned if target is not 4-byte aligned |

### B-type branches

Opcode `1100011`; B imm `{inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}`. If the condition is true, target is `pc + sext(imm_b)` and must be 4-byte aligned.

| Instruction | funct3 | Branch condition |
|---|---:|---|
| `beq` | `000` | `rs1 == rs2` |
| `bne` | `001` | `rs1 != rs2` |
| `blt` | `100` | signed `rs1 < rs2` |
| `bge` | `101` | signed `rs1 >= rs2` |
| `bltu` | `110` | unsigned `rs1 < rs2` |
| `bgeu` | `111` | unsigned `rs1 >= rs2` |

### Loads

Opcode `0000011`; effective address `rs1 + sext(imm_i)`. Loads to `x0` still perform the memory access and can still raise exceptions.

| Instruction | funct3 | Access | Behavior |
|---|---:|---|---|
| `lb` | `000` | 1 byte | sign-extend loaded byte |
| `lh` | `001` | 2 bytes | require 2-byte alignment; sign-extend halfword |
| `lw` | `010` | 4 bytes | require 4-byte alignment; load word |
| `lbu` | `100` | 1 byte | zero-extend loaded byte |
| `lhu` | `101` | 2 bytes | require 2-byte alignment; zero-extend halfword |

Misaligned loads raise load-address-misaligned. AXI `SLVERR`/`DECERR` or simulation memory access failure raises load-access-fault.

### Stores

Opcode `0100011`; effective address `rs1 + sext(imm_s)`, where `imm_s = {inst[31:25], inst[11:7]}`.

| Instruction | funct3 | Access | Behavior |
|---|---:|---|---|
| `sb` | `000` | 1 byte | store `rs2[7:0]` |
| `sh` | `001` | 2 bytes | require 2-byte alignment; store `rs2[15:0]` |
| `sw` | `010` | 4 bytes | require 4-byte alignment; store `rs2[31:0]` |

Misaligned stores raise store/AMO-address-misaligned. AXI `SLVERR`/`DECERR` or simulation memory access failure raises store/AMO-access-fault.

### I-type ALU

Opcode `0010011`; immediate is sign-extended 12-bit I immediate, except shift amount uses `inst[24:20]`.

| Instruction | funct3 | extra bits | Behavior |
|---|---:|---|---|
| `addi` | `000` | none | `rd = rs1 + sext(imm_i)`; overflow ignored |
| `slti` | `010` | none | `rd = signed(rs1) < signed(sext(imm_i)) ? 1 : 0` |
| `sltiu` | `011` | none | `rd = unsigned(rs1) < unsigned(sext(imm_i)) ? 1 : 0` |
| `xori` | `100` | none | `rd = rs1 ^ sext(imm_i)` |
| `ori` | `110` | none | `rd = rs1 | sext(imm_i)` |
| `andi` | `111` | none | `rd = rs1 & sext(imm_i)` |
| `slli` | `001` | `funct7=0000000` | `rd = rs1 << shamt` |
| `srli` | `101` | `funct7=0000000` | logical right shift |
| `srai` | `101` | `funct7=0100000` | arithmetic right shift |

For RV32, `shamt` is 5 bits. Other shift encodings are illegal.

### R-type ALU

Opcode `0110011`; all operations read `rs1` and `rs2` and write `rd`.

| Instruction | funct7 | funct3 | Behavior |
|---|---:|---:|---|
| `add` | `0000000` | `000` | `rd = rs1 + rs2`; overflow ignored |
| `sub` | `0100000` | `000` | `rd = rs1 - rs2`; overflow ignored |
| `sll` | `0000000` | `001` | `rd = rs1 << rs2[4:0]` |
| `slt` | `0000000` | `010` | signed less-than |
| `sltu` | `0000000` | `011` | unsigned less-than |
| `xor` | `0000000` | `100` | bitwise xor |
| `srl` | `0000000` | `101` | logical right shift by `rs2[4:0]` |
| `sra` | `0100000` | `101` | arithmetic right shift by `rs2[4:0]` |
| `or` | `0000000` | `110` | bitwise or |
| `and` | `0000000` | `111` | bitwise and |

Other R-type encodings, including M-extension encodings, are illegal.

### Memory ordering

| Instruction | Encoding | Behavior |
|---|---|---|
| `fence` / `fence.tso` | opcode `0001111`, funct3 `000`; `rd`/`rs1` ignored for forward compatibility | implemented as nop because the spec says memory access is in-order |
| `fence.i` | opcode `0001111`, funct3 `001`; unused fields ignored for forward compatibility | clear icache when present; otherwise nop-like architectural hook |

### System, privileged, and Zicsr

Opcode `1110011`.

| Instruction | Encoding | Behavior |
|---|---|---|
| `ecall` | funct3 `000`, `rd=0`, `rs1=0`, funct12 `000000000000` | raise environment-call-from-M-mode exception; `mepc = pc`; `mcause = 11`; next PC from `mtvec` |
| `ebreak` | funct3 `000`, `rd=0`, `rs1=0`, funct12 `000000000001` | raise breakpoint exception; `mepc = pc`; `mcause = 3`; for early simulation harness, may also be recognized as the program termination mechanism before full trap path is enabled |
| `mret` | funct3 `000`, funct12 `001100000010` | `pc = mepc`; MPP is hardwired M-mode so no real privilege-stack update is needed |
| `wfi` | funct3 `000`, funct12 `000100000101` | nop |
| `csrrw` | funct3 `001` | if `rd != x0`, read old CSR to `rd`; write CSR with `rs1` value |
| `csrrs` | funct3 `010` | read old CSR to `rd`; if `rs1 != x0`, write `old | rs1` |
| `csrrc` | funct3 `011` | read old CSR to `rd`; if `rs1 != x0`, write `old & ~rs1` |
| `csrrwi` | funct3 `101` | if `rd != x0`, read old CSR to `rd`; write CSR with zero-extended `uimm` |
| `csrrsi` | funct3 `110` | read old CSR to `rd`; if `uimm != 0`, write `old | uimm` |
| `csrrci` | funct3 `111` | read old CSR to `rd`; if `uimm != 0`, write `old & ~uimm` |

Implemented CSRs:

| CSR | Address | Behavior |
|---|---:|---|
| `mvendorid` | `0xf11` | read-only 0 |
| `marchid` | `0xf12` | read-only 0 |
| `mstatus` | `0x300` | MPP reads as M-mode; all other bits read 0; writes ignored or masked to this value |
| `mtvec` | `0x305` | hold 32-bit 4-byte-aligned trap vector; mask low 2 bits to 0 |
| `mepc` | `0x341` | hold 32-bit 4-byte-aligned exception PC; mask low 2 bits to 0 |
| `mcause` | `0x342` | hold supported synchronous exception cause code |

All other CSR addresses raise illegal-instruction exception. Writes to read-only `mvendorid`/`marchid` should raise illegal-instruction exception when the CSR instruction actually writes that CSR according to Zicsr read/write rules.

Supported synchronous exception cause codes from the spec:

| Cause | Code |
|---|---:|
| Instruction address misaligned | 0 |
| Instruction access fault | 1 |
| Illegal instruction | 2 |
| Breakpoint | 3 |
| Load address misaligned | 4 |
| Load access fault | 5 |
| Store/AMO address misaligned | 6 |
| Store/AMO access fault | 7 |
| Environment call from M-mode | 11 |

## Implementation-session decision

Do not implement all instructions in the first RTL session. The safer split is:

1. Build `npc/` skeleton and Verilator harness first.
2. Implement the minimal single-cycle datapath with `addi`.
3. Add `jalr` and `ebreak` termination.
4. Add DPI-C data memory and a small `lw`/`sw` subset.
5. Add debug trace and DiffTest scaffolding.
6. Then expand to full RV32E integer instructions and Zicsr/traps.

Reasoning:

- Full RV32E_Zicsr is not large, but bringing up RTL, memory loading, simulation control, and result reporting at the same time as every instruction would make failures ambiguous.
- The architecture should still be designed now for the full instruction set, so the early subsets are temporary coverage limits, not different architecture.
- Keep the module and directory layout final enough that adding instructions later is mostly table/control expansion, not a refactor.

## Recommended `npc/` directory layout

Use a Verilog-based NPC project:

```text
npc/
  Makefile
  README.md
  rtl/
    NPC.v
    core/
      Core.v
      Ifu.v
      Idu.v
      RegFile.v
      Exu.v
      Lsu.v
      Csr.v
      Wbu.v
    bus/
      MemIf.v
    include/
      npc_defines.vh
  csrc/
    main.cpp
    memory.cpp/.h
    dpi.cpp/.h
  tests/
    hex/ or asm/
  scripts/
    run-test.py
```

During the first few sessions, `NPC.v` can expose a small simulation boundary and call DPI-C memory functions. Internally, IFU/LSU should already talk through a simple request/response abstraction so Phase 5 can replace the backend with AXI without rewriting decode/execute.

## Decode design

`Idu.v` should decode in two layers:

1. Extract raw fields and immediates:
   - `imm_i = sext(inst[31:20])`
   - `imm_s = sext({inst[31:25], inst[11:7]})`
   - `imm_b = sext({inst[31], inst[7], inst[30:25], inst[11:8], 1'b0})`
   - `imm_u = {inst[31:12], 12'b0}`
   - `imm_j = sext({inst[31], inst[19:12], inst[20], inst[30:21], 1'b0})`
   - `csr_addr = inst[31:20]`
   - `csr_uimm = {27'b0, inst[19:15]}`
2. Generate compact control signals:
   - `illegal`
   - `src1_sel`: reg / pc / zero
   - `src2_sel`: reg / immediate / 4
   - `imm_sel`
   - `alu_op`
   - `cmp_op` or branch condition code
   - `branch_en`, `jump_en`, `jalr_en`
   - `reg_wen`, `wb_sel`: ALU / load / pc+4 / CSR
   - `mem_valid`, `mem_we`, `mem_size`, `mem_unsigned`
   - `csr_cmd`: none / rw / rs / rc / rwi / rsi / rci
   - `sys_cmd`: none / ecall / ebreak / mret / wfi / fence / fence_i

Illegal decode conditions should include:

- Unknown opcode/funct combination.
- Any referenced RV32E register field above 15 for an instruction that uses that field.
- Bad shift-immediate `funct7`.
- Unsupported CSR address.
- Writes to read-only CSRs when Zicsr rules say the instruction writes.
- Unsupported privileged/system encodings.

Use simple `casez` or nested `case` statements rather than a complicated generated decoder. The instruction set is small and explicit decode is easiest to debug.

## Datapath design

Start single-cycle architecturally, but use valid/ready-like boundaries where they matter so multi-cycle memory/AXI can be introduced later.

### Fetch / PC

- `pc` register resets to `RESET_PC` parameter, default `32'h2000_0000`.
- IFU fetches a 32-bit instruction at `pc`.
- If `pc[1:0] != 0`, raise instruction-address-misaligned before/at fetch.
- Fetch access failure from the memory backend becomes instruction-access-fault.
- Default `next_pc = pc + 4`.
- Branch/jump/trap/mret override `next_pc` with priority:
  1. synchronous exception/trap entry to `mtvec`
  2. `mret` to `mepc`
  3. taken branch / `jal` / `jalr`
  4. sequential `pc + 4`

### Register file

- 16 physical 32-bit registers.
- Read `x0` as zero.
- Ignore writes to `x0`.
- Decode should prevent access to `x16..x31`; if it reaches RegFile anyway, treat as zero defensively but raise illegal earlier.
- Writeback occurs only if instruction completes without exception.

### Execute

- One ALU handles add/sub/logic/shifts/compare input preparation.
- Branch compare can be in EXU using signed/unsigned comparators.
- Use `pc + imm` adder for `auipc`, `jal`, and branches; initially this can share the ALU if single-cycle timing is acceptable.
- `jalr` target clears bit 0, then alignment check requires bits `[1:0] == 0` after clearing bit 0.

### Load/store

- Address = `rs1 + sext(offset)`.
- Alignment rules:
  - byte: always aligned
  - halfword: `addr[0] == 0`
  - word: `addr[1:0] == 0`
- Generate byte write strobe for stores.
- Load data is selected from returned word according to address low bits, then sign/zero-extended.
- Early DPI memory can accept byte strobes; later AXI path maps these to `WSTRB`.
- Verilator assumes combinational reads/writes have no side effects and may simulate them in any order, including DPI-C functions. Do not implement UART, CLINT, memory-mapped devices, or fault/status updates as side effects of combinational DPI-C reads/writes; use explicit ordered/clocked operations or a harness protocol for side-effectful behavior.
- Do not add a data cache.

### CSR and traps

- `Csr.v` owns `mvendorid`, `marchid`, `mstatus`, `mtvec`, `mepc`, `mcause`.
- Trap entry:
  - `mepc = faulting pc`.
  - `mcause = cause code`.
  - `pc = mtvec`.
  - Do not write GPR/memory side effects for the faulting instruction.
- `ecall` and `ebreak` set `mepc` to the address of the instruction itself.
- `mret` sets `pc = mepc`.
- `mstatus` can be implemented as read constant with MPP set to M-mode and all other bits zero; writes are masked/ignored to preserve that behavior.

### Icache hook

Do not implement icache in the first RTL session, but reserve the hook:

- `fence_i` decode signal from IDU.
- IFU input `flush_i` or `icache_clear`.
- Early IFU ignores it or invalidates no state.
- Phase 7 replaces IFU internals with the required 8-instruction direct-mapped flip-flop icache without changing decode.

### Retire/debug interface

From the first harness session, expose enough retire metadata for tests and DiffTest:

- `retire_valid`
- `retire_pc`
- `retire_inst`
- `retire_trap` / `retire_exception_cause`
- `retire_reg_wen`, `retire_rd`, `retire_wdata`
- optional memory access summary

Early `ebreak` can terminate the simulator through DPI-C. Once trap handling is implemented, keep a harness mode that treats `ebreak` as test termination only for bare tiny tests, or let AM `halt()` convention continue to use it in a controlled way.

## First implementation slice

The current session starts `P2-S1: NPC project skeleton and Verilator harness` only:

1. Create `npc/` with Verilog RTL, C++ simulator, Makefile/scripts, and tiny tests.
2. Support image loading at a configurable base address.
3. Add cycle/instruction limit, optional waveform switch, and `NPC_RESULT status=...` output.
4. Keep reset PC configurable, defaulting to `0x20000000` per `specs/core.md`.
5. Exit when the simulator builds and a reset/empty-run smoke test is deterministic.

Do not broaden into real instruction execution before this harness is stable.
