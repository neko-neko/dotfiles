#!/bin/zsh
# Installs layers on top of the shared development baseline Brewfile.
#
# A machine is composed as: baseline (setup/install.zsh) + one machine-role
# layer + any service overlays it hosts. Layers always run in the order
# declared below, not in the order given on the command line.
#
#   ./setup/layer.zsh hermes-server home-network

source "${0:A:h}/util.zsh"

local layers_dir="${0:A:h}/layers"
# Captured here because $0 becomes the function name inside layer::usage.
local self="${0:t}"

# Resolved once to an absolute path, and overridable. A bare `brew` resolved at
# call time is not trustworthy: ~/.zshenv reorders PATH, so the binary a caller
# or a test believes it pinned is not necessarily the one that runs.
local brew_bin="${BREW_BIN:-$(command -v brew)}"

# name:kind:description. kind is `role` (what the machine is; pick one) or
# `overlay` (services it additionally hosts, layered on a role).
local -a registry=(
  'hermes-server:role:always-on Tailscale dev/build server (headless)'
  'mac-client:role:personal Mac workstation (GUI apps, mobile SDKs, fonts)'
  'home-network:overlay:home LAN services (AdGuard Home, Syncthing, Jellyfin)'
)

layer::usage() {
  print "usage: ${self} <layer> [<layer>...]"
  print ''
  print 'layers:'
  local entry
  for entry in ${registry[@]}; do
    printf '  %-14s %-9s %s\n' "${entry%%:*}" "[${${entry#*:}%%:*}]" "${entry##*:}"
  done
  print ''
  print 'Run setup/install.zsh (baseline Brewfile) first. Supported compositions:'
  print '  hermes-server                 headless dev/build server'
  print '  mac-client                    personal Mac workstation'
  print '  hermes-server home-network    dev/build server also serving the home LAN'
}

if (( $# == 0 )); then
  layer::usage
  exit 1
fi

if [[ -z ${brew_bin} || ${brew_bin} != /* || ! -x ${brew_bin} ]]; then
  util::error "brew not found; set BREW_BIN to its absolute path"
  exit 1
fi

local -a known=(${registry[@]%%:*})
local requested
for requested in "$@"; do
  if (( ! ${known[(I)${requested}]} )); then
    util::error "unknown layer: ${requested}"
    layer::usage
    exit 1
  fi
done

local entry name configure
for entry in ${registry[@]}; do
  name=${entry%%:*}
  (( ${@[(I)${name}]} )) || continue

  util::info "=== ${name} layer setup ==="
  util::confirm "install ${name} Brewfile?"
  if [[ $? = 0 ]]; then
    "${brew_bin}" bundle --file "${layers_dir}/${name}/Brewfile" || util::error "${name} Brewfile failed"
  fi

  # A layer that ships configure.zsh also has declarative state to apply. It is
  # confirmed separately from the packages, because applying settings to a
  # service is a different decision from installing its binaries.
  configure="${layers_dir}/${name}/configure.zsh"
  if [[ -f ${configure} ]]; then
    util::confirm "apply ${name} declarative configuration?"
    if [[ $? = 0 ]]; then
      zsh "${configure}" || util::error "${name} configure.zsh failed"
    fi
  fi

  util::info "=== ${name} layer setup complete ==="
done
