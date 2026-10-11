-- The camera zooms and pans the world while buttons and the timeline stay put
-- in screen space, in the plan and the execute phase. Captures frames at 1x
-- and 3x for review.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Camera = require("src.app.camera")
local Config = require("src.game.config")
local Trench = require("src.game.levels.trench")

local function render(game)
	local canvas = love.graphics.newCanvas(1280, 720)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	game:draw()
	love.graphics.setCanvas()
	return canvas:newImageData()
end

local function brightness(data, rect)
	local best = 0
	for px = rect.x + 1, rect.x + rect.w - 1, 2 do
		local r, g, b = data:getPixel(px, rect.y)
		best = math.max(best, r + g + b)
	end
	return best
end

-- Zooms 3x about the player's sub.
local function zoomOnSub(game)
	local sx, sy = game.state:subPosition()
	game:wheelmoved(sx, sy, math.log(3) / math.log(Config.camera.wheelStep))
	return sx, sy
end

test("plan phase at 1x and 3x: the buttons stay where they are and the sub stays under the cursor", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	local execute = game.state:executeButton()
	Capture.capture("camera_plan_1x")
	local before = brightness(render(game), execute)

	local sx, sy = zoomOnSub(game)
	Capture.capture("camera_plan_3x")

	assertNear(3, game.camera.zoom, 1e-9)
	local wx, wy = Camera.toWorld(game.camera, sx, sy)
	assertNear(sx, wx, 1e-6)
	assertNear(sy, wy, 1e-6)
	assertTrue(before > 0.5, "the execute button is drawn at 1x")
	assertTrue(brightness(render(game), execute) > 0.5, "the execute button is drawn at the same place at 3x")
end)

test("execute phase at 3x: the timeline strip stays in screen space", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	zoomOnSub(game)
	local b = game.state:executeButton()
	game:mousepressed(b.x + b.w / 2, b.y + b.h / 2, 1)
	game:mousereleased(b.x + b.w / 2, b.y + b.h / 2, 1)
	FrameStepper.step(game, 100)
	assertEqual("execute", game.state.phase)
	Capture.capture("camera_execute_3x")

	local strip = require("src.app.render.timeline").rect()
	assertTrue(brightness(render(game), { x = strip.x, y = strip.y, w = strip.w, h = 0 }) > 0.5, "the strip's top edge is drawn")
end)
