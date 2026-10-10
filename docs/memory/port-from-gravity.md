---
name: port-from-gravity
description: Scaffold, test tiers and compat layer are ported from ~/Projects/gravity; keep the structure, strip gravity-specific game code
metadata:
  type: reference
---

Sonar Ping copies GRAV//TY's structure from `/Users/fabian/Projects/gravity`.

**How to apply:**
- Copy: `main.lua`, `conf.lua`, `run.sh`, `test-*.sh`, `tests/{unit,integration,e2e}/run.lua`, `tests/support/*`, `src/app/compat.lua`, `src/app/screen.lua`, `src/core/{vec2,rng,angle}.lua`, `.vscode/launch.json`.
- Read first: gravity's `docs/ARCHITECTURE.md` and `tests/README.md`.
- Strip: gravity field, worlds, ships, asteroids, roster, menus, post pipeline, Steam and trailer tooling.
- `GameHarness.startMatch(levelTable, opts)` keeps its shape; levels are literal tables in tests.
