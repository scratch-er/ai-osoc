# macOS Platform Notes

This note collects macOS-specific assumptions and workarounds discovered before adding Linux validation at the end of Phase 7. macOS remains a supported development platform for functionality checks; future sessions must first detect the current host and choose either this note or `notes/platform-linux.md` instead of assuming a platform globally.

## Host and paths

- Previous working tree path in recorded commands: `/Users/venti/Workspace/ai-ysyx`.
- Many older validation snippets in `notes/next.md` use absolute macOS paths for:
  - `AM_HOME=/Users/venti/Workspace/ai-ysyx/abstract-machine`
  - `NPC_DIFFTEST_REF=/Users/venti/Workspace/ai-ysyx/nemu/build/riscv32-nemu-interpreter-so`
  - `ROOT=/Users/venti/Workspace/ai-ysyx`
- When moving those commands to another host, replace these with the current checkout path or use `ROOT=$(pwd)` from the repository root.

## Cross toolchain

- Previous macOS host had `riscv64-elf-gcc` and related binutils, not `riscv64-linux-gnu-gcc`.
- AM/NPC workload commands therefore used:

```sh
CROSS_COMPILE=riscv64-elf-
```

- The default AM RISC-V ISA script uses `riscv64-linux-gnu-`, so macOS commands had to override `CROSS_COMPILE` explicitly.

## Shell and Makefile behavior

- `am-kernels/tests/cpu-tests/Makefile` uses `/bin/echo -e` to generate temporary per-test makefiles.
- On macOS, `/bin/echo` does not handle `-e` the GNU/Linux way, so the wrapper command failed.
- Previous cpu-tests sweeps used a temporary Makefile generated with `printf` instead of invoking that wrapper directly. Example shape:

```sh
ROOT=/Users/venti/Workspace/ai-ysyx
TESTDIR="$ROOT/am-kernels/tests/cpu-tests/tests"
REF="$ROOT/nemu/build/riscv32-nemu-interpreter-so"
for t in $(cd "$TESTDIR" && ls *.c | sed 's/\.c$//' | sort); do
  tmp=$(mktemp /tmp/am-$t.XXXXXX.mk) || exit 1
  printf 'NAME = %s\nSRCS = %s/%s.c\nINC_PATH += %s/am-kernels/tests/cpu-tests/include\ninclude %s/abstract-machine/Makefile\n' \
    "$t" "$TESTDIR" "$t" "$ROOT" "$ROOT" > "$tmp"
  make -f "$tmp" ARCH=riscv32e-npc AM_HOME="$ROOT/abstract-machine" \
    CROSS_COMPILE=riscv64-elf- NPC_MAX_CYCLES=8000000 \
    NPC_DIFFTEST_REF="$REF" run
  rm -f "$tmp"
done
```

## RT-Thread generated config portability

- RT-Thread AM integration was adjusted during Phase 4 to avoid GNU `sed -i` assumptions on macOS.
- The current `rt-thread-am/bsp/abstract-machine/Makefile` path inserts `#include "extra.h"` without relying on GNU-only `sed -i`, adds the freestanding extension include path, and pre-includes `sys/types.h` for common POSIX typedefs.
- This remains useful portability work on Linux too; do not revert it to a GNU-only edit path.

## SDL and NEMU devices

- NEMU native device support for the project was configured for UART and timer only.
- Keyboard, VGA, audio, disk, and sdcard were disabled in the recorded `.config` so the macOS build did not need SDL for this slice.
- Recorded relevant NEMU config values:
  - `CONFIG_DEVICE=y`
  - `CONFIG_HAS_SERIAL=y`, `CONFIG_SERIAL_MMIO=0xa00003f8`
  - `CONFIG_HAS_TIMER=y`, `CONFIG_RTC_MMIO=0xa0000048`
  - keyboard/VGA/audio/disk/sdcard disabled.

## Existing generated binaries

- Before switching platforms, `npc/build/npc`, `nemu/build/riscv32-nemu-interpreter`, and `nemu/build/riscv32-nemu-interpreter-so` were macOS arm64 Mach-O outputs.
- Those outputs cannot run on Linux and must be rebuilt on the Linux host.

## Phase 8 implication

- macOS remains valid for functionality regressions and any performance counters emitted by the simulator itself.
- Some Phase 8 host-side tools are Linux-specific or host-sensitive, such as `perf` and the currently installed synthesis/PPA tools. When on macOS, either use macOS-available alternatives or record a documented blocker for those Linux-only measurements.
- Keep command examples platform-specific: use `CROSS_COMPILE=riscv64-elf-` on the recorded macOS host, and do not copy Linux-only paths or tool names without checking availability.
