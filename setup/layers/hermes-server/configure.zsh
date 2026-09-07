#!/bin/zsh
# hermes-server layer hook, discovered and confirmed by setup/layer.zsh.
#
# The layer decides *whether* this machine runs Hermes Agent. hermes/configure.zsh
# owns *what* the desired state is. No other layer has a Hermes hook.

exec zsh "${0:A:h}/../../../hermes/configure.zsh" "$@"
