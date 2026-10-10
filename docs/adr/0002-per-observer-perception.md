# ADR 0002: Per-observer perception from emissions and arrivals

**Status:** Accepted
**Date:** 2026-10-11

## Context
- The game's premise: each sub sees only sound that has physically reached it.
- Hulls are multi-cell shapes on a grid, not dot contacts.
- The AI must play fair, and future hot-seat/online play needs a view per player.

## Decision
- Every sub is an observer with its own perception. No player-only path.
- Sound is modelled as **emissions** (cell, tick) and **arrivals** at an observer, not packets stepping through cells.
  - Noisy cells emit every tick. Ping-struck cells emit once.
  - Arrival when `|cell − observer| ≈ c × (now − emitTick)` and line of sight is clear of rock.
- History keeps only dynamic emissions for the longest map-crossing time. Terrain is static and lives in the level grid.
- The player render and the AI read perception only. Only the debug view reads true state.

## Alternatives Considered
- **Literal sound packets moving cell to cell** — same result, far more objects. Can be drawn later as decoration.
- **Full-grid snapshot per tick** — tens of MB of history; most cells never change.
- **FDTD wave simulation** — physically richer, but echoes are hard to read and hard to test.
- **Single player perception, AI reads truth** — cheaper now, but unfair AI and a rewrite for multiplayer.

## Consequences
- Moving hulls appear distorted by delay. This is intended.
- Perception cost scales with emissions × observers, not grid size.
- A leak of true state into the player render or AI is a bug class. Enforced by module boundaries and tests.
