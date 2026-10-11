function love.conf(t)
	t.graphics = t.graphics or {} -- LÖVE 12 graphics startup options; keeps 11.5 working (docs/memory/love-11-and-12-compat.md)

	t.identity = "sonar-ping"
	t.window.title = "Sonar Ping"
	t.window.width = 1280
	t.window.height = 720
	t.window.resizable = true
	t.window.minwidth = 1
	t.window.minheight = 1
	t.window.vsync = 1
end
