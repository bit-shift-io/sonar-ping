-- The last-turn replay scrubber's view: the player's own perception as it
-- stood at a past tick, built from perception alone (ADR 0002; a unit test
-- checks this module's requires), plus the scrub bar drawn over the timeline
-- strip. SonarView draws the view like any live perception. Own ship is shown
-- where it is now (no position history is kept). Draws in world px; the
-- caller applies the screen fit. No `love.*` at load time.
local Perception = require("src.perception.perception")

local Replay = {}

-- A perception-shaped snapshot of `perception` at past `tick`: the contacts it
-- held then, with `tick` as its clock so ages count from there. Copies
-- nothing back; the source is untouched.
function Replay.view(perception, tick)
	return {
		c = perception.c,
		smear = perception.smear,
		fadeTicks = perception.fadeTicks,
		echoFadeTicks = perception.echoFadeTicks,
		contacts = Perception.at(perception, tick),
		tick = tick,
		x = perception.x,
		y = perception.y,
	}
end

local FRAME = { 0.6, 1.0, 0.6, 1 }
local BACK = { 0.0, 0.08, 0.04, 0.8 }
local CURSOR = { 1, 1, 1, 0.9 }

-- `bar` is the strip rect, `cursorX` the scrubbed tick's x on it.
function Replay.drawBar(bar, cursorX, label)
	love.graphics.setColor(BACK)
	love.graphics.rectangle("fill", bar.x, bar.y, bar.w, bar.h)
	love.graphics.setColor(FRAME)
	love.graphics.rectangle("line", bar.x, bar.y, bar.w, bar.h)
	love.graphics.setColor(CURSOR)
	love.graphics.line(cursorX, bar.y, cursorX, bar.y + bar.h)
	love.graphics.setColor(FRAME)
	love.graphics.print(label, 16, 96)
	love.graphics.setColor(1, 1, 1, 1)
end

return Replay
