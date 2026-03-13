# claude-spawn Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 独立した複数の `/feature-dev` セッションを4-6個同時実行するオーケストレーター `claude-spawn` を構築する。

**Architecture:** `claude-spawn` は zsh CLI で、git worktree 作成 → WezTerm タブ生成 → Claude Code 起動を自動化する。セッション状態は git-backed JSON ファイル (`~/.claude/kanban/sessions/`) を source of truth とし、kanban-server はダッシュボード UI（読み取り専用）として拡張する。リモートノードは SSH + zellij で管理。

**Tech Stack:** zsh (CLI), WezTerm Lua API, Deno + Hono (kanban-server 拡張), git (状態同期)

**Design Doc:** `docs/plans/2026-03-13-claude-spawn-design.md`

---

## Task 1: セッション状態ファイルの管理ライブラリ

セッション JSON ファイルの CRUD を行うシェル関数ライブラリ。他の全タスクの基盤。

**Files:**
- Create: `claude/scripts/session-lib.sh`
- Create: `claude/scripts/session-lib_spec.sh`

**Step 1: テスト用ヘルパーとディレクトリ構造を定義**

`claude/scripts/session-lib_spec.sh` を ShellSpec 形式で作成（既存の `post_commit_spec.sh` と同じパターン）:

```bash
#!/usr/bin/env bash
# shellcheck shell=bash

Describe "session-lib.sh"
  setup() {
    export TEST_SESSIONS_DIR
    TEST_SESSIONS_DIR="$(mktemp -d)/sessions"
    mkdir -p "$TEST_SESSIONS_DIR"
  }

  cleanup() {
    rm -rf "$(dirname "$TEST_SESSIONS_DIR")"
  }

  BeforeEach setup
  AfterEach cleanup

  Include claude/scripts/session-lib.sh

  Describe "create_session()"
    It "creates a session JSON file with correct fields"
      When call create_session "auth" "OAuth2認証の追加" "local" ".worktrees/auth" "feature/auth"
      The status should be success
      The path "$TEST_SESSIONS_DIR/auth-"*".json" should be file
    End

    It "rejects duplicate session names"
      # 先に1つ作る
      create_session "auth" "desc" "local" ".worktrees/auth" "feature/auth" >/dev/null
      When call create_session "auth" "desc2" "local" ".worktrees/auth2" "feature/auth2"
      The status should be failure
      The stderr should include "already exists"
    End
  End

  Describe "update_session()"
    It "updates status and phase fields"
      local id
      id=$(create_session "test" "desc" "local" ".worktrees/test" "feature/test")
      When call update_session "$id" '{"status":"awaiting-review","phase":"Code Review"}'
      The status should be success
      # ファイル内容を検証
      The contents of file "$TEST_SESSIONS_DIR/${id}.json" should include '"awaiting-review"'
    End
  End

  Describe "list_sessions()"
    It "returns JSON array of all sessions"
      create_session "a" "desc-a" "local" ".worktrees/a" "feature/a" >/dev/null
      create_session "b" "desc-b" "mac-mini" "~/worktrees/b" "feature/b" >/dev/null
      When call list_sessions
      The status should be success
      The output should include '"name":"a"'
      The output should include '"name":"b"'
    End

    It "filters by host"
      create_session "a" "desc-a" "local" ".worktrees/a" "feature/a" >/dev/null
      create_session "b" "desc-b" "mac-mini" "~/worktrees/b" "feature/b" >/dev/null
      When call list_sessions --host local
      The output should include '"name":"a"'
      The output should not include '"name":"b"'
    End
  End

  Describe "get_session()"
    It "returns session by ID"
      local id
      id=$(create_session "test" "desc" "local" ".worktrees/test" "feature/test")
      When call get_session "$id"
      The status should be success
      The output should include '"name":"test"'
    End
  End

  Describe "delete_session()"
    It "removes session file"
      local id
      id=$(create_session "test" "desc" "local" ".worktrees/test" "feature/test")
      When call delete_session "$id"
      The status should be success
      The path "$TEST_SESSIONS_DIR/${id}.json" should not be file
    End
  End

  Describe "count_sessions_by_host()"
    It "returns count for given host"
      create_session "a" "d" "local" ".w/a" "f/a" >/dev/null
      create_session "b" "d" "local" ".w/b" "f/b" >/dev/null
      create_session "c" "d" "mac-mini" "~/w/c" "f/c" >/dev/null
      When call count_sessions_by_host "local"
      The output should equal "2"
    End
  End
End
```

**Step 2: テストが失敗することを確認**

Run: `shellspec claude/scripts/session-lib_spec.sh 2>/dev/null || echo "FAIL as expected"`
Expected: FAIL (session-lib.sh が存在しない)

**Step 3: session-lib.sh を実装**

`claude/scripts/session-lib.sh`:

```bash
#!/usr/bin/env bash
# shellcheck shell=bash
# Session state file management library for claude-spawn
# Source of truth: ~/.claude/kanban/sessions/<session-id>.json

set -euo pipefail

# セッションディレクトリ（テスト時は TEST_SESSIONS_DIR で上書き可能）
SESSIONS_DIR="${TEST_SESSIONS_DIR:-${HOME}/.claude/kanban/sessions}"

_ensure_sessions_dir() {
  mkdir -p "$SESSIONS_DIR"
}

_now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%S+00:00"
}

_generate_id() {
  local name="$1"
  local ts
  ts=$(date +"%Y%m%d-%H%M%S")
  echo "${name}-${ts}"
}

# create_session <name> <description> <host> <worktree> <branch> [wezterm_pane_id] [zellij_session]
# Outputs: session ID
create_session() {
  _ensure_sessions_dir
  local name="$1" desc="$2" host="$3" worktree="$4" branch="$5"
  local pane_id="${6:-}" zellij_session="${7:-}"

  # 重複チェック（同名で active なセッションがないか）
  local existing
  existing=$(find "$SESSIONS_DIR" -name "${name}-*.json" -print -quit 2>/dev/null || true)
  if [[ -n "$existing" ]]; then
    echo "Session '${name}' already exists: $(basename "$existing" .json)" >&2
    return 1
  fi

  local id
  id=$(_generate_id "$name")
  local now
  now=$(_now_iso)

  local json
  json=$(cat <<EOJSON
{
  "id": "${id}",
  "name": "${name}",
  "description": "${desc}",
  "status": "starting",
  "phase": "",
  "host": "${host}",
  "worktree": "${worktree}",
  "branch": "${branch}",
  "wezterm_pane_id": "${pane_id}",
  "zellij_session": "${zellij_session}",
  "created_at": "${now}",
  "updated_at": "${now}",
  "waiting_since": null
}
EOJSON
  )

  echo "$json" > "${SESSIONS_DIR}/${id}.json"
  echo "$id"
}

# update_session <id> <json_patch>
# json_patch: jq で merge するオブジェクト e.g. '{"status":"in-progress","phase":"Design"}'
update_session() {
  local id="$1" patch="$2"
  local file="${SESSIONS_DIR}/${id}.json"

  if [[ ! -f "$file" ]]; then
    echo "Session not found: ${id}" >&2
    return 1
  fi

  local now
  now=$(_now_iso)

  # waiting_since の自動管理
  local waiting_patch=""
  local new_status
  new_status=$(echo "$patch" | jq -r '.status // empty')
  if [[ "$new_status" == "awaiting-review" ]]; then
    waiting_patch=", \"waiting_since\": \"${now}\""
  elif [[ -n "$new_status" && "$new_status" != "awaiting-review" ]]; then
    waiting_patch=', "waiting_since": null'
  fi

  jq --argjson patch "${patch}" \
     --arg now "$now" \
     '. * $patch | .updated_at = $now' "$file" | \
  jq --arg ws_patch "$waiting_patch" \
     'if ($ws_patch | length) > 0 then . else . end' > "${file}.tmp"

  # waiting_since を直接処理（jq で完結）
  if [[ "$new_status" == "awaiting-review" ]]; then
    jq --arg now "$now" '.waiting_since = $now' "${file}.tmp" > "${file}.tmp2"
    mv "${file}.tmp2" "${file}.tmp"
  elif [[ -n "$new_status" && "$new_status" != "awaiting-review" ]]; then
    jq '.waiting_since = null' "${file}.tmp" > "${file}.tmp2"
    mv "${file}.tmp2" "${file}.tmp"
  fi

  mv "${file}.tmp" "$file"
}

# list_sessions [--host <host>] [--status <status>]
list_sessions() {
  _ensure_sessions_dir
  local filter_host="" filter_status=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host) filter_host="$2"; shift 2 ;;
      --status) filter_status="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local files=("$SESSIONS_DIR"/*.json)
  if [[ ! -f "${files[0]:-}" ]]; then
    echo "[]"
    return
  fi

  local result="["
  local first=true
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    local content
    content=$(cat "$f")

    if [[ -n "$filter_host" ]]; then
      local h
      h=$(echo "$content" | jq -r '.host')
      [[ "$h" == "$filter_host" ]] || continue
    fi

    if [[ -n "$filter_status" ]]; then
      local s
      s=$(echo "$content" | jq -r '.status')
      [[ "$s" == "$filter_status" ]] || continue
    fi

    if $first; then
      first=false
    else
      result+=","
    fi
    result+="$content"
  done
  result+="]"
  echo "$result"
}

# get_session <id>
get_session() {
  local id="$1"
  local file="${SESSIONS_DIR}/${id}.json"
  if [[ ! -f "$file" ]]; then
    echo "Session not found: ${id}" >&2
    return 1
  fi
  cat "$file"
}

# delete_session <id>
delete_session() {
  local id="$1"
  local file="${SESSIONS_DIR}/${id}.json"
  if [[ ! -f "$file" ]]; then
    echo "Session not found: ${id}" >&2
    return 1
  fi
  rm "$file"
}

# count_sessions_by_host <host>
count_sessions_by_host() {
  local host="$1"
  list_sessions --host "$host" | jq 'length'
}

# find_session_by_name <name>
# Returns session ID or empty
find_session_by_name() {
  local name="$1"
  local file
  file=$(find "$SESSIONS_DIR" -name "${name}-*.json" -print -quit 2>/dev/null || true)
  if [[ -n "$file" ]]; then
    jq -r '.id' "$file"
  fi
}
```

**Step 4: テストを実行して全て通ることを確認**

Run: `shellspec claude/scripts/session-lib_spec.sh`
Expected: All examples passed

**Step 5: コミット**

```bash
git add claude/scripts/session-lib.sh claude/scripts/session-lib_spec.sh
git commit -m "feat: add session state file management library"
```

---

## Task 2: claude-spawn 設定ファイルのパーサー

TOML 設定ファイルを読み取るシェル関数。jq で JSON 変換して扱う。

**Files:**
- Create: `claude/scripts/spawn-config.sh`
- Create: `claude/scripts/spawn-config_spec.sh`

**Step 1: テストを書く**

`claude/scripts/spawn-config_spec.sh`:

```bash
#!/usr/bin/env bash

Describe "spawn-config.sh"
  setup() {
    export TEST_CONFIG_DIR
    TEST_CONFIG_DIR="$(mktemp -d)"
  }

  cleanup() {
    rm -rf "$TEST_CONFIG_DIR"
  }

  BeforeEach setup
  AfterEach cleanup

  Include claude/scripts/spawn-config.sh

  Describe "load_config()"
    It "loads config from TOML file"
      cat > "$TEST_CONFIG_DIR/config.toml" <<'TOML'
[local]
worktree_dir = ".worktrees"
max_sessions = 4

[nodes.mac-mini]
host = "mac-mini"
worktree_dir = "~/worktrees"
max_sessions = 2

[kanban]
repo = "~/.claude/kanban"
sessions_dir = "sessions"
TOML
      When call load_config "$TEST_CONFIG_DIR/config.toml"
      The status should be success
    End

    It "returns local worktree_dir"
      cat > "$TEST_CONFIG_DIR/config.toml" <<'TOML'
[local]
worktree_dir = ".worktrees"
max_sessions = 4
TOML
      load_config "$TEST_CONFIG_DIR/config.toml"
      When call config_get ".local.worktree_dir"
      The output should equal ".worktrees"
    End

    It "returns node host"
      cat > "$TEST_CONFIG_DIR/config.toml" <<'TOML'
[local]
worktree_dir = ".worktrees"
max_sessions = 4

[nodes.mac-mini]
host = "mac-mini"
worktree_dir = "~/worktrees"
max_sessions = 2
TOML
      load_config "$TEST_CONFIG_DIR/config.toml"
      When call config_get '.nodes["mac-mini"].host'
      The output should equal "mac-mini"
    End

    It "returns max_sessions for node"
      cat > "$TEST_CONFIG_DIR/config.toml" <<'TOML'
[local]
worktree_dir = ".worktrees"
max_sessions = 4

[nodes.mac-mini]
host = "mac-mini"
worktree_dir = "~/worktrees"
max_sessions = 2
TOML
      load_config "$TEST_CONFIG_DIR/config.toml"
      When call config_get '.nodes["mac-mini"].max_sessions'
      The output should equal "2"
    End
  End

  Describe "list_nodes()"
    It "lists all configured nodes"
      cat > "$TEST_CONFIG_DIR/config.toml" <<'TOML'
[local]
worktree_dir = ".worktrees"
max_sessions = 4

[nodes.mac-mini]
host = "mac-mini"
worktree_dir = "~/worktrees"
max_sessions = 2

[nodes.cloud-dev]
host = "cloud-dev"
worktree_dir = "~/worktrees"
max_sessions = 4
TOML
      load_config "$TEST_CONFIG_DIR/config.toml"
      When call list_nodes
      The output should include "mac-mini"
      The output should include "cloud-dev"
    End
  End
End
```

**Step 2: テストが失敗することを確認**

Run: `shellspec claude/scripts/spawn-config_spec.sh 2>/dev/null || echo "FAIL as expected"`

**Step 3: 実装**

TOML パースはシンプルな TOML のみ対応（ネストされたテーブルとスカラー値）。外部依存を避けるため awk で変換。

`claude/scripts/spawn-config.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# TOML を簡易パースして JSON に変換し、jq でアクセスする
# 対応範囲: [section], [section.subsection], key = "value", key = N

_SPAWN_CONFIG_JSON=""

# _toml_to_json <file>
# シンプルな TOML → JSON 変換（awk ベース）
_toml_to_json() {
  local file="$1"
  python3 -c "
import sys, json, re

result = {}
current = result

def set_nested(d, keys, value):
    for k in keys[:-1]:
        d = d.setdefault(k, {})
    d[keys[-1]] = value

path = []
with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        m = re.match(r'^\[(.+)\]$', line)
        if m:
            path = m.group(1).split('.')
            # ensure path exists
            d = result
            for p in path:
                d = d.setdefault(p, {})
            continue
        m = re.match(r'^(\w+)\s*=\s*(.+)$', line)
        if m:
            key, val = m.group(1), m.group(2).strip()
            if val.startswith('\"') and val.endswith('\"'):
                val = val[1:-1]
            elif val.isdigit():
                val = int(val)
            elif val == 'true':
                val = True
            elif val == 'false':
                val = False
            set_nested(result, path + [key], val)
print(json.dumps(result))
" "$file"
}

# load_config <toml_file>
load_config() {
  local file="${1:-${HOME}/.config/claude-spawn/config.toml}"
  if [[ ! -f "$file" ]]; then
    echo "Config not found: $file" >&2
    return 1
  fi
  _SPAWN_CONFIG_JSON=$(_toml_to_json "$file")
}

# config_get <jq_path>
config_get() {
  echo "$_SPAWN_CONFIG_JSON" | jq -r "$1"
}

# list_nodes - ノード名の一覧を出力
list_nodes() {
  echo "$_SPAWN_CONFIG_JSON" | jq -r '.nodes // {} | keys[]'
}

# get_node_config <node_name> - ノード設定を JSON で返す
get_node_config() {
  local node="$1"
  echo "$_SPAWN_CONFIG_JSON" | jq ".nodes[\"$node\"]"
}
```

**Step 4: テスト実行**

Run: `shellspec claude/scripts/spawn-config_spec.sh`
Expected: All examples passed

**Step 5: コミット**

```bash
git add claude/scripts/spawn-config.sh claude/scripts/spawn-config_spec.sh
git commit -m "feat: add claude-spawn config file parser"
```

---

## Task 3: claude-spawn CLI フレームワーク（start サブコマンド・ローカル）

メインの CLI スクリプトと `start` サブコマンドのローカル実行を実装。

**Files:**
- Create: `bin/claude-spawn`
- Modify: `claude/scripts/session-lib.sh` (git sync 関数追加)

**Step 1: テストを書く**

`claude-spawn` は統合的なコマンドなので、unit test ではなく実行可能性をテスト。

`claude/scripts/claude-spawn_spec.sh`:

```bash
#!/usr/bin/env bash

Describe "claude-spawn CLI"
  setup() {
    export TEST_SESSIONS_DIR
    TEST_SESSIONS_DIR="$(mktemp -d)/sessions"
    mkdir -p "$TEST_SESSIONS_DIR"
    export TEST_CONFIG_DIR
    TEST_CONFIG_DIR="$(mktemp -d)"
    cat > "$TEST_CONFIG_DIR/config.toml" <<'TOML'
[local]
worktree_dir = ".worktrees"
max_sessions = 4

[kanban]
repo = "~/.claude/kanban"
sessions_dir = "sessions"
TOML
    export CLAUDE_SPAWN_CONFIG="$TEST_CONFIG_DIR/config.toml"
    # dry-run モードで WezTerm/git 操作をスキップ
    export CLAUDE_SPAWN_DRY_RUN=1
  }

  cleanup() {
    rm -rf "$(dirname "$TEST_SESSIONS_DIR")" "$TEST_CONFIG_DIR"
  }

  BeforeEach setup
  AfterEach cleanup

  Describe "start subcommand"
    It "creates a session in dry-run mode"
      When run script bin/claude-spawn start --name test-feat --desc "test feature"
      The status should be success
      The output should include "Session created"
      The output should include "test-feat"
    End

    It "rejects missing --name"
      When run script bin/claude-spawn start --desc "test"
      The status should be failure
      The stderr should include "name"
    End

    It "rejects missing --desc"
      When run script bin/claude-spawn start --name test
      The status should be failure
      The stderr should include "desc"
    End
  End

  Describe "list subcommand"
    It "shows empty list"
      When run script bin/claude-spawn list
      The status should be success
      The output should include "No active sessions"
    End

    It "shows sessions after start"
      bin/claude-spawn start --name feat1 --desc "feature 1" >/dev/null
      When run script bin/claude-spawn list
      The status should be success
      The output should include "feat1"
    End
  End

  Describe "nodes subcommand"
    It "shows configured nodes"
      When run script bin/claude-spawn nodes
      The status should be success
      # ローカルのみの config なので "No remote nodes" 的な出力
      The output should include "local"
    End
  End
End
```

**Step 2: テストが失敗することを確認**

Run: `shellspec claude/scripts/claude-spawn_spec.sh 2>/dev/null || echo "FAIL as expected"`

**Step 3: CLI メインスクリプトを実装**

`bin/claude-spawn`:

```bash
#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
DOTFILES_DIR="${SCRIPT_DIR:h}"

# ライブラリ読み込み
source "${DOTFILES_DIR}/claude/scripts/session-lib.sh"
source "${DOTFILES_DIR}/claude/scripts/spawn-config.sh"

# 設定読み込み
CONFIG_FILE="${CLAUDE_SPAWN_CONFIG:-${HOME}/.config/claude-spawn/config.toml}"
DRY_RUN="${CLAUDE_SPAWN_DRY_RUN:-0}"

_die() { echo "Error: $*" >&2; exit 1; }
_info() { echo ">> $*"; }

_load_config_safe() {
  if [[ -f "$CONFIG_FILE" ]]; then
    load_config "$CONFIG_FILE"
  else
    _die "Config not found: $CONFIG_FILE\nCreate it with: mkdir -p ~/.config/claude-spawn && cp ${DOTFILES_DIR}/claude/templates/claude-spawn-config.toml ~/.config/claude-spawn/config.toml"
  fi
}

# --- start ---
cmd_start() {
  local name="" desc="" remote=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --desc) desc="$2"; shift 2 ;;
      --remote) remote="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -n "$name" ]] || _die "--name is required"
  [[ -n "$desc" ]] || _die "--desc is required"

  _load_config_safe

  local host="local"
  local worktree_dir
  local max_sessions

  if [[ -n "$remote" ]]; then
    host="$remote"
    worktree_dir=$(config_get ".nodes[\"$remote\"].worktree_dir")
    max_sessions=$(config_get ".nodes[\"$remote\"].max_sessions")
    [[ "$worktree_dir" != "null" ]] || _die "Unknown node: $remote"
  else
    worktree_dir=$(config_get ".local.worktree_dir")
    max_sessions=$(config_get ".local.max_sessions")
  fi

  # max_sessions チェック
  local current_count
  current_count=$(count_sessions_by_host "$host")
  if (( current_count >= max_sessions )); then
    _die "Max sessions ($max_sessions) reached for $host. Run 'claude-spawn clean' first."
  fi

  local branch="feature/${name}"
  local worktree_path="${worktree_dir}/${name}"

  if [[ "$DRY_RUN" == "1" ]]; then
    # dry-run: 実際の worktree/WezTerm 操作をスキップ
    local session_id
    session_id=$(create_session "$name" "$desc" "$host" "$worktree_path" "$branch")
    _info "Session created: $session_id (dry-run)"
    _info "  Host: $host"
    _info "  Worktree: $worktree_path"
    _info "  Branch: $branch"
    return 0
  fi

  if [[ -z "$remote" ]]; then
    _start_local "$name" "$desc" "$worktree_path" "$branch"
  else
    _start_remote "$name" "$desc" "$remote" "$worktree_path" "$branch"
  fi
}

_start_local() {
  local name="$1" desc="$2" worktree_path="$3" branch="$4"

  # 1. git worktree 作成
  _info "Creating worktree: $worktree_path"
  git worktree add "$worktree_path" -b "$branch"

  # 2. WezTerm タブ生成（claude-dev ワークスペース）
  _info "Spawning WezTerm tab..."
  local pane_id
  pane_id=$(wezterm cli spawn --cwd "$worktree_path" -- claude --resume)

  # 3. タブタイトル設定
  wezterm cli set-tab-title --pane-id "$pane_id" "[${name}] starting..."

  # 4. セッション登録
  local session_id
  session_id=$(create_session "$name" "$desc" "local" "$worktree_path" "$branch" "$pane_id")

  # 5. git sync
  _sync_sessions_push "Session started: $name"

  _info "Session created: $session_id"
  _info "  Pane ID: $pane_id"
  _info "  Worktree: $worktree_path"
  _info "  Run '/feature-dev ${desc}' in the new tab"
}

_start_remote() {
  local name="$1" desc="$2" node="$3" worktree_path="$4" branch="$5"
  local ssh_host
  ssh_host=$(config_get ".nodes[\"$node\"].host")

  # 1. SSH でリモート worktree 作成
  _info "Creating remote worktree on $node..."
  ssh "$ssh_host" "git worktree add ${worktree_path} -b ${branch}" || \
    _die "Failed to create worktree on $node"

  # 2. zellij セッション作成
  _info "Starting zellij session on $node..."
  ssh "$ssh_host" "cd ${worktree_path} && zellij -s ${name} -l claude-session.kdl &" || \
    _die "Failed to start zellij on $node"

  # 3. セッション登録
  local session_id
  session_id=$(create_session "$name" "$desc" "$node" "$worktree_path" "$branch" "" "$name")

  # 4. git sync
  _sync_sessions_push "Session started: $name on $node"

  _info "Session created: $session_id"
  _info "  Node: $node ($ssh_host)"
  _info "  Zellij session: $name"
  _info "  Attach with: claude-spawn attach $name"
}

# --- list ---
cmd_list() {
  _load_config_safe
  _sync_sessions_pull

  local sessions
  sessions=$(list_sessions "$@")
  local count
  count=$(echo "$sessions" | jq 'length')

  if (( count == 0 )); then
    _info "No active sessions"
    return
  fi

  echo "$sessions" | jq -r '.[] | "\(.host)\t\(.name)\t\(.status)\t\(.phase)\t\(.waiting_since // "-")"' | \
    column -t -s $'\t' -N HOST,NAME,STATUS,PHASE,WAITING
}

# --- attach ---
cmd_attach() {
  local name="${1:?Usage: claude-spawn attach <name>}"
  _load_config_safe

  local session_id
  session_id=$(find_session_by_name "$name")
  [[ -n "$session_id" ]] || _die "Session not found: $name"

  local session
  session=$(get_session "$session_id")
  local host
  host=$(echo "$session" | jq -r '.host')

  if [[ "$host" == "local" ]]; then
    local pane_id
    pane_id=$(echo "$session" | jq -r '.wezterm_pane_id')
    _info "Focusing pane $pane_id"
    wezterm cli activate-pane --pane-id "$pane_id"
  else
    local ssh_host
    ssh_host=$(config_get ".nodes[\"$host\"].host")
    local zellij_session
    zellij_session=$(echo "$session" | jq -r '.zellij_session')
    _info "Attaching to $host:$zellij_session..."
    wezterm cli spawn -- ssh -t "$ssh_host" "zellij attach $zellij_session"
  fi
}

# --- clean ---
cmd_clean() {
  local name="" all_done=false node=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all-done) all_done=true; shift ;;
      --node) node="$2"; shift 2 ;;
      *) name="$1"; shift ;;
    esac
  done

  _load_config_safe

  if $all_done; then
    _clean_by_status "done"
    return
  fi

  if [[ -n "$node" ]]; then
    _clean_by_node "$node"
    return
  fi

  [[ -n "$name" ]] || _die "Usage: claude-spawn clean <name> | --all-done | --node <node>"
  _clean_single "$name"
}

_clean_single() {
  local name="$1"
  local session_id
  session_id=$(find_session_by_name "$name")
  [[ -n "$session_id" ]] || _die "Session not found: $name"

  local session
  session=$(get_session "$session_id")
  local status host worktree branch
  status=$(echo "$session" | jq -r '.status')
  host=$(echo "$session" | jq -r '.host')
  worktree=$(echo "$session" | jq -r '.worktree')
  branch=$(echo "$session" | jq -r '.branch')

  if [[ "$status" != "done" && "$status" != "failed" ]]; then
    echo "Warning: Session '$name' is still $status. Continue? [y/N]" >&2
    read -r confirm
    [[ "$confirm" == "y" ]] || return 1
  fi

  if [[ "$DRY_RUN" != "1" ]]; then
    if [[ "$host" == "local" ]]; then
      git worktree remove "$worktree" 2>/dev/null || true
      git branch -d "$branch" 2>/dev/null || true
    else
      local ssh_host
      ssh_host=$(config_get ".nodes[\"$host\"].host")
      ssh "$ssh_host" "zellij delete-session $name 2>/dev/null; true"
      ssh "$ssh_host" "git worktree remove $worktree 2>/dev/null; true"
    fi
  fi

  delete_session "$session_id"
  _sync_sessions_push "Session cleaned: $name"
  _info "Cleaned: $name"
}

_clean_by_status() {
  local status="$1"
  local sessions
  sessions=$(list_sessions --status "$status")
  local count
  count=$(echo "$sessions" | jq 'length')

  if (( count == 0 )); then
    _info "No sessions with status: $status"
    return
  fi

  echo "$sessions" | jq -r '.[].name' | while read -r name; do
    _clean_single "$name"
  done
}

_clean_by_node() {
  local node="$1"
  local sessions
  sessions=$(list_sessions --host "$node")
  echo "$sessions" | jq -r '.[].name' | while read -r name; do
    _clean_single "$name"
  done
}

# --- nodes ---
cmd_nodes() {
  local subcmd="${1:-list}"
  _load_config_safe

  case "$subcmd" in
    list|"")
      _info "Local: max $(config_get '.local.max_sessions') sessions, worktree_dir=$(config_get '.local.worktree_dir')"
      local nodes
      nodes=$(list_nodes)
      if [[ -z "$nodes" ]]; then
        _info "No remote nodes configured"
      else
        echo "$nodes" | while read -r node; do
          local host max_s
          host=$(config_get ".nodes[\"$node\"].host")
          max_s=$(config_get ".nodes[\"$node\"].max_sessions")
          local count
          count=$(count_sessions_by_host "$node")
          _info "Node '$node': host=$host, sessions=$count/$max_s"
        done
      fi
      ;;
    check)
      local nodes
      nodes=$(list_nodes)
      echo "$nodes" | while read -r node; do
        local host
        host=$(config_get ".nodes[\"$node\"].host")
        if ssh -o ConnectTimeout=5 "$host" "echo ok" >/dev/null 2>&1; then
          _info "$node ($host): reachable"
        else
          _info "$node ($host): UNREACHABLE"
        fi
      done
      ;;
  esac
}

# --- dashboard ---
cmd_dashboard() {
  _info "Opening kanban dashboard..."
  open "http://localhost:3456"
}

# --- git sync helpers ---
_sync_sessions_push() {
  local message="${1:-session update}"
  local kanban_repo
  kanban_repo=$(config_get '.kanban.repo // "~/.claude/kanban"')
  kanban_repo="${kanban_repo/#\~/$HOME}"

  (
    cd "$kanban_repo"
    git add sessions/ 2>/dev/null || true
    git commit -m "claude-spawn: $message" 2>/dev/null || true
    git push 2>/dev/null || true
  ) &
}

_sync_sessions_pull() {
  local kanban_repo
  kanban_repo=$(config_get '.kanban.repo // "~/.claude/kanban"')
  kanban_repo="${kanban_repo/#\~/$HOME}"

  (cd "$kanban_repo" && git pull --rebase 2>/dev/null) || true
}

# --- main ---
main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    start)     cmd_start "$@" ;;
    list|ls)   cmd_list "$@" ;;
    attach)    cmd_attach "$@" ;;
    clean)     cmd_clean "$@" ;;
    nodes)     cmd_nodes "$@" ;;
    dashboard) cmd_dashboard ;;
    help|--help|-h)
      cat <<'USAGE'
claude-spawn - Parallel feature-dev session orchestrator

Usage:
  claude-spawn start --name <name> --desc "description" [--remote <node>]
  claude-spawn list [--host <host>] [--status <status>]
  claude-spawn attach <name>
  claude-spawn clean <name> | --all-done | --node <node>
  claude-spawn nodes [check]
  claude-spawn dashboard
USAGE
      ;;
    *) _die "Unknown command: $cmd. Run 'claude-spawn help'" ;;
  esac
}

main "$@"
```

**Step 4: 実行権限を付与してテスト実行**

Run: `chmod +x bin/claude-spawn && shellspec claude/scripts/claude-spawn_spec.sh`
Expected: All examples passed

**Step 5: コミット**

```bash
git add bin/claude-spawn claude/scripts/claude-spawn_spec.sh
git commit -m "feat: add claude-spawn CLI with start/list/attach/clean/nodes commands"
```

---

## Task 4: WezTerm Lua 拡張（ワークスペース・タブタイトル・キーバインド）

WezTerm の設定を拡張して claude-spawn セッションの視認性を向上。

**Files:**
- Modify: `wezterm.lua` (既存ファイル)

**Step 1: 現在の wezterm.lua のバックアップポイントを確認**

既存コードの構造:
- L1-50: 基本設定（フォント、テーマ等）
- L51-100: キーバインド
- L101-147: ワークスペース設定
- L148-158: claude_notify イベントハンドラ

**Step 2: claude-spawn 用のタブタイトル更新ハンドラを追加**

`wezterm.lua` の末尾（既存の `claude_notify` ハンドラの後）に追加:

```lua
-- claude-spawn: タブタイトル更新ハンドラ
-- user-var "claude_spawn_tab" を受信してタブタイトルを変更
wezterm.on("user-var-changed", function(window, pane, name, value)
  if name == "claude_spawn_tab" then
    local decoded = wezterm.base64_decode(value) or value
    pane:set_title(decoded)
  end
end)

-- claude-spawn: 承認待ちタブのハイライト
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local title = tab.active_pane.title
  if string.find(title, "WAITING") then
    return {
      { Background = { Color = "#c0752a" } },
      { Foreground = { Color = "#1a1a2e" } },
      { Text = " " .. title .. " " },
    }
  end
end)
```

**Step 3: claude-dev ワークスペースへの自動切替キーバインドを追加**

既存のキーバインド設定セクションに追加:

```lua
-- claude-spawn セッション一覧（fzf 選択で attach）
{ key = "L", mods = "CMD|SHIFT",
  action = wezterm.action.SpawnCommandInNewTab {
    args = { "bash", "-c", "claude-spawn list && echo '---' && read -p 'Attach to: ' name && claude-spawn attach $name" },
  },
},
-- 承認待ちセッション一覧
{ key = "W", mods = "CMD|SHIFT",
  action = wezterm.action.SpawnCommandInNewTab {
    args = { "bash", "-c", "claude-spawn list --status awaiting-review" },
  },
},
```

**Step 4: WezTerm をリロードして動作確認**

WezTerm は設定ファイルの変更を自動検知してリロードする。
確認: `Cmd+Shift+L` でタブが開き `claude-spawn list` が実行されること。

**Step 5: コミット**

```bash
git add wezterm.lua
git commit -m "feat: add WezTerm extensions for claude-spawn tab management"
```

---

## Task 5: Claude Code hooks 拡張（フェーズ追跡・承認待ち検知）

セッション内の Claude Code がフェーズ遷移や承認待ちになった際に、セッション状態ファイルとタブタイトルを更新する hooks。

**Files:**
- Create: `claude/hooks/spawn-phase-hook.sh`
- Modify: `claude/settings.json` (hook 登録)

**Step 1: spawn-phase-hook.sh を作成**

```bash
#!/usr/bin/env bash
set -euo pipefail

# claude-spawn phase tracking hook
# PostToolUse / Notification hook から呼ばれる
# 環境変数: CLAUDE_SPAWN_SESSION_ID (worktree の CLAUDE.md 経由で設定)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../scripts/session-lib.sh"

SESSION_ID="${CLAUDE_SPAWN_SESSION_ID:-}"
[[ -n "$SESSION_ID" ]] || exit 0  # spawn セッションでなければ何もしない

HOOK_TYPE="${1:-}"  # "notification" or "tool"
HOOK_DATA="${2:-}"  # JSON or keyword

case "$HOOK_TYPE" in
  notification)
    # 承認待ち検知（idle_prompt = 入力待ち）
    local notification_type
    notification_type=$(echo "$HOOK_DATA" | jq -r '.type // empty' 2>/dev/null || echo "$HOOK_DATA")
    case "$notification_type" in
      idle_prompt|permission_prompt|elicitation_dialog)
        update_session "$SESSION_ID" '{"status":"awaiting-review"}'
        # タブタイトル更新
        _update_tab_title "$SESSION_ID" "⏳ WAITING"
        ;;
    esac
    ;;
  phase)
    # フェーズ名を直接受け取る（feature-dev の各フェーズ遷移時）
    local phase="$HOOK_DATA"
    update_session "$SESSION_ID" "{\"status\":\"in-progress\",\"phase\":\"${phase}\"}"
    _update_tab_title "$SESSION_ID" "feature-dev: ${phase}"
    ;;
  done)
    update_session "$SESSION_ID" '{"status":"done","phase":"Complete"}'
    _update_tab_title "$SESSION_ID" "✅ Done"
    ;;
esac

# git sync（バックグラウンド）
_sync_sessions_push_bg() {
  local kanban_dir="${HOME}/.claude/kanban"
  (
    cd "$kanban_dir"
    git add sessions/ 2>/dev/null
    git commit -m "claude-spawn: phase update for $SESSION_ID" 2>/dev/null
    git push 2>/dev/null
  ) &
}

_update_tab_title() {
  local sid="$1" label="$2"
  local session
  session=$(get_session "$sid" 2>/dev/null) || return 0
  local name pane_id
  name=$(echo "$session" | jq -r '.name')
  pane_id=$(echo "$session" | jq -r '.wezterm_pane_id // empty')

  if [[ -n "$pane_id" ]]; then
    wezterm cli set-tab-title --pane-id "$pane_id" "[${name}] ${label}" 2>/dev/null || true
  fi
}

_sync_sessions_push_bg
```

**Step 2: settings.json に hook を登録**

既存の Notification hooks セクション（L169-196）に spawn-phase-hook を追加チェーン:

```json
{
  "hook": "Notification",
  "pattern": ".",
  "command": "claude/hooks/spawn-phase-hook.sh notification \"$CLAUDE_NOTIFICATION\""
}
```

**Step 3: claude-spawn start 時に worktree の CLAUDE.md にセッション ID を埋め込む処理を追加**

`_start_local()` 内で worktree 作成後に:

```bash
# CLAUDE.md にセッション情報を追記
mkdir -p "${worktree_path}/.claude"
cat >> "${worktree_path}/.claude/CLAUDE.md" <<EOF

# claude-spawn Session
export CLAUDE_SPAWN_SESSION_ID="${session_id}"
EOF
```

**Step 4: 動作確認**

dry-run モードでセッション作成し、hook が SESSION_ID なしでは何もしないことを確認。

**Step 5: コミット**

```bash
git add claude/hooks/spawn-phase-hook.sh claude/settings.json
git commit -m "feat: add Claude Code hooks for session phase tracking"
```

---

## Task 6: kanban-server セッション読み取り API

既存の kanban-server にセッション読み取り用エンドポイントを追加。

**Files:**
- Create: `~/.claude/tools/kanban-server/src/routes/sessions.ts`
- Create: `~/.claude/tools/kanban-server/src/repositories/session-repository.ts`
- Modify: `~/.claude/tools/kanban-server/server.ts` (ルート登録)

**Step 1: SessionRepository を作成**

`src/repositories/session-repository.ts`:

```typescript
import { join } from "@std/path";

export interface Session {
  id: string;
  name: string;
  description: string;
  status: "starting" | "in-progress" | "awaiting-review" | "done" | "failed";
  phase: string;
  host: string;
  worktree: string;
  branch: string;
  wezterm_pane_id: string;
  zellij_session: string | null;
  created_at: string;
  updated_at: string;
  waiting_since: string | null;
}

export class SessionRepository {
  private sessionsDir: string;

  constructor(dataDir: string) {
    this.sessionsDir = join(dataDir, "sessions");
  }

  async list(filters?: { host?: string; status?: string }): Promise<Session[]> {
    const sessions: Session[] = [];
    try {
      for await (const entry of Deno.readDir(this.sessionsDir)) {
        if (!entry.isFile || !entry.name.endsWith(".json")) continue;
        const content = await Deno.readTextFile(join(this.sessionsDir, entry.name));
        const session: Session = JSON.parse(content);
        if (filters?.host && session.host !== filters.host) continue;
        if (filters?.status && session.status !== filters.status) continue;
        sessions.push(session);
      }
    } catch (e) {
      if (!(e instanceof Deno.errors.NotFound)) throw e;
    }
    return sessions.sort((a, b) => b.updated_at.localeCompare(a.updated_at));
  }

  async get(id: string): Promise<Session | null> {
    try {
      const content = await Deno.readTextFile(join(this.sessionsDir, `${id}.json`));
      return JSON.parse(content);
    } catch {
      return null;
    }
  }

  async dashboard(): Promise<{
    sessions: Session[];
    byHost: Record<string, { count: number; maxSessions: number }>;
    awaitingReview: number;
  }> {
    const sessions = await this.list();
    const byHost: Record<string, { count: number; maxSessions: number }> = {};
    let awaitingReview = 0;

    for (const s of sessions) {
      if (!byHost[s.host]) byHost[s.host] = { count: 0, maxSessions: 0 };
      byHost[s.host].count++;
      if (s.status === "awaiting-review") awaitingReview++;
    }

    return { sessions, byHost, awaitingReview };
  }
}
```

**Step 2: セッションルートを作成**

`src/routes/sessions.ts`:

```typescript
import { Hono } from "@hono/hono";
import type { SessionRepository } from "../repositories/session-repository.ts";

export function sessionsRoutes(sessionRepo: SessionRepository): Hono {
  const app = new Hono();

  app.get("/", async (c) => {
    const host = c.req.query("host");
    const status = c.req.query("status");
    const sessions = await sessionRepo.list({ host, status });
    return c.json(sessions);
  });

  app.get("/dashboard", async (c) => {
    const data = await sessionRepo.dashboard();
    return c.json(data);
  });

  app.get("/:id", async (c) => {
    const session = await sessionRepo.get(c.req.param("id"));
    if (!session) return c.json({ error: "Session not found" }, 404);
    return c.json(session);
  });

  return app;
}
```

**Step 3: server.ts にルートを登録**

`server.ts` の既存のルート登録セクションに追加:

```typescript
import { SessionRepository } from "./src/repositories/session-repository.ts";
import { sessionsRoutes } from "./src/routes/sessions.ts";

// 既存の repository 初期化の後に追加
const sessionRepo = new SessionRepository(dataDir);

// 既存の api.route() の後に追加
api.route("/sessions", sessionsRoutes(sessionRepo));
```

**Step 4: テスト実行**

Run: `cd ~/.claude/tools/kanban-server && deno task dev`
別ターミナルで: `curl http://localhost:3456/api/sessions`
Expected: `[]` (空配列)

**Step 5: コミット**

```bash
cd ~/.claude/tools/kanban-server
git add src/repositories/session-repository.ts src/routes/sessions.ts server.ts
git commit -m "feat: add session read-only API endpoints"
```

---

## Task 7: kanban ダッシュボード UI にセッションタブを追加

既存の Terminal Luxe UI に Sessions タブを追加。

**Files:**
- Modify: `~/.claude/tools/kanban-server/public/index.html`

**Step 1: UI の現状を確認**

既存 UI は `public/index.html` (約 100KB の SPA)。タブ切替は vanilla JS で実装済み。

**Step 2: Sessions タブのナビゲーションを追加**

既存のタブナビゲーション HTML に Sessions タブを追加。

**Step 3: Sessions タブのコンテンツを実装**

Terminal Luxe スタイルに合わせた Sessions ビュー:

```html
<!-- Sessions タブコンテンツ -->
<div id="sessions-tab" class="tab-content hidden">
  <div class="sessions-header">
    <h2>Active Sessions</h2>
    <button onclick="refreshSessions()" class="btn-refresh">Refresh</button>
  </div>

  <div id="sessions-by-host" class="sessions-grid">
    <!-- JS で動的生成 -->
  </div>

  <div id="sessions-waiting" class="waiting-section">
    <h3>⏳ Awaiting Review</h3>
    <div id="waiting-list"></div>
  </div>

  <div id="sessions-activity" class="activity-section">
    <h3>Recent Activity</h3>
    <div id="activity-log"></div>
  </div>
</div>
```

**Step 4: JavaScript でセッションデータを取得・描画**

```javascript
async function refreshSessions() {
  const res = await fetch('/api/sessions/dashboard');
  const data = await res.json();
  renderSessionsByHost(data);
  renderWaitingList(data);
}

function renderSessionsByHost(data) {
  const container = document.getElementById('sessions-by-host');
  // ノード別にセッションをグループ化して表示
  // 各セッション: ステータスインジケーター（🟢/🟡/🔴）+ name + phase
  // ...
}

function renderWaitingList(data) {
  const container = document.getElementById('waiting-list');
  const waiting = data.sessions.filter(s => s.status === 'awaiting-review');
  // 承認待ちセッション一覧 + 経過時間表示
  // ...
}

// 30秒ごとに自動リフレッシュ
setInterval(refreshSessions, 30000);
```

**Step 5: スタイリング（Terminal Luxe テーマ準拠）**

既存の CSS 変数・カラーパレットを使用:
- amber (#c0752a) for WAITING 状態
- sage green for active 状態
- 既存のカード・グリッドスタイルを流用

**Step 6: 動作確認**

ブラウザで http://localhost:3456 を開き、Sessions タブが表示されることを確認。

**Step 7: コミット**

```bash
cd ~/.claude/tools/kanban-server
git add public/index.html
git commit -m "feat: add Sessions tab to kanban dashboard UI"
```

---

## Task 8: 設定テンプレートと初期セットアップ

初回セットアップを簡単にするためのテンプレートファイルとセットアップスクリプト。

**Files:**
- Create: `claude/templates/claude-spawn-config.toml`
- Create: `claude/templates/claude-session.kdl`
- Create: `bin/claude-spawn-setup`

**Step 1: 設定テンプレートを作成**

`claude/templates/claude-spawn-config.toml`:

```toml
# claude-spawn configuration
# Copy to ~/.config/claude-spawn/config.toml and customize

[local]
worktree_dir = ".worktrees"
max_sessions = 4

# Remote nodes (uncomment and configure as needed)
# [nodes.mac-mini]
# host = "mac-mini"
# worktree_dir = "~/worktrees"
# max_sessions = 2

[kanban]
repo = "~/.claude/kanban"
sessions_dir = "sessions"

[notifications]
enabled = true
on_waiting = true
on_complete = true
```

`claude/templates/claude-session.kdl`:

```kdl
// zellij layout for claude-spawn remote sessions
layout {
    tab name="claude" {
        pane command="claude" {
            args "--resume"
        }
    }
}
```

**Step 2: セットアップスクリプトを作成**

`bin/claude-spawn-setup`:

```bash
#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
DOTFILES_DIR="${SCRIPT_DIR:h}"

echo "claude-spawn setup"
echo "=================="

# 1. 設定ディレクトリ作成
CONFIG_DIR="${HOME}/.config/claude-spawn"
if [[ ! -d "$CONFIG_DIR" ]]; then
  mkdir -p "$CONFIG_DIR"
  echo "Created: $CONFIG_DIR"
fi

# 2. 設定ファイルコピー
if [[ ! -f "$CONFIG_DIR/config.toml" ]]; then
  cp "${DOTFILES_DIR}/claude/templates/claude-spawn-config.toml" "$CONFIG_DIR/config.toml"
  echo "Created: $CONFIG_DIR/config.toml (edit this file to configure nodes)"
else
  echo "Exists: $CONFIG_DIR/config.toml"
fi

# 3. sessions ディレクトリ作成
SESSIONS_DIR="${HOME}/.claude/kanban/sessions"
if [[ ! -d "$SESSIONS_DIR" ]]; then
  mkdir -p "$SESSIONS_DIR"
  echo "Created: $SESSIONS_DIR"
fi

# 4. .gitignore に .worktrees を追加（未追加の場合）
GITIGNORE="${DOTFILES_DIR}/.gitignore"
if ! grep -q "^\.worktrees" "$GITIGNORE" 2>/dev/null; then
  echo ".worktrees" >> "$GITIGNORE"
  echo "Added .worktrees to .gitignore"
fi

# 5. bin を PATH に追加する案内
if ! command -v claude-spawn &>/dev/null; then
  echo ""
  echo "NOTE: Add to your shell config:"
  echo "  export PATH=\"${DOTFILES_DIR}/bin:\$PATH\""
fi

echo ""
echo "Setup complete. Edit $CONFIG_DIR/config.toml to configure remote nodes."
echo "Run 'claude-spawn help' to get started."
```

**Step 3: 実行権限付与**

Run: `chmod +x bin/claude-spawn-setup`

**Step 4: セットアップを実行して動作確認**

Run: `bin/claude-spawn-setup`
Expected: 各ディレクトリ・ファイルの作成確認メッセージ

**Step 5: コミット**

```bash
git add claude/templates/ bin/claude-spawn-setup
git commit -m "feat: add claude-spawn setup script and config templates"
```

---

## Task 9: 統合テストと動作確認

全コンポーネントを結合して end-to-end の動作確認。

**Files:**
- Create: `claude/scripts/claude-spawn-e2e_spec.sh`

**Step 1: E2E テストを書く**

```bash
#!/usr/bin/env bash

Describe "claude-spawn E2E (dry-run)"
  setup() {
    export TEST_SESSIONS_DIR
    TEST_SESSIONS_DIR="$(mktemp -d)/sessions"
    mkdir -p "$TEST_SESSIONS_DIR"
    export TEST_CONFIG_DIR
    TEST_CONFIG_DIR="$(mktemp -d)"
    cat > "$TEST_CONFIG_DIR/config.toml" <<'TOML'
[local]
worktree_dir = ".worktrees"
max_sessions = 3

[nodes.test-remote]
host = "test-remote"
worktree_dir = "~/worktrees"
max_sessions = 2

[kanban]
repo = "~/.claude/kanban"
sessions_dir = "sessions"
TOML
    export CLAUDE_SPAWN_CONFIG="$TEST_CONFIG_DIR/config.toml"
    export CLAUDE_SPAWN_DRY_RUN=1
  }

  cleanup() {
    rm -rf "$(dirname "$TEST_SESSIONS_DIR")" "$TEST_CONFIG_DIR"
  }

  BeforeEach setup
  AfterEach cleanup

  Describe "full lifecycle"
    It "start → list → clean"
      # start
      run bin/claude-spawn start --name e2e-test --desc "E2E test feature"
      The status should be success

      # list
      run bin/claude-spawn list
      The output should include "e2e-test"

      # clean
      run bin/claude-spawn clean e2e-test
      The status should be success

      # verify cleaned
      run bin/claude-spawn list
      The output should include "No active sessions"
    End
  End

  Describe "max sessions enforcement"
    It "rejects when max_sessions reached"
      bin/claude-spawn start --name a --desc "a" >/dev/null
      bin/claude-spawn start --name b --desc "b" >/dev/null
      bin/claude-spawn start --name c --desc "c" >/dev/null
      When run bin/claude-spawn start --name d --desc "d"
      The status should be failure
      The stderr should include "Max sessions"
    End
  End

  Describe "node listing"
    It "shows both local and remote nodes"
      When run bin/claude-spawn nodes
      The output should include "local"
      The output should include "test-remote"
    End
  End
End
```

**Step 2: テスト実行**

Run: `shellspec claude/scripts/claude-spawn-e2e_spec.sh`
Expected: All examples passed

**Step 3: コミット**

```bash
git add claude/scripts/claude-spawn-e2e_spec.sh
git commit -m "test: add claude-spawn E2E integration tests"
```

---

## 依存関係

```
Task 1 (session-lib) ← Task 2 (config parser) ← Task 3 (CLI)
                                                      ↓
                                               Task 4 (WezTerm)
                                               Task 5 (hooks)
                                               Task 6 (kanban API) ← Task 7 (dashboard UI)
                                               Task 8 (setup)
                                                      ↓
                                               Task 9 (E2E テスト)
```

Tasks 4, 5, 6, 8 は Task 3 完了後に並列実行可能。Task 7 は Task 6 に依存。Task 9 は全タスク完了後。
