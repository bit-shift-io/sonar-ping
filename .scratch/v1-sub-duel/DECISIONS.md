# Decisions: v1 Sub Duel

### Q1: Engine and language
**Decision:** LÖVE + LuaJIT, same as GRAV//TY.
- **Why:** User's current stack; delay maths is event-based, not per-pixel simulation, so Lua is fast enough.
- **Implication:** Reuse gravity's layout, test tiers, compat layer.
- **Alternatives considered:** TypeScript + canvas; Godot. Rejected — no performance need, user knows LÖVE.

### Q2: View
**Decision:** Side-view ocean cutaway, whole map on one screen (~1280×720).
- **Why:** User's vision; depth is a real tactical axis for subs.
- **Implication:** Surface is the top edge, seabed the bottom. No camera scrolling in v1.

### Q3: Sensing modes
**Decision:** Passive always on; active ping is a player order.
- **Why:** Pinging must cost something — it reveals your position to everyone who hears it.
- **Implication:** Passive shows noisy cells only, range-smeared. Ping shows every struck solid cell sharply.

### Q4: World representation
**Decision:** Grid world (~320×180 cells, 4 px). Hulls occupy many cells.
- **Why:** User rejected dot contacts as too abstract. Multi-cell shapes give recognisable silhouettes.
- **Implication:** Moving hulls appear distorted (stern is older than bow). Kept as a feature — it encodes speed and heading.

### Q5: How sound reaches the observer
**Decision:** Emission events + arrival check, not literal packets stepping cell to cell.
- **Why:** Same on-screen result as packets, exact, and cheap.
- **Implication:** Noisy cells emit every tick; ping-struck cells emit once. A cell is perceived when `|cell − observer| ≈ c·(now − emitTick)` and line of sight is clear of rock.
- **Alternatives considered:** Full-grid snapshot history per tick (memory heavy); FDTD wave sim (messy, hard to read). Literal packets can be drawn later as decoration.

### Q6: Debug view
**Decision:** A key toggles a true-state overlay on top of the player view.
- **Why:** User needs to see where things really are while building and tuning.
- **Implication:** Debug is the only renderer allowed to read true state.

### Q7: Era and weapons
**Decision:** WW2. Torpedoes are unguided: angle, speed, fuse timer, blast radius. Two tubes with reload.
- **Why:** Setting before launch is the main fun and challenge.
- **Implication:** No wire guidance, no homing, ever, in this era.

### Q8: Enemies
**Decision:** Enemy subs only, hunting you the same way. 1v1 in v1, count configurable.
- **Why:** Symmetric duel; future multiplayer is sub vs sub.
- **Alternatives considered:** Convoy + destroyer escort. Rejected by user for now.

### Q9: Turn structure
**Decision:** Plan-then-execute. Planning is paused; execute runs a configurable 10–15 s.
- **Why:** Matches future hot-seat play; hardest part to retrofit; suits a deliberate pace.
- **Alternatives considered:** Real-time with pause. Rejected — turn loop would be a later rewrite.

### Q10: Planning UI
**Decision:** Mouse, on-map handles, plus a turn timeline for timed orders.
- **Why:** Placing a launch at a chosen second is a key skill.
- **Implication:** Previews: projected sub path with per-second ticks; torpedo line with fuse marker. Perception is frozen during planning.

### Q11: Multiplayer foundations
**Decision:** Per-observer perception, deterministic sim, orders as the only input — all from slice 1.
- **Why:** Hot-seat and online both need them; cheap now, expensive later.
- **Implication:** Order log + seed reproduces a match. Online lockstep needs only orders.

## Defaults chosen without asking (all in `config.lua`)
- Speed of sound tuned so crossing the map takes ~5–6 s.
- Turn length 12 s (720 ticks).
- One hit within blast radius sinks.
- Two tubes, reload in ticks.
- Green phosphor monochrome look; debug overlay in a contrasting colour.
- Passive range smear grows with distance; deterministic, seeded.
- Only boundary rock cells (rock adjacent to water) reflect pings.
- Sub hulls do not block line of sight in v1; rock does.

## Assumptions
- Echo timing uses the observer's position at arrival, not at ping time.
- A sub hears its own ping and its own wake as noise.
- A sub hears another sub's ping directly: exact bearing and origin, delayed.

## Trade-offs
- Straight-line sound with rock occlusion: readable over realistic.
- Sparse dynamic history (moving cells only) over full grid snapshots: less memory, slightly more bookkeeping.

## New CONTEXT.md terms
- True state, Perception, Observer, Emission, Arrival, Contact, Passive, Ping, Echo, Smear, Wavefront, Turn, Plan phase, Execute phase, Order, Timeline, Tube, Fuse, Blast radius, Debug view, Cell, Hull.
