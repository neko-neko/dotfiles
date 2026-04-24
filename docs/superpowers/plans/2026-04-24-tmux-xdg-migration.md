# tmux XDG Migration + Modern Session UX — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `~/.tmux.conf` into dotfiles under `config/tmux/tmux.conf`, switch to XDG Base Directory layout, and introduce `sesh` + `tmux-sessionx` for fuzzy session picking along with 10 tmux experience improvements from the approved spec.

**Architecture:** dotfiles `config/*` directory is auto-symlinked to `~/.config/*` by the existing `setup/setup.zsh`. Drop a new `config/tmux/` and `config/sesh/` into it — no setup.zsh changes. tmux 3.6+ auto-discovers `$XDG_CONFIG_HOME/tmux/tmux.conf`. tpm is relocated to `$XDG_DATA_HOME/tmux/plugins` via `TMUX_PLUGIN_MANAGER_PATH`, bootstrapped on first launch.

**Tech Stack:** tmux 3.6a, tpm, sesh, zoxide, fzf (already installed), Homebrew, zsh.

**Spec:** [`docs/superpowers/specs/2026-04-24-tmux-xdg-migration-design.md`](../specs/2026-04-24-tmux-xdg-migration-design.md)

---

## File Structure

Files created / modified by this plan:

| Path | Action | Responsibility |
|---|---|---|
| `config/tmux/tmux.conf` | Create | Main tmux config (XDG paths, core options, keybindings, plugin declarations, plugin-specific configs, TPM bootstrap + run) |
| `config/sesh/sesh.toml` | Create | sesh session manager config (default session + fixed `dotfiles` session; zoxide candidates are auto-merged by sesh) |
| `Brewfile` | Modify (insert at L71-74 area) | Add `sesh` and `zoxide` into the alphabetical cluster with `fzf`, `sheldon`, `starship`, `tmux` |
| `zshrc` | Modify (append new section before Custom local files) | `eval "$(zoxide init zsh)"` so `z` / `zi` work in shell and sesh's zoxide integration lights up |
| `~/.tmux.conf` | Delete (user filesystem, not dotfiles) | Obsolete — removed during deployment |
| `~/.tmux/` | Delete (user filesystem) | Obsolete TPM directory — removed, replaced by `$XDG_DATA_HOME/tmux/plugins/` |

No changes to `setup/setup.zsh` — the existing `config/` for-loop handles `tmux/` and `sesh/` subdirs automatically.

---

## Task 1: Create `config/tmux/tmux.conf`

**Files:**
- Create: `config/tmux/tmux.conf`

- [ ] **Step 1.1: Create the tmux config directory**

```bash
mkdir -p /Users/nishikataseiichi/.dotfiles/config/tmux
```

- [ ] **Step 1.2: Write `config/tmux/tmux.conf` with the full contents below**

Write the following exact content to `/Users/nishikataseiichi/.dotfiles/config/tmux/tmux.conf`:

```tmux
# =============================================================================
# tmux configuration (XDG Base Directory compliant)
# Managed under ~/.dotfiles/config/tmux/tmux.conf
# Symlinked by setup/setup.zsh to $XDG_CONFIG_HOME/tmux/tmux.conf
# =============================================================================

# ── Plugin manager path (must be set before any @plugin declarations) ────────
# Fall back to $HOME/.local/share if XDG_DATA_HOME is unset.
if-shell '[ -z "$XDG_DATA_HOME" ]' 'setenv -g XDG_DATA_HOME "$HOME/.local/share"'
set-environment -g TMUX_PLUGIN_MANAGER_PATH "$XDG_DATA_HOME/tmux/plugins"

# ── TPM bootstrap: auto-clone on first run ───────────────────────────────────
if-shell '[ ! -d "$XDG_DATA_HOME/tmux/plugins/tpm" ]' \
    "run 'git clone https://github.com/tmux-plugins/tpm \"$XDG_DATA_HOME/tmux/plugins/tpm\" && \"$XDG_DATA_HOME/tmux/plugins/tpm/bin/install_plugins\"'"

# ── Core options ─────────────────────────────────────────────────────────────
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*:RGB"
set -g mouse on
set -g history-limit 100000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -s escape-time 0
set -g focus-events on
setw -g aggressive-resize on
setw -g mode-keys vi

# ── Prefix: C-b → C-Space ────────────────────────────────────────────────────
unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

# ── Split / new-window keybindings (inherit current path) ────────────────────
unbind '"'
unbind %
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"

# ── Reload config ────────────────────────────────────────────────────────────
bind r source-file "$XDG_CONFIG_HOME/tmux/tmux.conf" \; display-message "tmux.conf reloaded"

# ── Copy-mode: vi-style + macOS pbcopy integration ───────────────────────────
bind -T copy-mode-vi v send-keys -X begin-selection
if-shell 'uname | grep -q Darwin' \
    "bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'pbcopy'"
if-shell 'uname | grep -q Darwin' \
    "bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel 'pbcopy'"

# ── tmux-fzf launch key (uses env var; sessionx handles prefix+o) ────────────
set-environment -g TMUX_FZF_LAUNCH_KEY "F"

# ── Plugin declarations ──────────────────────────────────────────────────────
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'sainnhe/tmux-fzf'
set -g @plugin 'omerxx/tmux-sessionx'
set -g @plugin 'fcsonline/tmux-thumbs'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'catppuccin/tmux#v2.3.0'

# ── Plugin: tmux-sessionx (prefix + o opens popup) ───────────────────────────
set -g @sessionx-bind 'o'
set -g @sessionx-preview-enabled 'true'
set -g @sessionx-zoxide-mode 'on'
set -g @sessionx-custom-paths "$HOME/.dotfiles"
set -g @sessionx-fallback-enabled 'true'
set -g @sessionx-window-height '85%'
set -g @sessionx-window-width '75%'

# ── Plugin: tmux-thumbs (prefix + t) ─────────────────────────────────────────
set -g @thumbs-key t
set -g @thumbs-command 'echo -n {} | pbcopy'

# ── Plugin: tmux-continuum + tmux-resurrect ──────────────────────────────────
set -g @continuum-restore 'on'
set -g @resurrect-capture-pane-contents 'on'

# ── Plugin: catppuccin (v2 API, mocha flavor) ────────────────────────────────
set -g @catppuccin_flavor 'mocha'
set -g @catppuccin_window_status_style 'rounded'

# ── Run TPM (keep at the very bottom) ────────────────────────────────────────
run "$XDG_DATA_HOME/tmux/plugins/tpm/tpm"
```

- [ ] **Step 1.3: Run tmux syntax check (no plugins loaded yet, so TPM-related errors are expected warnings — focus on parse errors)**

Run:
```bash
tmux -f /Users/nishikataseiichi/.dotfiles/config/tmux/tmux.conf -L dotfiles-syntax-check new-session -d 'true' 2>&1 | tee /tmp/tmux-syntax.log
tmux -L dotfiles-syntax-check kill-server 2>/dev/null || true
```

Expected: The session starts and exits cleanly. Output may contain a line about TPM auto-clone; that's normal. If you see `/unknown command/` or `/syntax error/`, fix the line indicated and re-run.

- [ ] **Step 1.4: Commit**

```bash
cd /Users/nishikataseiichi/.dotfiles
git add config/tmux/tmux.conf
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(tmux): add XDG-compliant tmux.conf with sesh/sessionx integration

Introduces config/tmux/tmux.conf under dotfiles. Includes 10 experience
improvements (prefix C-Space, split |/-, base-index 1, vi-mode pbcopy,
true color, focus-events, renumber-windows, escape-time 0, reload key,
current-path splits), plus plugin declarations for tmux-sessionx,
tmux-thumbs, and vim-tmux-navigator in addition to the existing set.
EOF
)"
```

---

## Task 2: Create `config/sesh/sesh.toml`

**Files:**
- Create: `config/sesh/sesh.toml`

- [ ] **Step 2.1: Create the sesh config directory**

```bash
mkdir -p /Users/nishikataseiichi/.dotfiles/config/sesh
```

- [ ] **Step 2.2: Write `config/sesh/sesh.toml` with the following content**

Write to `/Users/nishikataseiichi/.dotfiles/config/sesh/sesh.toml`:

```toml
# sesh — smart tmux session manager
# Docs: https://github.com/joshmedeski/sesh

[default_session]
startup_command = ""

# ─── Fixed sessions ──────────────────────────────────────────────────────────
# zoxide directories and live tmux sessions are auto-merged into `sesh list`.
# Add more entries here as needed.

[[session]]
name = "dotfiles"
path = "~/.dotfiles"
startup_command = "hx ."
```

- [ ] **Step 2.3: Commit**

```bash
cd /Users/nishikataseiichi/.dotfiles
git add config/sesh/sesh.toml
git -c commit.gpgsign=false commit -m "feat(sesh): add sesh.toml with dotfiles fixed session"
```

---

## Task 3: Add `sesh` and `zoxide` to `Brewfile`

**Files:**
- Modify: `Brewfile` (insert near lines 71-74 where fzf/sheldon/starship/tmux live)

- [ ] **Step 3.1: Inspect the current cluster**

Run:
```bash
sed -n '69,76p' /Users/nishikataseiichi/.dotfiles/Brewfile
```

Expected output around:
```
...
brew 'fzf'
brew 'sheldon'
brew 'starship'
brew 'tmux'
...
```

- [ ] **Step 3.2: Insert `sesh` and `zoxide` alphabetically**

The cluster is alphabetical (f → sh → st → t). Insert:
- `brew 'sesh'` between `brew 'fzf'` and `brew 'sheldon'`
- `brew 'zoxide'` after `brew 'tmux'` (z sorts after t)

Use the Edit tool with:
- `old_string`:
```
brew 'fzf'
brew 'sheldon'
brew 'starship'
brew 'tmux'
```
- `new_string`:
```
brew 'fzf'
brew 'sesh'
brew 'sheldon'
brew 'starship'
brew 'tmux'
brew 'zoxide'
```

- [ ] **Step 3.3: Verify the diff**

Run:
```bash
cd /Users/nishikataseiichi/.dotfiles && git diff Brewfile
```

Expected: Only `+brew 'sesh'` and `+brew 'zoxide'` added; no other changes.

- [ ] **Step 3.4: Commit**

```bash
cd /Users/nishikataseiichi/.dotfiles
git add Brewfile
git -c commit.gpgsign=false commit -m "chore(brewfile): add sesh and zoxide for modern tmux session UX"
```

---

## Task 4: Add `zoxide init` to `zshrc`

**Files:**
- Modify: `zshrc` (insert a new section between "fzf Settings" (ends L100) and "Key bindings" (L102))

- [ ] **Step 4.1: Inspect the insertion point**

Run:
```bash
sed -n '95,110p' /Users/nishikataseiichi/.dotfiles/zshrc
```

Expected: the `fzf Settings` block ends at line ~100, followed by `Key bindings` at ~102.

- [ ] **Step 4.2: Insert the zoxide section**

Use the Edit tool with:
- `old_string`:
```
# ------------------------------
# fzf Settings
# ------------------------------
eval "$(fzf --zsh)"
autoload fzf-history
zle -N fzf-history

# ------------------------------
# Key bindings
# ------------------------------
```
- `new_string`:
```
# ------------------------------
# fzf Settings
# ------------------------------
eval "$(fzf --zsh)"
autoload fzf-history
zle -N fzf-history

# ------------------------------
# zoxide Settings
# ------------------------------
if type zoxide > /dev/null; then
  eval "$(zoxide init zsh)"
fi

# ------------------------------
# Key bindings
# ------------------------------
```

The `if type zoxide` guard prevents shell startup failures if zoxide has not been installed yet on a fresh machine.

- [ ] **Step 4.3: Verify the diff**

Run:
```bash
cd /Users/nishikataseiichi/.dotfiles && git diff zshrc
```

Expected: only the new `zoxide Settings` block is added (6 lines of content + section header).

- [ ] **Step 4.4: Commit**

```bash
cd /Users/nishikataseiichi/.dotfiles
git add zshrc
git -c commit.gpgsign=false commit -m "feat(zsh): init zoxide for directory jumps and sesh integration"
```

---

## Task 5: Install `sesh` and `zoxide`

**Files:** (no file changes; system-state changes only)

- [ ] **Step 5.1: Run brew bundle**

Run:
```bash
brew bundle --file=/Users/nishikataseiichi/.dotfiles/Brewfile
```

Expected: `sesh` and `zoxide` are installed; other formulae report "Using ..." (already installed).

- [ ] **Step 5.2: Verify binaries**

Run:
```bash
sesh --version && zoxide --version
```

Expected: Both commands print a version string and exit 0.

---

## Task 6: Remove obsolete tmux files and deploy dotfiles

**Files:** (filesystem-level deletions + symlink creation)

- [ ] **Step 6.1: Kill any running tmux server (so new config takes effect on next launch)**

Run:
```bash
tmux list-sessions 2>/dev/null && echo "tmux is running — detach/exit any sessions first, then run: tmux kill-server" || echo "no tmux server running"
```

If a server is running and you are currently inside a tmux pane (e.g., Claude Code session), exit any tmux sessions first, then:
```bash
tmux kill-server
```

If the above step was deferred because you are currently in tmux, the new config will still apply after your next `tmux` launch following server restart.

- [ ] **Step 6.2: Remove the old `~/.tmux.conf`**

Run:
```bash
rm -f ~/.tmux.conf
```

Expected: no output (file removed or never existed).

- [ ] **Step 6.3: Remove the old `~/.tmux/` plugin directory**

Run:
```bash
rm -rf ~/.tmux
```

Expected: no output. Plugins will be re-cloned into `$XDG_DATA_HOME/tmux/plugins/` on next tmux launch.

- [ ] **Step 6.4: Deploy dotfiles (create symlinks)**

Run:
```bash
/Users/nishikataseiichi/.dotfiles/setup/setup.zsh
```

Expected output includes lines like:
```
.../config/tmux -> /Users/nishikataseiichi/.config/tmux
.../config/sesh -> /Users/nishikataseiichi/.config/sesh
```

(These are among the many symlinks setup.zsh creates; scan the output for the two new ones.)

- [ ] **Step 6.5: Verify symlinks**

Run:
```bash
ls -la ~/.config/tmux ~/.config/sesh
```

Expected:
```
lrwxr-xr-x ... /Users/nishikataseiichi/.config/tmux -> /Users/nishikataseiichi/.dotfiles/config/tmux
lrwxr-xr-x ... /Users/nishikataseiichi/.config/sesh -> /Users/nishikataseiichi/.dotfiles/config/sesh
```

Also confirm the config file is reachable:
```bash
test -f ~/.config/tmux/tmux.conf && echo OK || echo MISSING
```

Expected: `OK`.

---

## Task 7: Launch tmux and install plugins

**Files:** (none; plugin installation writes under `$XDG_DATA_HOME/tmux/plugins/`)

- [ ] **Step 7.1: Start a fresh shell so zoxide is initialized**

Open a new terminal tab/window (or run `exec zsh`). Confirm zoxide loaded:
```bash
type z
```

Expected: `z is a function` (or similar — it should NOT say "not found").

- [ ] **Step 7.2: Start tmux (this triggers TPM auto-clone + install_plugins)**

Run:
```bash
tmux
```

Expected behavior:
- First run only: a brief message about cloning TPM may flash. Plugins are fetched automatically.
- Status line loads with catppuccin theme (mocha).
- Prefix is `C-Space` (status indicator if catppuccin shows it).

- [ ] **Step 7.3: If plugins are not auto-installed, trigger manual install**

Inside tmux, press: `C-Space` then `I` (capital I). A TPM dialog runs `install_plugins`. Wait for "TMUX environment reloaded" or similar confirmation.

- [ ] **Step 7.4: Verify plugin directory**

Run (from any shell):
```bash
ls "$XDG_DATA_HOME/tmux/plugins/"
```

Expected: 10 entries —
```
catppuccin      tmux-continuum   tmux-resurrect   tmux-sessionx    vim-tmux-navigator
tmux            tmux-fzf         tmux-sensible    tmux-thumbs      tmux-yank
tpm
```

(Order may differ; count should be at least the 10 plugins declared plus `tpm` itself.)

---

## Task 8: Verify keybindings and session UX

**Files:** (manual verification; no commits)

- [ ] **Step 8.1: Reload config and verify the binding works**

Inside tmux, press: `C-Space` then `r`. Expected: status message `tmux.conf reloaded` appears briefly.

- [ ] **Step 8.2: Splits inherit current directory**

Inside tmux:
1. `cd /tmp` in current pane
2. Press `C-Space` then `|` — new pane opens at right, `pwd` reports `/tmp`
3. Press `C-Space` then `-` — new pane opens below, `pwd` reports `/tmp`
4. Close extra panes with `C-Space x` (and confirm with `y`)

- [ ] **Step 8.3: Session picker via tmux-sessionx**

Inside tmux, press `C-Space` then `o`.

Expected: a popup appears listing:
- The current tmux session
- Directories from zoxide (e.g., `.dotfiles`, home, recent CWDs)
- The `dotfiles` fixed session from `sesh.toml`

Use arrow keys / fzf query to pick `dotfiles` and Enter. A new session called `dotfiles` should attach with `hx .` running in `~/.dotfiles`.

Exit helix (`:q`) and detach the session (`C-Space d`) to return to the prior session.

- [ ] **Step 8.4: Shell-level `sesh connect`**

In any shell (outside tmux or in a pane):
```bash
sesh list
```
Expected: a newline-separated list including zoxide dirs, tmux sessions, and the `dotfiles` entry.

Then:
```bash
sesh connect dotfiles
```
Expected: attaches / creates the `dotfiles` session.

- [ ] **Step 8.5: tmux-fzf (non-session operations)**

Inside tmux, press `C-Space` then `F` (capital). A tmux-fzf menu appears. Navigate to `window > switch` or `pane > kill` to verify the menu works. Exit with `Esc`.

- [ ] **Step 8.6: tmux-thumbs**

Cause some URLs to appear on screen (e.g., `cat ~/.dotfiles/README.md`). Press `C-Space` then `t`. Hints (letters) appear over matchable strings. Type a hint's letter(s) to copy that string to clipboard. Verify with `pbpaste`.

- [ ] **Step 8.7: vi-mode copy + pbcopy**

Inside tmux:
1. `C-Space [` — enter copy mode
2. Move with `h/j/k/l`; press `v` to start selection; move to select a word; press `y`
3. Copy mode exits. Verify clipboard with `pbpaste` in a pane.

Expected: the selected text is on the macOS clipboard.

- [ ] **Step 8.8: vim-tmux-navigator (helix integration check)**

Inside tmux, split into two panes (`C-Space |`). In the left pane launch `hx ~/.dotfiles/zshrc`. In helix, create a vertical split. Then press `C-h` / `C-l` — focus should transition between helix splits and tmux panes transparently without pressing prefix.

Note: vim-tmux-navigator mainly integrates with vim/neovim. helix may require additional configuration if not working out of the box — if the keys feel unnatural, this is acceptable to note as a follow-up and does not block the plan completion.

- [ ] **Step 8.9: resurrect / continuum regression check**

Inside tmux, create 2 named windows with distinct contents. Press `C-Space` then `C-s` (tmux-resurrect save). Expected: `Tmux environment saved!` message.

Kill the server (`tmux kill-server`), relaunch `tmux`, and press `C-Space` then `C-r`. Expected: sessions/windows restored.

- [ ] **Step 8.10: Final state summary**

Run:
```bash
ls -la ~/.tmux.conf ~/.tmux 2>&1 | head -5
ls -la ~/.config/tmux ~/.config/sesh
ls "$XDG_DATA_HOME/tmux/plugins/" | wc -l
```

Expected:
- `~/.tmux.conf`: `No such file or directory`
- `~/.tmux`: `No such file or directory`
- `~/.config/tmux` and `~/.config/sesh` are symlinks into `~/.dotfiles/config/`
- Plugin count ≥ 10

This closes the migration.

---

## Rollback

If the migration causes issues and you need to revert to the previous working state:

```bash
cd /Users/nishikataseiichi/.dotfiles
git log --oneline -n 6  # identify the 4 commits from Tasks 1-4
# Revert each in reverse order (start from the most recent commit)
git revert --no-edit <hash-of-zshrc-commit>
git revert --no-edit <hash-of-brewfile-commit>
git revert --no-edit <hash-of-sesh-commit>
git revert --no-edit <hash-of-tmux-commit>

# Remove the deployed symlinks
rm -f ~/.config/tmux ~/.config/sesh

# Recreate the minimal previous ~/.tmux.conf (the original was not under git;
# this is the literal prior content that existed before the migration):
cat > ~/.tmux.conf <<'EOF'
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'sainnhe/tmux-fzf'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'catppuccin/tmux#v2.3.0'

set -g mouse on
set -g history-limit 100000

run '~/.tmux/plugins/tpm/tpm'
EOF

# Reinstall old tpm in the legacy location and let tmux reinstall the plugins
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Restart tmux
tmux kill-server
```

`brew uninstall sesh zoxide` is optional cleanup — they are small and harmless if left installed.
