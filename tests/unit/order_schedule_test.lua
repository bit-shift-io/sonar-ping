-- Orders fire at their scheduled tick exactly, not the tick before or after,
-- and the order log keeps the scheduled tick.
local Match = require("src.game.match")
local Config = require("src.game.config")
local Turn = require("src.game.turn")
local Orders = require("src.game.orders")
local Trench = require("src.game.levels.trench")

local function player(ctx)
	return ctx.pools.subs[1]
end

local function startTurn(orders)
	local ctx = Match.new(Trench, Config, 1, { ai = false })
	Turn.submit(ctx, "player", orders)
	Turn.submit(ctx, "enemy", {})
	return ctx
end

local function stepTo(ctx, tick)
	while ctx.turn.tick < tick do
		Match.step(ctx)
	end
end

test("a course order at tick 240 reaches the helm on tick 240, not 239 or 241", function()
	local ctx = startTurn({ { tick = 240, order = Orders.course("west", 0, "full") } })
	local helm = player(ctx).helm
	local before = helm.speed

	stepTo(ctx, 239)
	assertEqual(before, helm.speed, "unchanged after tick 239")
	stepTo(ctx, 240)

	assertEqual("full", helm.speed, "applied on tick 240")
	assertEqual("west", helm.heading)
end)

test("a ping order at tick 360 fires on tick 360 and not before", function()
	local ctx = startTurn({ { tick = 360, order = Orders.ping() } })

	stepTo(ctx, 359)
	assertEqual(0, #ctx.pings, "no ping after tick 359")
	stepTo(ctx, 360)

	assertEqual(1, #ctx.pings)
	assertEqual(360, ctx.turn.tick)
end)

test("the order log records each order at the tick it was scheduled for", function()
	local ctx = startTurn({
		{ tick = 90, order = Orders.ping() },
		{ tick = 1, order = Orders.course("east", 0, "half") },
		{ tick = 600, order = Orders.course("west", 0, "slow") },
	})

	local ticks = {}
	for i, entry in ipairs(ctx.orderLog.entries) do
		ticks[i] = entry.tick
	end

	assertEqual("90,1,600", table.concat(ticks, ","))
end)
