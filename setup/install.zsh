#!/bin/zsh
# The shared development baseline. Machine-role and service-overlay packages
# live in layers; install them afterwards with:
#   ./setup/layer.zsh <layer>...     (run with no arguments to list them)
# See README.md "Layer composition" for the supported compositions.
#
# Sourced, not executed, by setup/setup.zsh, and it sources each step for the
# same reason: 00_mise.zsh's activation has to land in the shell the later steps
# run in. `return` therefore reports failure to setup.zsh, and zsh treats it as
# an exit when this file is run on its own.
#
# Every failure here stops the run. It used to continue: a failed baseline
# Brewfile still ran every step, and a step that returned 1 was ignored, so
# `00_mise.zsh` could fail to install Node and `15_agent_skills.zsh` would still
# reach for `npx` four steps later.

: ${DOTFILES_DIR:=${0:A:h:h}}
source "${DOTFILES_DIR}/setup/util.zsh"

# The same seam setup/layer.zsh has: resolved once to an absolute path, and
# overridable. A bare `brew` resolved at call time is not trustworthy, because
# ~/.zshenv reorders PATH, so the binary a caller or a test believes it pinned is
# not necessarily the one that runs.
brew_bin="${BREW_BIN:-$(command -v brew)}"
if [[ -z ${brew_bin} || ${brew_bin} != /* || ! -x ${brew_bin} ]]; then
  util::error 'brew not found; set BREW_BIN to its absolute path'
  return 1
fi

util::confirm 'install packages from Brewfile?'
if [[ $? = 0 ]]; then
  if ! "${brew_bin}" bundle --file "${DOTFILES_DIR}/Brewfile"; then
    util::error 'baseline Brewfile failed; stopping before the setup steps'
    return 1
  fi
fi

for script in $(\ls "${DOTFILES_DIR}/setup/install"); do
  util::confirm "run setup script ${script}?"
  if [[ $? = 0 ]]; then
    if ! . "${DOTFILES_DIR}/setup/install/${script}"; then
      util::error "setup step ${script} failed; stopping"
      return 1
    fi
  fi
done

util::info 'done!'
