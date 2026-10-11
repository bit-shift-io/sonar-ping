-- Timeline geometry is pure at load (no `love.*` until drawn), so it is unit-testable.
local Timeline = require("src.app.render.timeline")

local LENGTH = 241
local function entries(...)
	local list = {}
	for i, kind in ipairs({ ... }) do
		list[i] = { tick = 100, order = { kind = kind } }
	end
	return list
end

test("the strip is about 36 px tall and ends at the bottom margin", function()
	assertEqual(36, Timeline.H)
	assertEqual(704, Timeline.Y + Timeline.H)
end)

test("each kind's row sits inside the strip, in order", function()
	assertTrue(Timeline.rowY("course") < Timeline.rowY("ping"))
	assertTrue(Timeline.rowY("ping") < Timeline.rowY("torpedo"))
	assertTrue(Timeline.rowY("course") > Timeline.Y and Timeline.rowY("torpedo") < Timeline.Y + Timeline.H)
end)

test("markerAt hits each kind's marker on its own row", function()
	local x = Timeline.tickX(100, LENGTH)
	for _, kind in ipairs({ "course", "ping", "torpedo" }) do
		assertEqual(1, Timeline.markerAt(entries(kind), LENGTH, x, Timeline.rowY(kind)), kind)
	end
end)

test("markerAt misses between rows", function()
	local x = Timeline.tickX(100, LENGTH)
	local all = entries("course", "ping", "torpedo")
	local between = (Timeline.rowY("course") + Timeline.rowY("ping")) / 2
	assertEqual(nil, Timeline.markerAt(all, LENGTH, x, between))
	between = (Timeline.rowY("ping") + Timeline.rowY("torpedo")) / 2
	assertEqual(nil, Timeline.markerAt(all, LENGTH, x, between))
end)

-- The strip runs from -length (left edge, -5 s) through 0 (centre, the plan's
-- start) to +length (right edge, +5 s): past ticks left, plan ticks right.
test("signed tick 0 sits at the centre of the strip", function()
	assertNear(Timeline.X + Timeline.W / 2, Timeline.tickX(0, LENGTH))
end)

test("tickAt finds the signed tick under x on either half", function()
	for _, tick in ipairs({ -LENGTH + 1, -120, 0, 1, 120, LENGTH }) do
		assertEqual(tick, Timeline.tickAt(Timeline.tickX(tick, LENGTH), LENGTH), "tick " .. tick)
	end
end)

test("tickAt clamps to the last plan tick and the first past tick", function()
	assertEqual(LENGTH, Timeline.tickAt(Timeline.X + Timeline.W + 50, LENGTH))
	assertEqual(-LENGTH + 1, Timeline.tickAt(Timeline.X - 50, LENGTH))
end)

test("tickAt with a lowest tick of 1 keeps the cursor out of the left half", function()
	assertEqual(1, Timeline.tickAt(Timeline.tickX(-120, LENGTH), LENGTH, 1))
end)

test("markerAt ignores markers on the left half", function()
	local past = { { tick = -120, order = { kind = "ping" } } }
	assertEqual(nil, Timeline.markerAt(past, LENGTH, Timeline.tickX(-120, LENGTH), Timeline.rowY("ping")))
end)

test("the last execute phase's ticks map onto the left half, its last tick at the centre", function()
	assertEqual(1 - LENGTH, Timeline.pastTick(1, LENGTH))
	assertEqual(0, Timeline.pastTick(LENGTH, LENGTH))
end)

test("the cursor's lowest tick is the left end from turn 2, the plan's first tick on turn 1", function()
	assertEqual(1, Timeline.lowestTick(1, LENGTH))
	assertEqual(1 - LENGTH, Timeline.lowestTick(2, LENGTH))
end)
