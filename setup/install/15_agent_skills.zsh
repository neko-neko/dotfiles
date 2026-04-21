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

external_skills=(
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-calendar"
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-docs"
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-drive"
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-gmail"
  "https://github.com/googleworkspace/cli/tree/main/skills/gws-sheets"
  "https://github.com/anthropics/skills --skill skill-creator"
  "vercel-labs/agent-browser --skill agent-browser --skill dogfood"
  "vercel-labs/agent-skills --skill react-best-practices --skill composition-patterns --skill web-design-guidelines"
  "https://github.com/github/awesome-copilot --skill breakdown-test"
  "mattpocock/skills/grill-me"
  "pzep1/xcode-build-skill"
)

npx skills update || util::warning 'skills update failed'

for skill in "${external_skills[@]}"; do
  npx skills add ${=skill} -g -y
done
