-- Seed + order log reproduces a match (ADR 0003): replaying the log into a
-- fresh match from the same seed gives identical true state and identical
-- per-observer perception every tick -- with the AI filling the enemy slot,
-- whose orders the log holds like any other.
local Match = require("src.game.match")
local Config = require("src.game.config")
local Turn = require("src.game.turn")
local Orders = require("src.game.orders")
local OrderLog = require("src.game.order_log")
local Bodies = require("src.sim.bodies")
local Trench = require("src.game.levels.trench")

local SEED = 20261011

-- Mixed orders for the player, including mid-turn orders, pings and a
-- torpedo launch; it runs east over the ridge towards the enemy, noisy, then
-- holds its last course once the plan runs out. The enemy is the AI, which
-- fills its slot from what it hears each plan phase: it fires back from turn 2
-- and sinks the player in turn 6.
local PLAN = {
	{
		{ tick = 1, order = Orders.course("east", math.rad(-10), "full") },
		{ tick = 1, order = Orders.ping() },
		{ tick = 120, order = Orders.torpedo(1, math.rad(5), "fast", 400) },
	},
	{
		{ tick = 1, order = Orders.course("east", math.rad(-5), "half") },
		{ tick = 200, order = Orders.course("west", 0, "slow") },
	},
	{
		{ tick = 150, order = Orders.course("west", math.rad(-30), "full") },
		{ tick = 100, order = Orders.ping() },
		{ tick = 250, order = Orders.ping() },
	},
}

-- Bound on the turns a match is played for, so a fixture that stops ending
-- fails instead of running on.
local MAX_TURNS = 10

-- An observer's perception as one comparable string: contact count plus an
-- order-sensitive checksum of every contact.
local function perceptionDigest(perception)
	local sum = 0
	for i, c in ipairs(perception.contacts) do
		sum = sum + i * (c.x * 7 + c.y * 13 + c.arrivalTick + c.level + c.kind:byte(1))
	end
	return string.format("%d %d %.17g %s", #perception.contacts, #perception.archive, sum, tostring(perception.tick))
end

-- Every piece of true state and perception a tick can change, as one
-- comparable string.
local function snapshot(ctx)
	local parts = { ctx.tick, ctx.turn.phase, ctx.turn.number, ctx.turn.tick, ctx.rng.state, #ctx.pings, #ctx.blasts }
	for _, t in ipairs(ctx.pools.torpedoes) do
		local b = Bodies.get(ctx.bodies, t.bodyId)
		parts[#parts + 1] = string.format(
			"T %s %d %.17g %.17g %s %s %d",
			t.owner, t.bodyId, b and b.x or -1, b and b.y or -1, tostring(t.armed), tostring(t.dead), #t.hull.cells
		)
	end
	for _, blast in ipairs(ctx.blasts) do
		parts[#parts + 1] = string.format("B %d %.17g %.17g", blast.tick, blast.x, blast.y)
	end
	if ctx.result then
		parts[#parts + 1] = string.format("R %d %s %s", ctx.result.tick, tostring(ctx.result.winner), tostring(ctx.result.draw))
	end
	for _, sub in ipairs(ctx.pools.subs) do
		local b = Bodies.get(ctx.bodies, sub.bodyId)
		parts[#parts + 1] = string.format(
			"%s %.17g %.17g %.17g %.17g %.17g %.17g %s %s %s %.17g %s %d",
			sub.slot, b.x, b.y, b.angle, b.vx, b.vy, b.angVel, tostring(b.blocked),
			sub.helm.heading, sub.helm.speed, sub.helm.dive, sub.noise, #sub.hull.cells
		)
		for _, tube in ipairs(sub.tubes) do
			parts[#parts + 1] = "tube " .. tube.reload
		end
		for _, c in ipairs(sub.hull.cells) do
			parts[#parts + 1] = c.cx .. "," .. c.cy
		end
		parts[#parts + 1] = perceptionDigest(sub.perception)
	end
	return table.concat(parts, "|")
end

-- Plays the match until it ends (or MAX_TURNS) and returns the snapshot
-- after every tick. `replayLog` nil: the player follows PLAN and the
-- AI fills the enemy slot. Otherwise both slots replay that order log, with
-- no AI.
local function play(replayLog)
	local ctx = Match.new(Trench, Config, SEED, { ai = replayLog == nil })
	local snapshots = {}
	for turn = 1, MAX_TURNS do
		if ctx.result then
			break
		end
		if replayLog then
			Turn.submit(ctx, "player", OrderLog.forTurn(replayLog, turn, "player"))
			Turn.submit(ctx, "enemy", OrderLog.forTurn(replayLog, turn, "enemy"))
		else
			Turn.submit(ctx, "player", PLAN[turn] or {})
		end
		while Match.step(ctx) do
			snapshots[#snapshots + 1] = snapshot(ctx)
		end
	end
	return snapshots, ctx
end

local function enemyOrderKinds(log)
	local kinds = {}
	for _, entry in ipairs(log.entries) do
		if entry.slot == "enemy" then
			kinds[entry.order.kind] = (kinds[entry.order.kind] or 0) + 1
		end
	end
	return kinds
end

test("a match with the AI active, replayed from its seed and order log, is identical every tick, perception included", function()
	local original, ctx = play()

	local replayed = play(ctx.orderLog)

	local kinds = enemyOrderKinds(ctx.orderLog)
	assertTrue((kinds.course or 0) > 0, "the log holds the AI's course orders")
	assertTrue((kinds.torpedo or 0) > 0, "the log holds the AI's launches")
	assertTrue(ctx.result ~= nil, "fixture: the match ends")
	assertEqual("enemy", ctx.result.winner, "fixture: the AI sank the player")
	assertEqual(6, ctx.turn.number)
	assertEqual(#original, #replayed)
	for i = 1, #original do
		assertEqual(original[i], replayed[i], "true state differs at tick " .. i)
	end
end)
