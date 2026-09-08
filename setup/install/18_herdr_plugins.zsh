#!/bin/zsh
# Applies the declarative Herdr plugin manifest.
#
# The manifest and the convergence logic live in setup/herdr.zsh, because
# setup/uninstall.zsh needs the same list to know which plugin this repo owns.
#
# Resolved from this file rather than ${HOME}/.dotfiles so the step can be
# exercised against a stub binary (spec/herdr_plugins_spec.sh).
source "${0:A:h}/../util.zsh"
source "${0:A:h}/../herdr.zsh"

util::info 'configure herdr plugins...'

herdr::apply || return 1

util::info 'herdr plugins match the manifest'
