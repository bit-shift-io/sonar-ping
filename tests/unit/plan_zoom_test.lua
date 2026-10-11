local GameHarness = require("tests.support.game_harness")
local Camera = require("src.app.camera")
local Trench = require("src.game.levels.trench")

test("at 2x zoom a course drag solves for the world point under the cursor", function()
	local game = GameHarness.startMatch(Trench)
	local state = game.state
	local sx, sy = state:subPosition()
	game.camera.zoom, game.camera.x, game.camera.y = 2, sx - 200, sy - 150
	local hx, hy = state:handlePosition()
	local targetX, targetY = sx + 225, sy
	local fromX, fromY = Camera.toScreen(game.camera, hx, hy)
	local toX, toY = Camera.toScreen(game.camera, targetX, targetY)

	game:mousepressed(fromX, fromY, 1)
	game:mousemoved(toX, toY)
	game:mousereleased(toX, toY, 1)

	assertEqual("course", state.target and "course")
	assertNear(targetX, state.target.x, 1e-6)
	assertNear(targetY, state.target.y, 1e-6)
end)

test("at 2x zoom the EXECUTE button is still hit at its fixed screen position", function()
	local game = GameHarness.startMatch(Trench)
	game.camera.zoom, game.camera.x, game.camera.y = 2, 300, 100
	local b = game.state:executeButton()

	game:mousepressed(b.x + b.w / 2, b.y + b.h / 2, 1)
	game:mousereleased(b.x + b.w / 2, b.y + b.h / 2, 1)

	assertEqual("execute", game.ctx.turn.phase)
end)

test("at 2x zoom a click on the timeline strip selects the tick under it", function()
	local game = GameHarness.startMatch(Trench)
	local state = game.state
	game.camera.zoom, game.camera.x, game.camera.y = 2, 300, 100

	game:mousepressed(state:tickX(120), state:timelineRect().y + 24, 1)
	game:mousereleased(state:tickX(120), state:timelineRect().y + 24, 1)

	assertEqual(120, state.selected)
end)
