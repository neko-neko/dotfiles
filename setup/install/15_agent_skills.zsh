#!/bin/zsh
# Resolved from this file rather than ${HOME}/.dotfiles, like every other step.
# A hard-coded ${HOME}/.dotfiles reads the checkout that happens to live there,
# which in CI is not the checkout under test and on a machine using the
# DOTFILES_DIR seam is not the checkout being installed either.
#
# The links this step makes go through setup/links.zsh, so they follow the same
# rule as everything else this repo deploys: create the parent, own an absent
# target or one already pointing into this repo, and preserve anything else with
# an actionable message. It used to `unlink` whatever symlink it found and then
# `ln -sfv` over the top, which silently took ownership of a skill somebody else
# had linked, and which put a nested <skill>/<skill> link inside any skill
# directory a human had materialised as a real one.
source "${0:A:h}/../util.zsh"
source "${0:A:h}/../links.zsh"

util::info 'configure Agent skills...'

skills_dir="${DOTFILES_DIR}/claude/skills"
agents_dir="${DOTFILES_DIR}/claude/agents"
link_failed=0

for skill in ${skills_dir}/*/SKILL.md(N); do
  name=${skill:h:t}
  links::link "${skills_dir}/${name}" "${HOME}/.claude/skills/${name}" || link_failed=1
done

# dotfiles-local skills that Hermes Agent loads as well as Claude Code.
shared_skills=(
  poteto-default
)
for name in "${shared_skills[@]}"; do
  links::link "${skills_dir}/${name}" "${HOME}/.hermes/skills/${name}" || link_failed=1
done

# dotfiles-local subagents. An entry already materialised as a real file is the
# human's own copy and stays: this is the one place where a conflict is the
# expected state rather than something to report.
for agent in ${agents_dir}/*.md(N); do
  aname=${agent:t}
  if [[ -e ${HOME}/.claude/agents/${aname} && ! -L ${HOME}/.claude/agents/${aname} ]]; then
    util::info "keeping ${HOME}/.claude/agents/${aname} (a real file, not a link)"
    continue
  fi
  links::link "${agent}" "${HOME}/.claude/agents/${aname}" || link_failed=1
done

if (( link_failed )); then
  util::error 'some agent skill links could not be deployed; resolve the conflicts above and rerun'
  return 1
fi

external_skills=(
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-calendar"
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-docs"
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-drive"
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-gmail"
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-sheets"
  "vercel-labs/agent-browser --skill agent-browser --skill dogfood"
  "vercel-labs/agent-skills --skill react-best-practices --skill composition-patterns --skill web-design-guidelines"
)

# The one operation here that may fail without stopping the run. `skills update`
# refreshes whatever is already installed; every skill this step requires is
# added below from an explicit source (a URL, or owner/repo plus --skill names),
# so the adds converge the installed set on their own. An `add` is different:
# nothing later re-attempts it, so a swallowed failure leaves the machine
# missing a skill while setup reports success.
npx skills update || util::warning 'skills update failed; the adds below still converge from their explicit sources'

for skill in "${external_skills[@]}"; do
  if ! npx skills add ${=skill} -g -y; then
    util::error "npx skills add ${skill} failed"
    return 1
  fi
done

# mattpocock/skills is installed skill-by-skill rather than wholesale. `tdd` now comes
# from pstack (see pstack_skills below), and a bare `mattpocock/skills` add would
# reclaim that name on the next setup run.
mattpocock_skills=(
  code-review
  codebase-design
  diagnosing-bugs
  domain-modeling
  grill-me
  grill-with-docs
  grilling
  implement
  improve-codebase-architecture
  prototype
  setup-matt-pocock-skills
  wayfinder
)
mattpocock_args=()
for name in "${mattpocock_skills[@]}"; do
  mattpocock_args+=(--skill "${name}")
done
if ! npx skills add mattpocock/skills -g -y "${mattpocock_args[@]}"; then
  util::error 'npx skills add mattpocock/skills failed'
  return 1
fi

# pstack (cursor/plugins) v0.14.8. Skill names come from each SKILL.md `name:` field,
# so two of them contain spaces and cannot survive the ${=skill} word splitting above.
# `tdd` is pstack's here: mattpocock/skills is pinned to a list that excludes it.
# The Benny automation pack and the other plugins in the monorepo are not selected.
pstack_skills=(
  "Poteto Mode"
  "Make Bot UI"
  architect
  arena
  automate-me
  blast-radius
  bro
  create-verification-skill
  figure-it-out
  how
  interrogate
  maintain-verification-skill
  no-comments
  principle-boundary-discipline
  principle-build-the-lever
  principle-encode-lessons-in-structure
  principle-exhaust-the-design-space
  principle-experience-first
  principle-fix-root-causes
  principle-foundational-thinking
  principle-guard-the-context-window
  principle-laziness-protocol
  principle-make-operations-idempotent
  principle-migrate-callers-then-delete-legacy-apis
  principle-minimize-reader-load
  principle-model-the-domain
  principle-never-block-on-the-human
  principle-outcome-oriented-execution
  principle-prove-it-works
  principle-redesign-from-first-principles
  principle-separate-before-serializing-shared-state
  principle-sequence-verifiable-units
  principle-subtract-before-you-add
  principle-type-system-discipline
  recall
  reflect
  setup-pstack
  show-me-your-work
  swarm
  tdd
  teach
  technical-writing
  typescript-best-practices
  unslop
  why
)
pstack_args=()
for name in "${pstack_skills[@]}"; do
  pstack_args+=(--skill "${name}")
done
if ! npx skills add cursor/plugins -g -y -a claude-code -a hermes-agent "${pstack_args[@]}"; then
  util::error 'npx skills add cursor/plugins failed'
  return 1
fi
