# Next Session

Current state:

- Phase 1 Session 1 (`P1-S1: Baseline NEMU bring-up and command inventory`) is complete.
- Phase 1 Session 2 (`P1-S2: Minimal execution path for AM dummy`) is complete.
- Phase 1 Session 3 (`P1-S3: CPU-test instruction coverage slice`) is complete: the representative RV32I cpu-test slice passes and remaining failures are M-extension/device blockers.
- Phase 1 Session 4 (`P1-S4: Batch mode and concise result reporting`) is complete.
- `npc/` is absent; no NPC work has started.
- Repository status before Phase 1 work already had modified `notes/plan.md` and `notes/next.md`, plus untracked `.DS_Store` and `activate`.

Submodules reported earlier by `git submodule status`:

- `am-kernels` at `76c80f8b5b4fdeeabe1b7caa167953cd64c16545` (`heads/master`)
- `specs/riscv-isa-manual` at `79b241cb6d2f07167366747ae49df94b88ad4d3b` (`riscv-isa-release-79b241c-2026-07-10`)
- `ysyxSoC` at `df38a4d93d1d71e621fe91b106d088bd33af984a` (`heads/ysyx6`)

NEMU/AM current configuration:

- Native NEMU build uses local ignored `nemu/.config` with key settings:
  - `CONFIG_ISA="riscv32"`
  - `CONFIG_TARGET_NATIVE_ELF=y`
  - `# CONFIG_TARGET_AM is not set`
  - `# CONFIG_DEVICE is not set`
  - `# CONFIG_TRACE is not set`
  - `CONFIG_MBASE=0x80000000`
  - `CONFIG_MSIZE=0x2000000`
- Devices remain disabled because native device build on this macOS environment failed on missing `SDL2/SDL.h`.
- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- The installed `riscv64-elf-gcc` is configured `--without-headers`, so local freestanding AM headers were added:
  - `abstract-machine/am/include/stdint.h`
  - `abstract-machine/am/include/stddef.h`
  - `abstract-machine/am/include/stdbool.h`

Changes made in Phase 1 Session 2:

- `nemu/src/monitor/monitor.c`
  - Removed the intentional PA skeleton `assert(0)` and exercise log from `welcome()`.
- `nemu/src/isa/riscv32/inst.c`
  - Added immediate decode for J-type.
  - Implemented the minimal RV32I instructions needed by AM `dummy`:
    - `addi`
    - `sw`
    - `jal`
    - `jalr`
  - Existing implemented instructions at that point were only a tiny skeleton: `auipc`, `lbu`, `sb`, `ebreak`, plus invalid instruction handling.
- `abstract-machine/Makefile`
  - Fixed library linkage expansion so AM and klib archives are linked into test images.
  - `define LIB_TEMPLATE =` was invalid for the intended multi-line macro; changed to `define LIB_TEMPLATE`.
  - `LINKAGE` was changed to immediate assignment so generated archive dependencies are preserved correctly.
- `abstract-machine/scripts/platform/nemu.mk`
  - Added `-b` to `NEMUFLAGS` so AM `run` invokes NEMU in batch mode.
  - Changed `python` to `python3` for `insert-arg.py` on this macOS environment.

Changes made in Phase 1 Session 3:

- `nemu/src/isa/riscv32/inst.c`
  - Added operand decode for B-type and R-type.
  - Added B-type immediate decode.
  - Added RV32I instructions needed by the cpu-test slice:
    - U-type: `lui`, `auipc`
    - I-type/immediate: `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`
    - loads/stores: `lb`, `lh`, `lw`, `lbu`, `lhu`, `sb`, `sh`, `sw`
    - R-type: `add`, `sub`, `sll`, `slt`, `srl`, `sra`, `sltu`, `xor`, `or`, `and`
    - branches: `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`
- Added `notes/nemu-rv32i-instruction-notes.md` with instruction encodings, behavior, RISC-V manual references, passing-test command pattern, and next target.

Changes made in Phase 1 Session 4:

- `nemu/include/utils.h`
  - Added `NEMU_LIMIT` state.
  - Declared global `nemu_inst_limit`.
- `nemu/src/utils/state.c`
  - Defined `nemu_inst_limit`, defaulting to `0` for unlimited execution.
- `nemu/src/monitor/monitor.c`
  - Added CLI option `-m N` / `--max-insts=N`.
  - Help text documents that `0` means unlimited.
- `nemu/src/cpu/cpu-exec.c`
  - Checks `nemu_inst_limit` before each guest instruction and stops with `NEMU_LIMIT` when reached.
  - Prints a stable machine-readable result line after terminal outcomes:

    ```text
    NEMU_RESULT status=<good|bad|abort|quit|limit|stop|running> state=<n> halt_pc=<hex> halt_ret=<n> insts=<n> limit=<n>
    ```

  - Existing human-readable `HIT GOOD TRAP` / `HIT BAD TRAP` logs are preserved.
- `abstract-machine/scripts/platform/nemu.mk`
  - Added `NEMU_MAX_INSTS ?= 10000000`.
  - AM `run` now passes `--max-insts=$(NEMU_MAX_INSTS)` together with existing batch/log flags.

Validated commands and results:

1. Build native NEMU and run the built-in image with an explicit limit:

   ```sh
   cd nemu
   make -j$(sysctl -n hw.ncpu)
   ./build/riscv32-nemu-interpreter --batch --max-insts=100
   ```

   Result: passes with `HIT GOOD TRAP`; final structured line:

   ```text
   NEMU_RESULT status=good state=2 halt_pc=0x8000000c halt_ret=0 insts=4 limit=100
   ```

2. Verify instruction-limit failure path:

   ```sh
   cd nemu
   ./build/riscv32-nemu-interpreter --batch --max-insts=2
   ```

   Result: exits nonzero as expected; final structured line:

   ```text
   NEMU_RESULT status=limit state=5 halt_pc=0x80000008 halt_ret=1 insts=2 limit=2
   ```

3. Current cpu-test slice, checking `NEMU_RESULT status=good` for each test:

   ```sh
   source ./activate
   cd am-kernels/tests/cpu-tests
   for t in dummy add add-longlong bit bubble-sort crc32 fib if-else load-store max min3 mov-c movsx pascal quick-sort select-sort shift sub-longlong sum switch to-lower-case unalign; do
     printf 'NAME = %s\nSRCS = tests/%s.c\ninclude %s/Makefile\n' "$t" "$t" "$AM_HOME" > Makefile.$t
     out=$(make -f Makefile.$t ARCH=riscv32-nemu CROSS_COMPILE=riscv64-elf- run 2>&1)
     status=$?
     rm -f Makefile.$t
     printf '%s\n' "$out" | grep 'NEMU_RESULT status=good' >/dev/null || { printf '%s\n' "$out"; exit 1; }
     printf '%s PASS %s\n' "$t" "$(printf '%s\n' "$out" | grep 'NEMU_RESULT' | tail -1)"
     [ $status -eq 0 ] || exit $status
   done
   ```

   Result: all 22 listed tests pass with `NEMU_RESULT status=good` and AM default `limit=10000000`.

Known caveats:

- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS:

  ```sh
  source ./activate
  make -C am-kernels/tests/cpu-tests ARCH=riscv32-nemu CROSS_COMPILE=riscv64-elf- ALL=dummy run
  ```

  It reports `[dummy] ***FAIL***` because the wrapper uses `/bin/echo -e` to generate `Makefile.$test`; macOS `/bin/echo` writes the literal `-e`, producing an invalid makefile. Do not modify `am-kernels/` unless explicitly allowed; use the temporary `printf` command above for now, or fix the wrapper later if the user permits changing `am-kernels`.

- P1-S3 broad survey result after the RV32I slice:
  - Passing: `dummy`, `add`, `add-longlong`, `bit`, `bubble-sort`, `crc32`, `fib`, `if-else`, `load-store`, `max`, `min3`, `mov-c`, `movsx`, `pascal`, `quick-sort`, `select-sort`, `shift`, `sub-longlong`, `sum`, `switch`, `to-lower-case`, `unalign`.
  - Failing on M-extension opcodes from current `-march=rv32im_zicsr`: `div`, `fact`, `goldbach`, `leap-year`, `matrix-mul`, `mersenne`, `mul-longlong`, `narcissistic`, `prime`, `recursion`, `wanshu`.
  - Failing on disabled serial MMIO at `0xa00003f8`: `hello-str`, `string`.
- `abstract-machine/scripts/riscv32-nemu.mk` still defaults `CROSS_COMPILE := riscv64-linux-gnu-`; continue passing `CROSS_COMPILE=riscv64-elf-` unless the toolchain/default is changed.
- Devices are still disabled; serial/timer work should wait until the relevant Phase 1/AM workload sessions, or until SDL2/device strategy is decided.
- `--max-insts` counts global guest instructions since process start. That is fine for current one-image one-run invocations.

Next work:

1. Start Phase 1 Session 5 (`P1-S5: Essential tracing for failures`).
2. Add or verify bounded itrace/failing-window support so a failing test can print compact recent instruction context.
3. Add mtrace only behind a filter/config switch; keep normal regression output concise by default.
4. Consider ftrace optional only if ELF symbol plumbing is nearby; do not block P1-S5 on it.
5. Do not start M-extension implementation unless explicitly choosing to broaden `riscv32-nemu` beyond the RV32I-focused slice; the future target core remains RV32E_Zicsr.
6. Do not touch `am-kernels/` unless the user explicitly approves fixing its macOS wrapper.

Relevant files:

- `notes/plan.md`
- `notes/lecture-note-summary.md`
- `notes/nemu-rv32i-instruction-notes.md`
- `specs/core.md`
- `specs/riscv-isa-manual/src/unpriv/rv32.adoc`
- `specs/riscv-isa-manual/src/unpriv/rv32e.adoc`
- `nemu/.config` (generated/ignored local build config)
- `nemu/include/utils.h`
- `nemu/src/utils/state.c`
- `nemu/src/monitor/monitor.c`
- `nemu/src/monitor/sdb/sdb.c`
- `nemu/src/cpu/cpu-exec.c`
- `nemu/src/isa/riscv32/inst.c`
- `nemu/src/isa/riscv32/init.c`
- `abstract-machine/Makefile`
- `abstract-machine/scripts/riscv32-nemu.mk`
- `abstract-machine/scripts/platform/nemu.mk`
- `abstract-machine/am/include/stdint.h`
- `abstract-machine/am/include/stddef.h`
- `abstract-machine/am/include/stdbool.h`
- `am-kernels/tests/cpu-tests/Makefile`
