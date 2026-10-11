-- The player's view shows the enemy only as delayed, range-smeared noise from
-- the player's own perception. The test reads true state only to know where
-- to look.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Bodies = require("src.sim.bodies")
local Trench = require("src.game.levels.trench")

local function render(game)
	local canvas = love.graphics.newCanvas(1280, 720)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	game:draw()
	love.graphics.setCanvas()
	return canvas:newImageData()
end

-- Brightest green in a box of half-size (hw, hh) around (x, y).
local function greenAround(data, x, y, hw, hh)
	local best = 0
	for py = math.max(0, math.floor(y - hh)), math.min(719, math.floor(y + hh)), 2 do
		for px = math.max(0, math.floor(x - hw)), math.min(1279, math.floor(x + hw)), 2 do
			local _, g = data:getPixel(px, py)
			best = math.max(best, g)
		end
	end
	return best
end

local function enemyBody(game)
	return Bodies.get(game.ctx.bodies, game.ctx.pools.subs[2].bodyId)
end

test("the enemy's noise is dark until sound reaches the player, then glows there smeared", function()
	local game = GameHarness.startMatch(Trench, { real = true })
	local startX, startY = enemyBody(game).x, enemyBody(game).y
	game.state:commit()

	-- ~1040 px at 4 px per tick: nothing can have arrived after 120 ticks.
	FrameStepper.step(game, 120)
	local before = greenAround(render(game), startX, startY, 140, 40)

	FrameStepper.play(game, 380) -- tick 500, into turn 2
	local after = greenAround(render(game), startX, startY, 140, 40)
	Capture.capture("passive")
	game:keypressed("f3")
	Capture.capture("passive_debug")

	assertEqual(0, before, "no enemy noise before its sound arrives")
	assertTrue(after > 0.2, "enemy noise glows near where it was, got " .. after)
end)

test("a stopped enemy is silent in the player's view", function()
	local level = {
		seabed = Trench.seabed,
		subs = {
			player = Trench.subs.player,
			enemy = { x = 1160, y = 400, order = { kind = "course", heading = "west", dive = 0, speed = 0 } },
		},
	}
	local game = GameHarness.startMatch(level, { real = true })
	game.state:commit()

	FrameStepper.play(game, 500)

	assertEqual(0, greenAround(render(game), 1160, 400, 140, 40))
end)
