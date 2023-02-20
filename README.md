![CI](https://github.com/neko-neko/dotfiles/workflows/CI/badge.svg?branch=master)

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

# Uninstallation
1. run this:  
    ```terminal
    cd ~/.dotfiles && ./setup/uninstall.zsh
    ```
