-- Contact tracking for the AI: a contact says where something WAS when it
-- made its sound, heard distance / c ticks later. The track turns contacts
-- back into emit-time samples and fits a straight-line course through them.
local Track = require("src.game.ai.track")

local C = 1 -- speed of sound, cells per tick (the shipped config's value)

-- The contact an observer at (ox, oy) hears from an emission at (x, y) on
-- tick `emitTick`: same position (an exact ping/echo, or a noise contact's
-- unsmeared centre), arriving distance / c ticks later.
local function heard(x, y, emitTick, ox, oy, kind)
	local distance = math.sqrt((x - ox) ^ 2 + (y - oy) ^ 2)
	return { x = x, y = y, arrivalTick = emitTick + distance / C, kind = kind or "noise", level = 2 }
end

test("a sample dates a contact back to when it was emitted", function()
	local contact = heard(200, 80, 1000, 40, 80)

	local sample = Track.sample(contact, 40, 80, C)

	assertNear(1000, sample.t, 1e-9)
	assertEqual(200, sample.x)
	assertEqual(80, sample.y)
end)

test("the track estimates a target's velocity from two delayed contacts heard from different places", function()
	-- Target running east-south-east at 0.4, 0.1 cells per tick; the observer moves between hearings.
	local first = heard(200, 80, 1000, 40, 60)
	local second = heard(200 + 0.4 * 150, 80 + 0.1 * 150, 1150, 70, 70)

	local estimate = Track.fit({ Track.sample(first, 40, 60, C), Track.sample(second, 70, 70, C) })

	assertNear(0.4, estimate.vx, 1e-9)
	assertNear(0.1, estimate.vy, 1e-9)
end)

test("the track predicts the target's position at a later tick along its course", function()
	local first = heard(200, 80, 1000, 40, 60)
	local second = heard(260, 95, 1150, 40, 60)
	local estimate = Track.fit({ Track.sample(first, 40, 60, C), Track.sample(second, 40, 60, C) })

	local x, y = Track.at(estimate, 1250)

	assertNear(300, x, 1e-9)
	assertNear(105, y, 1e-9)
end)

test("a single contact gives a position with no velocity", function()
	local estimate = Track.fit({ Track.sample(heard(200, 80, 1000, 40, 60), 40, 60, C) })

	assertEqual(0, estimate.vx)
	assertEqual(0, estimate.vy)
	assertEqual(200, estimate.x)
end)
