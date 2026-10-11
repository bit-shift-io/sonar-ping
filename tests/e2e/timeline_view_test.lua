-- The plan phase shows the timeline strip holding a ping and a course change,
-- with matching markers on the ghost path. Captures a frame for review.
local GameHarness = require("tests.support.game_harness")
local Timeline = require("src.app.render.timeline")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Trench = require("src.game.levels.trench")

local function centre(rect)
	return rect.x + rect.w / 2, rect.y + rect.h / 2
end

local function click(game, x, y)
	game:mousepressed(x, y, 1)
	game:mousereleased(x, y, 1)
end

-- Drags the course handle to (x, y), the course target.
local function steer(game, x, y)
	local hx, hy = game.state:handlePosition()
	game:mousepressed(hx, hy, 1)
	game:mousemoved(x, y)
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

test("the timeline strip and the ghost path markers are drawn for a ping and a course change", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	local state = game.state
	local sx, sy = state:subPosition()
	steer(game, sx + 225, sy)
	click(game, state:tickX(120), state:timelineRect().y + 24)
	local ax, ay = state:anchorPosition()
	steer(game, ax + 100, ay + 40)
	click(game, state:tickX(200), state:timelineRect().y + 24)
	click(game, centre(state:pingButton()))
	Capture.capture("timeline")

	local data = render(game)
	local mx, my = state:tickX(200), Timeline.rowY("ping")
	local best = 0
	for px = math.floor(mx) - 5, math.floor(mx) + 5 do
		for py = my - 6, my + 6 do
			local r, g, b = data:getPixel(px, py)
			best = math.max(best, r + g + b)
		end
	end
	assertTrue(best > 0.5, "the ping marker is drawn on the strip")
	local ghost = state.path[200]
	local gr, gg, gb = data:getPixel(math.floor(ghost.x), math.floor(ghost.y - 6))
	assertTrue(gr + gg + gb > 0.3, "the ping marker is drawn on the ghost path")
end)

test("mid-execute the strip shows the committed ping and the cursor at the turn tick", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	local state = game.state
	click(game, state:tickX(200), state:timelineRect().y + 24)
	click(game, centre(state:pingButton()))
	click(game, centre(state:executeButton()))
	FrameStepper.step(game, 150)
	local execute = game.state
	assertEqual("execute", execute.phase)
	Capture.capture("timeline_execute")

	local data = render(game)
	local mx, my = state:tickX(200), Timeline.rowY("ping")
	local best = 0
	for px = math.floor(mx) - 5, math.floor(mx) + 5 do
		for py = my - 6, my + 6 do
			local r, g, b = data:getPixel(px, py)
			best = math.max(best, r + g + b)
		end
	end
	assertTrue(best > 0.5, "the ping marker is drawn on the execute strip")
	local cx = math.floor(Timeline.tickX(execute:cursorTick(), execute.ctx.turn.length))
	local cy = Timeline.rowY("ping")
	local bright = 0
	for px = cx - 1, cx do
		local r, g, b = data:getPixel(px, cy)
		bright = math.max(bright, r + g + b)
	end
	assertTrue(bright > 1.0, "the cursor line is drawn at the turn tick")
end)

-- Bright pixels in a box: something is drawn there.
local function brightAround(data, x, y, half)
	local best = 0
	for py = math.max(0, math.floor(y - half)), math.min(719, math.floor(y + half)) do
		for px = math.max(0, math.floor(x - half)), math.min(1279, math.floor(x + half)) do
			local r, g, b = data:getPixel(px, py)
			best = math.max(best, r + g + b)
		end
	end
	return best
end

test("on turn 2 the one strip shows the cursor at -4 s, 0 and +3 s, with the projected sub only on the right", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	local state = game.state
	local sx, sy = state:subPosition()
	steer(game, sx + 800, sy)
	state:commit()
	FrameStepper.step(game, game.ctx.turn.length)
	state = game.state
	sx, sy = state:subPosition()
	steer(game, sx + 800, sy)
	local length, y = game.ctx.turn.length, Timeline.Y + 10 -- above the marker rows
	assertEqual(nil, state.replayButton, "there is no REPLAY button")

	local frames = {}
	for _, at in ipairs({ { "timeline_minus_4s", -240 }, { "timeline_0s", 0 }, { "timeline_plus_3s", 180 } }) do
		click(game, Timeline.tickX(at[2], length), y)
		assertEqual(at[2], state.selected)
		Capture.capture(at[1])
		frames[at[1]] = render(game)
	end

	for name, tick in pairs({ timeline_minus_4s = -240, timeline_0s = 0, timeline_plus_3s = 180 }) do
		local data = frames[name]
		local cx = Timeline.tickX(tick, length)
		assertTrue(brightAround(data, cx, Timeline.Y + Timeline.H - 2, 1) > 1.0, name .. ": the cursor line is drawn")
	end
	local px, py = state.path[180].x, state.path[180].y
	assertTrue(brightAround(frames.timeline_plus_3s, px, py, 2) > 0.8, "+3 s marks the sub's projected position")
	assertTrue(brightAround(frames.timeline_minus_4s, px, py, 2) < brightAround(frames.timeline_plus_3s, px, py, 2), "-4 s shows no plan overlay there")
end)
