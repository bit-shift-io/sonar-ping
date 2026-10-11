-- A torpedo tube (docs/CONTEXT.md "Tube"): fires when loaded, then reloads
-- for config.tubes.reloadTicks ticks.
local Tube = require("src.game.components.tube")
local Config = require("src.game.config")

test("a new tube is loaded", function()
	assertTrue(Tube.ready(Tube.new()))
end)

test("firing a loaded tube empties it for the reload time", function()
	local tube = Tube.new()

	assertTrue(Tube.fire(tube, Config))

	assertFalse(Tube.ready(tube))
	assertEqual(Config.tubes.reloadTicks, tube.reload)
end)

test("a tube cannot fire while reloading", function()
	local tube = Tube.new()
	Tube.fire(tube, Config)
	Tube.tick(tube)

	assertFalse(Tube.fire(tube, Config))
	assertEqual(Config.tubes.reloadTicks - 1, tube.reload, "a failed fire does not restart the reload")
end)

test("a tube is loaded again after reloadTicks ticks", function()
	local tube = Tube.new()
	Tube.fire(tube, Config)

	for _ = 1, Config.tubes.reloadTicks - 1 do
		Tube.tick(tube)
	end
	assertFalse(Tube.ready(tube), "one tick short")
	Tube.tick(tube)

	assertTrue(Tube.ready(tube))
	Tube.tick(tube)
	assertEqual(0, tube.reload, "a loaded tube stays at zero")
end)
