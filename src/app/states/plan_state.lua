-- Plan phase screen for one human slot: the match is paused (no Match.step).
-- The turn's orders live on a timeline (render/timeline): a `schedule` of
-- `{ tick, order }` entries, always starting with the sub's standing course at
-- tick 1. The player selects a tick by clicking the strip; dragging the course
-- handle then sets a course target, where the sub should end the turn, and
-- src/game/course_solve picks heading, dive and speed for the course order at
-- that tick (created from the course in effect there if none exists) to land
-- as close to it as it can; dropping it on the sub plans a stop. PING
-- toggles a ping at the selected tick.
-- A TUBE button toggles a torpedo launch from that tube at the selected tick
-- and makes it the launch being edited (`torpedo`; clicking a torpedo marker
-- on the strip selects it too): one drag anywhere off the buttons and the
-- course handle sets its aim point, and src/game/torpedo_aim turns that into
-- angle, speed and fuse (a point past the slow range clamps to it).
-- Markers on the strip can be dragged to another tick, and right-clicked to
-- delete (the tick-1 course stays). A ghost path (src/game/predict) shows the
-- projected course, and each launch's preview its straight run and fuse
-- point. Execute commits the schedule. Mouse coordinates are world px; the
-- REPLAY (once there is a last turn) opens a modal scrubber over the strip:
-- click or drag it to see the player's perception at each tick of the last
-- execute phase (`replay.tick`, a global tick); planning input is inert until
-- REPLAY closes it again. The strip then shows the last turn's orders,
-- read-only. Mouse coordinates are world px; the
-- caller undoes the screen fit. Logic is pure; drawing is in
-- render/plan_overlay, render/torpedo_plan and render/timeline.
local Bodies = require("src.sim.bodies")
local Helm = require("src.game.components.helm")
local Orders = require("src.game.orders")
local Turn = require("src.game.turn")
local Predict = require("src.game.predict")
local CourseSolve = require("src.game.course_solve")
local TorpedoAim = require("src.game.torpedo_aim")
local PlanOverlay = require("src.app.render.plan_overlay")
local Timeline = require("src.app.render.timeline")
local Replay = require("src.app.render.replay")
local Match = require("src.game.match")
local OrderLog = require("src.game.order_log")

local PlanState = {}
PlanState.__index = PlanState

-- UI layout in world px.
PlanState.HANDLE_DISTANCE = 60 -- handle sits this far from the sub along the planned course
PlanState.HANDLE_GRAB_RADIUS = 14
local BUTTON_Y, BUTTON_W, BUTTON_H, BUTTON_GAP = 16, 72, 32, 8
local ROW2_Y = BUTTON_Y + BUTTON_H + BUTTON_GAP -- the torpedo buttons' row
local TUBE_W = 112
local EXECUTE_W = 128
local PING_W = 96
local REPLAY_W = 112

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

-- The rest of the run of each of `slot`'s own torpedoes still in the water at
-- plan start, as `{ torpedo, preview, x, y, angle }` (Predict.torpedoInFlight;
-- x, y, angle: where it is at plan start, where its run line starts). Own-ship
-- knowledge only (ADR 0002): ctx.pools.torpedoes is read here filtered by
-- `owner == slot` and nowhere else; enemy torpedoes are never looked at.
local function ownTorpedoesInFlight(ctx, slot)
	local flights = {}
	for _, torpedo in ipairs(ctx.pools.torpedoes) do
		if torpedo.owner == slot and not torpedo.dead then
			local body = Bodies.get(ctx.bodies, torpedo.bodyId)
			flights[#flights + 1] = {
				torpedo = torpedo,
				preview = Predict.torpedoInFlight(ctx, torpedo),
				x = body.x, y = body.y, angle = body.angle,
			}
		end
	end
	return flights
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
			{ tick = 1, order = Orders.course(helm and helm.heading or "east", helm and helm.dive or 0, helm and helm.speed or 0) },
		},
		selected = 1, -- the timeline tick the course handle, speed buttons and PING act on
		dragging = false, -- what is being dragged: the "course" handle or the "torpedo" aim point
		solver = nil, -- the CourseSolve for the course drag in progress
		target = nil, -- the last course target: { order = <course order it was solved for>, x, y }
		moving = nil, -- the schedule entry being dragged along the timeline
		torpedo = nil, -- the torpedo launch entry being edited
		aims = {}, -- torpedo entry -> { x, y }: the aim point dragged to, as asked
		-- Earlier turns' own torpedoes still running, projected once per plan
		-- phase: the plan cannot change them.
		inFlight = ownTorpedoesInFlight(ctx, slot),
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
	self.aimed = {} -- torpedo entry -> TorpedoAim.solve result (clamped point, dud)
	for _, entry in ipairs(self.schedule) do
		if entry.order.kind == "torpedo" then
			local x, y = self:launchPoint(entry)
			local aim = self.aims[entry]
			if x and aim then
				-- The launch point moves with the course, so the order is
				-- solved afresh for the same aim point.
				local solved = TorpedoAim.solve(self.ctx, entry.order.tube, x, y, aim.x, aim.y)
				entry.order.angle, entry.order.speed, entry.order.fuse = solved.order.angle, solved.order.speed, solved.order.fuse
				self.aimed[entry] = solved
			end
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

-- The course target set for the selected tick's course order and where the
-- ghost path ends: tx, ty, ex, ey; nil when that order has no target.
function PlanState:courseTarget()
	local entry = entryAt(self, self.selected, "course")
	local last = self.path[#self.path]
	if not self.target or not entry or entry.order ~= self.target.order or not last then
		return nil
	end
	return self.target.x, self.target.y, last.x, last.y
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
				self.aims[entry] = nil
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

-- The course handle: on the selected course order's target if it has one,
-- else a fixed distance along its course from the anchor.
function PlanState:handlePosition()
	local tx, ty = self:courseTarget()
	if tx then
		return tx, ty
	end
	local x, y = self:anchorPosition()
	if not x then
		return nil
	end
	local angle = Helm.targetAngle(self:course())
	return x + PlanState.HANDLE_DISTANCE * math.cos(angle), y + PlanState.HANDLE_DISTANCE * math.sin(angle)
end

-- Places or removes a ping at the selected tick.
function PlanState:pingButton()
	return { x = 16, y = BUTTON_Y, w = PING_W, h = BUTTON_H }
end

function PlanState:tubeButton(i)
	return { x = 16 + (i - 1) * (TUBE_W + BUTTON_GAP), y = ROW2_Y, w = TUBE_W, h = BUTTON_H }
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

-- The PLAY/PAUSE button sits left of REPLAY/CLOSE.
function PlanState:playButton()
	local replay = self:replayButton()
	return { x = replay.x - BUTTON_GAP - REPLAY_W, y = BUTTON_Y, w = REPLAY_W, h = BUTTON_H }
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
		-- Last turn's orders for this slot, read once; drawn read-only on the strip.
		self.replay = {
			tick = (self:replayRange()),
			entries = OrderLog.forTurn(self.ctx.orderLog, self.ctx.turn.number - 1, self.slot),
		}
	end
end

-- The last turn's orders as `{ tick, order }` entries, while replaying.
function PlanState:replayPlaying()
	return self.replay ~= nil and self.replay.playing
end

function PlanState:playLabel()
	return self:replayPlaying() and "PAUSE" or "PLAY"
end

-- Plays from the scrubbed tick (from the first, if it is on the last), or pauses.
function PlanState:togglePlay()
	local replay = self.replay
	if replay.playing then
		replay.playing = false
		return
	end
	local first, last = self:replayRange()
	if replay.tick >= last then
		replay.tick = first
	end
	replay.playing, replay.accumulator = true, 0
end

function PlanState:replayEntries()
	return self.replay and self.replay.entries
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

-- Sets a course target at (x, y): solves the selected tick's course order
-- (heading, dive and speed) so the turn ends as close to it as it can.
-- Later course orders stay as they are. One solver serves a whole drag.
function PlanState:steerTo(x, y)
	local course = self:editCourse()
	if not self.solver then
		self.solver = CourseSolve.new(self.ctx, self.slot, self:orders(), course)
	end
	local solved = self.solver:solve(x, y).order
	course.heading, course.dive, course.speed = solved.heading, solved.dive, solved.speed
	self.target = { order = course, x = x, y = y }
	self:replan()
end

-- Submits this slot's orders. The match's own AI slots have already
-- submitted theirs, so the turn executes.
function PlanState:commit()
	Turn.submit(self.ctx, self.slot, self:orders())
end

-- The own torpedoes in the water at `tick`: each planned launch as `{ entry,
-- x, y }` from its launch tick (the launch point) until its run ends, and
-- each earlier turn's torpedo still running as `{ flight, x, y }` (a
-- self.inFlight item) until its run ends.
function PlanState:torpedoesAt(tick)
	local found = {}
	for _, flight in ipairs(self.inFlight) do
		local p = tick >= 1 and tick <= (flight.preview.endTick or #flight.preview.points) and flight.preview.points[tick]
		if p then
			found[#found + 1] = { flight = flight, x = p.x, y = p.y }
		end
	end
	for _, entry in ipairs(self.schedule) do
		local preview = self.previews[entry]
		local k = tick - entry.tick
		if preview and k >= 0 and k <= (preview.endTick or #preview.points) then
			local x, y
			if k == 0 then
				x, y = self:launchPoint(entry)
			else
				local p = preview.points[k]
				x, y = p.x, p.y
			end
			found[#found + 1] = { entry = entry, x = x, y = y }
		end
	end
	return found
end

-- The preview of the launch being edited, or nil.
function PlanState:torpedoPreview()
	return self.torpedo and self.previews[self.torpedo]
end

-- Places a launch from `tube` at the selected tick (aimed along the sub's
-- projected heading there, at the slow setting and the default fuse, until
-- an aim drag sets them) and edits it; or, if that tube already launches at this tick, removes it.
function PlanState:toggleTorpedo(tube)
	local existing = entryAt(self, self.selected, "torpedo", tube)
	if existing then
		self:remove(existing)
		return
	end
	local p = self.path[self.selected]
	local order = Orders.torpedo(tube, p and p.angle or 0, "slow", self.ctx.config.torpedo.defaultFuse)
	if self:place(order, self.selected) then
		self.torpedo = self.schedule[#self.schedule]
		self:replan()
	end
end

-- Aims the launch being edited at (x, y): sets its aim point, from which
-- the order's angle, speed and fuse follow.
function PlanState:aimTorpedo(x, y)
	local lx, ly = self:launchPoint(self.torpedo)
	if not lx or (x == lx and y == ly) then
		return
	end
	self.aims[self.torpedo] = { x = x, y = y }
	self:replan()
end

-- The aim point of the launch being edited as the plan runs it (clamped to
-- the slow range): x, y, whether it is a dud; nil before it is aimed.
function PlanState:aimPoint()
	local aimed = self.torpedo and self.aimed[self.torpedo]
	if not aimed then
		return nil
	end
	return aimed.x, aimed.y, aimed.dud
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
		self.scrubbing = true
	end
end

function PlanState:mousepressed(x, y, button)
	if self.ctx.turn.phase ~= "plan" then
		return
	end
	if self.replay then
		if button == 1 and inside(self:replayButton(), x, y) then
			self:toggleReplay()
		elseif button == 1 and inside(self:playButton(), x, y) then
			self:togglePlay()
		elseif button == 1 and Timeline.contains(x, y) then
			self.replay.playing = false
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
	if inside(self:executeButton(), x, y) then
		self:commit()
		return
	end
	if inside(self:replayButton(), x, y) then
		self:toggleReplay()
		return
	end
	-- The course handle, else (with a launch being edited) an aim drag.
	local hx, hy = self:handlePosition()
	if hx and (x - hx) ^ 2 + (y - hy) ^ 2 <= PlanState.HANDLE_GRAB_RADIUS ^ 2 then
		self.dragging = "course"
		self.solver = nil
	elseif self.torpedo then
		self.dragging = "torpedo"
		self:aimTorpedo(x, y)
	end
end

function PlanState:mousemoved(x, y)
	if self.replay then
		if self.replay.scrubbing then
			self:scrubTo(x)
		end
	elseif self.dragging == "course" then
		self:steerTo(x, y)
	elseif self.dragging == "torpedo" then
		self:aimTorpedo(x, y)
	elseif self.moving then
		self:move(self.moving, Timeline.tickAt(x, self.ctx.turn.length))
	elseif self.scrubbing then
		self.selected = Timeline.tickAt(x, self.ctx.turn.length)
	end
end

function PlanState:mousereleased(x, y, button)
	if self.replay then
		self.replay.scrubbing = false
	end
	if button == 1 then
		self.dragging = false
		self.solver = nil
		self.moving = nil
		self.scrubbing = false
	end
end

-- Once committed, hands over to the execute phase and runs its first frame.
function PlanState:update(dt)
	if self.ctx.turn.phase == "execute" then
		local ExecuteState = require("src.app.states.execute_state")
		local nextState = ExecuteState.new(self.ctx, self.slot)
		return nextState:update(dt) or nextState
	end
	local replay = self.replay
	if replay and replay.playing then
		local _, last = self:replayRange()
		local step = self.ctx.config.dt
		replay.accumulator = replay.accumulator + dt
		while replay.accumulator >= step and replay.tick < last do
			replay.accumulator = replay.accumulator - step
			replay.tick = replay.tick + 1
		end
		if replay.tick >= last then
			replay.playing = false
		end
	end
	return nil
end

function PlanState:draw()
	if self.replay then
		local first, last = self:replayRange()
		local label = string.format("TURN %d  REPLAY  %.1f s", self.ctx.turn.number - 1, (self.replay.tick - first + 1) * self.ctx.config.dt)
		local cursor = self.replay.tick - first + 1
		Timeline.draw(self.replay.entries, self.ctx.turn.length, PlanOverlay.ticksPerSecond(self), cursor)
		Replay.drawLabel(label)
		PlanOverlay.drawButton(self:replayButton(), "CLOSE", true)
		PlanOverlay.drawButton(self:playButton(), self:playLabel(), true)
		return
	end
	PlanOverlay.draw(self)
end

return PlanState
