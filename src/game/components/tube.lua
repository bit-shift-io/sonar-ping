-- A torpedo tube (docs/CONTEXT.md "Tube"): `reload` is the ticks left until
-- it is loaded again (0 = loaded). Plain data plus functions; no `love.*`.
local Tube = {}

function Tube.new()
	return { reload = 0 }
end

function Tube.ready(tube)
	return tube.reload == 0
end

-- Fires the tube if it is loaded and starts its reload; returns whether it fired.
function Tube.fire(tube, config)
	if not Tube.ready(tube) then
		return false
	end
	tube.reload = config.tubes.reloadTicks
	return true
end

-- One execute tick of reloading.
function Tube.tick(tube)
	if tube.reload > 0 then
		tube.reload = tube.reload - 1
	end
end

return Tube
