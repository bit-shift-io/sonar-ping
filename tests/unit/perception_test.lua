-- Per-observer perception built only from arrivals (ADR 0002). Positions are
-- in cell units: cell (cx, cy) has its centre at (cx, cy).
local Perception = require("src.perception.perception")
local Emissions = require("src.perception.emissions")
local Grid = require("src.sim.grid")

local function openGrid()
	return Grid.new(100, 40, 4)
end

local function newPerception(overrides)
	local opts = { c = 1, smear = 0, fadeTicks = 1000 }
	for k, v in pairs(overrides or {}) do
		opts[k] = v
	end
	return Perception.new(opts)
end

-- First arrival tick of any contact, or nil.
local function firstArrival(perception)
	local c = perception.contacts[1]
	return c and c.arrivalTick
end

-- Steps `observers` ({ perception, x, y }) for ticks 0..last, calling
-- `emit(history, tick)` first each tick, as Match.step does.
local function run(grid, history, observers, last, emit)
	for tick = 0, last do
		if emit then
			emit(history, tick)
		end
		for _, o in ipairs(observers) do
			Perception.step(o.perception, history, grid, o.x, o.y, tick)
		end
	end
end

test("two observers perceive the same emission at different ticks", function()
	local grid = openGrid()
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 1)
	local near = { perception = newPerception(), x = 15, y = 10 }
	local far = { perception = newPerception(), x = 40, y = 10 }

	run(grid, history, { near, far }, 60, function(h, tick)
		if tick == 0 then
			Emissions.record(h, 0, 10, 10, "noise", 2)
		end
	end)

	assertEqual(5, firstArrival(near.perception))
	assertEqual(30, firstArrival(far.perception))
end)

test("an observer behind rock never perceives the emission", function()
	local grid = openGrid()
	for cy = 1, 40 do
		Grid.set(grid, 20, cy, Grid.ROCK)
	end
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 1)
	local hidden = { perception = newPerception(), x = 30, y = 10 }

	run(grid, history, { hidden }, 60, function(h, tick)
		if tick == 0 then
			Emissions.record(h, 0, 10, 10, "noise", 2)
		end
	end)

	assertEqual(0, #hidden.perception.contacts)
end)

test("a contact carries the emission's kind and noise level", function()
	local grid = openGrid()
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 1)
	local o = { perception = newPerception(), x = 15, y = 10 }

	run(grid, history, { o }, 10, function(h, tick)
		if tick == 0 then
			Emissions.record(h, 0, 10, 10, "noise", 3)
		end
	end)

	local contact = o.perception.contacts[1]
	assertEqual("noise", contact.kind)
	assertEqual(3, contact.level)
end)

test("a contact arrives flagged when its emission came from a torpedo, for noise and echoes alike", function()
	local grid = openGrid()
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 1)
	local o = { perception = newPerception(), x = 15, y = 10 }

	run(grid, history, { o }, 10, function(h, tick)
		if tick == 0 then
			Emissions.record(h, 0, 10, 10, "noise", 3, true)
			Emissions.record(h, 0, 10, 11, "noise", 3)
			Emissions.record(h, 0, 10, 12, "echo", 0, true)
			Emissions.record(h, 0, 10, 13, "echo", 0)
		end
	end)

	local flagged = {}
	for _, c in ipairs(o.perception.contacts) do
		flagged[c.kind .. c.y] = c.torpedo
	end
	assertEqual(true, flagged.noise10)
	assertTrue(not flagged.noise11, "plain noise is unflagged")
	assertEqual(true, flagged.echo12)
	assertTrue(not flagged.echo13, "a plain echo is unflagged")
end)

test("a contact holds only where, when, what kind, how loud and whether a torpedo made it", function()
	local grid = openGrid()
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 1)
	local o = { perception = newPerception(), x = 15, y = 10 }

	run(grid, history, { o }, 10, function(h, tick)
		if tick == 0 then
			Emissions.record(h, 0, 10, 10, "noise", 3, true)
		end
	end)

	local keys = {}
	for k in pairs(o.perception.contacts[1]) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	assertEqual("arrivalTick,kind,level,torpedo,x,y", table.concat(keys, ","))
end)

test("a contact's age counts ticks since it arrived", function()
	local grid = openGrid()
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 1)
	local o = { perception = newPerception(), x = 15, y = 10 }

	run(grid, history, { o }, 12, function(h, tick)
		if tick == 0 then
			Emissions.record(h, 0, 10, 10, "noise", 2)
		end
	end)

	assertEqual(7, Perception.age(o.perception, o.perception.contacts[1]))
end)

test("a contact older than the fade time is forgotten", function()
	local grid = openGrid()
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 1)
	local o = { perception = newPerception({ fadeTicks = 20 }), x = 15, y = 10 }

	run(grid, history, { o }, 25, function(h, tick)
		if tick == 0 then
			Emissions.record(h, 0, 10, 10, "noise", 2)
		end
	end)
	assertEqual(1, #o.perception.contacts, "age 20 is still shown")
	Perception.step(o.perception, history, grid, o.x, o.y, 26)

	assertEqual(0, #o.perception.contacts)
end)

test("a smeared contact keeps the exact bearing to the cell", function()
	local grid = openGrid()
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 77)
	local o = { perception = newPerception({ smear = 0.3 }), x = 5, y = 5 }

	run(grid, history, { o }, 80, function(h, tick)
		if tick < 20 then
			Emissions.record(h, tick, 45, 35, "noise", 2)
		end
	end)

	assertTrue(#o.perception.contacts >= 20)
	local moved = false
	for _, c in ipairs(o.perception.contacts) do
		local cross = (c.x - 5) * (35 - 5) - (c.y - 5) * (45 - 5)
		assertNear(0, cross, 1e-6, "contact lies on the bearing line")
		moved = moved or math.abs(c.x - 45) > 0.5
	end
	assertTrue(moved, "range is smeared along the bearing")
end)

test("a moving hull's perceived cells are offset by their individual delays", function()
	local grid = openGrid()
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 1)
	local o = { perception = newPerception(), x = 1, y = 20 }
	-- A hull moving east (away) at half a cell per tick: stern in row 20,
	-- bow in row 21 ten cells ahead. True stern-to-bow gap is always 10.
	local function stern(tick)
		return 20 + math.floor(tick / 2)
	end

	run(grid, history, { o }, 120, function(h, tick)
		Emissions.record(h, tick, stern(tick), 20, "noise", 2)
		Emissions.record(h, tick, stern(tick) + 10, 21, "noise", 2)
	end)

	-- Pair stern and bow contacts that arrived on the same tick.
	local sternAt, matched = {}, 0
	for _, c in ipairs(o.perception.contacts) do
		if math.abs(c.y - 20) < 0.01 then
			sternAt[c.arrivalTick] = c.x
		end
	end
	for _, c in ipairs(o.perception.contacts) do
		local sx = math.abs(c.y - 21) < 0.01 and sternAt[c.arrivalTick]
		if sx then
			matched = matched + 1
			assertTrue(c.x - sx < 9, "the bow's older sound shows it further back, gap " .. (c.x - sx))
		end
	end
	assertTrue(matched > 10, "expected bow and stern arrivals on the same ticks")
end)
