---
name: test-scenarios
description: >-
  Generate a comprehensive test strategy (ISTQB test-design techniques + ISO 25010
  quality characteristics) plus, when `--e2e` is true, an agent-browser-replayable
  scenarios.yml in Given/When/Then YAML. Designed for feature-dev Phase 2. Reads a
  design document and outputs artifacts under docs/features/<topic>/.
user-invocable: true
---

# test-scenarios

Derive test cases and (optionally) executable E2E scenarios from a design doc.

## Args

| Arg | Type | Default | Description |
|---|---|---|---|
| e2e | bool | false | When true, also emit `scenarios.yml` |

## Inputs

1. A design document at `docs/features/<topic>/design.md` (required).
   Honor the sections:
   `Prerequisites`, `Impact Scope`, `Impact Analysis`, `Must-Verify Checklist`,
   `Test Perspectives`.

## Outputs

Always:
- `docs/features/<topic>/test-strategy.md` — human-readable.

When `--e2e`:
- `docs/features/<topic>/scenarios.yml` — machine-readable.

## `test-strategy.md` Required Sections

- **Test Design Techniques** (ISTQB): equivalence partitioning, boundary-value
  analysis, decision tables, state-transition testing. For each technique,
  list ≥ 1 concrete application to this feature.
- **Quality Characteristics** (ISO 25010): functional suitability, performance
  efficiency, compatibility, usability, reliability, security, maintainability,
  portability. For each, state: `Relevance: in-scope | out-of-scope (reason)`.
- **Priority Matrix**: a table mapping each characteristic to criticality
  (`critical | high | medium | low`) for this feature.
- **Non-Functional Requirements**: at least one measurable acceptance
  criterion (e.g., "Login responds in < 500ms p95").
- **Must-Verify Mapping**: a table with one row per item in the design's
  Must-Verify Checklist; each row links to one or more test entries in the
  sections above.

## `scenarios.yml` Schema

```yaml
scenarios:
  - id: <kebab-case>
    category: <string>         # e.g. authentication, payment, ui-navigation
    severity: critical | high | medium | low
    given: <string>            # natural language precondition
    when: <string>             # natural language action
    then: <string>             # natural language expected outcome
    preconditions: [<string>]  # optional, list
    postconditions: [<string>] # optional, list
```

- Generate ≥ 3 scenarios.
- Cover at least one scenario per `category` inferred from Test Perspectives.
- At least one scenario at `severity: critical` for the feature's core success path.
- Severity must track the design's Must-Verify Checklist priority.

## Interaction Model

1. Read `design.md`.
2. Propose the `test-strategy.md` outline to the user; get approval to write.
3. Write `test-strategy.md`.
4. When `--e2e`:
   a. Propose the `scenarios.yml` scenario list (titles + severities);
      get approval.
   b. For each approved scenario, draft the Given/When/Then; confirm per
      scenario.
   c. Write `scenarios.yml`.
5. Commit the outputs.

## Red Flags

- Never mix human-readable prose into `scenarios.yml`. It is machine-oriented.
- Never produce GitHub Issue templates. (That is `/breakdown-test`'s job.)
- Never write files outside `docs/features/<topic>/`.
