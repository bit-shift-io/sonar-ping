-- Hull rasterisation and hull-vs-terrain collision. A hull is rasterised
-- into a per-body cell list each tick; the static grid is never mutated.
-- Anything outside the grid (including above the surface) counts as solid.
-- Pure; no `love.*`.
local Grid = require("src.sim.grid")

local Collide = {}

-- Cells whose centre lies inside the oriented rectangle `shape`
-- ({ length, beam } px) centred on (x, y) and rotated by `angle`. Returned
-- row-major ({ cx, cy } entries); may include cells outside the grid.
function Collide.rasterHull(grid, x, y, angle, shape)
	local size = grid.cellSize
	local halfLength, halfBeam = shape.length / 2, shape.beam / 2
	local cos, sin = math.cos(angle), math.sin(angle)
	-- Bounding radius of the rectangle bounds the cells worth testing.
	local reach = math.sqrt(halfLength * halfLength + halfBeam * halfBeam)
	local minCx, minCy = Grid.worldToCell(grid, x - reach, y - reach)
	local maxCx, maxCy = Grid.worldToCell(grid, x + reach, y + reach)

	local cells = {}
	for cy = minCy, maxCy do
		for cx = minCx, maxCx do
			local dx = (cx - 0.5) * size - x
			local dy = (cy - 0.5) * size - y
			local along = dx * cos + dy * sin
			local across = -dx * sin + dy * cos
			if math.abs(along) <= halfLength and math.abs(across) <= halfBeam then
				cells[#cells + 1] = { cx = cx, cy = cy }
			end
		end
	end
	return cells
end

-- True when any hull cell of `body` at its current pose is rock or outside the grid.
function Collide.blocked(grid, body)
	local cells = Collide.rasterHull(grid, body.x, body.y, body.angle, body.shape)
	for _, c in ipairs(cells) do
		local material = Grid.get(grid, c.cx, c.cy)
		if material == nil or material == Grid.ROCK then
			return true
		end
	end
	return false
end

-- A body whose new pose is blocked goes back to the pose it started the
-- tick from and loses its velocity; `body.blocked` reports it.
function Collide.resolve(store, grid)
	for slot = 1, store.slotCount do
		local body = store.slots[slot]
		if body and not body.dead and body.shape then
			body.blocked = Collide.blocked(grid, body)
			if body.blocked then
				body.x, body.y, body.angle = body.prevX, body.prevY, body.prevAngle
				body.vx, body.vy, body.angVel = 0, 0, 0
			end
		end
	end
end

return Collide
