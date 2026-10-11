-- Arrival timing and line of sight (docs/CONTEXT.md "Arrival"). Positions are
-- in cell units: cell (cx, cy) has its centre at (cx, cy).
local Arrival = require("src.perception.arrival")
local Grid = require("src.sim.grid")

-- First tick in 0..limit at which an emission from (ex, ey) at tick 0 reaches
-- an observer whose position at tick t is `pos(t)`, and how often it arrived.
local function arrivals(ex, ey, c, pos, limit)
	local first, count = nil, 0
	for t = 0, limit do
		local px, py = pos(math.max(t - 1, 0))
		local x, y = pos(t)
		if Arrival.arrived(ex, ey, t, px, py, x, y, c) then
			first = first or t
			count = count + 1
		end
	end
	return first, count
end

test("an emission 10 cells away arrives exactly 10 / c ticks later, never earlier", function()
	local first = arrivals(1, 5, 0.5, function()
		return 11, 5
	end, 60)

	assertEqual(20, first)
end)

test("an observer moving away slower than sound still hears an emission exactly once", function()
	local _, count = arrivals(1, 5, 1, function(t)
		return 11 + 0.6 * t, 5
	end, 60)

	assertEqual(1, count)
end)

test("an observer moving towards an emission hears it at its position at arrival", function()
	-- Starts 20 cells away closing at 0.5 cell/tick: 20 - 0.5t = t at t = 13.3.
	local first = arrivals(1, 5, 1, function(t)
		return 21 - 0.5 * t, 5
	end, 40)

	assertEqual(14, first)
end)

test("rock between the cell and the observer blocks line of sight", function()
	local grid = Grid.new(20, 10, 4)
	for cy = 1, 10 do
		Grid.set(grid, 10, cy, Grid.ROCK)
	end

	assertFalse(Arrival.clear(grid, 2, 5, 18, 5.4))
end)

test("open water between the cell and the observer is a clear line of sight", function()
	local grid = Grid.new(20, 10, 4)
	Grid.set(grid, 10, 1, Grid.ROCK)

	assertTrue(Arrival.clear(grid, 2, 5, 18, 8.7))
end)

test("a solid cell's face is visible past the corner of a one-cell step beside it", function()
	local grid = Grid.new(60, 160, 4)
	-- A floor stepping down by one row at x = 36: rows 139+ under x <= 35,
	-- rows 140+ from x = 36.
	for cx = 1, 60 do
		for cy = cx <= 35 and 139 or 140, 160 do
			Grid.set(grid, cx, cy, Grid.ROCK)
		end
	end

	assertTrue(Arrival.clearToFace(grid, 36, 140, 30.5, 75.5))
	assertTrue(Arrival.clearToFace(grid, 20, 139, 30.5, 75.5))
end)

test("a solid cell is hidden from an observer behind a ridge", function()
	local grid = Grid.new(60, 40, 4)
	for cy = 10, 40 do
		Grid.set(grid, 20, cy, Grid.ROCK)
		Grid.set(grid, 30, cy, Grid.ROCK)
	end

	assertFalse(Arrival.clearToFace(grid, 30, 25, 10, 25))
end)
