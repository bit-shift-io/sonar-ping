-- A sub's hull: its shape and the cells it occupies this tick. The cell set is
-- computed per sub; the static grid is never mutated. No `love.*`.
local Collide = require("src.sim.collide")

local Hull = {}

function Hull.new(config)
	return { length = config.sub.length, beam = config.sub.beam, cells = {} }
end

function Hull.refresh(hull, body, grid)
	hull.cells = Collide.rasterHull(grid, body.x, body.y, body.angle, hull)
end

return Hull
