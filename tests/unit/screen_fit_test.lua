local Screen = require("src.app.screen")

test("Screen.fit scales to fill height and letterboxes the sides in a wider window", function()
	local fit = Screen.fit(1920, 720)

	assertNear(1.0, fit.scale)
	assertNear(320, fit.offsetX)
	assertNear(0, fit.offsetY)
end)

test("Screen.fit scales to fill width and letterboxes top and bottom in a taller window", function()
	local fit = Screen.fit(1280, 1440)

	assertNear(1.0, fit.scale)
	assertNear(0, fit.offsetX)
	assertNear(360, fit.offsetY)
end)

test("Screen.fit scales down uniformly when the window is smaller than the virtual resolution", function()
	local fit = Screen.fit(640, 360)

	assertNear(0.5, fit.scale)
	assertNear(0, fit.offsetX)
	assertNear(0, fit.offsetY)
end)

test("Screen.toVirtual maps a window point back through the fit to world pixels", function()
	local fit = Screen.fit(1920, 1440) -- scale 1.5, letterboxed 180 px top and bottom

	local x, y = Screen.toVirtual(fit, 960, 180 + 300 * 1.5)

	assertNear(640, x)
	assertNear(300, y)
end)
