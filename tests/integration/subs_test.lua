local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Trench = require("src.game.levels.trench")

test("on the trench level both subs sail their starting orders for ten seconds of a turn", function()
	local game = GameHarness.startMatch(Trench)
	game.state:commit() -- what clicking Execute does with an unchanged plan
	local player, enemy = game.ctx.pools.subs[1], game.ctx.pools.subs[2]
	local px, ex = Bodies.get(game.ctx.bodies, player.bodyId).x, Bodies.get(game.ctx.bodies, enemy.bodyId).x

	FrameStepper.step(game, 600)

	assertTrue(Bodies.get(game.ctx.bodies, player.bodyId).x > px + 100, "player sailed east")
	assertTrue(Bodies.get(game.ctx.bodies, enemy.bodyId).x < ex - 100, "enemy sailed west")
end)

test("the debug key toggles the overlay flag on the running game", function()
	local game = GameHarness.startMatch(Trench)

	game:keypressed("f3")
	assertTrue(game.input.debug)
	game:keypressed("f3")
	assertFalse(game.input.debug)
end)
