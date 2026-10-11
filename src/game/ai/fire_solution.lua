-- Intercept maths for an unguided torpedo (docs/CONTEXT.md "Torpedo"): the
-- launch angle and run time that put a straight-running torpedo where a target
-- on a constant course will be. Units are the caller's (the AI uses cell units
-- and ticks). Shared with nothing in the sim's truth. Pure; no `love.*`.
local FireSolution = {}

local atan2 = math.atan2 or math.atan

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

return FireSolution
