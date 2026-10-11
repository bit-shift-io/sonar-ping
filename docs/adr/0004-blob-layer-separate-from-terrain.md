# ADR 0004: Blobs live in a per-tick layer, not the terrain grid

**Status:** Accepted
**Date:** 2026-10-11

## Context
- Drifting blobs add moving cover: solid blobs block movement and sound; soft cover muffles passive sound.
- Terrain lives in the static level grid (ADR 0002). Line of sight, collision and boundary echo cells all read it.
- `Match.aiView` hands the AI that grid as "the map it knows". The player knows the map only through sonar.

## Decision
- Blobs are entities in their own pool, stepped each tick.
- Each tick they rasterise into a separate blob layer (solid and soft cells), not into the grid.
- Collision, line of sight and ping strikes consult the grid and the blob layer. The AI view gets the grid only.
- Blobs are perceived only through sound: shadows, muffling and echoes.

## Alternatives Considered
- **Write blobs into the grid each tick** — least code, but the AI would read true blob positions through its map, breaking ADR 0002. Boundary rock cells would also need rebuilding every tick.
- **Treat blobs as part of the known map** — no cover value, and the player would need terrain drawn from truth.

## Consequences
- Every line-of-sight and collision check takes a second source. New checks must remember both.
- The grid stays static, so `ctx.boundaryCells` is still built once.
- Plan-phase predictions (`Predict`, course solve) ignore blobs, like the player does.
- A solid blob's echo looks exactly like a hull echo, so the AI may hunt blobs.
