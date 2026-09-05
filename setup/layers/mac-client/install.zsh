#!/bin/zsh
# Kept as the per-layer entrypoint. The registry, ordering and install
# behaviour live in setup/layer.zsh; this only names the layer.

"${0:A:h}/../../layer.zsh" mac-client
