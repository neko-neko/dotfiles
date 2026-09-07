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

# Top-level entries that are NOT deployed as ~/.<name>. `hermes` is on the list
# for a safety reason, not a stylistic one: linking it would put this repo on
# top of $HERMES_HOME (~/.hermes), the live runtime tree that holds secrets,
# auth, sessions and gateway state. hermes/configure.zsh applies the tracked
# desired state into that tree instead; it never becomes that tree.
not_deployed=(setup config claude README.md hermes)

# deploy dotfiles
for name in *; do
  if (( ${not_deployed[(I)${name}]} )); then
    continue
  fi
  if [[ -L ${HOME}/.${name} ]]; then
    unlink ${HOME}/.${name}
  fi
  ln -sfv ${PWD}/${name} ${HOME}/.${name}
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

# install...
cd ${HOME}/.dotfiles
FORCE=1
. ${HOME}/.dotfiles/setup/install.zsh
