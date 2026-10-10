Status: pending
Complexity: high

# AI enemy sub

## What to build
- The AI fills its slot's orders each plan phase from its own perception only.
- Behaviour: listen; close on noise contacts; ping when contacts are stale; fire when a straight-line prediction of the target is inside torpedo range; evade after hearing a launch.
- Match setup takes an enemy count from config.

## Files to create/modify
- `src/game/ai/ai.lua`, `src/game/ai/track.lua` — contact tracking and velocity estimate from perceived positions
- `src/game/ai/fire_solution.lua` — intercept maths shared with nothing in truth
- `src/game/match.lua` — call AI in plan phase
- `tests/unit/{ai_track_test,fire_solution_test,ai_isolation_test}.lua`
- `tests/integration/ai_duel_test.lua`

## Test approach
- Unit: track estimates velocity from two delayed contacts.
- Unit: fire solution hits a constant-velocity target in a pure-maths check.
- Unit: AI isolation — the AI module receives only a perception and its own sub; a test asserts no true-state access.
- Integration: AI vs stationary noisy sub — AI closes in and sinks it within N turns (seeded).

## Acceptance criteria
- [ ] AI only acts through orders.
- [ ] AI reacts to the player's ping by closing on the ping origin.
- [ ] AI sinks a predictable target; misses are possible against an evading one.
- [ ] Determinism test passes with the AI active.

## Blocked by
07

## Gotchas
- AI randomness uses a seed-derived RNG, never `ctx.rng` draws that shift with entity counts.
