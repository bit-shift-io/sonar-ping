-- The turn timeline: a strip along the bottom of the plan screen showing the
-- turn's seconds, with each scheduled order as a marker on its kind's row.
-- Planning UI only; the sim sees orders, never this. The geometry is pure (no
-- `love.*`), so PlanState can hit-test markers; drawing reaches `love.*` only
-- when called. A new order kind plugs in by adding an entry to Timeline.KINDS.
local Timeline = {}

-- World px. The strip spans the screen width less a margin, and is tall
-- enough for three rows (course, ping, torpedo).
Timeline.X, Timeline.Y, Timeline.W, Timeline.H = 16, 668, 1248, 36
local ROW_TOP, ROW_STEP = 18, 7 -- first row's centre below the strip top (clear of the second labels); row spacing
local HIT_X, HIT_Y = 4, 3 -- marker grab half-size

-- Per order kind: `row` (0-based line on the strip), `shape(mode, x, y)` (the
-- small marker on the strip), `ghost(x, y)` (marker drawn on the ghost path at the order's
-- position), `color`.
Timeline.KINDS = {
	course = {
		row = 0,
		shape = function(mode, x, y)
			love.graphics.polygon(mode, x, y - 3, x + 3, y, x, y + 3, x - 3, y)
		end,
		color = { 1.0, 0.9, 0.3, 1 },
		ghost = function(x, y)
			love.graphics.polygon("line", x, y - 6, x + 6, y, x, y + 6, x - 6, y)
		end,
	},
	ping = {
		row = 1,
		shape = function(mode, x, y)
			love.graphics.circle(mode, x, y, 3)
		end,
		color = { 0.5, 0.9, 1.0, 1 },
		ghost = function(x, y)
			love.graphics.circle("line", x, y, 6)
			love.graphics.circle("line", x, y, 10)
		end,
	},
	-- Both tubes share the row; a launch is drawn where the sub fires it.
	torpedo = {
		row = 2,
		shape = function(mode, x, y)
			love.graphics.polygon(mode, x, y - 3, x + 3, y + 3, x - 3, y + 3)
		end,
		color = { 1.0, 0.45, 0.3, 1 },
		ghost = function(x, y)
			love.graphics.polygon("line", x, y - 7, x + 6, y + 5, x - 6, y + 5)
		end,
	},
}

function Timeline.rect()
	return { x = Timeline.X, y = Timeline.Y, w = Timeline.W, h = Timeline.H }
end

-- Screen x of the left edge of `tick` (1..length) on the strip.
function Timeline.tickX(tick, length)
	return Timeline.X + (tick - 1) / (length - 1) * Timeline.W
end

-- The tick under screen x, clamped to the turn.
function Timeline.tickAt(x, length)
	local tick = math.floor((x - Timeline.X) / Timeline.W * (length - 1) + 0.5) + 1
	return math.max(1, math.min(length, tick))
end

function Timeline.contains(x, y)
	return x >= Timeline.X and x <= Timeline.X + Timeline.W and y >= Timeline.Y and y <= Timeline.Y + Timeline.H
end

-- Screen y of the centre of `kind`'s row on the strip.
function Timeline.rowY(kind)
	return Timeline.Y + ROW_TOP + Timeline.KINDS[kind].row * ROW_STEP
end

-- The index of the topmost entry (last in the list) whose marker is under
-- (x, y), or nil. `entries` are `{ tick, order }`.
function Timeline.markerAt(entries, length, x, y)
	for i = #entries, 1, -1 do
		local entry = entries[i]
		local style = Timeline.KINDS[entry.order.kind]
		if style then
			local mx, my = Timeline.tickX(entry.tick, length), Timeline.rowY(entry.order.kind)
			if math.abs(x - mx) <= HIT_X and math.abs(y - my) <= HIT_Y then
				return i
			end
		end
	end
	return nil
end

-- Markers on the ghost path, one per scheduled order, at the sub's position
-- on the order's tick (`path[tick]`).
function Timeline.drawGhostMarkers(entries, path)
	for _, entry in ipairs(entries) do
		local style = Timeline.KINDS[entry.order.kind]
		local p = path[entry.tick]
		if style and p then
			love.graphics.setColor(style.color)
			style.ghost(p.x, p.y)
		end
	end
end

local FRAME = { 0.6, 1.0, 0.6, 1 }
local BACK = { 0.0, 0.08, 0.04, 0.8 }
local CURSOR = { 1, 1, 1, 0.9 }

-- `selected` is the cursor tick; `moving` the entry being dragged, if any.
function Timeline.draw(entries, length, ticksPerSecond, selected, moving)
	love.graphics.setColor(BACK)
	love.graphics.rectangle("fill", Timeline.X, Timeline.Y, Timeline.W, Timeline.H)
	love.graphics.setColor(FRAME)
	love.graphics.rectangle("line", Timeline.X, Timeline.Y, Timeline.W, Timeline.H)
	for second = 0, math.floor((length - 1) / ticksPerSecond) do
		local x = Timeline.tickX(second * ticksPerSecond + 1, length)
		love.graphics.line(x, Timeline.Y, x, Timeline.Y + 8)
		love.graphics.print(tostring(second), x + 2, Timeline.Y - 1)
	end

	local cx = Timeline.tickX(selected, length)
	love.graphics.setColor(CURSOR)
	love.graphics.line(cx, Timeline.Y, cx, Timeline.Y + Timeline.H)

	for _, entry in ipairs(entries) do
		local style = Timeline.KINDS[entry.order.kind]
		if style then
			local x, y = Timeline.tickX(entry.tick, length), Timeline.rowY(entry.order.kind)
			love.graphics.setColor(style.color)
			style.shape(entry == moving and "fill" or "line", x, y)
		end
	end
end

return Timeline
