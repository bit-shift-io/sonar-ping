Status: done
Complexity: high

# Passive perception per observer

## What to build
- Every sub is an observer with its own perception. Noisy cells (propeller, engine; level from speed setting) emit every tick.
- Emissions arrive at an observer when `|cell − observer| ≈ c × elapsed` with rock-free line of sight. Arrivals become contacts with an age.
- The player render now draws only the player's perception: passive contacts as glowing cells smeared along the bearing, fading with age. Terrain is not drawn from truth any more; debug view still shows it.

## Files to create/modify
- `src/perception/emissions.lua` — sparse ring history of dynamic emissions
- `src/perception/arrival.lua` — arrival test, line of sight on grid
- `src/perception/perception.lua` — per-observer contact store
- `src/perception/smear.lua` — deterministic range smear
- `src/game/match.lua` — record emissions and step perceptions each tick
- `src/app/render/sonar_view.lua`; `src/app/render/terrain.lua` moves under debug
- `tests/unit/{arrival_test,emissions_test,perception_test,smear_test}.lua`
- `tests/e2e/passive_view_test.lua`

## Test approach
- Unit: an emission at distance d arrives exactly `d / c` ticks later; never earlier.
- Unit: rock between cell and observer blocks arrival.
- Unit: a moving observer receives using its position at arrival.
- Unit: a moving hull's perceived cells are offset by their individual delays (distortion test).
- Unit: two observers perceive the same emission at different ticks.
- Unit: smear is identical across runs with the same seed.

## Acceptance criteria
- [ ] Player view shows the enemy only as delayed, smeared noise.
- [ ] Stopped subs are silent.
- [ ] Debug view shows true hulls and terrain over the sonar view.
- [ ] The sonar view module requires nothing from true state (enforced by a unit test on its requires).

## Blocked by
03

## Gotchas
- Emission history must cover the longest diagonal crossing time, then drop old entries deterministically.
- Never iterate history with `pairs()`; use arrays.
- Per-tick cost scales with emissions × observers. Profile with 4 observers before moving on.
