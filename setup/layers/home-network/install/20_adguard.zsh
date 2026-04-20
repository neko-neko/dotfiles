#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/op.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/service.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/config.zsh

# bcrypt ハッシュ生成 (macOS 同梱の /usr/sbin/htpasswd)
# -i: パスワードを stdin から読む (ps から見える -b "$plain" を避けるため)
gen_bcrypt() {
  local plain="$1"
  /usr/sbin/htpasswd -B -C 10 -n -i "$ADGUARD_ADMIN_USER" <<< "$plain" | cut -d: -f2
}

util::info 'install adguardhome...'
brew install adguardhome

# admin パスワード item を冪等生成
op::ensure_login_item "$OP_ITEM_ADGUARD_ADMIN" "$OP_VAULT"

local plain_pw
plain_pw=$(op::read "op://${OP_VAULT}/${OP_ITEM_ADGUARD_ADMIN}/password")
if [[ -z "$plain_pw" ]]; then
  util::error "failed to read adguard admin password from 1password"
  exit 1
fi

local bcrypt_hash
bcrypt_hash=$(gen_bcrypt "$plain_pw")

# 設定ファイル配置先
local brew_prefix
brew_prefix=$(brew --prefix)
local conf_dir="${brew_prefix}/etc/AdGuardHome"
local conf_file="${conf_dir}/AdGuardHome.yaml"

sudo mkdir -p "$conf_dir"

# 既存設定のバックアップ
if [[ -f "$conf_file" ]]; then
  local backup="${conf_file}.bak.$(date +%Y%m%d%H%M%S)"
  util::info "backing up existing config to $backup"
  sudo mv "$conf_file" "$backup"
fi

# filters YAML ブロックを組み立てる
local filters_yaml=""
local i=1
for entry in "${ADGUARD_FILTERS[@]}"; do
  local url="${entry%%|*}"
  local name="${entry##*|}"
  filters_yaml+="  - enabled: true
    url: ${url}
    name: ${name}
    id: ${i}
"
  ((i++))
done

# upstream_dns YAML ブロック
local upstream_yaml=""
for dns in "${ADGUARD_UPSTREAM_DNS[@]}"; do
  upstream_yaml+="    - ${dns}
"
done

util::info "writing $conf_file"
sudo tee "$conf_file" >/dev/null <<EOF
http:
  address: ${ADGUARD_WEB_ADDRESS}
users:
  - name: ${ADGUARD_ADMIN_USER}
    password: ${bcrypt_hash}
dns:
  bind_hosts:
    - ${ADGUARD_DNS_BIND}
  port: ${ADGUARD_DNS_PORT}
  upstream_dns:
${upstream_yaml}
  bootstrap_dns:
    - 1.1.1.1
    - 8.8.8.8
  protection_enabled: true
  filtering_enabled: true
filters:
${filters_yaml}
schema_version: 20
EOF

sudo chown root:wheel "$conf_file"
sudo chmod 0644 "$conf_file"

service::ensure_started adguardhome true

util::info "adguard home started. web ui: http://$(hostname -s).local:3000"
util::info "admin user: ${ADGUARD_ADMIN_USER}"
util::info "admin password: stored in 1password: op://${OP_VAULT}/${OP_ITEM_ADGUARD_ADMIN}/password"
