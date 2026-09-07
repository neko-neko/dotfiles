#!/bin/zsh
# Installs the global language runtimes and puts their shims on PATH for the
# rest of this bootstrap run.
#
# It has to be the first step. `setup/install.zsh` sources the steps in `ls`
# order, and 15_agent_skills.zsh calls `npx`, so Node has to exist before it
# runs. No Brewfile declares Node any more: config/mise/config.toml is the
# single registry for every global runtime.
#
# `setup/install.zsh` sources this rather than executing it, so the `eval` below
# lands in the shell that runs the later steps. ~/.zshenv runs the same
# activation for every shell afterwards.
#
# Resolved from this file rather than ${HOME}/.dotfiles so the installer can be
# exercised against a stub binary (spec/mise_spec.sh).
source "${0:A:h}/../util.zsh"

# Overridable, and resolved once to an absolute path. A bare `mise` at call time
# is not trustworthy: ~/.zshenv reorders PATH, so the binary a caller or a test
# believes it pinned is not necessarily the one that runs.
mise_bin="${MISE_BIN:-$(command -v mise)}"

util::info 'install mise-managed runtimes...'

if [[ -z ${mise_bin} || ${mise_bin} != /* || ! -x ${mise_bin} ]]; then
  util::error "mise not found; install the baseline Brewfile first, or set MISE_BIN to its absolute path"
  return 1
fi

if ! "${mise_bin}" install --yes; then
  util::error 'mise install failed; later steps that need a runtime will not work'
  return 1
fi

# Captured before the eval. `eval "$(mise activate ...)"` reports the status of
# the eval, not of mise, so a mise that failed would look like a successful
# activation of an empty script.
if ! mise_shim_env="$("${mise_bin}" activate zsh --shims)"; then
  util::error 'mise activate failed; runtime shims are not on PATH'
  return 1
fi
eval "${mise_shim_env}"

util::info 'mise runtimes ready; shims are on PATH for the remaining setup steps'
