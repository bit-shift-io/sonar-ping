-- Arrival test and line of sight (docs/CONTEXT.md "Arrival"). Positions are in
-- cell units: cell (cx, cy) has its centre at (cx, cy). `c` is the speed of
-- sound in cells per tick. Pure; no `love.*`; requires nothing above sim.
local Grid = require("src.sim.grid")

local Arrival = {}

-- True when an emission from cell (ex, ey) reaches the observer on tick
-- `elapsed` after it was emitted: the wavefront radius c * elapsed has just
-- passed the observer, measured from the observer's position at arrival
-- (x, y), while one tick earlier (from the previous position px, py) it had
-- not. Subs move slower than sound, so this happens exactly once per
-- emission and observer, and never before distance / c ticks.
function Arrival.arrived(ex, ey, elapsed, px, py, x, y, c)
	local radius = c * elapsed
	local dx, dy = x - ex, y - ey
	if dx * dx + dy * dy > radius * radius then
		return false
	end
	local before = radius - c
	if before < 0 then
		return true
	end
	dx, dy = px - ex, py - ey
	return dx * dx + dy * dy > before * before
end

-- True when no rock lies on the grid line (Bresenham) from cell (ex, ey) to
-- the cell holding the observer's position (x, y). Hulls do not block in v1.
function Arrival.clear(grid, ex, ey, x, y)
	local x0, y0 = ex, ey
	local x1, y1 = math.floor(x + 0.5), math.floor(y + 0.5)
	local dx, dy = math.abs(x1 - x0), -math.abs(y1 - y0)
	local sx = x0 < x1 and 1 or -1
	local sy = y0 < y1 and 1 or -1
	local err = dx + dy
	while true do
		if Grid.get(grid, x0, y0) == Grid.ROCK then
			return false
		end
		if x0 == x1 and y0 == y1 then
			return true
		end
		local e2 = 2 * err
		if e2 >= dy then
			err = err + dy
			x0 = x0 + sx
		end
		if e2 <= dx then
			err = err + dx
			y0 = y0 + sy
		end
	end
end

local END = 1 - 1e-9

-- True when the segment from (x, y) to (tx, ty) meets no rock before it
-- reaches cell (cx, cy) or its end. Walks every cell the segment passes
-- through (a grid DDA); a segment through a corner passes between the two
-- side cells.
local function segmentClear(grid, cx, cy, x, y, tx, ty)
	-- Shift by half a cell so cell k covers [k, k + 1).
	local ux, uy = x + 0.5, y + 0.5
	local dx, dy = tx - x, ty - y
	local ix, iy = math.floor(ux), math.floor(uy)
	local stepX, stepY = dx > 0 and 1 or -1, dy > 0 and 1 or -1
	local deltaX = dx ~= 0 and 1 / math.abs(dx) or math.huge
	local deltaY = dy ~= 0 and 1 / math.abs(dy) or math.huge
	local maxX = dx > 0 and (ix + 1 - ux) * deltaX or dx < 0 and (ux - ix) * deltaX or math.huge
	local maxY = dy > 0 and (iy + 1 - uy) * deltaY or dy < 0 and (uy - iy) * deltaY or math.huge
	while true do
		if ix == cx and iy == cy then
			return true
		end
		if Grid.get(grid, ix, iy) == Grid.ROCK then
			return false
		end
		-- The segment ends on the cell's face: a crossing within rounding of
		-- the end is the end, not a step into a neighbour.
		if maxX >= END and maxY >= END then
			return true
		end
		if maxX <= maxY then
			if maxY == maxX then
				iy, maxY = iy + stepY, maxY + deltaY
			end
			ix, maxX = ix + stepX, maxX + deltaX
		else
			iy, maxY = iy + stepY, maxY + deltaY
		end
	end
end

-- True when the observer at (x, y) sees a face of solid cell (cx, cy): the
-- segment to the middle of a face turned towards the observer (one or two of
-- them) crosses no rock before it reaches the cell. Struck cells (ping
-- echoes) are rock or hull, so the cell itself never blocks, and a floor seen
-- at a grazing angle is not hidden by its own neighbours.
function Arrival.clearToFace(grid, cx, cy, x, y)
	local facesX = x < cx - 0.5 or x > cx + 0.5
	local facesY = y < cy - 0.5 or y > cy + 0.5
	if facesX then
		local fx = x < cx and cx - 0.5 or cx + 0.5
		if segmentClear(grid, cx, cy, x, y, fx, cy) then
			return true
		end
	end
	if facesY then
		local fy = y < cy and cy - 0.5 or cy + 0.5
		if segmentClear(grid, cx, cy, x, y, cx, fy) then
			return true
		end
	end
	return not facesX and not facesY
end

return Arrival
