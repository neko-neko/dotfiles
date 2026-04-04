# `.claude/` → `.agents/` 移行 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** プロジェクトローカルの `.claude/handover/` パスを `.agents/handover/` に直接置換し、Claude Code 固有ディレクトリへの結合を排除する

**Architecture:** 全10ファイル・32箇所の文字列置換。シェルスクリプトは実装+テストを同時に変更してテスト実行で検証。SKILL.md はプロンプトテキストの置換のみ。

**Tech Stack:** Bash (shellspec), Markdown

**Design spec:** `docs/superpowers/specs/2026-04-05-agents-dir-migration-design.md`

---

### Task 1: .gitignore に `.agents` を追加

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: `.agents` エントリを追加**

`.gitignore` の `.worktrees` の直後に追加:

```
.worktrees
.agents
```

- [ ] **Step 2: コミット**

```bash
git add .gitignore
git commit -m "add .agents to .gitignore"
```

---

### Task 2: handover-lib.sh + テストのパス置換

**Files:**
- Modify: `claude/skills/handover/scripts/handover-lib.sh:448,473,493`
- Modify: `claude/skills/handover/scripts/handover_lib_spec.sh:367-370,409`

- [ ] **Step 1: handover-lib.sh の3箇所を置換**

Line 448:
```bash
# before
  local branch_dir="${root}/.claude/handover/${branch}"
# after
  local branch_dir="${root}/.agents/handover/${branch}"
```

Line 473 (コメント):
```bash
# before
# - Reuses an existing READY session if found under {root}/.claude/handover/{branch}/
# after
# - Reuses an existing READY session if found under {root}/.agents/handover/{branch}/
```

Line 493:
```bash
# before
  local new_dir="${root}/.claude/handover/${branch}/${fingerprint}"
# after
  local new_dir="${root}/.agents/handover/${branch}/${fingerprint}"
```

- [ ] **Step 2: handover_lib_spec.sh の5箇所を置換**

Line 367-370:
```bash
# before
      mkdir -p "$test_root/.claude/handover/main/session-001"
      cp "$FIXTURES_DIR/valid-v4.json" "$test_root/.claude/handover/main/session-001/project-state.json"
      mkdir -p "$test_root/.claude/handover/main/session-002"
      cp "$FIXTURES_DIR/all-complete.json" "$test_root/.claude/handover/main/session-002/project-state.json"
# after
      mkdir -p "$test_root/.agents/handover/main/session-001"
      cp "$FIXTURES_DIR/valid-v4.json" "$test_root/.agents/handover/main/session-001/project-state.json"
      mkdir -p "$test_root/.agents/handover/main/session-002"
      cp "$FIXTURES_DIR/all-complete.json" "$test_root/.agents/handover/main/session-002/project-state.json"
```

Line 409:
```bash
# before
      rm -rf "$test_root/.claude/handover/main/session-001"
# after
      rm -rf "$test_root/.agents/handover/main/session-001"
```

- [ ] **Step 3: handover_lib_spec.sh を実行して PASS を確認**

```bash
cd ~/.dotfiles && shellspec claude/skills/handover/scripts/handover_lib_spec.sh
```

Expected: `find_active_session_dir()` の3テスト（finds READY, failure on different branch, skips ALL_COMPLETE）が PASS

- [ ] **Step 4: コミット**

```bash
git add claude/skills/handover/scripts/handover-lib.sh claude/skills/handover/scripts/handover_lib_spec.sh
git commit -m "migrate handover-lib.sh paths from .claude/ to .agents/"
```

---

### Task 3: hooks のパス置換

**Files:**
- Modify: `claude/hooks/session-start.sh:10`
- Modify: `claude/hooks/post_commit_spec.sh:226,253,272,279`

- [ ] **Step 1: session-start.sh の1箇所を置換**

Line 10:
```bash
# before
HANDOVER_BASE="${PROJECT_DIR}/.claude/handover"
# after
HANDOVER_BASE="${PROJECT_DIR}/.agents/handover"
```

- [ ] **Step 2: post_commit_spec.sh の4箇所を置換**

Line 226 (コメント):
```bash
# before
      # Don't create any .claude/handover/ directory — no session
# after
      # Don't create any .agents/handover/ directory — no session
```

Line 253:
```bash
# before
      local session_dir="${MOCK_PROJECT_DIR}/.claude/handover/main/test-session"
# after
      local session_dir="${MOCK_PROJECT_DIR}/.agents/handover/main/test-session"
```

Line 272:
```bash
# before
      local state_file="${MOCK_PROJECT_DIR}/.claude/handover/main/test-session/project-state.json"
# after
      local state_file="${MOCK_PROJECT_DIR}/.agents/handover/main/test-session/project-state.json"
```

Line 279:
```bash
# before
      local handover_file="${MOCK_PROJECT_DIR}/.claude/handover/main/test-session/handover.md"
# after
      local handover_file="${MOCK_PROJECT_DIR}/.agents/handover/main/test-session/handover.md"
```

- [ ] **Step 3: post_commit_spec.sh を実行して PASS を確認**

```bash
cd ~/.dotfiles && shellspec claude/hooks/post_commit_spec.sh
```

Expected: 全3テスト（not in git repo, no active session, active session full flow）が PASS

- [ ] **Step 4: コミット**

```bash
git add claude/hooks/session-start.sh claude/hooks/post_commit_spec.sh
git commit -m "migrate hooks paths from .claude/ to .agents/"
```

---

### Task 4: handover/SKILL.md のパス置換

**Files:**
- Modify: `claude/skills/handover/SKILL.md:21,29,31,34,167,254,293`

- [ ] **Step 1: 7箇所を置換**

Line 21:
```markdown
<!-- before -->
3. **チーム所属あり** → `.claude/handover/{team-name}/{agent-name}/`（以降のブランチ分離は適用しない）
<!-- after -->
3. **チーム所属あり** → `.agents/handover/{team-name}/{agent-name}/`（以降のブランチ分離は適用しない）
```

Line 29:
```markdown
<!-- before -->
     > worktree `{path}` が検出されました。こちらの `.claude/` に保存しますか？
<!-- after -->
     > worktree `{path}` が検出されました。こちらの `.agents/` に保存しますか？
```

Line 31:
```markdown
<!-- before -->
3. `{root}/.claude/handover/{branch}/` 配下を走査:
<!-- after -->
3. `{root}/.agents/handover/{branch}/` 配下を走査:
```

Line 34:
```markdown
<!-- before -->
4. 保存先: `{root}/.claude/handover/{branch}/{fingerprint}/`
<!-- after -->
4. 保存先: `{root}/.agents/handover/{branch}/{fingerprint}/`
```

Line 167:
```markdown
<!-- before -->
1. `.claude/handover/{branch}/{fingerprint}/phase-summaries/` ディレクトリを作成
<!-- after -->
1. `.agents/handover/{branch}/{fingerprint}/phase-summaries/` ディレクトリを作成
```

Line 254:
```markdown
<!-- before -->
handover 実行時に、`{root}/.claude/handover/` 配下の `ALL_COMPLETE` かつ `generated_at` が7日以上前のセッションディレクトリを自動削除する。削除前にログ出力する。
<!-- after -->
handover 実行時に、`{root}/.agents/handover/` 配下の `ALL_COMPLETE` かつ `generated_at` が7日以上前のセッションディレクトリを自動削除する。削除前にログ出力する。
```

Line 293:
```markdown
<!-- before -->
- `.claude/` ディレクトリが存在しない場合は作成すること
<!-- after -->
- `.agents/` ディレクトリが存在しない場合は作成すること
```

- [ ] **Step 2: コミット**

```bash
git add claude/skills/handover/SKILL.md
git commit -m "migrate handover/SKILL.md paths from .claude/ to .agents/"
```

---

### Task 5: continue/SKILL.md のパス置換

**Files:**
- Modify: `claude/skills/continue/SKILL.md:17,21,23,105,115,185`

- [ ] **Step 1: 6箇所を置換**

Line 17:
```markdown
<!-- before -->
4. **チーム所属あり** → `.claude/handover/{team-name}/{agent-name}/`
<!-- after -->
4. **チーム所属あり** → `.agents/handover/{team-name}/{agent-name}/`
```

Line 21:
```markdown
<!-- before -->
1. `{cwd}/.claude/handover/` を走査し、利用可能なセッション（status が `READY`）を収集する（グループ: **CWD**）
<!-- after -->
1. `{cwd}/.agents/handover/` を走査し、利用可能なセッション（status が `READY`）を収集する（グループ: **CWD**）
```

Line 23:
```markdown
<!-- before -->
3. CWD 以外の各 worktree の `{path}/.claude/handover/` を走査し、READY セッションを収集する（グループ: **worktree**）
<!-- after -->
3. CWD 以外の各 worktree の `{path}/.agents/handover/` を走査し、READY セッションを収集する（グループ: **worktree**）
```

Line 105:
```markdown
<!-- before -->
     2. 切り替え先の `.claude/handover/` から `project-state.json` を読み込む
<!-- after -->
     2. 切り替え先の `.agents/handover/` から `project-state.json` を読み込む
```

Line 115:
```markdown
<!-- before -->
     4. orphan セッションのデータ（`project-state.json`, `handover.md`）を新しい worktree の `.claude/handover/{branch}/{fingerprint}/` にコピーする
<!-- after -->
     4. orphan セッションのデータ（`project-state.json`, `handover.md`）を新しい worktree の `.agents/handover/{branch}/{fingerprint}/` にコピーする
```

Line 185:
```markdown
<!-- before -->
continue 実行時に、CWD および全 worktree の `.claude/handover/` 配下で `ALL_COMPLETE` かつ `generated_at` が7日以上前のセッションディレクトリを自動削除する。削除前にログ出力する。
<!-- after -->
continue 実行時に、CWD および全 worktree の `.agents/handover/` 配下で `ALL_COMPLETE` かつ `generated_at` が7日以上前のセッションディレクトリを自動削除する。削除前にログ出力する。
```

- [ ] **Step 2: コミット**

```bash
git add claude/skills/continue/SKILL.md
git commit -m "migrate continue/SKILL.md paths from .claude/ to .agents/"
```

---

### Task 6: 残りのスキル・モジュールのパス置換

**Files:**
- Modify: `claude/skills/kanban/SKILL.md:35`
- Modify: `claude/skills/workflow-engine/modules/resume.md:13`
- Modify: `claude/skills/workflow-engine/modules/phase-summary.md:14`

- [ ] **Step 1: kanban/SKILL.md の1箇所を置換**

Line 35:
```markdown
<!-- before -->
1. 現在の `pwd` から `.claude/handover/` 配下の最新 `project-state.json` を探す
<!-- after -->
1. 現在の `pwd` から `.agents/handover/` 配下の最新 `project-state.json` を探す
```

- [ ] **Step 2: resume.md の1箇所を置換**

Line 13:
```markdown
<!-- before -->
1. `.claude/handover/{branch}/` を走査し、`project-state.json` を検索
<!-- after -->
1. `.agents/handover/{branch}/` を走査し、`project-state.json` を検索
```

- [ ] **Step 3: phase-summary.md の1箇所を置換**

Line 14:
```markdown
<!-- before -->
`.claude/handover/{branch}/{fingerprint}/phase-summaries/{phase_id}.yml`
<!-- after -->
`.agents/handover/{branch}/{fingerprint}/phase-summaries/{phase_id}.yml`
```

- [ ] **Step 4: コミット**

```bash
git add claude/skills/kanban/SKILL.md claude/skills/workflow-engine/modules/resume.md claude/skills/workflow-engine/modules/phase-summary.md
git commit -m "migrate remaining skill paths from .claude/ to .agents/"
```

---

### Task 7: 最終検証

- [ ] **Step 1: `.claude/handover` がプロジェクトローカル参照として残っていないことを確認**

```bash
cd ~/.dotfiles && grep -r '\.claude/handover' claude/skills/ claude/hooks/ .gitignore --include='*.md' --include='*.sh' --include='*.json'
```

Expected: 出力なし（0件）。`~/.claude/` 参照（ホームディレクトリ）は残っていてよい。

- [ ] **Step 2: `.agents/handover` が正しく置換されていることを確認**

```bash
cd ~/.dotfiles && grep -r '\.agents/handover' claude/skills/ claude/hooks/ --include='*.md' --include='*.sh' | wc -l
```

Expected: 27行（SKILL.md 17箇所 + シェルスクリプト 10箇所）

- [ ] **Step 3: 全テストを実行**

```bash
cd ~/.dotfiles && shellspec claude/skills/handover/scripts/handover_lib_spec.sh && shellspec claude/hooks/post_commit_spec.sh
```

Expected: 全テスト PASS
