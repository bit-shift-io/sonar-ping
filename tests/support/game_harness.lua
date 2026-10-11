-- Boots a match the same way src/app/main.lua does, but from a literal level
-- table -- never a file path. Works under plain LuaJIT with no `love` global,
-- because src.game.match has none (docs/ARCHITECTURE.md "Layers"); `game:draw()`
-- does reach into src/app/render (which uses love.*), but that only runs under
-- the e2e tier, which supplies a real `love`.
local Match = require("src.game.match")
local Config = require("src.game.config")
local Frame = require("src.app.render.frame")
local Camera = require("src.app.camera")
local Input = require("src.app.input")
local PlanState = require("src.app.states.plan_state")

local GameHarness = {}

local DEFAULT_SEED = 1

-- opts.config overrides the tuning table (defaults to src/game/config.lua).
-- opts.seed fixes the match's RNG seed; defaults to DEFAULT_SEED so a run is
-- reproducible. opts.real = true additionally announces the started game to
-- the e2e runner via _G.E2E_ON_GAME_STARTED, so love.draw and Capture.capture
-- have something to render.
function GameHarness.startMatch(level, opts)
	opts = opts or {}

	local ctx = Match.new(level, opts.config or Config, opts.seed or DEFAULT_SEED)
	-- Same state flow as the app: plan phase first, then execute, and so on.
	local game = { ctx = ctx, input = Input.new(), camera = Camera.new(), state = PlanState.new(ctx, "player") }

	-- Same key handling as the app's love.keypressed / love.keyreleased.
	function game:keypressed(key)
		Input.keypressed(self.input, key)
	end

	function game:keyreleased(key)
		Input.keyreleased(self.input, key)
	end

	-- Fake mouse: coordinates are screen (virtual) px, what the app passes on
	-- after undoing the screen fit; Input adds the world pair under the camera.
	-- Forwarded only if the current state takes input.
	function game:mousepressed(x, y, button)
		Input.mousepressed(self.input, self.camera, self.state, x, y, button)
	end

	function game:mousemoved(x, y)
		Input.mousemoved(self.input, self.camera, self.state, x, y)
	end

	function game:mousereleased(x, y, button)
		Input.mousereleased(self.input, self.camera, self.state, x, y, button)
	end

	-- Wheel notches (positive = in) at screen point (x, y).
	function game:wheelmoved(x, y, notches)
		Input.wheelmoved(self.input, self.camera, x, y, notches)
	end

	-- One frame per call; FrameStepper always passes 1/60 s, so an execute
	-- phase runs one tick per call and a plan phase none.
	function game:update(dt)
		self.state = self.state:update(dt) or self.state
	end

	function game:draw()
		Frame.draw(ctx, self.state, self.camera, self.input.debug)
	end

	if opts.real and _G.E2E_ON_GAME_STARTED then
		love.graphics.setBackgroundColor(0, 0, 0, 1)
		_G.E2E_ON_GAME_STARTED(game)
	end

	return game
end

return GameHarness
