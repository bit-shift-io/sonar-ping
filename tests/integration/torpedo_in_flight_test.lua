-- A torpedo launched late in one turn is still running when the next plan
-- phase starts: the plan scrub shows it where the sim will have it. Enemy
-- torpedoes never show. Mouse coordinates are world px.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")
local Turn = require("src.game.turn")
local Orders = require("src.game.orders")

-- Flat seabed at y = 600; both subs stopped, the enemy high up and far east,
-- out of the way of the player's run.
local LEVEL = {
	seabed = { { x = 0, y = 600 }, { x = 1280, y = 600 } },
	subs = {
		player = { x = 200, y = 300, order = { kind = "course", heading = "west", dive = 0, speed = Config.speeds.stop.speed } },
		enemy = { x = 1200, y = 100, order = { kind = "course", heading = "west", dive = 0, speed = Config.speeds.stop.speed } },
	},
}

local LAUNCH = Config.turn.ticks - 10

local function click(game, x, y)
	game:mousepressed(x, y, 1)
	game:mousereleased(x, y, 1)
end

local function centre(rect)
	return rect.x + rect.w / 2, rect.y + rect.h / 2
end

local function torpedoOf(ctx, owner)
	for _, torpedo in ipairs(ctx.pools.torpedoes) do
		if torpedo.owner == owner and not torpedo.dead then
			return torpedo
		end
	end
	return nil
end

-- Turn 1: the player launches slow (an aim point past fast range), east, 10
-- ticks before the turn ends; the enemy launches west along its own depth,
-- clear of the player, on the same tick.
local function launchLateInTurnOne()
	local game = GameHarness.startMatch(LEVEL)
	local state = game.state
	local r = state:timelineRect()
	click(game, state:tickX(LAUNCH), r.y + r.h / 2)
	click(game, centre(state:tubeButton(1)))
	state:aimTorpedo(1000, 300)
	assertEqual("slow", state.torpedo.order.speed)
	Turn.submit(game.ctx, "enemy", { { tick = LAUNCH, order = Orders.torpedo(1, math.pi, "slow", 160) } })
	click(game, centre(state:executeButton()))
	FrameStepper.step(game, Config.turn.ticks)
	assertEqual("plan", game.ctx.turn.phase, "turn 2 plans")
	assertTrue(torpedoOf(game.ctx, "player") ~= nil, "the player's torpedo is still running")
	assertTrue(torpedoOf(game.ctx, "enemy") ~= nil, "the enemy's torpedo is still running")
	return game
end

test("a torpedo from last turn shows on the scrub where the sim later has it", function()
	local game = launchLateInTurnOne()
	local torpedo = torpedoOf(game.ctx, "player")

	local markers = game.state:torpedoesAt(60)

	assertEqual(1, #markers, "only the player's own torpedo")
	click(game, centre(game.state:executeButton()))
	FrameStepper.step(game, 60)
	local body = Bodies.get(game.ctx.bodies, torpedo.bodyId)
	assertEqual(body.x, markers[1].x)
	assertEqual(body.y, markers[1].y)
end)

test("editing the plan leaves last turn's torpedo projection as it was", function()
	local game = launchLateInTurnOne()
	local state = game.state
	local before = state:torpedoesAt(60)[1]

	click(game, centre(state:pingButton()))
	click(game, centre(state:tubeButton(2)))
	state:aimTorpedo(200, 100)

	local after = state:torpedoesAt(60)
	local flights = 0
	for _, t in ipairs(after) do
		if t.flight then
			flights = flights + 1
			assertEqual(before.flight.preview, t.flight.preview, "projected once, at plan start")
		end
	end
	assertEqual(1, flights)
end)
