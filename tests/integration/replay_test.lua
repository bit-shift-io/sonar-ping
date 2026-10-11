-- The plan phase can scrub back through the last execute phase, showing the
-- player's own perception as it stood at each tick. Scrubbing is read-only and
-- modal: planning input is inert until it closes. Mouse coordinates are world px.
local GameHarness = require("tests.support.game_harness")
local Timeline = require("src.app.render.timeline")
local FrameStepper = require("tests.support.frame_stepper")
local Perception = require("src.perception.perception")
local Match = require("src.game.match")
local Bodies = require("src.sim.bodies")
local SubSystem = require("src.game.systems.sub_system")
local Trench = require("src.game.levels.trench")

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

local function openReplay(game)
	click(game, centre(game.state:replayButton()))
end

local function scrubTo(game, tick)
	click(game, game.state:scrubX(tick), Timeline.rowY("course"))
end

test("on turn 1 there is no last turn to replay", function()
	local game = GameHarness.startMatch(Trench)

	openReplay(game)

	assertFalse(game.state:replaying())
	assertEqual(nil, game.state:replayPerception())
end)

test("after a turn the replay button opens the scrubber at the start of that turn", function()
	local game = afterOneTurn()

	openReplay(game)

	assertTrue(game.state:replaying())
	assertEqual(game.ctx.tick - game.ctx.turn.length + 1, game.state.replay.tick)
end)

test("the scrubbed view holds the contacts the player's perception held at that tick", function()
	local game = afterOneTurn()
	local perception = Match.perceptionOf(game.ctx, "player")
	openReplay(game)

	scrubTo(game, game.ctx.tick - game.ctx.turn.length / 2)

	local view = game.state:replayPerception()
	local tick = game.state.replay.tick
	assertEqual(tick, view.tick)
	local expected = Perception.at(perception, tick)
	assertEqual(#expected, #view.contacts)
	assertTrue(#expected > 0, "the player heard something by mid-turn")
end)

test("scrubbing changes neither the sim nor the perception", function()
	local game = afterOneTurn()
	local perception = Match.perceptionOf(game.ctx, "player")
	local player = Bodies.get(game.ctx.bodies, game.ctx.pools.subs[1].bodyId)
	local before = { game.ctx.tick, #perception.contacts, #perception.archive, perception.tick, player.x, player.y, game.ctx.rng.state }

	openReplay(game)
	local length = game.ctx.turn.length
	for _, offset in ipairs({ 0, 100, length / 2, length - 1 }) do
		scrubTo(game, game.ctx.tick - game.ctx.turn.length + 1 + offset)
	end
	openReplay(game)

	local after = { game.ctx.tick, #perception.contacts, #perception.archive, perception.tick, player.x, player.y, game.ctx.rng.state }
	for i = 1, #before do
		assertEqual(before[i], after[i], "field " .. i)
	end
end)

test("planning input is inert while the scrubber is open, and works again once it closes", function()
	local game = afterOneTurn()
	local state = game.state
	openReplay(game)

	local speed = state:course().speed
	steer(game, state:subPosition())
	click(game, centre(state:pingButton()))
	click(game, centre(state:executeButton()))

	assertEqual("plan", game.ctx.turn.phase)
	assertEqual(1, #state:orders())
	assertEqual(speed, state:course().speed, "the course handle did not move")
	openReplay(game)
	assertFalse(state:replaying())
	assertEqual(nil, state:replayPerception())
	click(game, centre(state:pingButton()))
	assertEqual(2, #state:orders())
end)

local TPS = 60

local function placePing(game, tick)
	click(game, game.state:tickX(tick), game.state:timelineRect().y + 24)
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

test("the replay strip holds last turn's ping at its tick", function()
	local game = turnOneWithPing()

	openReplay(game)

	local ping = markerOf(game.state:replayEntries(), "ping")
	assertTrue(ping ~= nil, "the replay holds the ping")
	assertEqual(4 * TPS, ping.tick)
end)

test("the replay strip holds last turn's course at tick 1", function()
	local game = turnOneWithPing()

	openReplay(game)

	local course = markerOf(game.state:replayEntries(), "course")
	assertTrue(course ~= nil, "the replay holds the course")
	assertEqual(1, course.tick)
end)

test("the replay strip holds last turn's torpedo launch at its tick", function()
	local game = GameHarness.startMatch(Trench)
	local sx, sy = game.state:subPosition()
	steer(game, sx + 800, sy)
	click(game, game.state:tickX(150), game.state:timelineRect().y + 24)
	click(game, centre(game.state:tubeButton(1)))
	game.state:aimTorpedo(sx - 300, sy)
	game.state:commit()
	FrameStepper.step(game, game.ctx.turn.length)

	openReplay(game)

	local launch = markerOf(game.state:replayEntries(), "torpedo")
	assertTrue(launch ~= nil, "the replay holds the launch")
	assertEqual(150, launch.tick)
end)

test("right-clicking a replay marker deletes nothing, from either turn", function()
	local game = turnOneWithPing()
	placePing(game, 60)
	local before = #game.state:orders()
	local length = game.ctx.turn.length
	local first = game.state:replayRange()
	openReplay(game)

	click(game, Timeline.tickX(4 * TPS, length), Timeline.rowY("ping"), 2)
	click(game, Timeline.tickX(60, length), Timeline.rowY("ping"), 2)

	assertEqual(before, #game.state:orders())
	assertEqual(first, game.state.replay.tick, "a right-click does not scrub")
end)

test("clicking a replay marker scrubs to it without selecting or moving it", function()
	local game = turnOneWithPing()
	placePing(game, 60)
	local state = game.state
	local length = game.ctx.turn.length
	local first = state:replayRange()
	local selected = state.selected
	local before = #state:orders()
	openReplay(game)

	click(game, Timeline.tickX(4 * TPS, length), Timeline.rowY("ping"))

	assertEqual(first + 4 * TPS - 1, state.replay.tick)
	assertEqual(selected, state.selected)
	assertEqual(before, #state:orders())
	assertEqual(60, markerOf(state.schedule, "ping").tick, "the own ping did not move")
end)

test("the replay view puts own ship where the sub was at the scrubbed tick", function()
	local game = GameHarness.startMatch(Trench)
	local perception = Match.perceptionOf(game.ctx, "player")
	local startX, startY = SubSystem.centre(game.ctx, game.state.sub)
	local sx, sy = game.state:subPosition()
	steer(game, sx + 800, sy)
	game.state:commit()
	FrameStepper.step(game, game.ctx.turn.length)
	openReplay(game)

	local view = game.state:replayPerception()

	assertTrue(math.abs(view.x - perception.x) > 1, "the ring is not at the current position")
	assertTrue(math.abs(view.x - startX) < 0.5, "the ring is near where the sub started")
	assertTrue(math.abs(view.y - startY) < 0.5)
	local x, y = Perception.positionAt(perception, game.state.replay.tick)
	assertEqual(x, view.x)
	assertEqual(y, view.y)
end)

local function playPause(game)
	click(game, centre(game.state:playButton()))
end

test("the replay opens paused, and time passing does not move the scrubbed tick", function()
	local game = afterOneTurn()
	openReplay(game)
	local first = game.state:replayRange()

	FrameStepper.step(game, 30)

	assertFalse(game.state:replayPlaying())
	assertEqual(first, game.state.replay.tick)
	assertEqual("PLAY", game.state:playLabel())
end)

test("playing advances the scrubbed tick one per frame without stepping the match", function()
	local game = afterOneTurn()
	openReplay(game)
	local first = game.state:replayRange()
	local tick = game.ctx.tick

	playPause(game)
	FrameStepper.step(game, 30)

	assertTrue(game.state:replayPlaying())
	assertEqual("PAUSE", game.state:playLabel())
	assertEqual(first + 30, game.state.replay.tick)
	assertEqual(tick, game.ctx.tick, "playback does not step the match")
	assertEqual("plan", game.ctx.turn.phase)
end)

test("pressing PAUSE stops the playback where it is", function()
	local game = afterOneTurn()
	openReplay(game)
	playPause(game)
	FrameStepper.step(game, 20)

	playPause(game)
	local at = game.state.replay.tick
	FrameStepper.step(game, 20)

	assertFalse(game.state:replayPlaying())
	assertEqual(at, game.state.replay.tick)
end)

test("playback stops on the last tick", function()
	local game = afterOneTurn()
	openReplay(game)
	local _, last = game.state:replayRange()

	playPause(game)
	FrameStepper.step(game, game.ctx.turn.length + 60)

	assertEqual(last, game.state.replay.tick)
	assertFalse(game.state:replayPlaying())
	assertEqual("PLAY", game.state:playLabel())
end)

test("PLAY on the last tick restarts from the first", function()
	local game = afterOneTurn()
	openReplay(game)
	local first, last = game.state:replayRange()
	scrubTo(game, last)

	playPause(game)
	FrameStepper.step(game, 10)

	assertTrue(game.state:replayPlaying())
	assertEqual(first + 10, game.state.replay.tick)
end)

test("pressing the strip pauses playback and scrubs", function()
	local game = afterOneTurn()
	openReplay(game)
	local first = game.state:replayRange()
	playPause(game)
	FrameStepper.step(game, 10)

	scrubTo(game, first + 100)
	FrameStepper.step(game, 10)

	assertFalse(game.state:replayPlaying())
	assertEqual(first + 100, game.state.replay.tick)
end)

test("the play button overlaps neither EXECUTE nor REPLAY", function()
	local game = GameHarness.startMatch(Trench)
	local p = game.state:playButton()
	for _, other in ipairs({ game.state:executeButton(), game.state:replayButton(), game.state:pingButton() }) do
		assertTrue(p.x + p.w <= other.x or other.x + other.w <= p.x, "no horizontal overlap")
	end
end)
