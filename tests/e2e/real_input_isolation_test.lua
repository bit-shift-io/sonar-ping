-- A scripted e2e run owns the window: real mouse and keyboard events (a user
-- nudging the mouse over the test window) must neither crash the app nor
-- reach the scenario's game. Scenarios drive input through the harness only.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Trench = require("src.game.levels.trench")

test("real mouse events during an e2e run are ignored", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	FrameStepper.step(game, 1)

	local ok, err = pcall(function()
		love.mousemoved(640, 360, 1, 1, false)
		love.mousepressed(640, 360, 1, false, 1)
		love.mousereleased(640, 360, 1, false, 1)
	end)

	assertTrue(ok, "real mouse events raise no error: " .. tostring(err))
end)

test("real key presses during an e2e run do not reach the scenario's game", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	local debugBefore = game.input.debug

	love.keypressed("f3", "f3", false)

	assertEqual(debugBefore, game.input.debug, "debug overlay state unchanged by a real key")
end)
