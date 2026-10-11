-- Sparse ring history of dynamic emissions (ADR 0002): one bucket per tick,
-- each an array of `{ tick, cx, cy, kind, level }`. Only moving or noisy cells
-- are recorded; terrain is static and lives in the level grid. A bucket is
-- overwritten when its slot comes round again, so history drops old ticks
-- deterministically. `kind` is "noise" for now; pings will add their own kind.
-- Pure; no `love.*`.
local Emissions = {}

-- `capacity` ticks of history; `seed` seeds each emission's smear.
function Emissions.new(capacity, seed)
	return { capacity = capacity, seed = seed, buckets = {}, ticks = {} }
end

-- Ticks of history needed for sound at `c` cells per tick to cross the grid's
-- longest diagonal, plus the tick before it (the arrival test looks back one).
function Emissions.capacityFor(grid, c)
	local diagonal = math.sqrt((grid.width - 1) ^ 2 + (grid.height - 1) ^ 2)
	return math.ceil(diagonal / c) + 1
end

local function slot(history, tick)
	return tick % history.capacity + 1
end

-- Records cell (cx, cy) emitting at `tick`. Ticks are recorded in order.
function Emissions.record(history, tick, cx, cy, kind, level)
	local i = slot(history, tick)
	local bucket = history.buckets[i]
	if history.ticks[i] ~= tick then
		bucket = {}
		history.buckets[i] = bucket
		history.ticks[i] = tick
	end
	bucket[#bucket + 1] = { tick = tick, cx = cx, cy = cy, kind = kind, level = level }
end

-- The emissions recorded at `tick`, or nil if none were or they were dropped.
function Emissions.bucket(history, tick)
	local i = slot(history, tick)
	if history.ticks[i] ~= tick then
		return nil
	end
	return history.buckets[i]
end

return Emissions
