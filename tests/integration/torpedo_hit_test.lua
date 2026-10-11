-- A torpedo planned with the mouse: pick a tube, drag the launch angle, pick
-- a speed, drag the fuse marker along the preview line, execute. Against the
-- idle (orderless, stopped) enemy it sinks it and the match ends. Mouse
-- coordinates are world px.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Config = require("src.game.config")
local Turn = require("src.game.turn")
local Orders = require("src.game.orders")
local MatchEnd = require("src.app.render.match_end")

-- Flat seabed at y = 600. The player is stopped facing west, away from the
-- enemy, so the default launch angle (along the hull) points the wrong way.
local LEVEL = {
	seabed = { { x = 0, y = 600 }, { x = 1280, y = 600 } },
	subs = {
		player = { x = 200, y = 300, order = { kind = "course", heading = "west", dive = 0, speed = "stop" } },
		enemy = { x = 900, y = 300, order = { kind = "course", heading = "west", dive = 0, speed = "stop" } },
	},
}

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

local function enemyAlive(game)
	for _, sub in ipairs(game.ctx.pools.subs) do
		if sub.slot == "enemy" then
			return true
		end
	end
	return false
end

test("a torpedo planned with the mouse at the idle enemy sinks it and ends the match in a win", function()
	local game = GameHarness.startMatch(LEVEL)
	local state = game.state

	click(game, centre(state:tubeButton(1)))
	local hx, hy = state:torpedoHandlePosition()
	assertTrue(hx < 200, "the launch angle starts along the hull, pointing west")
	drag(game, hx, hy, 600, 300)
	click(game, centre(state:torpedoSpeedButton("fast")))
	local fx, fy = state:fuseMarkerPosition()
	drag(game, fx, fy, 870, 302)
	local preview = state:torpedoPreview()
	assertNear(870, preview.points[preview.endTick].x, 2, "the fuse marker follows the drag along the line")
	click(game, centre(state:executeButton()))

	local log = game.ctx.orderLog.entries
	assertEqual("torpedo", log[2].order.kind)
	assertEqual(1, log[2].order.tube)
	assertEqual(1, log[2].tick)
	assertNear(0, log[2].order.angle, 1e-9)
	assertEqual("fast", log[2].order.speed)
	assertEqual(preview.endTick, log[2].order.fuse)

	FrameStepper.step(game, Config.turn.ticks)

	assertFalse(enemyAlive(game), "the enemy sank")
	assertEqual("player", game.ctx.result.winner)
	assertEqual("over", game.ctx.turn.phase)
	assertEqual("execute", game.state.phase, "no new plan phase after the match ends")
	assertEqual("VICTORY", MatchEnd.headline(game.ctx.result, "player"))
end)

test("an enemy launch at the player sinks it and the match ends in a loss", function()
	local game = GameHarness.startMatch(LEVEL)
	-- The enemy's orders arrive through the same Turn.submit an AI will use.
	Turn.submit(game.ctx, "enemy", { { tick = 1, order = Orders.torpedo(2, math.pi, "fast", 600) } })
	click(game, centre(game.state:executeButton()))

	FrameStepper.step(game, Config.turn.ticks)

	assertEqual("enemy", game.ctx.result.winner)
	assertEqual("DEFEAT", MatchEnd.headline(game.ctx.result, "player"))
end)

test("a torpedo marker selected on the timeline can be re-aimed; clicking its tube again removes it", function()
	local game = GameHarness.startMatch(LEVEL)
	local state = game.state
	local y = state:timelineRect().y + state:timelineRect().h / 2

	click(game, state:tickX(120), y)
	click(game, centre(state:tubeButton(2)))
	click(game, state:tickX(300), y)
	click(game, centre(state:tubeButton(1)))
	assertEqual(1, state:torpedoPreview() and state.torpedo.order.tube)

	-- Back to the tube-2 launch through its timeline marker.
	local marker
	for _, entry in ipairs(state.schedule) do
		if entry.order.kind == "torpedo" and entry.order.tube == 2 then
			marker = entry
		end
	end
	click(game, state:tickX(120), state:timelineRect().y + 22 + 2 * 14)
	assertEqual(marker, state.torpedo)
	local hx, hy = state:torpedoHandlePosition()
	drag(game, hx, hy, hx, hy - 200)
	assertTrue(marker.order.angle < -math.pi / 4, "aimed up")

	click(game, centre(state:tubeButton(2)))
	assertEqual(nil, state.torpedo)
	local torpedoes = 0
	for _, entry in ipairs(state:orders()) do
		if entry.order.kind == "torpedo" then
			torpedoes = torpedoes + 1
		end
	end
	assertEqual(1, torpedoes, "only the tube-1 launch is left")
end)
