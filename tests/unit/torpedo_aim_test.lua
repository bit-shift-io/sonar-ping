-- Torpedo aim point (docs/CONTEXT.md "Aim point"): the point a launch is
-- dragged to becomes an order whose run (out of the tube, the turn, then
-- straight) detonates there.
local Match = require("src.game.match")
local Config = require("src.game.config")
local Predict = require("src.game.predict")
local TorpedoAim = require("src.game.torpedo_aim")

local CELL = Config.grid.cellSize
local FAST, SLOW = Config.torpedo.speeds.fast, Config.torpedo.speeds.slow
local DT = Config.dt

-- Flat seabed at y = 600, open water above it.
local function ctx()
	return Match.new({
		seabed = { { x = 0, y = 600 }, { x = 1280, y = 600 } },
		subs = {
			player = { x = 100, y = 300, order = { kind = "course", heading = "east", dive = 0, speed = 0 } },
			enemy = { x = 1200, y = 100, order = { kind = "course", heading = "west", dive = 0, speed = 0 } },
		},
	}, Config, 1, { ai = false })
end

-- A sub at (300, 300) heading east.
local POSE = { x = 300, y = 300, angle = 0 }

local function missBy(world, tube, pose, tx, ty)
	local aim = TorpedoAim.solve(world, tube, pose, tx, ty)
	local preview = Predict.torpedo(world, pose, aim.order)
	assertTrue(preview.detonation ~= nil, "armed and detonates")
	return math.sqrt((preview.detonation.x - tx) ^ 2 + (preview.detonation.y - ty) ^ 2), aim
end

test("a reachable aim point, ahead, abeam or astern, detonates within a cell of it", function()
	local world = ctx()
	local cases = {
		{ 1, 600, 450 }, -- ahead and below, bow tube
		{ 1, 340, 120 }, -- abeam, up: a hard turn first
		{ 2, 80, 380 }, -- astern, stern tube
		{ 1, 150, 420 }, -- astern from the bow tube: turns most of the way round
	}
	for _, c in ipairs(cases) do
		local d = missBy(world, c[1], POSE, c[2], c[3])
		assertTrue(d <= CELL, string.format("tube %d to (%d, %d) off by %.2f", c[1], c[2], c[3], d))
	end
end)

test("an aim point inside the turning circle clamps to the nearest point of the run, where it detonates", function()
	local world = ctx()
	-- Just abeam of the bow tip, closer than the slow turning radius.
	local radius = SLOW.speed * DT / Config.torpedo.turnRate
	local tx, ty = POSE.x + Config.sub.length / 2, POSE.y + radius / 2

	local aim = TorpedoAim.solve(world, 1, POSE, tx, ty)

	assertTrue(math.sqrt((aim.x - tx) ^ 2 + (aim.y - ty) ^ 2) > CELL, "clamped away from the point")
	local preview = Predict.torpedo(world, POSE, aim.order)
	local p = preview.points[aim.order.fuse]
	assertNear(aim.x, p.x, 1e-9, "the clamped point is on the run")
	assertNear(aim.y, p.y, 1e-9)
end)

-- The bow tip of POSE, where tube 1 launches.
local BOW_X = POSE.x + Config.sub.length / 2

test("an aim point the fast run reaches is a fast launch from the named tube", function()
	local aim = TorpedoAim.solve(ctx(), 1, POSE, BOW_X + 300, POSE.y + 100)

	assertEqual("fast", aim.order.speed)
	assertEqual(1, aim.order.tube)
end)

test("an aim point beyond fast range is a slow launch fused to its run time", function()
	local fastRange = FAST.speed * DT * FAST.maxRun
	local aim = TorpedoAim.solve(ctx(), 1, POSE, BOW_X + fastRange + 100, POSE.y)

	assertEqual("slow", aim.order.speed)
	assertNear((fastRange + 100) / (SLOW.speed * DT), aim.order.fuse, 0.5)
end)

test("an aim point beyond slow range clamps to the slow max run", function()
	local slowRange = SLOW.speed * DT * SLOW.maxRun
	local aim = TorpedoAim.solve(ctx(), 1, POSE, BOW_X + 3 * slowRange, POSE.y)

	assertEqual("slow", aim.order.speed)
	assertEqual(SLOW.maxRun, aim.order.fuse)
	assertNear(BOW_X + slowRange, aim.x, 1e-6)
	assertNear(POSE.y, aim.y, 1e-6)
end)

test("an aim point inside the arming distance is flagged a dud, not refused", function()
	local aim = TorpedoAim.solve(ctx(), 1, POSE, BOW_X + Config.torpedo.armDistance / 2, POSE.y)

	assertTrue(aim.dud)
	assertFalse(TorpedoAim.solve(ctx(), 1, POSE, BOW_X + 300, POSE.y).dud)
end)
