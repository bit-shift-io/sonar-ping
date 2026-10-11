-- Previews for the plan phase. Course: where a slot's sub will be after each
-- tick of the coming execute phase if it follows `entries` ({ tick, order }
-- as for Turn.submit). Torpedo: the straight run of a launch and where it
-- ends. Both run the sim's own functions (helm, torpedo system, integrate,
-- collide) on private copies in Match.step's order, so a preview cannot
-- drift from what the sim does. Read ctx; change nothing in it. Pure; no
-- `love.*`.
local Bodies = require("src.sim.bodies")
local Integrate = require("src.sim.integrate")
local Collide = require("src.sim.collide")
local Helm = require("src.game.components.helm")
local Turn = require("src.game.turn")
local TorpedoSystem = require("src.game.systems.torpedo_system")

local Predict = {}

local function copy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return c
end

local function subForSlot(ctx, slot)
	for _, sub in ipairs(ctx.pools.subs) do
		if sub.slot == slot and not sub.dead then
			return sub
		end
	end
	return nil
end

-- Array of `{ x, y, angle }`, one per tick of the turn (ctx.turn.length), or
-- an empty array when the slot has no sub.
function Predict.path(ctx, slot, entries)
	local sub = subForSlot(ctx, slot)
	if not sub then
		return {}
	end
	return Predict.pathFrom(ctx, Bodies.get(ctx.bodies, sub.bodyId), sub.helm, entries, ctx.turn.length)
end

-- The same projection from a sub's own body and helm (`{ x, y, angle, vx, vy,
-- angVel, shape }` and `{ heading, dive, speed, noise }`, both copied, never
-- changed) for `length` ticks. `world` needs only `config` and `grid`, so an
-- AI can plan its own ship without the match.
function Predict.pathFrom(world, ownBody, ownHelm, entries, length)
	local path = {}
	local config = world.config
	local store = Bodies.new()
	local body = copy(ownBody)
	Bodies.add(store, body)
	local helm = copy(ownHelm)

	for tick = 1, length do
		for _, order in ipairs(Turn.dueOrders(entries, tick)) do
			Turn.applyToHelm(helm, order, config)
		end
		Helm.update(helm, body, config)
		Integrate.step(store, config.dt)
		Collide.resolve(store, world.grid)
		path[tick] = { x = body.x, y = body.y, angle = body.angle }
	end
	return path
end

-- The run of torpedo order `order` launched from world point (x, y) (the
-- launching sub's position after its launch tick, e.g. Predict.path's point
-- for that tick). Hulls are unknown to a plan, so contact with them is not
-- previewed. `world` needs only `config` and `grid` (ctx will do). Returns:
--   points     `{ x, y }` after each tick of running, up to the speed's max run in ticks or
--              the tick it meets rock, whatever the fuse (the line the fuse
--              marker slides along);
--   ends       "fuse" or "rock": what ends the run;
--   endTick    ticks after launch at which it ends (points[endTick] is there);
--   armedAt    ticks after launch at which it arms, or nil if it never does;
--   detonation `{ x, y }` where it detonates, or nil for a dud.
function Predict.torpedo(world, x, y, order)
	local config = world.config
	local store = Bodies.new()
	local body = TorpedoSystem.newBody(x, y, order, config)
	Bodies.add(store, body)
	local torpedo = { launchTick = 0, fuse = order.fuse, startX = x, startY = y, armed = false }
	local preview = { points = {} }

	for k = 1, config.torpedo.speeds[order.speed].maxRun do
		Integrate.step(store, config.dt)
		Collide.resolve(store, world.grid)
		preview.points[k] = { x = body.x, y = body.y }
		if not preview.ends then
			TorpedoSystem.arm(torpedo, body, config)
			if torpedo.armed and not preview.armedAt then
				preview.armedAt = k
			end
			local ended = TorpedoSystem.runEnd(torpedo, body, k)
			if ended then
				preview.ends, preview.endTick = ended, k
				if torpedo.armed then
					preview.detonation = { x = body.x, y = body.y }
				end
			end
		end
		if body.blocked then
			break
		end
	end
	return preview
end

return Predict
