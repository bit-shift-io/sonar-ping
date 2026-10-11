local Match = require("src.game.match")
local Config = require("src.game.config")
local Turn = require("src.game.turn")
local Orders = require("src.game.orders")
local Predict = require("src.game.predict")
local Bodies = require("src.sim.bodies")
local Trench = require("src.game.levels.trench")

-- Flat seabed at y = 600; both subs in open water well above it.
local LEVEL = {
	seabed = { { x = 0, y = 600 }, { x = 1280, y = 600 } },
	subs = {
		player = { x = 200, y = 300, order = { kind = "course", heading = "east", dive = 0, speed = Config.speeds.slow.speed } },
		enemy = { x = 1000, y = 300, order = { kind = "course", heading = "west", dive = 0, speed = Config.speeds.slow.speed } },
	},
}

-- Runs one turn of `orders` for the player and returns the player's true pose
-- after every tick.
local function actualPath(ctx, orders)
	Turn.submit(ctx, "player", orders)
	Turn.submit(ctx, "enemy", {})
	local body = Bodies.get(ctx.bodies, ctx.pools.subs[1].bodyId)
	local path = {}
	while Match.step(ctx) do
		path[#path + 1] = { x = body.x, y = body.y, angle = body.angle }
	end
	return path
end

local function assertSamePath(expected, actual)
	assertEqual(#expected, #actual, "path lengths")
	for i = 1, #expected do
		assertEqual(expected[i].x, actual[i].x, "x at tick " .. i)
		assertEqual(expected[i].y, actual[i].y, "y at tick " .. i)
		assertEqual(expected[i].angle, actual[i].angle, "angle at tick " .. i)
	end
end

test("the projected path has one point per tick of the turn", function()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })

	local path = Predict.path(ctx, "player", {})

	assertEqual(Config.turn.ticks, #path)
end)

test("the projected path matches the sim's actual path for the same orders", function()
	local orders = {
		{ tick = 1, order = Orders.course("east", math.rad(15), Config.speeds.full.speed) },
		{ tick = 240, order = Orders.course("west", math.rad(-10), Config.speeds.half.speed) },
	}
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })

	local predicted = Predict.path(ctx, "player", orders)

	assertSamePath(predicted, actualPath(ctx, orders))
end)

test("the projected path stops at rock where the sub does", function()
	local orders = { { tick = 1, order = Orders.course("east", math.rad(30), Config.speeds.full.speed) } }
	-- The player starts 80 px above the seabed, so a full-speed dive meets it
	-- well within one turn.
	local lvl = { seabed = LEVEL.seabed, subs = { player = { x = 200, y = 520, order = LEVEL.subs.player.order }, enemy = LEVEL.subs.enemy } }
	local ctx = Match.new(lvl, Config, 1, { ai = false })

	local predicted = Predict.path(ctx, "player", orders)

	assertEqual(predicted[#predicted].x, predicted[#predicted - 1].x, "the projection has come to rest")
	assertSamePath(predicted, actualPath(ctx, orders))
end)

test("on the trench map the projection from mid-match still matches the sim", function()
	local ctx = Match.new(Trench, Config, 3, { ai = false })
	actualPath(ctx, { { tick = 100, order = Orders.course("east", math.rad(20), Config.speeds.half.speed) } })
	local orders = { { tick = 1, order = Orders.course("east", math.rad(-25), Config.speeds.full.speed) } }

	local predicted = Predict.path(ctx, "player", orders)

	assertSamePath(predicted, actualPath(ctx, orders))
end)

test("projecting a course changes nothing in the match", function()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })
	local sub = ctx.pools.subs[1]
	local body = Bodies.get(ctx.bodies, sub.bodyId)
	local x, y, angle = body.x, body.y, body.angle

	Predict.path(ctx, "player", { { tick = 1, order = Orders.course("west", math.rad(20), Config.speeds.full.speed) } })

	assertEqual(x, body.x)
	assertEqual(y, body.y)
	assertEqual(angle, body.angle)
	assertEqual("east", sub.helm.heading)
	assertEqual(Config.speeds.slow.speed, sub.helm.speed)
	assertEqual(0, ctx.tick)
end)

test("a three-segment plan with a ping among its orders projects exactly what the sim does", function()
	local orders = {
		{ tick = 1, order = Orders.course("east", math.rad(10), Config.speeds.half.speed) },
		{ tick = 150, order = Orders.ping() },
		{ tick = 100, order = Orders.course("east", math.rad(-20), Config.speeds.full.speed) },
		{ tick = 200, order = Orders.course("west", math.rad(5), Config.speeds.slow.speed) },
	}
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })

	local predicted = Predict.path(ctx, "player", orders)

	assertSamePath(predicted, actualPath(ctx, orders))
end)

test("a course order mid-turn leaves the projection before its tick untouched", function()
	local tick = Config.turn.ticks / 2
	local last = Config.turn.ticks
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })
	local base = { { tick = 1, order = Orders.course("east", 0, Config.speeds.half.speed) } }
	local changed = { base[1], { tick = tick, order = Orders.course("east", math.rad(25), Config.speeds.full.speed) } }

	local before = Predict.path(ctx, "player", base)
	local after = Predict.path(ctx, "player", changed)

	assertEqual(before[tick - 1].x, after[tick - 1].x)
	assertEqual(before[tick - 1].y, after[tick - 1].y)
	assertTrue(after[last].y > before[last].y, "the dive shows up after the order")
end)

test("a path projected from copies of a sub's own body and helm needs only the map and config", function()
	local orders = { { tick = 1, order = Orders.course("east", math.rad(15), Config.speeds.full.speed) } }
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })
	local sub = ctx.pools.subs[1]
	local body = Bodies.get(ctx.bodies, sub.bodyId)
	local own = { x = body.x, y = body.y, angle = body.angle, vx = body.vx, vy = body.vy, angVel = body.angVel, shape = body.shape }
	local helm = { heading = sub.helm.heading, dive = sub.helm.dive, speed = sub.helm.speed, noise = sub.helm.noise }

	local projected = Predict.pathFrom({ config = Config, grid = ctx.grid }, own, helm, orders, Config.turn.ticks)

	assertSamePath(Predict.path(ctx, "player", orders), projected)
	assertEqual(body.x, own.x, "the copies are left as they were")
end)
