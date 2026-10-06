#!/bin/zsh
# Installs pstack (cursor/plugins) with APM, from upstream, unchanged. The
# manifest next to this step is the whole declaration; see claude/apm/apm.yml
# for the pin and the target list.
#
# Resolved from this file rather than ${HOME}/.dotfiles, like every other step.
# The default matters because a spec sources this file directly, without
# install.zsh having set DOTFILES_DIR first.
: ${DOTFILES_DIR:=${0:A:h:h:h}}
source "${0:A:h}/../util.zsh"
source "${0:A:h}/../links.zsh"

util::info 'configure APM-managed pstack...'

# Absolute and overridable, the same seam BREW_BIN and MISE_BIN give the other
# steps: ~/.zshenv reorders PATH, so a bare `apm` resolved at call time is not
# necessarily the binary a caller or a test pinned.
apm_bin="${APM_BIN:-$(command -v apm)}"
if [[ -z ${apm_bin} || ${apm_bin} != /* || ! -x ${apm_bin} ]]; then
  util::error 'apm not found; install the baseline Brewfile first, or set APM_BIN to its absolute path'
  return 1
fi

# One file, not the directory: ~/.apm also holds APM's lockfile, module cache
# and config.json, which are APM's own state.
links::link "${DOTFILES_DIR}/claude/apm/apm.yml" "${HOME}/.apm/apm.yml" || return 1

# -t repeats the manifest's targets:. Passing them makes the two harnesses this
# repo deploys to readable at the call site, and APM creates their directories
# itself rather than silently deploying nothing when one is absent.
if ! "${apm_bin}" install -g -t claude,hermes; then
  util::error 'apm install failed'
  return 1
fi
