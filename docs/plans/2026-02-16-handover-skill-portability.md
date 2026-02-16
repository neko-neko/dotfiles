# Handover Skill 可搬性リファクタリング 実装計画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** bin/ 配下の handover 関連スクリプトを skill creator ボイラープレート構造に移行し、可搬性を改善する

**Architecture:** handover-lib.sh を handover skill の scripts/ に配置し単一ソースとする。post-commit hook は claude/hooks/ に分離し、lib を相対パスで source する。bin/ から handover 関連3ファイルを完全除去。

**Tech Stack:** Bash, jq, git

---

### Task 1: handover/scripts/ ディレクトリ作成とスクリプト移動

**Files:**
- Create: `claude/skills/handover/scripts/` ディレクトリ
- Move: `bin/claude-handover-lib.sh` → `claude/skills/handover/scripts/handover-lib.sh`
- Move: `bin/claude-handover` → `claude/skills/handover/scripts/claude-handover.sh`

**Step 1: ディレクトリ作成**

```bash
mkdir -p claude/skills/handover/scripts
```

**Step 2: lib.sh を移動**

```bash
git mv bin/claude-handover-lib.sh claude/skills/handover/scripts/handover-lib.sh
```

**Step 3: claude-handover を移動**

```bash
git mv bin/claude-handover claude/skills/handover/scripts/claude-handover.sh
```

**Step 4: claude-handover.sh の source パスを修正**

`claude/skills/handover/scripts/claude-handover.sh` の9行目:

変更前:
```bash
source "${SCRIPT_DIR}/claude-handover-lib.sh"
```

変更後:
```bash
source "${SCRIPT_DIR}/handover-lib.sh"
```

**Step 5: 実行権限を確認**

```bash
chmod +x claude/skills/handover/scripts/claude-handover.sh
chmod +x claude/skills/handover/scripts/handover-lib.sh
```

**Step 6: コミット**

```bash
git add claude/skills/handover/scripts/
git commit -m "refactor: handover スクリプトを skill/scripts/ に移動"
```

---

### Task 2: claude/hooks/ ディレクトリ作成と post-commit 移動

**Files:**
- Create: `claude/hooks/` ディレクトリ
- Move: `bin/claude-post-commit` → `claude/hooks/post-commit.sh`

**Step 1: ディレクトリ作成**

```bash
mkdir -p claude/hooks
```

**Step 2: post-commit を移動**

```bash
git mv bin/claude-post-commit claude/hooks/post-commit.sh
```

**Step 3: post-commit.sh の source パスを修正**

`claude/hooks/post-commit.sh` の7行目:

変更前:
```bash
source "${SCRIPT_DIR}/claude-handover-lib.sh"
```

変更後:
```bash
source "${SCRIPT_DIR}/../skills/handover/scripts/handover-lib.sh"
```

**Step 4: 実行権限を確認**

```bash
chmod +x claude/hooks/post-commit.sh
```

**Step 5: コミット**

```bash
git add claude/hooks/post-commit.sh
git commit -m "refactor: post-commit hook を claude/hooks/ に移動"
```

---

### Task 3: settings.json の hook command パス更新

**Files:**
- Modify: `claude/settings.json:215`

**Step 1: hook command のパスを更新**

変更前:
```json
"command": "if echo \"$CLAUDE_TOOL_INPUT\" | jq -r '.command' 2>/dev/null | grep -qE 'git commit'; then claude-post-commit; fi"
```

変更後:
```json
"command": "if echo \"$CLAUDE_TOOL_INPUT\" | jq -r '.command' 2>/dev/null | grep -qE 'git commit'; then \"${HOME}/.dotfiles/claude/hooks/post-commit.sh\"; fi"
```

**Step 2: コミット**

```bash
git add claude/settings.json
git commit -m "refactor: hook command のパスを claude/hooks/ に更新"
```

---

### Task 4: 動作検証

**Step 1: handover-lib.sh の source テスト（handover 側）**

```bash
bash -c 'SCRIPT_DIR="$(cd "$(dirname "claude/skills/handover/scripts/claude-handover.sh")" && pwd)"; source "${SCRIPT_DIR}/handover-lib.sh" && echo "OK: lib sourced from handover"'
```

Expected: `OK: lib sourced from handover`

**Step 2: handover-lib.sh の source テスト（hooks 側）**

```bash
bash -c 'SCRIPT_DIR="$(cd "$(dirname "claude/hooks/post-commit.sh")" && pwd)"; source "${SCRIPT_DIR}/../skills/handover/scripts/handover-lib.sh" && echo "OK: lib sourced from hooks"'
```

Expected: `OK: lib sourced from hooks`

**Step 3: shellcheck による静的解析**

```bash
shellcheck claude/skills/handover/scripts/claude-handover.sh
shellcheck claude/skills/handover/scripts/handover-lib.sh
shellcheck claude/hooks/post-commit.sh
```

**Step 4: bin/ に残骸がないことを確認**

```bash
ls bin/claude-handover* bin/claude-post-commit 2>&1
```

Expected: すべて `No such file or directory`

**Step 5: 最終コミット（検証結果に基づく修正があれば）**

```bash
git add -A && git commit -m "fix: 検証で見つかった問題を修正"
```
