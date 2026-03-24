#!/bin/zsh
# Tailscale セットアップ — インストール + ログインガイド

SCRIPT_DIR="${0:A:h}"
DOTFILES_DIR="${SCRIPT_DIR:h:h}"

source "${DOTFILES_DIR}/setup/util.zsh"

# --- 1. Brewfile でインストール ---
util::info "Installing Tailscale, Syncthing, jq from Brewfile..."
brew bundle --file="${SCRIPT_DIR}/Brewfile"
if [[ $? -ne 0 ]]; then
  util::error "brew bundle failed."
  return 1
fi

# --- 2. Tailscale アプリ起動 ---
TAILSCALE_APP="/Applications/Tailscale.app"
TAILSCALE_CLI="${TAILSCALE_APP}/Contents/MacOS/Tailscale"

if [[ ! -d "${TAILSCALE_APP}" ]]; then
  util::error "Tailscale.app not found at ${TAILSCALE_APP}"
  return 1
fi

# アプリが起動していなければ起動
if ! pgrep -q "Tailscale"; then
  util::info "Starting Tailscale.app..."
  open -a Tailscale
  sleep 3
fi

# --- 3. ログイン状態確認 ---
if "${TAILSCALE_CLI}" status &>/dev/null; then
  util::info "Tailscale: already connected."
else
  util::warning "Tailscale: not connected. Starting login..."
  "${TAILSCALE_CLI}" login
  util::info "Please complete authentication in your browser."
  util::confirm "Tailscale login completed?"
  if [[ $? -ne 0 ]]; then
    util::warning "Tailscale login skipped. You can run 'tailscale login' later."
    return 1
  fi
  # FORCE=1 時を含め、ログイン後に実際の接続状態を検証
  if ! "${TAILSCALE_CLI}" status &>/dev/null; then
    util::error "Tailscale is still not connected after login."
    return 1
  fi
fi

# --- 4. 接続情報表示 ---
util::info "Tailscale status:"
"${TAILSCALE_CLI}" status

TAILSCALE_IP=$("${TAILSCALE_CLI}" ip -4 2>/dev/null)
if [[ -n "${TAILSCALE_IP}" ]]; then
  util::info "Your Tailscale IPv4: ${TAILSCALE_IP}"
fi

util::info "Tailscale setup complete."
