-- Torpedo plan preview: for each planned launch, its straight run from the
-- launch point (Predict.torpedo, via PlanState.previews) with a tick mark
-- where it arms, its fuse marker (a blast-radius circle where it detonates, a
-- cross for a dud), and the line on past the fuse, dim, for sliding the fuse
-- marker along. The launch being edited also gets its angle handle. Reads
-- only the planning slot's own sub and plan (own-ship knowledge), never the
-- enemy. Draws in world px; the caller applies the screen fit. No `love.*`
-- at load time.
local TorpedoPlan = {}

local RUN = { 1.0, 0.45, 0.3, 0.8 }
local BEYOND = { 1.0, 0.45, 0.3, 0.2 }
local FUSE = { 1.0, 0.75, 0.3, 1 }
local HANDLE = { 1.0, 0.9, 0.3, 1 }
local DIM = 0.45 -- alpha factor for launches other than the one being edited
local FUSE_MARK = 7

local function setColor(c, alpha)
	love.graphics.setColor(c[1], c[2], c[3], c[4] * alpha)
end

-- `points` from index `from` to `to` as one line, starting at (x, y) when given.
local function polyline(points, from, to, x, y)
	local flat = {}
	if x then
		flat[1], flat[2] = x, y
	end
	for k = from, to do
		flat[#flat + 1] = points[k].x
		flat[#flat + 1] = points[k].y
	end
	if #flat >= 4 then
		love.graphics.line(flat)
	end
end

local function drawLaunch(state, entry, preview, alpha)
	local lx, ly = state:launchPoint(entry)
	local points, endTick = preview.points, preview.endTick or #preview.points
	if not lx or #points == 0 then
		return
	end
	setColor(RUN, alpha)
	polyline(points, 1, endTick, lx, ly)
	setColor(BEYOND, alpha)
	polyline(points, endTick, #points)

	if preview.armedAt and preview.armedAt <= endTick then
		local a = points[preview.armedAt]
		local nx, ny = -math.sin(entry.order.angle) * 5, math.cos(entry.order.angle) * 5
		setColor(RUN, alpha)
		love.graphics.line(a.x - nx, a.y - ny, a.x + nx, a.y + ny)
	end

	local f = points[endTick]
	setColor(FUSE, alpha)
	if preview.detonation then
		love.graphics.circle("line", f.x, f.y, state.ctx.config.torpedo.blastRadius, 48)
		love.graphics.circle("fill", f.x, f.y, FUSE_MARK / 2)
	else
		love.graphics.line(f.x - FUSE_MARK, f.y - FUSE_MARK, f.x + FUSE_MARK, f.y + FUSE_MARK)
		love.graphics.line(f.x - FUSE_MARK, f.y + FUSE_MARK, f.x + FUSE_MARK, f.y - FUSE_MARK)
	end
	love.graphics.rectangle(state.dragging == "fuse" and entry == state.torpedo and "fill" or "line", f.x - FUSE_MARK, f.y - FUSE_MARK, FUSE_MARK * 2, FUSE_MARK * 2)
end

function TorpedoPlan.draw(state)
	for _, entry in ipairs(state.schedule) do
		local preview = state.previews[entry]
		if preview and entry ~= state.torpedo then
			drawLaunch(state, entry, preview, DIM)
		end
	end
	local preview = state:torpedoPreview()
	if preview then
		drawLaunch(state, state.torpedo, preview, 1)
		local lx, ly = state:launchPoint(state.torpedo)
		local hx, hy = state:torpedoHandlePosition()
		love.graphics.setColor(HANDLE)
		love.graphics.line(lx, ly, hx, hy)
		love.graphics.circle(state.dragging == "torpedo" and "fill" or "line", hx, hy, 8)
	end
	love.graphics.setColor(1, 1, 1, 1)
end

return TorpedoPlan
