local Bodies = require("src.sim.bodies")
local Collide = require("src.sim.collide")
local Integrate = require("src.sim.integrate")
local Grid = require("src.sim.grid")

local DT = 1 / 60

-- 40 x 20 cells of 4 px: water, with a rock wall in column 30 and rock below row 15.
local function room()
	local grid = Grid.new(40, 20, 4)
	for cy = 1, 20 do
		Grid.set(grid, 30, cy, Grid.ROCK)
	end
	for cx = 1, 40 do
		for cy = 16, 20 do
			Grid.set(grid, cx, cy, Grid.ROCK)
		end
	end
	return grid
end

local function addSub(store, x, y, vx, vy)
	local body = {
		x = x, y = y, angle = 0, vx = vx, vy = vy, angVel = 0,
		shape = { length = 32, beam = 8 },
	}
	Bodies.add(store, body)
	return body
end

local function run(store, grid, ticks)
	for _ = 1, ticks do
		Integrate.step(store, DT)
		Collide.resolve(store, grid)
	end
end

test("a sub driving into a rock wall stops with its bow against the rock", function()
	local grid, store = room(), Bodies.new()
	local body = addSub(store, 60, 40, 60, 0)

	run(store, grid, 120)

	assertEqual(0, body.vx)
	-- Hull cells are sampled at cell centres; the wall (column 30) starts at x = 116.
	assertFalse(Collide.blocked(grid, body), "hull entered rock")
	assertTrue(body.x + 16 > 116, "sub stopped well short of the wall: x = " .. body.x)
end)

test("a sub diving onto the seabed stops above it", function()
	local grid, store = room(), Bodies.new()
	local body = addSub(store, 60, 40, 0, 60)

	run(store, grid, 120)

	assertEqual(0, body.vy)
	-- Rock begins at y = 60 (row 16); the 8 px beam gives a 4 px half-width.
	assertFalse(Collide.blocked(grid, body), "hull entered the seabed")
	assertTrue(body.y + 4 > 60, "sub stopped well above the seabed: y = " .. body.y)
end)

test("a sub rising to the surface stops below it", function()
	local grid, store = room(), Bodies.new()
	local body = addSub(store, 60, 20, 0, -60)

	run(store, grid, 120)

	assertEqual(0, body.vy)
	assertFalse(Collide.blocked(grid, body), "hull left the water column")
	assertTrue(body.y - 4 < 2, "sub stopped well below the surface: y = " .. body.y)
end)

test("a sub in open water is not blocked and keeps moving", function()
	local grid, store = room(), Bodies.new()
	local body = addSub(store, 60, 40, 60, 0)

	run(store, grid, 10)

	assertFalse(body.blocked)
	assertNear(60 + 60 * 10 * DT, body.x, 0.0001)
end)

test("a turn that would swing the hull into rock is refused", function()
	local grid, store = room(), Bodies.new()
	-- Hull is 8 px tall when level at y = 52; turning vertical needs +-16 px.
	local body = addSub(store, 60, 52, 0, 0)
	body.angVel = math.pi / 2 / DT

	Integrate.step(store, DT)
	Collide.resolve(store, grid)

	assertTrue(body.blocked)
	assertEqual(0, body.angle)
end)
