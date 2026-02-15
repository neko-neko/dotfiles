# Intent Guard Design

## Problem

Claude Code usage data analysis identified 25 `wrong_approach` incidents as the largest friction source. Root causes:

- Claude silently pivots from the invoked skill to a different one (e.g., brainstorming -> handover)
- Subagents are spawned with haiku model without user consent, degrading quality
- Multi-step tasks are executed without a planning phase, leading to cascading errors

## Solution

Add an `## Intent Guard` section to `~/.claude/CLAUDE.md` with 3 rules:

1. **Skill pivot prohibition** - Execute only the invoked skill. Switching requires explicit user approval.
2. **Model inheritance** - Omit `model` parameter for subagents unless user explicitly specifies one. This inherits the parent model by default.
3. **Planning requirement** - Tasks with 3+ steps must go through a planning phase (brainstorming / writing-plans / EnterPlanMode) before execution.

## Approach

- Implementation: CLAUDE.md rule addition (not a skill)
- Placement: After `## Multi-agent` section, before `## Session Management`
- Size: 4 lines (1 header + 3 rules)
- CLAUDE.md grows from 53 to 57 lines

## Design Decisions

- "Approach declaration before execution" was excluded — already covered by existing rule "do not guess on ambiguous instructions, ask specifically"
- Planning threshold set at 3 steps to avoid overhead for trivial tasks (typo fixes, single-function changes)
- Model rule uses "omit parameter" rather than "set to inherit" since omission causes natural inheritance in Task tool

## Content

```markdown
## Intent Guard

 - Skill invocation: execute only the invoked skill. No implicit pivoting. If switching is needed, ask user for approval
 - Subagent model: only set model parameter when user explicitly specifies. Otherwise omit (inherits parent model)
 - Planning gate: multi-step tasks (3+ steps) must go through planning (brainstorming / writing-plans / EnterPlanMode) before execution. No skipping
```

## Expected Impact

- Directly reduces `wrong_approach` incidents (25 -> target <5)
- Prevents quality degradation from unintended haiku downgrades
- Catches cascading failures earlier through mandatory planning
