-- Torpedo aim point (planning UI; docs/CONTEXT.md "Aim point"). Turns the
-- point a player drags a launch to into a torpedo order whose run (out of the
-- tube, the turn onto its angle, then straight) detonates there: fast when
-- the fast run reaches the point, else slow. A point the run cannot reach
-- (beyond the slow range, or inside the turning circle) clamps to the
-- nearest point of the run. The solve is Predict.aim. The sim never sees the
-- point, only the order. Pure; no `love.*`.
local Predict = require("src.game.predict")

local TorpedoAim = {}

-- The launch from tube `tube` of a sub at `pose` (`{ x, y, angle }`: its pose
-- at the launch tick) aimed at (tx, ty). Returns `{ order, x, y, dud }`: the
-- torpedo order, the (clamped) point it detonates at, and whether that is
-- inside the arming distance of the launch point (a dud).
function TorpedoAim.solve(world, tube, pose, tx, ty)
	local fast = Predict.aim(world, tube, pose, tx, ty, "fast")
	if fast.reachable then
		return fast
	end
	return Predict.aim(world, tube, pose, tx, ty, "slow")
end

return TorpedoAim
