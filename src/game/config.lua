-- All tuning numbers live here (docs/ARCHITECTURE.md "Rules"). Sections are
-- added by the slice that needs them.
local Config = {
	-- Fixed simulation step in seconds; turn time is counted in ticks.
	dt = 1 / 60,

	-- Camera (src/app/camera): zoom range and the factor one wheel notch
	-- multiplies the zoom by.
	camera = {
		minZoom = 1,
		maxZoom = 4,
		wheelStep = 1.15,
	},

	-- World grid (docs/CONTEXT.md "Cell"): 320 x 180 cells of 4 px is the
	-- 1280 x 720 virtual screen.
	grid = {
		cellSize = 4,
		width = 320,
		height = 180,
	},

	-- Hull of a sub in world px: a rectangle `length` along its heading and
	-- `beam` across. `turnRate` is radians per tick; `maxDive` the steepest
	-- dive/climb angle an order may ask for.
	sub = {
		length = 32,
		beam = 8,
		turnRate = 0.02,
		maxDive = math.rad(30),
	},

	-- Speed anchors: px per second, and the noise level a sub at that speed
	-- broadcasts. A course order may ask for any speed from stop to full;
	-- noise between two anchors is interpolated linearly.
	speeds = {
		stop = { speed = 0, noise = 0 },
		slow = { speed = 20, noise = 1 },
		half = { speed = 45, noise = 2 },
		full = { speed = 80, noise = 4 },
	},

	-- Course solver (src/game/course_solve, planning UI only): `dives`
	-- evenly spaced dive angles per heading from -maxDive to maxDive, each
	-- projected at stop and full speed when a drag starts; an interval whose
	-- midpoint ends further than `splitTolerance` px from the interpolated
	-- end is halved, at most `splitDepth` times. `subSteps` interpolation
	-- steps between neighbouring samples. A solved course whose real end is
	-- more than `tolerance` px from the interpolated one (rock in the way) is
	-- refined with `refineSteps` golden-section steps over speed. A target
	-- within `stopRadius` px of where the sub is at the order's tick plans a
	-- stop.
	courseSolve = {
		dives = 5,
		splitTolerance = 2,
		splitDepth = 6,
		subSteps = 8,
		tolerance = 1,
		refineSteps = 6,
		stopRadius = 16,
	},

	-- Match setup: `enemies` enemy subs (slots "enemy", "enemy2", ...), each
	-- filled by the AI.
	match = {
		enemies = 1,
	},

	-- Turn: the execute phase runs `ticks` fixed steps (300 = 5 s).
	turn = {
		ticks = 300,
	},

	-- Passive perception (docs/CONTEXT.md "Perception", ADR 0002).
	-- `soundSpeed` px/s: 240 is one cell per tick, so sound crosses the
	-- 1280 px map in ~5.3 s and its diagonal in ~6.1 s. `noisyAft` is the
	-- fraction of a hull's length, from the stern, holding the propeller and
	-- engine (the cells that emit noise). `smear` is the passive range smear
	-- half-width as a fraction of distance. A contact is forgotten once it is
	-- `fadeTicks` old. Ping echoes and ping origins are forgotten once
	-- `echoFadeTicks` old (longer, so a ping's seabed outline builds up as
	-- its echoes return).
	perception = {
		soundSpeed = 240,
		noisyAft = 0.5,
		smear = 0.08,
		fadeTicks = 240,
		echoFadeTicks = 600,
	},

	-- Torpedo tubes: `count` per sub; a tube that fires is empty for
	-- `reloadTicks` ticks of execute phase (1200 = 20 s). `facing[i]` is the
	-- direction tube i points, relative to the sub's heading: tube 1 the bow
	-- (0), tube 2 the stern (pi). A torpedo leaves from that end of the hull.
	tubes = {
		count = 2,
		reloadTicks = 1200,
		facing = { 0, math.pi },
	},

	-- Torpedoes (docs/CONTEXT.md "Torpedo"): unguided, they leave the tube
	-- along the sub's axis, turn at `turnRate` radians per tick onto the
	-- order's angle (turning radius: 40 px slow, ~67 px fast), then run
	-- straight. Hull in world px (`length` along the run,
	-- `beam` across). `speeds` are the settings a launch order may pick: px/s
	-- and the running noise level; `maxRun` is the longest fuse in ticks the
	-- speed allows (fast runs shorter: its range is half the slow range);
	-- `defaultFuse` is what the plan screen offers first. `aimSteps` is how
	-- many fixed-point steps src/game/torpedo_aim takes to solve the angle
	-- that turns a run onto an aim point. A torpedo arms once
	-- it is `armDistance` px from its launch point; before that it ignores
	-- hulls and a fuse or rock contact makes it a dud (no blast), so the
	-- firing sub is never inside its blast. `blastRadius` px from the
	-- detonation point to the nearest hull cell centre sinks a sub.
	-- `launchNoise` and `blastNoise` are the levels of the one-off launch and
	-- detonation emissions.
	torpedo = {
		length = 16,
		beam = 6,
		speeds = {
			slow = { speed = 120, noise = 3, maxRun = 540 },
			fast = { speed = 200, noise = 5, maxRun = 160 },
		},
		turnRate = 0.05,
		aimSteps = 12,
		defaultFuse = 300,
		armDistance = 64,
		blastRadius = 20,
		launchNoise = 6,
		blastNoise = 10,
	},

	-- The AI (src/game/ai/): distances in cells, times in ticks. A contact
	-- within `selfRadius` of the AI when it arrives is its own noise, ping or
	-- echo; one within `ownTorpedoRadius` (plus the smear) of the run of one
	-- of its own torpedoes is that torpedo. Ping and hull-echo samples weigh
	-- `exactWeight` noise samples in the course fit, which uses the samples
	-- emitted within `trackWindow` ticks of the newest, and none once that is
	-- older than `trackMaxAge`. With no sample newer than `staleTicks` the AI
	-- pings (at most once per `staleTicks`). A tracked contact draws a course
	-- at `closeSpeed` towards where it will be `leadTicks` ahead (a fitted
	-- course is run on at most `extrapolateTicks` past its newest sample),
	-- and a shot (first loaded tube, at turn tick 1) when the newest sample
	-- is at most `fireMaxAge` old and the intercept is at least `armMargin`
	-- px beyond the arming distance: fast if it is within the fast max run,
	-- else slow if within the slow max run, else it holds fire. A noise contact at the launch level or louder makes it
	-- evade at `evadeSpeed`, away from the launch and diving or climbing hard,
	-- for `evadeTicks`, then level out at `quietSpeed`. A first course (the
	-- standing one too) that would run the sub into rock within `steerTicks`
	-- is swapped for level, the mirrored dive or level the other way,
	-- whichever stays clear longest; if what it keeps would run aground
	-- before the turn ends, it stops `groundMargin` ticks short of the rock.
	-- Lying stopped with nothing to hunt, it searches at `quietSpeed`.
	-- `closeSpeed`, `evadeSpeed` and `quietSpeed` name `speeds` anchors.
	ai = {
		selfRadius = 8,
		ownTorpedoRadius = 4,
		exactWeight = 8,
		trackWindow = 360,
		trackMaxAge = 1440,
		staleTicks = 720,
		leadTicks = 120,
		extrapolateTicks = 240,
		closeSpeed = "half",
		fireMaxAge = 480,
		armMargin = 16,
		evadeSpeed = "full",
		evadeTicks = 240,
		quietSpeed = "slow",
		steerTicks = 240,
		groundMargin = 40,
	},
}

return Config
