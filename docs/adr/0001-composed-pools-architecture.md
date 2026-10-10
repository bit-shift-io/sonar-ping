# ADR 0001: Composed pools architecture (from GRAV//TY)

**Status:** Accepted
**Date:** 2026-10-11

## Context
- Sonar Ping is a sibling of GRAV//TY (`~/Projects/gravity`), also LÖVE + LuaJIT.
- GRAV//TY's composed pools give a single visible frame order, headless tests, and no `love` mock.
- Sonar Ping needs determinism and headless AI, which that structure already supports.

## Decision
- Copy GRAV//TY's architecture: layers with downward-only dependencies, typed pools, plain-data components called by pool systems, one `Match.step` frame order, a single despawn sweep, `config.lua`, fixed 1/60 s step.
- Add one layer, `perception`, between `sim` and `game`: `core → sim → perception → game → app`.
- Only `src/app/` touches `love.*`.

## Alternatives Considered
- **Object-oriented entities** — hides frame order; needs a `love` mock to test.
- **Full ECS library** — indirection without benefit at under 50 entities.

## Consequences
- Conventions, test tiers and compat code port directly from GRAV//TY.
- `sim`, `perception` and `game` run under plain LuaJIT.
- Optional components need nil checks in the owning system.
