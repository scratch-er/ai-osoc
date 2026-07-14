# NPC

Initial Verilog NPC project for the RV32E_Zicsr core.

Current status: P2-S4 DPI-C data memory slice. The RTL fetches instructions through DPI-C memory, executes RV32E `addi`, aligned `lw`/`sw`, and `jalr`, keeps `x0` immutable, and terminates on `ebreak` with GOOD/BAD status from `a0` (`x10 == 0` means GOOD). Unsupported instructions halt with BAD status.

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

Run with an optional image, reset PC, cycle limit, and optional x1 check:

```sh
make -C npc run ARGS="--image path/to/image.bin --reset-pc 0x20000000 --max-cycles 100 --expect-x1 0x5"
```

Enable waveform generation:

```sh
make -C npc TRACE=1 run ARGS="--wave --max-cycles 8"
```

The simulator prints stable result lines of the form:

```text
NPC_RESULT status=... cycles=... pc=... halted=... limit=... x1=... a0=... trap=...
```
