# Next Session

Current state:

- Phase 1 Session 1 (`P1-S1: Baseline NEMU bring-up and command inventory`) is complete.
- Phase 1 Session 2 (`P1-S2: Minimal execution path for AM dummy`) is complete.
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
  - Existing implemented instructions are still only a tiny skeleton: `auipc`, `lbu`, `sb`, `ebreak`, plus invalid instruction handling.
- `abstract-machine/Makefile`
  - Fixed library linkage expansion so AM and klib archives are linked into test images.
  - `define LIB_TEMPLATE =` was invalid for the intended multi-line macro; changed to `define LIB_TEMPLATE`.
  - `LINKAGE` was changed to immediate assignment so generated archive dependencies are preserved correctly.
- `abstract-machine/scripts/platform/nemu.mk`
  - Added `-b` to `NEMUFLAGS` so AM `run` invokes NEMU in batch mode.
  - Changed `python` to `python3` for `insert-arg.py` on this macOS environment.

Validated commands and results:

1. Build native NEMU:

   ```sh
   cd nemu
   make -j$(sysctl -n hw.ncpu)
   ```

   Result: passes, target `nemu/build/riscv32-nemu-interpreter` is built.

2. Run NEMU built-in image:

   ```sh
   cd nemu
   ./build/riscv32-nemu-interpreter --batch
   ```

   Result: `HIT GOOD TRAP` at `pc = 0x8000000c`, total guest instructions `4`.

3. Build and run AM `dummy` directly with a temporary generated makefile:

   ```sh
   source ./activate
   cd am-kernels/tests/cpu-tests
   printf 'NAME = dummy\nSRCS = tests/dummy.c\ninclude %s/Makefile\n' "$AM_HOME" > Makefile.dummy
   make -f Makefile.dummy ARCH=riscv32-nemu CROSS_COMPILE=riscv64-elf- run
   rm -f Makefile.dummy
   ```

   Result: `HIT GOOD TRAP` at `pc = 0x80000030`, total guest instructions `13`.

Known caveats:

- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS:

  ```sh
  source ./activate
  make -C am-kernels/tests/cpu-tests ARCH=riscv32-nemu CROSS_COMPILE=riscv64-elf- ALL=dummy run
  ```

  It reports `[dummy] ***FAIL***` because the wrapper uses `/bin/echo -e` to generate `Makefile.$test`; macOS `/bin/echo` writes the literal `-e`, producing an invalid makefile. Do not modify `am-kernels/` unless explicitly allowed; use the temporary `printf` command above for now, or fix the wrapper later if the user permits changing `am-kernels`.

- NEMU is still far from full RV32 coverage. Only the `dummy` path is supported.
- `abstract-machine/scripts/riscv32-nemu.mk` still defaults `CROSS_COMPILE := riscv64-linux-gnu-`; continue passing `CROSS_COMPILE=riscv64-elf-` unless the toolchain/default is changed.
- Devices are still disabled; serial/timer work should wait until the relevant Phase 1/AM workload sessions, or until SDL2/device strategy is decided.

Next work:

1. Start Phase 1 Session 3 (`P1-S3: CPU-test instruction coverage slice`).
2. Use one small CPU test at a time with the temporary `printf` makefile pattern, starting with likely `add` or `bit`.
3. For each failure, inspect `build/<test>-riscv32-nemu.txt`, add only the missing instruction(s), rebuild NEMU, and rerun that test.
4. Keep a compact list of implemented instructions and passing tests in this file.
5. Avoid touching `am-kernels/` unless the user explicitly approves fixing its macOS wrapper.

Relevant files:

- `notes/plan.md`
- `notes/lecture-note-summary.md`
- `specs/core.md`
- `nemu/.config` (generated/ignored local build config)
- `nemu/src/monitor/monitor.c`
- `nemu/src/isa/riscv32/inst.c`
- `nemu/src/isa/riscv32/init.c`
- `abstract-machine/Makefile`
- `abstract-machine/scripts/riscv32-nemu.mk`
- `abstract-machine/scripts/platform/nemu.mk`
- `abstract-machine/am/include/stdint.h`
- `abstract-machine/am/include/stddef.h`
- `abstract-machine/am/include/stdbool.h`
- `am-kernels/tests/cpu-tests/Makefile`
