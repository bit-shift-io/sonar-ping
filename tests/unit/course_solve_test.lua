local Match = require("src.game.match")
local Config = require("src.game.config")
local Orders = require("src.game.orders")
local Predict = require("src.game.predict")
local CourseSolve = require("src.game.course_solve")

local CELL = Config.grid.cellSize
local FULL = Config.speeds.full.speed

-- Flat seabed at y = 600; the player in open water heading east at slow.
local function level(px, py)
	return {
		seabed = { { x = 0, y = 600 }, { x = 1280, y = 600 } },
		subs = {
			player = { x = px or 200, y = py or 300, order = { kind = "course", heading = "east", dive = 0, speed = Config.speeds.slow.speed } },
			enemy = { x = 1100, y = 300, order = { kind = "course", heading = "west", dive = 0, speed = Config.speeds.slow.speed } },
		},
	}
end

local function standing()
	return { { tick = 1, order = Orders.course("east", 0, Config.speeds.slow.speed) } }
end

-- `entries` with `edited`'s order swapped for `order`.
local function swapped(entries, edited, order)
	local out = {}
	for i, entry in ipairs(entries) do
		out[i] = entry.order == edited and { tick = entry.tick, order = order } or entry
	end
	return out
end

local function endOf(ctx, entries)
	local path = Predict.path(ctx, "player", entries)
	return path[#path]
end

local function distance(p, x, y)
	return math.sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2)
end

-- The closest end of turn to (x, y) over a brute-force grid of courses.
local function bruteBest(ctx, entries, edited, x, y)
	local best = math.huge
	local maxDive = Config.sub.maxDive
	for _, heading in ipairs({ "east", "west" }) do
		for i = 0, 12 do
			local dive = -maxDive + 2 * maxDive * i / 12
			for j = 0, 10 do
				local order = Orders.course(heading, dive, FULL * j / 10)
				best = math.min(best, distance(endOf(ctx, swapped(entries, edited, order)), x, y))
			end
		end
	end
	return best
end

local function solve(ctx, entries, x, y)
	local result = CourseSolve.solveOnce(ctx, "player", entries, entries[1].order, x, y)
	return result, distance(endOf(ctx, swapped(entries, entries[1].order, result.order)), x, y)
end

test("a reachable target in open water: the turn ends within one cell of it", function()
	local ctx = Match.new(level(), Config, 1, { ai = false })

	local result, miss = solve(ctx, standing(), 330, 350)

	assertTrue(miss <= CELL, "missed by " .. miss)
	assertEqual("east", result.order.heading)
	assertTrue(result.order.speed > 0 and result.order.speed < FULL, "a reachable point needs less than full speed")
end)

test("the result's end is where Predict.path ends with the solved order", function()
	local ctx = Match.new(level(), Config, 1, { ai = false })
	local entries = standing()

	local result = CourseSolve.solveOnce(ctx, "player", entries, entries[1].order, 300, 280)

	local p = endOf(ctx, swapped(entries, entries[1].order, result.order))
	assertEqual(p.x, result.x)
	assertEqual(p.y, result.y)
end)

test("a target beyond full speed resolves to the full-speed end along the best line", function()
	local ctx = Match.new(level(), Config, 1, { ai = false })
	local entries = standing()

	local result, miss = solve(ctx, entries, 1000, 340)

	assertEqual(FULL, result.order.speed)
	assertEqual("east", result.order.heading)
	assertTrue(result.order.dive > 0, "the line runs down towards the target")
	assertTrue(miss <= bruteBest(ctx, entries, entries[1].order, 1000, 340) + 0.5, "no course ends closer")
end)

test("a target steeper than the maximum dive resolves to the closest reachable end", function()
	local ctx = Match.new(level(), Config, 1, { ai = false })
	local entries = standing()

	local _, miss = solve(ctx, entries, 215, 500)

	assertTrue(miss <= bruteBest(ctx, entries, entries[1].order, 215, 500) + 0.5, "no course ends closer, missed by " .. miss)
end)

test("a target behind rock resolves to the closest reachable end", function()
	local ctx = Match.new(level(200, 540), Config, 1, { ai = false })
	local entries = standing()

	local result, miss = solve(ctx, entries, 330, 700)

	assertTrue(result.y < 600, "the end stays in the water")
	assertTrue(miss <= bruteBest(ctx, entries, entries[1].order, 330, 700) + 0.5, "no course ends closer, missed by " .. miss)
end)

test("a target behind the sub turns it around", function()
	local ctx = Match.new(level(), Config, 1, { ai = false })
	local entries = standing()

	local result, miss = solve(ctx, entries, 120, 300)

	assertEqual("west", result.order.heading)
	assertTrue(result.x < 200, "the turn ends behind the start")
	assertTrue(miss <= bruteBest(ctx, entries, entries[1].order, 120, 300) + 0.5, "no course ends closer, missed by " .. miss)
end)

test("with a later course order only the edited order changes", function()
	local ctx = Match.new(level(), Config, 1, { ai = false })
	local later = Orders.course("west", math.rad(10), Config.speeds.half.speed)
	local entries = { standing()[1], { tick = 200, order = later } }

	local result = CourseSolve.solveOnce(ctx, "player", entries, entries[1].order, 330, 380)

	assertEqual("west", later.heading)
	assertEqual(math.rad(10), later.dive)
	assertEqual(Config.speeds.half.speed, later.speed)
	assertEqual(Config.speeds.slow.speed, entries[1].order.speed, "the edited order itself is not changed in place")
	local p = endOf(ctx, swapped(entries, entries[1].order, result.order))
	assertEqual(p.x, result.x, "the end accounts for the later order")
	assertTrue(distance(p, 330, 380) <= CELL, "the end still lands within a cell")
end)

test("a target on the sub plans a stop", function()
	local ctx = Match.new(level(), Config, 1, { ai = false })
	local entries = standing()

	local result = CourseSolve.solveOnce(ctx, "player", entries, entries[1].order, 203, 301)

	assertEqual(0, result.order.speed)
end)

test("a target on where the sub is at a later order's tick plans a stop there", function()
	local ctx = Match.new(level(), Config, 1, { ai = false })
	local entries = { standing()[1], { tick = 150, order = Orders.course("east", 0, Config.speeds.slow.speed) } }
	local at = Predict.path(ctx, "player", entries)[149]

	local result = CourseSolve.solveOnce(ctx, "player", entries, entries[2].order, at.x, at.y)

	assertEqual(0, result.order.speed)
end)

test("solving one drag event after the first stays cheap", function()
	local ctx = Match.new(level(), Config, 1, { ai = false })
	local entries = standing()
	local solver = CourseSolve.new(ctx, "player", entries, entries[1].order)
	solver:solve(330, 350)

	local start = os.clock()
	for i = 1, 20 do
		solver:solve(330 + i, 350 - i)
	end
	local perEvent = (os.clock() - start) / 20

	assertTrue(perEvent < 0.005, string.format("%.2f ms per drag event", perEvent * 1000))
end)
