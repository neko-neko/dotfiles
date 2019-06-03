#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'update macOS settings...'

# Key repeat
defaults write -g InitialKeyRepeat -int 10
defaults write -g KeyRepeat -int 1
defaults write com.apple.finder AppleShowAllFiles -boolean true

# Dock
defaults write com.apple.dock orientation left
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock persistent-apps -array

# Finder
defaults write -g AppleShowAllExtensions -bool true
