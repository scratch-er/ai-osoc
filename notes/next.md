# Next Session

Current state:

- Phase 1 Session 1 (`P1-S1: Baseline NEMU bring-up and command inventory`) is complete.
- Phase 1 Session 2 (`P1-S2: Minimal execution path for AM dummy`) is complete.
- Phase 1 Session 3 (`P1-S3: CPU-test instruction coverage slice`) is complete: the representative RV32I cpu-test slice passes and remaining failures are M-extension/device blockers.
- Phase 1 Session 4 (`P1-S4: Batch mode and concise result reporting`) is complete.
- Phase 1 Session 5 (`P1-S5: Essential tracing for failures`) is complete.
- Phase 1 Session 6 (`P1-S6: DiffTest REF shared object preparation`) is complete: the NEMU REF shared object builds and its exported memory/register/exec APIs pass a host-side smoke test.
- Phase 1 Session 7 (`P1-S7: AM workload integration and hello smoke test`) is complete: AM `hello` prints through the minimal NEMU serial path and exits with `NEMU_RESULT status=good`.
- `npc/` is absent; no NPC work has started.
- Repository status before Phase 1 work already had untracked `.DS_Store` and `activate`. Leave them alone unless the user explicitly asks.

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
  - `CONFIG_IQUEUE=y`
  - `CONFIG_IQUEUE_SIZE=16`
  - `# CONFIG_MTRACE is not set`
  - `CONFIG_MBASE=0x80000000`
  - `CONFIG_MSIZE=0x2000000`
- The REF shared-object check temporarily edits `nemu/.config` to `CONFIG_TARGET_SHARE=y`, runs `tools/kconfig/build/conf -s --syncconfig Kconfig`, builds `build/riscv32-nemu-interpreter-so`, then restores the native `.config` and rebuilds the native executable.
- Devices remain disabled because native device build on this macOS environment failed on missing `SDL2/SDL.h`.
- Host has `riscv64-elf-gcc`, not `riscv64-linux-gnu-gcc`; AM commands currently need `CROSS_COMPILE=riscv64-elf-`.
- The installed `riscv64-elf-gcc` is configured `--without-headers`, so local freestanding AM headers were added:
  - `abstract-machine/am/include/stdint.h`
  - `abstract-machine/am/include/stddef.h`
  - `abstract-machine/am/include/stdbool.h`

Important completed changes by session:

- P1-S2:
  - `nemu/src/monitor/monitor.c`: removed the intentional PA skeleton `assert(0)` from `welcome()`.
  - `nemu/src/isa/riscv32/inst.c`: added minimal AM `dummy` execution support (`addi`, `sw`, `jal`, `jalr`, J-type decode).
  - `abstract-machine/Makefile`: fixed library linkage expansion for AM/klib archives.
  - `abstract-machine/scripts/platform/nemu.mk`: run NEMU in batch mode and use `python3` for `insert-arg.py`.
- P1-S3:
  - `nemu/src/isa/riscv32/inst.c`: added common RV32I decode/execution coverage for the representative cpu-test slice: U/I/load/store/R/B instruction groups.
  - Added `notes/nemu-rv32i-instruction-notes.md`.
- P1-S4:
  - Added `--max-insts` / `NEMU_LIMIT` and stable `NEMU_RESULT status=...` reporting.
  - AM `riscv32-nemu` run path now passes `--max-insts=$(NEMU_MAX_INSTS)`.
- P1-S5:
  - Added compact instruction ring buffer (`CONFIG_IQUEUE`) and filtered memory tracing (`CONFIG_MTRACE`).
  - Failure paths dump bounded recent instructions; normal passing runs stay concise.
- P1-S6:
  - `nemu/src/cpu/difftest/ref.c`: implemented REF-side `difftest_memcpy`, `difftest_regcpy`, and `difftest_exec` for the current riscv32 CPU state; `difftest_raise_intr` remains an explicit `assert(0)` gap because trap/CSR behavior is not implemented yet.
  - `nemu/src/filelist.mk`: made the shared-object target omit `src/nemu-main.c`, monitor code, and the interactive engine entry so it can link as a DiffTest REF library without unresolved sdb symbols.
  - Added `nemu/tools/ref-api-smoke.py`, a host-side ctypes smoke test that checks exported symbols, REF initialization, register copy, memory round-trip, and a one-instruction execution step.
- P1-S7:
  - `nemu/src/isa/riscv32/include/isa-def.h` now carries the minimal M-mode CSR state used by AM traps: `mstatus`, `mtvec`, `mepc`, and `mcause`.
  - `nemu/src/isa/riscv32/inst.c` implements the Zicsr instruction forms used by AM trap code, plus M-mode `ecall` and `mret`.
  - `nemu/src/isa/riscv32/system/intr.c` saves `mepc`/`mcause` and dispatches to `mtvec`.
  - `nemu/src/memory/paddr.c` provides a minimal `0xa00003f8` serial MMIO fallback when `CONFIG_DEVICE` is off, enough for AM `putch()`/`hello` output without requiring SDL2-backed devices.

Validated commands and results:

1. Build REF shared object and run REF API smoke test:

   ```sh
   cd nemu
   cp .config /tmp/nemu.config.before-p1s6
   python3 - <<'PY'
   from pathlib import Path
   p = Path('.config')
   lines = p.read_text().splitlines()
   out = []
   seen_share = seen_native = False
   for line in lines:
       if line.startswith('CONFIG_TARGET_NATIVE_ELF=') or line == 'CONFIG_TARGET_NATIVE_ELF=y':
           out.append('# CONFIG_TARGET_NATIVE_ELF is not set')
           seen_native = True
       elif line.startswith('# CONFIG_TARGET_NATIVE_ELF is not set'):
           out.append('# CONFIG_TARGET_NATIVE_ELF is not set')
           seen_native = True
       elif line.startswith('CONFIG_TARGET_SHARE=') or line == 'CONFIG_TARGET_SHARE=y':
           out.append('CONFIG_TARGET_SHARE=y')
           seen_share = True
       elif line.startswith('# CONFIG_TARGET_SHARE is not set'):
           out.append('CONFIG_TARGET_SHARE=y')
           seen_share = True
       else:
           out.append(line)
   if not seen_native:
       out.append('# CONFIG_TARGET_NATIVE_ELF is not set')
   if not seen_share:
       out.append('CONFIG_TARGET_SHARE=y')
   p.write_text('\n'.join(out) + '\n')
   PY
   tools/kconfig/build/conf -s --syncconfig Kconfig
   make -j$(sysctl -n hw.ncpu)
   python3 tools/ref-api-smoke.py ./build/riscv32-nemu-interpreter-so
   cp /tmp/nemu.config.before-p1s6 .config
   tools/kconfig/build/conf -s --syncconfig Kconfig
   make -j$(sysctl -n hw.ncpu)
   ```

   Result:

   ```text
   REF_API_SMOKE status=pass pc=0x80000004 x0=0x00000000 t0=0x80000000 mem_addr=0x80000100
   ```

   Export check on macOS:

   ```sh
   nm -gU build/riscv32-nemu-interpreter-so | grep difftest
   ```

   Result includes all required exported symbols:

   ```text
   _difftest_exec
   _difftest_init
   _difftest_memcpy
   _difftest_raise_intr
   _difftest_regcpy
   ```

2. Build native NEMU and run the built-in image with an explicit limit:

   ```sh
   cd nemu
   make -j$(sysctl -n hw.ncpu)
   ./build/riscv32-nemu-interpreter --batch --max-insts=100
   ```

   Result: passes with `HIT GOOD TRAP`; final structured line:

   ```text
   NEMU_RESULT status=good state=2 halt_pc=0x8000000c halt_ret=0 insts=4 limit=100
   ```

3. Verify instruction-limit failure path and bounded recent instruction dump:

   ```sh
   cd nemu
   ./build/riscv32-nemu-interpreter --batch --max-insts=2
   ```

   Result: exits nonzero as expected; output includes:

   ```text
   NEMU_RESULT status=limit state=5 halt_pc=0x80000008 halt_ret=1 insts=2 limit=2
   ```

4. Current cpu-test slice, checking `NEMU_RESULT status=good` for each test:

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

5. AM `hello` workload:

   ```sh
   source ./activate
   cd am-kernels/kernels/hello
   make ARCH=riscv32-nemu CROSS_COMPILE=riscv64-elf- run
   ```

   Result: prints the expected text through serial MMIO and exits cleanly:

   ```text
   Hello, AbstractMachine!
   mainargs = ''.
   NEMU_RESULT status=good state=2 halt_pc=0x800000c4 halt_ret=0 insts=352 limit=10000000
   ```

Known caveats:

- `difftest_raise_intr()` in the NEMU REF shared object still asserts. Current `ecall`/`mret` trap execution works in normal NEMU execution, but the REF external interrupt API is still not implemented.
- The current DiffTest register blob is still `DIFFTEST_REG_SIZE`, i.e. 32 riscv32 GPRs plus PC. The CPU struct now has `mstatus`/`mtvec`/`mepc`/`mcause`, but CSR state is not included in the DiffTest copy/check contract yet.
- `CONFIG_IQUEUE=y` builds Capstone under `nemu/tools/capstone/repo/` if not already present, because the ring buffer stores disassembled instruction strings. This directory is ignored/generated tooling.
- The `am-kernels/tests/cpu-tests` wrapper command still fails on macOS:

  ```sh
  source ./activate
  make -C am-kernels/tests/cpu-tests ARCH=riscv32-nemu CROSS_COMPILE=riscv64-elf- ALL=dummy run
  ```

  It reports `[dummy] ***FAIL***` because the wrapper uses `/bin/echo -e` to generate `Makefile.$test`; macOS `/bin/echo` writes the literal `-e`, producing an invalid makefile. Do not modify `am-kernels/` unless explicitly allowed; use the temporary `printf` command above for now, or fix the wrapper later if the user permits changing `am-kernels`.
- Current cpu-test status after P1-S7:
  - Passing verified this session: `dummy`, `add`, `add-longlong`, `bit`, `bubble-sort`, `crc32`, `fib`, `if-else`, `load-store`, `max`, `min3`, `mov-c`, `movsx`, `pascal`, `quick-sort`, `select-sort`, `shift`, `sub-longlong`, `sum`, `switch`, `to-lower-case`, `unalign`.
  - The earlier serial MMIO blocker is fixed for simple byte output; AM `hello` now passes.
  - `hello-str` was probed after the serial fix and now reaches serial output, but still fails in `abstract-machine/klib/src/stdio.c:17` because klib `printf` is not implemented. Leave this for a later klib/runtime session unless needed immediately.
  - M-extension tests remain out of scope for now because the future target core remains RV32E_Zicsr.
- `abstract-machine/scripts/riscv32-nemu.mk` still defaults `CROSS_COMPILE := riscv64-linux-gnu-`; continue passing `CROSS_COMPILE=riscv64-elf-` unless the toolchain/default is changed.
- Devices remain disabled because the native device build on this macOS environment needs SDL2; the minimal serial fallback is intentionally not a full device model.
- `--max-insts` counts global guest instructions since process start. That is fine for current one-image one-run invocations.

Next work:

1. Start Phase 1 Session 8 (`P1-S8: Phase closeout and handoff to NPC creation`).
2. Re-run the standard Phase 1 smoke set: built-in NEMU, representative cpu-tests, AM `hello`, and REF shared-object smoke test.
3. Decide whether to keep Phase 1 closed with only simple serial output or add a small klib `printf` session for `hello-str`/`string` before NPC work.
4. Update `notes/next.md` with the stable Phase 1 handoff and first Phase 2 task.
5. Do not touch `am-kernels/` unless the user explicitly approves fixing its macOS wrapper.

Relevant files:

- `notes/plan.md`
- `notes/lecture-note-summary.md`
- `notes/nemu-rv32i-instruction-notes.md`
- `specs/core.md`
- `specs/riscv-isa-manual/src/unpriv/rv32.adoc`
- `specs/riscv-isa-manual/src/unpriv/rv32e.adoc`
- `nemu/.config` (generated/ignored local build config)
- `nemu/src/filelist.mk`
- `nemu/src/cpu/difftest/ref.c`
- `nemu/tools/ref-api-smoke.py`
- `nemu/Kconfig`
- `nemu/include/utils.h`
- `nemu/include/cpu/decode.h`
- `nemu/src/utils/state.c`
- `nemu/src/monitor/monitor.c`
- `nemu/src/monitor/sdb/sdb.c`
- `nemu/src/cpu/cpu-exec.c`
- `nemu/src/memory/paddr.c`
- `nemu/src/isa/riscv32/include/isa-def.h`
- `nemu/src/isa/riscv32/inst.c`
- `nemu/src/isa/riscv32/init.c`
- `nemu/src/isa/riscv32/system/intr.c`
- `abstract-machine/Makefile`
- `abstract-machine/scripts/riscv32-nemu.mk`
- `abstract-machine/scripts/platform/nemu.mk`
- `abstract-machine/am/include/stdint.h`
- `abstract-machine/am/include/stddef.h`
- `abstract-machine/am/include/stdbool.h`
- `am-kernels/tests/cpu-tests/Makefile`
