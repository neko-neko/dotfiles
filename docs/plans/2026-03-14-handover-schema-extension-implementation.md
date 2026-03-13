# Handover Schema Extension: attempted_approaches Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `attempted_approaches` field to handover project-state.json schema to capture failed/abandoned approaches, and display them in handover.md

**Architecture:** Optional array field on each task object in `active_tasks`. The `generate_handover_md()` function in handover-lib.sh renders these as `tried:` lines. SKILL.md documents the schema and merge rules.

**Tech Stack:** Shell (bash), jq, ShellSpec (testing)

---

### Task 1: Add attempted_approaches to test fixture (mixed-tasks.json)

**Files:**
- Modify: `claude/skills/handover/scripts/fixtures/mixed-tasks.json`

**Step 1: Update mixed-tasks.json to include attempted_approaches on the in_progress task**

```json
{ "id": "T2", "description": "In progress task", "status": "in_progress", "file_paths": ["src/b.sh"], "next_action": "Continue coding", "attempted_approaches": [{"approach": "Used grep-based parsing", "result": "failed", "reason": "Could not handle multiline values", "learnings": "Need a proper JSON parser"}], "last_touched": "2026-01-15T09:30:00Z" }
```

T3 (blocked task) should also get an `attempted_approaches` with result `abandoned`:

```json
{ "id": "T3", "description": "Blocked task", "status": "blocked", "file_paths": ["src/c.sh"], "next_action": "Wait for review", "blockers": ["PR #42 pending"], "attempted_approaches": [{"approach": "Direct API call", "result": "abandoned", "reason": "API rate limits too strict", "learnings": "Use batch endpoint instead"}], "last_touched": "2026-01-15T09:00:00Z" }
```

**Step 2: Verify fixture is valid JSON**

Run: `jq empty claude/skills/handover/scripts/fixtures/mixed-tasks.json`
Expected: exit 0, no output

**Step 3: Commit**

```bash
git add claude/skills/handover/scripts/fixtures/mixed-tasks.json
git commit -m "test: add attempted_approaches to mixed-tasks fixture"
```

---

### Task 2: Write failing test for attempted_approaches in handover.md generation

**Files:**
- Modify: `claude/skills/handover/scripts/handover_lib_spec.sh`

**Step 1: Add test case to Section 6 (generate_handover_md)**

Add after the existing "includes blockers section" test (line ~197):

```shellspec
    It "includes attempted approaches as tried lines"
      When call generate_handover_md "$FIXTURES_DIR/mixed-tasks.json" "$md_output"
      The status should be success
      The contents of file "$md_output" should include "tried:"
      The contents of file "$md_output" should include "Used grep-based parsing"
      The contents of file "$md_output" should include "failed"
    End
```

**Step 2: Run the test to confirm it fails**

Run: `cd /Users/nishikataseiichi/.dotfiles && shellspec spec/handover_lib_spec.sh --example "includes attempted approaches"`
Expected: FAIL — `tried:` not found in output (generate_handover_md doesn't render attempted_approaches yet)

**Step 3: Commit**

```bash
git add claude/skills/handover/scripts/handover_lib_spec.sh
git commit -m "test: add failing test for attempted_approaches in handover.md"
```

---

### Task 3: Implement attempted_approaches rendering in generate_handover_md

**Files:**
- Modify: `claude/skills/handover/scripts/handover-lib.sh:162-209`

**Step 1: Update the jq query in generate_handover_md to render tried lines**

Update the `format_task` function inside the jq expression. The `in_progress` and `blocked` branches need a `tried:` line appended when `attempted_approaches` is present and non-empty.

Replace the `format_task` definition (lines 163-172) with:

```jq
    def format_approaches:
      if (.attempted_approaches // [] | length) > 0 then
        [.attempted_approaches[] |
          "\n  - tried: \(.approach) → \(.result): \(.reason) (\(.learnings))"] | join("")
      else "" end;

    def format_task:
      if .status == "done" then
        "- [\(.id)] \(.description) (\(.commit_sha // "no-sha"))"
      elif .status == "in_progress" then
        "- [\(.id)] **in_progress** \(.description)\n  - files: \((.file_paths // []) | join(", "))\n  - next: \(.next_action // "未定義")" + format_approaches
      elif .status == "blocked" then
        "- [\(.id)] **blocked** \(.description)\n  - files: \((.file_paths // []) | join(", "))\n  - next: \(.next_action // "未定義")\n  - blocker: \((.blockers // []) | join(", "))" + format_approaches
      else
        "- [\(.id)] **\(.status)** \(.description)"
      end;
```

**Step 2: Run the test to verify it passes**

Run: `cd /Users/nishikataseiichi/.dotfiles && shellspec spec/handover_lib_spec.sh --example "includes attempted approaches"`
Expected: PASS

**Step 3: Run all handover tests to check for regressions**

Run: `cd /Users/nishikataseiichi/.dotfiles && shellspec spec/handover_lib_spec.sh`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add claude/skills/handover/scripts/handover-lib.sh
git commit -m "feat: render attempted_approaches as tried lines in handover.md"
```

---

### Task 4: Update SKILL.md with schema documentation and merge rules

**Files:**
- Modify: `claude/skills/handover/SKILL.md:46-103`

**Step 1: Add attempted_approaches to the JSON schema in SKILL.md**

In the `active_tasks` array item schema (after `"blockers"` field, around line 64), add:

```json
      "attempted_approaches": [
        {
          "approach": "試みたアプローチの説明",
          "result": "failed | abandoned | partial",
          "reason": "なぜ失敗/断念したか",
          "learnings": "次に活かすべき知見"
        }
      ],
```

**Step 2: Add tried line to handover.md template**

In the handover.md template section (around line 130), update the Remaining section:

```markdown
## Remaining
- [ID] **status** タスク説明
  - files: ファイルパス
  - next: 次のアクション
  （attempted_approaches がある場合）
  - tried: アプローチ説明 → result: 理由 (知見)
  （blocked の場合）
  - blocker: ブロッカー
```

**Step 3: Update merge rules**

In the merge rules section (around line 99), add:

```markdown
   - attempted_approaches: 同一タスク ID のタスクでは追記（重複排除、approach が同じエントリは上書き）
```

**Step 4: Commit**

```bash
git add claude/skills/handover/SKILL.md
git commit -m "docs: document attempted_approaches schema and merge rules in SKILL.md"
```

---

### Task 5: Update valid-v3.json fixture (optional field, keep without it)

**Files:**
- Verify: `claude/skills/handover/scripts/fixtures/valid-v3.json`

**Step 1: Verify valid-v3.json still passes validation without attempted_approaches**

This confirms backward compatibility — the field is optional.

Run: `cd /Users/nishikataseiichi/.dotfiles && shellspec spec/handover_lib_spec.sh --example "succeeds for valid v3 JSON"`
Expected: PASS

**Step 2: Run full test suite**

Run: `cd /Users/nishikataseiichi/.dotfiles && shellspec spec/handover_lib_spec.sh`
Expected: All tests PASS

**Step 3: No commit needed if all passes** (valid-v3.json intentionally omits optional field to test backward compatibility)
