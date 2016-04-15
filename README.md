# My dotfiles
[prezto](https://github.com/sorin-ionescu/prezto) base my dotfiles

# Installation
1. Launch Zsh:
    ```
    zsh
    ```
2. Clone the repository:
    ```
    git clone --recursive https://github.com/neko-neko/dotfiles.git "${ZDOTDIR:-$HOME}/.dotfiles"
    ```
3. Install my dot files:
    ```
    cd ~/.dotfiles && zsh setup.zsh
    ```
4. Set Zsh as default shell:
    ```
    chsh -s /bin/zsh
    ```
