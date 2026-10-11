-- Execute phase screen: runs the turn's ticks at the fixed timestep and takes
-- no input (it has no mouse handlers). When the turn ends it hands back to a
-- new plan phase; when the match ends (`ctx.result`) it stays, showing the
-- match-end screen (render/match_end).
local Match = require("src.game.match")
local MatchEnd = require("src.app.render.match_end")
local OrderLog = require("src.game.order_log")
local Timeline = require("src.app.render.timeline")
local PlanOverlay = require("src.app.render.plan_overlay")

local ExecuteState = {}
ExecuteState.__index = ExecuteState

local TEXT = { 0.6, 1.0, 0.6, 1 }

function ExecuteState.new(ctx, slot)
	return setmetatable({
		phase = "execute",
		ctx = ctx,
		slot = slot,
		accumulator = 0,
		-- The player's committed orders for this turn, read once; own slot only.
		entries = OrderLog.forTurn(ctx.orderLog, ctx.turn.number, slot),
	}, ExecuteState)
end

-- The timeline cursor: the turn tick, from tick 1 (the tick is 0 before the first step).
function ExecuteState:cursorTick()
	return math.max(1, self.ctx.turn.tick)
end

-- Returns the next state once the turn is over, else nil.
function ExecuteState:update(dt)
	local ctx = self.ctx
	if ctx.result then
		return nil
	end
	self.accumulator = self.accumulator + dt
	while self.accumulator >= ctx.config.dt do
		self.accumulator = self.accumulator - ctx.config.dt
		Match.step(ctx)
		if ctx.result then
			return nil
		end
		if ctx.turn.phase == "plan" then
			local PlanState = require("src.app.states.plan_state")
			return PlanState.new(ctx, self.slot)
		end
	end
	return nil
end

function ExecuteState:draw()
	if self.ctx.result then
		MatchEnd.draw(self.ctx.result, self.slot)
		return
	end
	local turn = self.ctx.turn
	love.graphics.setColor(TEXT)
	love.graphics.print(
		string.format("TURN %d  EXECUTING  %.1f s", turn.number, (turn.length - turn.tick) * self.ctx.config.dt),
		16,
		24
	)
	Timeline.draw(self.entries, turn.length, PlanOverlay.ticksPerSecond(self), self:cursorTick())
	love.graphics.setColor(1, 1, 1, 1)
end

return ExecuteState
