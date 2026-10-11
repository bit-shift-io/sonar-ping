-- Sparse ring history of dynamic emissions (ADR 0002).
local Emissions = require("src.perception.emissions")
local Grid = require("src.sim.grid")

test("an emission recorded at a tick is listed in that tick's bucket", function()
	local history = Emissions.new(10, 1)

	Emissions.record(history, 3, 40, 12, "noise", 2)
	local bucket = Emissions.bucket(history, 3)

	assertEqual(1, #bucket)
	assertEqual(40, bucket[1].cx)
	assertEqual(12, bucket[1].cy)
	assertEqual("noise", bucket[1].kind)
	assertEqual(2, bucket[1].level)
	assertEqual(3, bucket[1].tick)
end)

test("a tick with no emissions has no bucket", function()
	local history = Emissions.new(10, 1)

	Emissions.record(history, 3, 40, 12, "noise", 2)

	assertEqual(nil, Emissions.bucket(history, 4))
end)

test("history is long enough for sound to cross the grid's diagonal", function()
	local grid = Grid.new(320, 180, 4)
	local c = 1

	local capacity = Emissions.capacityFor(grid, c)

	local diagonal = math.sqrt(319 ^ 2 + 179 ^ 2)
	assertTrue((capacity - 1) * c >= diagonal, "oldest kept bucket must reach the far corner")
end)

test("the oldest tick still in range keeps its emissions", function()
	local history = Emissions.new(5, 1)
	for tick = 1, 5 do
		Emissions.record(history, tick, tick, 1, "noise", 1)
	end

	assertEqual(1, Emissions.bucket(history, 1)[1].cx)
end)

test("a tick older than the history's capacity is dropped", function()
	local history = Emissions.new(5, 1)
	for tick = 1, 6 do
		Emissions.record(history, tick, tick, 1, "noise", 1)
	end

	assertEqual(nil, Emissions.bucket(history, 1))
	assertEqual(6, Emissions.bucket(history, 6)[1].cx)
end)
