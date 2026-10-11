-- Torpedoes (docs/CONTEXT.md "Torpedo", "Fuse"): a launch order fires a tube;
-- the torpedo runs straight from the sub's centre, is noisy, and detonates at
-- its fuse, on rock or on a hull once armed.
local Match = require("src.game.match")
local Config = require("src.game.config")
local Turn = require("src.game.turn")
local Orders = require("src.game.orders")
local Bodies = require("src.sim.bodies")

-- Flat seabed at y = 600; both subs stopped (silent) in open water, 800 px apart.
local function level(overrides)
	local t = {
		seabed = { { x = 0, y = 600 }, { x = 1280, y = 600 } },
		subs = {
			player = { x = 200, y = 300, order = { kind = "course", heading = "east", dive = 0, speed = "stop" } },
			enemy = { x = 1000, y = 300, order = { kind = "course", heading = "west", dive = 0, speed = "stop" } },
		},
	}
	for k, v in pairs(overrides or {}) do
		t[k] = v
	end
	return t
end

-- A match executing turn 1 with `playerOrders` for the player and
-- `enemyOrders` (default none) for the enemy.
local function executing(lvl, playerOrders, enemyOrders)
	local ctx = Match.new(lvl or level(), Config, 1, { ai = false })
	Turn.submit(ctx, "player", playerOrders or {})
	Turn.submit(ctx, "enemy", enemyOrders or {})
	return ctx
end

local function stepTo(ctx, tick)
	while ctx.tick < tick do
		assertTrue(Match.step(ctx), "the match stopped before tick " .. tick)
	end
end

-- Steps until a torpedo is launched and then gone; returns the tick it went
-- and its last position.
local function runUntilGone(ctx)
	while #ctx.pools.torpedoes == 0 do
		assertTrue(Match.step(ctx), "no torpedo was launched")
	end
	local torpedo = ctx.pools.torpedoes[1]
	local body = Bodies.get(ctx.bodies, torpedo.bodyId)
	local x, y = body.x, body.y
	while ctx.pools.torpedoes[1] == torpedo do
		x, y = body.x, body.y
		if not Match.step(ctx) then
			break
		end
	end
	return ctx.tick, x, y
end

test("a torpedo order needs a real tube, a configured speed, a number angle and a fuse in range", function()
	assertTrue(Orders.validate(Orders.torpedo(1, 0.5, "fast", 120), Config))
	assertTrue(Orders.validate(Orders.torpedo(2, -3, "slow", Config.torpedo.maxFuse), Config))
	assertFalse(Orders.validate(Orders.torpedo(3, 0, "fast", 120), Config), "tube 3")
	assertFalse(Orders.validate(Orders.torpedo(1, 0, "warp", 120), Config), "speed")
	assertFalse(Orders.validate(Orders.torpedo(1, "east", "fast", 120), Config), "angle")
	assertFalse(Orders.validate(Orders.torpedo(1, 0, "fast", 0), Config), "fuse 0")
	assertFalse(Orders.validate(Orders.torpedo(1, 0, "fast", 1.5), Config), "fractional fuse")
	assertFalse(Orders.validate(Orders.torpedo(1, 0, "fast", Config.torpedo.maxFuse + 1), Config), "fuse too long")
end)

test("a launch at tick 30 puts a torpedo at the sub's centre heading along the launch angle", function()
	local ctx = executing(nil, { { tick = 30, order = Orders.torpedo(1, math.rad(10), "slow", 200) } })
	local sub = ctx.pools.subs[1]
	local subBody = Bodies.get(ctx.bodies, sub.bodyId)

	stepTo(ctx, 29)
	assertEqual(0, #ctx.pools.torpedoes)
	stepTo(ctx, 30)

	assertEqual(1, #ctx.pools.torpedoes)
	local torpedo = ctx.pools.torpedoes[1]
	local body = Bodies.get(ctx.bodies, torpedo.bodyId)
	assertEqual(subBody.x, body.x)
	assertEqual(subBody.y, body.y)
	assertNear(Config.torpedo.speeds.slow.speed * math.cos(math.rad(10)), body.vx)
	assertNear(Config.torpedo.speeds.slow.speed * math.sin(math.rad(10)), body.vy)
	assertEqual("player", torpedo.owner)
	assertEqual(30, torpedo.launchTick)
	assertFalse(Bodies.get(ctx.bodies, sub.bodyId) == nil)
	assertFalse(require("src.game.components.tube").ready(sub.tubes[1]), "the tube is reloading")
end)

test("the fuse detonates at exactly launch tick + fuse ticks", function()
	local ctx = executing(nil, { { tick = 10, order = Orders.torpedo(1, -math.rad(20), "fast", 150) } })
	stepTo(ctx, 10)

	local tick = runUntilGone(ctx)

	assertEqual(160, tick)
	assertEqual(160, ctx.blasts[1].tick)
end)

test("rock contact detonates the torpedo early, just short of the rock", function()
	-- Straight down from y = 300 at the seabed (y = 600), with a long fuse.
	local ctx = executing(nil, { { tick = 1, order = Orders.torpedo(1, math.pi / 2, "fast", 600) } })

	local tick, x, y = runUntilGone(ctx)

	assertTrue(tick < 1 + 600, "detonated before its fuse")
	assertEqual(1, #ctx.blasts)
	assertEqual(tick, ctx.blasts[1].tick)
	assertNear(200, ctx.blasts[1].x, 1e-9)
	assertEqual(y, ctx.blasts[1].y, "at its last pose in the water")
	-- Hulls collide cell by cell, so the nose ends within a cell of the seabed line.
	assertTrue(math.abs(y + Config.torpedo.length / 2 - 600) <= Config.grid.cellSize, "nose against the seabed: " .. y)
	assertEqual(x, ctx.blasts[1].x)
end)

test("a torpedo that hits rock before it has run armDistance is a dud", function()
	local lvl = level()
	lvl.subs.player = { x = 200, y = 570, order = lvl.subs.player.order }
	local ctx = executing(lvl, { { tick = 1, order = Orders.torpedo(1, math.pi / 2, "fast", 600) } })

	runUntilGone(ctx)

	assertEqual(0, #ctx.pools.torpedoes, "the torpedo is gone")
	assertEqual(0, #ctx.blasts, "without a blast")
end)

test("a fuse that runs out before the torpedo has armed is a dud", function()
	local ctx = executing(nil, { { tick = 1, order = Orders.torpedo(1, 0, "slow", 5) } })

	local tick = runUntilGone(ctx)

	assertEqual(6, tick)
	assertEqual(0, #ctx.blasts)
end)

test("an armed torpedo detonates on contact with a hull, before its fuse", function()
	-- Due east at the stopped enemy 800 px away; the fuse would carry it past.
	local ctx = executing(nil, { { tick = 1, order = Orders.torpedo(1, 0, "fast", 600) } })

	local tick = runUntilGone(ctx)

	assertTrue(tick < 400, "detonated on the way, at tick " .. tick)
	assertEqual(1, #ctx.blasts)
	local hullFront = 1000 - Config.sub.length / 2
	assertTrue(math.abs(ctx.blasts[1].x + Config.torpedo.length / 2 - hullFront) <= 6, "at the enemy's hull: " .. ctx.blasts[1].x)
end)

test("the firing sub's own hull does not set off its torpedo at launch", function()
	local ctx = executing(nil, { { tick = 1, order = Orders.torpedo(1, 0, "fast", 100) } })

	local tick = runUntilGone(ctx)

	assertEqual(101, tick, "it ran to its fuse")
end)

test("a launch from a tube still reloading fires nothing; the other tube fires", function()
	local ctx = executing(nil, {
		{ tick = 1, order = Orders.torpedo(1, -math.rad(30), "slow", 60) },
		{ tick = 100, order = Orders.torpedo(1, -math.rad(30), "slow", 60) },
		{ tick = 100, order = Orders.torpedo(2, -math.rad(40), "slow", 60) },
	})

	stepTo(ctx, 100)

	assertEqual(1, #ctx.pools.torpedoes, "only tube 2 fired at tick 100")
	assertEqual(100, ctx.pools.torpedoes[1].launchTick)
	assertEqual(Config.tubes.reloadTicks - 99, ctx.pools.subs[1].tubes[1].reload)
end)

-- Steps to `tick`, collecting every contact each sub's perception gains as it
-- arrives (contacts fade, so a late snapshot would miss early ones).
local function arrivalsUntil(ctx, tick)
	local arrivals = { player = {}, enemy = {} }
	while ctx.tick < tick do
		Match.step(ctx)
		for _, sub in ipairs(ctx.pools.subs) do
			for _, c in ipairs(sub.perception.contacts) do
				if c.arrivalTick == ctx.tick then
					local list = arrivals[sub.slot]
					list[#list + 1] = c
				end
			end
		end
	end
	return arrivals
end

-- On how many distinct ticks `contacts` of `kind` at `level` arrived.
local function heardOn(contacts, kind, level)
	local ticks, n = {}, 0
	for _, c in ipairs(contacts) do
		if c.kind == kind and c.level == level and not ticks[c.arrivalTick] then
			ticks[c.arrivalTick] = true
			n = n + 1
		end
	end
	return n
end

test("both observers hear a running torpedo, its launch and its detonation at their own levels", function()
	-- Fired steeply up from the stopped (silent) player; detonates at its fuse.
	local ctx = executing(nil, { { tick = 1, order = Orders.torpedo(1, -math.rad(60), "fast", 60) } })

	local arrivals = arrivalsUntil(ctx, 400)

	local t = Config.torpedo
	for _, slot in ipairs({ "player", "enemy" }) do
		assertEqual(1, heardOn(arrivals[slot], "noise", t.launchNoise), slot .. " heard the launch")
		assertTrue(heardOn(arrivals[slot], "noise", t.speeds.fast.noise) >= 30, slot .. " heard the run")
		assertEqual(1, heardOn(arrivals[slot], "blast", t.blastNoise), slot .. " heard the blast")
	end
end)

test("a ping echoes off a running torpedo's hull", function()
	-- The enemy fires west at the player; the player pings at the same tick.
	local ctx = executing(
		nil,
		{ { tick = 1, order = Orders.ping() } },
		{ { tick = 1, order = Orders.torpedo(1, math.pi, "slow", 600) } }
	)

	-- The wavefront (1 cell/tick) meets the torpedo (0.5 cells/tick) near
	-- tick 133; the echo is back by about tick 266.
	stepTo(ctx, 300)

	-- Only the torpedo is in open water between the subs at this depth
	-- (cells 100..240, rows 70..80); the seabed is row 151.
	local found = false
	for _, c in ipairs(ctx.pools.subs[1].perception.contacts) do
		if c.kind == "echo" and c.x > 100 and c.x < 240 and c.y > 70 and c.y < 80 then
			found = true
		end
	end
	assertTrue(found, "an echo came back from the torpedo")
end)

local Predict = require("src.game.predict")

-- The preview of `order` launched at `tick` by the player following `course`
-- (one turn of orders), and the same turn run for real: the torpedo's
-- position after every tick of its run and the blasts.
local function previewAndRun(lvl, course, tick, order)
	local ctx = Match.new(lvl or level(), Config, 1, { ai = false })
	local orders = { course, { tick = tick, order = order } }
	local path = Predict.path(ctx, "player", orders)
	local preview = Predict.torpedo(ctx, path[tick].x, path[tick].y, order)

	Turn.submit(ctx, "player", orders)
	Turn.submit(ctx, "enemy", {})
	stepTo(ctx, tick)
	local torpedo = ctx.pools.torpedoes[1]
	local body = Bodies.get(ctx.bodies, torpedo.bodyId)
	local run = {}
	while not torpedo.dead do
		Match.step(ctx)
		run[#run + 1] = { x = body.x, y = body.y }
	end
	return preview, run, ctx
end

test("the preview's line is the torpedo's actual run and its fuse point is the actual blast", function()
	local course = { tick = 1, order = Orders.course("east", math.rad(20), "full") }
	local order = Orders.torpedo(2, -math.rad(15), "slow", 200)

	local preview, run, ctx = previewAndRun(nil, course, 90, order)

	assertEqual("fuse", preview.ends)
	assertEqual(200, preview.endTick)
	assertEqual(#run, preview.endTick)
	for k = 1, #run - 1 do
		assertEqual(run[k].x, preview.points[k].x, "x after " .. k .. " ticks")
		assertEqual(run[k].y, preview.points[k].y, "y after " .. k .. " ticks")
	end
	assertEqual(ctx.blasts[1].x, preview.detonation.x)
	assertEqual(ctx.blasts[1].y, preview.detonation.y)
	assertTrue(#preview.points > preview.endTick, "the line runs on past the fuse, for moving the fuse marker")
end)

test("the preview stops at rock where the torpedo does", function()
	local course = { tick = 1, order = Orders.course("east", 0, "half") }
	local order = Orders.torpedo(1, math.rad(70), "fast", 800)

	local preview, run, ctx = previewAndRun(nil, course, 30, order)

	assertEqual("rock", preview.ends)
	assertEqual(#run, preview.endTick)
	assertEqual(preview.endTick, #preview.points, "the line ends at the rock")
	assertEqual(ctx.blasts[1].x, preview.detonation.x)
	assertEqual(ctx.blasts[1].y, preview.detonation.y)
end)

test("the preview shows a dud when the run ends before the torpedo arms", function()
	local course = { tick = 1, order = Orders.course("east", 0, "stop") }

	local preview, _, ctx = previewAndRun(nil, course, 1, Orders.torpedo(1, 0, "slow", 10))

	assertEqual("fuse", preview.ends)
	assertEqual(nil, preview.detonation)
	assertEqual(0, #ctx.blasts)
end)

test("previewing a torpedo changes nothing in the match", function()
	local ctx = Match.new(level(), Config, 1, { ai = false })
	local slots = ctx.bodies.slotCount

	Predict.torpedo(ctx, 200, 300, Orders.torpedo(1, 0, "fast", 300))

	assertEqual(slots, ctx.bodies.slotCount)
	assertEqual(0, #ctx.pools.torpedoes)
	assertEqual(0, #ctx.blasts)
end)
