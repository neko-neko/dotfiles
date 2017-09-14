#!/bin/zsh
#
# Install my tools
set -eu

#######################################
# Install brew formulas
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
install_brew_files() {
  # install basic formulas
  echo "install basic formulas..."
  taps=(
    homebrew/dupes
  )
  formulas=(
    ansible
    autoconf
    binutils
    ccat
    cmake
    coreutils
    ctags
    curl
    diffutils
    findutils --with-default-names
    gawk
    gibo
    git-extras
    gnu-indent --with-default-names
    gnu-sed --with-default-names
    gnu-tar --with-default-names
    gnu-which --with-default-names
    gnupg
    gnutls
    go --cross-compile-all
    graphviz
    grep --with-default-names
    hub
    imagemagick
    jq
    lua
    nkf
    openssl
    p7zip
    packer
    pandoc
    peco
    readline
    reattach-to-user-namespace
    terraform
    tig
    tmux
    tree
    wget
    zsh --without-etcdir
  )
  brew tap ${taps[@]}
  brew install ${formulas[@]}
  brew install macvim --with-cscope --with-lua --with-override-system-vim
  brew linkapps macvim

  # install ruby formulas
  echo "install ruby formulas..."
  brew install ruby-build
  brew install rbenv

  # install golang
  echo "install golang formulas..."
  golang_get=(
    github.com/golang/dep/...
    github.com/jteeuwen/go-bindata/...
    github.com/mitchellh/gox
    golang.org/x/tools/cmd/stringer
    github.com/simeji/jid/cmd/jid
  )
  for get_item in ${golang_get[@]}; do
    go get -u ${get_item}
  done

  # install nodebrew
  curl -L git.io/nodebrew | perl - setup
  mkdir -p ${ZDOTDIR:-$HOME}/.nodebrew/src

  # install gems
  install_gems=(
    tmuxinator
  )
  for install_gem in ${install_gems[@]}; do
    gem install ${install_gem}
  done

  # cleanup brew
  brew cleanup

  # install plantuml
  mkdir -p ${ZDOTDIR:-$HOME}/lib/java
  wget http://jaist.dl.sourceforge.net/project/plantuml/plantuml.jar -P ${ZDOTDIR:-$HOME}/lib/java/

  # update zsh
  echo 'update using zsh path? (y/n)'
  read confirmation
  if [[ $confirmation = "y" || $confirmation = "Y" ]]; then
    echo "update /etc/shells..."
    sudo sh -c "echo '/usr/local/bin/zsh' >> /etc/shells"
    echo "switch new zsh..."
    chsh -s /usr/local/bin/zsh
  fi
}

#######################################
# Install brew casks
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
install_brew_casks() {
  # brew taps
  taps=(
    caskroom/cask
  )

  # brew casks
  casks=(
    alfred
    atom
    caffeine
    docker
    evernote
    firefox
    google-chrome
    google-japanese-ime
    iterm2
    java
    karabiner-elements
    licecap
    mysqlworkbench
    shiftit
    slack
    vagrant
    virtualbox
  )

  # install taps
  brew tap ${taps[@]}

  # install casks
  brew cask install ${casks[@]}

  # atom package manager
  apm install sync-settings

  # cleanup cask files
  brew cask cleanup
}

######################################
# Install my toys
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
######################################
install_my_toys() {
  casks=(
    wireshark
    xquartz
  )
  formulas=(
    wine
    winetricks
  )
  # install casks
  brew cask install ${casks[@]}

  # install formulas
  brew install ${formulas[@]}

  # install winetricks plugins
  wine_plugins=(
    allfonts
    d3dx9_43
    d3dx10_43
    d3dx11_43
    directmusic
    dsound
    vcrun2005
    vcrun2008
    vcrun2010
    vcrun2012
    vcrun2013
    vcrun2015
    vcrun6
  )
  winetricks ${wine_plugins[@]}
}

# ------------------------------
# Run installation
# ------------------------------
# clone my dotfiles
if [[ ! -e ${ZDOTDIR:-$HOME}/.dotfiles ]]; then
  git clone --recursive https://github.com/neko-neko/dotfiles.git "${ZDOTDIR:-$HOME}/.dotfiles"
else
  git pull ${ZDOTDIR:-$HOME}/.dotfiles
fi

# move dotfiles dir
cd "${ZDOTDIR:-$HOME}/.dotfiles"

# install my dotfiles
for name in *; do
  if [[ "$name" != 'install.zsh' ]] && [[ "$name" != 'uninstall.zsh' ]] && [[ "$name" != 'README.md' ]] && [[ "$name" != 'prezto' ]]; then
    if [[ -e ${ZDOTDIR:-$HOME}/.$name ]]; then
      unlink "${ZDOTDIR:-$HOME}/.$name"
    fi
    ln -sfv "$PWD/$name" "${ZDOTDIR:-$HOME}/.$name"
  fi
done
if [[ -e ${ZDOTDIR:-$HOME}/.zprezto ]]; then
  unlink "${ZDOTDIR:-$HOME}/.zprezto"
fi
ln -sf "$PWD/prezto" "${ZDOTDIR:-$HOME}/.zprezto"

# install brew files
echo 'install brew files? (y/n)'
read confirmation
if [[ $confirmation = "y" || $confirmation = "Y" ]]; then
  echo "Install brew files..."
  install_brew_files
fi

# install brew casks
echo 'install brew casks? (y/n)'
read confirmation
if [[ $confirmation = "y" || $confirmation = "Y" ]]; then
  echo "Install brew casks..."
  install_brew_casks
fi

# install my toys
echo 'install my toys? (y/n)'
read confirmation
if [[ $confirmation = "y" || $confirmation = "Y" ]]; then
  echo "Install my toys..."
  install_my_toys
fi

# Fixed key repeat?
echo 'fixed key repeat?'
read confirmation
if [[ $confirmation = "y" || $confirmation = "Y" ]]; then
  defaults write -g InitialKeyRepeat -int 10
  defaults write -g KeyRepeat -int 1
fi
