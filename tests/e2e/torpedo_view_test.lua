-- A torpedo planned at the enemy shows its preview line and fuse marker
-- while planning; in the debug view the running torpedo's true path is
-- drawn; when it sinks the enemy the match-end screen appears. Captures a
-- frame of each for review.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Config = require("src.game.config")
local Trench = require("src.game.levels.trench")

-- Trench seabed; the enemy is moved up level with the player, in open water
-- above the ridge's far side, and stopped (it has no orders).
local LEVEL = {
	seabed = Trench.seabed,
	subs = {
		player = Trench.subs.player,
		enemy = { x = 760, y = 300, order = { kind = "course", heading = "west", dive = 0, speed = "stop" } },
	},
}

local function centre(rect)
	return rect.x + rect.w / 2, rect.y + rect.h / 2
end

local function click(game, x, y)
	game:mousepressed(x, y, 1)
	game:mousereleased(x, y, 1)
end

local function drag(game, fromX, fromY, toX, toY)
	game:mousepressed(fromX, fromY, 1)
	game:mousemoved(toX, toY)
	game:mousereleased(toX, toY, 1)
end

local function render(game)
	local canvas = love.graphics.newCanvas(1280, 720)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	game:draw()
	love.graphics.setCanvas()
	return canvas:newImageData()
end

-- Brightest red channel in a box of half-size h around (x, y).
local function redAround(data, x, y, h)
	local best = 0
	for py = math.floor(y - h), math.floor(y + h) do
		for px = math.floor(x - h), math.floor(x + h) do
			local r = data:getPixel(px, py)
			best = math.max(best, r)
		end
	end
	return best
end

test("the torpedo preview, its true path in debug, and the match-end screen are drawn", function()
	local game = GameHarness.startMatch(LEVEL, { real = true })
	local state = game.state

	click(game, centre(state:tubeButton(1)))
	click(game, centre(state:torpedoSpeedButton("fast")))
	local fx, fy = state:fuseMarkerPosition()
	drag(game, fx, fy, 820, 300) -- past the enemy: it strikes the hull first
	fx, fy = state:fuseMarkerPosition()
	local plan = render(game)
	Capture.capture("torpedo_plan")
	assertTrue(redAround(plan, fx, fy, 8) > 0.9, "the fuse marker is drawn at the fuse point")
	local preview = state:torpedoPreview()
	local mid = preview.points[math.floor(preview.endTick / 2)]
	assertTrue(redAround(plan, mid.x, mid.y, 2) > 0.5, "the preview line is drawn")

	click(game, centre(state:executeButton()))
	FrameStepper.step(game, 60)
	game:keypressed("f3")
	Capture.capture("torpedo_running_debug")
	game:keypressed("f3")

	FrameStepper.step(game, Config.turn.ticks)
	assertEqual("player", game.ctx.result.winner)
	local done = render(game)
	Capture.capture("match_end")
	local best = 0
	for y = 255, 265 do -- across the box's top edge (y = 260)
		local _, g = done:getPixel(640, y)
		best = math.max(best, g)
	end
	assertTrue(best > 0.5, "the match-end box is drawn")
end)
