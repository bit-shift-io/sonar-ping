Status: pending
Complexity: high

# Active ping and echoes

## What to build
- A ping order (immediate, in plan phase) emits a wavefront from the sub at `c`.
- Boundary rock cells and hull cells the wavefront reaches with clear line of sight become one-off emissions; their echoes arrive at every observer and render sharp (no smear), fading with age.
- Every observer the ping reaches perceives its origin; debug view draws the wavefront.

## Files to create/modify
- `src/perception/ping.lua` — wavefront shell, struck-cell detection per tick
- `src/perception/emissions.lua` — one-off emission kind
- `src/game/orders.lua`, `src/game/systems/sub_system.lua` — ping order
- `src/app/render/{sonar_view,debug,plan_overlay}.lua`
- `tests/unit/ping_test.lua`, `tests/e2e/ping_view_test.lua`

## Test approach
- Unit: a rock cell at distance d echoes back at `2d / c` ticks for a stationary sub.
- Unit: a cell behind a ridge is never struck.
- Unit: a moving hull is struck where it was when the wavefront reached it.
- Unit: the enemy observer perceives the ping origin at `d / c`.

## Acceptance criteria
- [ ] Pinging reveals the seabed outline progressively as echoes return.
- [ ] The enemy hull appears as a sharp, ageing shape.
- [ ] Echoes fade over a configured time.

## Blocked by
04

## Gotchas
- Precompute the boundary-rock cell list once per level; do not scan the grid per tick.
- A shell is one tick thick in distance; use `[r_prev, r_now)` so no cell is struck twice or skipped.
