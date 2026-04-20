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
