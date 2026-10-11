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
