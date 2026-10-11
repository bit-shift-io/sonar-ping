-- Typed pools of plain-data records. Pools own record lifetime; systems own
-- behaviour. Pools.sweep runs before Bodies.sweep so no record is left
-- pointing at a freed body. The only place records are removed.
local Pools = {}

function Pools.new()
	return { subs = {}, torpedoes = {} }
end

local function sweepArray(array)
	local kept = {}
	for _, record in ipairs(array) do
		if not record.dead then
			kept[#kept + 1] = record
		end
	end
	for i = #array, 1, -1 do
		array[i] = nil
	end
	for i, record in ipairs(kept) do
		array[i] = record
	end
end

function Pools.sweep(pools)
	sweepArray(pools.subs)
	sweepArray(pools.torpedoes)
end

return Pools
