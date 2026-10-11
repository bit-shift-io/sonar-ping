-- Debug view only: draws the true level grid's rock in a translucent
-- contrasting colour, so it can sit over the sonar view without hiding it.
-- Called from src/app/render/debug.lua; the player render never draws true
-- terrain (docs/ARCHITECTURE.md, docs/adr/0002). Draws in world pixels (the
-- grid's own units); the caller applies the screen fit. No `love.*` at load
-- time.
local Grid = require("src.sim.grid")

local Terrain = {}

local ROCK = { 1.0, 0.6, 0.15, 0.35 }

function Terrain.draw(grid)
	local size = grid.cellSize
	love.graphics.setColor(ROCK)
	for cx = 1, grid.width do
		local runStart = nil
		for cy = 1, grid.height + 1 do
			local isRock = Grid.get(grid, cx, cy) == Grid.ROCK
			if isRock and not runStart then
				runStart = cy
			elseif not isRock and runStart then
				love.graphics.rectangle("fill", (cx - 1) * size, (runStart - 1) * size, size, (cy - runStart) * size)
				runStart = nil
			end
		end
	end
	love.graphics.setColor(1, 1, 1, 1)
end

return Terrain
