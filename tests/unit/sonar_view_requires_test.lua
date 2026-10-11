-- The player render reads perception only (ADR 0002): the sonar view module
-- may require nothing from true state (game, sim) -- only perception.
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

test("the sonar view requires nothing from true state", function()
	for _, name in ipairs(requiresOf("src/app/render/sonar_view.lua")) do
		assertTrue(name:match("^src%.perception%.") ~= nil, "sonar view must not require " .. name)
	end
end)

test("the replay view requires nothing from true state", function()
	for _, name in ipairs(requiresOf("src/app/render/replay.lua")) do
		assertTrue(name:match("^src%.perception%.") ~= nil, "replay view must not require " .. name)
	end
end)

test("the requires scan finds a module's requires", function()
	local found = requiresOf("src/game/match.lua")

	assertEqual("src.game.level", found[1])
end)
