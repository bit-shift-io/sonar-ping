Status: pending
Complexity: medium

# Turn timeline for timed orders

## What to build
- A timeline strip in the plan phase shows the turn's seconds.
- The player places pings and course changes at chosen ticks; the ghost path shows the course change and where the sub will be at each order.
- Orders execute at their scheduled tick.

## Files to create/modify
- `src/game/turn.lua` — scheduled order queue, tick dispatch
- `src/game/predict.lua` — multi-segment projection
- `src/app/render/timeline.lua`, `src/app/states/plan_state.lua`
- `tests/unit/{order_schedule_test,predict_test}.lua`
- `tests/integration/timeline_test.lua`

## Test approach
- Unit: an order at tick t applies at tick t exactly, not t±1.
- Unit: multi-segment projection matches the sim.
- Integration: place a ping at 6 s via fake input; the ping origin matches the projected position.

## Acceptance criteria
- [ ] Orders can be placed, moved and deleted on the timeline.
- [ ] Ghost path shows a marker at each scheduled order.
- [ ] Order log records scheduled ticks; determinism test still passes.

## Blocked by
05
