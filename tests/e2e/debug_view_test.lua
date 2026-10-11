-- The debug overlay draws true hull cells over the map only when toggled on.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Trench = require("src.game.levels.trench")

local function pixelAtPlayer(game)
	local sub = game.ctx.pools.subs[1]
	local cell = sub.hull.cells[1]
	local size = game.ctx.grid.cellSize
	local canvas = love.graphics.newCanvas(1280, 720)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	game:draw()
	love.graphics.setCanvas()
	return canvas:newImageData():getPixel((cell.cx - 0.5) * size, (cell.cy - 0.5) * size)
end

test("the debug key shows and hides the player's true hull cells", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	FrameStepper.step(game, 2)

	local offR, offG = pixelAtPlayer(game)
	game:keypressed("f3")
	local onR, onG = pixelAtPlayer(game)
	Capture.capture("debug_on")
	game:keypressed("f3")
	local againR, againG = pixelAtPlayer(game)

	assertFalse(offR == onR and offG == onG, "overlay changes the hull pixel")
	assertTrue(offR == againR and offG == againG, "toggling off restores the plain map")
end)
