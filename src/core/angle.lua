-- Angle helpers (radians). Pure; no `love.*`.
local Angle = {}

-- `angle` wrapped into [-pi, pi).
function Angle.wrap(angle)
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

return Angle
