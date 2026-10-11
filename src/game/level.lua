-- A level is a plain table: `subs` (`player` and `enemy`, each `{ x, y, order }`
-- in world px with a starting course order), optional `extraEnemies` (an
-- array of the same `{ x, y, order }`: where enemies after the first start)
-- and `seabed`, a polyline of world-pixel points with strictly increasing x (docs/CONTEXT.md "Cell"). Everything below the
-- polyline is rock, everything above is water. Tests pass literal level tables
-- (see src/game/levels/ for the shipped ones). Pure; no `love.*`.
local Grid = require("src.sim.grid")

local Level = {}

-- Returns true, or false plus an error message.
function Level.validate(t)
	if type(t) ~= "table" or type(t.seabed) ~= "table" or #t.seabed < 2 then
		return false, "level must be a table with a seabed of at least 2 points"
	end
	for i = 2, #t.seabed do
		if t.seabed[i].x <= t.seabed[i - 1].x then
			return false, string.format("seabed point %d: x must be greater than the previous point's", i)
		end
	end
	for _, slot in ipairs({ "player", "enemy" }) do
		local spawn = type(t.subs) == "table" and t.subs[slot]
		if type(spawn) ~= "table" or type(spawn.x) ~= "number" or type(spawn.y) ~= "number" or type(spawn.order) ~= "table" then
			return false, "level subs." .. slot .. " must have numeric x, y and an order"
		end
	end
	return true
end

-- Seabed depth (world y) at world x; clamped to the end points outside the polyline.
local function seabedY(seabed, x)
	if x <= seabed[1].x then
		return seabed[1].y
	end
	for i = 2, #seabed do
		local a, b = seabed[i - 1], seabed[i]
		if x <= b.x then
			return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)
		end
	end
	return seabed[#seabed].y
end

-- Rasterises the seabed into a Grid sized by config.grid: a cell is rock when
-- its centre is at or below the seabed line at that column.
function Level.buildGrid(level, config)
	local g = config.grid
	local grid = Grid.new(g.width, g.height, g.cellSize)
	for cx = 1, g.width do
		local x, _ = Grid.cellToWorld(grid, cx, 1)
		local floorY = seabedY(level.seabed, x)
		for cy = 1, g.height do
			local _, y = Grid.cellToWorld(grid, cx, cy)
			if y >= floorY then
				Grid.set(grid, cx, cy, Grid.ROCK)
			end
		end
	end
	return grid
end

return Level
