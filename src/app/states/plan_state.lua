-- Plan phase screen for one human slot: the match is paused (no Match.step).
-- The turn's orders live on a timeline (render/timeline): a `schedule` of
-- `{ tick, order }` entries, always starting with the sub's standing course at
-- tick 1. The player selects a tick by clicking the strip; the heading handle
-- and speed buttons then edit the course order at that tick (created from the
-- course in effect there if none exists), and PING toggles a ping at it.
-- A TUBE button toggles a torpedo launch from that tube at the selected tick
-- and makes it the launch being edited (`torpedo`; clicking a torpedo marker
-- on the strip selects it too): drag its angle handle to aim, pick its speed,
-- and drag its fuse marker along the preview line to set the fuse.
-- Markers on the strip can be dragged to another tick, and right-clicked to
-- delete (the tick-1 course stays). A ghost path (src/game/predict) shows the
-- projected course, and each launch's preview its straight run and fuse
-- point. Execute commits the schedule. Mouse coordinates are world px; the
-- REPLAY (once there is a last turn) opens a modal scrubber over the strip:
-- click or drag it to see the player's perception at each tick of the last
-- execute phase (`replay.tick`, a global tick); planning input is inert until
-- REPLAY closes it again. Mouse coordinates are world px; the
-- caller undoes the screen fit. Logic is pure; drawing is in
-- render/plan_overlay, render/torpedo_plan and render/timeline.
local Bodies = require("src.sim.bodies")
local Helm = require("src.game.components.helm")
local Orders = require("src.game.orders")
local Turn = require("src.game.turn")
local Predict = require("src.game.predict")
local PlanOverlay = require("src.app.render.plan_overlay")
local Timeline = require("src.app.render.timeline")
local Replay = require("src.app.render.replay")
local Match = require("src.game.match")

local PlanState = {}
PlanState.__index = PlanState

-- UI layout in world px.
PlanState.HANDLE_DISTANCE = 60 -- handle sits this far from the sub along the planned course
PlanState.HANDLE_GRAB_RADIUS = 14
PlanState.SPEEDS = { "stop", "slow", "half", "full" } -- button order, left to right
PlanState.TORPEDO_SPEEDS = { "slow", "fast" } -- torpedo speed buttons, left to right
PlanState.TORPEDO_HANDLE_DISTANCE = 100 -- launch angle handle, from the launch point
PlanState.FUSE_GRAB_RADIUS = 12
local BUTTON_Y, BUTTON_W, BUTTON_H, BUTTON_GAP = 16, 72, 32, 8
local ROW2_Y = BUTTON_Y + BUTTON_H + BUTTON_GAP -- the torpedo buttons' row
local TUBE_W = 112
local EXECUTE_W = 128
local PING_W = 96
local REPLAY_W = 112

local atan2 = math.atan2 or math.atan

local function inside(rect, x, y)
	return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function subForSlot(ctx, slot)
	for _, sub in ipairs(ctx.pools.subs) do
		if sub.slot == slot and not sub.dead then
			return sub
		end
	end
	return nil
end

-- `slot` is the slot this screen plans for ("player").
function PlanState.new(ctx, slot)
	local sub = subForSlot(ctx, slot)
	local helm = sub and sub.helm
	local self = setmetatable({
		phase = "plan",
		ctx = ctx,
		slot = slot,
		sub = sub,
		-- The plan starts as the sub's standing course, from the first tick.
		schedule = {
			{ tick = 1, order = Orders.course(helm and helm.heading or "east", helm and helm.dive or 0, helm and helm.speed or "stop") },
		},
		selected = 1, -- the timeline tick the course handle, speed buttons and PING act on
		dragging = false, -- what is being dragged: "course" or "torpedo" handle, or the "fuse" marker
		moving = nil, -- the schedule entry being dragged along the timeline
		torpedo = nil, -- the torpedo launch entry being edited
	}, PlanState)
	self:replan()
	return self
end

local function isBase(entry)
	return entry.tick == 1 and entry.order.kind == "course"
end

-- The entry at `tick` of order kind `kind` (and, for torpedoes, from `tube`).
-- A tick holds at most one order per kind, and per tube for torpedoes.
local function entryAt(self, tick, kind, tube)
	for _, entry in ipairs(self.schedule) do
		if entry.tick == tick and entry.order.kind == kind and entry.order.tube == tube then
			return entry
		end
	end
	return nil
end

-- The orders this plan submits, in tick order (ties keep placement order).
function PlanState:orders()
	local indexed = {}
	for i, entry in ipairs(self.schedule) do
		indexed[i] = { entry = entry, i = i }
	end
	table.sort(indexed, function(a, b)
		if a.entry.tick ~= b.entry.tick then
			return a.entry.tick < b.entry.tick
		end
		return a.i < b.i
	end)
	local orders = {}
	for i, item in ipairs(indexed) do
		orders[i] = { tick = item.entry.tick, order = item.entry.order }
	end
	return orders
end

-- Where the sub launches `entry`'s torpedo: its projected position after the
-- launch tick.
function PlanState:launchPoint(entry)
	local p = self.path[entry.tick]
	if not p then
		return nil
	end
	return p.x, p.y
end

function PlanState:replan()
	self.path = Predict.path(self.ctx, self.slot, self:orders())
	self.previews = {} -- torpedo entry -> Predict.torpedo preview
	for _, entry in ipairs(self.schedule) do
		if entry.order.kind == "torpedo" then
			local x, y = self:launchPoint(entry)
			if x then
				self.previews[entry] = Predict.torpedo(self.ctx, x, y, entry.order)
			end
		end
	end
end

-- The course order in effect at the selected tick: the latest course at or
-- before it.
function PlanState:course()
	local best
	for _, entry in ipairs(self.schedule) do
		if entry.order.kind == "course" and entry.tick <= self.selected and (not best or entry.tick >= best.tick) then
			best = entry
		end
	end
	return best.order
end

-- The course order at exactly the selected tick, created from the course in
-- effect there if the tick has none.
function PlanState:editCourse()
	local entry = entryAt(self, self.selected, "course")
	if not entry then
		local c = self:course()
		entry = { tick = self.selected, order = Orders.course(c.heading, c.dive, c.speed) }
		self.schedule[#self.schedule + 1] = entry
	end
	return entry.order
end

-- Places `order` at `tick` (selecting it), or returns false when the tick
-- already holds an order of that kind.
function PlanState:place(order, tick)
	if entryAt(self, tick, order.kind, order.tube) then
		return false
	end
	self.schedule[#self.schedule + 1] = { tick = tick, order = order }
	self.selected = tick
	self:replan()
	return true
end

-- Deletes `entry`; the tick-1 course is the standing course and stays.
function PlanState:remove(entry)
	if isBase(entry) then
		return false
	end
	for i, e in ipairs(self.schedule) do
		if e == entry then
			table.remove(self.schedule, i)
			if self.torpedo == entry then
				self.torpedo = nil
			end
			self:replan()
			return true
		end
	end
	return false
end

-- Moves `entry` to `tick` unless that is the standing course or the target
-- tick already holds an order of its kind.
function PlanState:move(entry, tick)
	if isBase(entry) or tick == entry.tick then
		return false
	end
	if entryAt(self, tick, entry.order.kind, entry.order.tube) then
		return false
	end
	entry.tick = tick
	self.selected = tick
	self:replan()
	return true
end

function PlanState:timelineRect()
	return Timeline.rect()
end

function PlanState:tickX(tick)
	return Timeline.tickX(tick, self.ctx.turn.length)
end

function PlanState:subPosition()
	local body = self.sub and Bodies.get(self.ctx.bodies, self.sub.bodyId)
	if not body then
		return nil
	end
	return body.x, body.y
end

-- Where the sub is when the selected tick's orders apply: its start for the
-- first tick, else where the ghost path has it after the tick before.
function PlanState:anchorPosition()
	if self.selected <= 1 then
		return self:subPosition()
	end
	local p = self.path[self.selected - 1]
	if not p then
		return nil
	end
	return p.x, p.y
end

function PlanState:handlePosition()
	local x, y = self:anchorPosition()
	if not x then
		return nil
	end
	local angle = Helm.targetAngle(self:course())
	return x + PlanState.HANDLE_DISTANCE * math.cos(angle), y + PlanState.HANDLE_DISTANCE * math.sin(angle)
end

function PlanState:speedButton(speed)
	for i, key in ipairs(PlanState.SPEEDS) do
		if key == speed then
			return { x = 16 + (i - 1) * (BUTTON_W + BUTTON_GAP), y = BUTTON_Y, w = BUTTON_W, h = BUTTON_H }
		end
	end
	return nil
end

-- Sits right of the speed buttons, after a gap. Places or removes a ping at
-- the selected tick.
function PlanState:pingButton()
	local x = 16 + #PlanState.SPEEDS * (BUTTON_W + BUTTON_GAP) + BUTTON_W / 2
	return { x = x, y = BUTTON_Y, w = PING_W, h = BUTTON_H }
end

function PlanState:tubeButton(i)
	return { x = 16 + (i - 1) * (TUBE_W + BUTTON_GAP), y = ROW2_Y, w = TUBE_W, h = BUTTON_H }
end

-- Right of the tube buttons, after a gap.
function PlanState:torpedoSpeedButton(speed)
	local left = 16 + self.ctx.config.tubes.count * (TUBE_W + BUTTON_GAP) + BUTTON_W / 2
	for i, key in ipairs(PlanState.TORPEDO_SPEEDS) do
		if key == speed then
			return { x = left + (i - 1) * (BUTTON_W + BUTTON_GAP), y = ROW2_Y, w = BUTTON_W, h = BUTTON_H }
		end
	end
	return nil
end

-- Ticks until tube `i` is loaded, as the turn starts (own-ship knowledge).
function PlanState:tubeReload(i)
	local tube = self.sub and self.sub.tubes[i]
	return tube and tube.reload or 0
end

function PlanState:executeButton()
	return { x = 1280 - 16 - EXECUTE_W, y = BUTTON_Y, w = EXECUTE_W, h = BUTTON_H }
end

function PlanState:replayButton()
	local execute = self:executeButton()
	return { x = execute.x - BUTTON_GAP - REPLAY_W, y = BUTTON_Y, w = REPLAY_W, h = BUTTON_H }
end

-- There is a last turn to replay from turn 2 on.
function PlanState:replayAvailable()
	return self.ctx.turn.number > 1
end

function PlanState:replaying()
	return self.replay ~= nil
end

-- The last execute phase's first and last global ticks.
function PlanState:replayRange()
	local last = self.ctx.tick
	return last - self.ctx.turn.length + 1, last
end

-- Screen x of global `tick` on the scrub bar (the timeline strip's geometry).
function PlanState:scrubX(tick)
	local first = self:replayRange()
	return Timeline.tickX(tick - first + 1, self.ctx.turn.length)
end

function PlanState:toggleReplay()
	if self.replay then
		self.replay = nil
	elseif self:replayAvailable() then
		self.dragging, self.moving = false, nil
		self.replay = { tick = (self:replayRange()) }
	end
end

function PlanState:scrubTo(x)
	local first = self:replayRange()
	self.replay.tick = first + Timeline.tickAt(x, self.ctx.turn.length) - 1
end

-- The player's perception at the scrubbed tick, or nil when not replaying.
function PlanState:replayPerception()
	if not self.replay then
		return nil
	end
	local perception = Match.perceptionOf(self.ctx, self.slot)
	return perception and Replay.view(perception, self.replay.tick)
end

-- Points the selected tick's course from the sub towards (x, y): the side picks the heading,
-- the slope the dive, clamped to the configured limit.
function PlanState:aimAt(x, y)
	local sx, sy = self:anchorPosition()
	local dx, dy = x - sx, y - sy
	if dx == 0 and dy == 0 then
		return
	end
	local maxDive = self.ctx.config.sub.maxDive
	local course = self:editCourse()
	course.heading = dx < 0 and "west" or "east"
	course.dive = math.max(-maxDive, math.min(maxDive, atan2(dy, math.abs(dx))))
	self:replan()
end

-- Submits this slot's orders. The match's own AI slots have already
-- submitted theirs, so the turn executes.
function PlanState:commit()
	Turn.submit(self.ctx, self.slot, self:orders())
end

-- The preview of the launch being edited, or nil.
function PlanState:torpedoPreview()
	return self.torpedo and self.previews[self.torpedo]
end

-- Places a launch from `tube` at the selected tick (aimed along the sub's
-- projected heading there, at the slow setting and the default fuse) and
-- edits it; or, if that tube already launches at this tick, removes it.
function PlanState:toggleTorpedo(tube)
	local existing = entryAt(self, self.selected, "torpedo", tube)
	if existing then
		self:remove(existing)
		return
	end
	local p = self.path[self.selected]
	local order = Orders.torpedo(tube, p and p.angle or 0, PlanState.TORPEDO_SPEEDS[1], self.ctx.config.torpedo.defaultFuse)
	if self:place(order, self.selected) then
		self.torpedo = self.schedule[#self.schedule]
		self:replan()
	end
end

function PlanState:torpedoHandlePosition()
	if not self.torpedo then
		return nil
	end
	local x, y = self:launchPoint(self.torpedo)
	if not x then
		return nil
	end
	local angle, d = self.torpedo.order.angle, PlanState.TORPEDO_HANDLE_DISTANCE
	return x + d * math.cos(angle), y + d * math.sin(angle)
end

-- Aims the launch being edited from its launch point towards (x, y).
function PlanState:aimTorpedo(x, y)
	local lx, ly = self:launchPoint(self.torpedo)
	if not lx or (x == lx and y == ly) then
		return
	end
	self.torpedo.order.angle = atan2(y - ly, x - lx)
	self:replan()
end

-- The fuse marker of the launch being edited: the preview point where the
-- fuse runs out (the line's end if it meets rock first).
function PlanState:fuseMarkerPosition()
	local preview = self:torpedoPreview()
	if not preview or #preview.points == 0 then
		return nil
	end
	local p = preview.points[math.min(self.torpedo.order.fuse, #preview.points)]
	return p.x, p.y
end

-- Sets the fuse of the launch being edited to the tick of the preview point
-- nearest (x, y).
function PlanState:setFuseNear(x, y)
	local preview = self:torpedoPreview()
	if not preview then
		return
	end
	local best, bestD
	for k, p in ipairs(preview.points) do
		local d = (p.x - x) ^ 2 + (p.y - y) ^ 2
		if not bestD or d < bestD then
			best, bestD = k, d
		end
	end
	if best then
		self.torpedo.order.fuse = best
		self:replan()
	end
end

function PlanState:hasPingAtSelected()
	return entryAt(self, self.selected, "ping") ~= nil
end

function PlanState:togglePing()
	local ping = entryAt(self, self.selected, "ping")
	if ping then
		self:remove(ping)
	else
		self:place(Orders.ping(), self.selected)
	end
end

local function timelinePress(self, x, y, button)
	local length = self.ctx.turn.length
	local i = Timeline.markerAt(self.schedule, length, x, y)
	local entry = i and self.schedule[i]
	if button == 2 then
		if entry then
			self:remove(entry)
		end
		return
	end
	if entry then
		self.selected = entry.tick
		self.moving = not isBase(entry) and entry or nil
		if entry.order.kind == "torpedo" then
			self.torpedo = entry
		end
	else
		self.selected = Timeline.tickAt(x, length)
	end
end

function PlanState:mousepressed(x, y, button)
	if self.ctx.turn.phase ~= "plan" then
		return
	end
	if self.replay then
		if button == 1 and inside(self:replayButton(), x, y) then
			self:toggleReplay()
		elseif button == 1 and Timeline.contains(x, y) then
			self.replay.scrubbing = true
			self:scrubTo(x)
		end
		return
	end
	if Timeline.contains(x, y) then
		timelinePress(self, x, y, button)
		return
	end
	if button ~= 1 then
		return
	end
	for _, speed in ipairs(PlanState.SPEEDS) do
		if inside(self:speedButton(speed), x, y) then
			self:editCourse().speed = speed
			self:replan()
			return
		end
	end
	if inside(self:pingButton(), x, y) then
		self:togglePing()
		return
	end
	for i = 1, self.ctx.config.tubes.count do
		if inside(self:tubeButton(i), x, y) then
			self:toggleTorpedo(i)
			return
		end
	end
	for _, speed in ipairs(PlanState.TORPEDO_SPEEDS) do
		if inside(self:torpedoSpeedButton(speed), x, y) then
			if self.torpedo then
				self.torpedo.order.speed = speed
				self:replan()
			end
			return
		end
	end
	if inside(self:executeButton(), x, y) then
		self:commit()
		return
	end
	if inside(self:replayButton(), x, y) then
		self:toggleReplay()
		return
	end
	-- Handles, topmost first: the fuse marker, the launch angle, the course.
	local grabs = {
		{ "fuse", PlanState.FUSE_GRAB_RADIUS, self:fuseMarkerPosition() },
		{ "torpedo", PlanState.HANDLE_GRAB_RADIUS, self:torpedoHandlePosition() },
		{ "course", PlanState.HANDLE_GRAB_RADIUS, self:handlePosition() },
	}
	for _, grab in ipairs(grabs) do
		local hx, hy = grab[3], grab[4]
		if hx and (x - hx) ^ 2 + (y - hy) ^ 2 <= grab[2] ^ 2 then
			self.dragging = grab[1]
			return
		end
	end
end

function PlanState:mousemoved(x, y)
	if self.replay then
		if self.replay.scrubbing then
			self:scrubTo(x)
		end
	elseif self.dragging == "course" then
		self:aimAt(x, y)
	elseif self.dragging == "torpedo" then
		self:aimTorpedo(x, y)
	elseif self.dragging == "fuse" then
		self:setFuseNear(x, y)
	elseif self.moving then
		self:move(self.moving, Timeline.tickAt(x, self.ctx.turn.length))
	end
end

function PlanState:mousereleased(x, y, button)
	if self.replay then
		self.replay.scrubbing = false
	end
	if button == 1 then
		self.dragging = false
		self.moving = nil
	end
end

-- Once committed, hands over to the execute phase and runs its first frame.
function PlanState:update(dt)
	if self.ctx.turn.phase == "execute" then
		local ExecuteState = require("src.app.states.execute_state")
		local nextState = ExecuteState.new(self.ctx, self.slot)
		return nextState:update(dt) or nextState
	end
	return nil
end

function PlanState:draw()
	if self.replay then
		local first, last = self:replayRange()
		local label = string.format("TURN %d  REPLAY  %.1f s", self.ctx.turn.number - 1, (self.replay.tick - first + 1) * self.ctx.config.dt)
		Replay.drawBar(self:timelineRect(), self:scrubX(self.replay.tick), label)
		PlanOverlay.drawButton(self:replayButton(), "CLOSE", true)
		return
	end
	PlanOverlay.draw(self)
end

return PlanState
