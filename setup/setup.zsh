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
  if [[ ${name} != 'setup' ]] && [[ ${name} != 'config' ]] && [[ ${name} != 'vscode' ]] && [[ ${name} != 'README.md' ]]; then
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

# download zplug
if [[ ! -d ${HOME}/.zplug ]]; then
  curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
fi
source ${HOME}/.zshrc

# replace zsh
source ${HOME}/.dotfiles/setup/util.zsh
util::confirm 'update using zsh path?'
if [[ $? = 0 ]]; then
  brew install zsh --without-etcdir
  configured=$(grep -c '/usr/local/bin/zsh' /etc/shells)
  if [[ $configured = 0 ]]; then
    sudo sh -c "echo '/usr/local/bin/zsh' >> /etc/shells"
  fi
  chsh -s /usr/local/bin/zsh
  source ${HOME}/.zshrc
fi

# install...
FORCE=1
. ${HOME}/.dotfiles/setup/install.zsh
