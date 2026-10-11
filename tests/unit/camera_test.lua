local Camera = require("src.app.camera")
local Config = require("src.game.config")
local Screen = require("src.app.screen")

test("a new camera at 1x shows the whole map: screen and world coincide", function()
	local cam = Camera.new()

	local wx, wy = Camera.toWorld(cam, 300, 200)

	assertNear(300, wx)
	assertNear(200, wy)
end)

test("zooming about the cursor keeps the world point under it fixed", function()
	local cam = Camera.new()
	local wx0, wy0 = Camera.toWorld(cam, 900, 500)

	Camera.zoomAt(cam, 900, 500, 3, Config.camera)

	assertTrue(cam.zoom > 1, "zoomed in")
	local wx, wy = Camera.toWorld(cam, 900, 500)
	assertNear(wx0, wx, 1e-9)
	assertNear(wy0, wy, 1e-9)
end)

test("zoom stays within the configured minimum and maximum", function()
	local cam = Camera.new()

	Camera.zoomAt(cam, 640, 360, 100, Config.camera)
	assertNear(Config.camera.maxZoom, cam.zoom)

	Camera.zoomAt(cam, 640, 360, -100, Config.camera)
	assertNear(Config.camera.minZoom, cam.zoom)
end)

test("zooming out to 1x restores today's view", function()
	local cam = Camera.new()
	Camera.zoomAt(cam, 1200, 700, 4, Config.camera)

	Camera.zoomAt(cam, 1200, 700, -4, Config.camera)

	assertNear(1, cam.zoom)
	assertNear(0, cam.x)
	assertNear(0, cam.y)
end)

test("panning is clamped so the view stays inside the map", function()
	local cam = Camera.new()
	Camera.zoomAt(cam, 640, 360, 100, Config.camera) -- 4x

	Camera.panBy(cam, 100000, 100000) -- drag far right/down moves the view left/up
	assertNear(0, cam.x)
	assertNear(0, cam.y)

	Camera.panBy(cam, -100000, -100000)
	assertNear(Screen.VIRTUAL_WIDTH - Screen.VIRTUAL_WIDTH / cam.zoom, cam.x)
	assertNear(Screen.VIRTUAL_HEIGHT - Screen.VIRTUAL_HEIGHT / cam.zoom, cam.y)
end)

test("dragging the map by a screen distance moves the view by that distance over zoom", function()
	local cam = Camera.new()
	Camera.zoomAt(cam, 640, 360, 100, Config.camera) -- 4x, centred
	local x0, y0 = cam.x, cam.y

	Camera.panBy(cam, 40, -20)

	assertNear(x0 - 10, cam.x)
	assertNear(y0 + 5, cam.y)
end)

test("screen to world to screen round-trips at any zoom and pan", function()
	local cam = Camera.new()
	Camera.zoomAt(cam, 200, 150, 5, Config.camera)
	Camera.panBy(cam, -37, 12)

	local wx, wy = Camera.toWorld(cam, 777, 333)
	local sx, sy = Camera.toScreen(cam, wx, wy)

	assertNear(777, sx, 1e-9)
	assertNear(333, sy, 1e-9)
end)
