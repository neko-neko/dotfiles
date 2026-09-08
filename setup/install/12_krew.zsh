#!/bin/zsh
# Converges the declared krew plugin set: installs what is missing, and nothing
# else.
#
# It used to run `kubectl krew upgrade` on every bootstrap, which upgrades every
# plugin on the machine whether this repo declares it or not, and then reinstall
# all six declared plugins whether or not they were already there. A rerun on a
# converged machine now issues one read and no writes.
#
# It also used to `source ~/.zshenv && source ~/.zshrc`, running the human's
# whole interactive startup inside bootstrap to get one directory onto PATH.
# That line is what krew::_prepend_path below replaces.
#
# Resolved from this file rather than ${HOME}/.dotfiles so the step can be
# exercised against a stub binary (spec/krew_spec.sh).
source "${0:A:h}/../util.zsh"

# The step is sourced into the shell that runs every later step, so its working
# variables are that shell's variables. `plugins`, `missing` and `installed` at
# file scope were three names this step handed to everything after it; inside a
# function they are its own.
krew::plugins() {
  print -rl -- exec-as exec-cronjob node-shell score stern open-svc
}

# Where krew puts the plugins and where kubectl looks for them. ~/.zshenv
# exports the same entry for every interactive shell afterwards.
#
# Idempotent, because the step can be sourced more than once in a bootstrap run
# and an unconditional prepend grows PATH by one duplicate entry each time.
krew::_prepend_path() {
  local dir="$1"

  case ":${PATH}:" in
    *":${dir}:"*) return 0 ;;
  esac

  export PATH="${dir}:${PATH}"
}

# PATH is only touched once the binary is settled. Prepending first meant a run
# that went on to refuse an unusable KUBECTL_BIN had already changed the PATH of
# every step after it.
krew::converge() {
  local kubectl_bin installed plugin
  local -a missing

  kubectl_bin="${KUBECTL_BIN:-$(command -v kubectl)}"
  if [[ -z ${kubectl_bin} || ${kubectl_bin} != /* || ! -x ${kubectl_bin} ]]; then
    util::error 'kubectl not found; install the baseline Brewfile first, or set KUBECTL_BIN to its absolute path'
    return 1
  fi

  krew::_prepend_path "${KREW_ROOT:-${HOME}/.krew}/bin"

  if ! installed=$("${kubectl_bin}" krew list); then
    util::error 'kubectl krew list failed; is krew installed?'
    return 1
  fi

  missing=()
  for plugin in $(krew::plugins); do
    if ! print -r -- "${installed}" | grep -qxF "${plugin}"; then
      missing+=("${plugin}")
    fi
  done

  if (( ${#missing} == 0 )); then
    util::info 'krew plugins already installed'
    return 0
  fi

  # The plugin index is only refreshed when there is something to install from
  # it, and a stale index is a real failure rather than something to install
  # through.
  if ! "${kubectl_bin}" krew update; then
    util::error 'kubectl krew update failed'
    return 1
  fi

  for plugin in ${missing[@]}; do
    if ! "${kubectl_bin}" krew install "${plugin}"; then
      util::error "kubectl krew install ${plugin} failed"
      return 1
    fi
  done

  util::info "installed krew plugins: ${missing[*]}"
}

util::info 'configure krew...'

krew::converge || return 1
