[![CI](https://github.com/neko-neko/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/neko-neko/dotfiles/actions/workflows/ci.yml)

# My dotfiles
my dotfiles

# Installation
1. Install XCode CLI tools, run this.
    ```terminal
    sudo xcode-select --switch /Library/Developer/CommandLineTools
    xcode-select --install
    ```

2. Install my dot files:  
    ```terminal
    zsh -c "$(curl -s https://raw.githubusercontent.com/neko-neko/dotfiles/master/setup/setup.zsh)"
    ```
    This installs the common `Brewfile` (packages suitable for both the
    Hermes server and a Mac client) plus the scripts under `setup/install/`.

3. Install the layer matching this machine's role. Layers are opt-in so a
    server doesn't get GUI/mobile/media packages it doesn't need:
    ```terminal
    ./setup/layers/hermes-server/install.zsh  # Tailscale Hermes server / dev server
    ./setup/layers/mac-client/install.zsh     # personal Mac client (GUI, mobile dev, desktop apps)
    ./setup/layers/home-network/install.zsh   # Jellyfin/media/home-network box
    ```

# Uninstallation
1. run this:  
    ```terminal
    cd ~/.dotfiles && ./setup/uninstall.zsh
    ```
