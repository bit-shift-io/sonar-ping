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
- **Definition:** The turn's ticks shown as a strip in the plan phase, holding scheduled orders.
- **Boundary:** Planning UI only. The sim sees orders, not the timeline.

## Tube
- **Definition:** A torpedo launcher on a sub, with a reload time.
- **Boundary:** Two per sub in v1.

## Torpedo
- **Definition:** An unguided WW2 weapon set before launch: angle, speed, fuse.
- **Boundary:** Runs straight. No guidance or homing. Noisy.

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
