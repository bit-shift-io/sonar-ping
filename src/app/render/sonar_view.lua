-- The player's screen: one observer's perception drawn as green phosphor
-- (blue for contacts a torpedo produced).
-- Passive contacts glow at their perceived (smeared) positions; ping echoes
-- are sharp cells with no halo; a heard ping origin is a small cross; a heard
-- detonation (a "blast", smeared like any passive sound) is a ring. All
-- fade with age; everything not heard stays dark, terrain included. Reads only the
-- perception it is given -- never true state (ADR 0002; a unit test checks
-- this module's requires). Draws in world px; the caller applies the screen
-- fit. No `love.*` at load time.
local Perception = require("src.perception.perception")

local SonarView = {}

local PHOSPHOR = { 0.3, 1.0, 0.4 }
local TORPEDO = { 0.3, 0.6, 1.0 } -- contacts a torpedo produced draw blue
local GLOW_SCALE = 3 -- halo size in cells
local GLOW_ALPHA = 0.08
local OWN_SHIP = { 0.35, 1.0, 0.45, 0.35 }
local ECHO_ALPHA = 0.9
local PING_MARK = 3 -- ping origin cross half-size, in cells
local BLAST_RING = 6 -- heard detonation ring radius, in cells

-- Louder noise draws brighter: level 1 (slow) is dim, 4 (full) near full.
local function loudness(level)
	return math.min(1, 0.35 + 0.18 * level)
end

-- `perception` may be nil (no observer, e.g. the player's sub is gone).
-- `cellSize` converts perception's cell units to world px.
function SonarView.draw(perception, cellSize)
	if not perception or not perception.tick then
		return
	end
	local glow = cellSize * GLOW_SCALE
	-- Alpha blending: overlapping contacts converge on phosphor green rather
	-- than saturating to white.
	for _, contact in ipairs(perception.contacts) do
		local colour = contact.torpedo and TORPEDO or PHOSPHOR
		local r, g, b = colour[1], colour[2], colour[3]
		local fade = 1 - Perception.age(perception, contact) / Perception.fadeTicksOf(perception, contact)
		-- Cell units have cell centres at integers; (x - 0.5) * size is px.
		local px, py = (contact.x - 0.5) * cellSize, (contact.y - 0.5) * cellSize
		if contact.kind == "echo" then
			love.graphics.setColor(r, g, b, ECHO_ALPHA * fade)
			love.graphics.rectangle("fill", px - cellSize / 2, py - cellSize / 2, cellSize, cellSize)
		elseif contact.kind == "ping" then
			local arm = PING_MARK * cellSize
			love.graphics.setColor(r, g, b, fade)
			love.graphics.line(px - arm, py, px + arm, py)
			love.graphics.line(px, py - arm, px, py + arm)
		elseif contact.kind == "blast" then
			love.graphics.setColor(r, g, b, fade)
			love.graphics.circle("line", px, py, BLAST_RING * cellSize, 32)
			love.graphics.circle("fill", px, py, cellSize)
		else
			local alpha = loudness(contact.level) * fade
			love.graphics.setColor(r, g, b, alpha * GLOW_ALPHA)
			love.graphics.rectangle("fill", px - glow / 2, py - glow / 2, glow, glow)
			love.graphics.setColor(r, g, b, alpha * 0.6)
			love.graphics.rectangle("fill", px - cellSize / 2, py - cellSize / 2, cellSize, cellSize)
		end
	end

	-- Own ship: the observer knows where it is listening from.
	love.graphics.setColor(OWN_SHIP)
	love.graphics.circle("line", (perception.x - 0.5) * cellSize, (perception.y - 0.5) * cellSize, cellSize * 2)
	love.graphics.setColor(1, 1, 1, 1)
end

return SonarView
