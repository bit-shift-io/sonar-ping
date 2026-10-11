Status: done
Complexity: medium

# Scaffold and seabed map

## What to build
- A LÖVE project that boots to a 1280×720 resizable window showing the hand-made map as a side-view cutaway: surface at top, seabed at bottom.
- The layer structure, three test tiers and project docs, ported from `~/Projects/gravity`.
- The level grid: ~320×180 cells of water or rock, built from a literal level table (seabed polyline plus a ridge and a trench).

## Files to create/modify
- `main.lua`, `conf.lua`, `run.sh`, `test-unit.sh`, `test-integration.sh`, `test-e2e.sh`, `test-all.sh`, `.gitignore`, `.vscode/launch.json`
- `CLAUDE.md`, `docs/ARCHITECTURE.md`
- `src/core/{vec2,rng,angle}.lua`
- `src/sim/grid.lua` — cell storage, material lookup, world↔cell conversion, boundary-rock flag
- `src/game/{config,level,match}.lua`, `src/game/levels/trench.lua`
- `src/app/{main,compat,screen}.lua`, `src/app/render/terrain.lua`
- `tests/unit/run.lua`, `tests/integration/run.lua`, `tests/e2e/run.lua`, `tests/support/*`
- `tests/unit/grid_test.lua`, `tests/unit/level_test.lua`, `tests/e2e/map_render_test.lua`

## Test approach
- Unit: polyline → grid rasterisation; world↔cell round trip; boundary-rock detection (rock with a water neighbour).
- Unit: `Match.new(level)` runs under plain LuaJIT with no `love` global.
- e2e: capture a frame of the map.

## Acceptance criteria
- [ ] `./run.sh` shows the seabed cutaway, scaled to fit any window size.
- [ ] `sh test-unit.sh`, `sh test-integration.sh`, `sh test-e2e.sh` all run and pass.
- [ ] `docs/ARCHITECTURE.md` states layers `core → sim → perception → game → app` and the rule "player render reads perception only".
- [ ] `CLAUDE.md` links ARCHITECTURE, CONTEXT, ADRs and memory, and lists the test commands.

## Blocked by
None — can start immediately.

## Gotchas
- Read [port-from-gravity](../../../docs/memory/port-from-gravity.md) first. Copy, then strip; do not rewrite the test runners.
- Register every new unit/integration test in its `run.lua`.
- `CLAUDE.md` must say whether this project uses ClickUp cards; ask the user rather than guess.
