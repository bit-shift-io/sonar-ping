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
	local helm = Helm.new(Orders.course("west", 0, "slow"), Config)

	tick(helm, store, body)

	assertNear(Config.sub.turnRate, math.abs(body.angle), 0.000001)
end)

test("the sub settles exactly on the ordered dive angle without overshooting", function()
	local store, body = newBody(0)
	local dive = math.rad(20)
	local helm = Helm.new(Orders.course("east", dive, "slow"), Config)

	for _ = 1, 200 do
		tick(helm, store, body)
	end

	assertNear(dive, body.angle, 0.000001)
end)

test("a westbound sub diving 20 degrees points down and to the left", function()
	local store, body = newBody(math.pi - math.rad(20))
	local helm = Helm.new(Orders.course("west", math.rad(20), "full"), Config)

	tick(helm, store, body)

	assertTrue(body.vx < 0, "heading west moves left")
	assertTrue(body.vy > 0, "positive dive moves down (y points down)")
end)

test("each speed setting maps to its configured speed and noise level", function()
	for _, name in ipairs({ "stop", "slow", "half", "full" }) do
		local store, body = newBody(0)
		local helm = Helm.new(Orders.course("east", 0, name), Config)

		tick(helm, store, body)

		assertNear(Config.speeds[name].speed, math.sqrt(body.vx ^ 2 + body.vy ^ 2), 0.000001, name)
		assertEqual(Config.speeds[name].noise, helm.noise, name)
	end
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
	local helm = Helm.new(Orders.course("east", 0, "slow"), Config)

	Helm.apply(helm, Orders.course("west", math.rad(10), "full"), Config)

	assertEqual("west", helm.heading)
	assertNear(math.rad(10), helm.dive, 0.000001)
	assertEqual("full", helm.speed)
	assertEqual(Config.speeds.full.noise, helm.noise)
end)

test("Orders.validate accepts a good course order and rejects bad ones", function()
	assertTrue(Orders.validate(Orders.course("east", 0, "half"), Config))
	assertFalse(Orders.validate(Orders.course("north", 0, "half"), Config), "unknown heading")
	assertFalse(Orders.validate(Orders.course("east", 0, "ludicrous"), Config), "unknown speed setting")
	assertFalse(Orders.validate(Orders.course("east", math.rad(80), "half"), Config), "dive beyond the limit")
	assertFalse(Orders.validate({ kind = "dance" }, Config), "unknown order kind")
	assertFalse(Orders.validate(nil, Config), "missing order")
end)
