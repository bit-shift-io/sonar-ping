-- Torpedoes (docs/CONTEXT.md "Torpedo", "Fuse"): launched from a sub's tube
-- by a torpedo order, they run straight at a fixed speed, make noise every
-- tick, and detonate at their fuse, on rock or on a hull. Knows nothing about
-- who (human or AI) gave the order. The motion is the sim's own integrate and
-- collide; Predict.torpedo runs the same functions for the plan preview.
-- No `love.*`.
local Bodies = require("src.sim.bodies")
local Grid = require("src.sim.grid")
local Hull = require("src.game.components.hull")
local Tube = require("src.game.components.tube")
local Emissions = require("src.perception.emissions")
local Blast = require("src.game.blast")

local TorpedoSystem = {}

-- A torpedo body launched by `order` from world point (x, y): pointing and
-- moving along the launch angle at the ordered speed, never turning.
function TorpedoSystem.newBody(x, y, order, config)
	local t = config.torpedo
	local speed = t.speeds[order.speed].speed
	return {
		x = x, y = y, angle = order.angle,
		vx = speed * math.cos(order.angle), vy = speed * math.sin(order.angle), angVel = 0,
		shape = { length = t.length, beam = t.beam, cells = {} },
	}
end

-- Records a one-off emission of `level` at world point (x, y) (the cell holding it).
local function emitAt(ctx, x, y, kind, level)
	local cx, cy = Grid.worldToCell(ctx.grid, x, y)
	Emissions.record(ctx.emissions, ctx.tick, cx, cy, kind, level)
end

local function spawn(ctx, sub, subBody, order)
	local body = TorpedoSystem.newBody(subBody.x, subBody.y, order, ctx.config)
	local torpedo = {
		owner = sub.slot,
		bodyId = Bodies.add(ctx.bodies, body),
		hull = body.shape,
		launchTick = ctx.tick,
		fuse = order.fuse,
		noise = ctx.config.torpedo.speeds[order.speed].noise,
		startX = body.x,
		startY = body.y,
		armed = false,
		dead = false,
	}
	Hull.refresh(torpedo.hull, body, ctx.grid)
	ctx.pools.torpedoes[#ctx.pools.torpedoes + 1] = torpedo
	emitAt(ctx, body.x, body.y, "noise", ctx.config.torpedo.launchNoise)
	return torpedo
end

-- After collision: hull cells follow the resolved pose.
function TorpedoSystem.refreshHulls(ctx)
	for _, torpedo in ipairs(ctx.pools.torpedoes) do
		local body = Bodies.get(ctx.bodies, torpedo.bodyId)
		if body then
			Hull.refresh(torpedo.hull, body, ctx.grid)
		end
	end
end

local function remove(ctx, torpedo)
	torpedo.dead = true
	Bodies.markDead(ctx.bodies, torpedo.bodyId)
end

-- Arms `torpedo` (for good) once its body is armDistance from the launch point.
function TorpedoSystem.arm(torpedo, body, config)
	local dx, dy = body.x - torpedo.startX, body.y - torpedo.startY
	local d = config.torpedo.armDistance
	torpedo.armed = torpedo.armed or dx * dx + dy * dy >= d * d
end

-- How the run ends on tick `now`, hulls aside: "rock" when the move just
-- made was blocked (Collide.resolve put it back at its last pose in the
-- water), "fuse" once the fuse has run out, else nil.
function TorpedoSystem.runEnd(torpedo, body, now)
	if body.blocked then
		return "rock"
	end
	if now - torpedo.launchTick >= torpedo.fuse then
		return "fuse"
	end
	return nil
end

-- True when a cell of `torpedo`'s hull is a cell of a live sub's hull.
local function touchesHull(ctx, torpedo)
	for _, sub in ipairs(ctx.pools.subs) do
		if not sub.dead then
			for _, a in ipairs(torpedo.hull.cells) do
				for _, b in ipairs(sub.hull.cells) do
					if a.cx == b.cx and a.cy == b.cy then
						return true
					end
				end
			end
		end
	end
	return false
end

-- Each torpedo launched before this tick arms once far enough out, then
-- ends its run on rock, at its fuse, or (armed only) on a hull. An armed
-- torpedo detonates where it is; an unarmed one is a dud and just goes.
-- Unarmed torpedoes pass through hulls (the firing sub's included).
function TorpedoSystem.update(ctx)
	for _, torpedo in ipairs(ctx.pools.torpedoes) do
		local body = not torpedo.dead and Bodies.get(ctx.bodies, torpedo.bodyId)
		if body and torpedo.launchTick < ctx.tick then
			TorpedoSystem.arm(torpedo, body, ctx.config)
			local ended = TorpedoSystem.runEnd(torpedo, body, ctx.tick) or (torpedo.armed and touchesHull(ctx, torpedo))
			if ended then
				if torpedo.armed then
					Blast.detonate(ctx, body.x, body.y)
				end
				remove(ctx, torpedo)
			end
		end
	end
end

-- A running torpedo is noisy end to end: every in-grid hull cell.
function TorpedoSystem.noisyCells(ctx, torpedo)
	local cells = {}
	if torpedo.dead then
		return cells
	end
	for _, c in ipairs(torpedo.hull.cells) do
		if Grid.inBounds(ctx.grid, c.cx, c.cy) then
			cells[#cells + 1] = c
		end
	end
	return cells
end

-- Tubes reload one tick; then each live sub's launch orders due this tick
-- fire from their tubes, if loaded, at the sub's resolved pose. A launch from
-- an empty tube does nothing. Launch orders are spent either way.
function TorpedoSystem.launch(ctx)
	for _, sub in ipairs(ctx.pools.subs) do
		local body = not sub.dead and Bodies.get(ctx.bodies, sub.bodyId)
		if body then
			for _, tube in ipairs(sub.tubes) do
				Tube.tick(tube)
			end
			for _, order in ipairs(sub.launches) do
				if Tube.fire(sub.tubes[order.tube], ctx.config) then
					spawn(ctx, sub, body, order)
				end
			end
		end
		sub.launches = {}
	end
end

return TorpedoSystem
