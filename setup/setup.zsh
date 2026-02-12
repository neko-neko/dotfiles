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

# deploy claude
if [[ ! -d ${HOME}/.claude ]]; then
  mkdir ${HOME}/.claude
fi
ln -sfv ${HOME}/.dotfiles/claude/CLAUDE.md ${HOME}/.claude/CLAUDE.md
ln -sfv ${HOME}/.dotfiles/claude/settings.json ${HOME}/.claude/settings.json
if [[ ! -d ${HOME}/.claude/skills ]]; then
  mkdir ${HOME}/.claude/skills
fi
cd ${HOME}/.dotfiles/.claude/skills
for name in *; do
  if [[ -d ${name} ]]; then
    if [[ -L ${HOME}/.claude/skills/${name} ]]; then
      unlink ${HOME}/.claude/skills/${name}
    fi
    ln -sfv ${PWD}/${name} ${HOME}/.claude/skills/${name}
  fi
done
cd ${HOME}/.dotfiles

# install...
FORCE=1
. ${HOME}/.dotfiles/setup/install.zsh
