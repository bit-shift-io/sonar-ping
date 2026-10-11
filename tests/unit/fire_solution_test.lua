-- Intercept maths for a straight-running torpedo against a target on a
-- constant course. Pure maths: no match, no sim.
local FireSolution = require("src.game.ai.fire_solution")

-- Where a torpedo fired from (sx, sy) at `angle` and `speed` is after `k`
-- ticks, and where the target is then.
local function positionsAfter(k, sx, sy, angle, speed, tx, ty, vx, vy)
	return sx + math.cos(angle) * speed * k, sy + math.sin(angle) * speed * k, tx + vx * k, ty + vy * k
end

test("the fire solution meets a constant-velocity target at the intercept tick", function()
	local sx, sy, tx, ty, vx, vy, speed = 40, 75, 140, 60, -0.2, 0.05, 0.83

	local angle, ticks = FireSolution.intercept(sx, sy, tx, ty, vx, vy, speed)

	local ax, ay, bx, by = positionsAfter(ticks, sx, sy, angle, speed, tx, ty, vx, vy)
	assertNear(bx, ax, 1e-6)
	assertNear(by, ay, 1e-6)
	assertTrue(ticks > 0)
end)

test("a stationary target is aimed at directly, at range over speed ticks", function()
	local angle, ticks = FireSolution.intercept(0, 0, 30, 40, 0, 0, 2)

	assertNear(math.atan2(40, 30), angle, 1e-9)
	assertNear(25, ticks, 1e-9)
end)

test("a target running away faster than the torpedo has no solution", function()
	local angle = FireSolution.intercept(0, 0, 50, 0, 3, 0, 2)

	assertEqual(nil, angle)
end)
