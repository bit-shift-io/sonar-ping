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

test("on the trench the AI closes on a player holding a slow, steady course and sinks it within three turns", function()
	local game = GameHarness.startMatch(Trench, { seed = SEED })
	local start = distance(game)

	-- The unchanged plan each turn: the starting course, slow east.
	local function commit(g)
		g.state:commit()
	end

	play(game, 2, commit)
	assertTrue(distance(game) < start / 3, "the AI closed in over turns 1 and 2")
	play(game, 1, commit)

	assertEqual("enemy", game.ctx.result and game.ctx.result.winner, "the AI sank the player")
	assertEqual(3, game.ctx.turn.number, "in turn 3")
	assertEqual(1, #enemyLaunches(game), "with its first shot")
end)

-- Open water: a flat seabed well below both subs.
local OPEN = {
	seabed = { { x = 0, y = 660 }, { x = 1280, y = 660 } },
	subs = {
		player = { x = 400, y = 330, order = Orders.course("east", 0, "slow") },
		enemy = { x = 1000, y = 330, order = Orders.course("west", 0, "slow") },
	},
}

-- Full speed, weaving: down then up, then about and down then up, every
-- turn, starting the other way each turn.
local function weave(turn)
	local first = turn % 2 == 1 and "east" or "west"
	local second = first == "east" and "west" or "east"
	local dive = math.rad(12)
	return {
		{ tick = 1, order = Orders.course(first, dive, "full") },
		{ tick = 180, order = Orders.course(first, -dive, "full") },
		{ tick = 360, order = Orders.course(second, dive, "full") },
		{ tick = 540, order = Orders.course(second, -dive, "full") },
	}
end

test("a player weaving at full speed makes the AI's straight-line shots miss", function()
	local game = GameHarness.startMatch(OPEN, { seed = SEED })

	play(game, 3, function(g, turn)
		Turn.submit(g.ctx, "player", weave(turn))
	end)

	assertTrue(#enemyLaunches(game) >= 2, "the AI fired at the weaving player")
	assertEqual(#enemyLaunches(game), #game.ctx.blasts, "every shot ran out")
	assertEqual(nil, game.ctx.result, "and the player is still afloat")
end)
