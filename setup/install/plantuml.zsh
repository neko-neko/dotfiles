#!/bin/zsh
# include util functions
source ${HOME}/.dotfiles/setup/util.zsh

install::plantuml() {
  util::info 'install PlantUML...'

  mkdir -p ${HOME}/lib/java
  wget http://jaist.dl.sourceforge.net/project/plantuml/plantuml.jar -P ${HOME}/lib/java/
}
