# Home Network Mac mini Setup Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `~/.dotfiles/setup/layers/home-network/` を新設し、Mac mini 上で Tailscale subnet router + AdGuard Home + Syncthing + Splashtop Streamer を一括セットアップできる独立レイヤーを実装する。

**Architecture:** 既存の共通セットアップ（`setup/install.zsh` + `setup/install/*.zsh`）には一切手を入れず、`setup/layers/home-network/install.zsh` を独立エントリポイントとして追加。4 サービスはそれぞれ `install/[10-40]_*.zsh` に責務分離。設定ファイルはインライン heredoc + `op inject` で生成し、secret は 1Password 経由で冪等管理。

**Tech Stack:** zsh, Homebrew (formula/cask), Tailscale CLI, AdGuard Home, Syncthing REST API, 1Password CLI (op), launchd (brew services), htpasswd (macOS 標準)

**Design spec:** `docs/superpowers/specs/2026-04-20-home-network-mac-mini-setup-design.md`

## Environment Assumptions

- 実装コード（zsh スクリプト）作成は現在の MacBook 上で完結する
- 副作用を伴う実行検証（`brew install`、`sudo tailscale up` 等）は Mac mini 本体でのみ可能。この plan は**コード作成まで**を対象とし、実環境検証は plan 外
- テスト手段: `zsh -n <file>` による構文チェック、`shellcheck --shell=bash <file>` による静的解析、`source` 後の関数定義検証
- 既存の `setup/util.zsh` の `util::info / util::error / util::warning / util::confirm` を再利用する

---

### Task 1: 共通 Brewfile に 1Password Desktop cask を追加

**Files:**
- Modify: `Brewfile:165`（既存 `cask 'karabiner-elements'` の直前、cask 群のアルファベット順に挿入）

- [ ] **Step 1: 現状の cask セクション行番号を確認**

Run: `grep -n "^cask '1password-cli'" Brewfile`
Expected: `144:cask '1password-cli'` のような行が返る

- [ ] **Step 2: `cask '1password'` を追加**

Edit `Brewfile`：既存の `cask '1password-cli'` の**次の行**に `cask '1password'` を挿入する。

変更前:
```ruby
cask '1password-cli'
cask 'android-studio'
```

変更後:
```ruby
cask '1password-cli'
cask '1password'
cask 'android-studio'
```

- [ ] **Step 3: 構文妥当性の smoke test**

Run: `brew bundle check --file=Brewfile --verbose 2>&1 | tail -5`
Expected: エラーなく進行（未インストール項目のリストが出るのは想定内）

- [ ] **Step 4: Commit**

```bash
git add Brewfile
git commit -m "feat(brewfile): add 1password desktop cask"
```

---

### Task 2: home-network レイヤーのディレクトリ骨格を作成

**Files:**
- Create: `setup/layers/home-network/` ディレクトリ構造

- [ ] **Step 1: ディレクトリ作成**

Run:
```bash
mkdir -p setup/layers/home-network/lib
mkdir -p setup/layers/home-network/install
```

- [ ] **Step 2: 確認**

Run: `ls -la setup/layers/home-network/`
Expected: `lib/` と `install/` が存在する

- [ ] **Step 3: Commit（空ディレクトリは git に乗らないので、後続のファイル作成まで commit 不要。このタスクでは commit しない）**

---

### Task 3: `.gitignore` に `config.local.zsh` パターンを追加

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: .gitignore 末尾にパターン追加**

Edit `.gitignore`：末尾に以下を追加。

```
# home-network layer local overrides
setup/layers/*/config.local.zsh
```

- [ ] **Step 2: パターン確認**

Run: `git check-ignore -v setup/layers/home-network/config.local.zsh`
Expected: パターンがマッチして対象ファイルが ignore 対象であることが表示される（ファイル自体は未作成でも ignore ルールの検証は可能）

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore(gitignore): ignore layer-local override configs"
```

---

### Task 4: `config.zsh` (既定値) を作成

**Files:**
- Create: `setup/layers/home-network/config.zsh`

- [ ] **Step 1: ファイル作成**

Create `setup/layers/home-network/config.zsh`:

```zsh
#!/bin/zsh
# home-network layer 既定値。secret は含めない。
# 端末固有値は config.local.zsh で上書きすること。

# 1Password vault / item 名
OP_VAULT="home-network"
OP_ITEM_TAILSCALE_AUTHKEY="tailscale-authkey"
OP_ITEM_ADGUARD_ADMIN="adguard-admin"
OP_ITEM_SYNCTHING_GUI="syncthing-gui"
OP_ITEM_SYNCTHING_APIKEY="syncthing-apikey"
OP_ITEM_SYNCTHING_PEER_MACBOOK="syncthing-peer-macbook"

# AdGuard Home
ADGUARD_ADMIN_USER="admin"
ADGUARD_WEB_ADDRESS="0.0.0.0:3000"
ADGUARD_DNS_BIND="0.0.0.0"
ADGUARD_DNS_PORT="53"
ADGUARD_UPSTREAM_DNS=(
  "1.1.1.1"
  "1.0.0.1"
  "8.8.8.8"
)
ADGUARD_FILTERS=(
  "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt|AdGuard DNS filter"
  "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus|Peter Lowe's List"
)

# Syncthing
SYNCTHING_GUI_USER="admin"
SYNCTHING_GUI_ADDRESS="127.0.0.1:8384"
SYNCTHING_CLAUDE_FOLDER_ID="claude-home"
SYNCTHING_CLAUDE_FOLDER_LABEL="Claude Home"
SYNCTHING_CLAUDE_FOLDER_PATH="${HOME}/.claude"
SYNCTHING_CONFIG_DIR="${HOME}/Library/Application Support/Syncthing"

# Tailscale: advertise-routes に使う LAN CIDR は config.local.zsh で必須設定
# HOME_LAN_CIDR="192.168.10.0/24"
HOME_LAN_CIDR="${HOME_LAN_CIDR:-}"
```

- [ ] **Step 2: zsh 構文チェック**

Run: `zsh -n setup/layers/home-network/config.zsh`
Expected: エラー無し（出力なし）

- [ ] **Step 3: source 可能性検証**

Run: `zsh -c 'source setup/layers/home-network/config.zsh && echo "OP_VAULT=$OP_VAULT"'`
Expected: `OP_VAULT=home-network`

- [ ] **Step 4: Commit**

```bash
git add setup/layers/home-network/config.zsh
git commit -m "feat(home-network): add layer default config"
```

---

### Task 5: `config.local.zsh.example` (雛形) を作成

**Files:**
- Create: `setup/layers/home-network/config.local.zsh.example`

- [ ] **Step 1: ファイル作成**

Create `setup/layers/home-network/config.local.zsh.example`:

```zsh
#!/bin/zsh
# home-network layer 端末固有値の雛形。
# このファイルを config.local.zsh にコピーして編集すること。
#   cp config.local.zsh.example config.local.zsh

# Tailscale Subnet Router が advertise する LAN CIDR
# 自宅 LAN のサブネットを指定する（ルーター DHCP の範囲と一致させる）
HOME_LAN_CIDR="192.168.10.0/24"
```

- [ ] **Step 2: 構文チェック**

Run: `zsh -n setup/layers/home-network/config.local.zsh.example`
Expected: エラー無し

- [ ] **Step 3: Commit**

```bash
git add setup/layers/home-network/config.local.zsh.example
git commit -m "feat(home-network): add local config template"
```

---

### Task 6: `lib/op.zsh` 1Password 冪等ヘルパーを作成

**Files:**
- Create: `setup/layers/home-network/lib/op.zsh`

- [ ] **Step 1: ファイル作成**

Create `setup/layers/home-network/lib/op.zsh`:

```zsh
#!/bin/zsh
# 1Password CLI (op) 用の冪等ヘルパー関数群。
# 依存: op >=2.13, util.zsh (util::error / util::info)

op::ensure_signed_in() {
  if ! op whoami &>/dev/null; then
    util::error "op CLI is not signed in."
    util::error "Run 'op signin' or enable 1Password Desktop app integration first."
    return 1
  fi
  return 0
}

# 冪等: title の Login item が vault に無ければ --generate-password で作成。
# 既存なら何もしない。戻り値は op item の状態に関係なく 0。
# 使い方: op::ensure_login_item "adguard-admin" "home-network"
op::ensure_login_item() {
  local title="$1"
  local vault="$2"
  local recipe="${3:-letters,digits,symbols,32}"

  if [[ -z "$title" || -z "$vault" ]]; then
    util::error "op::ensure_login_item requires title and vault"
    return 1
  fi

  if op item get "$title" --vault "$vault" &>/dev/null; then
    util::info "op item '$title' already exists in vault '$vault', skipping creation"
    return 0
  fi

  util::info "creating op item '$title' in vault '$vault'"
  op item create \
    --category Login \
    --title "$title" \
    --vault "$vault" \
    --generate-password="$recipe" \
    >/dev/null
}

# 既存 item の存在確認だけを行う。未存在ならエラー付きで 1 を返す。
# 手動登録が前提の item (tailscale-authkey, syncthing-peer-macbook) 用。
op::require_item() {
  local title="$1"
  local vault="$2"

  if ! op item get "$title" --vault "$vault" &>/dev/null; then
    util::error "required op item '$title' not found in vault '$vault'"
    util::error "register it manually before running this script"
    return 1
  fi
  return 0
}

# secret reference から値を取得する。
# 例: op::read "op://home-network/adguard-admin/password"
op::read() {
  local ref="$1"
  op read "$ref"
}

# field の書き込み。既存値と同じなら skip (冪等)。
# 例: op::set_field "syncthing-apikey" "home-network" "password" "xxx"
op::set_field() {
  local title="$1"
  local vault="$2"
  local field="$3"
  local value="$4"

  local current
  current=$(op item get "$title" --vault "$vault" --fields "$field" --reveal 2>/dev/null)
  if [[ "$current" == "$value" ]]; then
    return 0
  fi

  op item edit "$title" --vault "$vault" "${field}=${value}" >/dev/null
}
```

- [ ] **Step 2: 構文チェック**

Run: `zsh -n setup/layers/home-network/lib/op.zsh`
Expected: エラー無し

- [ ] **Step 3: 関数定義検証**

Run:
```bash
zsh -c '
  source setup/util.zsh
  source setup/layers/home-network/lib/op.zsh
  typeset -f op::ensure_signed_in op::ensure_login_item op::require_item op::read op::set_field \
    | grep -c "^op::" 
'
```
Expected: `5` が出力される（5 関数定義）

- [ ] **Step 4: Commit**

```bash
git add setup/layers/home-network/lib/op.zsh
git commit -m "feat(home-network): add 1password idempotent helpers"
```

---

### Task 7: `lib/service.zsh` brew services ヘルパーを作成

**Files:**
- Create: `setup/layers/home-network/lib/service.zsh`

- [ ] **Step 1: ファイル作成**

Create `setup/layers/home-network/lib/service.zsh`:

```zsh
#!/bin/zsh
# brew services 用の冪等ヘルパー。
# 依存: util.zsh (util::info / util::error)

# name の brew service が started 状態でなければ start する。
# sudo_required=true の場合は sudo 経由で起動。
# 使い方: service::ensure_started "adguardhome" true
service::ensure_started() {
  local name="$1"
  local sudo_required="${2:-false}"

  local status
  if [[ "$sudo_required" == "true" ]]; then
    status=$(sudo brew services list 2>/dev/null | awk -v n="$name" '$1==n {print $2}')
  else
    status=$(brew services list 2>/dev/null | awk -v n="$name" '$1==n {print $2}')
  fi

  if [[ "$status" == "started" ]]; then
    util::info "brew service '$name' is already started"
    return 0
  fi

  util::info "starting brew service '$name'"
  if [[ "$sudo_required" == "true" ]]; then
    sudo brew services start "$name"
  else
    brew services start "$name"
  fi
}

# name の brew service を restart する（状態問わず）。
service::restart() {
  local name="$1"
  local sudo_required="${2:-false}"

  util::info "restarting brew service '$name'"
  if [[ "$sudo_required" == "true" ]]; then
    sudo brew services restart "$name"
  else
    brew services restart "$name"
  fi
}
```

- [ ] **Step 2: 構文チェック**

Run: `zsh -n setup/layers/home-network/lib/service.zsh`
Expected: エラー無し

- [ ] **Step 3: 関数定義検証**

Run:
```bash
zsh -c '
  source setup/util.zsh
  source setup/layers/home-network/lib/service.zsh
  typeset -f service::ensure_started service::restart | grep -c "^service::"
'
```
Expected: `2`

- [ ] **Step 4: Commit**

```bash
git add setup/layers/home-network/lib/service.zsh
git commit -m "feat(home-network): add brew services idempotent helpers"
```

---

### Task 8: home-network レイヤー専用 Brewfile を作成

**Files:**
- Create: `setup/layers/home-network/Brewfile`

- [ ] **Step 1: ファイル作成**

Create `setup/layers/home-network/Brewfile`:

```ruby
# home-network layer: Mac mini 専用パッケージ
# 共通 Brewfile とは別に管理する。

# Tailscale subnet router (ヘッドレス用、cask ではなく formula)
brew 'tailscale'

# AdGuard Home (tailnet 向け DNS + 広告ブロック)
brew 'adguardhome'

# Syncthing (~/.claude 同期)
brew 'syncthing'

# Splashtop Streamer (iPad からの遠隔操作の受信側)
cask 'splashtop-streamer'
```

- [ ] **Step 2: Brewfile 構文妥当性の smoke test**

Run: `brew bundle check --file=setup/layers/home-network/Brewfile --verbose 2>&1 | head -10`
Expected: 各項目の install 可否が表示される（未インストールの旨はエラーではない）

- [ ] **Step 3: Commit**

```bash
git add setup/layers/home-network/Brewfile
git commit -m "feat(home-network): add layer-specific brewfile"
```

---

### Task 9: `install/00_preflight.zsh` 前提チェックを作成

**Files:**
- Create: `setup/layers/home-network/install/00_preflight.zsh`

- [ ] **Step 1: ファイル作成**

Create `setup/layers/home-network/install/00_preflight.zsh`:

```zsh
#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/op.zsh

util::info 'preflight: home-network layer...'

# 1Password CLI 認証確認
op::ensure_signed_in || exit 1

# config.local.zsh の存在と HOME_LAN_CIDR 設定の確認
local local_config="${HOME}/.dotfiles/setup/layers/home-network/config.local.zsh"
if [[ ! -f "$local_config" ]]; then
  util::error "config.local.zsh not found at $local_config"
  util::error "cp config.local.zsh.example config.local.zsh and edit it first"
  exit 1
fi

source ${HOME}/.dotfiles/setup/layers/home-network/config.zsh
source "$local_config"

if [[ -z "$HOME_LAN_CIDR" ]]; then
  util::error "HOME_LAN_CIDR is not set in config.local.zsh"
  exit 1
fi

# sudo 認証先取り（後続の sudo brew services を対話なしに通すため）
util::info 'caching sudo credential...'
sudo -v || exit 1

util::info 'preflight passed'
```

- [ ] **Step 2: 構文チェック**

Run: `zsh -n setup/layers/home-network/install/00_preflight.zsh`
Expected: エラー無し

- [ ] **Step 3: Commit**

```bash
git add setup/layers/home-network/install/00_preflight.zsh
git commit -m "feat(home-network): add preflight check script"
```

---

### Task 10: `install/10_tailscale.zsh` Tailscale subnet router セットアップを作成

**Files:**
- Create: `setup/layers/home-network/install/10_tailscale.zsh`

- [ ] **Step 1: ファイル作成**

Create `setup/layers/home-network/install/10_tailscale.zsh`:

```zsh
#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/op.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/service.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/config.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/config.local.zsh

util::info 'install tailscale (formula)...'
brew install --formula tailscale

# Tailscale auth-key は手動発行前提。未登録ならここで abort。
op::require_item "$OP_ITEM_TAILSCALE_AUTHKEY" "$OP_VAULT" || {
  util::error "register tailscale auth-key in 1Password first:"
  util::error "  1. visit https://login.tailscale.com/admin/settings/keys"
  util::error "  2. generate a reusable=false, ephemeral=false, pre-approved=true key"
  util::error "     with tag 'tag:home-mac-mini'"
  util::error "  3. save as Login item '$OP_ITEM_TAILSCALE_AUTHKEY' in vault '$OP_VAULT'"
  exit 1
}

service::ensure_started tailscale true

local authkey
authkey=$(op::read "op://${OP_VAULT}/${OP_ITEM_TAILSCALE_AUTHKEY}/password")

util::info "tailscale up --advertise-routes=$HOME_LAN_CIDR"
sudo tailscale up \
  --advertise-routes="$HOME_LAN_CIDR" \
  --auth-key="$authkey" \
  --accept-dns=false \
  --reset

util::info 'tailscale subnet router is up'
sudo tailscale status | head -5
```

- [ ] **Step 2: 構文チェック**

Run: `zsh -n setup/layers/home-network/install/10_tailscale.zsh`
Expected: エラー無し

- [ ] **Step 3: shellcheck**

Run: `shellcheck --shell=bash --severity=error setup/layers/home-network/install/10_tailscale.zsh 2>&1 | head -20`
Expected: severity=error の指摘なし（warning の `local` 使用は zsh スクリプトのため許容）

- [ ] **Step 4: Commit**

```bash
git add setup/layers/home-network/install/10_tailscale.zsh
git commit -m "feat(home-network): add tailscale subnet router setup"
```

---

### Task 11: `install/20_adguard.zsh` AdGuard Home セットアップを作成

**Files:**
- Create: `setup/layers/home-network/install/20_adguard.zsh`

- [ ] **Step 1: ファイル作成**

Create `setup/layers/home-network/install/20_adguard.zsh`:

```zsh
#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/op.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/service.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/config.zsh

# bcrypt ハッシュ生成 (macOS 同梱の /usr/sbin/htpasswd)
gen_bcrypt() {
  local plain="$1"
  htpasswd -B -C 10 -n -b "$ADGUARD_ADMIN_USER" "$plain" | cut -d: -f2
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
```

- [ ] **Step 2: 構文チェック**

Run: `zsh -n setup/layers/home-network/install/20_adguard.zsh`
Expected: エラー無し

- [ ] **Step 3: gen_bcrypt の局所テスト（Mac mini 到達前でも動く）**

Run:
```bash
zsh -c '
  ADGUARD_ADMIN_USER=admin
  source <(sed -n "/^gen_bcrypt/,/^}/p" setup/layers/home-network/install/20_adguard.zsh)
  result=$(gen_bcrypt "testpass")
  [[ "$result" =~ ^\\\$2y\\\$10\\\$ ]] && echo "OK: $result" || { echo "FAIL: $result"; exit 1; }
'
```
Expected: `OK: $2y$10$...` が出力される

- [ ] **Step 4: Commit**

```bash
git add setup/layers/home-network/install/20_adguard.zsh
git commit -m "feat(home-network): add adguard home setup"
```

---

### Task 12: `install/30_syncthing.zsh` Syncthing セットアップを作成

**Files:**
- Create: `setup/layers/home-network/install/30_syncthing.zsh`

- [ ] **Step 1: ファイル作成**

Create `setup/layers/home-network/install/30_syncthing.zsh`:

```zsh
#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/op.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/service.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/config.zsh

util::info 'install syncthing...'
brew install syncthing

# 初回起動: config.xml が無ければ syncthing を start して自動生成させる
local config_xml="${SYNCTHING_CONFIG_DIR}/config.xml"
if [[ ! -f "$config_xml" ]]; then
  util::info 'first run: starting syncthing to generate config.xml'
  service::ensure_started syncthing false

  local waited=0
  while [[ ! -f "$config_xml" && $waited -lt 30 ]]; do
    sleep 1
    ((waited++))
  done

  if [[ ! -f "$config_xml" ]]; then
    util::error "syncthing config.xml was not created within 30s"
    exit 1
  fi
  util::info "config.xml created after ${waited}s"
else
  service::ensure_started syncthing false
  # API が応答するまで少し待つ
  sleep 2
fi

# config.xml から API key を抽出
local apikey
apikey=$(grep -oE '<apikey>[^<]+</apikey>' "$config_xml" | sed -E 's|<apikey>(.*)</apikey>|\1|')
if [[ -z "$apikey" ]]; then
  util::error "failed to extract apikey from $config_xml"
  exit 1
fi

# API key を 1Password に書き戻し（冪等、既存と同値なら skip）
if ! op::require_item "$OP_ITEM_SYNCTHING_APIKEY" "$OP_VAULT" 2>/dev/null; then
  util::info "creating op item '$OP_ITEM_SYNCTHING_APIKEY'"
  op item create \
    --category Password \
    --title "$OP_ITEM_SYNCTHING_APIKEY" \
    --vault "$OP_VAULT" \
    "password=$apikey" \
    >/dev/null
else
  op::set_field "$OP_ITEM_SYNCTHING_APIKEY" "$OP_VAULT" "password" "$apikey"
fi

# GUI パスワード item を冪等生成
op::ensure_login_item "$OP_ITEM_SYNCTHING_GUI" "$OP_VAULT"

local gui_pw
gui_pw=$(op::read "op://${OP_VAULT}/${OP_ITEM_SYNCTHING_GUI}/password")

# 対向デバイス (MacBook) の Device ID を取得（手動登録前提）
op::require_item "$OP_ITEM_SYNCTHING_PEER_MACBOOK" "$OP_VAULT" || {
  util::error "register MacBook's syncthing device id in 1password:"
  util::error "  1. on MacBook: syncthing cli show system | grep myID"
  util::error "  2. save as Secure Note '$OP_ITEM_SYNCTHING_PEER_MACBOOK' in vault '$OP_VAULT'"
  util::error "  3. put the device id in 'notesPlain' field"
  exit 1
}

local peer_id
peer_id=$(op item get "$OP_ITEM_SYNCTHING_PEER_MACBOOK" --vault "$OP_VAULT" --fields notesPlain --reveal)
peer_id=$(echo "$peer_id" | tr -d '[:space:]')
if [[ -z "$peer_id" ]]; then
  util::error "peer device id not found in item $OP_ITEM_SYNCTHING_PEER_MACBOOK"
  exit 1
fi

# REST API で設定を更新
local api_base="http://${SYNCTHING_GUI_ADDRESS}"
local curl_opts=(-sS -H "X-API-Key: $apikey" -H "Content-Type: application/json")

util::info "registering peer device $peer_id via REST API"
curl "${curl_opts[@]}" -X PUT "${api_base}/rest/config/devices/${peer_id}" -d @- <<EOF
{
  "deviceID": "${peer_id}",
  "name": "MacBook",
  "addresses": ["dynamic"],
  "compression": "metadata",
  "introducer": false,
  "paused": false
}
EOF

util::info "registering folder ${SYNCTHING_CLAUDE_FOLDER_ID} via REST API"
curl "${curl_opts[@]}" -X PUT "${api_base}/rest/config/folders/${SYNCTHING_CLAUDE_FOLDER_ID}" -d @- <<EOF
{
  "id": "${SYNCTHING_CLAUDE_FOLDER_ID}",
  "label": "${SYNCTHING_CLAUDE_FOLDER_LABEL}",
  "path": "${SYNCTHING_CLAUDE_FOLDER_PATH}",
  "type": "sendreceive",
  "devices": [
    {"deviceID": "${peer_id}"}
  ],
  "rescanIntervalS": 3600,
  "fsWatcherEnabled": true,
  "fsWatcherDelayS": 10
}
EOF

# .stignore を生成
util::info "writing $SYNCTHING_CLAUDE_FOLDER_PATH/.stignore"
cat > "${SYNCTHING_CLAUDE_FOLDER_PATH}/.stignore" <<'EOF'
// home-network layer Claude home sync excludes
plugins
telemetry
cache
file-history
shell-snapshots
ide
statsig
session-env
chrome
debug
usage-data
downloads
paste-cache
*.bak
*.backup.*
.DS_Store
EOF

# GUI パスワードを設定（REST API）
util::info "setting syncthing GUI credentials"
curl "${curl_opts[@]}" -X PUT "${api_base}/rest/config/gui" -d @- <<EOF
{
  "enabled": true,
  "address": "${SYNCTHING_GUI_ADDRESS}",
  "user": "${SYNCTHING_GUI_USER}",
  "password": "${gui_pw}",
  "useTLS": false
}
EOF

service::restart syncthing false

util::info 'syncthing configured'
util::info "gui: http://${SYNCTHING_GUI_ADDRESS}"
util::info "gui user: ${SYNCTHING_GUI_USER}"
util::info "gui password: stored in 1password: op://${OP_VAULT}/${OP_ITEM_SYNCTHING_GUI}/password"
util::info "NEXT: on MacBook, accept this device's pairing request and approve the '${SYNCTHING_CLAUDE_FOLDER_ID}' folder share"
```

- [ ] **Step 2: 構文チェック**

Run: `zsh -n setup/layers/home-network/install/30_syncthing.zsh`
Expected: エラー無し

- [ ] **Step 3: Commit**

```bash
git add setup/layers/home-network/install/30_syncthing.zsh
git commit -m "feat(home-network): add syncthing setup with rest api"
```

---

### Task 13: `install/40_splashtop.zsh` Splashtop Streamer セットアップを作成

**Files:**
- Create: `setup/layers/home-network/install/40_splashtop.zsh`

- [ ] **Step 1: ファイル作成**

Create `setup/layers/home-network/install/40_splashtop.zsh`:

```zsh
#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install splashtop streamer...'
brew install --cask splashtop-streamer

util::info 'launching splashtop streamer for manual login'
open -a "Splashtop Streamer" || util::warning "failed to launch Splashtop Streamer.app"

util::warning 'MANUAL STEP:'
util::warning '  1. sign in with your Splashtop account in the Streamer app'
util::warning '  2. disable auto-update in the Streamer preferences (to avoid surprise dialogs)'
util::warning '  3. on iPad: install Splashtop Business/Personal from App Store'
util::warning '  4. on iPad: sign in with the same Splashtop account'
```

- [ ] **Step 2: 構文チェック**

Run: `zsh -n setup/layers/home-network/install/40_splashtop.zsh`
Expected: エラー無し

- [ ] **Step 3: Commit**

```bash
git add setup/layers/home-network/install/40_splashtop.zsh
git commit -m "feat(home-network): add splashtop streamer setup"
```

---

### Task 14: レイヤーエントリポイント `install.zsh` を作成

**Files:**
- Create: `setup/layers/home-network/install.zsh`

- [ ] **Step 1: ファイル作成**

Create `setup/layers/home-network/install.zsh`:

```zsh
#!/bin/zsh
# home-network layer entrypoint
# prerequisite: 共通 Brewfile / setup/install.zsh が完了している Mac mini 上で実行

set -e

local layer_dir="${HOME}/.dotfiles/setup/layers/home-network"
source ${HOME}/.dotfiles/setup/util.zsh

util::info '=== home-network layer setup ==='

# Brewfile
util::confirm "install home-network Brewfile?"
if [[ $? = 0 ]]; then
  brew bundle --file "${layer_dir}/Brewfile"
fi

# install scripts (番号順)
for script in $(\ls "${layer_dir}/install" | sort); do
  util::confirm "run setup script ${script}?"
  if [[ $? = 0 ]]; then
    . "${layer_dir}/install/${script}"
  fi
done

util::info '=== home-network layer setup complete ==='
util::info 'see README.md for post-install steps'
```

- [ ] **Step 2: 実行権限付与**

Run: `chmod +x setup/layers/home-network/install.zsh`

- [ ] **Step 3: 構文チェック**

Run: `zsh -n setup/layers/home-network/install.zsh`
Expected: エラー無し

- [ ] **Step 4: Commit**

```bash
git add setup/layers/home-network/install.zsh
git commit -m "feat(home-network): add layer entrypoint script"
```

---

### Task 15: README を作成

**Files:**
- Create: `setup/layers/home-network/README.md`

- [ ] **Step 1: ファイル作成**

Create `setup/layers/home-network/README.md`:

```markdown
# Home Network Layer for Mac mini

自宅 LAN 配下の Mac mini に以下 4 機能を一括セットアップするレイヤー。

- Tailscale Subnet Router (tailnet から LAN 全体にアクセス)
- AdGuard Home (tailnet 全端末向け広告ブロック DNS)
- Syncthing (`~/.claude` を MacBook と双方向同期)
- Splashtop Streamer (iPad Pro からの遠隔操作受信)

## 前提

- 共通 `./setup/install.zsh` による基盤セットアップが完了している
- 現在のユーザーで運用する（専用ユーザーは作らない）

## 一度だけ手動で済ませるステップ

1. **1Password Desktop app** を起動 → サインイン → Touch ID 有効化
   - Settings → Developer → "Integrate with 1Password CLI" を有効化
2. **op CLI 認証確認**: `op whoami` が成功すること
3. **Vault 作成**: 1Password で `home-network` という Vault を作成
4. **Tailscale auth-key 発行**:
   1. <https://login.tailscale.com/admin/settings/keys> で
      - Reusable: **false**
      - Ephemeral: **false**
      - Pre-approved: **true**
      - Tags: `tag:home-mac-mini`
      で発行
   2. `home-network` Vault に `tailscale-authkey` という Login item を作り、
      password フィールドに上記 key を貼り付ける
5. **Tailscale ACL 設定** (<https://login.tailscale.com/admin/acls/file>):
   ```json
   {
     "tagOwners": { "tag:home-mac-mini": ["autogroup:admin"] },
     "autoApprovers": {
       "routes": { "192.168.x.0/24": ["tag:home-mac-mini"] }
     }
   }
   ```
   `192.168.x.0/24` は LAN 実サブネットに置換。
6. **MacBook の Syncthing Device ID** を取得:
   ```bash
   syncthing cli show system | grep myID
   ```
   1Password `home-network` Vault に `syncthing-peer-macbook` という Secure Note を作り、
   `notesPlain` フィールドに Device ID を貼り付け。

## ローカル設定

```bash
cp setup/layers/home-network/config.local.zsh.example \
   setup/layers/home-network/config.local.zsh
# 編集: HOME_LAN_CIDR=192.168.x.0/24 を実サブネットに
```

## 実行

```bash
./setup/layers/home-network/install.zsh
```

途中で sudo パスワードを 1 度問われる（`00_preflight.zsh` の `sudo -v`）。
各 install/*.zsh は `(y/N)` プロンプトで確認。

## 実行後の手動完了ステップ

1. **Splashtop Streamer**: アプリが開くので Splashtop アカウントでサインイン、自動アップデートを無効化
2. **MacBook 側の Syncthing**:
   - Web UI (`http://127.0.0.1:8384`) で Add Remote Device → Mac mini の Device ID を入力
   - Mac mini 側 Web UI で Pending Devices を承認、フォルダ共有も承認
3. **動作検証**:
   - `tailscale status` で Mac mini と Subnet Routes が `connected`
   - `dig @<mac-mini-tailscale-ip> example.com` で解決される
   - `dig @<mac-mini-tailscale-ip> doubleclick.net` でブロック（NXDOMAIN or 0.0.0.0）
   - iPad の Splashtop から Mac mini に接続できる
   - MacBook 側 `~/.claude/projects/` に Mac mini のセッションが現れる

## 運用上の注意

- **Mac mini と MacBook で Claude Code を同時起動しない**。Syncthing conflict file が発生し、
  `projects/*.jsonl` のセッション履歴が分岐する
- AdGuard のブロックリスト等の変更は Mac mini の Web UI (`http://<ip>:3000`) で実施
- Tailscale auth-key 期限切れ時は 1Password の item を更新して `10_tailscale.zsh` を再実行

## 非サポート

- 移行アシスタントの自動化
- macOS スリープ等の OS 設定（共通 `29_macos.zsh` の責務）
- iPad 側 Splashtop アプリ設定
```

- [ ] **Step 2: 内容確認**

Run: `wc -l setup/layers/home-network/README.md`
Expected: 70-100 行程度

- [ ] **Step 3: Commit**

```bash
git add setup/layers/home-network/README.md
git commit -m "docs(home-network): add layer readme with manual setup steps"
```

---

### Task 16: 全体 smoke test — レイヤー全ファイルの構文チェックと関数定義確認

**Files:**
- None (検証のみ)

- [ ] **Step 1: 全 zsh ファイルの構文チェック**

Run:
```bash
find setup/layers/home-network -name '*.zsh' -print0 | \
  xargs -0 -I{} zsh -n {} && echo "ALL OK"
```
Expected: `ALL OK` が最後に出る

- [ ] **Step 2: install.zsh が install/ 以下を正しく列挙するか dry-run**

Run:
```bash
\ls setup/layers/home-network/install | sort
```
Expected:
```
00_preflight.zsh
10_tailscale.zsh
20_adguard.zsh
30_syncthing.zsh
40_splashtop.zsh
```

- [ ] **Step 3: lib/ の関数が全て定義されているか確認**

Run:
```bash
zsh -c '
  source setup/util.zsh
  source setup/layers/home-network/lib/op.zsh
  source setup/layers/home-network/lib/service.zsh
  typeset -f op::ensure_signed_in op::ensure_login_item op::require_item op::read op::set_field \
             service::ensure_started service::restart \
    | grep -cE "^(op|service)::"
'
```
Expected: `7`

- [ ] **Step 4: 共通 Brewfile に `cask '1password'` が含まれているか確認**

Run: `grep "^cask '1password'$" Brewfile`
Expected: `cask '1password'` が 1 行返る

- [ ] **Step 5: .gitignore に local config パターンが含まれているか確認**

Run: `git check-ignore -v setup/layers/home-network/config.local.zsh 2>&1`
Expected: パターンにマッチして ignore される旨が出る

- [ ] **Step 6: Commit（検証だけなので、このタスクでは commit しない）**

---

## 実行完了条件

以下が全て true:

- `setup/layers/home-network/` 配下に 11 ファイル（Brewfile, install.zsh, README.md, config.zsh, config.local.zsh.example, lib/op.zsh, lib/service.zsh, install/00_preflight.zsh, install/10_tailscale.zsh, install/20_adguard.zsh, install/30_syncthing.zsh, install/40_splashtop.zsh）が存在
- 全 zsh ファイルが `zsh -n` 構文チェックをパス
- 共通 Brewfile に `cask '1password'` が追加されている
- `.gitignore` に layer 専用 config.local.zsh の除外ルールが追加されている
- 各タスクごとに個別 commit が作られている（Task 16 除く）

## 非対象（plan 外の手動検証）

以下は Mac mini 本体でのみ検証可能、plan の完了条件に含めない:

- `brew install --formula tailscale` の成功
- `sudo tailscale up` による tailnet 参加と subnet router 機能
- AdGuard Home の port 53 listen
- Syncthing GUI への REST API 操作の成否
- Splashtop Streamer の GUI ログイン
- iPad からの接続
- `~/.claude/projects/` の双方向同期
