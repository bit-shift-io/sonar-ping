-- Two full turns driven the way a player does it: drag the course handle to
-- where the sub should end the turn, click Execute, watch the turn run. Mouse coordinates are
-- world px (the harness has no window, so no screen fit to undo).
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")
local OrderLog = require("src.game.order_log")
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

local function distance(p, x, y)
	return math.sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2)
end

-- Plans one turn with the mouse and returns the ghost path shown at commit.
local function planTurn(game, targetX, targetY)
	local hx, hy = game.state:handlePosition()
	drag(game, hx, hy, targetX, targetY)
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

	-- Turn 1: a target east, down and beyond reach: full speed, diving.
	local body = playerBody(game)
	local pingButton = game.state:pingButton()
	local ghost1 = planTurn(game, body.x + 600, body.y + 100)
	assertEqual("execute", game.ctx.turn.phase)
	FrameStepper.step(game, ticks / 2)
	click(game, centre(pingButton)) -- execute accepts no input
	FrameStepper.step(game, ticks / 2)

	assertEqual("plan", game.state.phase)
	assertEqual(2, game.ctx.turn.number)
	assertEqual(ticks, game.ctx.tick)
	assertEqual(ghost1[ticks].x, body.x)
	assertEqual(ghost1[ticks].y, body.y)

	-- Turn 2: a reachable target back west and up.
	local targetX, targetY = body.x - 100, body.y - 110
	local ghost2 = planTurn(game, targetX, targetY)
	assertTrue(distance(ghost2[ticks], targetX, targetY) <= Config.grid.cellSize, "the ghost path ends on the target")
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
	assertTrue(log[1].order.dive > 0, "a target below the sub orders a dive")
	assertEqual(Config.speeds.full.speed, log[1].order.speed, "a target out of reach orders full speed")
	assertEqual(2, log[2].turn)
	assertEqual("west", log[2].order.heading)
	local speed = log[2].order.speed
	assertTrue(speed > 0 and speed < Config.speeds.full.speed, "a target within reach orders less than full speed")
end)

test("dragging the course handle onto the sub plans a stop", function()
	local game = GameHarness.startMatch(Trench)
	local body = playerBody(game)
	local hx, hy = game.state:handlePosition()

	drag(game, hx, hy, body.x + 2, body.y - 1)

	assertEqual(0, game.state:course().speed)
	local last = game.state.path[Config.turn.ticks]
	assertEqual(body.x, last.x, "the ghost path stays on the sub")
	assertEqual(body.y, last.y)
end)

test("the course handle stays on the course target after the drag", function()
	local game = GameHarness.startMatch(Trench)
	local body = playerBody(game)
	local hx, hy = game.state:handlePosition()

	drag(game, hx, hy, body.x + 700, body.y)

	local nx, ny = game.state:handlePosition()
	assertEqual(body.x + 700, nx)
	assertEqual(body.y, ny)
	local tx, ty, ex = game.state:courseTarget()
	assertEqual(body.x + 700, tx)
	assertTrue(ex < tx, "the end of turn falls short of an unreachable target")
end)

test("a target below the steepest dive keeps the planned dive within the configured limit", function()
	local game = GameHarness.startMatch(Trench)
	local body = playerBody(game)
	local hx, hy = game.state:handlePosition()

	drag(game, hx, hy, body.x + 10, body.y + 200)

	assertTrue(math.abs(game.state:course().dive) <= Config.sub.maxDive)
	assertTrue(game.state.path[Config.turn.ticks].y > body.y, "the turn ends deeper")
end)

test("there are no sub speed buttons", function()
	local game = GameHarness.startMatch(Trench)

	assertEqual(nil, game.state.speedButton)
	assertEqual(nil, game.state.SPEEDS)
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

test("the execute screen's timeline holds the player's committed orders and its cursor follows the turn tick", function()
	local game = GameHarness.startMatch(Trench)
	local state = game.state
	state.selected = 120
	state:togglePing()
	state.selected = 200
	state:toggleTorpedo(1)
	click(game, centre(state:executeButton()))
	FrameStepper.step(game, Config.turn.ticks / 2)

	local execute = game.state
	assertEqual("execute", execute.phase)
	local planned = OrderLog.forTurn(game.ctx.orderLog, game.ctx.turn.number, "player")
	assertEqual(#planned, #execute.entries)
	for i, entry in ipairs(planned) do
		assertEqual(entry.tick, execute.entries[i].tick)
		assertEqual(entry.order, execute.entries[i].order)
	end
	local kinds = {}
	for _, entry in ipairs(execute.entries) do
		kinds[entry.order.kind] = true
	end
	assertTrue(kinds.ping and kinds.torpedo, "the planned ping and launch are on the strip")
	for _, logged in ipairs(game.ctx.orderLog.entries) do
		if logged.slot ~= "player" then
			for _, entry in ipairs(execute.entries) do
				assertTrue(entry.order ~= logged.order, "no AI order on the strip")
			end
		end
	end
	assertEqual(game.ctx.turn.tick, execute:cursorTick())
	assertTrue(execute:cursorTick() > 1, "the cursor has moved off the start")
end)
