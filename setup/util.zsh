#!/bin/zsh
# setup util functions.

error() {
  local message="$1"

  echo -e "\e[31m${message}\e[m"
}

warning() {
  local message="$1"

  echo -e "\e[33m${message}\e[m"
}

info() {
  local message="$1"

  echo -e "\e[32m${message}\e[m"
}

confirm() {
  local message="$1"

  if [[ ${FORCE} = 1 ]]; then
    return 0
  fi

  echo "${message} (y/N)"
  read confirmation
  if [[ ${confirmation} = "y" || ${confirmation} = "Y" ]]; then
    return 0
  fi

  return 4
}
