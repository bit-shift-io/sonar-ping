-- Pinging reveals the seabed outline progressively as echoes return, and the
-- enemy hull as a sharp shape; echoes fade. Both subs start stopped so
-- nothing but the ping makes sound until the AI, having heard it, gets under
-- way in turn 2; the hull is checked before that noise can reach the player. The test reads true state only to know where to
-- look.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")
local Trench = require("src.game.levels.trench")

local function stopped(spec)
	return { x = spec.x, y = spec.y, order = { kind = "course", heading = spec.order.heading, dive = 0, speed = Config.speeds.stop.speed } }
end

local LEVEL = {
	seabed = Trench.seabed,
	subs = { player = stopped(Trench.subs.player), enemy = stopped(Trench.subs.enemy) },
}

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
	for py = math.max(0, math.floor(y - hh)), math.min(719, math.floor(y + hh)) do
		for px = math.max(0, math.floor(x - hw)), math.min(1279, math.floor(x + hw)) do
			local _, g = data:getPixel(px, py)
			best = math.max(best, g)
		end
	end
	return best
end

local function centre(rect)
	return rect.x + rect.w / 2, rect.y + rect.h / 2
end

local function pingAndExecute(game)
	local x, y = centre(game.state:pingButton())
	game:mousepressed(x, y, 1)
	game:mousereleased(x, y, 1)
	game.state:commit()
end

-- Seabed below the player (~61 cells from it) and the ridge crest (~82).
local BELOW = { x = 120, y = 548 }
local RIDGE = { x = 440, y = 384 }

test("echoes reveal the seabed progressively, then the enemy hull as a sharp shape, then fade", function()
	local game = GameHarness.startMatch(LEVEL, { real = true })
	-- Where the ping strikes the enemy hull (it lies stopped all of turn 1).
	local body = Bodies.get(game.ctx.bodies, game.ctx.pools.subs[2].bodyId)
	local enemy = { x = body.x, y = body.y }
	pingAndExecute(game)

	FrameStepper.step(game, 100)
	local early = render(game)
	FrameStepper.step(game, 45) -- tick 145
	local nearOnly = render(game)
	FrameStepper.step(game, 155) -- tick 300
	local outline = render(game)
	Capture.capture("echoes_returning")
	game:keypressed("f3")
	Capture.capture("echoes_returning_debug")
	game:keypressed("f3")
	FrameStepper.play(game, 250) -- tick 550, into turn 2 (no ping)
	local hull = render(game)
	Capture.capture("enemy_hull_echo")

	assertEqual(0, greenAround(early, BELOW.x, BELOW.y, 24, 10), "no echo before the sound has gone and returned")
	assertTrue(greenAround(nearOnly, BELOW.x, BELOW.y, 24, 10) > 0.5, "the near seabed has returned")
	assertEqual(0, greenAround(nearOnly, RIDGE.x, RIDGE.y, 12, 8), "the farther ridge has not")
	assertTrue(greenAround(outline, RIDGE.x, RIDGE.y, 12, 8) > 0.5, "the ridge crest returns later")
	assertEqual(0, greenAround(outline, enemy.x, enemy.y, 20, 6), "the enemy hull is too far to have returned yet")

	assertTrue(greenAround(hull, enemy.x, enemy.y, 16, 4) > 0.5, "the enemy hull returns")
	assertEqual(0, greenAround(hull, enemy.x, enemy.y - 16, 30, 6), "with no halo or smear above it")
	assertTrue(
		greenAround(hull, BELOW.x, BELOW.y, 24, 10) < greenAround(nearOnly, BELOW.x, BELOW.y, 24, 10),
		"older echoes are dimmer"
	)

	-- Later turns, no ping: the first echoes pass the fade time and vanish.
	FrameStepper.play(game, 150 + Config.perception.echoFadeTicks - game.ctx.tick)
	assertEqual(0, greenAround(render(game), BELOW.x, BELOW.y, 24, 10), "faded echoes are gone")
end)
