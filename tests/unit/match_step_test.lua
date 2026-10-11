local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local Collide = require("src.sim.collide")
local Grid = require("src.sim.grid")
local SubSystem = require("src.game.systems.sub_system")
local Turn = require("src.game.turn")
local Orders = require("src.game.orders")
local Play = require("tests.support.play")

-- Flat seabed at y = 600 (row 151); open water above it.
local function level(overrides)
	local t = {
		seabed = { { x = 0, y = 600 }, { x = 1280, y = 600 } },
		subs = {
			player = { x = 200, y = 300, order = { kind = "course", heading = "east", dive = 0, speed = Config.speeds.full.speed } },
			enemy = { x = 1000, y = 300, order = { kind = "course", heading = "west", dive = 0, speed = Config.speeds.slow.speed } },
		},
	}
	for k, v in pairs(overrides or {}) do
		t[k] = v
	end
	return t
end

-- A match already in the execute phase of turn 1, both slots with no new orders,
-- so each sub keeps its starting order.
local function executing(lvl, seed)
	local ctx = Match.new(lvl, Config, seed or 1, { ai = false })
	Turn.submit(ctx, "player", {})
	Turn.submit(ctx, "enemy", {})
	return ctx
end

local function bodyOf(ctx, sub)
	return Bodies.get(ctx.bodies, sub.bodyId)
end

test("Match.new spawns the player and the enemy sub from the level table", function()
	local ctx = Match.new(level(), Config, 1, { ai = false })

	assertEqual(2, #ctx.pools.subs)
	local player, enemy = ctx.pools.subs[1], ctx.pools.subs[2]
	assertEqual("player", player.slot)
	assertEqual("enemy", enemy.slot)
	assertNear(200, bodyOf(ctx, player).x, 0.0001)
	assertNear(1000, bodyOf(ctx, enemy).x, 0.0001)
	assertTrue(#player.hull.cells > 1, "a hull is a multi-cell shape")
end)

test("both subs move per their starting orders", function()
	local ctx = executing(level())
	local player, enemy = bodyOf(ctx, ctx.pools.subs[1]), bodyOf(ctx, ctx.pools.subs[2])

	for _ = 1, 60 do
		Match.step(ctx)
	end

	assertNear(200 + Config.speeds.full.speed, player.x, 0.01)
	assertTrue(enemy.x < 1000, "the enemy follows its own starting order")
	assertNear(1000 - Config.speeds.slow.speed, enemy.x, 0.5)
end)

test("a sub stores its speed setting's noise level for perception to read", function()
	local ctx = executing(level())

	Match.step(ctx)

	assertEqual(Config.speeds.full.noise, ctx.pools.subs[1].noise)
	assertEqual(Config.speeds.slow.noise, ctx.pools.subs[2].noise)
end)

test("a sub's hull cells follow it each tick and lie in water", function()
	local ctx = executing(level())
	local sub = ctx.pools.subs[1]
	local before = sub.hull.cells[1].cx

	for _ = 1, 30 do
		Match.step(ctx)
	end

	assertTrue(sub.hull.cells[1].cx > before, "hull cells moved east")
	for _, c in ipairs(sub.hull.cells) do
		assertEqual(Grid.WATER, Grid.get(ctx.grid, c.cx, c.cy))
	end
end)

test("a sub ordered to dive stops on the seabed instead of passing through it", function()
	local lvl = level()
	lvl.subs.player = { x = 200, y = 560, order = { kind = "course", heading = "east", dive = math.rad(30), speed = Config.speeds.full.speed } }
	local ctx = executing(lvl)
	local body = bodyOf(ctx, ctx.pools.subs[1])

	Play.steps(ctx, 600)

	assertTrue(body.blocked)
	assertFalse(Collide.blocked(ctx.grid, body), "the sub rests in water")
end)

test("a spawn order that fails validation is rejected by Match.new", function()
	local lvl = level()
	lvl.subs.enemy.order.speed = "ludicrous"

	assertFalse(pcall(Match.new, lvl, Config, 1))
end)

test("the same seed and starting orders give identical subs after 300 ticks", function()
	local a, b = executing(level(), 7), executing(level(), 7)

	for _ = 1, 300 do
		Play.advance(a)
		Play.advance(b)
	end

	for i = 1, 2 do
		local ba, bb = bodyOf(a, a.pools.subs[i]), bodyOf(b, b.pools.subs[i])
		assertEqual(ba.x, bb.x)
		assertEqual(ba.y, bb.y)
		assertEqual(ba.angle, bb.angle)
	end
end)

test("the despawn sweep removes a dead sub from its pool and frees its body", function()
	local ctx = executing(level())
	local enemy = ctx.pools.subs[2]
	local id = enemy.bodyId

	SubSystem.kill(ctx, enemy)
	assertEqual(2, #ctx.pools.subs, "kill only marks; the sweep removes")
	Match.step(ctx)

	assertEqual(1, #ctx.pools.subs)
	assertEqual("player", ctx.pools.subs[1].slot)
	assertEqual(nil, Bodies.get(ctx.bodies, id))
end)

-- A match whose subs both start with `speed`, on the flat test level.
local function executingAt(speed)
	local lvl = level()
	lvl.subs.player.order.speed = speed
	lvl.subs.enemy.order.speed = speed
	return executing(lvl)
end

test("every sub is an observer with its own perception", function()
	local ctx = executing(level())

	assertTrue(Match.perceptionOf(ctx, "player") ~= nil)
	assertTrue(Match.perceptionOf(ctx, "enemy") ~= nil)
	assertTrue(Match.perceptionOf(ctx, "player") ~= Match.perceptionOf(ctx, "enemy"))
end)

test("stopped subs are silent: nobody perceives anything", function()
	local ctx = executingAt(Config.speeds.stop.speed)

	Play.steps(ctx, 400)

	assertEqual(0, #Match.perceptionOf(ctx, "player").contacts)
	assertEqual(0, #Match.perceptionOf(ctx, "enemy").contacts)
end)

test("only a sub's aft (propeller and engine) cells emit noise", function()
	local ctx = executingAt(Config.speeds.slow.speed)
	local sub = ctx.pools.subs[1]
	local body = bodyOf(ctx, sub)

	local cells = SubSystem.noisyCells(ctx, sub)

	assertTrue(#cells > 0 and #cells < #sub.hull.cells)
	for _, c in ipairs(cells) do
		local wx = Grid.cellToWorld(ctx.grid, c.cx, c.cy)
		assertTrue(wx < body.x, "an east-heading sub's noise is astern")
	end
end)

test("the player hears the enemy only after sound has crossed the gap", function()
	local lvl = level()
	lvl.subs.player.order.speed = Config.speeds.stop.speed
	local ctx = executing(lvl)
	local player = bodyOf(ctx, ctx.pools.subs[1])
	local enemy = bodyOf(ctx, ctx.pools.subs[2])
	local soundPxPerTick = Config.perception.soundSpeed * Config.dt
	-- Its noise comes from within half a hull length of its centre.
	local halfLength = Config.sub.length / 2
	local earliest = (enemy.x - player.x - halfLength) / soundPxPerTick
	local latest = (enemy.x - player.x + halfLength) / soundPxPerTick + 1

	local first = nil
	for _ = 1, 400 do
		Play.advance(ctx)
		if not first and #Match.perceptionOf(ctx, "player").contacts > 0 then
			first = ctx.tick
		end
	end

	assertTrue(first ~= nil, "the enemy's noise arrives")
	assertTrue(first >= earliest, "arrived at tick " .. first .. ", before " .. earliest)
	assertTrue(first <= latest, "arrived at tick " .. first .. ", after " .. latest)
end)

-- Both subs stopped (silent), the player pinging at tick 1 of turn 1.
local function pingingMatch()
	local lvl = level()
	lvl.subs.player.order.speed = Config.speeds.stop.speed
	lvl.subs.enemy.order.speed = Config.speeds.stop.speed
	local ctx = Match.new(lvl, Config, 1, { ai = false })
	Turn.submit(ctx, "player", { { tick = 1, order = Orders.ping() } })
	Turn.submit(ctx, "enemy", {})
	return ctx
end

local function contactsOfKind(perception, kind)
	local found = {}
	for _, c in ipairs(perception.contacts) do
		if c.kind == kind then
			found[#found + 1] = c
		end
	end
	return found
end

test("a ping order is valid and leaves the helm alone", function()
	assertTrue(Orders.validate(Orders.ping(), Config))
	local ctx = pingingMatch()
	local helm = ctx.pools.subs[1].helm
	local speed, heading = helm.speed, helm.heading

	Match.step(ctx)

	assertEqual(speed, helm.speed)
	assertEqual(heading, helm.heading)
end)

test("a ping fires at its tick and every observer perceives its origin, the farther later", function()
	local ctx = pingingMatch()
	local gapCells = (1000 - 200) / Config.grid.cellSize

	for _ = 1, 210 do
		Match.step(ctx)
	end

	local own = contactsOfKind(Match.perceptionOf(ctx, "player"), "ping")
	local heard = contactsOfKind(Match.perceptionOf(ctx, "enemy"), "ping")
	assertEqual(1, #own, "the pinger hears its own ping")
	assertTrue(own[1].arrivalTick <= 2)
	assertEqual(1, #heard, "the enemy hears the ping")
	assertNear(1 + gapCells, heard[1].arrivalTick, 1)
	assertNear(200 / Config.grid.cellSize + 0.5, heard[1].x, 0.5, "the enemy learns the origin exactly")
end)

test("a ping's echoes return the seabed and the enemy hull to the pinger, not its own hull", function()
	local ctx = pingingMatch()
	local enemyBody = bodyOf(ctx, ctx.pools.subs[2])
	local ex, ey = enemyBody.x / Config.grid.cellSize + 0.5, enemyBody.y / Config.grid.cellSize + 0.5

	Play.steps(ctx, 430)

	local seabed, hull = 0, 0
	for _, c in ipairs(contactsOfKind(Match.perceptionOf(ctx, "player"), "echo")) do
		if c.y == 151 then
			seabed = seabed + 1
		elseif math.abs(c.x - ex) <= 5 and math.abs(c.y - ey) <= 2 then
			hull = hull + 1
		else
			assertTrue(false, "unexpected echo at " .. c.x .. "," .. c.y)
		end
	end
	assertTrue(seabed > 20, "the seabed outline returns, got " .. seabed)
	assertTrue(hull > 0, "the enemy hull returns")
end)

test("a spent ping is dropped", function()
	local ctx = pingingMatch()

	Match.step(ctx)
	assertEqual(1, #ctx.pings)
	Play.steps(ctx, 420)

	assertEqual(0, #ctx.pings)
end)
