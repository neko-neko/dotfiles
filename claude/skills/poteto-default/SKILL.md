---
name: poteto-default
description: Default working mode for development tasks on this machine. Use at the start of any coding, debugging, refactoring, design, or codebase-investigation task to load pstack's poteto-mode together with the local Owner-Auditor safety precedence. Also use for "poteto", "/poteto-mode", "pstack", or a request to work in poteto's style. Not for casual questions, chat, or non-development work.
---

# Poteto default

Local entry point for pstack v0.14.8's `poteto-mode` on this machine. It exists because poteto-mode ships Cursor-specific assumptions and an Autonomy section that conflicts with the Owner-Auditor safety gates. Load this, then poteto-mode, and apply the precedence below.

## 1. Load poteto-mode by path, not by skill invocation

43 of pstack's 44 installed skills carry `disable-model-invocation: true`. In Claude Code that makes them unreachable through the Skill tool; only a human typing `/name` can invoke them. So navigate pstack by **reading files**, not by invoking skills. Nothing in poteto-mode's routing works otherwise.

Read this in full, including its inline Principles index, before writing a todolist:

`~/.agents/skills/poteto-mode/SKILL.md`

Everything it names resolves under `~/.agents/skills/`:

- Playbooks: `~/.agents/skills/poteto-mode/playbooks/<name>.md` (23 of them)
- References: `~/.agents/skills/poteto-mode/references/bugbot-triage.md`
- A leaf principle: `~/.agents/skills/principle-<name>/SKILL.md`
- A routed workflow skill (`how`, `why`, `architect`, `arena`, `swarm`, `interrogate`, `reflect`, `unslop`, `technical-writing`, `figure-it-out`, `no-comments`, `show-me-your-work`, and the rest): `~/.agents/skills/<name>/SKILL.md`

When poteto-mode says "the **how** skill" or "read the leaf skill in full", read that path. Cite it the same way you would a skill you invoked.

The one pstack skill the model *can* invoke is `setup-pstack`, and it is the one that must never run. See the precedence below.

## 2. Local precedence, which outranks poteto-mode

poteto-mode is subordinate to the Owner-Auditor greenlight rules and the 副作用ゲート in `~/.claude/CLAUDE.md` (Claude Code) and to the equivalent approval rules in the Hermes profile. Where they disagree, the local rule wins.

- **poteto-mode "Autonomy" (`Just do it`, external actions proceed without asking) does not apply here.** Push, deploy, release, PR creation, remote writes, external messages, and writes or deletions against databases and external services each require an explicit instruction naming that operation. Produce the artifact (command, SQL, diff, draft message) instead of executing it.
- **`principle-never-block-on-the-human` is bounded by the same gate.** It applies to reversible local work only. It never authorizes an external side effect.
- **Session overrides ("don't stop", "run until done") extend autonomy over local work only.** They do not lift the side-effect gate.
- **Never run `/setup-pstack`.** It writes `~/.cursor/rules/pstack-models.mdc`, which nothing on this machine reads, and configures Cursor-only model slugs.

## 3. Host translation

pstack's text is written for Cursor. Read it with these substitutions.

- **Subagents.** poteto-mode's `Task` calls with `subagent_type: "poteto-agent"` mean the host's own delegation mechanism. In Claude Code that is the Agent tool with `subagent_type: "poteto-agent"` (installed as a user agent). In Hermes, use its native delegation and instruct the delegate to read `~/.agents/skills/poteto-mode/SKILL.md` first.
- **Models.** Ignore every model slug poteto-mode names (`grok-4.6-fast-xhigh`, `claude-fable-5-1-thinking-max`, and the rest). They are Cursor entitlements and are not verified here. Every role runs on the parent model; omit the `model` parameter when delegating.
- **Skills from other Cursor plugins are absent.** poteto-mode references `deslop`, `control-cli`, and `control-ui` (Cursor's `cursor-team-kit`) and Cursor's built-in `create-skill` and `babysit`. None are installed. Substitute the closest local skill or do the step directly, and say which you did.
- **`tdd` is pstack's.** The installed `tdd` skill comes from `cursor/plugins` at `pstack/skills/tdd/SKILL.md`. The dotfiles installer installs the other selected `mattpocock/skills` explicitly and excludes its `tdd`, so future setup runs preserve pstack's ownership.
