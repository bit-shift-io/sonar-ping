local Bodies = require("src.sim.bodies")
local Integrate = require("src.sim.integrate")
local Helm = require("src.game.components.helm")
local Orders = require("src.game.orders")
local Config = require("src.game.config")

local DT = Config.dt

local function newBody(angle)
	local store = Bodies.new()
	local body = { x = 100, y = 100, angle = angle or 0, vx = 0, vy = 0, angVel = 0 }
	Bodies.add(store, body)
	return store, body
end

local function tick(helm, store, body)
	Helm.update(helm, body, Config)
	Integrate.step(store, DT)
end

test("a westbound course order turns an eastbound sub at the configured turn rate", function()
	local store, body = newBody(0)
	local helm = Helm.new(Orders.course("west", 0, Config.speeds.slow.speed), Config)

	tick(helm, store, body)

	assertNear(Config.sub.turnRate, math.abs(body.angle), 0.000001)
end)

test("the sub settles exactly on the ordered dive angle without overshooting", function()
	local store, body = newBody(0)
	local dive = math.rad(20)
	local helm = Helm.new(Orders.course("east", dive, Config.speeds.slow.speed), Config)

	for _ = 1, 200 do
		tick(helm, store, body)
	end

	assertNear(dive, body.angle, 0.000001)
end)

test("a westbound sub diving 20 degrees points down and to the left", function()
	local store, body = newBody(math.pi - math.rad(20))
	local helm = Helm.new(Orders.course("west", math.rad(20), Config.speeds.full.speed), Config)

	tick(helm, store, body)

	assertTrue(body.vx < 0, "heading west moves left")
	assertTrue(body.vy > 0, "positive dive moves down (y points down)")
end)

test("each speed anchor gives its configured speed and noise level", function()
	for _, name in ipairs({ "stop", "slow", "half", "full" }) do
		local store, body = newBody(0)
		local helm = Helm.new(Orders.course("east", 0, Config.speeds[name].speed), Config)

		tick(helm, store, body)

		assertNear(Config.speeds[name].speed, math.sqrt(body.vx ^ 2 + body.vy ^ 2), 0.000001, name)
		assertEqual(Config.speeds[name].noise, helm.noise, name)
	end
end)

test("the sub moves at exactly the ordered speed between anchors", function()
	local store, body = newBody(0)
	local helm = Helm.new(Orders.course("east", 0, 33), Config)

	tick(helm, store, body)

	assertNear(33, math.sqrt(body.vx ^ 2 + body.vy ^ 2), 0.000001)
end)

test("a speed between two anchors makes noise interpolated between theirs", function()
	local half, full = Config.speeds.half, Config.speeds.full
	local speed = half.speed + (full.speed - half.speed) * 0.25

	local helm = Helm.new(Orders.course("east", 0, speed), Config)

	assertNear(half.noise + (full.noise - half.noise) * 0.25, helm.noise, 0.000001)
end)

test("a stopped sub is silent", function()
	assertEqual(0, Helm.new(Orders.course("east", 0, 0), Config).noise)
end)

test("speeds get louder from stop to full", function()
	local last = -1
	for _, name in ipairs({ "stop", "slow", "half", "full" }) do
		assertTrue(Config.speeds[name].noise > last, name .. " is louder than the setting below it")
		assertTrue(Config.speeds[name].speed >= 0)
		last = Config.speeds[name].noise
	end
end)

test("a new course order replaces the helm's heading, dive and speed", function()
	local helm = Helm.new(Orders.course("east", 0, Config.speeds.slow.speed), Config)

	Helm.apply(helm, Orders.course("west", math.rad(10), Config.speeds.full.speed), Config)

	assertEqual("west", helm.heading)
	assertNear(math.rad(10), helm.dive, 0.000001)
	assertEqual(Config.speeds.full.speed, helm.speed)
	assertEqual(Config.speeds.full.noise, helm.noise)
end)

test("Orders.validate accepts a good course order and rejects bad ones", function()
	assertTrue(Orders.validate(Orders.course("east", 0, 45), Config))
	assertFalse(Orders.validate(Orders.course("north", 0, 45), Config), "unknown heading")
	assertFalse(Orders.validate(Orders.course("east", math.rad(80), 45), Config), "dive beyond the limit")
	assertFalse(Orders.validate({ kind = "dance" }, Config), "unknown order kind")
	assertFalse(Orders.validate(nil, Config), "missing order")
end)

test("Orders.validate accepts course speeds from stop to full", function()
	assertTrue(Orders.validate(Orders.course("east", 0, 0), Config), "stop")
	assertTrue(Orders.validate(Orders.course("east", 0, 12.5), Config), "between anchors")
	assertTrue(Orders.validate(Orders.course("east", 0, Config.speeds.full.speed), Config), "full")
end)

test("Orders.validate rejects a negative course speed", function()
	assertFalse(Orders.validate(Orders.course("east", 0, -1), Config))
end)

test("Orders.validate rejects a course speed above full", function()
	assertFalse(Orders.validate(Orders.course("east", 0, Config.speeds.full.speed + 0.5), Config))
end)

test("Orders.validate rejects a course speed that is not a number", function()
	assertFalse(Orders.validate(Orders.course("east", 0, "half"), Config), "speed key")
	assertFalse(Orders.validate(Orders.course("east", 0, 0 / 0), Config), "NaN")
	assertFalse(Orders.validate(Orders.course("east", 0, nil), Config), "missing")
end)

test("the speed band label names the nearest speed setting and the solved speed", function()
	assertEqual("HALF 45", Helm.speedBand(45, Config))
	assertEqual("HALF 33", Helm.speedBand(33, Config))
	assertEqual("FULL 80", Helm.speedBand(80, Config))
end)

test("a stopped sub is labelled STOP", function()
	assertEqual("STOP", Helm.speedBand(0, Config))
end)

test("a speed exactly between two settings takes the slower one", function()
	assertEqual("SLOW 33", Helm.speedBand(32.5, Config))
end)
