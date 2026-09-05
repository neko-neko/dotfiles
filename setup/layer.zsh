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

local -a known=(${registry[@]%%:*})
local requested
for requested in "$@"; do
  if (( ! ${known[(I)${requested}]} )); then
    util::error "unknown layer: ${requested}"
    layer::usage
    exit 1
  fi
done

local entry name
for entry in ${registry[@]}; do
  name=${entry%%:*}
  (( ${@[(I)${name}]} )) || continue

  util::info "=== ${name} layer setup ==="
  util::confirm "install ${name} Brewfile?"
  if [[ $? = 0 ]]; then
    brew bundle --file "${layers_dir}/${name}/Brewfile" || util::error "${name} Brewfile failed"
  fi
  util::info "=== ${name} layer setup complete ==="
done
