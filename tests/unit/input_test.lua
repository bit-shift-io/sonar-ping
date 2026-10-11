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

local Camera = require("src.app.camera")
local Config = require("src.game.config")

-- A state that records the coordinate pairs it is given.
local function recorder()
	local calls = {}
	return calls, {
		mousepressed = function(_, sx, sy, wx, wy, button) calls[#calls + 1] = { "press", sx, sy, wx, wy, button } end,
		mousemoved = function(_, sx, sy, wx, wy) calls[#calls + 1] = { "move", sx, sy, wx, wy } end,
		mousereleased = function(_, sx, sy, wx, wy, button) calls[#calls + 1] = { "release", sx, sy, wx, wy, button } end,
	}
end

test("a click is passed to the state in screen px and in world px under the camera", function()
	local input, cam = Input.new(), { zoom = 2, x = 100, y = 50 }
	local calls, state = recorder()

	Input.mousepressed(input, cam, state, 300, 200, 1)

	assertEqual(1, #calls)
	assertEqual(300, calls[1][2])
	assertEqual(200, calls[1][3])
	assertNear(250, calls[1][4])
	assertNear(150, calls[1][5])
	assertEqual(1, calls[1][6])
end)

test("middle-drag pans the camera and sends nothing to the state", function()
	local input, cam = Input.new(), Camera.new()
	Camera.zoomAt(cam, 640, 360, 100, Config.camera)
	local x0 = cam.x
	local calls, state = recorder()

	Input.mousepressed(input, cam, state, 500, 300, 3)
	Input.mousemoved(input, cam, state, 540, 300)
	Input.mousereleased(input, cam, state, 540, 300, 3)

	assertNear(x0 - 10, cam.x)
	assertEqual(0, #calls)
end)

test("space plus left-drag pans, and left alone goes to the state again after release", function()
	local input, cam = Input.new(), Camera.new()
	Camera.zoomAt(cam, 640, 360, 100, Config.camera)
	local x0 = cam.x
	local calls, state = recorder()

	Input.keypressed(input, "space")
	Input.mousepressed(input, cam, state, 500, 300, 1)
	Input.mousemoved(input, cam, state, 540, 300)
	Input.mousereleased(input, cam, state, 540, 300, 1)
	Input.keyreleased(input, "space")
	Input.mousepressed(input, cam, state, 500, 300, 1)

	assertNear(x0 - 10, cam.x)
	assertEqual(1, #calls)
	assertEqual("press", calls[1][1])
end)

test("the wheel zooms toward the cursor", function()
	local input, cam = Input.new(), Camera.new()
	local wx0, wy0 = Camera.toWorld(cam, 900, 500)

	Input.wheelmoved(input, cam, 900, 500, 2)

	assertTrue(cam.zoom > 1)
	local wx, wy = Camera.toWorld(cam, 900, 500)
	assertNear(wx0, wx, 1e-9)
	assertNear(wy0, wy, 1e-9)
end)
