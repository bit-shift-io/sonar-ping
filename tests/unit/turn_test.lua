local Match = require("src.game.match")
local Config = require("src.game.config")
local Turn = require("src.game.turn")
local Orders = require("src.game.orders")
local OrderLog = require("src.game.order_log")
local Bodies = require("src.sim.bodies")

-- Flat seabed at y = 600; both subs in open water.
local LEVEL = {
	seabed = { { x = 0, y = 600 }, { x = 1280, y = 600 } },
	subs = {
		player = { x = 200, y = 300, order = { kind = "course", heading = "east", dive = 0, speed = "slow" } },
		enemy = { x = 1000, y = 300, order = { kind = "course", heading = "west", dive = 0, speed = "slow" } },
	},
}

-- Config with a short turn so tests can count every tick.
local function shortTurnConfig(ticks)
	return setmetatable({ turn = { ticks = ticks } }, { __index = Config })
end

local function playerBody(ctx)
	return Bodies.get(ctx.bodies, ctx.pools.subs[1].bodyId)
end

test("the default turn length is 720 ticks from config", function()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })

	assertEqual(720, Config.turn.ticks)
	assertEqual(720, ctx.turn.length)
end)

test("a match starts in the plan phase of turn 1", function()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })

	assertEqual("plan", ctx.turn.phase)
	assertEqual(1, ctx.turn.number)
end)

test("no ticks advance and no sub moves during the plan phase", function()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })
	local x = playerBody(ctx).x

	for _ = 1, 100 do
		Match.step(ctx)
	end

	assertEqual(0, ctx.tick)
	assertEqual(x, playerBody(ctx).x)
end)

test("the execute phase starts only once every slot has submitted", function()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })

	Turn.submit(ctx, "player", {})
	assertEqual("plan", ctx.turn.phase)
	Turn.submit(ctx, "enemy", {})

	assertEqual("execute", ctx.turn.phase)
end)

test("execute runs exactly the configured number of ticks, then returns to plan", function()
	local ctx = Match.new(LEVEL, shortTurnConfig(5), 1, { ai = false })
	Turn.submit(ctx, "player", {})
	Turn.submit(ctx, "enemy", {})

	for _ = 1, 4 do
		Match.step(ctx)
	end
	assertEqual("execute", ctx.turn.phase)
	Match.step(ctx)

	assertEqual("plan", ctx.turn.phase)
	assertEqual(2, ctx.turn.number)
	assertEqual(5, ctx.tick)
	Match.step(ctx)
	assertEqual(5, ctx.tick, "the next plan phase is paused too")
end)

test("a course order takes effect at its scheduled tick, not before", function()
	local ctx = Match.new(LEVEL, shortTurnConfig(10), 1, { ai = false })
	Turn.submit(ctx, "player", { { tick = 4, order = Orders.course("east", 0, "stop") } })
	Turn.submit(ctx, "enemy", {})

	for _ = 1, 3 do
		Match.step(ctx)
	end
	assertEqual("slow", ctx.pools.subs[1].helm.speed)
	Match.step(ctx)

	assertEqual("stop", ctx.pools.subs[1].helm.speed)
end)

test("an order goes only to the sub of the slot that submitted it", function()
	local ctx = Match.new(LEVEL, shortTurnConfig(5), 1, { ai = false })
	Turn.submit(ctx, "player", {})
	Turn.submit(ctx, "enemy", { { tick = 1, order = Orders.course("east", 0, "full") } })

	Match.step(ctx)

	assertEqual("slow", ctx.pools.subs[1].helm.speed)
	assertEqual("full", ctx.pools.subs[2].helm.speed)
end)

test("a submitted order with a tick outside the turn is rejected", function()
	local ctx = Match.new(LEVEL, shortTurnConfig(5), 1, { ai = false })

	assertFalse(pcall(Turn.submit, ctx, "player", { { tick = 6, order = Orders.course("east", 0, "slow") } }))
	assertFalse(pcall(Turn.submit, ctx, "player", { { tick = 0, order = Orders.course("east", 0, "slow") } }))
end)

test("a submitted order that fails validation is rejected", function()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })

	assertFalse(pcall(Turn.submit, ctx, "player", { { tick = 1, order = Orders.course("north", 0, "slow") } }))
end)

test("submitting during the execute phase is rejected", function()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })
	Turn.submit(ctx, "player", {})
	Turn.submit(ctx, "enemy", {})

	assertFalse(pcall(Turn.submit, ctx, "player", {}))
end)

test("the match records every order with its turn, tick and slot", function()
	local ctx = Match.new(LEVEL, shortTurnConfig(5), 1, { ai = false })
	Turn.submit(ctx, "player", { { tick = 1, order = Orders.course("east", 0.1, "half") } })
	Turn.submit(ctx, "enemy", { { tick = 3, order = Orders.course("west", 0, "stop") } })
	for _ = 1, 5 do
		Match.step(ctx)
	end
	Turn.submit(ctx, "player", { { tick = 2, order = Orders.course("west", 0, "full") } })
	Turn.submit(ctx, "enemy", {})

	local entries = ctx.orderLog.entries
	assertEqual(3, #entries)
	assertEqual(1, entries[1].turn)
	assertEqual(1, entries[1].tick)
	assertEqual("player", entries[1].slot)
	assertEqual("half", entries[1].order.speed)
	assertEqual("enemy", entries[2].slot)
	assertEqual(3, entries[2].tick)
	assertEqual(2, entries[3].turn)
	assertEqual(2, entries[3].tick)
	assertEqual("west", entries[3].order.heading)
end)

test("the order log hands back one slot's orders for one turn in submit form", function()
	local log = OrderLog.new()
	OrderLog.append(log, { turn = 1, tick = 1, slot = "player", order = Orders.course("east", 0, "half") })
	OrderLog.append(log, { turn = 1, tick = 9, slot = "enemy", order = Orders.course("west", 0, "slow") })
	OrderLog.append(log, { turn = 2, tick = 4, slot = "player", order = Orders.course("west", 0, "full") })

	local turn2 = OrderLog.forTurn(log, 2, "player")

	assertEqual(1, #turn2)
	assertEqual(4, turn2[1].tick)
	assertEqual("full", turn2[1].order.speed)
	assertEqual(0, #OrderLog.forTurn(log, 2, "enemy"))
end)

test("the order log keeps its own copy, so later edits to a submitted order change nothing", function()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })
	local order = Orders.course("east", 0, "half")
	Turn.submit(ctx, "player", { { tick = 1, order = order } })
	Turn.submit(ctx, "enemy", {})

	order.speed = "full"

	assertEqual("half", ctx.orderLog.entries[1].order.speed)
end)
