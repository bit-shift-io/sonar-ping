-- The turn loop (docs/CONTEXT.md "Turn"): a paused plan phase, then an execute
-- phase of `config.turn.ticks` ticks. Each slot submits its scheduled orders
-- (`{ tick, order }`, tick 1..length within the turn) through Turn.submit;
-- the execute phase starts once every slot has. Nothing here knows whether a
-- human or an AI filled a slot. Pure; no `love.*`.
local Orders = require("src.game.orders")
local OrderLog = require("src.game.order_log")
local Helm = require("src.game.components.helm")

local Turn = {}

-- `slots` is the fixed slot order (player first); it fixes the order orders
-- are logged and applied in, so nothing depends on table iteration order.
function Turn.new(config, slots)
	return {
		phase = "plan",
		number = 1,
		tick = 0, -- ticks run so far in the current execute phase
		length = config.turn.ticks,
		slots = slots,
		queues = {}, -- slot -> submitted { tick, order } entries
	}
end

local function copyOrder(order)
	local copy = {}
	for k, v in pairs(order) do
		copy[k] = v
	end
	return copy
end

local function validateEntry(entry, turn, config)
	local tick = entry.tick
	if type(tick) ~= "number" or tick ~= math.floor(tick) or tick < 1 or tick > turn.length then
		error("order tick must be an integer in 1.." .. turn.length .. ", got " .. tostring(tick))
	end
	local ok, err = Orders.validate(entry.order, config)
	if not ok then
		error("invalid order: " .. err)
	end
end

-- Every slot has submitted: log the turn's orders in slot order and execute.
local function commit(ctx)
	local turn = ctx.turn
	for _, slot in ipairs(turn.slots) do
		for _, entry in ipairs(turn.queues[slot]) do
			OrderLog.append(ctx.orderLog, { turn = turn.number, tick = entry.tick, slot = slot, order = entry.order })
		end
	end
	turn.phase = "execute"
	turn.tick = 0
end

-- `slot` commits its orders for this turn. Errors outside the plan phase, on a
-- tick outside the turn, or on an invalid order. Orders are copied, so the
-- caller may keep editing its own tables.
function Turn.submit(ctx, slot, entries)
	local turn = ctx.turn
	if turn.phase ~= "plan" then
		error("orders can only be submitted in the plan phase")
	end
	local queue = {}
	for _, entry in ipairs(entries) do
		validateEntry(entry, turn, ctx.config)
		queue[#queue + 1] = { tick = entry.tick, order = copyOrder(entry.order) }
	end
	turn.queues[slot] = queue

	for _, s in ipairs(turn.slots) do
		if not turn.queues[s] then
			return
		end
	end
	commit(ctx)
end

-- The orders in `entries` scheduled at turn tick `tick`, in submit order.
-- Shared by the sim (Turn.beginTick) and the course preview (Predict).
function Turn.dueOrders(entries, tick)
	local due = {}
	for _, entry in ipairs(entries) do
		if entry.tick == tick then
			due[#due + 1] = entry.order
		end
	end
	return due
end

-- An order's effect on a helm. Only course orders steer; ping and torpedo
-- launch leave the helm alone.
function Turn.applyToHelm(helm, order, config)
	if order.kind == "course" then
		Helm.apply(helm, order, config)
	end
end

local function subForSlot(ctx, slot)
	for _, sub in ipairs(ctx.pools.subs) do
		if sub.slot == slot and not sub.dead then
			return sub
		end
	end
	return nil
end

-- Frame step 1: count the tick and hand each slot's due orders to its sub. A
-- ping order raises `sub.pingOrdered` and a torpedo order joins
-- `sub.launches`; both fire later this tick, once the sub has moved
-- (Match.step).
function Turn.beginTick(ctx)
	local turn = ctx.turn
	turn.tick = turn.tick + 1
	for _, slot in ipairs(turn.slots) do
		local sub = subForSlot(ctx, slot)
		if sub then
			for _, order in ipairs(Turn.dueOrders(turn.queues[slot], turn.tick)) do
				if order.kind == "ping" then
					sub.pingOrdered = true
				elseif order.kind == "torpedo" then
					sub.launches[#sub.launches + 1] = order
				end
				Turn.applyToHelm(sub.helm, order, ctx.config)
			end
		end
	end
end

-- Last frame step: after the turn's final tick, back to a fresh plan phase.
function Turn.endTick(ctx)
	local turn = ctx.turn
	if turn.tick >= turn.length then
		turn.phase = "plan"
		turn.number = turn.number + 1
		turn.tick = 0
		turn.queues = {}
	end
end

return Turn
