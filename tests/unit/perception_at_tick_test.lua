-- A perception can be asked what it held at a past tick (the replay scrubber):
-- every contact that had arrived by then and not yet faded, aged from then.
-- Expired contacts stay retrievable for `archiveTicks`, and asking never
-- changes the perception.
local Perception = require("src.perception.perception")
local Emissions = require("src.perception.emissions")
local Grid = require("src.sim.grid")

local OBSERVER = { x = 15, y = 10 }

-- Observer listening at (15, 10) from tick 0 to `last`; noise emitted at
-- (10, 10) on each tick in `emitAt` reaches it five ticks later. Fade 240 for
-- noise, 600 for active returns, an archive of one 720-tick turn plus 600.
local function listen(emitAt, last, overrides)
	local grid = Grid.new(100, 40, 4)
	local history = Emissions.new(Emissions.capacityFor(grid, 1), 1)
	local opts = { c = 1, smear = 0, fadeTicks = 240, echoFadeTicks = 600, archiveTicks = 1320 }
	for k, v in pairs(overrides or {}) do
		opts[k] = v
	end
	local perception = Perception.new(opts)
	for tick = 0, last do
		for _, at in ipairs(emitAt) do
			if at == tick then
				Emissions.record(history, tick, 10, 10, "noise", 2)
			end
		end
		Perception.step(perception, history, grid, OBSERVER.x, OBSERVER.y, tick)
	end
	return perception
end

test("perception at a past tick holds the contacts that had arrived by then, aged from then", function()
	local perception = listen({ 0, 200 }, 300)

	local contacts = Perception.at(perception, 100)

	assertEqual(1, #contacts)
	assertEqual(5, contacts[1].arrivalTick)
	assertEqual(95, Perception.age(perception, contacts[1], 100))
end)

test("perception at a tick before anything arrived is empty", function()
	local perception = listen({ 0 }, 300)

	assertEqual(0, #Perception.at(perception, 4))
	assertEqual(1, #Perception.at(perception, 5))
end)

test("a contact already faded at the asked tick is not in it", function()
	local perception = listen({ 0 }, 600)

	assertEqual(1, #Perception.at(perception, 245))
	assertEqual(0, #Perception.at(perception, 246))
end)

test("contacts faded from the live view are still in the perception at an earlier tick", function()
	local perception = listen({ 0 }, 400)

	assertEqual(0, #perception.contacts)
	assertEqual(1, #Perception.at(perception, 100))
end)

test("perception at a tick lists contacts in arrival order", function()
	local perception = listen({ 0, 10, 20 }, 100)

	local contacts = Perception.at(perception, 100)

	assertEqual(3, #contacts)
	assertEqual(5, contacts[1].arrivalTick)
	assertEqual(15, contacts[2].arrivalTick)
	assertEqual(25, contacts[3].arrivalTick)
end)

test("contacts older than the archive window are dropped from the archive", function()
	local perception = listen({ 0 }, 1400, { archiveTicks = 1320 })

	assertEqual(0, #Perception.at(perception, 100))
end)

test("asking for a past tick does not change the perception", function()
	local perception = listen({ 0, 200 }, 400)
	local live, tick = #perception.contacts, perception.tick

	Perception.at(perception, 100)
	Perception.at(perception, 250)

	assertEqual(live, #perception.contacts)
	assertEqual(tick, perception.tick)
	assertEqual(1, #Perception.at(perception, 250))
	assertEqual(205, Perception.at(perception, 250)[1].arrivalTick)
end)

test("the live contacts are unchanged by the archive", function()
	local archived = listen({ 0, 200 }, 400)
	local plain = listen({ 0, 200 }, 400, { archiveTicks = false })

	assertEqual(#plain.contacts, #archived.contacts)
	assertEqual(plain.contacts[1].arrivalTick, archived.contacts[1].arrivalTick)
end)
