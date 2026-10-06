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
  "vercel-labs/agent-browser --skill agent-browser"
  "vercel-labs/agent-skills --skill web-design-guidelines"
  "nanaism/yomiyasu"
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

# mattpocock/skills is installed skill-by-skill rather than wholesale. `tdd` comes
# from pstack, which APM owns (setup/install/19_apm_agents.zsh), and a bare
# `mattpocock/skills` add would reclaim that name on the next setup run.
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

# consulting-pptx-skill. Named with --skill so the add stays pinned to that one
# skill if the upstream repo ever grows a second, and deployed to both hosts
# explicitly: without -a, the add falls back to whatever
# `lastSelectedAgents` happens to hold in ~/.agents/.skill-lock.json, which is
# machine state rather than something this repo declares. The skill name is the
# `name:` field of its SKILL.md and matches the repo name here.
if ! npx skills add carnot-tech/consulting-pptx-skill -g -y -a claude-code -a hermes-agent --skill consulting-pptx-skill; then
  util::error 'npx skills add carnot-tech/consulting-pptx-skill failed'
  return 1
fi
