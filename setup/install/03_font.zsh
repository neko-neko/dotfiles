#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install font files...'

brew install fontforge
pip3 install configparser

# Ricty
brew tap sanemat/font
brew install ricty --with-powerline
\cp -f /opt/homebrew/opt/ricty/share/fonts/Ricty*.ttf ~/Library/Fonts/

# Nerd Fonts
git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git
cd nerd-fonts
chmod 755 font-patcher
fontforge -script ./font-patcher ~/Library/Fonts/Ricty\ Regular\ for\ Powerline.ttf \
  --progressbars \
  --fontawesome \
  --fontawesomeextension \
  --fontlinux \
  --octicons \
  --pomicons \
  --powerline \
  --powerlineextra
\cp -f \
  ./Ricty\ Regular\ Nerd\ Font\ Plus\ Font\ Awesome\ Plus\ Font\ Awesome\ Extension\ Plus\ Octicons\ Plus\ Pomicons\ Plus\ Font\ Logos\ \(Font\ Linux\).ttf \
  ~/Library/Fonts/Ricty\ Regular\ for\ Powerline\ Patched.ttf

fc-cache -vf
cd ..
rm -rf nerd-fonts
