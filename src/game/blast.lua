-- Detonations (docs/CONTEXT.md "Blast radius"). A blast is a loud one-off
-- emission and an entry in `ctx.blasts` (`{ tick, x, y }` world px, oldest
-- first; read by the debug view and tests). No `love.*`.
local Grid = require("src.sim.grid")
local Emissions = require("src.perception.emissions")
local SubSystem = require("src.game.systems.sub_system")

local Blast = {}

-- True when a hull cell centre of `sub` lies within `radius` px of (x, y).
local function inside(ctx, sub, x, y, radius)
	for _, c in ipairs(sub.hull.cells) do
		local wx, wy = Grid.cellToWorld(ctx.grid, c.cx, c.cy)
		if (wx - x) ^ 2 + (wy - y) ^ 2 <= radius * radius then
			return true
		end
	end
	return false
end

-- A detonation at world point (x, y) on this tick: every live sub inside the
-- blast radius sinks.
function Blast.detonate(ctx, x, y)
	ctx.blasts[#ctx.blasts + 1] = { tick = ctx.tick, x = x, y = y }
	local cx, cy = Grid.worldToCell(ctx.grid, x, y)
	Emissions.record(ctx.emissions, ctx.tick, cx, cy, "blast", ctx.config.torpedo.blastNoise, true)
	for _, sub in ipairs(ctx.pools.subs) do
		if not sub.dead and inside(ctx, sub, x, y, ctx.config.torpedo.blastRadius) then
			SubSystem.kill(ctx, sub)
		end
	end
end

return Blast
