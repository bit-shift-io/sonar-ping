-- One frame's layers, shared by src/app/main.lua and the test harness: the
-- world (sonar view, the state's map overlay, the debug overlay) under the
-- camera, then the state's fixed screen-space UI (buttons, timeline,
-- match-end box) over it. The player sees only their own perception: live,
-- or as it stood at the cursor's tick while the timeline cursor is on the
-- left half (the replay); the debug overlay adds true state on top, except
-- during the replay, since it would show the current state, not the replayed
-- one. No `love.*` at load time.
local SonarView = require("src.app.render.sonar_view")
local Debug = require("src.app.render.debug")
local Match = require("src.game.match")

local Frame = {}

function Frame.draw(ctx, state, camera, debugOn)
	local replay = state.replayPerception and state:replayPerception()
	love.graphics.push()
	love.graphics.scale(camera.zoom)
	love.graphics.translate(-camera.x, -camera.y)
	SonarView.draw(replay or Match.perceptionOf(ctx, "player"), ctx.grid.cellSize)
	state:drawWorld()
	if debugOn and not replay then
		Debug.draw(ctx)
	end
	love.graphics.pop()
	state:drawUI()
end

return Frame
