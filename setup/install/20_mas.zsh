#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install App Store apps...'

apps=(
  # LINE
  539883307
  # Keynote
  409183694
  # WinArchiver
  414855915
)

if [[ -n "${CI}" && "${CI}" == "true" ]]; then
  echo "CI is set to 'true'. Skip the script."
  exit 0
fi

brew install mas
for app in ${apps[@]}; do
  mas install ${app}
done
