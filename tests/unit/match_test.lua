local Match = require("src.game.match")
local Config = require("src.game.config")
local Grid = require("src.sim.grid")
local Trench = require("src.game.levels.trench")
local Turn = require("src.game.turn")

test("Match.new builds the level grid under plain LuaJIT with no love global", function()
	assertEqual(nil, love, "unit tier must not have a love global")

	local ctx = Match.new(Trench, Config, 1)

	assertEqual(Trench, ctx.level)
	assertEqual(320, ctx.grid.width)
	assertEqual(Grid.WATER, Grid.get(ctx.grid, 1, 1))
	assertEqual(Grid.ROCK, Grid.get(ctx.grid, 1, 180))
	assertEqual(0, ctx.tick)
end)

test("Match.new rejects an invalid level", function()
	local ok = pcall(Match.new, { seabed = {} }, Config, 1)

	assertFalse(ok)
end)

test("Match.step advances the tick and time by one fixed step in the execute phase", function()
	local ctx = Match.new(Trench, Config, 1, { ai = false })
	Turn.submit(ctx, "player", {})
	Turn.submit(ctx, "enemy", {})

	Match.step(ctx)
	Match.step(ctx)

	assertEqual(2, ctx.tick)
	assertNear(2 / 60, ctx.time, 0.000001)
end)

test("Match.new seeds the rng so the same seed gives the same sequence", function()
	local a = Match.new(Trench, Config, 42)
	local b = Match.new(Trench, Config, 42)

	assertEqual(a.rng:next(), b.rng:next())
end)

-- Config with `enemies` enemy subs (config.match.enemies), the rest shipped.
local function withEnemies(n)
	return setmetatable({ match = { enemies = n } }, { __index = Config })
end

local function slotsOf(ctx)
	local slots = {}
	for _, sub in ipairs(ctx.pools.subs) do
		slots[#slots + 1] = sub.slot
	end
	return table.concat(slots, ",")
end

test("in a new match's plan phase the AI has filled the enemy slot, so the player's submit starts the turn", function()
	local ctx = Match.new(Trench, Config, 1)

	assertTrue(ctx.turn.queues.enemy ~= nil, "the AI submitted for its slot")
	Turn.submit(ctx, "player", {})

	assertEqual("execute", ctx.turn.phase)
end)

test("with ai = false Match.new leaves every slot to its caller", function()
	local ctx = Match.new(Trench, Config, 1, { ai = false })

	assertEqual(nil, ctx.turn.queues.enemy)
end)

test("after each turn the AI fills its slot again for the next plan phase", function()
	local ctx = Match.new(Trench, Config, 1)
	Turn.submit(ctx, "player", {})
	while Match.step(ctx) do
	end

	assertEqual("plan", ctx.turn.phase)
	assertEqual(2, ctx.turn.number)
	assertTrue(ctx.turn.queues.enemy ~= nil)
	assertEqual(nil, ctx.turn.queues.player)
end)

test("the enemy count comes from config: each extra enemy gets its own AI slot and the level's next spawn", function()
	local ctx = Match.new(Trench, withEnemies(3), 1)

	assertEqual("player,enemy,enemy2,enemy3", slotsOf(ctx))
	assertEqual("player,enemy,enemy2,enemy3", table.concat(ctx.turn.slots, ","))
	assertTrue(ctx.turn.queues.enemy2 ~= nil and ctx.turn.queues.enemy3 ~= nil, "the AI fills every enemy slot")
	local spawn = Trench.extraEnemies[1]
	local body = require("src.sim.bodies").get(ctx.bodies, ctx.pools.subs[3].bodyId)
	assertEqual(spawn.x, body.x)
	assertEqual(spawn.y, body.y)
end)

test("an extra enemy on a level with no extra spawns starts above the enemy's spawn", function()
	local level = { seabed = Trench.seabed, subs = Trench.subs }

	local ctx = Match.new(level, withEnemies(2), 1)

	local body = require("src.sim.bodies").get(ctx.bodies, ctx.pools.subs[3].bodyId)
	assertEqual(Trench.subs.enemy.x, body.x)
	assertTrue(body.y < Trench.subs.enemy.y, "shifted up, into open water")
end)
