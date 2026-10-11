-- Scrubbing the last turn in the plan phase shows the player's perception as
-- it stood at each tick: sound that has faded from the live view is back at
-- mid-turn, and the replay never shows true state (even with F3 on).
-- Captures frames at the start, middle and end of a replay.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Match = require("src.game.match")
local Perception = require("src.perception.perception")
local Trench = require("src.game.levels.trench")

local function centre(rect)
	return rect.x + rect.w / 2, rect.y + rect.h / 2
end

local function click(game, x, y)
	game:mousepressed(x, y, 1)
	game:mousereleased(x, y, 1)
end

local function render(game)
	local canvas = love.graphics.newCanvas(1280, 720)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	game:draw()
	love.graphics.setCanvas()
	return canvas:newImageData()
end

local function greenAround(data, x, y, half)
	local best = 0
	for py = math.max(0, math.floor(y - half)), math.min(719, math.floor(y + half)) do
		for px = math.max(0, math.floor(x - half)), math.min(1279, math.floor(x + half)) do
			local _, g = data:getPixel(px, py)
			best = math.max(best, g)
		end
	end
	return best
end

local function scrubTo(game, tick)
	click(game, game.state:scrubX(tick), game.state:timelineRect().y + 30)
end

test("the replay shows sound heard mid-turn that has since faded, and nothing of true state", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	click(game, centre(game.state:speedButton("full")))
	click(game, game.state:tickX(1), game.state:timelineRect().y + 24)
	click(game, centre(game.state:pingButton()))
	game.state:commit()
	FrameStepper.step(game, game.ctx.turn.length)
	local ctx = game.ctx
	local perception = Match.perceptionOf(ctx, "player")
	local first, last = ctx.tick - ctx.turn.length + 1, ctx.tick

	-- A noise contact audible at mid-turn and faded from the live view by now.
	local mid = first + 360
	local faded
	for _, contact in ipairs(Perception.at(perception, mid)) do
		local live = false
		for _, c in ipairs(perception.contacts) do
			live = live or c == contact
		end
		if contact.kind == "noise" and not live then
			faded = contact
			break
		end
	end
	assertTrue(faded ~= nil, "some noise heard mid-turn has faded by the plan phase")
	local px, py = (faded.x - 0.5) * ctx.grid.cellSize, (faded.y - 0.5) * ctx.grid.cellSize
	local liveGreen = greenAround(render(game), px, py, 6)

	click(game, centre(game.state:replayButton()))
	scrubTo(game, first)
	Capture.capture("replay_start")
	scrubTo(game, mid)
	local midGreen = greenAround(render(game), px, py, 6)
	Capture.capture("replay_middle")
	game:keypressed("f3")
	local debugData = render(game)
	game:keypressed("f3")
	scrubTo(game, last)
	Capture.capture("replay_end")

	assertTrue(midGreen > liveGreen + 0.1, "the faded sound glows again at mid-turn: " .. liveGreen .. " -> " .. midGreen)
	-- Debug draws current true state; hidden during a replay, the frame is unchanged.
	scrubTo(game, mid)
	local again = render(game)
	for _, p in ipairs({ { 100, 100 }, { 640, 360 }, { px, py } }) do
		local r1, g1, b1 = again:getPixel(math.floor(p[1]), math.floor(p[2]))
		local r2, g2, b2 = debugData:getPixel(math.floor(p[1]), math.floor(p[2]))
		assertTrue(r1 == r2 and g1 == g2 and b1 == b2, "F3 changes nothing during a replay")
	end
end)
