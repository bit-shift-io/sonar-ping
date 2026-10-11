-- The match-end screen: the outcome for the viewing slot over the sonar view,
-- and how to start a new match. Reads only the match result (a game-rule
-- outcome, `ctx.result`), never positions. Draws in world px; the caller
-- applies the screen fit. No `love.*` at load time.
local MatchEnd = {}

MatchEnd.RESTART_KEY = "r"

local PHOSPHOR = { 0.6, 1.0, 0.6, 1 }
local SHADE = { 0.0, 0.06, 0.03, 0.85 }
local BOX = { x = 440, y = 260, w = 400, h = 200 }
local TITLE_SCALE = 4

-- "VICTORY", "DEFEAT" or "DRAW" for `slot`, given `result` ({ winner, draw }).
function MatchEnd.headline(result, slot)
	if result.draw then
		return "DRAW"
	end
	return result.winner == slot and "VICTORY" or "DEFEAT"
end

function MatchEnd.draw(result, slot)
	love.graphics.setColor(SHADE)
	love.graphics.rectangle("fill", BOX.x, BOX.y, BOX.w, BOX.h)
	love.graphics.setColor(PHOSPHOR)
	love.graphics.rectangle("line", BOX.x, BOX.y, BOX.w, BOX.h)
	local font = love.graphics.getFont()
	local title = MatchEnd.headline(result, slot)
	local tw = font:getWidth(title) * TITLE_SCALE
	love.graphics.print(title, BOX.x + (BOX.w - tw) / 2, BOX.y + 40, 0, TITLE_SCALE, TITLE_SCALE)
	local hint = "PRESS " .. MatchEnd.RESTART_KEY:upper() .. " FOR A NEW MATCH"
	love.graphics.print(hint, BOX.x + (BOX.w - font:getWidth(hint)) / 2, BOX.y + 140)
	love.graphics.setColor(1, 1, 1, 1)
end

return MatchEnd
