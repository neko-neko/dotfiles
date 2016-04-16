#!/bin/zsh
# ------------------------------
# Install brew files function
# ------------------------------
function install_brew_files() {
  # update brew and formulas
  echo "brew updating..."
  brew outdated
  brew update
  brew upgrade --all

  # install basic formulas
  echo "install basic formulas..."
  brew install ag
  brew install ansible
  brew install autoconf
  brew install binutils
  brew install cmake
  brew install coreutils
  brew install ctags
  brew install curl
  brew install diffutils
  brew install findutils --with-default-names
  brew install gawk
  brew install gibo
  brew install gnu-indent --with-default-names
  brew install gnu-sed --with-default-names
  brew install gnu-tar --with-default-names
  brew install gnu-which --with-default-names
  brew install gnupg
  brew install gnutls
  brew install hub
  brew install imagemagick
  brew install jq
  brew install macvim --with-cscope --with-lua --with-override-system-vim
  brew linkapps macvim
  brew install openssl
  brew install readline
  brew install reattach-to-user-namespace
  brew install tig
  brew install tmux
  brew install tree
  brew install tree
  brew install watch
  brew install wget
  brew install zsh --without-etcdir

  # install ruby formulas
  echo "install ruby formulas..."
  brew install ruby-build
  brew install rbenv

  # install golang
  echo "install golang formulas..."
  brew install go --cross-compile-all
  go get github.com/Masterminds/glide
  go install github.com/Masterminds/glide
  go get github.com/codegangsta/cli
  go get -u github.com/jteeuwen/go-bindata/...

  # install node
  echo "install node formulas..."
  brew install nodebrew

  # cleanup brew
  brew cleanup

  # update zsh
  echo "update /etc/shells..."
  sudo sh -c "echo '/usr/local/bin/zsh' >> /etc/shells"
  echo "switch new zsh..."
  chsh -s /usr/local/bin/zsh
}

# ------------------------------
# Install brew casks function
# ------------------------------
function install_brew_casks() {
  # install cask
  brew tap caskroom/cask
  brew install brew-cask

  # install terminal
  brew cask install iterm2

  # install browsers
  brew cask install firefox --caskroom=/Applications
  brew cask install google-chrome --caskroom=/Applications

  # install ime
  brew cask install google-japanese-ime

  # install editors
  brew cask install atom
  brew cask install mou
  brew cask install evernote

  # install keyboard utils
  brew cask install shiftit
  brew cask install karabiner

  # install capture utils
  brew cask install licecap

  # install screen utils
  brew cask install caffeine

  # install development tools
  brew cask install sourcetree
  brew cask install virtualbox
  brew cask install vagrant
  brew cask install dockertoolbox
  brew cask install java
  brew cask install mysqlworkbench

  # install slack
  brew cask install slack

  # install alfred
  brew cask install alfred

  # cleanup cask files
  brew cask cleanup
}

# ------------------------------
# Install my toys function
# ------------------------------
function install_my_toys() {
  # install wireshark
  brew cask install wireshark

  # install wine
  brew cask install xquartz
  brew install wine
  brew install winetricks
  winetricks d3dx9
  winetricks d3dx10
  winetricks d3dx11
  winetricks directmusic
  winetricks dsound
  winetricks allfonts
  winetricks vcrun6
  winetricks vcrun2005
  winetricks vcrun2008
  winetricks vcrun2010
  winetricks vcrun2012
  winetricks vcrun2013
  winetricks vcrun2015
}

# ------------------------------
# Do functions
# ------------------------------
# install my dotfiles
for name in *; do
  target="$HOME/.$name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "$target already exists"
  else
  if [ "$name" != 'setup.zsh' ] && [ "$name" != 'README.md' ] && [ "$name" != 'prezto' ]; then
    echo "creating $target"
    ln -sf "$PWD/$name" "$target"
  fi
fi
done

# install Prezto
echo "creating prezto link ${ZDOTDIR:-$HOME}/.zprezto"
ln -sf "$PWD/prezto" "${ZDOTDIR:-$HOME}/.zprezto"

# install brew files
echo "Install brew files..."
install_brew_files

# install brew casks
echo 'install brew casks? (y/n)'
read confirmation
if [[ $confirmation = "y" || confirmation = "Y" ]]; then
  echo "Install brew casks..."
  install_brew_casks
fi

# install my toys
echo 'install my toys? (y/n)'
read confirmation
if [[ $confirmation = "y" || confirmation = "Y" ]]; then
  echo "Install my toys..."
  install_my_toys
fi
