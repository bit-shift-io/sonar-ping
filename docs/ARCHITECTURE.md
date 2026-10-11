# Sonar Ping Architecture

Sonar Ping uses **composed pools**, copied from GRAV//TY: typed entity pools, plain-data components, and one visible frame order.
See [ADR 0001](adr/0001-composed-pools-architecture.md) for why, [ADR 0002](adr/0002-per-observer-perception.md) for perception and [ADR 0003](adr/0003-deterministic-order-driven-turns.md) for turns and determinism.
Terms are defined in [CONTEXT.md](CONTEXT.md).

## Layers

`core → sim → perception → game → app`. Dependencies point down only: a module never requires a module from a layer above it.

| Layer | Path | Owns | May use `love.*` |
|---|---|---|---|
| app | `src/app/` | LÖVE callbacks, screen fit, input mapping, rendering, debug view, LÖVE 11/12 compat | **Yes — the only layer that may** |
| game | `src/game/` | Pools, systems, components, match and turn rules, orders, AI, levels, tuning config | No |
| perception | `src/perception/` | Per-observer emissions, arrivals, contacts and history | No |
| sim | `src/sim/` | World grid (cells, materials), hull rasterisation, sound propagation maths, collision | No |
| core | `src/core/` | vec2, angle, seeded RNG | No |

- `sim` knows nothing about pools, subs or rules.
- `game` and below run under plain LuaJIT with no `love` global. Unit tests exercise them without a mock.
- `perception` requires only `sim` (the grid for line of sight). It knows nothing about pools, subs or config; `Match` hands it plain numbers.

## Rules

- **Player render reads perception only.** The AI reads perception only. Only the debug view reads true state (ADR 0002).
- Perception is per observer. There is no player-only path; the AI uses the same perception as a human.
- Humans and AI act through orders only (ADR 0003).
- Deterministic sim: seeded RNG from `src/core/rng.lua`, no `math.random`, no wall-clock, no `pairs()` order dependence in `sim`, `perception` and `game`.
- Fixed timestep 1/60 s; turn time is counted in ticks.
- All tuning numbers live in `src/game/config.lua`.
- Only `src/app/` touches `love.*`. Version-sensitive calls go through `src/app/compat.lua` (LÖVE 11.5 and 12).
- Levels are literal tables (`src/game/levels/`). Tests pass literal level tables, never file paths.

## The world grid

- `src/sim/grid.lua`: a fixed `width × height` array of cells, each `WATER`, `ROCK` or `HULL`. Cells are 1-based, y points down, row 1 is the surface.
- `Grid.worldToCell` / `Grid.cellToWorld` convert between world pixels and cells. `Grid.isBoundaryRock` marks rock with a water neighbour (the only rock that echoes).
- `Level.buildGrid(level, config)` rasterises a level's seabed polyline into a grid.

## Match and frame order

- `Match.new(level, config, seed, opts)` returns `ctx`: `level`, `config`, `grid`, `rng`, `bodies`, `pools`, `tick`, `time`, `turn`, `sides`, `ai`. It spawns the player from `level.subs.player` and `config.match.enemies` enemies in slots `"enemy"`, `"enemy2"`, … (the first from `level.subs.enemy`, then `level.extraEnemies` in order, then the enemy spawn moved up). The round rules count two sides: `"player"` and `"enemy"` (every enemy slot).
- Every enemy slot is filled by the AI unless `opts.ai == false` (scripted tests and replays submit for every slot themselves). The AI submits through `Turn.submit` at the start of every plan phase (in `Match.new` and after `Turn.endTick`), so a human committing their own slot starts the turn; the app never knows which slots are AI.
- `Match.step(ctx)` is the whole frame order in one function: tick, `Turn.beginTick` (due orders reach helms), `SubSystem.update` (helms set body turn and speed), `Integrate.step`, `Collide.resolve` (a move into rock or out of the water is undone), `SubSystem.refreshHulls` and `TorpedoSystem.refreshHulls`, **torpedoes** (`TorpedoSystem.update`: torpedoes in the water arm, then end their run on rock, at their fuse or, armed only, on a sub's hull; an armed one detonates through `Blast.detonate`, sinking every sub within the blast radius; then `TorpedoSystem.launch`: tubes reload a tick and launch orders due this tick fire from loaded tubes at the sub's resolved pose), **pings** (pings ordered this tick fire from the pinger's centre into `ctx.pings` and record a `"ping"` origin emission; every active wavefront records an `"echo"` emission for each boundary rock or hull cell it strikes this tick; spent pings are dropped), **record emissions** (every noisy cell into `ctx.emissions`), **step perceptions** (each sub's `sub.perception` hears what arrives this tick; then each AI slot's `Ai.listen` reads what its sub just heard), the **despawn sweep** (`Pools.sweep` before `Bodies.sweep`; the only place records are removed; systems mark records `dead = true`), then the **round rules** (a side with no sub left ends the match: `ctx.result = { tick, winner, draw }`, turn phase `"over"`; both sides sinking on the same tick is a draw), then `Turn.endTick` unless the match ended. Later slices add more systems.

## Torpedoes

- A torpedo order (`Orders.torpedo(tube, angle, speed, fuse)`) is a scheduled entry like any other; `Turn.beginTick` adds it to `sub.launches`. Each sub has `config.tubes.count` tubes (`src/game/components/tube.lua`); tube 1 faces the bow and tube 2 the stern (`config.tubes.facing`, relative to the sub's heading). A tube that fires reloads for `config.tubes.reloadTicks` execute ticks, and a launch from an empty tube does nothing.
- A torpedo (`ctx.pools.torpedoes`) is a body with a multi-cell hull launched from its tube's end of the hull (`TorpedoSystem.launchPose`), pointing along the sub's axis that way. Each tick it turns at most `config.torpedo.turnRate` towards the order's angle (`TorpedoSystem.steer`, which also points the velocity along the new angle, since `Integrate.step` moves by `vx, vy` only), then runs straight at its speed setting. It arms once `config.torpedo.armDistance` from its launch point (the tube's end, so the firing sub is behind it); before that it ignores hulls and a fuse or rock contact makes it a dud (no blast), so the firing sub is never inside its own blast.
- Rock contact uses `Collide.resolve`: the blocked move is undone and the torpedo detonates at its last pose in the water. The surface counts as solid.
- Torpedoes are noisy (every hull cell, at the speed setting's level), and launch (`launchNoise`, kind `"noise"`) and detonation (`blastNoise`, kind `"blast"`) are one-off emissions. Torpedo hulls echo pings.
- `Predict.torpedo(world, pose, order)` (world: anything with `config` and `grid`, e.g. ctx; pose: the launching sub's `{ x, y, angle }` at the launch tick) previews a launch with the torpedo system's own functions on a private body store, turn included; the plan screen draws the curve (`src/app/render/torpedo_plan.lua`).
- Aiming is the inverse: `Predict.aim(world, tube, pose, tx, ty, speed)` solves the angle whose run (turn, then straight) passes through a point by `config.torpedo.aimSteps` fixed-point steps (the angle is the bearing of the point from where the turn ends), with the fuse at the run's nearest tick; a point the run cannot reach (inside the turning circle, or beyond max run) clamps to that nearest point. `src/game/torpedo_aim.lua` picks fast when the fast run reaches the point, else slow, for the plan screen's aim drag.
- `ctx` is one table passed to every system and component function. No module reads globals for game state.

## AI

- `src/game/ai/ai.lua` is a producer of orders for a slot. It reads only `Match.aiView(ctx, sub)`: its own perception, its own ship (centre in cell units, body pose, helm and tube reloads, all copies), the static grid (it knows the map), config and the clock (`tick`, `turnLength`). Never pools, other bodies, pings, blasts or emissions; `tests/unit/ai_isolation_test.lua` checks its requires and runs it through a view that errors on any other field.
- `Ai.listen(brain, view)` runs every execute tick: it drops its own sounds (within `config.ai.selfRadius`, or on the run of its own torpedoes), terrain echoes (echo contacts in rock cells) and blasts, and turns the rest into emit-time samples (`src/game/ai/track.lua`; noise averaged per arrival tick, pings and hull echoes weighted higher). A noise contact at `launchNoise` or louder is a launch.
- `Ai.plan(brain, view)` runs each plan phase: evade a heard launch, else close on the fitted course (`Track.fit`, least squares, extrapolated a bounded time), else search when lying stopped; ping when nothing has been heard for `staleTicks`; fire at turn tick 1 from the tube facing the target (`FireSolution.tubeFor`; the other if that one is reloading), fast if the led shot (`FireSolution.lead`: fuse and aim point iterated through `Predict.aim`) reaches the target's predicted course, else slow, when its run is clear of rock (`Predict.torpedo`). Courses are checked against the map with `Predict.pathFrom` (own body and helm only) and steered or stopped short of rock.
- AI randomness comes from its own `Rng`, seeded from the match seed and the slot index, never `ctx.rng`. Its orders are logged like a human's, so seed + order log replays a match with the AI switched off.

## Perception

- `src/perception/emissions.lua`: a ring of per-tick buckets (`{ tick, cx, cy, kind, level }` arrays) long enough for sound to cross the grid's diagonal; old ticks are overwritten in place. Only noisy cells, ping origins and ping-struck cells are recorded.
- `src/perception/arrival.lua`: an emission arrives on the tick the wavefront radius `c × elapsed` passes the observer's position at arrival (exactly once, never before `d / c`), if the Bresenham line to the observer is free of rock.
- `src/perception/smear.lua`: a hash of (seed, emit tick, cell) gives each emission a fixed range offset within `± smear × distance`.
- `src/perception/perception.lua`: one per sub (`sub.perception`). Contacts hold only the perceived position (exact bearing, smeared range), arrival tick, kind and level; they are forgotten after `fadeTicks`. `Match.perceptionOf(ctx, slot)` finds one.
- `src/perception/ping.lua`: a ping is a wavefront of radius `c × (now − pingTick)` from its origin. `Ping.strike` returns the cells the wavefront crosses this tick (the arrival test, so the shell is `(r − c, r]` and each cell is struck once; a moving hull is struck where it was) with a clear line of sight. Candidates are the level's boundary rock cells (`ctx.boundaryCells`, built once in `Match.new`) and every other sub's hull (`SubSystem.echoCells`, with continuous positions). The pinger's own hull does not echo.
- Echoes and ping origins are active returns: perceived at the cell itself (no smear) and forgotten after `echoFadeTicks`. An echo's line of sight runs to the middle of a face of the struck cell turned towards the observer (`Arrival.clearToFace`), so the solid cell and its neighbours along a grazing floor do not hide it.
- A ping order (`Orders.ping()`) is a scheduled `{ tick, order }` entry like any other; `Turn.beginTick` raises `sub.pingOrdered` and the ping fires in the pings step.
- Noisy cells are the aft `config.perception.noisyAft` of a moving sub's hull (`SubSystem.noisyCells`); a stopped sub is silent. A sub hears its own noise.
- Positions in perception are cell units: cell `(cx, cy)` has its centre at `(cx, cy)`; world px = `(u − 0.5) × cellSize`.

## Rendering

- The player's screen is `src/app/render/sonar_view.lua`, drawn from the player's perception only (a unit test checks its requires). Terrain is not drawn from truth.
- Passive contacts glow with a halo; echoes are sharp single cells; a heard ping origin is a small cross. All fade with age.
- A heard detonation (`"blast"`) is drawn as a ring.
- When the match ends, the execute screen shows `src/app/render/match_end.lua` (it reads only `ctx.result`); R starts a new match.
- F3 adds the debug view (`src/app/render/debug.lua`) over it: true rock (`terrain.lua`, debug only), true sub and torpedo hulls, each torpedo's true path (run so far and on to its fuse point), recent blast radii and each active ping's wavefront, in colours that contrast with the green phosphor.

## Test tiers

| Tier | Command | Runs |
|---|---|---|
| unit | `sh test-unit.sh` | `src/core`, `src/sim`, `src/game` and pure app functions under plain LuaJIT |
| integration | `sh test-integration.sh` | `GameHarness.startMatch(levelTable, opts)` stepped with `FrameStepper`; no rendering |
| e2e | `sh test-e2e.sh` | Real LÖVE window and rendering; frame capture to `tests/screenshots/` |
