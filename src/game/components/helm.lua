-- A sub's helm: its standing course order and the noise of its speed setting.
-- Turns the body towards the ordered course at the configured turn rate and
-- sets its speed. Plain data plus functions; no `love.*`.
local Angle = require("src.core.angle")

local Helm = {}

local function clamp(v, limit)
	return math.max(-limit, math.min(limit, v))
end

function Helm.apply(helm, order, config)
	helm.heading = order.heading
	helm.dive = order.dive
	helm.speed = order.speed
	helm.noise = config.speeds[order.speed].noise
end

function Helm.new(order, config)
	local helm = {}
	Helm.apply(helm, order, config)
	return helm
end

-- Angle in the side view (0 = east, y down) the order asks the sub to point at.
function Helm.targetAngle(helm)
	if helm.heading == "east" then
		return helm.dive
	end
	return Angle.wrap(math.pi - helm.dive)
end

-- Sets the body's turn and velocity for the coming step.
function Helm.update(helm, body, config)
	local delta = Angle.wrap(Helm.targetAngle(helm) - body.angle)
	body.angVel = clamp(delta, config.sub.turnRate) / config.dt
	local speed = config.speeds[helm.speed].speed
	body.vx = speed * math.cos(body.angle)
	body.vy = speed * math.sin(body.angle)
end

return Helm
