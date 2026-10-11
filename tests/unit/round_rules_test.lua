-- Match end: a side with no subs left loses. When both sides lose their last
-- sub on the same tick the match is a draw. Once decided, the match stops.
local Match = require("src.game.match")
local Config = require("src.game.config")
local Turn = require("src.game.turn")
local Orders = require("src.game.orders")

-- Stopped subs facing each other 400 px apart, mirror images about x = 640.
local LEVEL = {
	seabed = { { x = 0, y = 600 }, { x = 1280, y = 600 } },
	subs = {
		player = { x = 440, y = 300, order = { kind = "course", heading = "east", dive = 0, speed = Config.speeds.stop.speed } },
		enemy = { x = 840, y = 300, order = { kind = "course", heading = "west", dive = 0, speed = Config.speeds.stop.speed } },
	},
}

local AT_ENEMY = { { tick = 1, order = Orders.torpedo(1, 0, "fast", 160) } }
local AT_PLAYER = { { tick = 1, order = Orders.torpedo(1, math.pi, "fast", 160) } }

-- Steps until the match stops; returns the number of ticks it ran.
local function play(playerOrders, enemyOrders)
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })
	Turn.submit(ctx, "player", playerOrders)
	Turn.submit(ctx, "enemy", enemyOrders)
	while Match.step(ctx) do
	end
	return ctx
end

test("while both sides have a sub the match has no result", function()
	local ctx = play({}, {})

	assertEqual(nil, ctx.result)
	assertEqual("plan", ctx.turn.phase, "the turn ended normally")
end)

test("sinking the enemy's last sub wins the match for the player", function()
	local ctx = play(AT_ENEMY, {})

	assertEqual("player", ctx.result.winner)
	assertFalse(ctx.result.draw)
	assertEqual(ctx.blasts[1].tick, ctx.tick, "the match ended on the tick the enemy sank")
	assertEqual(ctx.tick, ctx.result.tick)
end)

test("losing the player's last sub wins the match for the enemy", function()
	local ctx = play({}, AT_PLAYER)

	assertEqual("enemy", ctx.result.winner)
end)

test("both sides sinking on the same tick is a draw", function()
	local ctx = play(AT_ENEMY, AT_PLAYER)

	assertEqual(2, #ctx.blasts)
	assertEqual(ctx.blasts[1].tick, ctx.blasts[2].tick, "fixture: the torpedoes strike together")
	assertTrue(ctx.result.draw)
	assertEqual(nil, ctx.result.winner)
end)

test("a decided match takes no more ticks and no more orders", function()
	local ctx = play(AT_ENEMY, {})
	local tick = ctx.tick

	assertFalse(Match.step(ctx))
	assertEqual(tick, ctx.tick)
	assertEqual("over", ctx.turn.phase)
	local ok = pcall(Turn.submit, ctx, "player", {})
	assertFalse(ok, "submitting after the end is an error")
end)

test("with two enemies, sinking one leaves the match undecided", function()
	local config = setmetatable({ match = { enemies = 2 } }, { __index = Config })
	local level = { seabed = LEVEL.seabed, subs = LEVEL.subs, extraEnemies = { { x = 840, y = 150, order = LEVEL.subs.enemy.order } } }
	local ctx = Match.new(level, config, 1, { ai = false })
	Turn.submit(ctx, "player", AT_ENEMY)
	Turn.submit(ctx, "enemy", {})
	Turn.submit(ctx, "enemy2", {})
	while Match.step(ctx) do
	end

	assertEqual(1, #ctx.blasts, "fixture: the enemy at y = 300 sank")
	assertEqual(nil, ctx.result)
	assertEqual("plan", ctx.turn.phase)
end)
