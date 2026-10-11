local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Grid = require("src.sim.grid")

local LEVEL = {
	seabed = { { x = 0, y = 600 }, { x = 640, y = 480 }, { x = 1280, y = 600 } },
	subs = {
		player = { x = 100, y = 200, order = { kind = "course", heading = "east", dive = 0, speed = "slow" } },
		enemy = { x = 1100, y = 200, order = { kind = "course", heading = "west", dive = 0, speed = "slow" } },
	},
}

test("a match boots from a literal level table and steps one second of frames", function()
	local game = GameHarness.startMatch(LEVEL)
	game.state:commit() -- what clicking Execute does with an unchanged plan

	FrameStepper.step(game, 60)

	assertEqual(60, game.ctx.tick)
	assertNear(1.0, game.ctx.time, 0.0001)
	assertEqual(Grid.ROCK, Grid.get(game.ctx.grid, 160, 180))
end)
