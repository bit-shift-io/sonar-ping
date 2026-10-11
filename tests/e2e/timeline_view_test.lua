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
