-- The AI enemy against a scripted player, run the way the app runs a match:
-- the player commits through the plan screen (or Turn.submit), and the AI
-- fills the enemy slot itself every plan phase -- nothing outside the match
-- asks it to.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Config = require("src.game.config")
local Turn = require("src.game.turn")
local Orders = require("src.game.orders")
local Bodies = require("src.sim.bodies")
local Trench = require("src.game.levels.trench")

local SEED = 20261011

local function distance(game)
	local subs = game.ctx.pools.subs
	local a, b = Bodies.get(game.ctx.bodies, subs[1].bodyId), Bodies.get(game.ctx.bodies, subs[2].bodyId)
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

local function enemyLaunches(game)
	local launches = {}
	for _, entry in ipairs(game.ctx.orderLog.entries) do
		if entry.slot == "enemy" and entry.order.kind == "torpedo" then
			launches[#launches + 1] = entry
		end
	end
	return launches
end

-- Plays turns, each committed by `commit(game, turn)`, until the match ends
-- or `turns` have run; returns the number of turns played.
local function play(game, turns, commit)
	for turn = 1, turns do
		if game.ctx.result then
			return turn - 1
		end
		assertEqual("plan", game.state.phase)
		commit(game, turn)
		FrameStepper.step(game, Config.turn.ticks)
	end
	return turns
end

test("on the trench the AI closes on a player holding a slow, steady course and sinks it within four turns", function()
	local game = GameHarness.startMatch(Trench, { seed = SEED })

	-- The unchanged plan each turn: the starting course, slow east.
	local function commit(g)
		g.state:commit()
	end

	local start = distance(game)
	play(game, 1, commit)
	assertTrue(distance(game) < start, "the AI closed in over turn 1")
	assertEqual(0, #enemyLaunches(game), "with nothing heard yet it holds fire in turn 1")
	play(game, 3, commit)

	assertEqual("enemy", game.ctx.result and game.ctx.result.winner, "the AI sank the player")
	assertTrue(game.ctx.turn.number <= 4, "within four turns")
	local launches = enemyLaunches(game)
	assertTrue(#launches >= 1 and #launches <= 2, "with its first shot or one follow-up")
	assertEqual("slow", launches[1].order.speed, "the first shot is slow: the target is beyond fast range")
end)

-- Open water: a flat seabed well below both subs.
local OPEN = {
	seabed = { { x = 0, y = 660 }, { x = 1280, y = 660 } },
	subs = {
		player = { x = 400, y = 330, order = Orders.course("east", 0, Config.speeds.slow.speed) },
		enemy = { x = 1000, y = 330, order = Orders.course("west", 0, Config.speeds.slow.speed) },
	},
}

-- Full speed, weaving in 3 s legs whatever the turn length: down then up,
-- then about and down then up, starting the other way every four legs.
local LEG = 180

local function legOrder(leg)
	local block, within = math.floor(leg / 4), leg % 4
	local first = block % 2 == 0 and "east" or "west"
	local second = first == "east" and "west" or "east"
	local dive = math.rad(12)
	return Orders.course(within < 2 and first or second, within % 2 == 0 and dive or -dive, Config.speeds.full.speed)
end

-- The weave's orders for the turn after global tick `start`: the leg in
-- effect at its tick 1, then each leg that starts within the turn.
local function weave(start, length)
	local entries = { { tick = 1, order = legOrder(math.floor(start / LEG)) } }
	for tick = 2, length do
		local t = start + tick - 1
		if t % LEG == 0 then
			entries[#entries + 1] = { tick = tick, order = legOrder(t / LEG) }
		end
	end
	return entries
end

test("a player weaving at full speed for 40 s makes the AI's straight-line shots miss", function()
	local game = GameHarness.startMatch(OPEN, { seed = SEED })
	local turns = math.ceil(40 / (Config.turn.ticks * Config.dt))

	assertEqual(turns, play(game, turns, function(g)
		Turn.submit(g.ctx, "player", weave(g.ctx.tick, g.ctx.turn.length))
	end), "every turn ran")

	assertTrue(#enemyLaunches(game) >= 2, "the AI fired at the weaving player")
	assertEqual(#enemyLaunches(game), #game.ctx.blasts, "every shot ran out")
	assertEqual(nil, game.ctx.result, "and the player is still afloat")
end)
