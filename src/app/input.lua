-- Maps key and mouse input to app state: the debug overlay toggle, camera
-- zoom and pan, and routing of clicks to the current state. Pure table logic
-- so it runs under plain LuaJIT; main.lua and the test harness forward
-- LÖVE's callbacks here.
--
-- Mouse coordinates arrive in screen (virtual) px, the screen fit already
-- undone. States get both pairs: screen px for the fixed UI (buttons,
-- timeline) and world px, under the camera, for the map.
local Camera = require("src.app.camera")
local Config = require("src.game.config")

local Input = {}

Input.DEBUG_KEY = "f3"
Input.PAN_KEY = "space"
local PAN_BUTTON = 3 -- middle

function Input.new()
	return { debug = false, spaceDown = false, pan = nil }
end

function Input.keypressed(state, key)
	if key == Input.DEBUG_KEY then
		state.debug = not state.debug
	elseif key == Input.PAN_KEY then
		state.spaceDown = true
	end
end

function Input.keyreleased(state, key)
	if key == Input.PAN_KEY then
		state.spaceDown = false
	end
end

-- Wheel notches (positive = in) zoom toward the cursor.
function Input.wheelmoved(_, cam, sx, sy, notches)
	Camera.zoomAt(cam, sx, sy, notches, Config.camera)
end

function Input.mousepressed(input, cam, state, sx, sy, button)
	if button == PAN_BUTTON or (button == 1 and input.spaceDown) then
		input.pan = { x = sx, y = sy, button = button }
		return
	end
	if state.mousepressed then
		local wx, wy = Camera.toWorld(cam, sx, sy)
		state:mousepressed(sx, sy, wx, wy, button)
	end
end

function Input.mousemoved(input, cam, state, sx, sy)
	local pan = input.pan
	if pan then
		Camera.panBy(cam, sx - pan.x, sy - pan.y)
		pan.x, pan.y = sx, sy
		return
	end
	if state.mousemoved then
		local wx, wy = Camera.toWorld(cam, sx, sy)
		state:mousemoved(sx, sy, wx, wy)
	end
end

function Input.mousereleased(input, cam, state, sx, sy, button)
	if input.pan then
		if button == input.pan.button then
			input.pan = nil
		end
		return
	end
	if state.mousereleased then
		local wx, wy = Camera.toWorld(cam, sx, sy)
		state:mousereleased(sx, sy, wx, wy, button)
	end
end

return Input
