-- Contact tracking for the AI, from perceived positions only. A contact is
-- where something WAS when its sound left it, heard distance / c ticks later;
-- a sample dates it back to that emit tick. A track is a weighted
-- least-squares straight-line course through samples. Cell units and ticks.
-- Pure; no `love.*`.
local Track = {}

-- `contact` ({ x, y, arrivalTick }) heard by an observer at (ox, oy) with
-- sound at `c` cells per tick: `{ x, y, t }`, t its emit tick.
function Track.sample(contact, ox, oy, c)
	local dx, dy = contact.x - ox, contact.y - oy
	return { x = contact.x, y = contact.y, t = contact.arrivalTick - math.sqrt(dx * dx + dy * dy) / c }
end

-- Fits `samples` ({ x, y, t, w? }, w defaults to 1) with a constant-velocity
-- course. Returns `{ x, y, t, vx, vy }`: the fitted position at the newest
-- sample's tick `t` and the velocity per tick (0 when every sample has the
-- same tick). Nil for no samples.
function Track.fit(samples)
	if #samples == 0 then
		return nil
	end
	local sw, st, sx, sy, latest = 0, 0, 0, 0, -math.huge
	for _, s in ipairs(samples) do
		local w = s.w or 1
		sw, st, sx, sy = sw + w, st + w * s.t, sx + w * s.x, sy + w * s.y
		latest = math.max(latest, s.t)
	end
	local mt, mx, my = st / sw, sx / sw, sy / sw
	local stt, stx, sty = 0, 0, 0
	for _, s in ipairs(samples) do
		local w, dt = s.w or 1, s.t - mt
		stt, stx, sty = stt + w * dt * dt, stx + w * dt * (s.x - mx), sty + w * dt * (s.y - my)
	end
	local vx, vy = 0, 0
	if stt > 1e-9 then
		vx, vy = stx / stt, sty / stt
	end
	return { x = mx + vx * (latest - mt), y = my + vy * (latest - mt), t = latest, vx = vx, vy = vy }
end

-- The estimate's position at `tick`, along its course.
function Track.at(estimate, tick)
	local dt = tick - estimate.t
	return estimate.x + estimate.vx * dt, estimate.y + estimate.vy * dt
end

return Track
