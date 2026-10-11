-- Match state and the one place the frame order lives (docs/ARCHITECTURE.md
-- "Systems and frame order"). Runs under plain LuaJIT with no `love` global.
local Level = require("src.game.level")
local Rng = require("src.core.rng")
local Bodies = require("src.sim.bodies")
local Integrate = require("src.sim.integrate")
local Collide = require("src.sim.collide")
local Pools = require("src.game.pools")
local SubSystem = require("src.game.systems.sub_system")
local TorpedoSystem = require("src.game.systems.torpedo_system")
local Turn = require("src.game.turn")
local OrderLog = require("src.game.order_log")
local Emissions = require("src.perception.emissions")
local Perception = require("src.perception.perception")
local Ping = require("src.perception.ping")
local Ai = require("src.game.ai.ai")

local Match = {}

-- Perception settings in the units perception works in: `c` is the speed of
-- sound in cells per tick. `archiveTicks` keeps contacts long enough to
-- replay a whole turn, back to what was still audible at its first tick.
local function soundSettings(config)
	local p = config.perception
	return {
		c = p.soundSpeed * config.dt / config.grid.cellSize,
		smear = p.smear,
		fadeTicks = p.fadeTicks,
		echoFadeTicks = p.echoFadeTicks,
		archiveTicks = config.turn.ticks + math.max(p.fadeTicks, p.echoFadeTicks),
	}
end

-- Enemy slots in fixed order: "enemy", "enemy2", ... (config.match.enemies).
local function enemySlots(config)
	local slots = {}
	for i = 1, config.match.enemies do
		slots[i] = i == 1 and "enemy" or "enemy" .. i
	end
	return slots
end

-- Where enemy `i` starts: the level's enemy spawn for the first, then the
-- level's `extraEnemies` list in order; past its end, the enemy spawn moved
-- up `EXTRA_SPAWN_STEP` px per extra enemy (kept below the surface).
local EXTRA_SPAWN_STEP = 60

local function enemySpawn(level, i)
	local base = level.subs.enemy
	if i == 1 then
		return base
	end
	local listed = level.extraEnemies and level.extraEnemies[i - 1]
	if listed then
		return listed
	end
	return { x = base.x, y = math.max(EXTRA_SPAWN_STEP, base.y - EXTRA_SPAWN_STEP * (i - 1)), order = base.order }
end

-- Every slot whose sub is AI-filled gets its own memory and RNG, seeded
-- from the match seed and its index alone (never ctx.rng draws).
local AI_SEED_STEP = 1000003

-- What the AI may read (ADR 0002): its own perception, its own ship (body
-- pose, helm and tube reloads, all copies), the static map and config, and
-- the clock. Never pools, other bodies, pings, blasts or emissions.
function Match.aiView(ctx, sub)
	local body = Bodies.get(ctx.bodies, sub.bodyId)
	local x, y = SubSystem.centre(ctx, sub)
	local tubes = {}
	for i, tube in ipairs(sub.tubes) do
		tubes[i] = { reload = tube.reload }
	end
	return {
		tick = ctx.tick,
		turnLength = ctx.turn.length,
		config = ctx.config,
		grid = ctx.grid,
		perception = sub.perception,
		own = {
			x = x,
			y = y,
			body = {
				x = body.x, y = body.y, angle = body.angle,
				vx = body.vx, vy = body.vy, angVel = body.angVel,
				shape = { length = body.shape.length, beam = body.shape.beam },
			},
			helm = { heading = sub.helm.heading, dive = sub.helm.dive, speed = sub.helm.speed, noise = sub.helm.noise },
			tubes = tubes,
		},
	}
end

local function subForSlot(ctx, slot)
	for _, sub in ipairs(ctx.pools.subs) do
		if sub.slot == slot and not sub.dead then
			return sub
		end
	end
	return nil
end

-- Plan phase: every AI slot submits through the same Turn.submit a human
-- uses (a slot whose sub is gone submits nothing, so the turn can run).
local function planAi(ctx)
	for _, ai in ipairs(ctx.ai) do
		local sub = subForSlot(ctx, ai.slot)
		local entries = {}
		if sub then
			entries = Ai.plan(ai.brain, Match.aiView(ctx, sub))
		end
		Turn.submit(ctx, ai.slot, entries)
	end
end

-- Execute phase: every AI slot keeps listening while its orders run.
local function listenAi(ctx)
	for _, ai in ipairs(ctx.ai) do
		local sub = subForSlot(ctx, ai.slot)
		if sub then
			Ai.listen(ai.brain, Match.aiView(ctx, sub))
		end
	end
end

-- `ctx` is the single table passed to every system: level, grid, config, rng,
-- tick counter, turn state, order log, the sound settings and the shared
-- emission history, the active pings (`pings`, oldest first) and the level's
-- boundary rock cells (`boundaryCells`, built once: terrain is static). Each
-- sub owns its perception (`sub.perception`). `sides` groups slots into the
-- two sides the round rules count ("player"; "enemy" with every enemy slot).
-- `ai` lists the AI-filled slots (`{ slot, brain }`), which submit at the
-- start of every plan phase; `opts.ai = false` leaves every slot to the
-- caller (scripted tests, replays). A match starts in the plan phase of
-- turn 1.
function Match.new(level, config, seed, opts)
	opts = opts or {}
	local ok, err = Level.validate(level)
	if not ok then
		error("invalid level: " .. tostring(err))
	end
	local enemies = enemySlots(config)
	local slots = { "player" }
	for _, slot in ipairs(enemies) do
		slots[#slots + 1] = slot
	end
	local ctx = {
		level = level,
		config = config,
		grid = Level.buildGrid(level, config),
		rng = Rng.new(seed),
		bodies = Bodies.new(),
		pools = Pools.new(),
		tick = 0,
		time = 0,
		turn = Turn.new(config, slots),
		sides = { { name = "player", slots = { "player" } }, { name = "enemy", slots = enemies } },
		ai = {},
		orderLog = OrderLog.new(),
		sound = soundSettings(config),
		pings = {},
		blasts = {},
	}
	ctx.boundaryCells = Ping.boundaryCells(ctx.grid)
	-- The smear seed is the first draw from the match RNG.
	ctx.emissions = Emissions.new(Emissions.capacityFor(ctx.grid, ctx.sound.c), ctx.rng:int(0, 2147483646))
	-- Fixed spawn order (not pairs) keeps pool order deterministic.
	SubSystem.spawn(ctx, "player", level.subs.player)
	for i, slot in ipairs(enemies) do
		SubSystem.spawn(ctx, slot, enemySpawn(level, i))
		if opts.ai ~= false then
			ctx.ai[#ctx.ai + 1] = { slot = slot, brain = Ai.new(seed + AI_SEED_STEP * i) }
		end
	end
	planAi(ctx)
	return ctx
end

-- The perception owned by the sub in `slot`, or nil if it has none.
function Match.perceptionOf(ctx, slot)
	for _, sub in ipairs(ctx.pools.subs) do
		if sub.slot == slot and not sub.dead then
			return sub.perception
		end
	end
	return nil
end

-- Fires the pings ordered this tick from each pinger's centre (the origin is
-- itself an emission, so every observer it reaches learns it), then records
-- an echo for every cell each active wavefront strikes this tick: boundary
-- rock and the hulls of every sub but the pinger (the wavefront starts inside
-- its own hull). Spent pings are dropped. Arrays only, in fixed order.
local function stepPings(ctx)
	local c, history, now = ctx.sound.c, ctx.emissions, ctx.tick
	for _, sub in ipairs(ctx.pools.subs) do
		if sub.pingOrdered then
			sub.pingOrdered = false
			local x, y = SubSystem.centre(ctx, sub)
			if x then
				local ping = Ping.new(x, y, now)
				ping.bodyId = sub.bodyId
				ctx.pings[#ctx.pings + 1] = ping
				Emissions.record(history, now, math.floor(x + 0.5), math.floor(y + 0.5), "ping", 0)
			end
		end
	end
	local kept = 0
	for i = 1, #ctx.pings do
		local ping = ctx.pings[i]
		for _, cell in ipairs(Ping.strike(ping, ctx.boundaryCells, ctx.grid, now, c)) do
			Emissions.record(history, now, cell.cx, cell.cy, "echo", 0)
		end
		for _, sub in ipairs(ctx.pools.subs) do
			if sub.bodyId ~= ping.bodyId then
				for _, cell in ipairs(Ping.strike(ping, SubSystem.echoCells(ctx, sub), ctx.grid, now, c)) do
					Emissions.record(history, now, cell.cx, cell.cy, "echo", 0)
				end
			end
		end
		-- Torpedo hulls echo like sub hulls (same shape of record).
		for _, torpedo in ipairs(ctx.pools.torpedoes) do
			for _, cell in ipairs(Ping.strike(ping, SubSystem.echoCells(ctx, torpedo), ctx.grid, now, c)) do
				Emissions.record(history, now, cell.cx, cell.cy, "echo", 0)
			end
		end
		if not Ping.spent(ping, ctx.grid, now, c) then
			kept = kept + 1
			ctx.pings[kept] = ping
		end
	end
	for i = kept + 1, #ctx.pings do
		ctx.pings[i] = nil
	end
end

local function recordEmissions(ctx)
	for _, sub in ipairs(ctx.pools.subs) do
		if not sub.dead then
			for _, c in ipairs(SubSystem.noisyCells(ctx, sub)) do
				Emissions.record(ctx.emissions, ctx.tick, c.cx, c.cy, "noise", sub.noise)
			end
		end
	end
	for _, torpedo in ipairs(ctx.pools.torpedoes) do
		for _, c in ipairs(TorpedoSystem.noisyCells(ctx, torpedo)) do
			Emissions.record(ctx.emissions, ctx.tick, c.cx, c.cy, "noise", torpedo.noise)
		end
	end
end

-- Observers listen from their body centre, in cell units (cell centres at
-- integer coordinates).
local function stepPerceptions(ctx)
	for _, sub in ipairs(ctx.pools.subs) do
		local x, y = SubSystem.centre(ctx, sub)
		if x then
			Perception.step(sub.perception, ctx.emissions, ctx.grid, x, y, ctx.tick)
		end
	end
end

local function sideAlive(ctx, side)
	for _, slot in ipairs(side.slots) do
		if subForSlot(ctx, slot) then
			return true
		end
	end
	return false
end

-- Round rules: once a side has no sub left the match is decided.
-- `ctx.result` becomes `{ tick, winner = side, draw = false }` when one
-- side is left ("player" or "enemy"), or `{ tick, draw = true }` when both
-- sides lost their last sub on the same tick; the turn phase becomes "over"
-- and the match takes no more ticks or orders.
local function decide(ctx)
	local survivor, left = nil, 0
	for _, side in ipairs(ctx.sides) do
		if sideAlive(ctx, side) then
			survivor, left = side.name, left + 1
		end
	end
	if left == #ctx.sides then
		return
	end
	if left == 0 then
		ctx.result = { tick = ctx.tick, draw = true }
	else
		ctx.result = { tick = ctx.tick, winner = survivor, draw = false }
	end
	ctx.turn.phase = "over"
end

-- One fixed step (config.dt): the whole frame order. Only the execute phase
-- has ticks; in the plan phase this does nothing and returns false.
-- Time is derived from the tick count so it never drifts.
function Match.step(ctx)
	if ctx.turn.phase ~= "execute" then
		return false
	end
	ctx.tick = ctx.tick + 1
	ctx.time = ctx.tick * ctx.config.dt

	-- 1. Orders scheduled at this tick of the turn reach their slots' subs.
	Turn.beginTick(ctx)
	-- 2. Helms turn course orders into body turn and speed.
	SubSystem.update(ctx)
	-- 3. Sim: move bodies, then undo any move that ends in rock or out of the water.
	Integrate.step(ctx.bodies, ctx.config.dt)
	Collide.resolve(ctx.bodies, ctx.grid)
	-- 4. Hull cells follow the resolved poses.
	SubSystem.refreshHulls(ctx)
	TorpedoSystem.refreshHulls(ctx)
	-- 5. Torpedoes: those in the water detonate (fuse, rock or hull) and
	-- their blasts sink subs; then tubes reload, and launches due this tick
	-- fire from where their subs now are.
	TorpedoSystem.update(ctx)
	TorpedoSystem.launch(ctx)
	-- 6. Pings: ordered pings fire from where their subs now are, and every
	-- active wavefront records an echo for each cell it strikes this tick.
	stepPings(ctx)
	-- 7. Emissions: every noisy cell is recorded at this tick.
	recordEmissions(ctx)
	-- 8. Perception: each observer hears what reaches it this tick, and each
	-- AI slot reads what its sub heard.
	stepPerceptions(ctx)
	listenAi(ctx)
	-- 9. Despawn sweep, the only place records are removed: pools before bodies.
	Pools.sweep(ctx.pools)
	Bodies.sweep(ctx.bodies)
	-- 10. Round rules: a side with no sub left ends the match; otherwise,
	-- after the turn's last tick, back to the plan phase, where the AI
	-- slots submit at once.
	decide(ctx)
	if not ctx.result then
		Turn.endTick(ctx)
		if ctx.turn.phase == "plan" then
			planAi(ctx)
		end
	end
	return true
end

return Match
