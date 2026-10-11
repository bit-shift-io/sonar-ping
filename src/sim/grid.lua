-- The world grid: a fixed rectangle of square cells, each water, rock or hull
-- (docs/CONTEXT.md "Cell"). Plain data plus pure functions; no `love.*`.
-- Cells are 1-based (cx 1..width, cy 1..height); y points down, so row 1 is the
-- surface. World coordinates are pixels: cell (cx, cy) covers
-- [(cx-1)*cellSize, cx*cellSize) x [(cy-1)*cellSize, cy*cellSize).
local Grid = {}

Grid.WATER = 0
Grid.ROCK = 1
Grid.HULL = 2

function Grid.new(width, height, cellSize)
	local cells = {}
	for i = 1, width * height do
		cells[i] = Grid.WATER
	end
	return { width = width, height = height, cellSize = cellSize, cells = cells }
end

function Grid.inBounds(grid, cx, cy)
	return cx >= 1 and cx <= grid.width and cy >= 1 and cy <= grid.height
end

-- Material at a cell, or nil outside the grid.
function Grid.get(grid, cx, cy)
	if not Grid.inBounds(grid, cx, cy) then
		return nil
	end
	return grid.cells[(cy - 1) * grid.width + cx]
end

function Grid.set(grid, cx, cy, material)
	grid.cells[(cy - 1) * grid.width + cx] = material
end

-- The cell containing world point (x, y). May be outside the grid.
function Grid.worldToCell(grid, x, y)
	return math.floor(x / grid.cellSize) + 1, math.floor(y / grid.cellSize) + 1
end

-- World position of a cell's centre.
function Grid.cellToWorld(grid, cx, cy)
	return (cx - 0.5) * grid.cellSize, (cy - 0.5) * grid.cellSize
end

local NEIGHBOURS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- Rock with at least one water neighbour (4-connected). The map edge is not
-- water, so rock against the edge is not boundary. Only these cells echo
-- (docs/CONTEXT.md "Echo").
function Grid.isBoundaryRock(grid, cx, cy)
	if Grid.get(grid, cx, cy) ~= Grid.ROCK then
		return false
	end
	for _, d in ipairs(NEIGHBOURS) do
		if Grid.get(grid, cx + d[1], cy + d[2]) == Grid.WATER then
			return true
		end
	end
	return false
end

return Grid
