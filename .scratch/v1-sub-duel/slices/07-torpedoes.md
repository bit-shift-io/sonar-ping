Status: done
Complexity: high

# Torpedoes, sinking and match end

## What to build
- Two tubes per sub with reload. The player picks a tube, drags a launch angle, picks a speed, and drags a fuse marker along a straight-line preview; launch is scheduled on the timeline.
- Torpedoes run straight, emit noise, and detonate at fuse, rock or hull contact. Subs within blast radius sink.
- The match ends with a win or loss screen when a side has no subs left.

## Files to create/modify
- `src/game/components/tube.lua`, `src/game/systems/torpedo_system.lua`, `src/game/blast.lua`
- `src/game/pools.lua`, `src/game/match.lua` — torpedoes pool, round rules
- `src/game/predict.lua` — torpedo path and fuse point
- `src/app/render/{torpedo_plan,sonar_view,debug,match_end}.lua`
- `tests/unit/{tube_test,torpedo_test,blast_test,round_rules_test}.lua`
- `tests/integration/torpedo_hit_test.lua`

## Test approach
- Unit: fuse detonates at exactly launch tick + fuse ticks.
- Unit: rock contact detonates early.
- Unit: blast sinks subs inside radius, spares those outside.
- Unit: a tube cannot fire while reloading.
- Integration: a scripted launch at the idle enemy sinks it and ends the match.

## Acceptance criteria
- [ ] Torpedo preview matches the actual run and fuse point.
- [ ] Torpedoes appear on passive perception for both observers.
- [ ] Debug view draws true torpedo paths.
- [ ] Win and loss both reachable.

## Blocked by
06

## Gotchas
- The firing sub is inside blast range at launch; arm the torpedo after a configured minimum distance.
- Launch and detonation are loud emissions; give them their own noise levels in config.
