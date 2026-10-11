-- Every LÖVE-11-vs-12 version-sensitive call goes through here (see
-- docs/memory/love-11-and-12-compat.md). Wrappers are added as a slice hits a
-- real difference (stencils, canvas/mesh formats).
local Compat = {}

function Compat.getVersion()
	return love.getVersion()
end

function Compat.isLove12()
	local major = Compat.getVersion()
	return major >= 12
end

-- Plain RGBA canvas of the given pixel size, nearest-filtered so drawing it
-- 1:1 stays sharp. newCanvas(w, h) is valid on both 11.5 and 12.
function Compat.newCanvas(width, height, filter)
	local canvas = love.graphics.newCanvas(width, height)
	filter = filter or "nearest"
	canvas:setFilter(filter, filter)
	canvas:setWrap("clamp", "clamp")
	return canvas
end

return Compat
