# Physical CLINT Implementation Plan

## Decision

Implement the built-in CLINT as a physical RTL block on the LSU side before `AxiArbiter` (Position 5), using a combinational bypass/mux.

This is the approved topology because the core only needs one local device (`CLINT`) and the design should minimize area and protect frequency. Do not add a generic local-device bus, AXI xbar, post-arbiter decoder, or source tags for extensibility that the spec does not require.

## Current bus topology

Current core memory path:

```text
IFU request  ----\
                 AxiArbiter -> AxiMaster -> AXI master
LSU request  ----/
```

Properties:

- `AxiArbiter` gives LSU priority over IFU.
- `AxiMaster` is single-request, single-beat AXI.
- `LOCAL_AXI=1` simulation loops the top AXI master into `LocalAxiSlave.v`.
- Current CLINT/timer behavior is in C++ `Memory`, not physical RTL.

## Target topology

```text
IFU request --------------------------\
                                      AxiArbiter -> AxiMaster -> AXI master
LSU request -> combinational CLINT ---/
              bypass/mux
              |
              `-> Clint.v
```

Only LSU data accesses can hit CLINT. The IFU path remains untouched.

## Frequency and latency guardrails

The bypass must not add cycles to normal non-CLINT data loads/stores.

For non-CLINT LSU requests, preserve the existing handshake shape:

```text
Lsu -> AxiArbiter -> AxiMaster -> response -> Lsu
```

Allowed extra logic on the normal LSU path:

- one cheap CLINT window compare, preferably `lsu_raw_addr[31:16] == 16'h0200`;
- `valid` gating into the arbiter;
- a 2:1 response mux for `ready`, `rdata`, and `error`.

Do not add:

- a new FSM;
- a registered request buffer;
- a registered response stage;
- an extra ready/valid handshake cycle;
- a full request address/data/mask mux for non-CLINT accesses;
- changes to `AxiArbiter.v` or `AxiMaster.v` unless only trivial warning cleanup is forced.

Normal non-CLINT request fields should pass through directly:

```text
lsu_arb_addr  = lsu_raw_addr
lsu_arb_wdata = lsu_raw_wdata
lsu_arb_wmask = lsu_raw_wmask
lsu_arb_write = lsu_raw_write
```

Steering rule:

```text
lsu_is_clint = lsu_raw_valid && (lsu_raw_addr[31:16] == 16'h0200)

lsu_arb_valid = lsu_raw_valid && !lsu_is_clint
clint_valid   = lsu_raw_valid &&  lsu_is_clint

lsu_raw_ready = lsu_is_clint ? clint_ready : lsu_arb_ready
lsu_raw_rdata = lsu_is_clint ? clint_rdata : lsu_arb_rdata
lsu_raw_error = lsu_is_clint ? clint_error : lsu_arb_error
```

This can add small combinational delay to the LSU path, but it should not materially hurt frequency. If a later timing flow shows the compare/mux on the critical path, optimize the local decode/mux before reconsidering topology. Position 3 is not expected to improve frequency because it places decode on the shared IFU/LSU path.

## Required CLINT behavior

Follow `specs/core.md` where it is more specific, with `specs/clint.rst` offsets:

- CLINT window: default `0x02000000..0x0200ffff`.
- `mtime` low word: `0x0200bff8`.
- `mtimeh` high word: `0x0200bffc`.
- `mtime` is 64-bit and increments by 1 every non-reset core clock cycle.
- No interrupt behavior.
- `msip`, `mtimecmp`, and `mtimecmph` accesses complete with no error and no effect.
- Ignored-register read content is undefined; this implementation may return zero.

## Implementation steps

1. Add a small `Clint.v` RTL module, probably under `npc/rtl/core/` or `npc/rtl/bus/`.
   - Non-AXI local interface: `valid`, `write`, `addr`, `wdata`, `wmask`, `ready`, `rdata`, `error`.
   - `mtime` resets to zero and increments once per non-reset `posedge clock`.
   - Reads of `mtime`/`mtimeh` return the corresponding 32-bit word.
   - Other CLINT-window reads return zero with no error.
   - Writes complete with no error and no state change.

2. Insert the combinational LSU-side CLINT bypass in `npc/rtl/core/Core.v`.
   - Split current LSU bus wires into raw LSU outputs and arbiter-facing LSU wires.
   - Route CLINT-window LSU requests to `Clint.v`.
   - Suppress arbiter LSU valid for CLINT requests.
   - Return CLINT response to LSU for CLINT requests; return arbiter response otherwise.
   - Leave IFU, `AxiArbiter.v`, and `AxiMaster.v` unchanged.

3. Add committed load metadata for DiffTest replay.
   - Extend `Core.v` and `NPC.v` with `commit_mem_ren` and `commit_mem_rdata`.
   - Drive `commit_mem_ren` for retired loads and `commit_mem_rdata` from `lsu_rdata`.
   - In `npc/csrc/main.cpp`, synthesize CLINT MMIO replay records from committed RTL load data, not from C++ `Memory::time_`.
   - Preserve existing UART MMIO replay and CLINT write replay behavior.

4. Keep C++ CLINT support only as fallback/debug.
   - `npc/csrc/memory.cpp` can keep accepting CLINT addresses for compatibility/debug.
   - Normal CPU CLINT accesses should no longer reach DPI memory.
   - If `Memory::time_` remains visible through debug paths, set it from cycles rather than retired instruction count to avoid misleading output.

5. Add focused directed CLINT tests.
   - Add `make -C npc test-clint`.
   - Test that `mtime` increases, robust `mtimeh/mtime/mtimeh` reads work, and writes to ignored CLINT registers do not fault.
   - Do not overfit tests to exact `mtime` values unless intentionally checking current single-cycle timing.

## Validation checklist

Run at least:

```sh
make -C npc
make -C npc test-clint
make -C npc test-lw-sw test-axi-local test-mem-size
make -C npc test-access-fault test-difftest
```

Then run workload validation from `notes/next.md`:

- NPC AM timer/devscan smoke.
- NPC RT-Thread with DiffTest.
- 35-test `cpu-tests` sweep if commit/replay changes create broad risk.

Existing exact-cycle tests are important: if normal non-CLINT load/store gains an extra cycle, tests such as `test-lw-sw`, `test-axi-local`, `test-mem-size`, or `test-difftest` should fail their current cycle-count greps.

## Acceptance criteria

- CLINT is physical RTL, not defined by C++ `Memory::time_`.
- `mtime` increments by core cycles.
- Normal non-CLINT loads/stores do not gain an extra cycle.
- IFU path is untouched.
- `AxiArbiter.v` and `AxiMaster.v` behavior remains unchanged.
- CLINT data accesses do not go to external AXI/local DPI memory.
- DiffTest remains usable with CLINT MMIO read values replayed from the DUT RTL result.
