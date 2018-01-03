#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'update macOS settings...'

# Key repeat
defaults write -g InitialKeyRepeat -int 10
defaults write -g KeyRepeat -int 1
defaults write com.apple.finder AppleShowAllFiles -boolean true
