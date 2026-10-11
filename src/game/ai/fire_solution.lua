-- Fire control for an unguided torpedo (docs/CONTEXT.md "Torpedo", "Tube"):
-- which tube faces a target, the straight-run intercept (units are the
-- caller's), and the led shot whose curved run (Predict.aim) meets a target
-- on a constant course. Reads only own-ship pose, config and the map handed
-- in; nothing of the sim's truth. Pure; no `love.*`.
local Angle = require("src.core.angle")
local Predict = require("src.game.predict")

local FireSolution = {}

local atan2 = math.atan2 or math.atan

-- The tube to fire at a target on `bearing` from a sub heading `heading`:
-- the loaded one of `tubes` (`{ reload }` each) whose facing
-- (config.tubes.facing) is nearest the bearing, or nil when none is loaded.
function FireSolution.tubeFor(config, heading, bearing, tubes)
	local best, bestOff
	for i, tube in ipairs(tubes) do
		local off = math.abs(Angle.wrap(bearing - heading - config.tubes.facing[i]))
		if tube.reload == 0 and (not best or off < bestOff) then
			best, bestOff = i, off
		end
	end
	return best
end

-- Torpedo from (sx, sy) at `speed` per tick; target at (tx, ty) now, moving
-- (vx, vy) per tick. Returns `angle, ticks` for the earliest intercept, or nil
-- when the torpedo can never catch it.
function FireSolution.intercept(sx, sy, tx, ty, vx, vy, speed)
	local dx, dy = tx - sx, ty - sy
	-- |D + V k| = speed * k  =>  a k^2 + b k + c = 0
	local a = vx * vx + vy * vy - speed * speed
	local b = 2 * (dx * vx + dy * vy)
	local c = dx * dx + dy * dy
	local ticks
	if math.abs(a) < 1e-12 then
		if b < 0 then
			ticks = -c / b
		end
	else
		local disc = b * b - 4 * a * c
		if disc >= 0 then
			local root = math.sqrt(disc)
			local k1, k2 = (-b - root) / (2 * a), (-b + root) / (2 * a)
			local lo, hi = math.min(k1, k2), math.max(k1, k2)
			ticks = lo > 0 and lo or (hi > 0 and hi or nil)
		end
	end
	if not ticks then
		return nil
	end
	return atan2(dy + vy * ticks, dx + vx * ticks), ticks
end

-- A shot at speed setting `name` from tube `tube` of a sub at `pose` (`{ x,
-- y, angle }` at the launch tick) that meets `target` (`{ x, y, vx, vy }`,
-- world px and px per tick, where it is at the launch tick) where the target
-- will be at its fuse: the torpedo order, or nil when the run (turn
-- included, Predict.aim) cannot get within a cell of it inside its max run.
-- Iterates fuse and aim point (config.torpedo.aimSteps steps) from the
-- straight-run intercept.
function FireSolution.lead(world, pose, tube, name, target)
	local config = world.config
	local lx, ly = Predict.launchPose(world, pose, tube)
	local speed = config.torpedo.speeds[name].speed * config.dt
	local _, ticks = FireSolution.intercept(lx, ly, target.x, target.y, target.vx, target.vy, speed)
	local k = math.floor((ticks or 0) + 0.5)
	local aim
	for _ = 1, config.torpedo.aimSteps do
		aim = Predict.aim(world, tube, pose, target.x + target.vx * k, target.y + target.vy * k, name)
		if aim.order.fuse == k then
			break
		end
		k = aim.order.fuse
	end
	k = aim.order.fuse
	local dx, dy = aim.x - (target.x + target.vx * k), aim.y - (target.y + target.vy * k)
	if dx * dx + dy * dy > config.grid.cellSize ^ 2 then
		return nil
	end
	return aim.order
end

return FireSolution
