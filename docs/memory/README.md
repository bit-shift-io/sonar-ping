# Repo Memory

Situational facts: true only when touching a particular area. One fact per file.

- [port-from-gravity.md](port-from-gravity.md) — scaffold, test tiers and compat layer are ported from `~/Projects/gravity`; what to keep and strip
- [love-11-and-12-compat.md](love-11-and-12-compat.md) — must run on LÖVE 11.5 and 12; version-sensitive calls go through `src/app/compat.lua`
- [register-new-test-files.md](register-new-test-files.md) — unit and integration runners use fixed file lists; register new tests or they never run
