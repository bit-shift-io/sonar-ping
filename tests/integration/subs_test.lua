local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")
local Trench = require("src.game.levels.trench")

test("on the trench level both subs sail their starting orders for a whole turn", function()
	local game = GameHarness.startMatch(Trench)
	game.state:commit() -- what clicking Execute does with an unchanged plan
	local player, enemy = game.ctx.pools.subs[1], game.ctx.pools.subs[2]
	local px, ex = Bodies.get(game.ctx.bodies, player.bodyId).x, Bodies.get(game.ctx.bodies, enemy.bodyId).x

	FrameStepper.step(game, Config.turn.ticks)

	-- Both start at slow; each covers at least half a turn's run at that speed.
	local run = Config.speeds.slow.speed * Config.turn.ticks * Config.dt / 2
	assertEqual(Config.turn.ticks, game.ctx.tick, "the whole turn ran")
	assertTrue(Bodies.get(game.ctx.bodies, player.bodyId).x > px + run, "player sailed east")
	assertTrue(Bodies.get(game.ctx.bodies, enemy.bodyId).x < ex - run, "enemy sailed west")
end)

test("the debug key toggles the overlay flag on the running game", function()
	local game = GameHarness.startMatch(Trench)

	game:keypressed("f3")
	assertTrue(game.input.debug)
	game:keypressed("f3")
	assertFalse(game.input.debug)
end)
