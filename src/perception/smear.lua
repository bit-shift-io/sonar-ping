-- Passive range smear (docs/CONTEXT.md "Smear"): an offset along the bearing
-- line, uniform in [-fraction, +fraction) x distance. Deterministic per
-- emission: a hash of the seed, emit tick and cell, so every run (and every
-- observer) draws the same unit value for the same emission. Pure; no
-- `love.*`, no math.random.
local Smear = {}

local MODULUS = 4294967296 -- 2^32
local MULTIPLIER = 1664525
local INCREMENT = 1013904223

-- One LCG step folding in `value`. All products stay below 2^53, so the
-- arithmetic is exact in doubles.
local function mix(h, value)
	return (h * MULTIPLIER + value % MODULUS + INCREMENT) % MODULUS
end

-- A value in [0, 1) fixed by (seed, tick, cx, cy).
function Smear.unit(seed, tick, cx, cy)
	local h = mix(mix(mix(mix(0, seed), tick), cx), cy)
	h = mix(mix(h, 0), 0)
	return h / MODULUS
end

-- Range offset in cells for an emission heard `distance` cells away.
function Smear.offset(seed, tick, cx, cy, distance, fraction)
	return (Smear.unit(seed, tick, cx, cy) * 2 - 1) * fraction * distance
end

return Smear
