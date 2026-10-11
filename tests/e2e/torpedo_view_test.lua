-- A torpedo planned at the enemy shows its preview line, aim point and speed
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
		enemy = { x = 460, y = 300, order = { kind = "course", heading = "west", dive = 0, speed = Config.speeds.stop.speed } },
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
	drag(game, 700, 500, 520, 300) -- past the enemy: it strikes the hull first
	local ax, ay = state:aimPoint()
	assertEqual("fast", state.torpedo.order.speed)
	local plan = render(game)
	Capture.capture("torpedo_plan")
	assertTrue(redAround(plan, ax + 8, ay, 2) > 0.9, "the aim point is drawn")
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

-- Counts pixels in the box whose colour is mostly `channel` ("g" or "b").
local function dominantPixels(data, x0, y0, x1, y1, channel)
	local n = 0
	for y = y0, y1 do
		for x = x0, x1 do
			local r, g, b = data:getPixel(x, y)
			if channel == "b" and b > 0.4 and b > g + 0.15 and b > r + 0.3 then
				n = n + 1
			elseif channel == "g" and g > 0.4 and g > b + 0.3 and g > r + 0.3 then
				n = n + 1
			end
		end
	end
	return n
end

test("a torpedo's track draws blue beside a moving sub's green track", function()
	local level = {
		seabed = Trench.seabed,
		subs = {
			player = Trench.subs.player,
			enemy = { x = 760, y = 300, order = { kind = "course", heading = "east", dive = 0, speed = Config.speeds.full.speed } },
		},
	}
	local game = GameHarness.startMatch(level, { real = true })
	local state = game.state

	click(game, centre(state:tubeButton(1)))
	drag(game, 700, 500, 500, 300)
	click(game, centre(state:executeButton()))
	FrameStepper.step(game, 150)

	local frame = render(game)
	Capture.capture("torpedo_blue_beside_sub_green")
	local w, h = frame:getDimensions()
	assertTrue(dominantPixels(frame, 0, 0, w - 1, h - 1, "b") > 0, "the torpedo's contacts draw blue")
	assertTrue(dominantPixels(frame, 0, 0, w - 1, h - 1, "g") > 0, "the sub's contacts draw green")
end)
