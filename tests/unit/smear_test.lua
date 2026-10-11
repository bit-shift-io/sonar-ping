-- Deterministic passive range smear (docs/CONTEXT.md "Smear").
local Smear = require("src.perception.smear")

test("the same seed and emission give the same smear on every run", function()
	local a = Smear.offset(1234, 77, 40, 12, 150, 0.08)
	local b = Smear.offset(1234, 77, 40, 12, 150, 0.08)

	assertEqual(a, b)
end)

test("different seeds smear the same emission differently", function()
	local differing = 0
	for tick = 1, 20 do
		if Smear.offset(1, tick, 40, 12, 150, 0.08) ~= Smear.offset(2, tick, 40, 12, 150, 0.08) then
			differing = differing + 1
		end
	end

	assertTrue(differing >= 18, "seeds should rarely coincide, got " .. differing .. "/20 differing")
end)

test("successive emissions of one cell spread across the whole smear band", function()
	local low, high = math.huge, -math.huge
	for tick = 1, 200 do
		local o = Smear.offset(99, tick, 40, 12, 100, 0.1)
		low, high = math.min(low, o), math.max(high, o)
	end

	assertTrue(low >= -10 and high <= 10, "stays within +/- fraction x distance")
	assertTrue(low < -8 and high > 8, "uses the band, got " .. low .. ".." .. high)
end)

test("smear grows in proportion to distance", function()
	local near = Smear.offset(5, 10, 40, 12, 50, 0.08)
	local far = Smear.offset(5, 10, 40, 12, 200, 0.08)

	assertNear(near * 4, far, 1e-9)
end)
