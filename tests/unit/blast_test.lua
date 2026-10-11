-- Blast radius (docs/CONTEXT.md): a sub with any hull cell within
-- config.torpedo.blastRadius of the detonation sinks. One hit sinks.
local Match = require("src.game.match")
local Config = require("src.game.config")
local Blast = require("src.game.blast")

-- Two stopped subs, 800 px apart, level and heading east/west: hulls run
-- x = 184..216 (player) and 984..1016 (enemy) at y = 300.
local LEVEL = {
	seabed = { { x = 0, y = 600 }, { x = 1280, y = 600 } },
	subs = {
		player = { x = 200, y = 300, order = { kind = "course", heading = "east", dive = 0, speed = "stop" } },
		enemy = { x = 1000, y = 300, order = { kind = "course", heading = "west", dive = 0, speed = "stop" } },
	},
}

local function subs(ctx)
	return ctx.pools.subs[1], ctx.pools.subs[2]
end

test("a blast sinks a sub inside the radius and spares one outside it", function()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })
	local player, enemy = subs(ctx)

	-- Half the radius off the enemy's westmost hull cell centre (x = 986).
	Blast.detonate(ctx, 986 - Config.torpedo.blastRadius / 2, 300)

	assertTrue(enemy.dead, "half a radius off the enemy's bow")
	assertFalse(player.dead, "the player is 740 px away")
end)

test("a sub just beyond the blast radius is spared", function()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })
	local _, enemy = subs(ctx)
	-- The enemy's westmost hull cell centre is at x = 986.
	Blast.detonate(ctx, 986 - Config.torpedo.blastRadius - 1, 300)

	assertFalse(enemy.dead)
end)

test("the radius is measured to the nearest hull cell, not the sub's centre", function()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })
	local _, enemy = subs(ctx)
	-- Inside the radius of the nearest hull cell (x = 986), but 10 px beyond
	-- it measured from the enemy's centre (x = 1000).
	Blast.detonate(ctx, 986 - (Config.torpedo.blastRadius - 4), 300)

	assertTrue(enemy.dead)
end)

test("a blast sinks every sub inside it", function()
	local close = {
		seabed = LEVEL.seabed,
		subs = {
			player = LEVEL.subs.player,
			enemy = { x = 260, y = 300, order = LEVEL.subs.enemy.order },
		},
	}
	local ctx = Match.new(close, Config, 1, { ai = false })
	local player, enemy = subs(ctx)

	Blast.detonate(ctx, 230, 300)

	assertTrue(player.dead)
	assertTrue(enemy.dead)
end)
