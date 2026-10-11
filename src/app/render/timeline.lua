-- The turn timeline: one strip along the bottom of the screen from -5 s to
-- +5 s. Ticks are signed, relative to the plan's start (0, the centre): the
-- left half is the last execute phase (its orders greyed, read-only), the
-- right half this turn (plan ticks 1..length, each scheduled order a marker on
-- its kind's row).
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

-- Screen x of signed `tick` on the strip: 0 at the centre, `length` at the
-- right edge, `-length` at the left.
function Timeline.tickX(tick, length)
	return Timeline.X + Timeline.W / 2 + tick / length * Timeline.W / 2
end

-- The signed tick of tick `tick` (1..length) of the last execute phase: its
-- last tick is 0, the plan's start.
function Timeline.pastTick(tick, length)
	return tick - length
end

-- The lowest tick the cursor can reach in turn `number`: the last execute
-- phase's first tick, or the plan's first on turn 1 (there is none before).
function Timeline.lowestTick(number, length)
	return number > 1 and 1 - length or 1
end

-- The signed tick under screen x, clamped to `lowest` (default the last
-- execute phase's first tick, `1 - length`) and the plan's last tick.
function Timeline.tickAt(x, length, lowest)
	local tick = math.floor((x - Timeline.X - Timeline.W / 2) / (Timeline.W / 2) * length + 0.5)
	return math.max(lowest or 1 - length, math.min(length, tick))
end

function Timeline.contains(x, y)
	return x >= Timeline.X and x <= Timeline.X + Timeline.W and y >= Timeline.Y and y <= Timeline.Y + Timeline.H
end

-- Screen y of the centre of `kind`'s row on the strip.
function Timeline.rowY(kind)
	return Timeline.Y + ROW_TOP + Timeline.KINDS[kind].row * ROW_STEP
end

-- The index of the topmost entry (last in the list) whose marker is under
-- (x, y), or nil. `entries` are `{ tick, order }`. Only plan markers (right
-- half, tick >= 1) can be hit; the left half is read-only.
function Timeline.markerAt(entries, length, x, y)
	for i = #entries, 1, -1 do
		local entry = entries[i]
		local style = Timeline.KINDS[entry.order.kind]
		if style and entry.tick >= 1 then
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
local EMPTY = { 0.0, 0.0, 0.0, 0.6 } -- the left half on turn 1: no last execute phase
local PAST = { 0.45, 0.5, 0.45, 1 } -- last turn's markers: read-only
local CURSOR = { 1, 1, 1, 0.9 }
local LABEL_ABOVE = 14 -- the cursor's time label sits this far above the strip

local function secondLabel(second)
	return second > 0 and "+" .. second or tostring(second)
end

-- `entries` are this turn's orders (right half), `past` last turn's at their
-- signed ticks (left half, greyed). `cursor` is the signed cursor tick;
-- `moving` the entry being dragged, if any; `lowest` the lowest tick the
-- cursor can reach (1 on turn 1, whose left half is drawn empty).
function Timeline.draw(entries, past, length, ticksPerSecond, cursor, moving, lowest)
	local centre = Timeline.tickX(0, length)
	love.graphics.setColor(BACK)
	love.graphics.rectangle("fill", Timeline.X, Timeline.Y, Timeline.W, Timeline.H)
	if (lowest or 1 - length) >= 1 then
		love.graphics.setColor(EMPTY)
		love.graphics.rectangle("fill", Timeline.X, Timeline.Y, centre - Timeline.X, Timeline.H)
	end
	love.graphics.setColor(FRAME)
	love.graphics.rectangle("line", Timeline.X, Timeline.Y, Timeline.W, Timeline.H)
	love.graphics.line(centre, Timeline.Y, centre, Timeline.Y + Timeline.H)
	local seconds = math.floor(length / ticksPerSecond)
	for second = -seconds, seconds do
		local x = Timeline.tickX(second * ticksPerSecond, length)
		local label = secondLabel(second)
		local font = love.graphics.getFont()
		local lx = math.min(x + 2, Timeline.X + Timeline.W - font:getWidth(label) - 2)
		love.graphics.line(x, Timeline.Y, x, Timeline.Y + 8)
		love.graphics.print(label, lx, Timeline.Y - 1)
	end

	for _, entry in ipairs(past) do
		local style = Timeline.KINDS[entry.order.kind]
		if style then
			love.graphics.setColor(PAST)
			style.shape("line", Timeline.tickX(entry.tick, length), Timeline.rowY(entry.order.kind))
		end
	end
	for _, entry in ipairs(entries) do
		local style = Timeline.KINDS[entry.order.kind]
		if style then
			local x, y = Timeline.tickX(entry.tick, length), Timeline.rowY(entry.order.kind)
			love.graphics.setColor(style.color)
			style.shape(entry == moving and "fill" or "line", x, y)
		end
	end

	local cx = Timeline.tickX(cursor, length)
	love.graphics.setColor(CURSOR)
	love.graphics.line(cx, Timeline.Y, cx, Timeline.Y + Timeline.H)
	love.graphics.print(string.format("%+.1f s", cursor / ticksPerSecond), cx + 3, Timeline.Y - LABEL_ABOVE)
end

return Timeline
