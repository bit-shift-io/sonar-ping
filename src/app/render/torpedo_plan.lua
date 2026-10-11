-- Torpedo plan preview: for each planned launch, its run from the launch
-- point (out of the tube, the turn onto its angle, then straight; drawn as
-- the curve of its tick-by-tick points) (Predict.torpedo, via PlanState.previews) with a tick mark
-- where it arms and where it ends (a blast-radius circle where it detonates,
-- a cross for a dud). The launch being edited also gets its aim point (the
-- clamped point, PlanState:aimPoint) and the chosen speed. Earlier turns'
-- own torpedoes still running (PlanState.inFlight) draw their projected rest
-- of run dimmed, like launches not being edited. Reads only the
-- planning slot's own sub and plan (own-ship knowledge), never the enemy.
-- Draws in world px; the caller applies the screen fit. No `love.*` at load
-- time.
local TorpedoPlan = {}

local RUN = { 1.0, 0.45, 0.3, 0.8 }
local FUSE = { 1.0, 0.75, 0.3, 1 }
local AIM = { 1.0, 0.9, 0.3, 1 }
local DIM = 0.45 -- alpha factor for launches other than the one being edited
local FUSE_MARK = 7
local MARKER = { 1, 1, 1, 1 } -- an own torpedo's position at the scrubbed tick
local MARKER_RADIUS = 4

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

-- A run line from (lx, ly) through its points, with its arming and end marks.
local function drawRun(state, preview, lx, ly, alpha)
	local points, endTick = preview.points, preview.endTick or #preview.points
	if not lx or #points == 0 then
		return
	end
	setColor(RUN, alpha)
	polyline(points, 1, endTick, lx, ly)

	if preview.armedAt and preview.armedAt <= endTick then
		local a = points[preview.armedAt]
		-- Across the run where it arms (its direction over that tick).
		local b = points[preview.armedAt - 1] or { x = lx, y = ly }
		local dx, dy = a.x - b.x, a.y - b.y
		local len = math.sqrt(dx * dx + dy * dy)
		local nx, ny = 0, 5
		if len > 0 then
			nx, ny = -dy / len * 5, dx / len * 5
		end
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
end

local function drawLaunch(state, entry, preview, alpha)
	local lx, ly = state:launchPoint(entry)
	drawRun(state, preview, lx, ly, alpha)
end

function TorpedoPlan.draw(state)
	-- Earlier turns' own torpedoes still running: dimmed, never edited.
	for _, flight in ipairs(state.inFlight) do
		drawRun(state, flight.preview, flight.x, flight.y, DIM)
	end
	for _, entry in ipairs(state.schedule) do
		local preview = state.previews[entry]
		if preview and entry ~= state.torpedo then
			drawLaunch(state, entry, preview, DIM)
		end
	end
	local preview = state:torpedoPreview()
	if preview then
		drawLaunch(state, state.torpedo, preview, 1)
		local ax, ay, dud = state:aimPoint()
		if ax then
			love.graphics.setColor(AIM)
			love.graphics.circle(state.dragging == "torpedo" and "fill" or "line", ax, ay, 8)
			love.graphics.print(string.format("%s%s", state.torpedo.order.speed:upper(), dud and "  DUD" or ""), ax + 12, ay - 7)
		end
	end
	-- Each own torpedo in the water at the scrubbed tick, planned or running.
	love.graphics.setColor(MARKER)
	for _, t in ipairs(state:torpedoesAt(state.selected)) do
		love.graphics.circle("fill", t.x, t.y, MARKER_RADIUS)
	end
	love.graphics.setColor(1, 1, 1, 1)
end

return TorpedoPlan
