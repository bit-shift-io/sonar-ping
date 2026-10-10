---
name: love-11-and-12-compat
description: The game must run on both LÖVE 11.5 and LÖVE 12; route version-sensitive calls through src/app/compat.lua
metadata:
  type: project
---

Same constraint as GRAV//TY: must run unmodified on LÖVE 11.5 and 12.

**Why:** The developers test on different LÖVE versions.

**How to apply:**
- Put every version-sensitive call in `src/app/compat.lua`, branching on `love.getVersion()`.
- Guard `conf.lua` with `t.graphics = t.graphics or {}`.
- Avoid stencils. Prefer lines, rectangles, points, a single canvas, and simple shaders.
- Gravity's `docs/memory/love-11-and-12-compat.md` lists the known differences.
