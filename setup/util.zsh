#!/bin/zsh
# setup util functions.

# stderr, because it is an error. On stdout it was invisible to any caller that
# redirected output, and indistinguishable from progress to one that did not:
# `setup.zsh > log` produced a file in which the reason a run failed sat between
# two green "linked" lines.
util::error() {
  local message="$1"

  echo -e "\e[31m${message}\e[m" >&2
}

util::warning() {
  local message="$1"

  echo -e "\e[33m${message}\e[m"
}

util::info() {
  local message="$1"

  echo -e "\e[32m${message}\e[m"
}

util::confirm() {
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

util::is_ci() {
  if [[ -n "${CI}" && "${CI}" == "true" ]]; then
    return 0
  fi

  return 1
}
