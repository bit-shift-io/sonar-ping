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

-- Runs torpedo `body` (a private copy) and its record `torpedo` (a copy:
-- launchTick, fuse, startX, startY, armed) the way TorpedoSystem.update does,
-- for the ticks after global tick `now`: up to `limit` ticks, past the end of
-- the run, or (no `limit`) only until the run ends. Hulls aside.
local function run(world, body, torpedo, now, limit)
	local config = world.config
	local store = Bodies.new()
	Bodies.add(store, body)
	local wasArmed = torpedo.armed
	local preview = { points = {} }
	local k = 0
	while (limit and k < limit) or (not limit and not preview.ends) do
		k = k + 1
		Integrate.step(store, config.dt)
		Collide.resolve(store, world.grid)
		preview.points[k] = { x = body.x, y = body.y }
		if not preview.ends then
			TorpedoSystem.arm(torpedo, body, config)
			if torpedo.armed and not wasArmed and not preview.armedAt then
				preview.armedAt = k
			end
			local ended = TorpedoSystem.runEnd(torpedo, body, now + k)
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
	local body = TorpedoSystem.newBody(x, y, order, config)
	local torpedo = { launchTick = 0, fuse = order.fuse, startX = x, startY = y, armed = false }
	return run(world, body, torpedo, 0, config.torpedo.speeds[order.speed].maxRun)
end

-- The rest of the run of own torpedo `torpedo` (a ctx.pools.torpedoes record
-- still running at plan start), from its body's current state, as the
-- execute phase after global tick ctx.tick takes it. Fuse and arming carry
-- over (`launchTick` keeps the fuse counted from the launch, so the run ends
-- on the sim's tick). Same shape as Predict.torpedo, with ticks counted from
-- plan start and points stopping where the run ends; `armedAt` is nil if it
-- was armed already. Reads copies; changes nothing in ctx.
function Predict.torpedoInFlight(ctx, torpedo)
	local body = copy(Bodies.get(ctx.bodies, torpedo.bodyId))
	return run(ctx, body, copy(torpedo), ctx.tick)
end

return Predict
