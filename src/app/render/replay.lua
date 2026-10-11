-- The replay's view (the timeline's left half): the player's own perception
-- as it stood at a past tick, built from perception alone (ADR 0002; a unit
-- test checks this module's requires). The strip and the cursor's time label
-- are drawn by render/timeline. SonarView draws the view like any live
-- perception. Own ship is shown where it was at the tick (Perception.positionAt).
-- Draws in world px; the caller applies the screen fit. No `love.*` at load time.
local Perception = require("src.perception.perception")

local Replay = {}

-- A perception-shaped snapshot of `perception` at past `tick`: the contacts it
-- held then, with `tick` as its clock so ages count from there. Copies
-- nothing back; the source is untouched.
function Replay.view(perception, tick)
	local x, y = Perception.positionAt(perception, tick)
	return {
		c = perception.c,
		smear = perception.smear,
		fadeTicks = perception.fadeTicks,
		echoFadeTicks = perception.echoFadeTicks,
		contacts = Perception.at(perception, tick),
		tick = tick,
		x = x or perception.x,
		y = y or perception.y,
	}
end

return Replay
