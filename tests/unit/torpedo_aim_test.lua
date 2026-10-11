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

test("an aim point inside fast range is a fast launch at the exact angle, fused to its run time", function()
	local aim = TorpedoAim.solve(ctx(), 1, 100, 300, 400, 500)
	local order = aim.order
	assertEqual("fast", order.speed)
	assertEqual(1, order.tube)
	assertNear(math.atan2(200, 300), order.angle, 1e-9)
	local distance = math.sqrt(300 ^ 2 + 200 ^ 2)
	assertNear(distance / (FAST.speed * DT), order.fuse, 0.5)
	assertEqual(400, aim.x)
	assertEqual(500, aim.y)
end)

test("an aim point between fast and slow range is a slow launch", function()
	local fastRange = FAST.speed * DT * FAST.maxRun
	local aim = TorpedoAim.solve(ctx(), 2, 100, 300, 100 + fastRange + 100, 300)
	assertEqual("slow", aim.order.speed)
	assertNear((fastRange + 100) / (SLOW.speed * DT), aim.order.fuse, 0.5)
end)

test("an aim point beyond slow range clamps to the slow max run along the same angle", function()
	local slowRange = SLOW.speed * DT * SLOW.maxRun
	local aim = TorpedoAim.solve(ctx(), 1, 100, 300, 100 + 3 * slowRange, 300 - 3 * slowRange)
	assertEqual("slow", aim.order.speed)
	assertEqual(SLOW.maxRun, aim.order.fuse)
	assertNear(-math.pi / 4, aim.order.angle, 1e-9)
	assertNear(slowRange, math.sqrt((aim.x - 100) ^ 2 + (aim.y - 300) ^ 2), 1e-6)
end)

test("an aim point inside the arming distance is flagged a dud, not refused", function()
	local aim = TorpedoAim.solve(ctx(), 1, 100, 300, 100 + Config.torpedo.armDistance / 2, 300)
	assertTrue(aim.dud)
	assertFalse(TorpedoAim.solve(ctx(), 1, 100, 300, 400, 300).dud)
end)

test("Predict.torpedo for the produced order detonates at the aim point in open water", function()
	local world = ctx()
	local targets = { { 400, 500 }, { 100, 100 }, { 700, 300 }, { 500, 200 } }
	for _, t in ipairs(targets) do
		local aim = TorpedoAim.solve(world, 1, 100, 300, t[1], t[2])
		local preview = Predict.torpedo(world, 100, 300, aim.order)
		assertTrue(preview.detonation ~= nil, "armed and detonates")
		local d = math.sqrt((preview.detonation.x - aim.x) ^ 2 + (preview.detonation.y - aim.y) ^ 2)
		assertTrue(d <= CELL, "detonates within a cell of the aim point, off by " .. d)
	end
end)
