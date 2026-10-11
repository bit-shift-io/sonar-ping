-- Course target solver (planning UI only; docs/CONTEXT.md "Course target").
-- Given a slot's planned `entries` ({ tick, order } as for Turn.submit) and
-- one course order among them to edit, picks heading, dive and speed for it
-- so the projected end-of-turn position lands as close as possible to a
-- target point. Every other entry stays as it is. Motion comes only from
-- Predict.path, so the solved end is exactly the ghost path's end. The sim
-- never sees the target, only the order.
--
-- Away from rock a path's positions are linear in the edited order's speed
-- (turning is per tick, whatever the speed), so `new` projects each sampled
-- dive at stop and full speed once, and `solve` interpolates between them,
-- checks the pick with one real projection, and refines the speed with real
-- projections only when rock made the check disagree. Pure; no `love.*`.
local Bodies = require("src.sim.bodies")
local Orders = require("src.game.orders")
local Predict = require("src.game.predict")

local CourseSolve = {}
CourseSolve.__index = CourseSolve

local HEADINGS = { "east", "west" }
local GOLDEN = (math.sqrt(5) - 1) / 2

local function subForSlot(ctx, slot)
	for _, sub in ipairs(ctx.pools.subs) do
		if sub.slot == slot and not sub.dead then
			return sub
		end
	end
	return nil
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Projected end of turn with the edited order swapped for `order`. Memoised
-- per solver: interpolated dives fall on a fixed lattice, so neighbouring
-- drag events often project the same courses.
local function endOf(self, order)
	local key = string.format("%s %.17g %.17g", order.heading, order.dive, order.speed)
	if self.ends[key] then
		return self.ends[key]
	end
	local entries = {}
	for i, entry in ipairs(self.entries) do
		entries[i] = entry.order == self.edited and { tick = entry.tick, order = order } or entry
	end
	local path = Predict.path(self.ctx, self.slot, entries)
	self.ends[key] = path[#path]
	return path[#path]
end

-- Where the sub is when the edited order applies: its start for tick 1, else
-- the projection after the tick before.
local function anchorOf(self)
	local tick
	for _, entry in ipairs(self.entries) do
		if entry.order == self.edited then
			tick = entry.tick
		end
	end
	self.lastCourse = true
	for _, entry in ipairs(self.entries) do
		if entry.order.kind == "course" and entry.tick > tick then
			self.lastCourse = false
		end
	end
	if tick <= 1 then
		local body = Bodies.get(self.ctx.bodies, subForSlot(self.ctx, self.slot).bodyId)
		return body.x, body.y
	end
	local p = Predict.path(self.ctx, self.slot, self.entries)[tick - 1]
	return p.x, p.y
end

-- The ends of turn at stop and full speed for one heading and dive. With no
-- course order after the edited one, a stop ends where the order applies.
local function sample(self, heading, dive)
	local z = self.lastCourse and { x = self.anchorX, y = self.anchorY } or endOf(self, Orders.course(heading, dive, 0))
	local f = endOf(self, Orders.course(heading, dive, self.full))
	return { dive = dive, zx = z.x, zy = z.y, fx = f.x, fy = f.y }
end

-- Appends to `row` the samples after `a` up to and including `b`, halving
-- the interval while its midpoint is further than `splitTolerance` px from
-- the interpolation (a turn that flips direction, rock), at most `depth`
-- times. An interval still split at the last depth is marked `broken` on its
-- end sample: only its two ends are used, never what lies between.
local function split(self, heading, a, b, row, depth)
	if depth > 0 then
		local m = sample(self, heading, (a.dive + b.dive) / 2)
		local tol2 = self.tuning.splitTolerance ^ 2
		local zOff = (m.zx - (a.zx + b.zx) / 2) ^ 2 + (m.zy - (a.zy + b.zy) / 2) ^ 2
		local fOff = (m.fx - (a.fx + b.fx) / 2) ^ 2 + (m.fy - (a.fy + b.fy) / 2) ^ 2
		if zOff > tol2 or fOff > tol2 then
			split(self, heading, a, m, row, depth - 1)
			split(self, heading, m, b, row, depth - 1)
			return
		end
		row[#row + 1] = m
		row[#row + 1] = b
		return
	end
	b = { dive = b.dive, zx = b.zx, zy = b.zy, fx = b.fx, fy = b.fy, broken = true }
	row[#row + 1] = b
end

-- `edited` is the course order (a table inside `entries`) to solve for; it is
-- never changed. Projects the samples, so build one per drag.
function CourseSolve.new(ctx, slot, entries, edited)
	local config = ctx.config
	local self = setmetatable({
		ctx = ctx,
		slot = slot,
		entries = entries,
		edited = edited,
		full = config.speeds.full.speed,
		tuning = config.courseSolve,
		samples = {},
		ends = {},
	}, CourseSolve)
	self.anchorX, self.anchorY = anchorOf(self)
	local maxDive, n = config.sub.maxDive, config.courseSolve.dives
	for _, heading in ipairs(HEADINGS) do
		local row = {}
		local prev = sample(self, heading, -maxDive)
		row[1] = prev
		for i = 2, n do
			local nextSample = sample(self, heading, lerp(-maxDive, maxDive, (i - 1) / (n - 1)))
			split(self, heading, prev, nextSample, row, config.courseSolve.splitDepth)
			prev = nextSample
		end
		self.samples[heading] = row
	end
	return self
end

-- The interpolated course ending closest to (tx, ty): heading, dive, speed
-- and its interpolated end.
local function interpolate(self, tx, ty)
	local best = { d2 = math.huge }
	local steps = self.tuning.subSteps
	for _, heading in ipairs(HEADINGS) do
		local row = self.samples[heading]
		for i = 1, #row - 1 do
			local a, b = row[i], row[i + 1]
			for k = 0, steps, b.broken and steps or 1 do
				local u = k / steps
				local zx, zy = lerp(a.zx, b.zx, u), lerp(a.zy, b.zy, u)
				local dx, dy = lerp(a.fx, b.fx, u) - zx, lerp(a.fy, b.fy, u) - zy
				local len2 = dx * dx + dy * dy
				local t = len2 > 0 and ((tx - zx) * dx + (ty - zy) * dy) / len2 or 0
				t = math.max(0, math.min(1, t))
				local px, py = zx + t * dx, zy + t * dy
				local d2 = (px - tx) ^ 2 + (py - ty) ^ 2
				if d2 < best.d2 then
					best = { d2 = d2, heading = heading, dive = lerp(a.dive, b.dive, u), speed = t * self.full, x = px, y = py }
				end
			end
		end
	end
	return best
end

-- Golden-section search over speed at a fixed heading and dive, on real
-- projections. Returns the best order and its end.
local function refineSpeed(self, heading, dive, tx, ty, order, p)
	local bestOrder, bestP = order, p
	local bestD = (p.x - tx) ^ 2 + (p.y - ty) ^ 2
	local function try(speed)
		local o = Orders.course(heading, dive, speed)
		local e = endOf(self, o)
		local d = (e.x - tx) ^ 2 + (e.y - ty) ^ 2
		if d < bestD then
			bestOrder, bestP, bestD = o, e, d
		end
		return d
	end
	local lo, hi = 0, self.full
	local m1, m2 = hi - GOLDEN * (hi - lo), lo + GOLDEN * (hi - lo)
	local d1, d2 = try(m1), try(m2)
	for _ = 1, self.tuning.refineSteps do
		if d1 <= d2 then
			hi, m2, d2 = m2, m1, d1
			m1 = hi - GOLDEN * (hi - lo)
			d1 = try(m1)
		else
			lo, m1, d1 = m1, m2, d2
			m2 = lo + GOLDEN * (hi - lo)
			d2 = try(m2)
		end
	end
	return bestOrder, bestP
end

-- Solves the edited order for a target at (tx, ty). Returns
-- `{ order = <course order>, x, y }`, (x, y) being the projected end of turn
-- with that order. A target on the sub keeps the edited order's heading and
-- dive at speed 0.
function CourseSolve:solve(tx, ty)
	local order
	if (tx - self.anchorX) ^ 2 + (ty - self.anchorY) ^ 2 <= self.tuning.stopRadius ^ 2 then
		order = Orders.course(self.edited.heading, self.edited.dive, 0)
		local p = endOf(self, order)
		return { order = order, x = p.x, y = p.y }
	end
	local best = interpolate(self, tx, ty)
	order = Orders.course(best.heading, best.dive, best.speed)
	local p = endOf(self, order)
	if (p.x - best.x) ^ 2 + (p.y - best.y) ^ 2 > self.tuning.tolerance ^ 2 then
		order, p = refineSpeed(self, best.heading, best.dive, tx, ty, order, p)
	end
	return { order = order, x = p.x, y = p.y }
end

-- One-off solve: CourseSolve.new(...):solve(tx, ty).
function CourseSolve.solveOnce(ctx, slot, entries, edited, tx, ty)
	return CourseSolve.new(ctx, slot, entries, edited):solve(tx, ty)
end

return CourseSolve
