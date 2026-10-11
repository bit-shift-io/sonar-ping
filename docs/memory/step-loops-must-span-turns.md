---
name: step-loops-must-span-turns
description: Test loops that step a match must check Match.step's return and cross plan phases via tests/support/play.lua or FrameStepper.play, or they hang
metadata:
  type: convention
---

**Why:** `Match.step` returns false and advances nothing in the plan phase and after the match ends. A loop like `while ctx.tick < n do Match.step(ctx) end` spins forever once a scenario outlasts one turn, and a loop that ignores the return can pass silently on a partial run.

**How to apply:** Whenever a test steps a match for more ticks than one turn, or the turn length changes.

- Unit tier: use `Play.advance` / `Play.steps` / `Play.stepTo` / `Play.toPlan` from `tests/support/play.lua`. At a plan phase they submit `{}` for slots that have not submitted, then assert `Match.step` succeeded.
- Harness tiers: use `FrameStepper.play(game, ticks)`, which commits the unchanged plan at each plan phase. A bare `FrameStepper.step` stalls silently in a plan phase.
- Express scheduled ticks relative to `Config.turn.ticks` so turn-length tuning does not break scenarios.
