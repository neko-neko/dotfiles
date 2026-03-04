# Claude Code 設定改善 実装計画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Claude Code の dotfiles 設定を改善する — post-commit.sh のパス解決バグ修正、notify.sh のリッチ化、CLAUDE.md の簡素化、SessionStart フックの新規追加

**Architecture:** handover-lib.sh の git コマンドに `-C` オプションを追加してパス解決を修正。notify.sh にタイプ別アイコンを追加。CLAUDE.md から Handover 詳細を handover/SKILL.md に移動して簡素化。session-start.sh を新規作成し handover セッション確認を自動化。

**Tech Stack:** Bash, ShellSpec (テスト), jq, WezTerm user-var protocol

---

### Task 1: handover-lib.sh の get_current_branch() にパス引数を追加

**Files:**
- Modify: `claude/skills/handover/scripts/handover-lib.sh:362-384`

**Step 1: Write the failing test**

`claude/skills/handover/scripts/handover_lib_spec.sh` のセクション 10 (get_current_branch) に以下のテストを追加:

```bash
    It "uses -C flag when project_dir is provided"
      git() {
        if [ "$1" = "-C" ] && [ "$2" = "/other/repo" ] && [ "$3" = "rev-parse" ] && [ "$4" = "--abbrev-ref" ]; then
          echo "feature/remote-branch"
          return 0
        fi
        echo "main"
        return 0
      }
      When call get_current_branch "/other/repo"
      The output should eq "feature/remote-branch"
    End
```

**Step 2: Run test to verify it fails**

Run: `shellspec claude/skills/handover/scripts/handover_lib_spec.sh --example "get_current_branch uses -C flag"`
Expected: FAIL (get_current_branch doesn't accept arguments yet)

**Step 3: Write minimal implementation**

`handover-lib.sh` の `get_current_branch()` を以下に置き換え:

```bash
get_current_branch() {
  local git_args=()
  if [[ -n "${1:-}" ]]; then
    git_args=(-C "$1")
  fi

  local branch
  branch="$(git "${git_args[@]}" rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [[ -z "$branch" ]]; then
    _handover_log "ERROR: unable to determine branch (not in a git repository?)"
    return 1
  fi

  if [[ "$branch" == "HEAD" ]]; then
    local sha
    sha="$(git "${git_args[@]}" rev-parse --short=7 HEAD 2>/dev/null)"
    if [[ -z "$sha" ]]; then
      _handover_log "ERROR: unable to determine commit hash"
      return 1
    fi
    echo "detached-${sha}"
  else
    echo "$branch"
  fi
}
```

**Step 4: Run test to verify it passes**

Run: `shellspec claude/skills/handover/scripts/handover_lib_spec.sh --example "get_current_branch"`
Expected: ALL PASS (既存テスト含む)

**Step 5: Commit**

```bash
git add claude/skills/handover/scripts/handover-lib.sh claude/skills/handover/scripts/handover_lib_spec.sh
git commit -m "fix: add -C support to get_current_branch for cross-repo use"
```

---

### Task 2: find_active_session_dir() から get_current_branch にルートを渡す

**Files:**
- Modify: `claude/skills/handover/scripts/handover-lib.sh:411-444`

**Step 1: Write the failing test**

`handover_lib_spec.sh` のセクション 12 (find_active_session_dir) に以下のテストを追加:

```bash
    It "passes root to get_current_branch (uses -C flag)"
      # git mock that ONLY responds to -C calls — verifies find_active_session_dir
      # passes root properly
      git() {
        if [ "$1" = "-C" ] && [ "$2" = "$test_root" ] && [ "$3" = "rev-parse" ] && [ "$4" = "--abbrev-ref" ]; then
          echo "main"
          return 0
        fi
        # Without -C: fail to prove the function uses -C
        if [ "$1" = "rev-parse" ] && [ "$2" = "--abbrev-ref" ]; then
          echo "wrong-branch"
          return 0
        fi
      }
      When call find_active_session_dir "$test_root"
      The status should be success
      The output should include "session-001"
    End
```

**Step 2: Run test to verify it fails**

Run: `shellspec claude/skills/handover/scripts/handover_lib_spec.sh --example "find_active_session_dir passes root"`
Expected: FAIL (looks for wrong-branch directory)

**Step 3: Write minimal implementation**

`handover-lib.sh:420` の `branch="$(get_current_branch)" || return 1` を以下に変更:

```bash
  branch="$(get_current_branch "$root")" || return 1
```

**Step 4: Run test to verify it passes**

Run: `shellspec claude/skills/handover/scripts/handover_lib_spec.sh`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add claude/skills/handover/scripts/handover-lib.sh claude/skills/handover/scripts/handover_lib_spec.sh
git commit -m "fix: pass project root to get_current_branch in find_active_session_dir"
```

---

### Task 3: notify.sh にタイプ別アイコンを追加

**Files:**
- Modify: `claude/hooks/notify.sh`

**Step 1: notify.sh を書き換え**

```bash
#!/bin/bash
set -euo pipefail

MESSAGE="${1:?Usage: notify.sh MESSAGE TITLE TYPE}"
TITLE="${2:?Usage: notify.sh MESSAGE TITLE TYPE}"
TYPE="${3:?Usage: notify.sh MESSAGE TITLE TYPE}"

# タイプ別アイコンとタイムアウト
case "$TYPE" in
  idle)       ICON="✅"; TIMEOUT=5000 ;;
  permission) ICON="🔐"; TIMEOUT=0    ;;
  question)   ICON="💬"; TIMEOUT=0    ;;
  *)          ICON="📢"; TIMEOUT=5000 ;;
esac

DISPLAY_TITLE="${ICON} ${TITLE}"

# WezTerm の user-var エスケープシーケンスで toast_notification をトリガー
VALUE="$(printf '%s\t%s\t%s' "$DISPLAY_TITLE" "$MESSAGE" "$TIMEOUT")"
ENCODED="$(printf '%s' "$VALUE" | base64)"
ESCAPE_SEQ="$(printf "\033]1337;SetUserVar=%s=%s\007" "claude_notify" "$ENCODED")"

if (printf '%s' "$ESCAPE_SEQ" > /dev/tty) 2>/dev/null; then
  : # WezTerm toast_notification に送信成功
else
  # TTY が使えない場合は osascript にフォールバック
  osascript -e "display notification \"$MESSAGE\" with title \"$DISPLAY_TITLE\""
fi
```

**Step 2: 手動テスト**

Run: `bash claude/hooks/notify.sh "Test message" "Claude Code" idle`
Expected: WezTerm toast に ✅ アイコン付きで表示

Run: `bash claude/hooks/notify.sh "Test message" "Claude Code" permission`
Expected: WezTerm toast に 🔐 アイコン付きで表示

**Step 3: Commit**

```bash
git add claude/hooks/notify.sh
git commit -m "feat: add type-specific icons to notify.sh"
```

---

### Task 4: CLAUDE.md から Handover 詳細を削除して簡素化

**Files:**
- Modify: `claude/CLAUDE.md`

**Step 1: CLAUDE.md を以下の内容に書き換え**

```markdown
# コミュニケーション方針

 - 技術的に誤った意見には根拠を示して反論すること。懸念・代替案は実装提案の前に伝える
 - 曖昧な指示に対しては推測で進めず、具体的に確認すること

## 出力方針

 - 設計・レビュー・分析は分割確認せず、完全な形で一度に出力すること

## 実装規律

 - 初回の実装パスでバリデーション（範囲制約、境界値、型チェック）を含めること
 - コミット前に linter・型チェッカー・フォーマッター・テストを実行すること

## マルチエージェント

 - サブエージェントには明確なスコープと完了条件を与え、作業の重複を防ぐこと
 - サブエージェントの出力は検証すること

## Intent Guard

 - サブエージェント生成時、model パラメータはユーザーが明示的に指定した場合のみ設定する。指定がなければ省略（親モデルを継承）すること
 - 3ステップ以上のマルチステップ作業は、計画（brainstorming / writing-plans / EnterPlanMode のいずれか）を経てから実行すること。計画フェーズのスキップ禁止

## セッション管理

 - 完了タスクの要約・整理はユーザーに指摘される前に行うこと
 - handover の詳細なプロトコルは `/handover` スキルを参照すること

## Document Dependency Check

- md ファイルの frontmatter に `depends-on` が宣言されている場合、そのドキュメントはコード変更の影響を受ける可能性がある
- コード変更を含むタスクを完了する際、`/doc-check` の実行を検討すること
- ドキュメントの更新はユーザー承認後に行うこと。自動更新は禁止
```

**Step 2: 確認**

CLAUDE.md が約30行になったことを確認。Handover Protocol 関連のルールがすべて削除されていることを確認。

**Step 3: Commit**

```bash
git add claude/CLAUDE.md
git commit -m "refactor: simplify CLAUDE.md by moving Handover details to skill"
```

---

### Task 5: handover SKILL.md に CLAUDE.md から移動したルールを追加

**Files:**
- Modify: `claude/skills/handover/SKILL.md`

**Step 1: SKILL.md の末尾に以下のセクションを追加**

```markdown
## CLAUDE.md から移動したルール

以下のルールは以前 CLAUDE.md に記載されていたもので、handover スキルの一部として適用される。

### Handover Protocol

- `continue from handover` や handover.md への言及があった場合、まず前回の変更がコミット済みか `git log` で確認してから作業を開始すること
- 全タスク完了済み（status: ALL_COMPLETE）なら即座にその旨を報告し、コードベースの探索を始めないこと
- handover 文書には必ず以下を含めること:
  - 具体的なファイルパス
  - タスクID（T1, T2, ...）
  - ブロッカー（あれば）
  - コミット SHA（完了タスク）
- handover.md は project-state.json から自動生成されたビューであり、直接編集しないこと

### v2 マイグレーション

- `.claude/project-state.json`（v2 形式）が残っている場合は新パス `.claude/handover/{branch}/{fingerprint}/` へマイグレーションすること
```

**Step 2: 確認**

SKILL.md にルールが追加され、既存の内容と重複がないことを確認。

**Step 3: Commit**

```bash
git add claude/skills/handover/SKILL.md
git commit -m "refactor: absorb Handover Protocol rules from CLAUDE.md into SKILL.md"
```

---

### Task 6: session-start.sh を新規作成

**Files:**
- Create: `claude/hooks/session-start.sh`

**Step 1: スクリプトを作成**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../skills/handover/scripts/handover-lib.sh"

# プロジェクトルートを取得
PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

HANDOVER_BASE="${PROJECT_DIR}/.claude/handover"

# handover ディレクトリがなければ何もしない
[[ -d "$HANDOVER_BASE" ]] || exit 0

# アクティブセッションをスキャン
SESSIONS="$(scan_sessions "$HANDOVER_BASE")"
SESSION_COUNT="$(echo "$SESSIONS" | jq 'length')"

if [[ "$SESSION_COUNT" -eq 0 ]]; then
  exit 0
fi

# READY セッション情報を出力
echo "📋 Handover sessions found:"
echo "$SESSIONS" | jq -r '.[] | "  - [\(.branch)/\(.fingerprint)] tasks: \(.done_tasks)/\(.total_tasks) | next: \(.next_action)"'
echo ""
echo "Use '/continue' to resume, or start fresh."
```

**Step 2: 実行権限を付与**

Run: `chmod +x claude/hooks/session-start.sh`

**Step 3: 手動テスト**

Run: `bash claude/hooks/session-start.sh`
Expected: handover セッションがない場合は何も出力しない。セッションがある場合はサマリーが表示される。

**Step 4: Commit**

```bash
git add claude/hooks/session-start.sh
git commit -m "feat: add session-start.sh hook for automatic handover detection"
```

---

### Task 7: settings.json に SessionStart フックを追加

**Files:**
- Modify: `claude/settings.json`

**Step 1: settings.json の hooks セクションに SessionStart を追加**

`hooks` オブジェクト内の `"PostToolUse"` の後に以下を追加:

```json
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${HOME}/.dotfiles/claude/hooks/session-start.sh\"",
            "timeout": 10
          }
        ]
      }
    ]
```

**Step 2: JSON syntax の確認**

Run: `jq empty claude/settings.json`
Expected: exit 0 (valid JSON)

**Step 3: Commit**

```bash
git add claude/settings.json
git commit -m "feat: register session-start.sh as SessionStart hook"
```

---

### Task 8: 全テストを実行して確認

**Files:**
- None (verification only)

**Step 1: ShellSpec テストをすべて実行**

Run: `shellspec`
Expected: ALL PASS

**Step 2: notify.sh の動作確認**

Run: `bash claude/hooks/notify.sh "test" "Claude Code" idle`
Run: `bash claude/hooks/notify.sh "test" "Claude Code" permission`
Run: `bash claude/hooks/notify.sh "test" "Claude Code" question`
Expected: 各タイプで正しいアイコンが表示される

**Step 3: session-start.sh の動作確認**

Run: `bash claude/hooks/session-start.sh`
Expected: 正常終了（handover セッションの有無に応じて出力）
