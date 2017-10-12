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
    universal-ctags/universal-ctags
    sanemat/font
  )
  formulas=(
    ansible
    autoconf
    binutils
    ccat
    cmake
    coreutils
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
    grip
    hub
    imagemagick
    jq
    kubectl
    lua
    neovim
    nkf
    openssl
    p7zip
    packer
    pandoc
    peco
    python3
    readline
    reattach-to-user-namespace
    ricty --with-powerline
    terraform
    tig
    tmux
    tree
    wget
    zsh --without-etcdir
  )
  brew upgrade
  for tap in ${taps[@]}; do
    brew tap ${tap}
  done
  brew install ${formulas[@]}

  # update zsh
  echo 'update using zsh path? (y/n)'
  read confirmation
  if [[ $confirmation = "y" || $confirmation = "Y" ]]; then
    echo "update /etc/shells..."
    sudo sh -c "echo '/usr/local/bin/zsh' >> /etc/shells"
    echo "switch new zsh..."
    chsh -s /usr/local/bin/zsh
    echo "refreshing environment..."
    source ${ZDOTDIR:-$HOME}/.zshrc
  fi

  # setup ricty font
  brew install --HEAD universal-ctags
  cp -f /usr/local/opt/ricty/share/fonts/Ricty*.ttf ~/Library/Fonts/
  fc-cache -vf
  
  # install ruby formulas
  echo "install ruby formulas..."
  brew install ruby-build
  brew install rbenv

  # install golang
  echo "install golang formulas..."
  golang_get=(
    github.com/golang/dep/...
    gopkg.in/alecthomas/gometalinter.v1
    github.com/jteeuwen/go-bindata/...
    github.com/mitchellh/gox
    golang.org/x/tools/cmd/stringer
    github.com/simeji/jid/cmd/jid
    github.com/nsf/gocode
    github.com/go-swagger/go-swagger/cmd/swagger
  )
  for get_item in ${golang_get[@]}; do
    go get -u -v ${get_item}
  done
  ln -sfv ${GOPATH}/bin/gometalinter.v1 ${GOPATH}/bin/gometalinter
  gometalinter --install --update

  # install nodebrew
  curl -L git.io/nodebrew | perl - setup
  mkdir -p ${ZDOTDIR:-$HOME}/.nodebrew/src

  # install gems
  install_gems=(
    neovim
    rcodetools
    tmuxinator
  )
  for install_gem in ${install_gems[@]}; do
    gem install ${install_gem}
  done

  # install pips
  install_py3_pips=(
    neovim
  )
  pip3 install --upgrade pip setuptools wheel
  for install_py3_pip in ${install_py3_pips[@]}; do
    pip3 install ${install_py3_pip}
  done

  # cleanup brew
  brew cleanup

  # install plantuml
  mkdir -p ${ZDOTDIR:-$HOME}/lib/java
  wget http://jaist.dl.sourceforge.net/project/plantuml/plantuml.jar -P ${ZDOTDIR:-$HOME}/lib/java/
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
  if [[ "$name" != 'install.zsh' ]] && [[ "$name" != 'uninstall.zsh' ]] && [[ "$name" != 'config' ]] && [[ "$name" != 'README.md' ]] && [[ "$name" != 'prezto' ]]; then
    if [[ -L ${ZDOTDIR:-$HOME}/.$name ]]; then
      unlink "${ZDOTDIR:-$HOME}/.$name"
    fi
    ln -sfv "$PWD/$name" "${ZDOTDIR:-$HOME}/.$name"
  fi
done

# install prezto
if [[ -e ${ZDOTDIR:-$HOME}/.zprezto ]]; then
  unlink "${ZDOTDIR:-$HOME}/.zprezto"
fi
ln -sfv "$PWD/prezto" "${ZDOTDIR:-$HOME}/.zprezto"

# install my config
if [[ ! -d ${ZDOTDIR:-$HOME}/.config ]]; then
  mkdir ${ZDOTDIR:-$HOME}/.config
fi
cd config
for name in *; do
  if [[ -L ${XDG_CONFIG_HOME:-$HOME/.config}/$name ]]; then
    unlink "${XDG_CONFIG_HOME:-$HOME/.config}/$name"
  fi
  ln -sfv "$PWD/$name" "${XDG_CONFIG_HOME:-$HOME/.config}/$name"
done
cd ..

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

# update mac settings?
echo 'update mac settings? (y/n)'
read confirmation
if [[ $confirmation = "y" || $confirmation = "Y" ]]; then
  defaults write -g InitialKeyRepeat -int 10
  defaults write -g KeyRepeat -int 1
  defaults write com.apple.finder AppleShowAllFiles -boolean true
fi
