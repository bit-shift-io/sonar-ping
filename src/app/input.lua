-- Maps key presses to app state (the debug overlay toggle). Pure table logic so
-- it runs under plain LuaJIT; main.lua forwards love.keypressed here.
local Input = {}

Input.DEBUG_KEY = "f3"

function Input.new()
	return { debug = false }
end

function Input.keypressed(state, key)
	if key == Input.DEBUG_KEY then
		state.debug = not state.debug
	end
end

return Input
