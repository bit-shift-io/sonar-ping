-- Drives a pure match (no `love`) tick by tick across turn boundaries for
-- scripted tests whose scenarios outlast one turn (config.turn.ticks).
-- Match.step returns false in the plan phase and once the match is over, so
-- a bare `Match.step` loop stalls silently at a turn's end; these helpers
-- step through the plan phase instead and fail loudly once the match is over.
-- Uses the test runner's global `assertTrue`.
local Match = require("src.game.match")
local Turn = require("src.game.turn")

local Play = {}

-- At a plan phase, every slot that has not yet submitted (AI slots submit on
-- their own) submits no new orders, so its sub holds its course.
function Play.holdCourse(ctx)
	if ctx.turn.phase ~= "plan" then
		return
	end
	for _, slot in ipairs(ctx.turn.slots) do
		if ctx.turn.phase == "plan" and not ctx.turn.queues[slot] then
			Turn.submit(ctx, slot, {})
		end
	end
end

-- One tick of play; errors once the match is over.
function Play.advance(ctx)
	Play.holdCourse(ctx)
	assertTrue(Match.step(ctx), "the match is over at tick " .. ctx.tick)
end

-- `n` ticks of play.
function Play.steps(ctx, n)
	for _ = 1, n do
		Play.advance(ctx)
	end
end

-- Plays until the global tick is `tick`.
function Play.stepTo(ctx, tick)
	while ctx.tick < tick do
		Play.advance(ctx)
	end
end

-- Plays until the current turn's execute phase ends (the next plan phase),
-- without submitting for that next turn. Errors once the match is over.
function Play.toPlan(ctx)
	Play.holdCourse(ctx)
	repeat
		assertTrue(Match.step(ctx), "the match is over at tick " .. ctx.tick)
	until ctx.turn.phase == "plan"
end

return Play
