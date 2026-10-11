-- The turn timeline driven with the mouse: place, move and delete timed
-- orders, edit the course at a chosen second, and watch the orders execute at
-- their scheduled ticks. Mouse coordinates are world px.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Config = require("src.game.config")
local SubSystem = require("src.game.systems.sub_system")
local Trench = require("src.game.levels.trench")

local TPS = 60

local function centre(rect)
	return rect.x + rect.w / 2, rect.y + rect.h / 2
end

local function click(game, x, y, button)
	game:mousepressed(x, y, button or 1)
	game:mousereleased(x, y, button or 1)
end

local function timelineY(game)
	local r = game.state:timelineRect()
	return r.y + r.h / 2
end

-- Clicks the timeline at `tick` to select it.
local function selectTick(game, tick)
	click(game, game.state:tickX(tick), timelineY(game))
end

local function placePing(game, tick)
	selectTick(game, tick)
	click(game, centre(game.state:pingButton()))
end

local function entriesOfKind(game, kind)
	local found = {}
	for _, entry in ipairs(game.state:orders()) do
		if entry.order.kind == kind then
			found[#found + 1] = entry
		end
	end
	return found
end

test("a ping placed at 4 s fires on tick 240 from where the ghost path put the sub", function()
	local game = GameHarness.startMatch(Trench)
	click(game, centre(game.state:speedButton("full")))
	placePing(game, 4 * TPS)
	local projected = game.state.path[4 * TPS]

	click(game, centre(game.state:executeButton()))
	FrameStepper.step(game, 4 * TPS)

	local ping = game.ctx.pings[1]
	assertEqual(4 * TPS, game.ctx.tick, "the ping fired on the fourth second")
	local cx, cy = SubSystem.centre(game.ctx, game.ctx.pools.subs[1])
	assertEqual(cx, ping.x)
	assertEqual(cy, ping.y)
	-- Cell units to world px: centres at integers, px = (u - 0.5) * cellSize.
	local size = Config.grid.cellSize
	assertTrue(math.abs((ping.x - 0.5) * size - projected.x) <= size, "ping x within a cell of the projection")
	assertTrue(math.abs((ping.y - 0.5) * size - projected.y) <= size, "ping y within a cell of the projection")
	local log = game.ctx.orderLog.entries
	assertEqual(4 * TPS, log[#log].tick, "the log keeps the scheduled tick")
	assertEqual("ping", log[#log].order.kind)
end)

local function markerPoint(game, tick, kind)
	local style = require("src.app.render.timeline").KINDS[kind]
	return game.state:tickX(tick), game.state:timelineRect().y + 22 + style.row * 14
end

local function drag(game, fromX, fromY, toX, toY)
	game:mousepressed(fromX, fromY, 1)
	game:mousemoved((fromX + toX) / 2, toY)
	game:mousemoved(toX, toY)
	game:mousereleased(toX, toY, 1)
end

test("a placed ping can be dragged along the timeline to another second", function()
	local game = GameHarness.startMatch(Trench)
	placePing(game, 2 * TPS)

	local x, y = markerPoint(game, 2 * TPS, "ping")
	drag(game, x, y, game.state:tickX(4 * TPS), y)

	local pings = entriesOfKind(game, "ping")
	assertEqual(1, #pings)
	assertEqual(4 * TPS, pings[1].tick)
end)

test("right-clicking a marker deletes it, but never the standing course", function()
	local game = GameHarness.startMatch(Trench)
	placePing(game, 4 * TPS)

	local px, py = markerPoint(game, 4 * TPS, "ping")
	click(game, px, py, 2)
	local cx, cy = markerPoint(game, 1, "course")
	click(game, cx, cy, 2)

	assertEqual(0, #entriesOfKind(game, "ping"))
	assertEqual(1, #entriesOfKind(game, "course"), "the tick-1 course stays")
end)

test("a course change at 3 s: the ghost path bends there, shows a marker, and the sub turns at that tick", function()
	local game = GameHarness.startMatch(Trench)
	click(game, centre(game.state:speedButton("half")))
	local straight = game.state.path
	local straightEnd = straight[#straight].y

	selectTick(game, 3 * TPS)
	local hx, hy = game.state:handlePosition()
	drag(game, hx, hy, hx + 40, hy + 60)

	local courses = entriesOfKind(game, "course")
	assertEqual(2, #courses)
	assertEqual(3 * TPS, courses[2].tick)
	assertTrue(courses[2].order.dive > 0, "the new course dives")
	assertEqual("half", courses[2].order.speed, "it inherits the speed in effect")
	assertEqual(0, courses[1].order.dive, "the first course is unchanged")
	assertEqual(straight[3 * TPS - 1].y, game.state.path[3 * TPS - 1].y, "no bend before the order")
	assertTrue(game.state.path[#game.state.path].y > straightEnd, "the ghost path dives after it")

	local planned = game.state.path
	click(game, centre(game.state:executeButton()))
	FrameStepper.step(game, Config.turn.ticks)
	local body = require("src.sim.bodies").get(game.ctx.bodies, game.ctx.pools.subs[1].bodyId)
	assertEqual(planned[#planned].x, body.x)
	assertEqual(planned[#planned].y, body.y)
	assertEqual(3 * TPS, game.ctx.orderLog.entries[2].tick)
end)

test("a speed button at the selected second schedules a speed change there", function()
	local game = GameHarness.startMatch(Trench)
	selectTick(game, 3 * TPS)

	click(game, centre(game.state:speedButton("stop")))

	local courses = entriesOfKind(game, "course")
	assertEqual(3 * TPS, courses[2].tick)
	assertEqual("stop", courses[2].order.speed)
	assertEqual("slow", courses[1].order.speed, "the standing course keeps its speed")
end)

test("the standing course cannot be dragged off tick 1", function()
	local game = GameHarness.startMatch(Trench)

	local x, y = markerPoint(game, 1, "course")
	drag(game, x, y, game.state:tickX(4 * TPS), y)

	assertEqual(1, entriesOfKind(game, "course")[1].tick)
end)
