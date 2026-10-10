# Sonar Ping v1: Sub Duel

## Problem
- Sub games show the world instantly, so "where is the enemy now?" is never a real question.
- Real sonar is slow: sound takes seconds to cross the water, so every contact is out of date.
- No game makes predicting an intercept from stale, partial information the core skill.

## Solution
- A side-view ocean cutaway where each sub sees only sound that has physically reached it.
- Passive listening shows delayed, range-smeared noise; an active ping shows sharp but instantly ageing echoes.
- Plan-then-execute turns: set course, pings and unguided WW2 torpedoes, then watch 10–15 s play out against an AI sub.

## Out of Scope
- Multiplayer (hot-seat, online). v1 only lays the foundations: per-observer perception, deterministic order-driven sim.
- Surface ships, convoys, depth charges.
- Torpedo guidance or homing. Depth settings beyond launch angle.
- Damage systems. One hit sinks.
- Campaign, multiple maps, menus beyond what a single match needs.
- Gamepad input. Audio.
- Wave physics (diffraction, multipath). Sound travels in straight lines, blocked by rock.

## Cross-cutting Constraints
- Architecture copies GRAV//TY (`~/Projects/gravity`): layers, composed pools, `Match.step` frame order, despawn sweep, `config.lua`, three test tiers. See [ADR 0001](../../docs/adr/0001-composed-pools-architecture.md).
- Only `src/app/` touches `love.*`. Must run on LÖVE 11.5 and 12.
- **The player render reads perception only.** Only the debug view reads true state. See [ADR 0002](../../docs/adr/0002-per-observer-perception.md).
- **Perception is per observer.** Never build a player-only path; the AI uses the same perception.
- **AI decides from its own perception only.** It never reads true state.
- **Deterministic sim.** Same seed + same orders → identical result. Seeded RNG only; no `math.random`, no wall-clock, no `pairs()` order dependence in sim/game/perception. See [ADR 0003](../../docs/adr/0003-deterministic-order-driven-turns.md).
- Humans and AI both act through orders. Nothing in `game` knows which kind filled a slot.
- Fixed timestep 1/60 s. Turn time is counted in ticks, not seconds.
- All tuning numbers in `src/game/config.lua`.
- Sim, perception and game run under plain LuaJIT with no `love` global.

## Acceptance Criteria
- [ ] Launch the game; a 1v1 match starts against an AI sub on a hand-made seabed map.
- [ ] Planning: set heading, dive angle, speed, timed pings and timed torpedo launches with fuse; previews show projected paths.
- [ ] Execute plays one turn, then returns to planning.
- [ ] The player view shows only delayed passive noise and ping echoes; hulls render as multi-cell shapes, distorted by delay when moving.
- [ ] A debug key overlays true positions, wavefronts and torpedo paths.
- [ ] The AI hears pings and noise with the same delay, closes in, pings, and fires predicted shots.
- [ ] A torpedo detonating within blast radius sinks a sub; the match ends with win or loss.
- [ ] Replaying a match from seed + recorded orders yields identical outcomes (verified by test).
- [ ] Last-turn replay scrubs through the player's own perception.

## References
- Glossary: [docs/CONTEXT.md](../../docs/CONTEXT.md)
- ADRs: [0001](../../docs/adr/0001-composed-pools-architecture.md), [0002](../../docs/adr/0002-per-observer-perception.md), [0003](../../docs/adr/0003-deterministic-order-driven-turns.md)
- Reference project: `~/Projects/gravity` (`docs/ARCHITECTURE.md`, `tests/`, `src/app/compat.lua`)
