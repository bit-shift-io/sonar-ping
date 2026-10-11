-- Virtual-resolution letterboxing. Pure math -- no `love.*` calls -- so it is
-- unit-testable directly; src/app/main.lua applies the returned transform
-- with love.graphics.
local Screen = {}

Screen.VIRTUAL_WIDTH = 1280
Screen.VIRTUAL_HEIGHT = 720

-- Returns the uniform scale and pixel offsets that fit the virtual
-- resolution inside a window of size (windowWidth, windowHeight), centered
-- and letterboxed on whichever axis has slack.
function Screen.fit(windowWidth, windowHeight)
	local scale = math.min(windowWidth / Screen.VIRTUAL_WIDTH, windowHeight / Screen.VIRTUAL_HEIGHT)
	local offsetX = (windowWidth - Screen.VIRTUAL_WIDTH * scale) / 2
	local offsetY = (windowHeight - Screen.VIRTUAL_HEIGHT * scale) / 2

	return {
		scale = scale,
		offsetX = offsetX,
		offsetY = offsetY,
	}
end

-- Inverse of the fit: a window pixel (e.g. the mouse) in virtual/world pixels.
function Screen.toVirtual(fit, windowX, windowY)
	return (windowX - fit.offsetX) / fit.scale, (windowY - fit.offsetY) / fit.scale
end

return Screen
