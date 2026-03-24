#!/bin/zsh
# Kanban Sync setup — Tailscale + Syncthing のインストールと初期設定

SCRIPT_DIR="${0:A:h}"
DOTFILES_DIR="${SCRIPT_DIR:h:h}"

source "${DOTFILES_DIR}/setup/util.zsh"

util::info "=== Kanban Sync Setup ==="

for script in "${SCRIPT_DIR}"/[0-9]*_*.zsh(on); do
  script_name="${script:t}"
  util::confirm "run ${script_name}?"
  if [[ $? = 0 ]]; then
    . "${script}"
    if [[ $? -ne 0 ]]; then
      util::warning "${script_name} did not complete successfully."
      util::confirm "continue to next script?" || break
    fi
  fi
done

util::info "=== Kanban Sync Setup Complete ==="
