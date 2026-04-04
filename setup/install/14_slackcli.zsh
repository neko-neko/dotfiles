#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install slackcli...'

local install_dir="${HOME}/.local/bin"
mkdir -p "${install_dir}"

# アーキテクチャ判定
local arch=$(uname -m)
local binary_name="slackcli-macos-arm64"
if [[ "${arch}" = "x86_64" ]]; then
  binary_name="slackcli-macos"
fi

# 最新バージョン取得
local latest_version=$(curl -s https://api.github.com/repos/shaharia-lab/slackcli/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
if [[ -z "${latest_version}" ]]; then
  util::error "failed to fetch latest version"
  return 1
fi

# 現在のバージョンと比較（インストール済みの場合）
if command -v slackcli &>/dev/null; then
  local current_version=$(slackcli --version 2>/dev/null)
  if [[ "${current_version}" = "${latest_version}" ]]; then
    util::info "slackcli is already up to date (v${latest_version})"
    return 0
  fi
  util::info "updating slackcli: v${current_version} -> v${latest_version}"
fi

# ダウンロード & 配置
local url="https://github.com/shaharia-lab/slackcli/releases/download/v${latest_version}/${binary_name}"
util::info "downloading from ${url}"

curl -fSL -o "${install_dir}/slackcli" "${url}"
if [[ $? -ne 0 ]]; then
  util::error "failed to download slackcli"
  return 1
fi

chmod +x "${install_dir}/slackcli"
util::info "slackcli v${latest_version} installed to ${install_dir}/slackcli"
