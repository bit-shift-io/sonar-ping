---
name: register-new-test-files
description: New test files must be added to the run lists in tests/unit/run.lua and tests/integration/run.lua
metadata:
  type: convention
---

**Why:** The runners (ported from gravity) execute a fixed list, not a glob. An unregistered test never runs and never fails.

**How to apply:** When creating a `*_test.lua` under `tests/unit/` or `tests/integration/`, add it to that tier's `run.lua` list in the same change and confirm the test count rose. e2e files are discovered automatically.
