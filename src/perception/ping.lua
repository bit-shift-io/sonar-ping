-- Active ping (docs/CONTEXT.md "Ping", "Echo", "Wavefront"): a wavefront of
-- radius c x (now - ping.tick) expands from the origin. Each tick it strikes
-- the solid cells it has just reached with a clear line of sight; each struck
-- cell then emits once (an "echo" emission). Only boundary rock and hull cells
-- are candidates. Positions are in cell units (cell (cx, cy) has its centre
-- at (cx, cy)). Pure; no `love.*`; requires nothing above sim.
local Grid = require("src.sim.grid")
local Arrival = require("src.perception.arrival")

local Ping = {}

-- Every boundary rock cell of `grid` (rock touching water), row-major, as
-- `{ cx, cy }`. Terrain is static: build this once per level, never per tick.
function Ping.boundaryCells(grid)
	local cells = {}
	for cy = 1, grid.height do
		for cx = 1, grid.width do
			if Grid.isBoundaryRock(grid, cx, cy) then
				cells[#cells + 1] = { cx = cx, cy = cy }
			end
		end
	end
	return cells
end

-- A ping emitted from (x, y) at `tick`.
function Ping.new(x, y, tick)
	return { x = x, y = y, tick = tick }
end

function Ping.radius(ping, now, c)
	return c * (now - ping.tick)
end

-- The cells of `cells` the wavefront reaches on tick `now` with a clear line
-- of sight from the origin. A cell is `{ cx, cy }`; a moving one (a hull)
-- may add its continuous position now (`x, y`) and one tick ago (`px, py`).
-- The wavefront crossing test is the arrival test, so each cell is struck
-- exactly once (the shell is (r - c, r]) and a moving hull is struck where it
-- was when the wavefront caught it. Returns the struck cell tables, in input
-- order.
function Ping.strike(ping, cells, grid, now, c)
	local struck = {}
	local elapsed = now - ping.tick
	for i = 1, #cells do
		local cell = cells[i]
		local x, y = cell.x or cell.cx, cell.y or cell.cy
		local px, py = cell.px or x, cell.py or y
		if
			Arrival.arrived(ping.x, ping.y, elapsed, px, py, x, y, c)
			and Arrival.clearToFace(grid, cell.cx, cell.cy, ping.x, ping.y)
		then
			struck[#struck + 1] = cell
		end
	end
	return struck
end

-- True once the wavefront has passed every cell of the grid.
function Ping.spent(ping, grid, now, c)
	local farX = math.max(ping.x - 1, grid.width - ping.x)
	local farY = math.max(ping.y - 1, grid.height - ping.y)
	return Ping.radius(ping, now, c) - c > math.sqrt(farX * farX + farY * farY)
end

return Ping
