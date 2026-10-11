Status: done
Complexity: medium

# Last-turn replay scrubber

## What to build
- In the plan phase the player can scrub back through the last execute phase, seeing only their own perception at each tick.
- Planning resumes from the current frozen perception when the scrubber closes.

## Files to create/modify
- `src/perception/perception.lua` — expose contacts as of a past tick
- `src/app/render/replay.lua`, `src/app/states/plan_state.lua`
- `tests/unit/perception_at_tick_test.lua`
- `tests/e2e/replay_view_test.lua`

## Test approach
- Unit: perception at tick t contains exactly the contacts arrived by t, with ages relative to t.
- e2e: capture frames at the start, middle and end of a replay.

## Acceptance criteria
- [ ] Scrubbing never shows true state (debug view excepted).
- [ ] Scrubbing does not change the sim or perceptions.

## Blocked by
05
