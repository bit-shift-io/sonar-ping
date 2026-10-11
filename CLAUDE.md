# Sonar Ping

Turn-based WW2 submarine duel on a side-view seabed cutaway, played by sound. LÖVE (11.5 and 12) + LuaJIT.

- Architecture and rules: `docs/ARCHITECTURE.md` — layers `core → sim → perception → game → app`; no `love.*` outside `src/app/`.
- Glossary: `docs/CONTEXT.md`
- Decisions: `docs/adr/`
- Repo memory: `docs/memory/README.md`

## Testing
- Unit tests: `sh test-unit.sh`. Run them freely.
- Integration tests: `sh test-integration.sh`. Headless harness (`tests/support/game_harness.lua`) driven by `FrameStepper`.
- e2e tests: `sh test-e2e.sh`. Opens a real LÖVE window per file and captures frames to `tests/screenshots/`. Needs `love` on PATH; run it with a timeout.
- All three: `sh test-all.sh` (skips e2e when `CI` is set).
- Run integration and e2e once at the end of a piece of work, not per step.
- Put new tests in the unit tier unless the behaviour needs the real harness. `src/core`, `src/sim`, `src/game` run under plain LuaJIT, so `Match.new` and `Match.step` work there.
- Unit and integration runners use fixed file lists. Register every new test file in `tests/unit/run.lua` or `tests/integration/run.lua`. e2e files are discovered automatically.

## Planning
- This project has no ClickUp card. Never ask about one and never offer to archive plans there.
