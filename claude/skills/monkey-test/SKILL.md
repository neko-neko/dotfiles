---
name: monkey-test
description: >-
  Replay pre-defined Given/When/Then scenarios via agent-browser. Designed for
  feature-dev Phase 6. Consumes scenarios.yml and produces a human-readable
  report plus machine-readable results.json. Reads design.md, test-strategy.md,
  and plan.md as hints to resolve ambiguity and decide SKIP verdicts.
allowed-tools: Bash(agent-browser:*), Bash(npx agent-browser:*)
user-invocable: true
---

# monkey-test

Scripted E2E regression testing via agent-browser.

## Inputs

- `docs/features/<topic>/scenarios.yml` (required)
- `docs/features/<topic>/design.md` (hint — disambiguates natural-language steps)
- `docs/features/<topic>/test-strategy.md` (hint — severity calibration)
- `docs/features/<topic>/plan.md` (hint — SKIP decision for incomplete tasks)

## Outputs

- `docs/features/<topic>/monkey-test-report.md` — human-readable
- `docs/features/<topic>/monkey-test-results.json` — machine-readable
- `docs/features/<topic>/monkey-test-screenshots/` — step screenshots

## results.json Schema

```json
{
  "scenarios": [
    {
      "id": "string",
      "status": "PASS | FAIL | SKIP",
      "severity": "critical | high | medium | low",
      "duration_ms": 1234,
      "error": "string (FAIL only)",
      "skip_reason": "string (SKIP only)",
      "screenshots": ["docs/features/<topic>/monkey-test-screenshots/<id>-step1.png", "..."]
    }
  ],
  "summary": {
    "total": 10,
    "passed": 8,
    "failed": 1,
    "skipped": 1
  }
}
```

## Execution Flow

1. Read `scenarios.yml`.
2. For each scenario:
   a. Check `plan.md`: if the implementing task is marked incomplete,
      status = `SKIP` with `skip_reason`.
   b. Otherwise launch agent-browser (restore auth-state from
      `docs/features/<topic>/monkey-test-screenshots/auth-state.json` if
      present).
   c. Interpret `given`: set up preconditions (navigate, fixture setup).
      When wording is ambiguous, consult `design.md` definitions.
   d. Interpret `when`: perform actions. Capture a screenshot per action.
   e. Interpret `then`: evaluate assertions. Capture a final screenshot.
   f. Record result. On FAIL, include expected-vs-actual in `error`.
3. Write `results.json` conforming to the schema.
4. Write `monkey-test-report.md` with:
   - Summary (totals)
   - Critical and High FAIL details (expected vs actual, screenshots)
   - Full per-scenario table

## Report Template (report.md)

```markdown
# Monkey Test Report: <feature-name>

## Summary
- Total scenarios: N
- Passed: N
- Failed: N
- Skipped: N
- Duration: XX min

## Critical and High Failures
<per-failure: id, severity, expected vs actual, screenshots>

## Full Results
| id | status | severity | duration_ms | notes |
| ... | ... | ... | ... | ... |
```

## Red Flags

- Never skip writing `results.json` — downstream Phase 7 (dogfood) depends on it.
- Never auto-retry FAIL scenarios silently — report them.
- Never write files outside `docs/features/<topic>/`.
- Never fabricate screenshots — absence of agent-browser output = SKIP with
  a clear `skip_reason` ("agent-browser unavailable").

## Difference from /dogfood

- This skill is **scripted** — replays scenarios to verify known behavior.
- `/dogfood` is **exploratory** — finds new issues without a script.
- Both use agent-browser. Use this when scenarios.yml exists; use dogfood to
  discover issues scenarios.yml cannot foresee.
