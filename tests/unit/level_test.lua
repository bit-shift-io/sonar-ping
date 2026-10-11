local Level = require("src.game.level")
local Grid = require("src.sim.grid")
local Config = require("src.game.config")
local Trench = require("src.game.levels.trench")

local SMALL = { grid = { cellSize = 4, width = 8, height = 6 } }

-- Row of the first rock cell in a column (top of the seabed), or nil if all water.
local function seabedRow(grid, cx)
	for cy = 1, grid.height do
		if Grid.get(grid, cx, cy) == Grid.ROCK then
			return cy
		end
	end
	return nil
end

test("Level.buildGrid fills below a flat seabed with rock and above it with water", function()
	local level = { seabed = { { x = 0, y = 12 }, { x = 32, y = 12 } } }

	local grid = Level.buildGrid(level, SMALL)

	assertEqual(8, grid.width)
	assertEqual(6, grid.height)
	assertEqual(Grid.WATER, Grid.get(grid, 4, 3))
	assertEqual(Grid.ROCK, Grid.get(grid, 4, 4))
	assertEqual(Grid.ROCK, Grid.get(grid, 4, 6))
end)

test("Level.buildGrid interpolates a sloping seabed between polyline points", function()
	local level = { seabed = { { x = 0, y = 24 }, { x = 32, y = 0 } } }

	local grid = Level.buildGrid(level, SMALL)

	assertEqual(nil, seabedRow(grid, 1), "left end sits at the bottom edge: all water")
	assertEqual(1, seabedRow(grid, 8), "right end reaches the surface: all rock")
	assertEqual(4, seabedRow(grid, 5))
end)

test("Level.buildGrid on the trench level has a ridge above and a trench below the flanks", function()
	local grid = Level.buildGrid(Trench, Config)
	local flank = seabedRow(grid, 80) -- x ~ 320, level seabed before the ridge
	local ridge = seabedRow(grid, 110) -- x ~ 440, ridge crest
	local trench = seabedRow(grid, 230) -- x ~ 920, trench floor

	assertEqual(320, grid.width)
	assertEqual(180, grid.height)
	assertTrue(ridge < flank, "ridge crest is shallower than the flank")
	assertTrue(trench > flank, "trench floor is deeper than the flank")
end)

test("Level.buildGrid on the trench level is all water at the surface and all rock at the bottom row", function()
	local grid = Level.buildGrid(Trench, Config)

	for cx = 1, grid.width do
		assertEqual(Grid.WATER, Grid.get(grid, cx, 1))
		assertEqual(Grid.ROCK, Grid.get(grid, cx, grid.height))
	end
end)

test("Level.validate accepts the trench level", function()
	local ok = Level.validate(Trench)

	assertTrue(ok)
end)

test("Level.validate rejects a seabed with fewer than two points", function()
	local ok, err = Level.validate({ seabed = { { x = 0, y = 10 } } })

	assertFalse(ok)
	assertTrue(err:find("seabed"), "error names the seabed")
end)

test("Level.validate rejects a seabed whose x does not strictly increase", function()
	local ok = Level.validate({ seabed = { { x = 0, y = 10 }, { x = 50, y = 12 }, { x = 50, y = 14 } } })

	assertFalse(ok)
end)

test("Level.validate rejects a level with no enemy sub spawn", function()
	local ok, err = Level.validate({
		seabed = { { x = 0, y = 10 }, { x = 50, y = 12 } },
		subs = { player = { x = 5, y = 5, order = { kind = "course" } } },
	})

	assertFalse(ok)
	assertTrue(err:find("enemy"), "error names the missing slot")
end)

test("Level.validate rejects a sub spawn with no starting order", function()
	local ok = Level.validate({
		seabed = { { x = 0, y = 10 }, { x = 50, y = 12 } },
		subs = { player = { x = 5, y = 5 }, enemy = { x = 9, y = 5, order = { kind = "course" } } },
	})

	assertFalse(ok)
end)
