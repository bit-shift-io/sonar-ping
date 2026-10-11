-- Hand-made v1 map, in world pixels (1280 x 720, y down, surface at y = 0):
-- a gently sloping shelf, a ridge near x = 440 and a trench near x = 920.
-- The seabed is a polyline; everything below it is rock, everything above is water.
-- Subs start in open water: the player on the west shelf heading east, the
-- enemy past the trench heading west (the AI takes over from turn 1).
-- `extraEnemies` are where enemies after the first start
-- (config.match.enemies > 1), in order: open water east of the ridge.
return {
	subs = {
		player = { x = 120, y = 300, order = { kind = "course", heading = "east", dive = 0, speed = 20 } },
		enemy = { x = 1160, y = 400, order = { kind = "course", heading = "west", dive = 0, speed = 20 } },
	},
	extraEnemies = {
		{ x = 1040, y = 220, order = { kind = "course", heading = "west", dive = 0, speed = 20 } },
		{ x = 860, y = 320, order = { kind = "course", heading = "west", dive = 0, speed = 20 } },
	},
	seabed = {
		{ x = 0, y = 540 },
		{ x = 200, y = 560 },
		{ x = 360, y = 540 },
		{ x = 440, y = 380 },
		{ x = 520, y = 540 },
		{ x = 700, y = 570 },
		{ x = 840, y = 600 },
		{ x = 880, y = 690 },
		{ x = 960, y = 690 },
		{ x = 1000, y = 600 },
		{ x = 1120, y = 580 },
		{ x = 1280, y = 560 },
	},
}
