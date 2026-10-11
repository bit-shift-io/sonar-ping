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

local Config = require("src.game.config")

local function tubes(reload1, reload2)
	return { { reload = reload1 or 0 }, { reload = reload2 or 0 } }
end

test("a target ahead of the beam gets the bow tube; one abaft it the stern tube", function()
	local heading = math.pi - math.rad(10) -- west, nose a little up

	assertEqual(1, FireSolution.tubeFor(Config, heading, math.pi + math.rad(40), tubes()))
	assertEqual(2, FireSolution.tubeFor(Config, heading, math.rad(30), tubes()))
end)

test("with the nearer tube reloading the other loaded tube fires; with none loaded, none", function()
	assertEqual(2, FireSolution.tubeFor(Config, 0, 0, tubes(100, 0)))
	assertEqual(nil, FireSolution.tubeFor(Config, 0, 0, tubes(100, 5)))
end)

local Match = require("src.game.match")
local Predict = require("src.game.predict")

-- Open water: a flat seabed at y = 700.
local function world()
	return Match.new({
		seabed = { { x = 0, y = 700 }, { x = 1280, y = 700 } },
		subs = {
			player = { x = 100, y = 300, order = { kind = "course", heading = "east", dive = 0, speed = 0 } },
			enemy = { x = 1200, y = 100, order = { kind = "course", heading = "west", dive = 0, speed = 0 } },
		},
	}, Config, 1, { ai = false })
end

test("a led shot's curved run meets a moving target within a cell at its fuse", function()
	local w = world()
	local pose = { x = 400, y = 350, angle = 0 }
	-- Off the bow quarter and climbing away, so the run must turn first.
	local target = { x = 600, y = 200, vx = 1.0, vy = -0.3 }

	local order = FireSolution.lead(w, pose, 1, "slow", target)

	local preview = Predict.torpedo(w, pose, order)
	local p = preview.points[order.fuse]
	local tx, ty = target.x + target.vx * order.fuse, target.y + target.vy * order.fuse
	assertTrue(math.sqrt((p.x - tx) ^ 2 + (p.y - ty) ^ 2) <= Config.grid.cellSize, "off by more than a cell")
end)

test("a target the run cannot reach inside its max run draws no led shot", function()
	local pose = { x = 200, y = 350, angle = 0 }
	-- Beyond fast range and running away.
	local target = { x = 700, y = 350, vx = 1.3, vy = 0 }

	assertEqual(nil, FireSolution.lead(world(), pose, 1, "fast", target))
end)
