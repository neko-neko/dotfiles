#!/bin/zsh
# Resolved from this file rather than ${HOME}/.dotfiles so the installer can be
# exercised against a throwaway HOME (spec/lazyvim_spec.sh).
source "${0:A:h}/../util.zsh"

# Overridable so the spec clones from a local fixture instead of the network.
: ${LAZYVIM_STARTER_URL:="https://github.com/LazyVim/starter"}

# Clones into a staging directory this run created, so the cleanup can only ever
# remove what it made. Staging sits beside the target so the final step is a
# rename rather than a cross-filesystem copy.
lazyvim::install_starter() {
  local target="$1"
  local staging

  mkdir -p "${target:h}" || return 1
  staging=$(mktemp -d "${target:h}/nvim.lazyvim.XXXXXX") || return 1

  {
    git clone --depth 1 "${LAZYVIM_STARTER_URL}" "${staging}/starter" || {
      util::error "failed to clone ${LAZYVIM_STARTER_URL}"
      return 1
    }

    # The starter is a template, not an upstream to track.
    rm -rf "${staging}/starter/.git"

    # rmdir only succeeds on an empty directory, so a real config can never be
    # replaced here.
    rmdir "${target}" 2>/dev/null
    if [[ -e ${target} ]]; then
      util::error "${target} is not empty; leaving it untouched"
      return 1
    fi

    mv "${staging}/starter" "${target}" || return 1
  } always {
    rm -rf "${staging}"
  }
}

local nvim_config="${XDG_CONFIG_HOME:-${HOME}/.config}/nvim"

util::info 'configure LazyVim...'

if [[ -L ${nvim_config} ]]; then
  util::info "keeping ${nvim_config} (symlink to $(readlink ${nvim_config}))"
  return 0
fi

if [[ -e ${nvim_config} && ! -d ${nvim_config} ]]; then
  util::warning "keeping ${nvim_config} (not a directory); LazyVim not installed"
  return 0
fi

if [[ -d ${nvim_config} && -n "$(\ls -A ${nvim_config})" ]]; then
  util::info "keeping existing ${nvim_config}; LazyVim starter not applied"
  if [[ "$(git -C ${nvim_config} remote get-url origin 2>/dev/null)" == *LazyVim/starter* ]]; then
    util::warning "  it is still a clone of LazyVim/starter. to own it yourself: rm -rf ${nvim_config}/.git"
  fi
  return 0
fi

lazyvim::install_starter "${nvim_config}" || return 1
util::info "installed LazyVim starter to ${nvim_config} (plugins install on first nvim launch)"
