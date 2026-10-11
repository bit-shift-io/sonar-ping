-- Plan phase overlay: the player's own sub marker, course handle, ghost path
-- with a tick mark per second and a marker per scheduled order, the course
-- target and the achieved end of turn when they differ, the PING button, the
-- torpedo previews (render/torpedo_plan), the tube buttons, the turn timeline and Execute. Reads only the
-- planning slot's own sub (own-ship knowledge), never the enemy. Draws in
-- world px; the caller applies the screen fit. No `love.*` at load time.
local Timeline = require("src.app.render.timeline")
local TorpedoPlan = require("src.app.render.torpedo_plan")
local Helm = require("src.game.components.helm")

local PlanOverlay = {}

local GHOST = { 0.6, 1.0, 0.6, 0.55 }
local MARK = { 0.6, 1.0, 0.6, 0.9 }
local HANDLE = { 1.0, 0.9, 0.3, 1 }
local BUTTON = { 0.6, 1.0, 0.6, 1 }
local BUTTON_FILL = { 0.1, 0.35, 0.15, 1 }
local MARK_HALF = 3
local TARGET_HALF = 7 -- the course target's cross
local END_RADIUS = 5 -- the achieved end of turn's ring
local SUB_AT = { 0.3, 1.0, 1.0, 1 } -- the sub's projected position at the scrubbed tick
local SUB_AT_RADIUS = 5

local function button(rect, label, selected)
	if selected then
		love.graphics.setColor(BUTTON_FILL)
		love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
	end
	love.graphics.setColor(BUTTON)
	love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
	love.graphics.print(label, rect.x + 8, rect.y + rect.h / 2 - 7)
end

PlanOverlay.drawButton = button

function PlanOverlay.ticksPerSecond(state)
	return math.floor(1 / state.ctx.config.dt + 0.5)
end

local function ghostPath(state, sx, sy)
	local path = state.path
	if #path == 0 then
		return
	end
	local points = { sx, sy }
	for _, p in ipairs(path) do
		points[#points + 1] = p.x
		points[#points + 1] = p.y
	end
	love.graphics.setColor(GHOST)
	love.graphics.line(points)

	local ticksPerSecond = PlanOverlay.ticksPerSecond(state)
	love.graphics.setColor(MARK)
	for tick = ticksPerSecond, #path, ticksPerSecond do
		local p = path[tick]
		love.graphics.rectangle("fill", p.x - MARK_HALF, p.y - MARK_HALF, MARK_HALF * 2, MARK_HALF * 2)
	end
	Timeline.drawGhostMarkers(state.schedule, path)
end

-- Marks the course target (a cross) and where the ghost path actually ends
-- (a ring) when they are more than a cell apart.
local function courseTarget(state)
	local tx, ty, ex, ey = state:courseTarget()
	if not tx or (tx - ex) ^ 2 + (ty - ey) ^ 2 <= state.ctx.config.grid.cellSize ^ 2 then
		return
	end
	love.graphics.setColor(HANDLE)
	love.graphics.line(tx - TARGET_HALF, ty - TARGET_HALF, tx + TARGET_HALF, ty + TARGET_HALF)
	love.graphics.line(tx - TARGET_HALF, ty + TARGET_HALF, tx + TARGET_HALF, ty - TARGET_HALF)
	love.graphics.setColor(MARK)
	love.graphics.circle("line", ex, ey, END_RADIUS)
end

function PlanOverlay.draw(state)
	local sx, sy = state:subPosition()
	if sx then
		ghostPath(state, sx, sy)
		courseTarget(state)
		local hx, hy = state:handlePosition()
		local ax, ay = state:anchorPosition()
		love.graphics.setColor(HANDLE)
		love.graphics.circle("line", sx, sy, 6)
		love.graphics.line(ax, ay, hx, hy)
		love.graphics.circle(state.dragging == "course" and "fill" or "line", hx, hy, 8)
		if state.dragging == "course" or state:courseTarget() then
			love.graphics.setColor(HANDLE)
			love.graphics.print(Helm.speedBand(state:course().speed, state.ctx.config), hx + 12, hy - 7)
		end
	end
	TorpedoPlan.draw(state)
	local at = state.path[state.selected]
	if at then
		love.graphics.setColor(SUB_AT)
		love.graphics.circle("fill", at.x, at.y, SUB_AT_RADIUS)
	end

	button(state:pingButton(), "PING", state:hasPingAtSelected())
	local editing = state.torpedo and state.torpedo.order
	for i = 1, state.ctx.config.tubes.count do
		local reload = state:tubeReload(i)
		local label = reload > 0 and string.format("TUBE %d  %.1fs", i, reload * state.ctx.config.dt) or "TUBE " .. i
		button(state:tubeButton(i), label, editing and editing.tube == i)
	end
	button(state:executeButton(), "EXECUTE", false)
	if state:replayAvailable() then
		button(state:replayButton(), "REPLAY", false)
	end

	Timeline.draw(state.schedule, state.ctx.turn.length, PlanOverlay.ticksPerSecond(state), state.selected, state.moving)

	love.graphics.setColor(BUTTON)
	love.graphics.print(string.format("TURN %d  PLAN", state.ctx.turn.number), 16, 96)
	love.graphics.setColor(1, 1, 1, 1)
end

return PlanOverlay
