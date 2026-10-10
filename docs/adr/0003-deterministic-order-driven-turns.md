# ADR 0003: Deterministic, order-driven plan/execute turns

**Status:** Accepted
**Date:** 2026-10-11

## Context
- Future multiplayer: hot-seat (each player plans in turn) and online.
- The core skill is planning shots from stale information, which suits a paused planning phase.

## Decision
- Turns: a paused plan phase, then an execute phase of a fixed tick count.
- **Orders** (course, speed, ping, torpedo launch), each scheduled at a tick within the turn, are the only input to the sim.
- Humans and AI produce orders through the same interface.
- The sim is deterministic: seeded RNG, fixed timestep, no wall-clock, no iteration-order dependence.
- A match is reproducible from seed + order log.

## Alternatives Considered
- **Real-time with pause** — simpler first build; turn loop and determinism retrofitted later at high cost.
- **Per-frame intents (GRAV//TY style)** — fine for real-time; turns need scheduled orders.

## Consequences
- Online play can lockstep on orders alone. Replays and regression tests come free.
- Every new sim feature must stay deterministic; a determinism test guards it.
- No mid-turn reaction. Players plan around that.
