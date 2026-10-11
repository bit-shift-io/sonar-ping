-- Two full turns driven the way a player does it: drag the heading handle,
-- click a speed, click Execute, watch the turn run. Mouse coordinates are
-- world px (the harness has no window, so no screen fit to undo).
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")
local Trench = require("src.game.levels.trench")

local function centre(rect)
	return rect.x + rect.w / 2, rect.y + rect.h / 2
end

local function click(game, x, y)
	game:mousepressed(x, y, 1)
	game:mousereleased(x, y, 1)
end

local function drag(game, fromX, fromY, toX, toY)
	game:mousepressed(fromX, fromY, 1)
	game:mousemoved((fromX + toX) / 2, (fromY + toY) / 2)
	game:mousemoved(toX, toY)
	game:mousereleased(toX, toY, 1)
end

local function playerBody(game)
	return Bodies.get(game.ctx.bodies, game.ctx.pools.subs[1].bodyId)
end

-- Plans one turn with the mouse and returns the ghost path shown at commit.
local function planTurn(game, aimX, aimY, speed)
	local hx, hy = game.state:handlePosition()
	drag(game, hx, hy, aimX, aimY)
	click(game, centre(game.state:speedButton(speed)))
	local ghost = game.state.path
	click(game, centre(game.state:executeButton()))
	return ghost
end

test("two turns planned with the mouse: the sub ends each turn where its ghost path ended", function()
	local game = GameHarness.startMatch(Trench)
	local ticks = Config.turn.ticks

	assertEqual("plan", game.state.phase)
	FrameStepper.step(game, 120)
	assertEqual(0, game.ctx.tick, "no ticks advance while planning")

	-- Turn 1: east, diving, full speed.
	local body = playerBody(game)
	local stopButton = game.state:speedButton("stop")
	local ghost1 = planTurn(game, body.x + 100, body.y + 40, "full")
	assertEqual("execute", game.ctx.turn.phase)
	FrameStepper.step(game, ticks / 2)
	click(game, centre(stopButton)) -- execute accepts no input
	FrameStepper.step(game, ticks / 2)

	assertEqual("plan", game.state.phase)
	assertEqual(2, game.ctx.turn.number)
	assertEqual(ticks, game.ctx.tick)
	assertEqual(ghost1[ticks].x, body.x)
	assertEqual(ghost1[ticks].y, body.y)

	-- Turn 2: back west and climbing, slow.
	local ghost2 = planTurn(game, body.x - 100, body.y - 30, "slow")
	FrameStepper.step(game, ticks)

	assertEqual(3, game.ctx.turn.number)
	assertEqual(2 * ticks, game.ctx.tick)
	assertEqual(ghost2[ticks].x, body.x)
	assertEqual(ghost2[ticks].y, body.y)

	local log = {}
	for _, entry in ipairs(game.ctx.orderLog.entries) do
		if entry.slot == "player" then
			log[#log + 1] = entry
		end
	end
	assertEqual(2, #log, "one course order per turn from the player")
	assertEqual(1, log[1].turn)
	assertEqual("player", log[1].slot)
	assertEqual("east", log[1].order.heading)
	assertTrue(log[1].order.dive > 0, "dragging below the sub orders a dive")
	assertEqual("full", log[1].order.speed)
	assertEqual(2, log[2].turn)
	assertEqual("west", log[2].order.heading)
	assertTrue(log[2].order.dive < 0, "dragging above the sub orders a climb")
	assertEqual("slow", log[2].order.speed)
end)

test("dragging below the steepest dive clamps the planned dive to the configured limit", function()
	local game = GameHarness.startMatch(Trench)
	local body = playerBody(game)
	local hx, hy = game.state:handlePosition()

	drag(game, hx, hy, body.x + 10, body.y + 200)

	assertEqual("east", game.state:course().heading)
	assertNear(Config.sub.maxDive, game.state:course().dive)
end)

test("a press away from the handle and the buttons changes nothing", function()
	local game = GameHarness.startMatch(Trench)
	local before = game.state:course().dive

	drag(game, 640, 360, 640, 500)

	assertEqual(before, game.state:course().dive)
	assertEqual("plan", game.ctx.turn.phase)
end)

test("clicking PING at the first tick plans a ping there; clicking again cancels it", function()
	local game = GameHarness.startMatch(Trench)

	click(game, centre(game.state:pingButton()))
	click(game, centre(game.state:pingButton()))
	click(game, centre(game.state:pingButton()))
	assertTrue(game.state:hasPingAtSelected())
	click(game, centre(game.state:executeButton()))
	FrameStepper.step(game, 1)

	local log = game.ctx.orderLog.entries
	assertEqual(2, #log, "the course order and the ping")
	assertEqual("ping", log[2].order.kind)
	assertEqual(1, log[2].tick)
	assertEqual(1, #game.ctx.pings, "the ping fired on tick 1")
end)

test("the plan starts fresh each turn: no ping carries over", function()
	local game = GameHarness.startMatch(Trench)

	click(game, centre(game.state:pingButton()))
	click(game, centre(game.state:executeButton()))
	FrameStepper.step(game, Config.turn.ticks)

	assertEqual("plan", game.state.phase)
	assertFalse(game.state:hasPingAtSelected())
end)
