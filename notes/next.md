# Next Session

Current state:

- Created `notes/plan.md` from `notes/lecture-note-summary.md`, selected full lecture notes, and `specs/core.md`.
- The plan scopes the project around a maintainable RV32E_Zicsr core, NEMU/AM validation infrastructure, AXI integration, built-in CLINT, required icache, performance counters, and optional measured pipeline optimization.
- Important decisions in the plan:
  - Follow `specs/core.md` as the target spec.
  - Use lecture notes as guidance, not as a checklist of every educational exercise.
  - Skip optional PA/Navy/graphics/audio/full-OS work unless it directly supports required validation.
  - Prefer automated batch experiments and structured output over manual monitor interaction.
  - Do not optimize before measuring with counters.

Next work:

1. Inspect repository status and determine whether an `npc/` project already exists.
2. Inspect NEMU/AM build state and available toolchain.
3. Start Phase 1 or Phase 2 depending on current code readiness:
   - If NEMU/AM is incomplete, first make NEMU a usable automated REF.
   - If NEMU is already usable, start creating or validating the NPC Verilator harness.
4. Keep commands and results in notes as work proceeds.

Relevant files:

- `notes/plan.md`
- `notes/lecture-note-summary.md`
- `specs/core.md`
- Full notes read for planning:
  - `specs/lecture-notes/05_D阶段讲义/04_D4.md`
  - `specs/lecture-notes/05_D阶段讲义/05_D5.md`
  - `specs/lecture-notes/05_D阶段讲义/06_D6.md`
  - `specs/lecture-notes/02_C阶段讲义/02_C2.md`
  - `specs/lecture-notes/02_C阶段讲义/05_C5.md`
  - `specs/lecture-notes/03_B阶段讲义/01_B1.md`
  - `specs/lecture-notes/03_B阶段讲义/04_B4.md`
  - `specs/lecture-notes/03_B阶段讲义/05_B5.md`
