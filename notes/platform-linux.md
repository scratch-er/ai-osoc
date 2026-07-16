# Linux Platform Notes

This note records the Linux environment found during the Phase 7 closing session. It is the Linux counterpart to `notes/platform-macos.md`; future sessions must first identify the current host platform and then use the matching platform note rather than assuming either macOS or Linux.

## Host

Observed on 2026-07-16 session:

```text
Linux aosc 7.0.13-aosc-main #1 SMP PREEMPT_DYNAMIC Thu Jun 25 03:09:20 UTC 2026 aarch64 GNU/Linux
AOSC OS 13.3.0 (Meow), VERSION_ID=13.3.0, BUILD_ID=20260613
```

Repository path in this session:

```sh
/host/Workspace/ai-ysyx
```

Use repository-relative paths or derive `ROOT` dynamically instead of copying the old macOS `/Users/venti/...` paths:

```sh
ROOT=/host/Workspace/ai-ysyx
REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so"
```

## Available tools

Observed available commands after Linux setup was completed:

- `bash`: `/usr/bin/bash`
- `make`: `/usr/bin/make` (`GNU Make 4.4.1`)
- `gcc`: `/usr/bin/gcc` (`GCC 15.3.0 20260612 (AOSC OS)`)
- `g++`: `/usr/bin/g++`
- `clang`: `/usr/bin/clang` (`clang version 20.1.8`)
- `clang++`: `/usr/bin/clang++`
- `verilator`: `/usr/bin/verilator` (`Verilator 5.046 2026-02-28`)
- `git`: `/usr/bin/git`
- `python3`: `/usr/bin/python3` (`Python 3.14.6`)
- `scons`: `/usr/bin/scons` (`SCons v4.10.1`)
- `perf`: `/usr/bin/perf` (`perf version 7.0.13`)
- `yosys`: `/usr/bin/yosys` (`Yosys 0.45`)
- `iEDA`: `/home/venti/.nix-profile/bin/iEDA`
- `riscv64-linux-gnu-gcc`: `/usr/bin/riscv64-linux-gnu-gcc` (`GCC 15.2.0`)

Observed missing commands in `PATH`:

- `riscv64-elf-gcc`
- `riscv64-unknown-elf-gcc`

These missing bare-metal prefixes are not blockers on this Linux host because it uses `CROSS_COMPILE=riscv64-linux-gnu-`. On macOS, use the macOS platform note instead.

## RISC-V cross toolchain

This Linux host has `riscv64-linux-gnu-gcc`; the previous macOS host had `riscv64-elf-gcc`. Choose `CROSS_COMPILE` from the current host, not from a hard-coded global assumption.

- Sysroot: `/var/ab/cross-root/riscv64`
- GCC target: `riscv64-aosc-linux-gnu`
- GCC default target arch/ABI: `rv64gc/lp64d`
- A direct compile smoke confirmed explicit RV32E object generation works:

```sh
riscv64-linux-gnu-gcc -march=rv32e_zicsr -mabi=ilp32e -ffreestanding -nostdlib -c t.c -o t.o
```

`file t.o` reported:

```text
ELF 32-bit LSB relocatable, UCB RISC-V, RVE, soft-float ABI, version 1 (SYSV), not stripped
```

Linux AM commands can therefore usually use the default AM RISC-V prefix, or pass it explicitly:

```sh
CROSS_COMPILE=riscv64-linux-gnu-
```

## Generated binary compatibility and rebuild notes

The checked-out `npc/build/npc`, `nemu/build/riscv32-nemu-interpreter`, and `nemu/build/riscv32-nemu-interpreter-so` were generated on the previous macOS host and were Mach-O arm64 binaries. They could not run on this Linux host and had to be rebuilt.

Linux rebuild notes from P7 closeout:

- `nemu/tools/fixdep/build/fixdep` and `nemu/tools/kconfig/build/conf` were also stale macOS Mach-O helpers; remove their `build/` directories and rebuild them before using NEMU config/build rules.
- `NEMU_HOME` must be passed explicitly when invoking NEMU make targets from this environment.
- The NEMU REF must be built with `.config` selecting `CONFIG_TARGET_SHARE=y` and `CONFIG_DEVICE=y` so the shared object includes NPC UART/CLINT MMIO replay support.
- `nemu/src/device/Kconfig` was adjusted to allow `CONFIG_DEVICE=y` together with `CONFIG_TARGET_SHARE=y`; otherwise the shared REF lacks the NPC MMIO replay backing code.

Useful rebuild sequence:

```sh
ROOT=/host/Workspace/ai-ysyx
rm -rf "$ROOT/nemu/tools/fixdep/build" "$ROOT/nemu/tools/kconfig/build"
make -C "$ROOT/nemu/tools/fixdep" NEMU_HOME="$ROOT/nemu"
make -C "$ROOT/nemu/tools/kconfig" NEMU_HOME="$ROOT/nemu" conf
# Ensure nemu/.config has CONFIG_TARGET_SHARE=y and CONFIG_DEVICE=y, then:
(cd "$ROOT/nemu" && yes '' | tools/kconfig/build/conf -s --syncconfig Kconfig >/tmp/nemu-sync.log 2>&1 || true)
make -C "$ROOT/nemu" NEMU_HOME="$ROOT/nemu" clean
make -C "$ROOT/nemu" NEMU_HOME="$ROOT/nemu"
make -C "$ROOT/npc" clean
make -C "$ROOT/npc" REF_SO="$ROOT/nemu/build/riscv32-nemu-interpreter-so"
```

After the rebuild, the observed REF was a Linux/aarch64 ELF shared object and DiffTest could `dlopen()` it.

## Linux-specific simplifications vs macOS

- GNU `/bin/echo -e` behavior is available on Linux, so the old macOS `printf` workaround for `am-kernels/tests/cpu-tests/Makefile` may no longer be necessary. The workaround remains portable and safe if exact reproducibility is preferred.
- GNU `sed -i` is available on Linux, but the current RT-Thread AM Makefile workaround is already portable and should stay.
- `perf` is available and should be used in Phase 8 for Linux-side profiling experiments.

## PPA/synthesis tooling notes

- The repository has a `yosys-sta/` directory.
- `yosys` is available in `PATH` and reports `Yosys 0.45` for this aarch64 host.
- `iEDA` is available as `/home/venti/.nix-profile/bin/iEDA`; verify the exact flow in Phase 8 before relying on it for timing/area reports.
- `yosys-sta/bin/iEDA.x86_64` is an x86-64 Linux ELF binary; this host is `aarch64`, so that specific binary is not directly runnable without an x86-64 compatibility layer/emulator.
- `perf` is available and should be used for Linux-only profiling work.

Phase 8 synthesis/timing/area work should start with a small tool smoke before running long baseline jobs.

## Linux P7 verification commands and results

Use Linux paths/prefixes:

```sh
ROOT=/host/Workspace/ai-ysyx
REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so"

make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug \
  test-difftest test-clint test-icache test-fencei test-access-fault \
  REF_SO="$REF"

make -C am-kernels/kernels/hello ARCH=riscv32e-npc \
  AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-linux-gnu- \
  NPC_MAX_CYCLES=2000000 NPC_DIFFTEST_REF="$REF" run

make -C rt-thread-am/bsp/abstract-machine ARCH=riscv32e-npc \
  AM_HOME="$ROOT/abstract-machine" CROSS_COMPILE=riscv64-linux-gnu- \
  NPC_MAX_CYCLES=12000000 NPC_DIFFTEST_REF="$REF" run
```

For the full cpu-tests sweep, either use the Linux wrapper directly or keep the portable temporary-Makefile loop from `notes/platform-macos.md` with `ROOT=/host/Workspace/ai-ysyx` and `CROSS_COMPILE=riscv64-linux-gnu-`.


Observed P7 closeout results on Linux:

- NPC directed regression passed:

```sh
make -C npc smoke test-addi test-jalr-ebreak test-lw-sw test-alu \
  test-mem-size test-rv32e-illegal test-csr-trap test-debug \
  test-difftest test-clint test-icache test-fencei test-access-fault \
  REF_SO=/host/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so
```

Representative directed counters:

- `test-clint`: `NPC_RESULT status=good reason=good_trap cycles=68 insts=19 pc=0x80000048 ...`; `NPC_ICACHE accesses=19 hits=14 misses=5 miss_wait_cycles=30 refill_beats=20 hit_rate_x1000=736 amat_x1000=2578`.
- `test-icache`: `NPC_RESULT status=good reason=good_trap cycles=50 insts=19 pc=0x20000010 ...`; `NPC_ICACHE accesses=19 hits=17 misses=2 miss_wait_cycles=12 refill_beats=8 hit_rate_x1000=894 amat_x1000=1631`.
- `test-fencei`: `NPC_RESULT status=good reason=good_trap cycles=50 insts=9 pc=0x80000008 ...`; `NPC_ICACHE accesses=9 hits=4 misses=5 miss_wait_cycles=30 refill_beats=20 hit_rate_x1000=444 amat_x1000=4333`.

- `hello` passed with NEMU event DiffTest using `CROSS_COMPILE=riscv64-linux-gnu-`:
  - printed `Hello, AbstractMachine!` and `mainargs = ''.`
  - `NEMU_RESULT status=good state=2 halt_pc=0x800000c4 halt_ret=0 insts=465 limit=0`
  - `NPC_RESULT status=good reason=good_trap cycles=2116 insts=465 pc=0x800000c4 ...`
  - `NPC_ICACHE accesses=465 hits=297 misses=168 miss_wait_cycles=1008 refill_beats=672 hit_rate_x1000=638 amat_x1000=3167`

- Full 35-test `cpu-tests` sweep passed with NEMU event DiffTest and `CROSS_COMPILE=riscv64-linux-gnu-`:
  - passed: `add`, `add-longlong`, `bit`, `bubble-sort`, `crc32`, `div`, `dummy`, `fact`, `fib`, `goldbach`, `hello-str`, `if-else`, `leap-year`, `load-store`, `matrix-mul`, `max`, `mersenne`, `min3`, `mov-c`, `movsx`, `mul-longlong`, `narcissistic`, `pascal`, `prime`, `quick-sort`, `recursion`, `select-sort`, `shift`, `string`, `sub-longlong`, `sum`, `switch`, `to-lower-case`, `unalign`, `wanshu`.
  - Representative counters:
    - `sum`: `NPC_ICACHE accesses=528 hits=517 misses=11 miss_wait_cycles=66 refill_beats=44 hit_rate_x1000=979 amat_x1000=1125`.
    - `matrix-mul`: `NPC_RESULT status=good reason=good_trap cycles=543774 insts=131726 ...`; `NPC_ICACHE accesses=131726 hits=87058 misses=44668 miss_wait_cycles=268008 refill_beats=178672 hit_rate_x1000=660 amat_x1000=3034`.
    - `string`: `NPC_ICACHE accesses=1449 hits=1379 misses=70 miss_wait_cycles=420 refill_beats=280 hit_rate_x1000=951 amat_x1000=1289`.

- AM devscan/timer bounded run reached the expected timer-loop cycle limit:
  - `NPC_RESULT status=limit reason=cycle_limit cycles=80000000 insts=25000215 pc=0x80000a5c ...`
  - `NPC_ICACHE accesses=25000215 hits=24998806 misses=1409 miss_wait_cycles=8454 refill_beats=5636 hit_rate_x1000=999 amat_x1000=1000`.

- `yield-os` bounded run reached the expected cycle limit after printing `ABABABAB`:
  - `NPC_RESULT status=limit reason=cycle_limit cycles=12000000 insts=3749488 pc=0x800000a0 ...`
  - `NPC_CSR mstatus=0x00001800 mtvec=0x80000318 mepc=0x80000308 mcause=0x0000000b`
  - `NPC_ICACHE accesses=3749488 hits=3749151 misses=337 miss_wait_cycles=2022 refill_beats=1348 hit_rate_x1000=999 amat_x1000=1000`.

- `thread-os` bounded run reached the expected cycle limit after eight ordered `Thread-B on CPU #0` lines:
  - `NPC_RESULT status=limit reason=cycle_limit cycles=12000000 insts=3746560 pc=0x800001a8 ...`
  - `NPC_CSR mstatus=0x00001800 mtvec=0x800003e0 mepc=0x800003d8 mcause=0x0000000b`
  - `NPC_ICACHE accesses=3746560 hits=3744200 misses=2360 miss_wait_cycles=14160 refill_beats=9440 hit_rate_x1000=999 amat_x1000=1003`.

- RT-Thread passed after regenerating `rt-thread-am/bsp/abstract-machine/files.mk` with Linux paths via `make init` and `scons`:
  - output included the RT-Thread banner, `Hello RISC-V!`, shell commands through `msh />halt`.
  - `NEMU_RESULT status=good state=2 halt_pc=0x8000022c halt_ret=0 insts=511842 limit=0`
  - `NPC_RESULT status=good reason=good_trap cycles=1816964 insts=511842 pc=0x8001f718 ...`
  - `NPC_ICACHE accesses=511842 hits=428931 misses=82911 miss_wait_cycles=497466 refill_beats=331644 hit_rate_x1000=838 amat_x1000=1971`
