-- The player's view no longer draws true terrain; the debug view does, over
-- the sonar view. A frame can be captured.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Trench = require("src.game.levels.trench")

local function render(game)
	local canvas = love.graphics.newCanvas(1280, 720)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	game:draw()
	love.graphics.setCanvas()
	return canvas:newImageData()
end

local function same(data, ax, ay, bx, by)
	local r1, g1, b1 = data:getPixel(ax, ay)
	local r2, g2, b2 = data:getPixel(bx, by)
	return r1 == r2 and g1 == g2 and b1 == b2
end

test("the trench map renders and a frame is captured to a non-empty PNG", function()
	local game = GameHarness.startMatch(Trench, { real = true })

	FrameStepper.step(game, 2)
	local path = Capture.capture("map")

	local file = assert(io.open(path, "rb"))
	local bytes = file:read("*a")
	file:close()
	assertEqual("PNG", bytes:sub(2, 4))
	assertTrue(#bytes > 100, "expected a real image, not an empty file")
end)

test("the player's view leaves terrain dark: rock and water look the same", function()
	local game = GameHarness.startMatch(Trench, { real = true })

	local data = render(game)

	-- Open water near the surface vs rock at the bottom edge.
	assertTrue(same(data, 100, 100, 100, 710), "true terrain must not reach the player's view")
end)

test("the debug view draws rock over the sonar view", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	game:keypressed("f3")

	local data = render(game)
	Capture.capture("debug_terrain")

	assertFalse(same(data, 100, 100, 100, 710), "debug view shows rock")
end)
