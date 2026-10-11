-- The AI decides from its own perception only (ADR 0002): it is handed a
-- restricted view of the match -- its own perception, its own ship, the static
-- map, config and the clock -- and never reaches true state.
local Match = require("src.game.match")
local Config = require("src.game.config")
local Turn = require("src.game.turn")
local Orders = require("src.game.orders")
local Ai = require("src.game.ai.ai")

local AI_MODULES = { "src/game/ai/ai.lua", "src/game/ai/track.lua", "src/game/ai/fire_solution.lua" }

-- Modules that hold no true state of anything but the AI's own ship: core
-- helpers, the static grid, order shapes, own-ship projection (Predict reads
-- only the `config` and `grid` it is handed) and the AI's own modules.
local ALLOWED = { "^src%.core%.", "^src%.sim%.grid$", "^src%.game%.orders$", "^src%.game%.predict$", "^src%.game%.ai%." }

local LEVEL = {
	seabed = { { x = 0, y = 600 }, { x = 1280, y = 600 } },
	subs = {
		player = { x = 360, y = 300, order = Orders.course("east", 0, "slow") },
		enemy = { x = 600, y = 300, order = Orders.course("west", 0, "stop") },
	},
}

local function requiresOf(path)
	local file = assert(io.open(path, "r"))
	local source = file:read("*a")
	file:close()
	local found = {}
	for name in source:gmatch("require%s*%(?%s*[\"']([^\"']+)[\"']") do
		found[#found + 1] = name
	end
	return found
end

local function allowed(name)
	for _, pattern in ipairs(ALLOWED) do
		if name:match(pattern) then
			return true
		end
	end
	return false
end

local function keys(t)
	local list = {}
	for k in pairs(t) do
		list[#list + 1] = k
	end
	table.sort(list)
	return table.concat(list, ",")
end

-- A table that errors on reading any key `t` does not have.
local function strict(t)
	return setmetatable({}, {
		__index = function(_, k)
			local v = t[k]
			if v == nil then
				error("the AI read a field the view does not offer: " .. tostring(k), 2)
			end
			return v
		end,
	})
end

-- A match one turn in, with the enemy's view as the AI gets it.
local function viewAfterOneTurn()
	local ctx = Match.new(LEVEL, Config, 1, { ai = false })
	Turn.submit(ctx, "player", {})
	Turn.submit(ctx, "enemy", {})
	while Match.step(ctx) do
	end
	return Match.aiView(ctx, ctx.pools.subs[2]), ctx
end

test("the AI modules require nothing that holds true state", function()
	for _, path in ipairs(AI_MODULES) do
		for _, name in ipairs(requiresOf(path)) do
			assertTrue(allowed(name), path .. " must not require " .. name)
		end
	end
end)

test("the view the AI gets holds only its perception, its own ship, the map, config and the clock", function()
	local view, ctx = viewAfterOneTurn()

	assertEqual("config,grid,own,perception,tick,turnLength", keys(view))
	assertEqual("body,helm,tubes,x,y", keys(view.own))
	assertEqual(ctx.pools.subs[2].perception, view.perception, "the enemy's own perception")
	assertTrue(view.own.tubes[1] ~= ctx.pools.subs[2].tubes[1], "own tubes are copies")
end)

test("the AI plans and listens through the view alone, changing nothing in it", function()
	local view = viewAfterOneTurn()
	local contacts = #view.perception.contacts
	local guarded = strict(view)
	rawset(guarded, "own", strict(view.own))
	local brain = Ai.new(1)

	Ai.listen(brain, guarded)
	local entries = Ai.plan(brain, guarded)

	assertTrue(#entries > 0, "fixture: the AI heard the player and acts")
	for _, entry in ipairs(entries) do
		assertTrue(Orders.validate(entry.order, Config), "the AI acts only through valid orders")
	end
	assertEqual(contacts, #view.perception.contacts)
end)
