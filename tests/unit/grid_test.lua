local Grid = require("src.sim.grid")

test("Grid.new fills every cell with water", function()
	local grid = Grid.new(8, 4, 4)

	assertEqual(8, grid.width)
	assertEqual(4, grid.height)
	assertEqual(Grid.WATER, Grid.get(grid, 1, 1))
	assertEqual(Grid.WATER, Grid.get(grid, 8, 4))
end)

test("Grid.set then Grid.get returns the material written", function()
	local grid = Grid.new(8, 4, 4)

	Grid.set(grid, 3, 2, Grid.ROCK)

	assertEqual(Grid.ROCK, Grid.get(grid, 3, 2))
	assertEqual(Grid.WATER, Grid.get(grid, 2, 2))
end)

test("Grid.get outside the grid is nil", function()
	local grid = Grid.new(8, 4, 4)

	assertEqual(nil, Grid.get(grid, 0, 1))
	assertEqual(nil, Grid.get(grid, 9, 1))
	assertEqual(nil, Grid.get(grid, 1, 5))
end)

test("Grid.worldToCell maps a world point to the 1-based cell containing it", function()
	local grid = Grid.new(8, 4, 4)

	local cx, cy = Grid.worldToCell(grid, 0, 0)
	assertEqual(1, cx)
	assertEqual(1, cy)

	cx, cy = Grid.worldToCell(grid, 7.9, 12.1)
	assertEqual(2, cx)
	assertEqual(4, cy)
end)

test("Grid.cellToWorld returns the cell centre, and worldToCell round-trips it", function()
	local grid = Grid.new(320, 180, 4)

	local x, y = Grid.cellToWorld(grid, 3, 2)
	assertNear(10, x)
	assertNear(6, y)

	for _, c in ipairs({ { 1, 1 }, { 160, 90 }, { 320, 180 }, { 17, 143 } }) do
		local wx, wy = Grid.cellToWorld(grid, c[1], c[2])
		local cx, cy = Grid.worldToCell(grid, wx, wy)
		assertEqual(c[1], cx)
		assertEqual(c[2], cy)
	end
end)

test("Grid.isBoundaryRock is true for rock with a water neighbour", function()
	local grid = Grid.new(5, 5, 4)
	for cx = 1, 5 do
		for cy = 3, 5 do
			Grid.set(grid, cx, cy, Grid.ROCK)
		end
	end

	assertTrue(Grid.isBoundaryRock(grid, 3, 3), "top rock row touches water above")
	assertFalse(Grid.isBoundaryRock(grid, 3, 4), "middle rock row is buried")
end)

test("Grid.isBoundaryRock is false for water and for rock buried under the map edge", function()
	local grid = Grid.new(5, 5, 4)
	for cx = 1, 5 do
		for cy = 3, 5 do
			Grid.set(grid, cx, cy, Grid.ROCK)
		end
	end

	assertFalse(Grid.isBoundaryRock(grid, 3, 2), "water is not rock")
	assertFalse(Grid.isBoundaryRock(grid, 3, 5), "map edge is not water")
	assertFalse(Grid.isBoundaryRock(grid, 1, 4), "side edge is not water")
end)
