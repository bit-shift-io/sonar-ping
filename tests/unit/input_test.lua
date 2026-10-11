local Input = require("src.app.input")

test("the debug key toggles the true-state overlay on and off", function()
	local state = Input.new()
	assertFalse(state.debug)

	Input.keypressed(state, Input.DEBUG_KEY)
	assertTrue(state.debug)

	Input.keypressed(state, Input.DEBUG_KEY)
	assertFalse(state.debug)
end)

test("other keys leave the debug overlay alone", function()
	local state = Input.new()

	Input.keypressed(state, "space")

	assertFalse(state.debug)
end)
