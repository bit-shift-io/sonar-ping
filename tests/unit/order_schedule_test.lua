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

-- Steps turn 1 to its tick `tick` (1..turn length).
local function stepTo(ctx, tick)
	assertTrue(tick <= ctx.turn.length, "tick " .. tick .. " is past the turn")
	while ctx.turn.tick < tick do
		assertTrue(Match.step(ctx), "the turn ended before tick " .. tick)
	end
end

test("a course order at tick 240 reaches the helm on tick 240, not 239 or 241", function()
	local ctx = startTurn({ { tick = 240, order = Orders.course("west", 0, Config.speeds.full.speed) } })
	local helm = player(ctx).helm
	local before = helm.speed

	stepTo(ctx, 239)
	assertEqual(before, helm.speed, "unchanged after tick 239")
	stepTo(ctx, 240)

	assertEqual(Config.speeds.full.speed, helm.speed, "applied on tick 240")
	assertEqual("west", helm.heading)
end)

test("a ping order mid-turn fires on its tick and not before", function()
	local tick = Config.turn.ticks / 2
	local ctx = startTurn({ { tick = tick, order = Orders.ping() } })

	stepTo(ctx, tick - 1)
	assertEqual(0, #ctx.pings, "no ping after tick " .. (tick - 1))
	stepTo(ctx, tick)

	assertEqual(1, #ctx.pings)
	assertEqual(tick, ctx.turn.tick)
end)

test("the order log records each order at the tick it was scheduled for", function()
	local ctx = startTurn({
		{ tick = 90, order = Orders.ping() },
		{ tick = 1, order = Orders.course("east", 0, Config.speeds.half.speed) },
		{ tick = Config.turn.ticks, order = Orders.course("west", 0, Config.speeds.slow.speed) },
	})

	local ticks = {}
	for i, entry in ipairs(ctx.orderLog.entries) do
		ticks[i] = entry.tick
	end

	assertEqual("90,1," .. Config.turn.ticks, table.concat(ticks, ","))
end)
