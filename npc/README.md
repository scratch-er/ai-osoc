# NPC

Initial Verilog NPC project for the RV32E_Zicsr core.

Current status: P2-S2 minimal datapath. The RTL fetches instructions through DPI-C memory, executes RV32E `addi`, keeps `x0` immutable, and halts on unsupported instructions.

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
NPC_RESULT status=... cycles=... pc=... halted=... limit=... x1=...
```
