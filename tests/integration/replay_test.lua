-- The timeline's left half replays the last execute phase: scrubbing the
-- cursor there shows the player's own perception as it stood at that tick,
-- read-only. PLAY runs the cursor on through 0 into the plan and stops at the
-- plan's end, never stepping the match or editing the plan. Mouse coordinates
-- are screen px.
local GameHarness = require("tests.support.game_harness")
local Timeline = require("src.app.render.timeline")
local FrameStepper = require("tests.support.frame_stepper")
local Perception = require("src.perception.perception")
local Match = require("src.game.match")
local Bodies = require("src.sim.bodies")
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

-- Drags the course handle to (x, y), the course target.
local function steer(game, x, y)
	local hx, hy = game.state:handlePosition()
	game:mousepressed(hx, hy, 1)
	game:mousemoved(x, y)
	game:mousereleased(x, y, 1)
end

-- Clicks the strip at signed `tick` (negative: the last execute phase).
local function scrubTo(game, tick)
	click(game, Timeline.tickX(tick, game.ctx.turn.length), Timeline.rowY("course"))
end

-- A game back in the plan phase after one full turn at full speed (a target
-- due east and out of reach).
local function afterOneTurn()
	local game = GameHarness.startMatch(Trench)
	local sx, sy = game.state:subPosition()
	steer(game, sx + 800, sy)
	game.state:commit()
	FrameStepper.step(game, game.ctx.turn.length)
	return game
end

test("on turn 1 the cursor cannot enter the left half", function()
	local game = GameHarness.startMatch(Trench)

	scrubTo(game, -150)

	assertEqual(1, game.state.selected)
	assertEqual(nil, game.state:replayPerception())
end)

test("scrubbing to -2.5 s shows the player's perception at that tick of the last execute phase", function()
	local game = afterOneTurn()
	local perception = Match.perceptionOf(game.ctx, "player")
	local tick = -2.5 * TPS

	scrubTo(game, tick)

	local view = game.state:replayPerception()
	local global = game.ctx.tick + tick
	assertTrue(game.state:replaying())
	assertEqual(global, view.tick)
	local expected = Perception.at(perception, global)
	assertTrue(#expected > 0, "the player heard something by mid-turn")
	assertEqual(#expected, #view.contacts)
end)

test("the left end of the strip is the last execute phase's first tick", function()
	local game = afterOneTurn()

	click(game, Timeline.X + 1, Timeline.rowY("course"))

	assertEqual(1 - game.ctx.turn.length, game.state.selected)
	assertEqual(game.ctx.tick - game.ctx.turn.length + 1, game.state:replayPerception().tick)
end)

test("the replay view puts own ship where the sub was at the scrubbed tick", function()
	local game = GameHarness.startMatch(Trench)
	local perception = Match.perceptionOf(game.ctx, "player")
	local startX, startY = SubSystem.centre(game.ctx, game.state.sub)
	local sx, sy = game.state:subPosition()
	steer(game, sx + 800, sy)
	game.state:commit()
	FrameStepper.step(game, game.ctx.turn.length)

	click(game, Timeline.X + 1, Timeline.rowY("course"))

	local view = game.state:replayPerception()
	assertTrue(math.abs(view.x - perception.x) > 1, "the ring is not at the current position")
	assertTrue(math.abs(view.x - startX) < 0.5, "the ring is near where the sub started")
	assertTrue(math.abs(view.y - startY) < 0.5)
end)

test("scrubbing changes neither the sim nor the perception", function()
	local game = afterOneTurn()
	local perception = Match.perceptionOf(game.ctx, "player")
	local player = Bodies.get(game.ctx.bodies, game.ctx.pools.subs[1].bodyId)
	local before = { game.ctx.tick, #perception.contacts, #perception.archive, perception.tick, player.x, player.y, game.ctx.rng.state }

	for _, tick in ipairs({ 1 - game.ctx.turn.length, -100, -1, 0, 120, game.ctx.turn.length }) do
		scrubTo(game, tick)
	end

	local after = { game.ctx.tick, #perception.contacts, #perception.archive, perception.tick, player.x, player.y, game.ctx.rng.state }
	for i = 1, #before do
		assertEqual(before[i], after[i], "field " .. i)
	end
end)

test("planning input is inert while the cursor is on the left half", function()
	local game = afterOneTurn()
	local state = game.state
	local speed = state:course().speed
	scrubTo(game, -120)

	click(game, centre(state:pingButton()))
	click(game, centre(state:tubeButton(1)))

	assertEqual(1, #state:orders())
	scrubTo(game, 120)
	assertEqual(speed, state:course().speed)
	click(game, centre(state:pingButton()))
	assertEqual(2, #state:orders(), "the same press plans a ping on the right half")
end)

local function placePing(game, tick)
	scrubTo(game, tick)
	click(game, centre(game.state:pingButton()))
end

local function markerOf(entries, kind)
	for _, entry in ipairs(entries) do
		if entry.order.kind == kind then
			return entry
		end
	end
	return nil
end

-- Turn 1 with a ping at 4 s, run to completion; the game is then in turn 2's plan phase.
local function turnOneWithPing()
	local game = GameHarness.startMatch(Trench)
	local sx, sy = game.state:subPosition()
	steer(game, sx + 800, sy)
	placePing(game, 4 * TPS)
	game.state:commit()
	FrameStepper.step(game, game.ctx.turn.length)
	return game
end

test("the left half holds last turn's orders at their ticks there", function()
	local game = turnOneWithPing()
	local length = game.ctx.turn.length

	local ping = markerOf(game.state.past, "ping")
	local course = markerOf(game.state.past, "course")

	assertEqual(4 * TPS - length, ping.tick)
	assertEqual(1 - length, course.tick)
end)

test("a left-half marker cannot be deleted, selected or moved", function()
	local game = turnOneWithPing()
	local state = game.state
	placePing(game, 60)
	local before = #state:orders()
	local tick = Timeline.pastTick(4 * TPS, game.ctx.turn.length)
	local x, y = Timeline.tickX(tick, game.ctx.turn.length), Timeline.rowY("ping")

	click(game, x, y, 2)
	game:mousepressed(x, y, 1)
	game:mousemoved(Timeline.tickX(200, game.ctx.turn.length), y)
	game:mousereleased(Timeline.tickX(200, game.ctx.turn.length), y, 1)

	assertEqual(before, #state:orders())
	assertEqual(4 * TPS, markerOf(game.state.past, "ping").tick + game.ctx.turn.length)
	assertEqual(60, markerOf(state.schedule, "ping").tick, "the own ping did not move")
	assertEqual(nil, state.moving)
end)

local function playPause(game)
	click(game, centre(game.state:playButton()))
end

test("the cursor stays put while paused", function()
	local game = afterOneTurn()
	scrubTo(game, -200)

	FrameStepper.step(game, 30)

	assertEqual(-200, game.state.selected)
	assertEqual("PLAY", game.state:playLabel())
end)

test("playing advances the cursor one tick per frame without stepping the match", function()
	local game = afterOneTurn()
	scrubTo(game, -200)
	local tick = game.ctx.tick

	playPause(game)
	FrameStepper.step(game, 30)

	assertEqual("PAUSE", game.state:playLabel())
	assertEqual(-170, game.state.selected)
	assertEqual(tick, game.ctx.tick, "playback does not step the match")
	assertEqual("plan", game.ctx.turn.phase)
end)

test("PLAY from the left end crosses 0 and stops at +5 s, editing nothing", function()
	local game = afterOneTurn()
	local state = game.state
	placePing(game, 90)
	local orders = #state:orders()
	click(game, Timeline.X + 1, Timeline.rowY("course"))

	playPause(game)
	FrameStepper.step(game, 3 * game.ctx.turn.length)

	assertEqual(game.ctx.turn.length, state.selected)
	assertEqual("PLAY", state:playLabel())
	assertEqual(orders, #state:orders())
	assertEqual(90, markerOf(state.schedule, "ping").tick)
	assertEqual("plan", game.ctx.turn.phase)
end)

test("pressing PAUSE stops the cursor where it is", function()
	local game = afterOneTurn()
	scrubTo(game, -200)
	playPause(game)
	FrameStepper.step(game, 20)

	playPause(game)
	local at = game.state.selected
	FrameStepper.step(game, 20)

	assertEqual(at, game.state.selected)
	assertEqual("PLAY", game.state:playLabel())
end)

test("PLAY at +5 s restarts from the left end", function()
	local game = afterOneTurn()
	scrubTo(game, game.ctx.turn.length)

	playPause(game)
	FrameStepper.step(game, 10)

	assertEqual(1 - game.ctx.turn.length + 10, game.state.selected)
end)

test("on turn 1 PLAY at +5 s restarts from the plan's first tick", function()
	local game = GameHarness.startMatch(Trench)
	scrubTo(game, game.ctx.turn.length)

	playPause(game)
	FrameStepper.step(game, 10)

	assertEqual(11, game.state.selected)
end)

test("pressing the strip pauses playback and scrubs", function()
	local game = afterOneTurn()
	scrubTo(game, -200)
	playPause(game)
	FrameStepper.step(game, 10)

	scrubTo(game, -100)
	FrameStepper.step(game, 10)

	assertEqual("PLAY", game.state:playLabel())
	assertEqual(-100, game.state.selected)
end)

test("there is no REPLAY button; PLAY overlaps no other button", function()
	local game = GameHarness.startMatch(Trench)
	local state = game.state
	assertEqual(nil, state.replayButton)
	local p = state:playButton()
	local others = { state:executeButton(), state:pingButton() }
	for i = 1, game.ctx.config.tubes.count do
		others[#others + 1] = state:tubeButton(i)
	end
	for _, other in ipairs(others) do
		local apart = p.x + p.w <= other.x or other.x + other.w <= p.x or p.y + p.h <= other.y or other.y + other.h <= p.y
		assertTrue(apart, "no overlap")
	end
end)
