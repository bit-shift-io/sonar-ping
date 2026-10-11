local Collide = require("src.sim.collide")
local Grid = require("src.sim.grid")

local HULL = { length = 32, beam = 8 }

-- A grid big enough that the hull below is well inside it.
local function grid()
	return Grid.new(40, 20, 4)
end

-- "cx,cy" keys of a cell list, for order-independent comparison.
local function keySet(cells)
	local set = {}
	for _, c in ipairs(cells) do
		set[c.cx .. "," .. c.cy] = true
	end
	return set
end

local function count(set)
	local n = 0
	for _ in pairs(set) do
		n = n + 1
	end
	return n
end

-- (64, 40) is the corner shared by cells (16,10), (17,10), (16,11), (17,11).
test("a hull at angle 0 rasterises to an 8 x 2 block of cells", function()
	local cells = Collide.rasterHull(grid(), 64, 40, 0, HULL)

	local set = keySet(cells)
	assertEqual(16, count(set))
	for cx = 13, 20 do
		for cy = 10, 11 do
			assertTrue(set[cx .. "," .. cy], "missing cell " .. cx .. "," .. cy)
		end
	end
end)

test("a hull at 90 degrees rasterises to a 2 x 8 block of cells", function()
	local cells = Collide.rasterHull(grid(), 64, 40, math.pi / 2, HULL)

	local set = keySet(cells)
	assertEqual(16, count(set))
	for cx = 16, 17 do
		for cy = 7, 14 do
			assertTrue(set[cx .. "," .. cy], "missing cell " .. cx .. "," .. cy)
		end
	end
end)

test("a hull at 45 degrees rasterises to a diagonal band of cells", function()
	local cells = Collide.rasterHull(grid(), 64, 40, math.pi / 4, HULL)

	local set = keySet(cells)
	-- Cell (16 + k, 10 + k) lies on the centre line, which runs down-right.
	for k = -2, 3 do
		assertTrue(set[(16 + k) .. "," .. (10 + k)], "missing diagonal cell " .. k)
	end
	for _, c in ipairs(cells) do
		assertTrue(math.abs((c.cx - 16) - (c.cy - 10)) <= 1, "cell off the diagonal band")
	end
	assertFalse(set["13,10"], "a horizontal hull's end cell is not in the diagonal band")
	assertFalse(set["20,11"])
	assertEqual(16, count(set))
end)

test("rasterHull returns cells in row-major order so the result is deterministic", function()
	local cells = Collide.rasterHull(grid(), 64, 40, 0, HULL)

	assertEqual(13, cells[1].cx)
	assertEqual(10, cells[1].cy)
	assertEqual(13, cells[9].cx)
	assertEqual(11, cells[9].cy)
end)
