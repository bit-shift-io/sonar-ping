-- Every order a match has committed, as scheduled `{ turn, tick, slot, order }`
-- entries in commit order. Seed + order log reproduces a match (ADR 0003), so
-- replay and online lockstep read from here. Pure; no `love.*`.
local OrderLog = {}

function OrderLog.new()
	return { entries = {} }
end

function OrderLog.append(log, entry)
	log.entries[#log.entries + 1] = entry
end

-- One slot's orders for one turn, in the `{ tick, order }` form Turn.submit takes.
function OrderLog.forTurn(log, turn, slot)
	local scheduled = {}
	for _, entry in ipairs(log.entries) do
		if entry.turn == turn and entry.slot == slot then
			scheduled[#scheduled + 1] = { tick = entry.tick, order = entry.order }
		end
	end
	return scheduled
end

return OrderLog
