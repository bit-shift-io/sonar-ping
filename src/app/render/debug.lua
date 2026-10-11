-- The debug view: draws true state -- the level's rock, the hull cells of
-- every sub and torpedo, each torpedo's true path (run so far, and on to
-- where its fuse runs out), recent blasts and each active ping's wavefront
-- -- over the sonar view, in colours that contrast with the green
-- phosphor. It is the only renderer allowed to read true state (docs/adr/0002).
-- Draws in world pixels; the caller applies the screen fit. No `love.*` at
-- load time.
local Terrain = require("src.app.render.terrain")
local Ping = require("src.perception.ping")
local Bodies = require("src.sim.bodies")

local Debug = {}

local COLOURS = {
	player = { 0.3, 0.7, 1.0, 0.85 },
	enemy = { 1.0, 0.25, 0.4, 0.85 },
}
local WAVEFRONT = { 1.0, 0.3, 1.0, 0.8 }
local TORPEDO = { 1.0, 1.0, 0.2, 0.95 }
local TORPEDO_AHEAD = { 1.0, 1.0, 0.2, 0.35 }
local BLAST = { 1.0, 1.0, 1.0, 0.9 }
local BLAST_SHOW_TICKS = 120 -- how long a blast's radius stays drawn

local function drawTorpedoes(ctx)
	local size, dt = ctx.grid.cellSize, ctx.config.dt
	for _, torpedo in ipairs(ctx.pools.torpedoes) do
		local body = Bodies.get(ctx.bodies, torpedo.bodyId)
		if body then
			love.graphics.setColor(TORPEDO)
			for _, c in ipairs(torpedo.hull.cells) do
				love.graphics.rectangle("fill", (c.cx - 1) * size, (c.cy - 1) * size, size, size)
			end
			love.graphics.line(torpedo.startX, torpedo.startY, body.x, body.y)
			local left = torpedo.fuse - (ctx.tick - torpedo.launchTick)
			love.graphics.setColor(TORPEDO_AHEAD)
			love.graphics.line(body.x, body.y, body.x + body.vx * dt * left, body.y + body.vy * dt * left)
		end
	end
	love.graphics.setColor(BLAST)
	for _, blast in ipairs(ctx.blasts) do
		if ctx.tick - blast.tick <= BLAST_SHOW_TICKS then
			love.graphics.circle("line", blast.x, blast.y, ctx.config.torpedo.blastRadius, 48)
		end
	end
end

function Debug.draw(ctx)
	Terrain.draw(ctx.grid)
	local size = ctx.grid.cellSize
	for _, sub in ipairs(ctx.pools.subs) do
		love.graphics.setColor(COLOURS[sub.slot] or { 1, 1, 1, 0.85 })
		for _, c in ipairs(sub.hull.cells) do
			love.graphics.rectangle("fill", (c.cx - 1) * size, (c.cy - 1) * size, size, size)
		end
	end
	drawTorpedoes(ctx)
	-- Wavefronts: radius c x (now - pingTick) cells around the origin (cell
	-- units, centres at integers).
	love.graphics.setColor(WAVEFRONT)
	for _, ping in ipairs(ctx.pings) do
		local radius = Ping.radius(ping, ctx.tick, ctx.sound.c) * size
		love.graphics.circle("line", (ping.x - 0.5) * size, (ping.y - 0.5) * size, radius, 128)
	end
	love.graphics.setColor(1, 1, 1, 1)
end

return Debug
