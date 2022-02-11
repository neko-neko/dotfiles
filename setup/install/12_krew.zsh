#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure krew...'

plugins=(
  exec-as
  exec-cronjob
  node-shell
  score
  stern
  open-svc
)

kubectl krew update
kubectl krew upgrade
for plugin in ${plugins[@]}; do
  kubectl krew install ${plugin}
done
