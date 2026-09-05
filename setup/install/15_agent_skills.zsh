#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure Agent skills...'

for skill in ${HOME}/.dotfiles/claude/skills/*/SKILL.md; do
  local name=$(basename $(dirname "${skill}"))
  if [[ -L ${HOME}/.claude/skills/${name} ]]; then
    unlink ${HOME}/.claude/skills/${name}
  fi
  ln -sfv ${HOME}/.dotfiles/claude/skills/${name} ${HOME}/.claude/skills/${name}
done

# dotfiles-local skills that Hermes Agent loads as well as Claude Code.
shared_skills=(
  poteto-default
)
mkdir -p ${HOME}/.hermes/skills
for name in "${shared_skills[@]}"; do
  if [[ -L ${HOME}/.hermes/skills/${name} ]]; then
    unlink ${HOME}/.hermes/skills/${name}
  fi
  ln -sfv ${HOME}/.dotfiles/claude/skills/${name} ${HOME}/.hermes/skills/${name}
done

# dotfiles-local subagents. Entries already materialized as real files are left alone.
mkdir -p ${HOME}/.claude/agents
for agent in ${HOME}/.dotfiles/claude/agents/*.md; do
  aname=$(basename "${agent}")
  if [[ -e ${HOME}/.claude/agents/${aname} && ! -L ${HOME}/.claude/agents/${aname} ]]; then
    continue
  fi
  ln -sfv "${agent}" ${HOME}/.claude/agents/${aname}
done

external_skills=(
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-calendar"
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-docs"
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-drive"
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-gmail"
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-sheets"
  "vercel-labs/agent-browser --skill agent-browser --skill dogfood"
  "vercel-labs/agent-skills --skill react-best-practices --skill composition-patterns --skill web-design-guidelines"
)

npx skills update || util::warning 'skills update failed'

for skill in "${external_skills[@]}"; do
  npx skills add ${=skill} -g -y
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
npx skills add mattpocock/skills -g -y "${mattpocock_args[@]}" \
  || util::warning 'mattpocock skills install failed'

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
npx skills add cursor/plugins -g -y -a claude-code -a hermes-agent "${pstack_args[@]}" \
  || util::warning 'pstack skills install failed'
