# NPC

Initial Verilog NPC project for the RV32E_Zicsr core.

Current status: P2-S1 skeleton and Verilator harness only. The RTL currently resets `pc` to `0x20000000` and advances it by 4 each cycle; real instruction execution starts in the next session.

## Commands

Build:

```sh
make -C npc
```

Run the deterministic smoke test:

```sh
make -C npc smoke
```

Run with an optional image, reset PC, and cycle limit:

```sh
make -C npc run ARGS="--image path/to/image.bin --reset-pc 0x20000000 --max-cycles 100"
```

Enable waveform generation:

```sh
make -C npc TRACE=1 run ARGS="--wave --max-cycles 8"
```

The simulator prints stable result lines of the form:

```text
NPC_RESULT status=... cycles=... pc=... halted=... limit=...
```
