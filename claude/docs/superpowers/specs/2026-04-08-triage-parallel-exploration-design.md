# Triage Skill: Parallel Exploration Design

## Summary

Redesign Phase 2 (Context Exploration) of the `/triage` skill to execute explorations in parallel via sub-agents, with a confirmation gate before analysis.

## Motivation

Insights analysis (384 sessions, 2026-02-26 to 2026-04-08) identified two friction points:

1. **Sequential exploration is slow** — Complex bugs take 4+ hours because explorations (Slack threads, codebase, Linear tickets, etc.) run one at a time
2. **Slack thread misidentification** — During Phase 2, related thread searches pick up wrong threads and proceed without verification, causing wasted iteration

## Scope

- **Changed:** Phase 2 (Context Exploration) internal structure only
- **Unchanged:** Phase 1 (Data Collection), Phase 3 (Analysis), Phase 4 (Linear Registration), startup section, error handling table, existing Red Flags rules

Phase 2's external interface (input from Phase 1, output to Phase 3) remains identical. Phase 3 sees no difference.

## Design

### Current Phase 2

```
Phase 2: Context Exploration
  1. Analyze Phase 1 data, propose exploration candidates
  2. User approves (none / all / numbers)
  3. Execute approved explorations SEQUENTIALLY
  4. Pass accumulated results to Phase 3
```

### New Phase 2 (3 sub-steps)

```
Phase 2a: Exploration Planning
Phase 2b: Parallel Execution
Phase 2c: Findings Confirmation
```

### Phase 2a: Exploration Planning

No change from current behavior.

- LLM analyzes Phase 1 data and proposes exploration candidates
- Proposal format unchanged (numbered list with [recommended] / [optional] tags)
- User input unchanged: `none` / `all` / comma-separated numbers
- `none` → skip Phase 2b/2c, pass Phase 1 data only to Phase 3

### Phase 2b: Parallel Execution

Each approved exploration is dispatched as an independent Agent in parallel.

**Agent construction:**
- 1 approved exploration = 1 Agent
- Each agent receives:
  - Phase 1 collected data (shared context)
  - Specific exploration instruction (e.g., "Search Linear for similar tickets related to [topic]")
  - Tool specification (e.g., slackcli, Grep, linear CLI)
- No upper limit on agent count (count = number of user-approved explorations)

**Agent responsibility:**
- Execute the assigned single exploration and return results
- Do nothing else
- On failure: return "could not retrieve" (consistent with current error handling — skip and continue)

**Orchestrator responsibility:**
- Wait for all agents to complete
- Integrate and summarize results from all agents
- Do NOT forward raw agent output to Phase 3 (per multi-agent discipline in CLAUDE.md)

### Phase 2c: Findings Confirmation

Present all exploration results for user verification before proceeding to analysis.

**Presentation format:**

```
## Exploration Results Summary

### 1. [Exploration name, e.g., "Slack related thread search"]
- Source: [URL or search query]
- Summary: [2-3 line summary]
- Relevance: High / Medium / Low

### 2. [Exploration name, e.g., "Linear existing ticket search"]
- Source: ...
- Summary: ...
- Relevance: ...

---
Proceed to analysis with these findings? (Provide corrections if needed)
```

**Accepted input:**
- Approval → proceed to Phase 3
- Correction (e.g., "Thread #1 is wrong, the correct one is yesterday's thread in #channel") → re-execute only the specified exploration, then re-present confirmation gate
- `none` → discard all exploration results, proceed to Phase 3 with Phase 1 data only

**Re-execution rules:**
- Only the corrected exploration is re-executed (other results are preserved)
- Re-execution is single (not parallel — it's one exploration fix)
- After re-execution, the full confirmation gate is re-presented

## Red Flags Addition

Add to the existing Red Flags "Never" list:

- Forward raw agent output to Phase 3 without orchestrator synthesis

## Error Handling

No changes to the error handling table. The existing row applies:

| Phase | Error | Response |
|-------|-------|----------|
| 2 | Exploration tool fails | Skip that exploration, continue with collected data |

In the parallel model, individual agent failures are isolated. Other agents' results are unaffected.

## Non-Goals

- Multi-input support (Sentry URLs, error logs, screenshots as first-class inputs)
- Multi-output support (Slack reply drafting, GitHub Issue creation)
- Phase 5 addition (Slack response)
- Changes to Phase 1, 3, or 4

These can be layered on top of this design in future iterations.
