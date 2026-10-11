-- Torpedo aim point (planning UI only; docs/CONTEXT.md "Aim point"). Turns the
-- point a player drags a launch to into a torpedo order: the angle points at
-- it, the speed is fast within the fast range and else slow, and the fuse is
-- the run time to the point. A point beyond the slow range clamps to it along
-- the same angle. The sim never sees the point, only the order. Pure; no
-- `love.*`.
local Orders = require("src.game.orders")

local TorpedoAim = {}

local atan2 = math.atan2 or math.atan

-- Distance a torpedo covers at speed `name` over its max run, in px.
local function range(config, name)
	local s = config.torpedo.speeds[name]
	return s.speed * config.dt * s.maxRun
end

-- The launch from tube `tube` at launch point (lx, ly) aimed at (tx, ty).
-- Returns `{ order, x, y, dud }`: the torpedo order, the (clamped) aim point
-- it detonates at, and whether that is inside the arming distance (a dud).
-- A point on the launch point aims east.
function TorpedoAim.solve(world, tube, lx, ly, tx, ty)
	local config = world.config
	local dx, dy = tx - lx, ty - ly
	local distance = math.sqrt(dx * dx + dy * dy)
	local angle = (dx == 0 and dy == 0) and 0 or atan2(dy, dx)
	local speed = distance <= range(config, "fast") and "fast" or "slow"
	local slowRange = range(config, "slow")
	if distance > slowRange then
		distance = slowRange
	end
	local s = config.torpedo.speeds[speed]
	local fuse = math.max(1, math.min(s.maxRun, math.floor(distance / (s.speed * config.dt) + 0.5)))
	return {
		order = Orders.torpedo(tube, angle, speed, fuse),
		x = lx + distance * math.cos(angle),
		y = ly + distance * math.sin(angle),
		dud = distance < config.torpedo.armDistance,
	}
end

return TorpedoAim
