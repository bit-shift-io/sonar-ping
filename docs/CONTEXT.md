# Glossary

Domain terms for Sonar Ping. Code, docs, and conversation use these words with these meanings only.

## True state
- **Definition:** Where everything actually is right now: subs, torpedoes, terrain.
- **Boundary:** Read by sim, game rules and the debug view. Never by the player render or the AI.

## Perception
- **Definition:** What one observer has sensed so far: arrived passive noise and ping echoes, with arrival times.
- **Boundary:** Always per observer. Built only from arrivals. Never copies true state directly.

## Observer
- **Definition:** A sub that owns a perception.
- **Boundary:** Every sub is an observer, human or AI. There is no special player perception.

## Cell
- **Definition:** One square of the world grid (~4 px). Material is water, rock or hull.
- **Boundary:** Grid is fixed for a match. Hulls rasterise into cells each tick.

## Hull
- **Definition:** The set of cells a sub or torpedo occupies at a tick.
- **Boundary:** Multi-cell. Perceived cell by cell, so a moving hull can look distorted.

## Emission
- **Definition:** A cell producing sound at a tick: noisy cells (engine, propeller, torpedo, ping origin) or a ping-struck cell.
- **Boundary:** Noisy cells emit every tick. Struck cells emit once, at the tick the wavefront reaches them.

## Arrival
- **Definition:** The tick an emission reaches an observer: distance from cell to observer equals `c × elapsed`, with rock-free line of sight.
- **Boundary:** Uses the observer's position at arrival, not at emission.

## Contact
- **Definition:** A perceived cell or group of cells, with its arrival tick and age.
- **Boundary:** A contact shows where something was, never where it is. It also records whether a torpedo produced it; nothing distinguishes a sub from rock.

## Passive
- **Definition:** Always-on listening. Perceives noisy emissions only.
- **Boundary:** Bearing is exact; range is smeared. Quiet hulls and terrain stay dark.

## Ping
- **Definition:** An active sonar pulse ordered by a sub. A wavefront expands from the origin at `c`.
- **Boundary:** Every observer that the ping reaches learns its origin. Not continuous.

## Echo
- **Definition:** The return from a ping-struck cell, perceived sharply (no smear).
- **Boundary:** Fades with age. Only boundary rock cells and hull cells produce echoes.

## Smear
- **Definition:** Range uncertainty on a passive contact, drawn along the bearing line.
- **Boundary:** Grows with distance. Deterministic per emission.

## Wavefront
- **Definition:** The expanding circle of a ping at radius `c × (now − pingTick)`.
- **Boundary:** Visible in the debug view only. The player sees echoes, not the wavefront.

## Turn
- **Definition:** One plan phase followed by one execute phase.
- **Boundary:** Execute length is fixed per match, in ticks.

## Plan phase
- **Definition:** Paused state where each side sets orders against its frozen perception.
- **Boundary:** No ticks advance.

## Execute phase
- **Definition:** The sim runs the turn's ticks, applying orders at their scheduled ticks.
- **Boundary:** No input accepted.

## Order
- **Definition:** An instruction from a slot: course, speed, ping, or torpedo launch, scheduled at a tick within the turn.
- **Boundary:** The only way humans and AI affect the sim. Recorded for replay.

## Timeline
- **Definition:** One strip from −5 s to +5 s. The left half is the last execute phase; the right half is this turn. Shown in the plan and execute phases.
- **Boundary:** UI only. Only right-half orders are editable, and only in the plan phase. The sim sees orders, not the timeline.

## Scrub cursor
- **Definition:** The tick the timeline points at. On the left half it shows the replay. On the right half it selects where edits apply and shows own sub, own torpedoes and marks projected to that tick.
- **Boundary:** Shows own-ship knowledge and marks only. Never moves the sim.

## Replay
- **Definition:** The left half of the timeline: the last execute phase, built from the player's perception alone. PLAY runs it on through 0 into the plan.
- **Boundary:** Read-only. Shows contacts and own-ship position as they stood at the replayed tick; never true state.

## Tube
- **Definition:** A torpedo launcher on a sub, with a reload time. Tube 1 faces the bow, tube 2 the stern.
- **Boundary:** Two per sub. A torpedo leaves along the sub's axis from the tube's end of the hull.

## Torpedo
- **Definition:** An unguided WW2 weapon set before launch: angle, speed, fuse. It leaves its tube along the sub's axis, turns at a fixed rate onto its angle, then runs straight.
- **Boundary:** No guidance or homing after the turn. Noisy.

## Fuse
- **Definition:** Ticks after launch at which a torpedo detonates.
- **Boundary:** Also detonates on hitting rock or a hull.

## Blast radius
- **Definition:** Distance from detonation within which a sub sinks.
- **Boundary:** One hit sinks in v1.

## Debug view
- **Definition:** A toggled overlay drawing true state over the player view.
- **Boundary:** The only renderer allowed to read true state.

## Course target
- **Definition:** The point a player drags the course handle to: where the sub should end the turn.
- **Boundary:** Planning UI only. The edited course order is solved to land as close as possible; the sim sees only the order.

## Aim point
- **Definition:** The point a player drags a torpedo launch to: where it should detonate.
- **Boundary:** Sets angle, speed and fuse. Clamped to the slow speed's max run.

## Max run
- **Definition:** The longest run, in ticks, a torpedo speed setting allows.
- **Boundary:** Fast runs shorter than slow. A fuse never exceeds its speed's max run.

## Mark
- **Definition:** A player's guess at an enemy's track: a position at a tick and a velocity. Drawn at the scrub cursor tick on either half of the timeline.
- **Boundary:** Planning UI only. Never reaches the sim, the AI or the order log. Not a contact.

## Track
- **Definition:** The AI's straight-line course fit through samples it believes come from one contact.
- **Boundary:** AI memory only, built from perception. An AI holds several at once.

## Target
- **Definition:** The track an AI is hunting and firing at.
- **Boundary:** Chosen again at random from its live tracks after every shot. May be the player or another AI.

## Side
- **Definition:** A group of slots that wins or loses together. Every slot is its own side (free-for-all).
- **Boundary:** The match ends when the player sinks or every AI is gone.

## Solid blob
- **Definition:** A drifting mass in the water that blocks subs, torpedoes and sound, and echoes pings like rock.
- **Boundary:** Not terrain: it lives in the blob layer, never the grid (ADR 0004). Seen only by sonar. Its echo looks like a hull echo.

## Soft cover
- **Definition:** A drifting patch of water that muffles passive noise crossing it. Pinged, it echoes in its own colour.
- **Boundary:** Subs, torpedoes, pings and echoes pass through. Not terrain (ADR 0004).
