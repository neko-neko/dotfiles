#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install splashtop streamer...'
brew install --cask splashtop-streamer

util::info 'launching splashtop streamer for manual login'
open -a "Splashtop Streamer" || util::warning "failed to launch Splashtop Streamer.app"

util::warning 'MANUAL STEP:'
util::warning '  1. sign in with your Splashtop account in the Streamer app'
util::warning '  2. disable auto-update in the Streamer preferences (to avoid surprise dialogs)'
util::warning '  3. on iPad: install Splashtop Business/Personal from App Store'
util::warning '  4. on iPad: sign in with the same Splashtop account'
