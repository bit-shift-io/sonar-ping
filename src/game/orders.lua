-- Order shapes and validation. An order is the only way a slot (human or AI)
-- affects the sim. Orders are scheduled at a tick of the turn (Turn.submit).
-- Pure; no `love.*`.
local Orders = {}

-- Course: `heading` "east" or "west" (side view), `dive` angle in radians
-- (positive = nose down), `speed` a key of config.speeds.
function Orders.course(heading, dive, speed)
	return { kind = "course", heading = heading, dive = dive, speed = speed }
end

-- Ping: one active sonar pulse from the sub's position at its tick.
function Orders.ping()
	return { kind = "ping" }
end

-- Torpedo launch: fire tube `tube` (1..config.tubes.count) at `angle`
-- radians in the side view (0 = east, y down), at `speed` (a key of
-- config.torpedo.speeds), detonating `fuse` ticks after launch.
function Orders.torpedo(tube, angle, speed, fuse)
	return { kind = "torpedo", tube = tube, angle = angle, speed = speed, fuse = fuse }
end

local function isInteger(v)
	return type(v) == "number" and v == math.floor(v)
end

local function validateTorpedo(order, config)
	if not isInteger(order.tube) or order.tube < 1 or order.tube > config.tubes.count then
		return false, "tube must be 1.." .. config.tubes.count
	end
	if type(order.angle) ~= "number" or order.angle ~= order.angle or math.abs(order.angle) == math.huge then
		return false, "angle must be a finite number"
	end
	if config.torpedo.speeds[order.speed] == nil then
		return false, "unknown torpedo speed: " .. tostring(order.speed)
	end
	if not isInteger(order.fuse) or order.fuse < 1 or order.fuse > config.torpedo.maxFuse then
		return false, "fuse must be an integer in 1.." .. config.torpedo.maxFuse
	end
	return true
end

-- Returns true, or false plus an error message.
function Orders.validate(order, config)
	if type(order) ~= "table" then
		return false, "order must be a table"
	end
	if order.kind == "ping" then
		return true
	end
	if order.kind == "torpedo" then
		return validateTorpedo(order, config)
	end
	if order.kind ~= "course" then
		return false, "unknown order kind: " .. tostring(order.kind)
	end
	if order.heading ~= "east" and order.heading ~= "west" then
		return false, "heading must be east or west"
	end
	if type(order.dive) ~= "number" or math.abs(order.dive) > config.sub.maxDive then
		return false, "dive must be a number within the configured limit"
	end
	if config.speeds[order.speed] == nil then
		return false, "unknown speed setting: " .. tostring(order.speed)
	end
	return true
end

return Orders
