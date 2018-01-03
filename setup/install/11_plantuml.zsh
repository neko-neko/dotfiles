#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install PlantUML...'

mkdir -p ${HOME}/lib/java
wget http://jaist.dl.sourceforge.net/project/plantuml/plantuml.jar -P ${HOME}/lib/java/
