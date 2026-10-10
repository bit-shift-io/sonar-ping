Status: pending
Complexity: medium

# Subs move under orders; debug view shows true state

## What to build
- A `subs` pool: player sub and one enemy sub spawned from the level table. Hulls are multi-cell shapes.
- Course orders (heading, dive angle, speed setting) drive each sub through the sim; subs stop at rock and the surface.
- The debug view draws true hull cells over the map, toggled by a key. For now the app executes continuously with each sub's level-defined starting order.

## Files to create/modify
- `src/sim/{bodies,integrate,collide}.lua`
- `src/game/pools.lua`, `src/game/systems/sub_system.lua`, `src/game/components/{helm,hull}.lua`
- `src/game/orders.lua` — order shapes and validation
- `src/game/match.lua` — `Match.step` frame order, despawn sweep
- `src/app/render/debug.lua`, `src/app/input.lua`
- `tests/unit/{helm_test,hull_raster_test,collide_test,match_step_test}.lua`

## Test approach
- Unit: a course order turns the sub towards the heading at the configured turn rate; speed settings map to config speeds.
- Unit: hull rasterises to the expected cells at angles 0, 45 and 90 degrees.
- Unit: a sub driving into rock or the surface stops at the boundary.

## Acceptance criteria
- [ ] Both subs move per their starting orders.
- [ ] Debug key toggles the true-state overlay.
- [ ] Speed settings are stop, slow, half, full, each with a noise level in config.

## Blocked by
01

## Gotchas
- The enemy sub stays idle (no AI) until slice 08.
- Store the speed setting's noise level on the sub now; slice 04 reads it.
