# リモート開発環境 — Tailscale + herdr 運用手順

作成: 2026-07-11 / 対象: MacBook・iPad から mac-mini（herdr サーバー）へ接続して行う並列 AI エージェント開発

## 構成

```
┌─ tailnet (MagicDNS 有効) ─────────────────────────────┐
│                                                        │
│  mac-mini (mac-mini.tail9c5817.ts.net)                 │
│    ├─ tailscaled (brew 版 = open source 変種)          │
│    ├─ herdr サーバー（persistent session, 並列 agent）  │
│    └─ AdGuard / Syncthing (setup/layers/home-network)  │
│                                                        │
│  MacBook ──── ssh / herdr --remote ────→ mac-mini      │
│  iPad ─────── SSH クライアント (Blink 等) ──→ mac-mini  │
└────────────────────────────────────────────────────────┘
```

- Tailscale の macOS 変種に注意: **SSH サーバー・Funnel 等は brew (open source tailscaled) 変種のみ対応**。App Store / Standalone GUI 版はクライアント機能のみ
- mac-mini のセットアップは `setup/layers/home-network/` を参照

## 初回整備

1. **CLI / daemon のバージョン一致**（`tailscale status` に version mismatch 警告が出る場合）:

   ```bash
   brew upgrade tailscale
   sudo brew services restart tailscale   # 注意: 実行中の Tailscale 接続（iPad SSH 等）が切れる
   tailscale version                       # CLI と tailscaled の一致を確認
   ```

2. **HTTPS 証明書の有効化**（`ts-serve` の前提）: [admin console → DNS](https://login.tailscale.com/admin/dns) で MagicDNS と HTTPS Certificates を有効化する。未有効のまま `ts-serve` を実行すると有効化手順が案内される

## MacBook からの接続

2 通りある。**画像ペーストが必要なら `--remote` を使う**:

| 方式 | コマンド | 特徴 |
|------|---------|------|
| thin client | `herdr --remote mac-mini` | ローカル herdr がリモートへ SSH 接続しクライアント化。**ローカルクリップボードの画像ペーストをエージェントにブリッジ**（`remote_image_paste` キー）。キーバインドはローカル設定を維持 |
| ssh + attach | `ssh mac-mini` → `herdr` | tmux 相当。画像ペースト不可 |

Ghostty は `shell-integration-features = ssh-env,ssh-terminfo` 設定済みのため、初回 `ssh` 時に xterm-ghostty の terminfo がリモートへ自動インストールされる（`tic` 不在ホストでは `TERM=xterm-256color` にフォールバック）。

## iPad からの接続

1. Tailscale アプリで tailnet に接続
2. SSH クライアント（Blink / Termius 等）で `mac-mini.tail9c5817.ts.net` へ接続
3. `herdr` でセッションにアタッチ（thin client は使えないため ssh + attach 方式）

## iPad でのローカル開発プレビュー（ts-serve）

mac-mini 上の開発サーバーを HTTPS で tailnet に公開し、iPad Safari で確認する:

```bash
ts-serve 3000     # localhost:3000 を https://mac-mini.tail9c5817.ts.net/ で公開
ts-serve          # 現在の serve 状態を確認
ts-serve --off    # 解除（--bg のため明示的に解除するまで永続）
```

公開範囲は tailnet 内のみ（インターネットには出ない）。テストは `shellspec spec/ts-serve_spec.sh`。

## ファイル転送（Taildrop）

```bash
# mac-mini → iPad
tailscale file cp ./design.png ipad-pro:

# 受信（mac-mini 側で受け取る場合）
tailscale file get ~/Downloads
```

- iPad → mac-mini: 共有シート → Tailscale → 送信先に mac-mini を選択
- Mac ↔ Mac の常時同期フォルダが欲しい場合は Syncthing（home-network layer 導入済み）を使う

## トラブルシュート

| 症状 | 対処 |
|------|------|
| `tailscale status` に version mismatch 警告 | 「初回整備」手順 1 を実施 |
| `ts-serve` が HTTPS/cert エラー | 「初回整備」手順 2 を実施 |
| SSH 先で表示が崩れる / `unknown terminal type` | Ghostty の ssh-terminfo が未適用。手動なら `infocmp -x xterm-ghostty \| ssh <host> -- tic -x -`、または `TERM=xterm-256color` で接続 |
| iPad から serve URL が開けない | iPad の Tailscale アプリが接続中か確認。`tailscale serve status` で公開状態を確認 |
