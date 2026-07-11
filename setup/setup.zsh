#!/bin/zsh
# setup script.

# downloda dotfiles
if [[ ! -e ${HOME}/.dotfiles ]]; then
  git clone --recursive https://github.com/neko-neko/dotfiles.git ${HOME}/.dotfiles
else
  git pull ${HOME}/.dotfiles
fi

# move dotfiles dir
cd ${HOME}/.dotfiles

# deploy dotfiles
for name in *; do
  if [[ ${name} != 'setup' ]] && [[ ${name} != 'config' ]] && [[ ${name} != 'claude' ]] && [[ ${name} != 'vscode' ]] && [[ ${name} != 'README.md' ]]; then
    if [[ -L ${HOME}/.${name} ]]; then
      unlink ${HOME}/.${name}
    fi
    ln -sfv ${PWD}/${name} ${HOME}/.${name}
  fi
done

# deploy config
if [[ ! -d ${HOME}/.config ]]; then
  mkdir ${HOME}/.config
fi
cd config
for name in *; do
  # herdr keeps runtime files (sockets, logs, session.json) in ~/.config/herdr,
  # so link only config.toml instead of replacing the whole directory
  if [[ ${name} == 'herdr' ]]; then
    mkdir -p ${XDG_CONFIG_HOME:-$HOME/.config}/herdr
    ln -sfv ${PWD}/herdr/config.toml ${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml
    # plugins are registered via `herdr plugin link` (not symlinks); requires a running herdr server
    if command -v herdr >/dev/null 2>&1; then
      if ! herdr plugin list --json 2>/dev/null | grep -q '"drop-upload"'; then
        herdr plugin link ${PWD}/herdr/plugins/drop-upload || echo "warn: herdr plugin link failed (is herdr running?)"
      fi
    fi
    continue
  fi
  if [[ -L ${XDG_CONFIG_HOME:-$HOME/.config}/$name ]]; then
    unlink ${XDG_CONFIG_HOME:-$HOME/.config}/$name
  fi
  ln -sfv ${PWD}/${name} ${XDG_CONFIG_HOME:-$HOME/.config}/${name}
done
cd ..

# deploy vscode
if [[ ! -d ${HOME}/Library/Application\ Support/Code/User ]]; then
  mkdir -p ${HOME}/Library/Application\ Support/Code/User
fi
ln -sfv ${PWD}/vscode/settings.json ${HOME}/Library/Application\ Support/Code/User/settings.json

# install...
cd ${HOME}/.dotfiles
FORCE=1
. ${HOME}/.dotfiles/setup/install.zsh
