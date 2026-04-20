# Home Network Mac mini セットアップレイヤー 設計

- 作成日: 2026-04-20
- 対象リポジトリ: `~/.dotfiles`
- 対象端末: 自宅 LAN 内に新規配置する Mac mini
- 関連メモリ: `project_workflow_engine.md`（影響なし、レイヤー独立）

## 1. 目的とスコープ

自宅 LAN スイッチ配下に配置する Mac mini を、以下 4 機能のホームサーバとして構築するためのインストールレイヤーを `~/.dotfiles/setup/` 配下に追加する。

1. **Tailscale Subnet Router** — Mac mini を経由して LAN 内全端末へ tailnet からアクセス可能にする
2. **AdGuard Home** — tailnet 全端末に対して広告ブロック付き DNS を提供する
3. **Syncthing** — `~/.claude` 配下を既存 MacBook と双方向同期し、どの端末でも Claude Code セッションを継続できる状態にする
4. **Splashtop Streamer** — iPad Pro + Magic Keyboard から Mac mini を遠隔操作するための受信側

スクリプトと専用 Brewfile は既存の共通セットアップから物理的に分離して管理する。

## 2. 設計方針（決定事項）

### 2.1 共通セットアップとの関係

**ハイブリッド方式（プロファイル分離）** を採用する。共通の Brewfile と `setup/install/*` は Mac mini でも実行する前提とし、ホームネットワーク用の追加レイヤーを独立した名前空間 `setup/layers/home-network/` に配置する。

### 2.2 エントリポイント

**完全独立** とする。共通の `setup/install.zsh` には一切手を入れない。Mac mini で共通セットアップ完了後に、明示的に `./setup/layers/home-network/install.zsh` を別途実行する。

理由: 共通 install.zsh を Mac mini 以外で実行する際に余計なプロンプトを増やさないため。

### 2.3 設定ファイルの管理方針

**A 案（全自動化志向）の改良版** を採用する。設定ファイルは `op inject` で secret 参照を解決する形で **インライン heredoc により install スクリプト内で生成** する。`.tpl` 別ファイルは作らない（ファイル数増加と LSP 警告ノイズ回避）。

### 2.4 1Password 連携の強度

**B 案（中結合）** を採用する。

- 共有が必要な secret（Tailscale auth-key、Syncthing peer Device ID）は事前に 1Password に手動登録
- 端末固有の admin password（AdGuard 管理者、Syncthing GUI）は `op item create --generate-password` でスクリプト初回実行時に自動生成し 1Password に保存
- 全 op 操作は **冪等** とする：先に `op item get` で存在確認し、無ければ作成、あれば既存値を流用

### 2.5 Syncthing 同期スコープ

**ブラックリスト方式** を採用する。`~/.claude` 全体を 1 つの Syncthing folder として登録し、`.stignore` で以下を除外する。

- `plugins/`（133MB、端末ごとにキャッシュされる）
- `telemetry/`（122MB、端末固有）
- `cache/`、`file-history/`、`shell-snapshots/`、`ide/`、`statsig/`、`session-env/`、`chrome/`、`debug/`、`usage-data/`、`downloads/`
- `*.bak`、`.DS_Store`

### 2.6 排他運用前提

Mac mini と MacBook で Claude Code を**同時起動しない**ことを運用規律として明示する。同時起動した場合 Syncthing が `sync-conflict-...` ファイルを生成し、`projects/*.jsonl` のセッション履歴が分岐するリスクがある。

### 2.7 bcrypt 生成

`/usr/sbin/htpasswd`（macOS 同梱の Apache 由来）を直接使用する。Brewfile への追加依存は導入しない。htpasswd が存在しない環境はサポートしない（macOS 標準環境の前提）。

### 2.8 Tailscale パッケージ選定

`brew install --formula tailscale` を使用する。cask 版（GUI メニューバーアプリ）はサンドボックス制約により subnet router 用途には不適切。

### 2.9 Splashtop パッケージ選定

`splashtop` cask は存在しないため、`splashtop-streamer`（受信側）を採用する。iPad 側のクライアントアプリは App Store 経由で Brewfile スコープ外。

### 2.10 1Password Desktop app の置き場所

`cask '1password'` は **共通 Brewfile** に追加する。CLI (`1password-cli`) が既に共通にあるため一貫性を保つ。

## 3. ディレクトリ構造

```
~/.dotfiles/
├── Brewfile                                    # 共通（cask '1password' を追加）
├── setup/
│   ├── install.zsh                             # 共通（変更なし）
│   ├── install/                                # 共通（変更なし）
│   └── layers/
│       └── home-network/
│           ├── README.md                       # 初期セットアップ手順
│           ├── Brewfile                        # home-network 専用
│           ├── install.zsh                     # レイヤーエントリポイント
│           ├── config.zsh                      # 既定値（vault名・item名）
│           ├── config.local.zsh                # 端末固有値（gitignore）
│           ├── config.local.zsh.example        # 雛形
│           ├── lib/
│           │   ├── op.zsh                      # 1Password 冪等ヘルパー
│           │   └── service.zsh                 # brew services ヘルパー
│           └── install/
│               ├── 00_preflight.zsh
│               ├── 10_tailscale.zsh
│               ├── 20_adguard.zsh
│               ├── 30_syncthing.zsh
│               └── 40_splashtop.zsh
```

## 4. Brewfile

`setup/layers/home-network/Brewfile`:

```ruby
brew 'tailscale'        # subnet router (formula 強制)
brew 'adguardhome'      # DNS for tailnet
brew 'syncthing'        # ~/.claude 同期
cask 'splashtop-streamer'
```

共通 Brewfile への追加: `cask '1password'`

## 5. アーキテクチャ図

```
┌─ iPad Pro + Magic Keyboard ─┐
│  Splashtop Business app     │──┐ インターネット経由でも可
└─────────────────────────────┘  │
                                 │ Splashtop relay
┌─ MacBook (既存) ─────────────┐  │
│ Claude Code, MEMORY.md…     │  │
│                             │  │
│ syncthing 8384/22000 ◄──────┼──┼────┐
│ tailscale (client)          │  │    │ Tailscale Mesh (WireGuard)
└──┬──────────────────────────┘  │    │
   │                             │    │
   │ LAN (1 Gbps switch)         │    │
   │  ┌──────────────────────────▼────▼───────────┐
   └──│ Mac mini (home-network layer)            │
      │                                          │
      │ ┌── brew services (launchd) ──────────┐  │
      │ │                                     │  │
      │ │ tailscaled                          │  │
      │ │   └─ subnet router 192.168.x.0/24   │  │
      │ │   └─ auto-approved via ACL          │  │
      │ │                                     │  │
      │ │ AdGuardHome :53 (root)              │  │
      │ │   └─ DNS for tailnet clients        │  │
      │ │   └─ upstream: Cloudflare 1.1.1.1   │  │
      │ │                                     │  │
      │ │ syncthing :22000, :8384             │  │
      │ │   └─ ~/.claude folder (bidir)       │  │
      │ │                                     │  │
      │ │ Splashtop Streamer.app              │  │
      │ │   └─ LaunchDaemon, 受信待機         │  │
      │ └─────────────────────────────────────┘  │
      └──────────────────────────────────────────┘
```

## 6. 1Password Vault 構造

Vault 名: `home-network`

| Item 名 | カテゴリ | 生成方法 | 用途 |
|--------|---------|---------|------|
| `tailscale-authkey` | Login | **手動登録**（Tailscale Admin で発行後貼り付け） | `tailscale up --auth-key` |
| `adguard-admin` | Login | スクリプトが `--generate-password='letters,digits,symbols,32'` で自動生成 | AdGuard Web UI 認証 |
| `syncthing-gui` | Login | スクリプトが `--generate-password` で自動生成 | Syncthing Web UI 認証 |
| `syncthing-apikey` | Password | Syncthing 起動時に生成された値をスクリプトが書き戻す | REST API 操作 |
| `syncthing-peer-macbook` | Secure Note | **手動登録**（MacBook の Device ID を貼り付け） | 対向デバイス登録 |

冪等性パターン:

```zsh
op::ensure_login_item() {
  local title="$1" vault="$2" recipe="${3:-letters,digits,symbols,32}"
  if ! op item get "$title" --vault "$vault" &>/dev/null; then
    op item create --category Login --title "$title" --vault "$vault" \
      --generate-password="$recipe" >/dev/null
  fi
}
```

## 7. インストールスクリプト責務

### 7.1 `00_preflight.zsh`

- `op whoami` で 1Password CLI ログイン確認 → 失敗なら abort
- `sudo -v` で sudo 認証先取り
- `config.zsh`、`config.local.zsh` を source、`HOME_LAN_CIDR` 未設定なら abort

### 7.2 `10_tailscale.zsh`

- `brew install --formula tailscale`
- `op item get tailscale-authkey --vault home-network` で auth-key 存在確認、無ければ `util::error` で指示メッセージを出力し `exit 1`（abort の一貫定義）
- `sudo brew services start tailscale`（launchd 登録）
- `sudo tailscale up --advertise-routes="$HOME_LAN_CIDR" --auth-key="$(op read 'op://home-network/tailscale-authkey/password')" --reset`
- 既に tailnet 参加済みなら `tailscale up` は冪等（`--reset` で flag を再適用）

### 7.3 `20_adguard.zsh`

- `brew install adguardhome`
- `op::ensure_login_item adguard-admin home-network` で admin パスワード自動生成
- `gen_bcrypt $(op read 'op://home-network/adguard-admin/password')` で bcrypt ハッシュ取得
- 既存の `/opt/homebrew/etc/AdGuardHome/AdGuardHome.yaml` があれば `AdGuardHome.yaml.bak.$(date +%Y%m%d%H%M%S)` にリネームしてバックアップ
- heredoc + `op inject` で YAML 生成。デフォルト内容:
  - `http.address: 0.0.0.0:3000`（Web UI）
  - `dns.bind_hosts: ['0.0.0.0']`, `dns.port: 53`
  - `dns.upstream_dns: [1.1.1.1, 1.0.0.1, 8.8.8.8]`
  - `users: [{ name: admin, password: <bcrypt> }]`
  - `filters`: AdGuard DNS filter (`https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt`), Peter Lowe (`https://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus`)
- `sudo brew services start adguardhome`（port 53 のため root）

### 7.4 `30_syncthing.zsh`

- `brew install syncthing`
- 初回起動: `brew services start syncthing` → `~/Library/Application Support/Syncthing/config.xml` が存在するまで最大 30 秒 poll（1 秒間隔）、タイムアウトで abort
- API key を config.xml から抽出し `op item edit syncthing-apikey` で 1Password に書き戻し（既存と同値なら skip）
- `op::ensure_login_item syncthing-gui home-network` で GUI パスワード生成
- REST API で:
  - `~/.claude` を folder として登録（id=`claude-home`, type=sendreceive, fsWatcher=true）
  - 対向デバイス（MacBook）を `op item get syncthing-peer-macbook` から取得して device 登録
- `~/.claude/.stignore` を heredoc で生成
- `brew services restart syncthing`

### 7.5 `40_splashtop.zsh`

- `brew install --cask splashtop-streamer`
- `open -a "Splashtop Streamer"` でアプリ起動
- 「ログインは GUI で完了させてください」と guide 出力（自動化不可）

## 8. 初期セットアップ手順

`setup/layers/home-network/README.md` に記載する手順。

### 8.1 一度だけ手動で済ませるステップ

1. 1Password Desktop app 起動 → アカウントログイン → Touch ID 有効化、Settings → Developer → "Integrate with 1Password CLI"
2. `op whoami` 成功確認
3. 1Password で `home-network` Vault を作成
4. Tailscale Admin (`https://login.tailscale.com/admin/settings/keys`) で preauth key 発行（Reusable: false, Ephemeral: false, Pre-approved: true, Tags: `tag:home-mac-mini`）→ 1Password の `tailscale-authkey` Login item の password に保存
5. Tailscale ACL 設定（Access Controls）:
   ```json
   {
     "tagOwners": { "tag:home-mac-mini": ["autogroup:admin"] },
     "autoApprovers": {
       "routes": { "192.168.x.0/24": ["tag:home-mac-mini"] }
     }
   }
   ```
6. 既存 MacBook で `syncthing cli show system | grep myID` 実行 → 1Password の `syncthing-peer-macbook` Secure Note に Device ID を保存

### 8.2 ローカル設定

```bash
cp setup/layers/home-network/config.local.zsh.example \
   setup/layers/home-network/config.local.zsh
# 編集: HOME_LAN_CIDR=192.168.10.0/24 等
```

### 8.3 レイヤー実行

```bash
./setup/layers/home-network/install.zsh
```

### 8.4 実行後の手動完了ステップ

1. Splashtop Streamer がアプリで開くので、Splashtop アカウントでログイン
2. MacBook 側 Syncthing で Mac mini を Add Remote Device、Mac mini 側で承認、フォルダ共有を承認
3. 動作検証:
   - `tailscale status` で Mac mini と Subnet Routes が connected
   - `dig @<mac-mini-tailnet-ip> example.com` が解決される
   - `dig @<mac-mini-tailnet-ip> doubleclick.net` がブロックされる
   - iPad の Splashtop から接続できる
   - MacBook 側 `~/.claude/projects/` に Mac mini のセッションが現れる

## 9. 運用上の注意

- Mac mini と MacBook で Claude Code を**同時起動しない**
- AdGuard ブロックリスト・ルール変更は Mac mini の Web UI (`http://<mac-mini-ip>:3000`) で実施。スクリプトは初期構築のみ
- Tailscale auth-key 期限切れ時は 1Password の item を更新して `10_tailscale.zsh` を再実行
- 移行アシスタントは本レイヤーの**前**に実行する想定。本レイヤーは「移行後の Mac mini が共通セットアップを完了している」を前提とする

## 10. 非スコープ

以下は本設計に**含めない**:

- 移行アシスタントの自動化（GUI 必須）
- Mac mini のスリープ無効化等の OS 設定（共通 `29_macos.zsh` の責務）
- iPad 側 Splashtop アプリの設定
- AdGuard Home の運用中ブロックリスト追加（初期構築後は Web UI）
- Tailscale Admin の ACL を Terraform 等で管理する仕組み
- ファイアウォール (pf) の追加設定

## 11. 既知のリスクと緩和策

| リスク | 影響 | 緩和策 |
|-------|-----|-------|
| Mac mini と MacBook での Claude Code 同時起動 | `~/.claude/projects/*.jsonl` の sync-conflict 発生、セッション履歴分岐 | 運用規律として README に明記。技術的ロックは導入しない |
| Tailscale auth-key 漏洩 | 攻撃者が tailnet 参加可能 | 1Password vault に隔離、preauthorized + non-reusable で発行 |
| AdGuard Home の port 53 競合（mDNSResponder） | DNS 起動失敗 | `bind_hosts: ['0.0.0.0']` で全 IF listen、127.0.0.1 のみへの bind は避ける |
| Splashtop Streamer の自動アップデートで GUI 出現 | リモート操作中に妨害 | 初期セットアップで GUI から「自動アップデート無効化」を案内 |
| Syncthing 初回 2GB 同期の長時間化 | LAN 帯域専有 | 1 Gbps スイッチ前提で 5〜15 分許容、夜間実行を推奨 |
