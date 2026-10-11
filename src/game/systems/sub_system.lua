-- Subs: spawn from the level table, carry out the standing course order, keep
-- hull cells current. Knows nothing about who (human or AI) gave the order.
local Bodies = require("src.sim.bodies")
local Grid = require("src.sim.grid")
local Helm = require("src.game.components.helm")
local Hull = require("src.game.components.hull")
local Tube = require("src.game.components.tube")
local Orders = require("src.game.orders")
local Perception = require("src.perception.perception")

local SubSystem = {}

-- Spawns the sub for `slot` ("player"/"enemy") from level spec `spec`
-- ({ x, y, order }). Errors on an invalid starting order.
function SubSystem.spawn(ctx, slot, spec)
	local ok, err = Orders.validate(spec.order, ctx.config)
	if not ok then
		error("invalid starting order for " .. slot .. ": " .. err)
	end
	local helm = Helm.new(spec.order, ctx.config)
	local hull = Hull.new(ctx.config)
	local body = {
		x = spec.x, y = spec.y, angle = Helm.targetAngle(helm),
		vx = 0, vy = 0, angVel = 0, shape = hull,
	}
	local sub = { slot = slot, bodyId = Bodies.add(ctx.bodies, body), helm = helm, hull = hull, noise = helm.noise, dead = false }
	-- Every sub is an observer (ADR 0002).
	sub.perception = Perception.new(ctx.sound)
	-- Loaded tubes, and the launch orders due this tick (Turn.beginTick).
	sub.tubes = {}
	for i = 1, ctx.config.tubes.count do
		sub.tubes[i] = Tube.new()
	end
	sub.launches = {}
	Hull.refresh(hull, body, ctx.grid)
	ctx.pools.subs[#ctx.pools.subs + 1] = sub
	return sub
end

-- Marks a sub and its body dead; the despawn sweep removes them.
function SubSystem.kill(ctx, sub)
	sub.dead = true
	Bodies.markDead(ctx.bodies, sub.bodyId)
end

-- Frame step 2: helms drive bodies.
function SubSystem.update(ctx)
	for _, sub in ipairs(ctx.pools.subs) do
		local body = Bodies.get(ctx.bodies, sub.bodyId)
		if body then
			Helm.update(sub.helm, body, ctx.config)
			sub.noise = sub.helm.noise
		end
	end
end

-- The hull cells that make noise: the aft `config.perception.noisyAft` of the
-- hull (propeller and engine), inside the grid. Empty when the sub is stopped
-- (noise 0) or has no body.
function SubSystem.noisyCells(ctx, sub)
	local body = Bodies.get(ctx.bodies, sub.bodyId)
	local cells = {}
	if not body or sub.noise <= 0 then
		return cells
	end
	local cos, sin = math.cos(body.angle), math.sin(body.angle)
	local limit = sub.hull.length * (ctx.config.perception.noisyAft - 0.5)
	for _, c in ipairs(sub.hull.cells) do
		if Grid.inBounds(ctx.grid, c.cx, c.cy) then
			local wx, wy = Grid.cellToWorld(ctx.grid, c.cx, c.cy)
			if (wx - body.x) * cos + (wy - body.y) * sin < limit then
				cells[#cells + 1] = c
			end
		end
	end
	return cells
end

-- A sub's body centre in perception's cell units (cell centres at integer
-- coordinates): where it listens from and pings from. Nil without a body.
function SubSystem.centre(ctx, sub)
	local body = not sub.dead and Bodies.get(ctx.bodies, sub.bodyId)
	if not body then
		return nil
	end
	local size = ctx.grid.cellSize
	return body.x / size + 0.5, body.y / size + 0.5
end

-- The hull cells a ping can strike, in cell units: each in-grid hull cell
-- `{ cx, cy }` plus the continuous position of that part of the hull now
-- (`x, y`: the cell centre shifted by the body's offset from its own cell
-- centre, so it moves smoothly instead of jumping cell to cell) and one tick
-- ago (`px, py`, by the body's last move). Ping.strike uses them to catch a
-- moving hull exactly once. Also used for torpedoes, which carry the same
-- `bodyId`, `hull` and `dead` fields.
function SubSystem.echoCells(ctx, sub)
	local cells = {}
	local body = not sub.dead and Bodies.get(ctx.bodies, sub.bodyId)
	if not body then
		return cells
	end
	local size = ctx.grid.cellSize
	local bx, by = body.x / size + 0.5, body.y / size + 0.5
	local ox, oy = bx - math.floor(bx + 0.5), by - math.floor(by + 0.5)
	local mx, my = (body.x - (body.prevX or body.x)) / size, (body.y - (body.prevY or body.y)) / size
	for _, c in ipairs(sub.hull.cells) do
		if Grid.inBounds(ctx.grid, c.cx, c.cy) then
			local x, y = c.cx + ox, c.cy + oy
			cells[#cells + 1] = { cx = c.cx, cy = c.cy, x = x, y = y, px = x - mx, py = y - my }
		end
	end
	return cells
end

-- After collision: hull cells follow the resolved pose.
function SubSystem.refreshHulls(ctx)
	for _, sub in ipairs(ctx.pools.subs) do
		local body = Bodies.get(ctx.bodies, sub.bodyId)
		if body then
			Hull.refresh(sub.hull, body, ctx.grid)
		end
	end
end

return SubSystem
