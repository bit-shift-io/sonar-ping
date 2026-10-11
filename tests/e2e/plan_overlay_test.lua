-- The plan phase draws the ghost path with per-second marks; the execute
-- phase does not. A course target out of reach is marked apart from where the
-- ghost path ends.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Trench = require("src.game.levels.trench")
local Helm = require("src.game.components.helm")
local Config = require("src.game.config")

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

local function render(game)
	local canvas = love.graphics.newCanvas(1280, 720)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	game:draw()
	love.graphics.setCanvas()
	return canvas:newImageData()
end

-- Brightest red + green within `half` px of (x, y).
local function brightAround(data, x, y, half)
	local best = 0
	for py = math.floor(y - half), math.floor(y + half) do
		for px = math.floor(x - half), math.floor(x + half) do
			local r, g = data:getPixel(px, py)
			best = math.max(best, r + g)
		end
	end
	return best
end

test("a course target out of reach is marked, and so is the end the ghost path reaches", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	local state = game.state
	local sx, sy = state:subPosition()
	local hx, hy = state:handlePosition()
	local tx, ty = sx + 650, sy + 60

	game:mousepressed(hx, hy, 1)
	game:mousemoved(tx, ty)
	game:mousereleased(tx, ty, 1)
	Capture.capture("course_target")

	local _, _, ex, ey = state:courseTarget()
	assertTrue(tx - ex > 100, "the end falls well short of the target")
	local data = render(game)
	-- The target cross, inside the handle ring around it.
	assertTrue(brightAround(data, tx + 3, ty + 3, 1) > 0.5, "the target is marked")
	-- The end ring, beside the ghost path's last point.
	assertTrue(brightAround(data, ex, ey - 5, 1) > 0.5, "the reached end is marked")

	game:mousepressed(tx, ty, 1)
	game:mousemoved(ex, ey)
	game:mousereleased(ex, ey, 1)
	local again = render(game)
	assertTrue(brightAround(again, tx + 3, ty + 3, 1) < 0.3, "the old target is no longer marked")
end)

-- Every love.graphics.print during a draw, with its position.
local function printsOf(game)
	local printed = {}
	local original = love.graphics.print
	love.graphics.print = function(text, x, y, ...)
		printed[#printed + 1] = { text = tostring(text), x = x, y = y }
		return original(text, x, y, ...)
	end
	local ok, err = pcall(render, game)
	love.graphics.print = original
	assertTrue(ok, err)
	return printed
end

local function findPrint(printed, text)
	for _, p in ipairs(printed) do
		if p.text == text then
			return p
		end
	end
end

test("the course handle is labelled with its speed band while dragging", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	local state = game.state
	local sx, sy = state:subPosition()
	local hx, hy = state:handlePosition()

	game:mousepressed(hx, hy, 1)
	game:mousemoved(sx + 650, sy + 60)
	Capture.capture("course_drag")

	local expected = Helm.speedBand(state:course().speed, Config)
	local label = findPrint(printsOf(game), expected)
	assertTrue(label ~= nil, "the drag shows '" .. expected .. "'")
	local hx2, hy2 = state:handlePosition()
	assertTrue(math.abs(label.x - hx2) <= 30 and math.abs(label.y - hy2) <= 30, "the label sits beside the handle")
end)

test("the speed label stays on a course with a target after the drag ends", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	local state = game.state
	local sx, sy = state:subPosition()
	local hx, hy = state:handlePosition()
	local tx, ty = sx + 650, sy + 60

	game:mousepressed(hx, hy, 1)
	game:mousemoved(tx, ty)
	game:mousereleased(tx, ty, 1)

	local expected = Helm.speedBand(state:course().speed, Config)
	assertTrue(findPrint(printsOf(game), expected) ~= nil, "'" .. expected .. "' is still shown")
end)

test("the speed label is hidden when the selected course has no target and nothing is dragged", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	local state = game.state

	assertEqual(nil, state:courseTarget())
	local expected = Helm.speedBand(state:course().speed, Config)
	assertTrue(findPrint(printsOf(game), expected) == nil, "no '" .. expected .. "' label without a target")
end)
