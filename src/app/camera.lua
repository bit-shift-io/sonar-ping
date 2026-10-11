-- Zoom and pan over the world, in screen (virtual) px. Pure math -- no `love.*`
-- calls -- so it is unit-testable directly; src/app/main.lua applies it to the
-- world draws with love.graphics. A camera is `{ zoom, x, y }`: (x, y) is the
-- world point at the screen's top-left. At zoom 1 it is the identity.
local Screen = require("src.app.screen")

local Camera = {}

function Camera.new()
	return { zoom = 1, x = 0, y = 0 }
end

-- Keeps the view inside the map.
function Camera.clamp(cam)
	local maxX = Screen.VIRTUAL_WIDTH - Screen.VIRTUAL_WIDTH / cam.zoom
	local maxY = Screen.VIRTUAL_HEIGHT - Screen.VIRTUAL_HEIGHT / cam.zoom
	cam.x = math.max(0, math.min(maxX, cam.x))
	cam.y = math.max(0, math.min(maxY, cam.y))
end

function Camera.toWorld(cam, sx, sy)
	return cam.x + sx / cam.zoom, cam.y + sy / cam.zoom
end

function Camera.toScreen(cam, wx, wy)
	return (wx - cam.x) * cam.zoom, (wy - cam.y) * cam.zoom
end

-- Zooms by `notches` wheel notches (positive = in) about screen point
-- (sx, sy), which stays over the same world point. `cfg` is Config.camera.
function Camera.zoomAt(cam, sx, sy, notches, cfg)
	local wx, wy = Camera.toWorld(cam, sx, sy)
	cam.zoom = math.max(cfg.minZoom, math.min(cfg.maxZoom, cam.zoom * cfg.wheelStep ^ notches))
	cam.x = wx - sx / cam.zoom
	cam.y = wy - sy / cam.zoom
	Camera.clamp(cam)
end

-- Drags the map by a screen distance: the view moves the other way.
function Camera.panBy(cam, dsx, dsy)
	cam.x = cam.x - dsx / cam.zoom
	cam.y = cam.y - dsy / cam.zoom
	Camera.clamp(cam)
end

return Camera
