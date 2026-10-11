-- The plan phase can scrub back through the last execute phase, showing the
-- player's own perception as it stood at each tick. Scrubbing is read-only and
-- modal: planning input is inert until it closes. Mouse coordinates are world px.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Perception = require("src.perception.perception")
local Match = require("src.game.match")
local Bodies = require("src.sim.bodies")
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
	click(game, game.state:scrubX(tick), game.state:timelineRect().y + 30)
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
