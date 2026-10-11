-- The AI: a producer of orders for one slot (docs/ARCHITECTURE.md "Rules",
-- ADR 0002). Each plan phase it reads a restricted view (Match.aiView: its own
-- perception, its own ship, the map, config and the clock; never true state
-- of anything else) and returns `{ tick, order }` entries for Turn.submit.
-- It listens; closes on what it hears; pings when its contacts are stale;
-- fires a predicted shot at a target inside torpedo range; and evades when it
-- hears a launch. Deterministic from its seed and what it perceives. Cell
-- units and ticks throughout, except where Predict works in world px.
-- Pure; no `love.*`.
local Rng = require("src.core.rng")
local Grid = require("src.sim.grid")
local Orders = require("src.game.orders")
local Predict = require("src.game.predict")
local Track = require("src.game.ai.track")
local FireSolution = require("src.game.ai.fire_solution")

local Ai = {}

local atan2 = math.atan2 or math.atan

-- A fresh AI memory. `seed` seeds its own RNG (never the match's).
--   samples   course-fit samples `{ x, y, t, w }` of what it is hunting
--   heard     emit tick of the newest sample (match start counts as heard)
--   pinged    tick of its last ping
--   processed newest contact arrival tick already read
--   launch    the newest launch heard since it last planned (`{ x, y }`)
--   launches  its own torpedo runs `{ tick, x, y, points, endTick }`
function Ai.new(seed)
	return {
		rng = Rng.new(seed),
		samples = {},
		heard = 0,
		pinged = -math.huge,
		processed = -math.huge,
		launch = nil,
		launches = {},
	}
end

local function toCells(view, x, y)
	local size = view.grid.cellSize
	return x / size + 0.5, y / size + 0.5
end

local function distanceToSegment(px, py, ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	local len2 = dx * dx + dy * dy
	local u = len2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2)) or 0
	local ex, ey = ax + dx * u - px, ay + dy * u - py
	return math.sqrt(ex * ex + ey * ey)
end

-- True when `contact`, heard at `range` cells, lies on the run so far (up to
-- its arrival tick) of one of the AI's own torpedoes.
local function ownTorpedo(brain, view, contact, range)
	local radius = view.config.ai.ownTorpedoRadius + view.perception.smear * range
	for _, launch in ipairs(brain.launches) do
		local ran = math.min(contact.arrivalTick - launch.tick, launch.endTick)
		if ran >= 0 then
			local ax, ay = toCells(view, launch.x, launch.y)
			local bx, by = ax, ay
			if ran >= 1 then
				bx, by = toCells(view, launch.points[ran].x, launch.points[ran].y)
			end
			if distanceToSegment(contact.x, contact.y, ax, ay, bx, by) <= radius then
				return true
			end
		end
	end
	return false
end

-- Reads the contacts that arrived since it last listened, heard from where
-- the sub is now (Match calls this every tick, after perception): drops its
-- own sounds, terrain echoes (it knows the map) and blasts; turns the rest
-- into course samples (noise averaged per arrival tick) and remembers a
-- launch (a noise contact at the launch level or louder).
function Ai.listen(brain, view)
	local cfg, perception = view.config.ai, view.perception
	local contacts = perception.contacts
	local launchLevel = view.config.torpedo.launchNoise
	local ox, oy = view.own.x, view.own.y
	local first = #contacts + 1
	while first > 1 and contacts[first - 1].arrivalTick > brain.processed do
		first = first - 1
	end
	local group, groupTick
	local function flush()
		if group and group.n > 0 then
			local s = Track.sample({ x = group.x / group.n, y = group.y / group.n, arrivalTick = groupTick }, ox, oy, perception.c)
			s.w = 1
			brain.samples[#brain.samples + 1] = s
		end
		group = nil
	end
	for i = first, #contacts do
		local contact = contacts[i]
		local tick = contact.arrivalTick
		local dx, dy = contact.x - ox, contact.y - oy
		local range = math.sqrt(dx * dx + dy * dy)
		local terrain = contact.kind == "echo"
			and Grid.get(view.grid, math.floor(contact.x + 0.5), math.floor(contact.y + 0.5)) ~= Grid.WATER
		if contact.kind ~= "blast" and not terrain and range > cfg.selfRadius and not ownTorpedo(brain, view, contact, range) then
			if contact.kind == "noise" then
				if contact.level >= launchLevel then
					brain.launch = { x = contact.x, y = contact.y }
				end
				if tick ~= groupTick then
					flush()
					group, groupTick = { x = 0, y = 0, n = 0 }, tick
				end
				group.x, group.y, group.n = group.x + contact.x, group.y + contact.y, group.n + 1
			else
				local s = Track.sample(contact, ox, oy, perception.c)
				s.w = cfg.exactWeight
				brain.samples[#brain.samples + 1] = s
			end
		end
	end
	flush()
	if perception.tick then
		brain.processed = perception.tick
	end
end

-- Keeps the samples emitted within the track window of the newest one, and
-- none once even that is older than `trackMaxAge`; returns the course fit,
-- its speed capped at the fastest a sub can go.
local function track(brain, view)
	local cfg = view.config.ai
	for _, s in ipairs(brain.samples) do
		brain.heard = math.max(brain.heard, s.t)
	end
	local kept = {}
	if view.tick - brain.heard <= cfg.trackMaxAge then
		for _, s in ipairs(brain.samples) do
			if s.t >= brain.heard - cfg.trackWindow then
				kept[#kept + 1] = s
			end
		end
	end
	brain.samples = kept
	local estimate = Track.fit(kept)
	if estimate then
		local config = view.config
		local maxSpeed = config.speeds.full.speed * config.dt / config.grid.cellSize
		local speed = math.sqrt(estimate.vx * estimate.vx + estimate.vy * estimate.vy)
		if speed > maxSpeed then
			estimate.vx, estimate.vy = estimate.vx * maxSpeed / speed, estimate.vy * maxSpeed / speed
		end
	end
	return estimate
end

local function clampDive(view, dive)
	local maxDive = view.config.sub.maxDive
	return math.max(-maxDive, math.min(maxDive, dive))
end

-- Away from the launch, diving or climbing hard (the RNG picks which).
local function evade(brain, view, launch)
	local heading = launch.x > view.own.x and "west" or "east"
	local dive = view.config.sub.maxDive * (brain.rng:next() < 0.5 and -1 or 1)
	return Orders.course(heading, dive, view.config.ai.evadeSpeed)
end

-- Where the target will be on `tick`: along its fitted course, but run on
-- no more than `extrapolateTicks` past its newest sample.
local function predict(view, estimate, tick)
	return Track.at(estimate, math.min(tick, estimate.t + view.config.ai.extrapolateTicks))
end

-- Towards where the target will be `leadTicks` from now.
local function close(view, estimate)
	local tx, ty = predict(view, estimate, view.tick + view.config.ai.leadTicks)
	local dx, dy = tx - view.own.x, ty - view.own.y
	local heading = dx < 0 and "west" or "east"
	return Orders.course(heading, clampDive(view, atan2(dy, math.abs(dx))), view.config.ai.closeSpeed)
end

-- Nothing to hunt and lying stopped: set off quietly, level, towards the
-- middle of the map (where it can hear most of it).
local function search(view)
	local heading = view.own.x > view.grid.width / 2 and "west" or "east"
	return Orders.course(heading, 0, view.config.ai.quietSpeed)
end

local function loadedTube(view)
	for i, tube in ipairs(view.own.tubes) do
		if tube.reload == 0 then
			return i
		end
	end
	return nil
end

-- A torpedo launched at turn tick 1 (from path[1], where the sub is then) at
-- the target's predicted intercept, or nil when there is no clean shot: no
-- loaded tube, out of range, inside the arming distance, or rock in the way.
local function shot(view, estimate, path)
	local config, cfg = view.config, view.config.ai
	local tube = loadedTube(view)
	if not tube or #path == 0 then
		return nil
	end
	local wx, wy = path[1].x, path[1].y
	local sx, sy = toCells(view, wx, wy)
	local tx, ty = predict(view, estimate, view.tick + 1)
	local size = config.grid.cellSize
	local speed = config.torpedo.speeds[cfg.torpedoSpeed].speed * config.dt / size
	local angle, ticks = FireSolution.intercept(sx, sy, tx, ty, estimate.vx, estimate.vy, speed)
	if not angle then
		return nil
	end
	local fuse = math.floor(ticks + 0.5)
	local run = fuse * speed
	if fuse < 1 or fuse > config.torpedo.maxFuse or run > cfg.fireRange then
		return nil
	end
	if run * size < config.torpedo.armDistance + cfg.armMargin then
		return nil
	end
	local order = Orders.torpedo(tube, angle, cfg.torpedoSpeed, fuse)
	local preview = Predict.torpedo(view, wx, wy, order)
	if preview.ends ~= "fuse" or preview.endTick ~= fuse then
		return nil
	end
	return order, { x = wx, y = wy, points = preview.points, endTick = fuse }
end

-- Forgets its own torpedo runs once nothing of them can still be heard.
local function forgetLaunches(brain, view)
	local config, kept = view.config, {}
	local horizon = config.torpedo.maxFuse + config.perception.echoFadeTicks
	for _, run in ipairs(brain.launches) do
		if view.tick - run.tick <= horizon then
			kept[#kept + 1] = run
		end
	end
	brain.launches = kept
end

-- The turn tick on which following `course` from tick 1 (nil: the standing
-- course), then `later` (`{ tick, order }` entries), first runs the sub into
-- rock -- a tick on which it should move but is held where it was -- or
-- math.huge if it stays clear for `horizon` ticks (or is stopped).
local function groundTick(view, course, later, horizon)
	if view.config.speeds[(course or view.own.helm).speed].speed == 0 then
		return math.huge
	end
	local entries = { course and { tick = 1, order = course } or nil }
	for _, entry in ipairs(later) do
		entries[#entries + 1] = entry
	end
	local path = Predict.pathFrom(view, view.own.body, view.own.helm, entries, horizon)
	for i = 2, #path do
		if path[i].x == path[i - 1].x and path[i].y == path[i - 1].y then
			return i
		end
	end
	return math.huge
end

-- `course` (nil: the standing course) if it keeps the sub off the rock for
-- `steerTicks`; otherwise whichever of it, level, climbing hard, the
-- mirrored dive and level the other way stays clear longest (the first of
-- those, on a tie).
local function steerClear(view, course, later)
	local horizon = view.config.ai.steerTicks
	local best, bestTick = course, groundTick(view, course, later, horizon)
	if bestTick == math.huge then
		return course
	end
	local base = course or view.own.helm
	local other = base.heading == "east" and "west" or "east"
	local speed = view.config.speeds[base.speed].speed > 0 and base.speed or "slow"
	local candidates = {
		Orders.course(base.heading, 0, speed),
		Orders.course(base.heading, -view.config.sub.maxDive, speed),
		Orders.course(base.heading, -base.dive, speed),
		Orders.course(other, 0, speed),
	}
	for _, candidate in ipairs(candidates) do
		local tick = groundTick(view, candidate, later, horizon)
		if tick > bestTick then
			best, bestTick = candidate, tick
		end
	end
	return best
end

-- When the course would still run aground before the turn ends, a stop
-- `groundMargin` ticks short of it (on the course then in effect, so the hull
-- need not turn); returns the course and later entries to submit.
local function stopShort(view, course, later)
	local grounds = groundTick(view, course, later, view.turnLength)
	if grounds == math.huge then
		return course, later
	end
	local stopTick = grounds - view.config.ai.groundMargin
	local current, kept = course or view.own.helm, {}
	for _, entry in ipairs(later) do
		if entry.tick < stopTick then
			kept[#kept + 1] = entry
			current = entry.order
		end
	end
	local stop = Orders.course(current.heading, current.dive, "stop")
	if stopTick <= 1 then
		return stop, {}
	end
	kept[#kept + 1] = { tick = stopTick, order = stop }
	return course, kept
end

-- This plan phase's orders for the AI's slot, from `view` (Match.aiView).
function Ai.plan(brain, view)
	local cfg, now = view.config.ai, view.tick
	Ai.listen(brain, view)
	forgetLaunches(brain, view)
	local estimate = track(brain, view)

	local course, later = nil, {}
	if brain.launch then
		course = evade(brain, view, brain.launch)
		later[1] = { tick = cfg.evadeTicks, order = Orders.course(course.heading, 0, cfg.quietSpeed) }
		brain.launch = nil
	elseif estimate then
		course = close(view, estimate)
	elseif now > 0 and view.config.speeds[view.own.helm.speed].speed == 0 then
		course = search(view)
	end
	course = steerClear(view, course, later)
	course, later = stopShort(view, course, later)
	local entries = {}
	if course then
		entries[1] = { tick = 1, order = course }
	end
	for _, entry in ipairs(later) do
		entries[#entries + 1] = entry
	end
	if now - brain.heard >= cfg.staleTicks and now - brain.pinged >= cfg.staleTicks then
		entries[#entries + 1] = { tick = 1, order = Orders.ping() }
		brain.pinged = now
	end

	if estimate and now - estimate.t <= cfg.fireMaxAge then
		local path = Predict.pathFrom(view, view.own.body, view.own.helm, entries, 1)
		local order, run = shot(view, estimate, path)
		if order then
			entries[#entries + 1] = { tick = 1, order = order }
			run.tick = now + 1
			brain.launches[#brain.launches + 1] = run
		end
	end
	return entries
end

return Ai
