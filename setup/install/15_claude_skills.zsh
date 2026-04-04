#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure Claude Code skills...'

for skill in ${HOME}/.dotfiles/claude/skills/*/SKILL.md; do
  local name=$(basename $(dirname "${skill}"))
  if [[ -L ${HOME}/.claude/skills/${name} ]]; then
    unlink ${HOME}/.claude/skills/${name}
  fi
  ln -sfv ${HOME}/.dotfiles/claude/skills/${name} ${HOME}/.claude/skills/${name}
done

external_skills=(
  https://github.com/googleworkspace/cli/tree/main/skills/gws-calendar
  https://github.com/googleworkspace/cli/tree/main/skills/gws-docs
  https://github.com/googleworkspace/cli/tree/main/skills/gws-drive
  https://github.com/googleworkspace/cli/tree/main/skills/gws-gmail
  https://github.com/googleworkspace/cli/tree/main/skills/gws-sheets
)

npx skills update || util::warning 'skills update failed'

for skill in ${external_skills[@]}; do
  npx skills add "${skill}" -g -y
done
