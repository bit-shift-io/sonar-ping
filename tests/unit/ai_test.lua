-- The AI's behaviour, seen the only way it acts: the orders it submits for the
-- enemy slot each plan phase (ctx.turn.queues.enemy), decided from what the
-- enemy sub has heard. The player is scripted.
local Match = require("src.game.match")
local Config = require("src.game.config")
local Turn = require("src.game.turn")
local Orders = require("src.game.orders")
local Ai = require("src.game.ai.ai")

-- Flat seabed at y = 600; player and enemy level with each other, 800 px
-- (200 cells) apart in open water. `playerSpeed` and `enemySpeed` default to
-- "stop" (silent).
local function level(playerSpeed, enemySpeed)
	return {
		seabed = { { x = 0, y = 600 }, { x = 1280, y = 600 } },
		subs = {
			player = { x = 200, y = 300, order = Orders.course("east", 0, playerSpeed or "stop") },
			enemy = { x = 1000, y = 300, order = Orders.course("west", 0, enemySpeed or "stop") },
		},
	}
end

-- Plays one turn with `playerOrders`; afterwards the AI has planned the next.
local function playTurn(ctx, playerOrders)
	Turn.submit(ctx, "player", playerOrders or {})
	while Match.step(ctx) do
	end
end

local function ofKind(entries, kind)
	local found = {}
	for _, entry in ipairs(entries) do
		if entry.order.kind == kind then
			found[#found + 1] = entry
		end
	end
	return found
end

test("with nothing heard yet the AI listens: it submits no orders", function()
	local ctx = Match.new(level(), Config, 1)

	assertEqual(0, #ctx.turn.queues.enemy)
end)

test("the AI closes on the origin of the player's ping", function()
	local ctx = Match.new(level(), Config, 1)

	playTurn(ctx, { { tick = 1, order = Orders.ping() } })

	local courses = ofKind(ctx.turn.queues.enemy, "course")
	assertEqual(1, #courses)
	assertEqual("west", courses[1].order.heading, "towards the ping at x = 200")
	assertNear(0, courses[1].order.dive, 0.05, "level with it")
	assertEqual(Config.ai.closeSpeed, courses[1].order.speed)
end)

test("the AI ignores its own noise: a lone sub sailing on hears no contact to close on", function()
	local ctx = Match.new(level("stop", "slow"), Config, 1)

	playTurn(ctx)

	assertEqual(0, #ofKind(ctx.turn.queues.enemy, "course"))
end)

-- Plays silent turns until `config.ai.staleTicks` have passed with nothing
-- heard (several turns: staleness is time, not turns).
local function playUntilStale(ctx)
	while ctx.tick < Config.ai.staleTicks do
		assertEqual(0, #ofKind(ctx.turn.queues.enemy, "ping"), "pinged after only " .. ctx.tick .. " silent ticks")
		playTurn(ctx)
	end
end

test("after enough silent turns the AI's contacts are stale, so it pings", function()
	local ctx = Match.new(level(), Config, 1)

	playUntilStale(ctx)

	assertEqual(1, #ofKind(ctx.turn.queues.enemy, "ping"))
end)

test("the AI hears echoes of its own ping off the player and closes on them", function()
	local ctx = Match.new(level(), Config, 1)
	playUntilStale(ctx) -- the AI pings at the start of the next turn

	playTurn(ctx)

	local courses = ofKind(ctx.turn.queues.enemy, "course")
	assertEqual(1, #courses)
	assertEqual("west", courses[1].order.heading)
	assertEqual(Config.ai.closeSpeed, courses[1].order.speed)
end)

test("a noisy target inside torpedo range draws a predicted shot", function()
	-- The player runs slowly east, 100 cells off: inside config.ai.fireRange.
	local lvl = level("slow")
	lvl.subs.enemy.x = 600
	local ctx = Match.new(lvl, Config, 1)

	playTurn(ctx)

	local shots = ofKind(ctx.turn.queues.enemy, "torpedo")
	assertEqual(1, #shots)
	assertEqual(1, shots[1].tick)
	assertTrue(Orders.validate(shots[1].order, Config))
	assertTrue(math.cos(shots[1].order.angle) < 0, "fired west, at the player")
end)

test("a target heard beyond torpedo range draws no shot", function()
	local ctx = Match.new(level("slow"), Config, 1)

	playTurn(ctx)

	assertEqual(0, #ofKind(ctx.turn.queues.enemy, "torpedo"))
end)

test("the AI fires only from a loaded tube", function()
	local lvl = level("slow")
	lvl.subs.enemy.x = 600
	local ctx = Match.new(lvl, Config, 1, { ai = false })
	local enemy = ctx.pools.subs[2]
	Turn.submit(ctx, "player", {})
	Turn.submit(ctx, "enemy", {})
	while Match.step(ctx) do
	end
	local view = Match.aiView(ctx, enemy)
	view.own.tubes[1].reload = 100

	local shots = ofKind(Ai.plan(Ai.new(1), view), "torpedo")

	assertEqual(1, #shots)
	assertEqual(2, shots[1].order.tube)
end)

test("after hearing a launch the AI evades: full speed, turning away from it, then levels out quietly", function()
	local ctx = Match.new(level(), Config, 1)

	-- Fired away from the enemy, so only the launch noise reaches it.
	playTurn(ctx, { { tick = 1, order = Orders.torpedo(1, math.pi, "slow", 100) } })

	local courses = ofKind(ctx.turn.queues.enemy, "course")
	assertEqual(2, #courses)
	assertEqual(1, courses[1].tick)
	assertEqual(Config.ai.evadeSpeed, courses[1].order.speed)
	assertEqual("east", courses[1].order.heading, "away from the launch at x = 200")
	assertTrue(math.abs(courses[1].order.dive) > 0, "changing depth too")
	assertEqual(Config.ai.evadeTicks, courses[2].tick)
	assertEqual(0, courses[2].order.dive)
	assertEqual(Config.ai.quietSpeed, courses[2].order.speed)
end)

test("the same seed and the same perception give the same orders", function()
	local a = Match.new(level("slow"), Config, 7)
	local b = Match.new(level("slow"), Config, 7)

	playTurn(a, { { tick = 1, order = Orders.torpedo(1, math.pi, "slow", 100) } })
	playTurn(b, { { tick = 1, order = Orders.torpedo(1, math.pi, "slow", 100) } })

	local qa, qb = a.turn.queues.enemy, b.turn.queues.enemy
	assertEqual(#qa, #qb)
	for i = 1, #qa do
		for k, v in pairs(qa[i].order) do
			assertEqual(v, qb[i].order[k])
		end
	end
end)

test("the AI steers clear of the seabed: a standing course into rock is levelled out", function()
	local lvl = level()
	lvl.subs.enemy = { x = 1000, y = 540, order = Orders.course("west", math.rad(30), "half") }

	local ctx = Match.new(lvl, Config, 1)

	local courses = ofKind(ctx.turn.queues.enemy, "course")
	assertEqual(1, #courses)
	assertTrue(courses[1].order.dive <= 0, "no longer diving into the seabed")
	assertEqual("half", courses[1].order.speed, "otherwise as it was")
end)

test("in a pit too narrow to steer clear of the walls the AI stops short of the rock", function()
	-- A 240 px wide shaft; every course the AI could pick hits a wall this turn.
	local lvl = {
		seabed = {
			{ x = 0, y = 100 }, { x = 480, y = 100 }, { x = 481, y = 700 },
			{ x = 720, y = 700 }, { x = 721, y = 100 }, { x = 1280, y = 100 },
		},
		subs = {
			player = { x = 200, y = 40, order = Orders.course("east", 0, "stop") },
			enemy = { x = 600, y = 400, order = Orders.course("east", 0, "half") },
		},
	}

	local ctx = Match.new(lvl, Config, 1)
	Turn.submit(ctx, "player", {})
	local enemy = ctx.pools.subs[2]
	local blocked = false
	while Match.step(ctx) do
		blocked = blocked or require("src.sim.bodies").get(ctx.bodies, enemy.bodyId).blocked
	end

	local stops = {}
	for _, entry in ipairs(ofKind(ctx.orderLog.entries, "course")) do
		if entry.slot == "enemy" and entry.order.speed == "stop" then
			stops[#stops + 1] = entry
		end
	end
	assertEqual(1, #stops, "the AI ordered a stop")
	assertFalse(blocked, "and never touched the rock")
end)

test("a contact gone quiet is closed on near where it was last heard, not extrapolated far along its old course", function()
	-- The player runs east, stops (silent) at x = 240 px on tick 120; the
	-- enemy waits at x = 400 px. Its old course, run on to now, would pass the enemy.
	local lvl = level("slow")
	lvl.subs.enemy.x = 400
	local ctx = Match.new(lvl, Config, 1)

	playTurn(ctx, { { tick = 120, order = Orders.course("east", 0, "stop") } })

	local courses = ofKind(ctx.turn.queues.enemy, "course")
	assertEqual(1, courses[1].tick)
	assertEqual("west", courses[1].order.heading)
end)

test("stopped with nothing to hunt, the AI searches: it sets off quietly towards open water", function()
	local ctx = Match.new(level(), Config, 1)

	playTurn(ctx)

	local courses = ofKind(ctx.turn.queues.enemy, "course")
	assertEqual(1, #courses)
	assertEqual("west", courses[1].order.heading, "from x = 1000 px, towards the middle of the map")
	assertEqual(Config.ai.quietSpeed, courses[1].order.speed)
end)

test("a ridge in the way is climbed over rather than turned away from", function()
	-- The AI searches west from just east of a ridge rising to y = 300.
	local lvl = level()
	lvl.seabed = { { x = 0, y = 600 }, { x = 560, y = 600 }, { x = 640, y = 300 }, { x = 720, y = 600 }, { x = 1280, y = 600 } }
	lvl.subs.enemy = { x = 780, y = 520, order = Orders.course("west", 0, "stop") }
	local ctx = Match.new(lvl, Config, 1)

	playTurn(ctx)

	local courses = ofKind(ctx.turn.queues.enemy, "course")
	assertEqual("west", courses[1].order.heading)
	assertTrue(courses[1].order.dive < 0, "climbing")
end)
