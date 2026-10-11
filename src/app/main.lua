-- LÖVE callbacks: virtual-resolution letterboxing and the fixed-timestep
-- accumulator. This is the only module `main.lua` requires; every other
-- app-layer module hangs off it. No sim/game/core module may require
-- anything from here (see docs/ARCHITECTURE.md "Layers").
local Screen = require("src.app.screen")
local Camera = require("src.app.camera")
local Frame = require("src.app.render.frame")
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
App.camera = Camera.new()

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
	App.camera = Camera.new()
end

function love.keypressed(key)
	Input.keypressed(App.input, key)
	-- Once the match is decided, the restart key starts a new one (next seed).
	if key == MatchEnd.RESTART_KEY and App.match.result then
		App.seed = App.seed + 1
		App.newMatch(App.seed)
	end
end

function love.keyreleased(key)
	Input.keyreleased(App.input, key)
end

-- Mouse events reach Input in screen (virtual) px, the window fit undone; it
-- hands the state both those and the world px under the camera. The execute
-- state has no mouse handlers, so it takes no input.
local function virtualMouse(x, y)
	return Screen.toVirtual(Screen.fit(love.graphics.getDimensions()), x, y)
end

function love.mousepressed(x, y, button)
	local sx, sy = virtualMouse(x, y)
	Input.mousepressed(App.input, App.camera, App.state, sx, sy, button)
end

function love.mousemoved(x, y)
	local sx, sy = virtualMouse(x, y)
	Input.mousemoved(App.input, App.camera, App.state, sx, sy)
end

function love.mousereleased(x, y, button)
	local sx, sy = virtualMouse(x, y)
	Input.mousereleased(App.input, App.camera, App.state, sx, sy, button)
end

-- One wheel notch zooms toward the cursor; same callback on LÖVE 11.5 and 12.
function love.wheelmoved(_, dy)
	local sx, sy = virtualMouse(love.mouse.getPosition())
	Input.wheelmoved(App.input, App.camera, sx, sy, dy)
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
	Frame.draw(App.match, App.state, App.camera, App.input.debug)
	love.graphics.pop()
end

return App
