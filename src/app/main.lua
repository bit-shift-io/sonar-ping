-- LÖVE callbacks: virtual-resolution letterboxing and the fixed-timestep
-- accumulator. This is the only module `main.lua` requires; every other
-- app-layer module hangs off it. No sim/game/core module may require
-- anything from here (see docs/ARCHITECTURE.md "Layers").
local Screen = require("src.app.screen")
local SonarView = require("src.app.render.sonar_view")
local Debug = require("src.app.render.debug")
local Input = require("src.app.input")
local PlanState = require("src.app.states.plan_state")
local MatchEnd = require("src.app.render.match_end")
local Match = require("src.game.match")
local Config = require("src.game.config")
local Trench = require("src.game.levels.trench")

local App = {}

App.match = nil
App.state = nil -- PlanState or ExecuteState; each hands over to the other
App.input = Input.new()

local function findArg(args, pattern)
	for _, a in ipairs(args or {}) do
		local value = a:match(pattern)
		if value then
			return value
		end
	end
	return nil
end

function love.load(args)
	-- e2e=<path/to/scenario_test.lua>: hand control to the e2e runner, which
	-- defines its own love.update/love.draw/love.quit (tests/e2e/run.lua).
	local e2eTestFile = findArg(args, "^e2e=(.+)$")
	if e2eTestFile then
		local E2ERunner = require("tests.e2e.run")
		E2ERunner.start(e2eTestFile, args)
		return
	end

	love.graphics.setBackgroundColor(0, 0, 0)
	-- seed=N fixes the match seed; otherwise each launch picks one (wall-clock is
	-- fine here: the app layer is outside the deterministic sim).
	App.seed = tonumber(findArg(args, "^seed=(.+)$")) or os.time()
	App.newMatch(App.seed)
end

function App.newMatch(seed)
	App.match = Match.new(Trench, Config, seed)
	App.state = PlanState.new(App.match, "player")
end

function love.keypressed(key)
	Input.keypressed(App.input, key)
	-- Once the match is decided, the restart key starts a new one (next seed).
	if key == MatchEnd.RESTART_KEY and App.match.result then
		App.seed = App.seed + 1
		App.newMatch(App.seed)
	end
end

-- Mouse events reach the current state in world px (the screen fit undone).
-- The execute state has no mouse handlers, so it takes no input.
local function forwardMouse(name, x, y, ...)
	if App.state[name] then
		local fit = Screen.fit(love.graphics.getDimensions())
		local wx, wy = Screen.toVirtual(fit, x, y)
		App.state[name](App.state, wx, wy, ...)
	end
end

function love.mousepressed(x, y, button)
	forwardMouse("mousepressed", x, y, button)
end

function love.mousemoved(x, y)
	forwardMouse("mousemoved", x, y)
end

function love.mousereleased(x, y, button)
	forwardMouse("mousereleased", x, y, button)
end

-- The states own the fixed-timestep accumulator: only the execute state steps
-- the match.
function love.update(dt)
	App.state = App.state:update(dt) or App.state
end

function love.draw()
	local windowWidth, windowHeight = love.graphics.getDimensions()
	local fit = Screen.fit(windowWidth, windowHeight)

	love.graphics.clear(0, 0, 0, 1)
	love.graphics.push()
	love.graphics.translate(fit.offsetX, fit.offsetY)
	love.graphics.scale(fit.scale)
	-- The player sees only their own perception (as of the scrubbed tick while
	-- the replay is open); F3 adds true state on top, except during a replay,
	-- since it would show the current state, not the replayed one.
	local replay = App.state.replayPerception and App.state:replayPerception()
	SonarView.draw(replay or Match.perceptionOf(App.match, "player"), App.match.grid.cellSize)
	App.state:draw()
	if App.input.debug and not replay then
		Debug.draw(App.match)
	end
	love.graphics.pop()
end

return App
