#!/bin/zsh
# mac-client layer hook, discovered and confirmed by setup/layer.zsh.
#
# These are workstation preferences: a Dock position, Finder columns, key repeat.
# They ran as setup/install/29_macos.zsh, in the baseline every machine gets,
# which meant the headless server was told to autohide a Dock it has no screen
# for. As a layer hook they belong to the role that has a desk, and setup/layer.zsh
# confirms them separately from the layer's packages, because changing how
# someone's keyboard repeats is a different decision from installing an app.
source "${0:A:h:h:h}/util.zsh"

# Overridable and absolute, so the spec observes the calls instead of writing
# into the running machine's preference domains.
defaults_bin="${DEFAULTS_BIN:-/usr/bin/defaults}"

util::info 'update macOS settings...'

# Absolute as well as executable. A relative DEFAULTS_BIN resolves against the
# caller's cwd, so which binary rewrites the machine's preference domains would
# depend on where the layer was run from.
if [[ -z ${defaults_bin} || ${defaults_bin} != /* || ! -x ${defaults_bin} ]]; then
  util::error "defaults not found at ${defaults_bin}; set DEFAULTS_BIN to its absolute path"
  exit 1
fi

# Each write is checked. A preference domain that refuses the write leaves the
# machine half-configured, and the layer should say so rather than finish green.
macos::write() {
  if ! "${defaults_bin}" write "$@"; then
    util::error "defaults write $* failed"
    exit 1
  fi
}

# Key repeat
macos::write -g InitialKeyRepeat -int 10
macos::write -g KeyRepeat -int 1
macos::write com.apple.finder AppleShowAllFiles -boolean true

# Dock
macos::write com.apple.dock orientation left
macos::write com.apple.dock autohide -bool true
macos::write com.apple.dock persistent-apps -array

# Finder
macos::write -g AppleShowAllExtensions -bool true

util::info 'macOS settings applied; some of them need a logout to take effect'
