Status: pending
Complexity: high

# Plan/execute turn loop with course planning

## What to build
- A match alternates plan phase (paused) and execute phase (configured ticks, default 720).
- In the plan phase the player drags a heading handle from their sub (heading + dive angle) and picks a speed; a ghost path shows the projected course with a tick per second.
- An "Execute" control commits orders. The match records every order with its turn and tick.

## Files to create/modify
- `src/game/turn.lua` — phase state, tick counter, order queue per slot
- `src/game/order_log.lua`
- `src/game/predict.lua` — projected sub path, pure function of sub state + orders
- `src/app/states/plan_state.lua`, `src/app/states/execute_state.lua`
- `src/app/render/plan_overlay.lua`
- `tests/unit/{turn_test,predict_test}.lua`, `tests/unit/determinism_test.lua`
- `tests/integration/turn_cycle_test.lua`

## Test approach
- Unit: execute runs exactly N ticks, then returns to plan.
- Unit: projected path matches the sim's actual path for the same orders, including stopping at rock.
- Unit: determinism — run a match twice from seed + order log; true state is identical every tick.
- Integration: drive two turns with fake mouse input.

## Acceptance criteria
- [ ] No ticks advance during the plan phase.
- [ ] The ghost path matches where the sub actually goes.
- [ ] Turn length comes from config.
- [ ] Determinism test passes and is in the unit run list.

## Blocked by
02

## Gotchas
- `predict.lua` must reuse the sim's helm and collision functions, not reimplement them, or the preview drifts.
- Remove slice 02's continuous-execute stopgap.
