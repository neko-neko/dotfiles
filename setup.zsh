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
  # update brew and formulas
  echo "brew updating..."
  brew outdated
  brew update
  brew upgrade --all

  # install basic formulas
  echo "install basic formulas..."
  taps=(
    homebrew/dupes
  )
  formulas=(
    ag
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
    git-flow
    gnupg
    gnutls
    gnu-indent --with-default-names
    gnu-sed --with-default-names
    gnu-tar --with-default-names
    gnu-which --with-default-names
    go --cross-compile-all
    hub
    imagemagick
    jq
    nkf
    nodebrew
    openssl
    p7zip
    peco
    readline
    reattach-to-user-namespace
    tig
    tmux
    tree
    watch
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
  golang_installs=(
    github.com/Masterminds/glide
  )
  golang_get=(
    github.com/codegangsta/cli
    github.com/jteeuwen/go-bindata/...
    github.com/mitchellh/gox
    golang.org/x/tools/cmd/stringer
  )
  for install_item in ${golang_installs[@]}; do
    go install ${install_item}
  done
  for get_item in ${golang_get[@]}; do
    go get -u ${get_item}
  done

  # cleanup brew
  brew cleanup

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
    evernote
    firefox
    google-chrome
    google-japanese-ime
    java
    karabiner
    licecap
    mou
    mysqlworkbench
    shiftit
    slack
    sourcetree
    iterm2
    vagrant
    virtualbox
  )

  # cask update
  brew cask update

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
    d3dx10
    d3dx11
    d3dx9
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
# install my dotfiles
for name in *; do
  target="$HOME/.$name"
  if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
    echo "$target already exists"
  else
    if [[ "$name" != 'setup.zsh' ]] && [[ "$name" != 'README.md' ]] && [[ "$name" != 'prezto' ]] && [[ "$name" != 'remove.zsh' ]]; then
      echo "creating $target"
      ln -sf "$PWD/$name" "$target"
    fi
  fi
done

# install Prezto
echo "creating prezto link ${ZDOTDIR:-$HOME}/.zprezto"
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
