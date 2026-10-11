-- Active ping (docs/CONTEXT.md "Ping", "Echo"): a wavefront expands from the
-- origin at c; boundary rock and hull cells it reaches with clear line of
-- sight emit once, and every observer perceives those echoes sharply.
-- Positions are in cell units: cell (cx, cy) has its centre at (cx, cy).
local Ping = require("src.perception.ping")
local Perception = require("src.perception.perception")
local Emissions = require("src.perception.emissions")
local Grid = require("src.sim.grid")

local function openGrid()
	return Grid.new(100, 40, 4)
end

local function newPerception(overrides)
	local opts = { c = 1, smear = 0, fadeTicks = 1000, echoFadeTicks = 1000 }
	for k, v in pairs(overrides or {}) do
		opts[k] = v
	end
	return Perception.new(opts)
end

local function fillColumn(grid, cx, fromY, toY)
	for cy = fromY, toY do
		Grid.set(grid, cx, cy, Grid.ROCK)
	end
end

local function contactsOfKind(perception, kind)
	local found = {}
	for _, c in ipairs(perception.contacts) do
		if c.kind == kind then
			found[#found + 1] = c
		end
	end
	return found
end

-- Every cell `ping` strikes over ticks ping.tick..last, as `"cx,cy@tick"`.
local function strikes(ping, cellsAt, grid, last)
	local found = {}
	for tick = ping.tick, last do
		for _, cell in ipairs(Ping.strike(ping, cellsAt(tick), grid, tick, 1)) do
			found[#found + 1] = cell.cx .. "," .. cell.cy .. "@" .. tick
		end
	end
	return found
end

local function contains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

test("the boundary rock list holds only rock cells touching water", function()
	local grid = openGrid()
	fillColumn(grid, 20, 1, 40)
	fillColumn(grid, 21, 1, 40)
	fillColumn(grid, 22, 1, 40)

	local cells = Ping.boundaryCells(grid)

	assertEqual(80, #cells, "columns 20 and 22 face water; 21 is buried")
	for _, c in ipairs(cells) do
		assertTrue(c.cx == 20 or c.cx == 22)
	end
end)

test("a rock cell at distance d echoes back to a stationary sub at 2d / c", function()
	local grid = openGrid()
	fillColumn(grid, 20, 1, 40)
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 1)
	local o = { perception = newPerception(), x = 10, y = 10 }
	local ping = Ping.new(o.x, o.y, 0)
	local rock = Ping.boundaryCells(grid)

	for tick = 0, 25 do
		for _, cell in ipairs(Ping.strike(ping, rock, grid, tick, 1)) do
			Emissions.record(history, tick, cell.cx, cell.cy, "echo", 0)
		end
		Perception.step(o.perception, history, grid, o.x, o.y, tick)
	end

	local echoes = contactsOfKind(o.perception, "echo")
	assertTrue(#echoes > 0, "the wall echoes")
	assertEqual(20, echoes[1].arrivalTick, "the nearest wall cell, 10 cells away")
	assertEqual(20, echoes[1].x)
	assertEqual(10, echoes[1].y)
end)

test("an echo is perceived sharply, at the struck cell, even with smear set", function()
	local grid = openGrid()
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 77)
	local o = { perception = newPerception({ smear = 0.3 }), x = 5, y = 5 }

	for tick = 0, 60 do
		if tick == 0 then
			Emissions.record(history, 0, 45, 35, "echo", 0)
		end
		Perception.step(o.perception, history, grid, o.x, o.y, tick)
	end

	assertEqual(1, #o.perception.contacts)
	assertEqual(45, o.perception.contacts[1].x)
	assertEqual(35, o.perception.contacts[1].y)
end)

test("a struck rock cell is heard by an observer with line of sight to its face", function()
	local grid = openGrid()
	-- A flat floor in row 30: the observer sees it at a grazing angle.
	for cx = 1, 100 do
		for cy = 30, 40 do
			Grid.set(grid, cx, cy, Grid.ROCK)
		end
	end
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 1)
	local o = { perception = newPerception(), x = 10, y = 20 }

	for tick = 0, 80 do
		if tick == 0 then
			Emissions.record(history, 0, 70, 30, "echo", 0)
		end
		Perception.step(o.perception, history, grid, o.x, o.y, tick)
	end

	assertEqual(1, #o.perception.contacts)
end)

test("a cell behind a ridge is never struck", function()
	local grid = openGrid()
	fillColumn(grid, 20, 15, 40) -- the ridge
	fillColumn(grid, 30, 1, 40) -- a wall beyond it
	local ping = Ping.new(10, 20, 0)
	local rock = Ping.boundaryCells(grid)

	local struck = strikes(ping, function()
		return rock
	end, grid, 60)

	assertTrue(contains(struck, "20,20@10"), "the ridge face is struck")
	assertTrue(contains(struck, "30,1@28"), "the wall above the ridge crest is struck")
	for _, s in ipairs(struck) do
		assertFalse(s:match("^30,20@") ~= nil, "the wall cell behind the ridge was struck: " .. s)
	end
end)

test("each cell is struck exactly once as the wavefront passes", function()
	local grid = openGrid()
	fillColumn(grid, 20, 1, 40)
	local ping = Ping.new(10.5, 10.25, 0)
	local rock = Ping.boundaryCells(grid)

	local struck = strikes(ping, function()
		return rock
	end, grid, 120)

	assertEqual(40, #struck)
end)

test("a moving hull is struck where it was when the wavefront reached it", function()
	local grid = openGrid()
	local ping = Ping.new(10, 20, 0)
	-- A one-cell hull fleeing east at half a cell per tick from x = 20: its
	-- continuous position now (x, y) and one tick ago (px, py), and the cell
	-- it occupies.
	local function hullAt(tick)
		local x = 20 + tick / 2
		return { { cx = math.floor(x + 0.5), cy = 20, x = x, y = 20, px = x - 0.5, py = 20 } }
	end

	local struck = strikes(ping, hullAt, grid, 60)

	-- The wavefront (radius = tick) catches x = 20 + t / 2 at t = 20, in cell 30.
	assertEqual(1, #struck)
	assertEqual("30,20@20", struck[1])
end)

test("the enemy observer perceives the ping origin at d / c, exactly", function()
	local grid = openGrid()
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 5)
	local enemy = { perception = newPerception({ smear = 0.3 }), x = 40, y = 10 }

	for tick = 0, 40 do
		if tick == 0 then
			Emissions.record(history, 0, 10, 10, "ping", 0)
		end
		Perception.step(enemy.perception, history, grid, enemy.x, enemy.y, tick)
	end

	local heard = contactsOfKind(enemy.perception, "ping")
	assertEqual(1, #heard)
	assertEqual(30, heard[1].arrivalTick)
	assertEqual(10, heard[1].x)
	assertEqual(10, heard[1].y)
end)

test("echoes fade on their own clock, separate from passive noise", function()
	local grid = openGrid()
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 1)
	local o = { perception = newPerception({ fadeTicks = 5, echoFadeTicks = 30 }), x = 15, y = 10 }

	for tick = 0, 20 do
		if tick == 0 then
			Emissions.record(history, 0, 10, 10, "echo", 0)
			Emissions.record(history, 0, 10, 11, "noise", 2)
		end
		Perception.step(o.perception, history, grid, o.x, o.y, tick)
	end

	assertEqual(0, #contactsOfKind(o.perception, "noise"), "noise is forgotten after fadeTicks")
	assertEqual(1, #contactsOfKind(o.perception, "echo"), "the echo is still shown")
	assertEqual(30, Perception.fadeTicksOf(o.perception, contactsOfKind(o.perception, "echo")[1]))
end)

test("a ping is spent once its wavefront has crossed the grid", function()
	local grid = openGrid()
	local ping = Ping.new(1, 1, 0)

	assertFalse(Ping.spent(ping, grid, 100, 1))
	assertTrue(Ping.spent(ping, grid, 200, 1))
end)
