# tmux / sesh Aliases & Claude Code Session Naming — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a worktree-aware tmux session name helper, a Claude Code launcher that prefixes sessions with `cc/`, and a set of short aliases (`s` / `sa` / `sn` / `sk` / `sls` / `ccs` / `ccl` / `cck`) so running many Claude Code sessions is easy to identify in `tmux ls`.

**Architecture:** One pure helper (`bin/tmux-session-name`) derives a name from git worktree state + optional suffix, covered by shellspec in the same style as `bin/hash_port` + `spec/hash_port_spec.sh`. A thin launcher (`bin/cc-session`) uses that helper, prepends `cc/`, and creates-or-attaches a tmux session starting `claude`. Aliases in the existing `aliases` file wire these into short commands. No changes to `config/tmux/tmux.conf` or `config/sesh/sesh.toml`.

**Tech Stack:** bash (scripts) / zsh (aliases, function `sn`) / shellspec (tests) / git worktree / tmux 3.6a / sesh 2.26.0.

**Design spec:** `docs/superpowers/specs/2026-04-24-tmux-sesh-aliases-design.md`

---

## File Structure

| Path | Purpose | Responsibility |
|---|---|---|
| `bin/tmux-session-name` *(new)* | Pure name-deriver | Reads cwd + git state; writes the tmux session name to stdout. No tmux calls. |
| `bin/cc-session` *(new)* | Claude Code session launcher | Calls `tmux-session-name`, prefixes `cc/`, creates-or-attaches session, runs `claude` on first create. |
| `spec/tmux-session-name_spec.sh` *(new)* | Automated tests | Covers the deriver in git / non-git / worktree / detached / suffix / normalization cases. |
| `aliases` *(modify)* | User-facing shortcuts | Adds a `tmux / sesh` section and extends the `claude code` section. |

**Deployment:** `~/.dotfiles/bin` is already symlinked to `~/.bin` (which is on `$PATH` via `zshenv`), so new scripts are picked up immediately after creation + `chmod +x`. `~/.dotfiles/aliases` is symlinked to `~/.aliases` and sourced from `zshrc`; the existing `reload` alias re-sources it. `spec/` is auto-discovered by `.shellspec` (`--default-path spec`). **No `setup.zsh` re-run is required.**

---

## Task 1: Scaffold `bin/tmux-session-name` + first test (happy path)

**Files:**
- Create: `bin/tmux-session-name`
- Create: `spec/tmux-session-name_spec.sh`

- [ ] **Step 1: Write the failing test**

Create `spec/tmux-session-name_spec.sh`:

```bash
Describe "tmux-session-name"
  TMUX_SESSION_NAME="$SHELLSPEC_PROJECT_ROOT/bin/tmux-session-name"

  setup_git_repo() {
    TEST_ROOT=$(mktemp -d)
    mkdir "$TEST_ROOT/myproj"
    cd "$TEST_ROOT/myproj"
    git init -q -b main
    git -c user.name="test" -c user.email="test@test.com" \
      commit --allow-empty -q -m "init"
  }

  cleanup_git_repo() {
    cd "$SHELLSPEC_PROJECT_ROOT"
    rm -rf "$TEST_ROOT"
  }

  Describe "基本動作"
    Before "setup_git_repo"
    After  "cleanup_git_repo"

    run_name() { "$TMUX_SESSION_NAME"; }

    It "<repo>-<branch> 形式で名前を返す"
      When run run_name
      The output should equal "myproj-main"
      The status should be success
    End
  End
End
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd ~/.dotfiles
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: FAIL (script not found / not executable).

- [ ] **Step 3: Create minimal script**

Create `bin/tmux-session-name`:

```bash
#!/usr/bin/env bash
# tmux-session-name — derive a tmux session name from cwd/git state.
# Usage: tmux-session-name [suffix]
set -euo pipefail

common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
repo_root="$(dirname "$common_dir")"
repo="$(basename "$repo_root")"
branch="$(git rev-parse --abbrev-ref HEAD)"
printf '%s\n' "${repo}-${branch}"
```

- [ ] **Step 4: Make it executable**

```bash
chmod +x ~/.dotfiles/bin/tmux-session-name
```

- [ ] **Step 5: Run test to verify it passes**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: PASS — `1 example, 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add bin/tmux-session-name spec/tmux-session-name_spec.sh
git commit -m "feat(tmux-session-name): scaffold deriver with happy-path spec"
```

---

## Task 2: Suffix argument support

**Files:**
- Modify: `bin/tmux-session-name`
- Modify: `spec/tmux-session-name_spec.sh`

- [ ] **Step 1: Add the failing test**

Append inside the `Describe "基本動作"` block (same `Before`/`After` hooks apply), after the existing `It`:

```bash
    It "suffix 引数が末尾に付く"
      run_with_suffix() { "$TMUX_SESSION_NAME" review; }
      When run run_with_suffix
      The output should equal "myproj-main-review"
      The status should be success
    End
```

- [ ] **Step 2: Run test to verify it fails**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: FAIL on the new assertion (output `myproj-main`, expected `myproj-main-review`).

- [ ] **Step 3: Extend the script**

Replace the body of `bin/tmux-session-name` with:

```bash
#!/usr/bin/env bash
# tmux-session-name — derive a tmux session name from cwd/git state.
# Usage: tmux-session-name [suffix]
set -euo pipefail

suffix="${1:-}"

common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
repo_root="$(dirname "$common_dir")"
repo="$(basename "$repo_root")"
branch="$(git rev-parse --abbrev-ref HEAD)"
name="${repo}-${branch}"

if [[ -n "$suffix" ]]; then
  name="${name}-${suffix}"
fi

printf '%s\n' "$name"
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: PASS — `2 examples, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add bin/tmux-session-name spec/tmux-session-name_spec.sh
git commit -m "feat(tmux-session-name): support suffix argument"
```

---

## Task 3: Branch separator normalization (`feature/foo` → `feature-foo`)

**Files:**
- Modify: `bin/tmux-session-name`
- Modify: `spec/tmux-session-name_spec.sh`

- [ ] **Step 1: Add the failing test**

Append inside `Describe "基本動作"`:

```bash
    It "ブランチ名のスラッシュをハイフンに置換する"
      run_slash_branch() {
        git checkout -q -b "feature/foo"
        "$TMUX_SESSION_NAME"
      }
      When run run_slash_branch
      The output should equal "myproj-feature-foo"
      The status should be success
    End
```

- [ ] **Step 2: Run test to verify it fails**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: FAIL — actual output `myproj-feature/foo`.

- [ ] **Step 3: Add normalization to the script**

Append to `bin/tmux-session-name` just before the final `printf`:

```bash
# Normalize separators: / . : space tab → -
name="$(printf '%s' "$name" | tr '/.: \t' '-')"
# Collapse consecutive dashes, trim edges
name="$(printf '%s' "$name" | tr -s '-')"
name="${name#-}"
name="${name%-}"
```

Full file now:

```bash
#!/usr/bin/env bash
# tmux-session-name — derive a tmux session name from cwd/git state.
# Usage: tmux-session-name [suffix]
set -euo pipefail

suffix="${1:-}"

common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
repo_root="$(dirname "$common_dir")"
repo="$(basename "$repo_root")"
branch="$(git rev-parse --abbrev-ref HEAD)"
name="${repo}-${branch}"

if [[ -n "$suffix" ]]; then
  name="${name}-${suffix}"
fi

# Normalize separators: / . : space tab → -
name="$(printf '%s' "$name" | tr '/.: \t' '-')"
# Collapse consecutive dashes, trim edges
name="$(printf '%s' "$name" | tr -s '-')"
name="${name#-}"
name="${name%-}"

printf '%s\n' "$name"
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: PASS — `3 examples, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add bin/tmux-session-name spec/tmux-session-name_spec.sh
git commit -m "feat(tmux-session-name): normalize branch separators"
```

---

## Task 4: Non-git fallback

**Files:**
- Modify: `bin/tmux-session-name`
- Modify: `spec/tmux-session-name_spec.sh`

- [ ] **Step 1: Add the failing test**

Append a new `Describe` block at the same level as `Describe "基本動作"`:

```bash
  Describe "git 外ディレクトリ"
    setup_non_git() {
      TEST_ROOT=$(mktemp -d)
      mkdir "$TEST_ROOT/scratch"
      cd "$TEST_ROOT/scratch"
    }
    cleanup_non_git() {
      cd "$SHELLSPEC_PROJECT_ROOT"
      rm -rf "$TEST_ROOT"
    }
    Before "setup_non_git"
    After  "cleanup_non_git"

    run_name() { "$TMUX_SESSION_NAME"; }

    It "git 外では basename(PWD) を返す"
      When run run_name
      The output should equal "scratch"
      The status should be success
    End
  End
```

- [ ] **Step 2: Run test to verify it fails**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: FAIL — `git rev-parse` errors and script exits non-zero.

- [ ] **Step 3: Add git-detection branch**

Update the core of `bin/tmux-session-name` so the git block is conditional:

```bash
#!/usr/bin/env bash
# tmux-session-name — derive a tmux session name from cwd/git state.
# Usage: tmux-session-name [suffix]
set -euo pipefail

suffix="${1:-}"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
  repo_root="$(dirname "$common_dir")"
  repo="$(basename "$repo_root")"
  branch="$(git rev-parse --abbrev-ref HEAD)"
  name="${repo}-${branch}"
else
  name="$(basename "$PWD")"
fi

if [[ -n "$suffix" ]]; then
  name="${name}-${suffix}"
fi

# Normalize separators: / . : space tab → -
name="$(printf '%s' "$name" | tr '/.: \t' '-')"
# Collapse consecutive dashes, trim edges
name="$(printf '%s' "$name" | tr -s '-')"
name="${name#-}"
name="${name%-}"

printf '%s\n' "$name"
```

- [ ] **Step 4: Run tests to verify all pass**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: PASS — `4 examples, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add bin/tmux-session-name spec/tmux-session-name_spec.sh
git commit -m "feat(tmux-session-name): fall back to basename outside git"
```

---

## Task 5: Strip leading dot (`.dotfiles` → `dotfiles`)

**Files:**
- Modify: `bin/tmux-session-name`
- Modify: `spec/tmux-session-name_spec.sh`

- [ ] **Step 1: Add failing tests (both git and non-git cases)**

Append a new `Describe` block:

```bash
  Describe "先頭ドット除去"
    setup_dotted_git_repo() {
      TEST_ROOT=$(mktemp -d)
      mkdir "$TEST_ROOT/.dotproj"
      cd "$TEST_ROOT/.dotproj"
      git init -q -b main
      git -c user.name="test" -c user.email="test@test.com" \
        commit --allow-empty -q -m "init"
    }
    cleanup_dotted_git_repo() {
      cd "$SHELLSPEC_PROJECT_ROOT"
      rm -rf "$TEST_ROOT"
    }

    Context "git repo の basename が . で始まる"
      Before "setup_dotted_git_repo"
      After  "cleanup_dotted_git_repo"
      run_name() { "$TMUX_SESSION_NAME"; }
      It "先頭ドットを剥がす"
        When run run_name
        The output should equal "dotproj-main"
        The status should be success
      End
    End

    setup_dotted_non_git() {
      TEST_ROOT=$(mktemp -d)
      mkdir "$TEST_ROOT/.hidden"
      cd "$TEST_ROOT/.hidden"
    }
    cleanup_dotted_non_git() {
      cd "$SHELLSPEC_PROJECT_ROOT"
      rm -rf "$TEST_ROOT"
    }

    Context "git 外かつ basename が . で始まる"
      Before "setup_dotted_non_git"
      After  "cleanup_dotted_non_git"
      run_name() { "$TMUX_SESSION_NAME"; }
      It "先頭ドットを剥がす"
        When run run_name
        The output should equal "hidden"
        The status should be success
      End
    End
  End
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: FAIL — outputs have leading `.` (and/or `-` after normalization turned the dot into a dash).

- [ ] **Step 3: Strip leading dot in the script**

Apply the strip at the point each `name` component is formed. Update both branches in `bin/tmux-session-name`:

```bash
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
  repo_root="$(dirname "$common_dir")"
  repo="$(basename "$repo_root")"
  repo="${repo#.}"
  branch="$(git rev-parse --abbrev-ref HEAD)"
  name="${repo}-${branch}"
else
  base="$(basename "$PWD")"
  name="${base#.}"
fi
```

Full script after this step:

```bash
#!/usr/bin/env bash
# tmux-session-name — derive a tmux session name from cwd/git state.
# Usage: tmux-session-name [suffix]
set -euo pipefail

suffix="${1:-}"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
  repo_root="$(dirname "$common_dir")"
  repo="$(basename "$repo_root")"
  repo="${repo#.}"
  branch="$(git rev-parse --abbrev-ref HEAD)"
  name="${repo}-${branch}"
else
  base="$(basename "$PWD")"
  name="${base#.}"
fi

if [[ -n "$suffix" ]]; then
  name="${name}-${suffix}"
fi

# Normalize separators: / . : space tab → -
name="$(printf '%s' "$name" | tr '/.: \t' '-')"
# Collapse consecutive dashes, trim edges
name="$(printf '%s' "$name" | tr -s '-')"
name="${name#-}"
name="${name%-}"

printf '%s\n' "$name"
```

- [ ] **Step 4: Run tests to verify all pass**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: PASS — `6 examples, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add bin/tmux-session-name spec/tmux-session-name_spec.sh
git commit -m "feat(tmux-session-name): strip leading dot from basename"
```

---

## Task 6: Detached HEAD fallback

**Files:**
- Modify: `bin/tmux-session-name`
- Modify: `spec/tmux-session-name_spec.sh`

- [ ] **Step 1: Add the failing test**

Append a new `Describe` block:

```bash
  Describe "detached HEAD"
    setup_detached() {
      TEST_ROOT=$(mktemp -d)
      mkdir "$TEST_ROOT/myproj"
      cd "$TEST_ROOT/myproj"
      git init -q -b main
      git -c user.name="test" -c user.email="test@test.com" \
        commit --allow-empty -q -m "init"
      git checkout -q --detach
    }
    cleanup_detached() {
      cd "$SHELLSPEC_PROJECT_ROOT"
      rm -rf "$TEST_ROOT"
    }
    Before "setup_detached"
    After  "cleanup_detached"

    run_name() { "$TMUX_SESSION_NAME"; }

    It "<repo>-HEAD-<短SHA7> を返す"
      When run run_name
      The output should match pattern "myproj-HEAD-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"
      The status should be success
    End
  End
```

- [ ] **Step 2: Run test to verify it fails**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: FAIL — `git rev-parse --abbrev-ref HEAD` returns `HEAD`, producing `myproj-HEAD` (no SHA suffix).

- [ ] **Step 3: Use `git symbolic-ref` + short SHA fallback**

Replace the git branch block in `bin/tmux-session-name` so it handles detached HEAD:

```bash
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
  repo_root="$(dirname "$common_dir")"
  repo="$(basename "$repo_root")"
  repo="${repo#.}"
  if branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
    :
  else
    branch="HEAD-$(git rev-parse --short=7 HEAD)"
  fi
  name="${repo}-${branch}"
else
  base="$(basename "$PWD")"
  name="${base#.}"
fi
```

- [ ] **Step 4: Run tests to verify all pass**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: PASS — `7 examples, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add bin/tmux-session-name spec/tmux-session-name_spec.sh
git commit -m "feat(tmux-session-name): handle detached HEAD with short SHA"
```

---

## Task 7: Worktree consistency (same repo name as main)

**Files:**
- Modify: `spec/tmux-session-name_spec.sh` *(no script change expected)*

This task verifies that `--path-format=absolute --git-common-dir` already makes worktree + main return the same `repo`. If the test passes unchanged, no code edit is needed.

- [ ] **Step 1: Add the failing test**

Append a new `Describe` block:

```bash
  Describe "git worktree"
    setup_worktree() {
      TEST_ROOT=$(mktemp -d)
      mkdir "$TEST_ROOT/myproj"
      cd "$TEST_ROOT/myproj"
      git init -q -b main
      git -c user.name="test" -c user.email="test@test.com" \
        commit --allow-empty -q -m "init"
      git worktree add -q -b feat "$TEST_ROOT/myproj-wt"
      cd "$TEST_ROOT/myproj-wt"
    }
    cleanup_worktree() {
      cd "$SHELLSPEC_PROJECT_ROOT"
      rm -rf "$TEST_ROOT"
    }
    Before "setup_worktree"
    After  "cleanup_worktree"

    run_name() { "$TMUX_SESSION_NAME"; }

    It "worktree の basename ではなく main repo 名を使う"
      When run run_name
      The output should equal "myproj-feat"
      The status should be success
    End
  End
```

- [ ] **Step 2: Run tests**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: PASS — `8 examples, 0 failures` (the existing `--git-common-dir` logic already yields `myproj`, not `myproj-wt`).

**If this test unexpectedly fails**, investigate with `git -C "$TEST_ROOT/myproj-wt" rev-parse --path-format=absolute --git-common-dir` and adjust the script; the expected behavior is that the common-dir points into the main repo, so `dirname` → main repo root.

- [ ] **Step 3: Commit**

```bash
git add spec/tmux-session-name_spec.sh
git commit -m "test(tmux-session-name): verify worktree returns main repo name"
```

---

## Task 8: Character normalization + empty fallback

**Files:**
- Modify: `bin/tmux-session-name`
- Modify: `spec/tmux-session-name_spec.sh`

- [ ] **Step 1: Add failing tests**

Append a new `Describe` block:

```bash
  Describe "名前の正規化"
    setup_spacey_dir() {
      TEST_ROOT=$(mktemp -d)
      mkdir "$TEST_ROOT/has space:and.dots"
      cd "$TEST_ROOT/has space:and.dots"
    }
    cleanup_spacey_dir() {
      cd "$SHELLSPEC_PROJECT_ROOT"
      rm -rf "$TEST_ROOT"
    }

    Context "cwd に空白・コロン・ドットが含まれる"
      Before "setup_spacey_dir"
      After  "cleanup_spacey_dir"
      run_name() { "$TMUX_SESSION_NAME"; }
      It "全てハイフンに正規化され、連続ハイフンは圧縮される"
        When run run_name
        The output should equal "has-space-and-dots"
        The status should be success
      End
    End

    setup_root_dir() {
      ORIG_PWD="$PWD"
      cd /
    }
    cleanup_root_dir() {
      cd "$ORIG_PWD"
    }

    Context "cwd が / (basename が空)"
      Before "setup_root_dir"
      After  "cleanup_root_dir"
      run_name() { "$TMUX_SESSION_NAME"; }
      It "root にフォールバックする"
        When run run_name
        The output should equal "root"
        The status should be success
      End
    End
  End
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: FAIL on "root にフォールバック" (output is empty). The normalization case should already pass via existing `tr`/`tr -s` logic — if so, that one is a regression guard.

- [ ] **Step 3: Add the empty fallback**

Append to `bin/tmux-session-name` just before the final `printf`:

```bash
if [[ -z "$name" ]]; then
  name="root"
fi
```

Full script after this task:

```bash
#!/usr/bin/env bash
# tmux-session-name — derive a tmux session name from cwd/git state.
# Usage: tmux-session-name [suffix]
set -euo pipefail

suffix="${1:-}"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
  repo_root="$(dirname "$common_dir")"
  repo="$(basename "$repo_root")"
  repo="${repo#.}"
  if branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
    :
  else
    branch="HEAD-$(git rev-parse --short=7 HEAD)"
  fi
  name="${repo}-${branch}"
else
  base="$(basename "$PWD")"
  name="${base#.}"
fi

if [[ -n "$suffix" ]]; then
  name="${name}-${suffix}"
fi

# Normalize separators: / . : space tab → -
name="$(printf '%s' "$name" | tr '/.: \t' '-')"
# Collapse consecutive dashes, trim edges
name="$(printf '%s' "$name" | tr -s '-')"
name="${name#-}"
name="${name%-}"

if [[ -z "$name" ]]; then
  name="root"
fi

printf '%s\n' "$name"
```

- [ ] **Step 4: Run tests to verify all pass**

```bash
shellspec --shell bash spec/tmux-session-name_spec.sh
```

Expected: PASS — `10 examples, 0 failures`.

- [ ] **Step 5: Run the full CI-equivalent suite**

```bash
shellspec --shell bash
```

Expected: PASS — all specs including `hash_port_spec.sh` green.

- [ ] **Step 6: Commit**

```bash
git add bin/tmux-session-name spec/tmux-session-name_spec.sh
git commit -m "feat(tmux-session-name): normalize characters and fallback to root"
```

---

## Task 9: `bin/cc-session` launcher

**Files:**
- Create: `bin/cc-session`

`cc-session` talks to the tmux server, so unit-testing via shellspec is not worth the stubbing cost. It is verified via the integration smoke in Task 12.

- [ ] **Step 1: Create the launcher script**

Create `bin/cc-session`:

```bash
#!/usr/bin/env bash
# cc-session — launch or attach a Claude Code tmux session under `cc/<name>`.
# Usage: cc-session [suffix]
set -euo pipefail

suffix="${1:-}"
script_dir="$(cd "$(dirname "$0")" && pwd)"

if [[ -n "$suffix" ]]; then
  base="$("$script_dir/tmux-session-name" "$suffix")"
else
  base="$("$script_dir/tmux-session-name")"
fi

name="cc/${base}"

if ! tmux has-session -t "$name" 2>/dev/null; then
  tmux new-session -d -s "$name" -c "$PWD"
  tmux send-keys -t "$name" 'claude' C-m
fi

if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "$name"
else
  tmux attach -t "$name"
fi
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x ~/.dotfiles/bin/cc-session
```

- [ ] **Step 3: Sanity-check it can locate the helper**

Outside of any tmux session, call just the name-derivation path by piggy-backing on `tmux-session-name` itself (cc-session is validated in the Task 12 smoke):

```bash
~/.dotfiles/bin/tmux-session-name
```

Expected: outputs `dotfiles-master` (or whatever branch you're on), exit 0. This confirms the PATH / symlink wiring is fine and cc-session will also resolve.

- [ ] **Step 4: Commit**

```bash
git add bin/cc-session
git commit -m "feat(cc-session): add Claude Code tmux launcher with cc/ prefix"
```

---

## Task 10: Add `tmux / sesh` alias section

**Files:**
- Modify: `aliases`

- [ ] **Step 1: Read the current aliases file location**

```bash
grep -n "# claude code" ~/.dotfiles/aliases
```

Expected: one line showing where the `# claude code` section starts (around line 85 in the current file). The new section goes immediately before it.

- [ ] **Step 2: Insert the new section**

Edit `aliases`: insert the following block immediately **before** the `# claude code` section header:

```zsh
# ------------------------------
# tmux / sesh
# ------------------------------
alias s='sesh connect "$(sesh list -tzc | fzf)"'
alias sa='sesh connect --last'
alias sk='tmux ls 2>/dev/null | fzf --multi | cut -d: -f1 | xargs -r -n1 tmux kill-session -t'
alias sls='tmux ls'

sn() {
  local name
  name="$(tmux-session-name "${1:-}")" || return 1
  if ! tmux has-session -t "$name" 2>/dev/null; then
    tmux new-session -d -s "$name" -c "$PWD"
  fi
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$name"
  else
    tmux attach -t "$name"
  fi
}

```

- [ ] **Step 3: Verify the file still parses**

```bash
zsh -n ~/.dotfiles/aliases
```

Expected: no output, exit 0 (syntax check only).

- [ ] **Step 4: Source it in the current shell and verify aliases exist**

```bash
source ~/.aliases
type s sa sk sls sn
```

Expected: each prints its definition (alias for `s`/`sa`/`sk`/`sls`, function body for `sn`).

- [ ] **Step 5: Commit**

```bash
git add aliases
git commit -m "feat(aliases): add tmux/sesh shortcuts (s/sa/sn/sk/sls)"
```

---

## Task 11: Extend `claude code` alias section

**Files:**
- Modify: `aliases`

- [ ] **Step 1: Locate the current section**

The current block reads:

```zsh
# ------------------------------
# claude code
# ------------------------------
alias claude='claude --effort max --enable-auto-mode'
```

- [ ] **Step 2: Append the three new aliases**

Edit `aliases` so the section becomes:

```zsh
# ------------------------------
# claude code
# ------------------------------
alias claude='claude --effort max --enable-auto-mode'
alias ccs='cc-session'
alias ccl='tmux ls 2>/dev/null | grep "^cc/" || true'
alias cck='tmux ls 2>/dev/null | grep "^cc/" | fzf --multi | cut -d: -f1 | xargs -r -n1 tmux kill-session -t'
```

- [ ] **Step 3: Verify and source**

```bash
zsh -n ~/.dotfiles/aliases
source ~/.aliases
type ccs ccl cck
```

Expected: syntax check clean; each alias prints its definition.

- [ ] **Step 4: Commit**

```bash
git add aliases
git commit -m "feat(aliases): add Claude Code session shortcuts (ccs/ccl/cck)"
```

---

## Task 12: Integration smoke test (manual)

**Files:** *(none — verification only)*

Run each scenario in a live terminal. Mark the checkbox only when the observed result matches Expected. Do **not** proceed to "Commit" until all scenarios pass.

**Preconditions:** fresh shell session, `source ~/.aliases` applied, no pre-existing `dotfiles-*` / `cc/dotfiles-*` tmux sessions.

```bash
# Clean slate (if needed — make sure you are OK losing these sessions first)
tmux ls 2>/dev/null | grep -E '^(cc/)?dotfiles-' || echo "no stale sessions"
```

- [ ] **Step 1: `sn` from `~/.dotfiles` master**

```bash
cd ~/.dotfiles
sn
```

Expected: attached into a tmux session named `dotfiles-master`. `tmux display-message -p '#S'` inside the pane prints `dotfiles-master`.

- [ ] **Step 2: `sn` again — idempotent**

Inside the same pane (or detach and re-run `sn` from `~/.dotfiles`).

Expected: same session, no new session created. `tmux ls` shows exactly one `dotfiles-master`.

- [ ] **Step 3: `ccs` starts Claude Code session**

Detach (`C-Space d`), then:

```bash
ccs
```

Expected: new session `cc/dotfiles-master`; pane begins running `claude` (you see the Claude Code banner).

- [ ] **Step 4: `ccs` again — does not double-start claude**

Detach, then re-run `ccs`.

Expected: re-attached to existing `cc/dotfiles-master`, no second `claude` process starts. `pgrep -c claude` matches what it was before.

- [ ] **Step 5: `ccs review` creates suffixed variant**

Detach, then:

```bash
ccs review
```

Expected: new session `cc/dotfiles-master-review` (separate from `cc/dotfiles-master`).

- [ ] **Step 6: `sls` and `ccl` differentiate**

Detach.

```bash
sls
ccl
```

Expected: `sls` shows both `dotfiles-master` and the two `cc/*` sessions. `ccl` shows only the two `cc/*` sessions.

- [ ] **Step 7: `sk` kills selected sessions**

```bash
sk
# fzf opens — select with Tab, confirm with Enter
```

Expected: selected sessions disappear from `tmux ls`.

- [ ] **Step 8: Non-git directory**

```bash
cd ~/Downloads   # or any non-git dir
sn
```

Expected: session named `Downloads` (or the basename with leading dot stripped). Detach and clean up with `sk` when done.

- [ ] **Step 9: Worktree branch with slash**

```bash
cd ~/.dotfiles
wt switch --create feature/demo
ccs
```

Expected: session `cc/dotfiles-feature-demo` (slash normalized to dash). Detach and `cd ~/.dotfiles`, `wt remove` the worktree when done.

- [ ] **Step 10: `sesh` not-found graceful failure**

Run in a subshell that hides `sesh` from `$PATH` by placing an empty directory in front:

```bash
EMPTY_DIR="$(mktemp -d)"
env -i HOME="$HOME" PATH="$EMPTY_DIR:/usr/bin:/bin" zsh -c '
  source ~/.aliases
  s
'
rmdir "$EMPTY_DIR"
```

Expected: the `s` alias executes `sesh connect ...`, zsh prints `command not found: sesh` (or similar), and exits non-zero. The outer shell stays alive; nothing destructive happens.

- [ ] **Step 11: Final verification and cleanup commit**

Run the automated suite one more time:

```bash
cd ~/.dotfiles
shellspec --shell bash
```

Expected: all specs PASS.

Commit any lingering cleanup (should be nothing — if there is, reconsider whether a step was missed):

```bash
git status
```

Expected: clean working tree.

---

## Self-Review Coverage Check

Mapping plan tasks ↔ spec sections:

| Spec section | Covered by |
|---|---|
| § 3.1 Hybrid approach (cc/ prefix, sesh-first) | Tasks 9, 10, 11 |
| § 3.2 File layout | Tasks 1 (scaffold), 9 (cc-session), 10/11 (aliases), 12 (no tmux.conf/sesh.toml change verified) |
| § 4.1 naming logic — repo detection | Tasks 1, 7 |
| § 4.1 — branch normalization | Task 3 |
| § 4.1 — suffix | Task 2 |
| § 4.1 — leading dot | Task 5 |
| § 4.1 — char normalization | Task 8 |
| § 4.1 — empty → root | Task 8 |
| § 4.2 example table | Verified across Tasks 1/2/3/5/6/7 automated + Task 12 manual |
| § 4.3 edge cases (non-git, detached, worktree) | Tasks 4, 6, 7 |
| § 5.1 / 5.2 alias surface | Tasks 10, 11 |
| § 5.3 cc-session pseudocode | Task 9 |
| § 6.1 automated tests | Tasks 1–8 |
| § 6.2 manual smoke 1–10 | Task 12 |

No gaps identified.
