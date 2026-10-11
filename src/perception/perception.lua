-- One observer's perception (docs/CONTEXT.md "Perception", ADR 0002): the
-- contacts that have arrived so far, built only from arrivals. Every sub owns
-- one; nothing here knows whether a human or an AI reads it. Positions are in
-- cell units (cell (cx, cy) has its centre at (cx, cy)). Pure; no `love.*`.
local Arrival = require("src.perception.arrival")
local Emissions = require("src.perception.emissions")
local Smear = require("src.perception.smear")

local Perception = {}

-- opts: c (speed of sound, cells per tick), smear (passive range smear as a
-- fraction of distance), fadeTicks (age after which a passive contact is
-- forgotten), echoFadeTicks (the same for ping echoes and ping origins),
-- archiveTicks (how long after arrival a contact stays queryable through
-- Perception.at, even once forgotten from the live `contacts`; falsy keeps no
-- archive).
function Perception.new(opts)
	return {
		c = opts.c,
		smear = opts.smear,
		fadeTicks = opts.fadeTicks,
		echoFadeTicks = opts.echoFadeTicks,
		archiveTicks = opts.archiveTicks,
		-- Arrival order, oldest first: { x, y, arrivalTick, kind, level, torpedo }.
		-- Perceived position only; the true cell is never stored.
		contacts = {},
		-- Every contact that arrived within archiveTicks, in arrival order
		-- (the live contacts are its unexpired tail). Only `at` reads it.
		archive = {},
		-- The observer's own position at each tick stepped within
		-- archiveTicks, oldest first: { tick, x, y }. Own ship only.
		positions = {},
		tick = nil, -- last tick stepped
		x = nil, -- observer position at the last step
		y = nil,
	}
end

-- Age of `contact` at `tick` (default: the perception's own tick).
function Perception.age(perception, contact, tick)
	return (tick or perception.tick) - contact.arrivalTick
end

-- Passive noise is smeared and fades after fadeTicks; active returns (ping
-- echoes and ping origins) are sharp and fade after echoFadeTicks.
local function isActive(kind)
	return kind == "echo" or kind == "ping"
end

-- Ticks after arrival at which `contact` is forgotten.
function Perception.fadeTicksOf(perception, contact)
	return isActive(contact.kind) and perception.echoFadeTicks or perception.fadeTicks
end

-- Drops expired contacts, keeping the rest in arrival order.
local function forget(perception, now)
	local contacts = perception.contacts
	local n, kept = #contacts, 0
	for i = 1, n do
		local contact = contacts[i]
		if now - contact.arrivalTick <= Perception.fadeTicksOf(perception, contact) then
			kept = kept + 1
			contacts[kept] = contact
		end
	end
	for i = kept + 1, n do
		contacts[i] = nil
	end
end

-- Drops archived contacts older than archiveTicks. Arrivals are recorded in
-- tick order, so the stale ones are a prefix.
local function trimArchive(perception, now)
	local archive, limit = perception.archive, perception.archiveTicks
	local n, stale = #archive, 0
	while stale < n and now - archive[stale + 1].arrivalTick > limit do
		stale = stale + 1
	end
	if stale == 0 then
		return
	end
	for i = 1, n - stale do
		archive[i] = archive[i + stale]
	end
	for i = n - stale + 1, n do
		archive[i] = nil
	end
end

-- Drops recorded positions older than archiveTicks (a prefix, like the archive).
local function trimPositions(perception, now)
	local positions, limit = perception.positions, perception.archiveTicks
	local n, stale = #positions, 0
	while stale < n and now - positions[stale + 1].tick > limit do
		stale = stale + 1
	end
	if stale == 0 then
		return
	end
	for i = 1, n - stale do
		positions[i] = positions[i + stale]
	end
	for i = n - stale + 1, n do
		positions[i] = nil
	end
end

-- Where the observer was at past `tick` (x, y in cells), or nil if that tick
-- was not stepped or has aged out of archiveTicks.
function Perception.positionAt(perception, tick)
	local positions = perception.positions
	for i = #positions, 1, -1 do
		local p = positions[i]
		if p.tick == tick then
			return p.x, p.y
		end
		if p.tick < tick then
			break
		end
	end
	return nil
end

-- The contacts the perception held at past `tick`: arrived by then and not yet
-- faded, in arrival order. Reaches back archiveTicks from the perception's own
-- tick. Read-only; pair with Perception.age(perception, contact, tick).
function Perception.at(perception, tick)
	local held, archive = {}, perception.archive
	for i = 1, #archive do
		local contact = archive[i]
		if contact.arrivalTick > tick then
			break
		end
		if tick - contact.arrivalTick <= Perception.fadeTicksOf(perception, contact) then
			held[#held + 1] = contact
		end
	end
	return held
end

-- A contact on the exact bearing from the observer to the cell: at the true
-- range plus the emission's smear for passive noise, at the cell itself for
-- an active return.
local function contactFor(perception, seed, e, x, y, now)
	if isActive(e.kind) then
		return { x = e.cx, y = e.cy, arrivalTick = now, kind = e.kind, level = e.level, torpedo = e.torpedo }
	end
	local dx, dy = e.cx - x, e.cy - y
	local distance = math.sqrt(dx * dx + dy * dy)
	local range = distance
	if distance > 0 then
		range = math.max(0, distance + Smear.offset(seed, e.tick, e.cx, e.cy, distance, perception.smear))
		dx, dy = dx / distance, dy / distance
	end
	return { x = x + dx * range, y = y + dy * range, arrivalTick = now, kind = e.kind, level = e.level, torpedo = e.torpedo }
end

local function visible(grid, e, x, y)
	if e.kind == "echo" then
		return Arrival.clearToFace(grid, e.cx, e.cy, x, y)
	end
	return Arrival.clear(grid, e.cx, e.cy, x, y)
end

-- Advances the perception to tick `now` with the observer at (x, y): every
-- emission in `history` whose sound reaches the observer this tick, with a
-- clear line of sight, becomes a contact. An echo comes from a solid cell, so
-- its line of sight is to the cell's face; anything else is heard from the
-- water cell it was emitted in. Buckets are walked newest first,
-- each in record order (arrays only, never pairs()).
function Perception.step(perception, history, grid, x, y, now)
	local px, py = perception.x or x, perception.y or y
	local c, contacts, seed = perception.c, perception.contacts, history.seed
	local archive, archiving = perception.archive, perception.archiveTicks
	for elapsed = 0, history.capacity - 1 do
		local bucket = Emissions.bucket(history, now - elapsed)
		if bucket then
			for i = 1, #bucket do
				local e = bucket[i]
				if Arrival.arrived(e.cx, e.cy, elapsed, px, py, x, y, c) and visible(grid, e, x, y) then
					local contact = contactFor(perception, seed, e, x, y, now)
					contacts[#contacts + 1] = contact
					if archiving then
						archive[#archive + 1] = contact
					end
				end
			end
		end
	end
	perception.tick, perception.x, perception.y = now, x, y
	forget(perception, now)
	if archiving then
		local positions = perception.positions
		positions[#positions + 1] = { tick = now, x = x, y = y }
		trimPositions(perception, now)
		trimArchive(perception, now)
	end
end

return Perception
