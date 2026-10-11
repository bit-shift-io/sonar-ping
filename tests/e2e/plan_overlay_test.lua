-- The plan phase draws the ghost path with per-second marks; the execute
-- phase does not.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Trench = require("src.game.levels.trench")

local function pixelAt(game, x, y)
	local canvas = love.graphics.newCanvas(1280, 720)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	game:draw()
	love.graphics.setCanvas()
	return canvas:newImageData():getPixel(math.floor(x), math.floor(y))
end

test("the ghost path's two-second mark is drawn while planning and gone while executing", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	local mark = game.state.path[120]

	local pr, pg, pb = pixelAt(game, mark.x, mark.y)
	Capture.capture("plan")
	game.state:commit()
	FrameStepper.step(game, 1)
	local er, eg, eb = pixelAt(game, mark.x, mark.y)
	Capture.capture("execute")

	assertTrue(pg > 0.5 and pg > pr and pg > pb, "the mark is drawn in phosphor green")
	assertFalse(pr == er and pg == eg and pb == eb, "the mark is not drawn during execute")
end)
