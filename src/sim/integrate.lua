-- Moves every live body by its velocities for one fixed step. Records the
-- pose it started from (`prevX/prevY/prevAngle`) so Collide can undo a move
-- that ends inside rock. Pure; no `love.*`.
local Integrate = {}

function Integrate.step(store, dt)
	for slot = 1, store.slotCount do
		local body = store.slots[slot]
		if body and not body.dead then
			body.prevX, body.prevY, body.prevAngle = body.x, body.y, body.angle
			body.x = body.x + body.vx * dt
			body.y = body.y + body.vy * dt
			body.angle = body.angle + body.angVel * dt
		end
	end
end

return Integrate
