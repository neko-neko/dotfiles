---
name: dev-server
description: >-
  Worktree のポート競合を回避して dev サーバーを起動するためのガイダンス。
  hash_port コマンドでブランチ名から決定論的にポートを割り当てる。
user-invocable: true
---

# Dev Server — Worktree ポート競合回避

worktree で並列開発する際のポート番号競合を `hash_port` コマンドで回避する。

## 前提

- `hash_port` コマンドが PATH に存在すること（`~/.dotfiles/bin/hash_port`）
- 現在のディレクトリが git リポジトリ内であること

## hash_port の仕組み

ブランチ名を `cksum` でハッシュし、10000-19999 の範囲にマッピングする。
同じブランチ名なら常に同じポート番号が返る（決定論的）。

```bash
hash_port          # ブランチ名 → ポート (例: 14523)
hash_port db       # ブランチ名+suffix → 別のポート (例: 16891)
hash_port redis    # 同上 (例: 12047)
```

## npm / pnpm / yarn プロジェクト

### 基本パターン

```bash
PORT=$(hash_port) npm run dev
```

### フレームワーク別の PORT 環境変数対応

| フレームワーク | PORT 環境変数 | 対応していない場合 |
|---|---|---|
| Next.js | 対応 | `--port` フラグ |
| Vite | 未対応 | `--port $(hash_port)` または `vite.config` の `server.port` |
| Create React App | 対応 | — |
| Nuxt | 対応 | `--port` フラグ |
| Angular CLI | 未対応 | `--port $(hash_port)` |
| webpack-dev-server | 未対応 | `--port $(hash_port)` |

### PORT 非対応フレームワークの場合

```bash
# Vite
npx vite --port $(hash_port)

# Angular
npx ng serve --port $(hash_port)

# webpack-dev-server
npx webpack serve --port $(hash_port)
```

## Docker Compose プロジェクト

### Step 1: .env にポート変数を注入

`docker-compose.yml` で `${VAR_NAME}` として参照されているポート変数を `.env` に書き出す。

```bash
# 既存 .env のポート変数を上書き、他は保持
update_env_port() {
  local key="$1" value="$2" file="${3:-.env}"
  if [ -f "$file" ] && grep -q "^${key}=" "$file"; then
    sed -i '' "s/^${key}=.*/${key}=${value}/" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

update_env_port APP_PORT "$(hash_port app)"
update_env_port DB_PORT "$(hash_port db)"
update_env_port REDIS_PORT "$(hash_port redis)"
```

### Step 2: docker-compose.yml でポート変数を参照

```yaml
services:
  app:
    ports:
      - "${APP_PORT}:3000"
  db:
    ports:
      - "${DB_PORT}:5432"
  redis:
    ports:
      - "${REDIS_PORT}:6379"
```

### 注意事項

- `.env` が `.gitignore` に含まれていることを確認すること
- `COMPOSE_PROJECT_NAME` もワークツリーごとに変えるとコンテナ名の競合も回避できる:
  ```bash
  COMPOSE_PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel)")-$(git branch --show-current | tr '/' '-')
  ```

## このスキルがやらないこと

- フレームワークの自動検出
- dev サーバーの停止・ライフサイクル管理
- `docker-compose.yml` の自動解析・書き換え
