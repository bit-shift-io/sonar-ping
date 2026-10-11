-- Deterministic seeded RNG (docs/ARCHITECTURE.md names src/core/ as owning
-- "seeded RNG"; this is the first module to need it, slice 09). A simple
-- LCG (Numerical Recipes constants) rather than math.random -- LuaJIT gives
-- no cross-platform guarantee for math.random's algorithm, so the same seed
-- could produce a different sequence on a different machine or process.
-- This module's sequence is fully determined by its own arithmetic, so
-- "same seed -> same sequence" holds everywhere (this slice's acceptance
-- criterion). Pure -- no `love.*` (docs/ARCHITECTURE.md "Layers").
local Rng = {}

-- Numerical Recipes' 32-bit LCG constants.
local MULTIPLIER = 1664525
local INCREMENT = 1013904223
local MODULUS = 4294967296 -- 2^32

-- Returns a new generator seeded with `seed` (any number; non-integers and
-- negatives are folded into range via modulus). Two generators created with
-- the same seed produce exactly the same sequence of `next()`/`range()`
-- calls, in this process or any other.
function Rng.new(seed)
	seed = math.floor(tonumber(seed) or 0)
	local state = seed % MODULUS
	if state < 0 then
		state = state + MODULUS
	end

	local rng = { state = state }

	-- Advances the generator and returns a float in [0, 1).
	function rng:next()
		self.state = (self.state * MULTIPLIER + INCREMENT) % MODULUS
		return self.state / MODULUS
	end

	-- A float uniformly distributed in [min, max).
	function rng:range(min, max)
		return min + self:next() * (max - min)
	end

	-- An integer uniformly distributed in [min, max] (inclusive both ends).
	function rng:int(min, max)
		return math.floor(self:range(min, max + 1))
	end

	return rng
end

return Rng
