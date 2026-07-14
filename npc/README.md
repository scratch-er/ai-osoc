# NPC

Initial Verilog NPC project for the RV32E_Zicsr core.

Current status: P2-S6 early DiffTest slice. The RTL fetches instructions through DPI-C memory, executes RV32E `addi`, `auipc`, aligned `lw`/`sw`, and `jalr`, keeps `x0` immutable, and terminates on `ebreak` with GOOD/BAD status from `a0` (`x10 == 0` means GOOD). Unsupported instructions halt with BAD status. The C++ harness can optionally compare retired state against the NEMU REF shared object for the current tiny subset.

## Commands

Build:

```sh
make -C npc
```

Run the deterministic smoke test:

```sh
make -C npc smoke
```

Run the `addi` datapath regression:

```sh
make -C npc test-addi
```

Run the `jalr`/`ebreak` termination regression:

```sh
make -C npc test-jalr-ebreak
```

Run the aligned `lw`/`sw` data-memory regression:

```sh
make -C npc test-lw-sw
```

Run the debug-output regression:

```sh
make -C npc test-debug
```

Run the early DiffTest regression against NEMU REF:

```sh
make -C npc test-difftest
```

Run with an optional image, reset PC, cycle limit, optional x1 check, and optional DiffTest REF:

```sh
make -C npc run ARGS="--image path/to/image.bin --reset-pc 0x80000000 --max-cycles 100 --expect-x1 0x5 --difftest-ref ../nemu/build/riscv32-nemu-interpreter-so"
```

Enable waveform generation:

```sh
make -C npc TRACE=1 run ARGS="--wave --max-cycles 8"
```

The simulator prints stable result lines of the form:

```text
NPC_RESULT status=... cycles=... pc=... halted=... limit=... x1=... a0=... trap=...
```
