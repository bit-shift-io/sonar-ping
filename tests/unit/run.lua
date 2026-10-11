-- Unit test runner: discovers and runs test files with no `love` global and
-- no LÖVE mock. Only src/core, src/sim, src/game may be exercised here (see
-- docs/ARCHITECTURE.md) -- anything touching `love.*` belongs in a higher tier.
local defaultTestFiles = {
	"tests/unit/runner_smoke_test.lua",
	"tests/unit/screen_fit_test.lua",
	"tests/unit/vec2_test.lua",
	"tests/unit/timeline_geometry_test.lua",
	"tests/unit/rng_test.lua",
	"tests/unit/grid_test.lua",
	"tests/unit/level_test.lua",
	"tests/unit/match_test.lua",
	"tests/unit/helm_test.lua",
	"tests/unit/hull_raster_test.lua",
	"tests/unit/collide_test.lua",
	"tests/unit/match_step_test.lua",
	"tests/unit/input_test.lua",
	"tests/unit/turn_test.lua",
	"tests/unit/order_schedule_test.lua",
	"tests/unit/predict_test.lua",
	"tests/unit/course_solve_test.lua",
	"tests/unit/determinism_test.lua",
	"tests/unit/arrival_test.lua",
	"tests/unit/emissions_test.lua",
	"tests/unit/smear_test.lua",
	"tests/unit/perception_test.lua",
	"tests/unit/perception_at_tick_test.lua",
	"tests/unit/ping_test.lua",
	"tests/unit/sonar_view_requires_test.lua",
	"tests/unit/tube_test.lua",
	"tests/unit/torpedo_test.lua",
	"tests/unit/torpedo_aim_test.lua",
	"tests/unit/blast_test.lua",
	"tests/unit/round_rules_test.lua",
	"tests/unit/fire_solution_test.lua",
	"tests/unit/ai_track_test.lua",
	"tests/unit/ai_test.lua",
	"tests/unit/ai_isolation_test.lua",
}

local tests = {}
local failures = {}

local function valueToString(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function fail(message)
	error(message, 2)
end

function test(name, fn)
	table.insert(tests, {
		name = name,
		fn = fn,
	})
end

function assertTrue(value, message)
	if not value then
		fail(message or "expected value to be truthy")
	end
end

function assertFalse(value, message)
	if value then
		fail(message or "expected value to be falsey")
	end
end

function assertEqual(expected, actual, message)
	if expected ~= actual then
		fail(message or string.format("expected %s, got %s", valueToString(expected), valueToString(actual)))
	end
end

function assertNear(expected, actual, tolerance, message)
	tolerance = tolerance or 0.000001
	if math.abs(expected - actual) > tolerance then
		fail(
			message
				or string.format(
					"expected %s to be within %s of %s",
					valueToString(actual),
					valueToString(tolerance),
					valueToString(expected)
				)
		)
	end
end

local function testFilesFromArgs()
	local files = {}
	for i = 1, #arg do
		table.insert(files, arg[i])
	end

	if #files == 0 then
		return defaultTestFiles
	end

	return files
end

local function loadTestFile(path)
	local chunk, err = loadfile(path)
	if not chunk then
		error(string.format("Could not load %s: %s", path, err))
	end
	chunk()
end

local function run()
	local files = testFilesFromArgs()

	for _, file in ipairs(files) do
		loadTestFile(file)
	end

	for _, case in ipairs(tests) do
		local ok, err = xpcall(case.fn, debug.traceback)
		if ok then
			print("✓ " .. case.name)
		else
			table.insert(failures, {
				name = case.name,
				error = err,
			})
			print("✗ " .. case.name)
			print(err)
		end
	end

	local passed = #tests - #failures
	print(string.format("\n%d passed, %d failed", passed, #failures))

	if #failures > 0 then
		os.exit(1)
	end
end

run()
