-- Shared sim body store: every moving hull (sub, later torpedo) has one body
-- record here. Pools reference a body by id, never by table reference, and
-- ids are generation-checked: Bodies.get returns nil for a stale id, never a
-- reused slot's body. Pure data; no `love.*`.
-- A body is `{ x, y, angle, vx, vy, angVel, shape = { length, beam } }`
-- (world px, radians, px/s, rad/s).
local Bodies = {}

local GENERATION_MULTIPLIER = 1000000

local function encode(slot, generation)
	return slot * GENERATION_MULTIPLIER + generation
end

local function decode(id)
	local slot = math.floor(id / GENERATION_MULTIPLIER)
	return slot, id - slot * GENERATION_MULTIPLIER
end

function Bodies.new()
	return {
		slots = {}, -- slot index -> body record, or nil if free
		generations = {}, -- slot index -> generation currently occupying it
		freeSlots = {}, -- stack of slot indices freed by the last sweep
		slotCount = 0,
	}
end

-- Adds `body` to the store and returns its id. A freed slot is reused with a
-- bumped generation so ids held from before the free no longer resolve.
function Bodies.add(store, body)
	local slot
	if #store.freeSlots > 0 then
		slot = table.remove(store.freeSlots)
	else
		store.slotCount = store.slotCount + 1
		slot = store.slotCount
	end

	local generation = (store.generations[slot] or 0) + 1
	store.generations[slot] = generation
	body.dead = false
	store.slots[slot] = body

	return encode(slot, generation)
end

-- The body for `id`, or nil if the id is stale or the body is marked dead.
function Bodies.get(store, id)
	local slot, generation = decode(id)
	if store.generations[slot] ~= generation then
		return nil
	end
	local body = store.slots[slot]
	if not body or body.dead then
		return nil
	end
	return body
end

-- Marks the body dead without removing it; only Bodies.sweep removes records.
function Bodies.markDead(store, id)
	local body = Bodies.get(store, id)
	if body then
		body.dead = true
	end
end

-- Removes every dead body and frees its slot. Numeric loop so the free-slot
-- order (and so slot reuse) is deterministic. The only place bodies are removed.
function Bodies.sweep(store)
	for slot = 1, store.slotCount do
		local body = store.slots[slot]
		if body and body.dead then
			store.slots[slot] = nil
			table.insert(store.freeSlots, slot)
		end
	end
end

return Bodies
