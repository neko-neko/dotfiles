# tmux 設定の dotfiles 化 + XDG 移行 + モダンセッション体験

- **日付**: 2026-04-24
- **ステータス**: Approved
- **対象**: `~/.tmux.conf` を dotfiles 管理下に移し、XDG Base Directory 準拠に変更。併せて `sesh` + `tmux-sessionx` によるモダンな fuzzy session 体験と、主要な tmux 体験改善を導入する

## 背景と目的

### 現状

- `~/.tmux.conf` (13 行) は dotfiles の管理外で、ホームディレクトリ直下に直接配置されている
- tpm プラグインは `~/.tmux/plugins/` に配置されており、これも dotfiles 管理外
- 導入済みプラグイン: `tpm`, `tmux-sensible`, `tmux-fzf`, `tmux-yank`, `tmux-resurrect`, `tmux-continuum`, `catppuccin/tmux`
- `tmux-fzf` は導入済みだが日常的に活用できていない（セッション管理体験が平凡）
- dotfiles の `config/*` は既に XDG 準拠（`ghostty`, `helix`, `starship.toml` など）でリンクされている

### 目的

1. **管理の一元化**: tmux 設定を dotfiles で管理し、他環境で再現可能にする
2. **XDG 完全準拠**: `~/.tmux.conf` と `~/.tmux/` を無くし、`$XDG_CONFIG_HOME/tmux/` と `$XDG_DATA_HOME/tmux/` に統一
3. **モダンなセッション体験**: `sesh` + `tmux-sessionx` で zoxide 連携の fuzzy session picker を実現
4. **tmux 体験全般の改善**: prefix 変更、分割キー、vi-mode クリップボード、vim-tmux 透過移動など

## 非目標 (Non-goals)

- 既存の catppuccin テーマ変更（維持）
- Linux 環境向け最適化（macOS 向け、ただし `uname` ガードで pbcopy 依存部分は分離）
- tmuxinator 風の完全な project bootstrap（`sesh.toml` で最小限に留める）
- プラグイン全面入れ替え（既存プラグインは維持、追加のみ）

## アーキテクチャ

### ディレクトリ構造

```
~/.dotfiles/
├── config/
│   ├── tmux/
│   │   └── tmux.conf              # 本体（1 ファイル、セクション分け）
│   └── sesh/
│       └── sesh.toml              # sesh 設定（zoxide 連携 + 定型セッション）
├── Brewfile                       # + sesh, + zoxide
├── zshrc                          # + eval "$(zoxide init zsh)"
└── setup/setup.zsh                # 変更不要（既存の config/ 自動リンク機構を利用）
```

### シンボリックリンク配置 (setup.zsh が自動生成)

- `~/.config/tmux` → `~/.dotfiles/config/tmux` (XDG_CONFIG_HOME)
- `~/.config/sesh` → `~/.dotfiles/config/sesh`

tmux 3.1+ は `$XDG_CONFIG_HOME/tmux/tmux.conf` を自動検出するため、環境変数や追加フラグは不要。

### プラグイン配置

- `TMUX_PLUGIN_MANAGER_PATH` を `$XDG_DATA_HOME/tmux/plugins` に設定
- tpm 自身もこのパスに clone（tmux.conf 冒頭の bootstrap スニペットで初回自動 clone）
- 旧 `~/.tmux/` ディレクトリは廃止

### 旧ファイルの扱い

| 旧パス | 対応 |
|---|---|
| `~/.tmux.conf` | setup.zsh の対象外（dotfile として `.` プレフィックス付きのシンボリックリンク生成ロジックに合致しない）。**手動で `rm` する** |
| `~/.tmux/plugins/` | 新しい `$XDG_DATA_HOME/tmux/plugins/` にプラグインが再インストールされるため、**手動で `rm -rf` する**のが最速 |

## コンポーネント詳細

### 1. tmux.conf

1 ファイル、セクションコメントで論理分割。想定行数 ~150 行。

**セクション構成**:

1. **Bootstrap**: `TMUX_PLUGIN_MANAGER_PATH` 設定、tpm の存在チェック + 初回 clone スニペット
2. **Core options**:
   - `default-terminal "tmux-256color"` + `terminal-overrides ",*:RGB"` (true color)
   - `mouse on`
   - `history-limit 100000`
   - `base-index 1` / `pane-base-index 1` / `renumber-windows on`
   - `escape-time 0`
   - `focus-events on`
   - `aggressive-resize on`
   - `mode-keys vi`
3. **Keybindings**:
   - Prefix: `C-b` → `C-Space` (`unbind C-b; set -g prefix C-Space; bind C-Space send-prefix`)
   - 分割: `bind | split-window -h -c "#{pane_current_path}"`, `bind - split-window -v -c "#{pane_current_path}"`
   - 新規 window も current-path 継承: `bind c new-window -c "#{pane_current_path}"`
   - リロード: `bind r source-file ~/.config/tmux/tmux.conf \; display "reloaded"`
   - Session picker: `bind o display-popup -E -w 80% -h 80% "sesh connect \"$(sesh list -i | fzf)\""` (sessionx が無効化された際のフォールバック。sessionx 側でも同じキーを上書きする想定)
   - copy-mode (vi): `bind -T copy-mode-vi v send -X begin-selection`, `bind -T copy-mode-vi y send -X copy-pipe-and-cancel "pbcopy"` (macOS ガード付き)
   - smart pane switching (vim-tmux-navigator): `C-h/j/k/l` で透過移動
4. **Plugins (tpm 宣言)**:
   - `tmux-plugins/tpm`
   - `tmux-plugins/tmux-sensible`
   - `tmux-plugins/tmux-yank`
   - `tmux-plugins/tmux-resurrect`
   - `tmux-plugins/tmux-continuum`
   - `sainnhe/tmux-fzf` (window/pane/command 用に役割変更)
   - `omerxx/tmux-sessionx` (新規: session picker)
   - `fcsonline/tmux-thumbs` (新規: URL/hash コピー)
   - `christoomey/vim-tmux-navigator` (新規: pane 透過切替)
   - `catppuccin/tmux#v2.3.0`
5. **Plugin configs**:
   - `tmux-sessionx`:
     - `@sessionx-bind 'o'` (prefix + o で起動)
     - `@sessionx-preview-enabled 'true'`
     - `@sessionx-zoxide-mode 'on'` (zoxide のディレクトリも候補に)
     - `@sessionx-custom-paths` で `~/.dotfiles` など追加候補
   - `tmux-fzf`:
     - `TMUX_FZF_LAUNCH_KEY="F"` (prefix + F で起動)
     - session 機能は sessionx に任せるため、メニューから除外（`TMUX_FZF_OPTIONS` で制御）
   - `tmux-thumbs`:
     - `@thumbs-command 'echo -n {} | pbcopy'`
     - `@thumbs-key t` (prefix + t で起動、prefix 変更後は `C-Space t`)
   - `catppuccin`: 既存スタイル維持（status line の配置調整のみ）
   - `tmux-continuum`: `@continuum-restore 'on'`
   - `tmux-resurrect`: `@resurrect-capture-pane-contents 'on'`
6. **TPM run**: `run '$TMUX_PLUGIN_MANAGER_PATH/tpm/tpm'`

### 2. sesh.toml

```toml
# Global defaults
[default_session]
startup_command = ""  # 空: デフォルトシェルのみ

# ----- Fixed sessions -----
[[session]]
name = "dotfiles"
path = "~/.dotfiles"
startup_command = "hx ."

# zoxide のディレクトリは sesh が自動統合するため、追加定義は不要。
# 必要に応じて後日追加する想定。
```

### 3. Brewfile 差分

```diff
+brew 'sesh'
+brew 'zoxide'
```

### 4. zshrc 差分

```diff
+# zoxide (directory jump, integrated with sesh)
+eval "$(zoxide init zsh)"
```

配置位置は既存の init 系コマンドが集まるセクション末尾（sheldon / starship の近く）とする。

### 5. setup.zsh

**変更なし**。既存ロジック (`config/*` を `~/.config/*` にシンボリックリンクする for ループ) がそのまま `tmux/` と `sesh/` を扱う。

## データフロー

### セッション作成・アタッチの主要経路

| 操作 | 起動元 | 流れ |
|---|---|---|
| `prefix + o` | tmux 内 | tmux-sessionx が popup を開く → sesh list (zoxide + tmux セッション + sesh.toml の固定セッション) を fzf 表示 → 選択で既存アタッチ or 新規作成 |
| `sesh connect $(sesh list | fzf)` | shell | zoxide + tmux + sesh.toml を統合した候補を fzf → アタッチ/作成 |
| `prefix + F` | tmux 内 | tmux-fzf メニュー (window, pane, command, keybinding) — session 機能は除外 |
| `prefix + t` | tmux 内 | tmux-thumbs でハイライト → キーで pbcopy |
| `C-h/j/k/l` | tmux/helix 内 | vim-tmux-navigator が tmux pane 境界と helix split を透過的に移動 |

### プラグインブートストラップ

1. 初回 tmux 起動時: tmux.conf 冒頭のスニペットが `$TMUX_PLUGIN_MANAGER_PATH/tpm` の存在をチェック、無ければ `git clone https://github.com/tmux-plugins/tpm $TMUX_PLUGIN_MANAGER_PATH/tpm`
2. ユーザーが `prefix + I` でプラグイン一括インストール
3. 以降は tpm が管理

## インストール・移行手順

新規環境 / 既存環境ともに共通の手順:

1. `cd ~/.dotfiles && git pull`
2. `brew bundle --file=Brewfile` (sesh, zoxide が追加導入される)
3. **旧ファイル削除**:
   - `rm -f ~/.tmux.conf`
   - `rm -rf ~/.tmux` (旧 TPM と plugins を削除。新しい XDG パスに再配置される)
4. `~/.dotfiles/setup/setup.zsh` 実行 → `~/.config/tmux`, `~/.config/sesh` のシンボリックリンク生成
5. 新しい zsh セッションで `zoxide init` が有効化されたことを確認
6. `tmux` 起動 → tpm 自動 clone 発動 → `prefix + I` でプラグイン一括インストール
7. 動作確認 (下記テスト項目)

## エラーハンドリング

| 障害条件 | 挙動 |
|---|---|
| TPM が未インストール | tmux.conf 冒頭 bootstrap が `git clone` を実行。失敗時はメッセージ表示のみ、tmux 起動は続行 |
| sesh / zoxide が未インストール | tmux-sessionx は sesh 連携が失敗した場合、tmux 標準の session 一覧にフォールバック (`@sessionx-fallback-enabled`) |
| macOS 以外で実行 (pbcopy 無し) | `if-shell 'uname | grep -q Darwin'` で pbcopy 依存部分を条件分岐 |
| 古い `~/.tmux.conf` が残存 | tmux 3.1+ は `$XDG_CONFIG_HOME/tmux/tmux.conf` を優先するため機能的問題は無いが、混乱回避のため手動削除を推奨 (手順 3) |

## テスト方針

### 構文・起動確認

- `tmux -f ~/.config/tmux/tmux.conf -L test new-session -d && tmux -L test kill-server` — 設定ファイルに文法エラーが無いこと
- 新規 tmux セッションで status line が catppuccin テーマで表示されること
- `prefix + I` 後、`$XDG_DATA_HOME/tmux/plugins/` 配下に 10 プラグインが存在すること

### キーバインド手動確認チェックリスト

- `C-Space |` で縦分割、current-path が継承される
- `C-Space -` で横分割、current-path が継承される
- `C-Space r` で設定リロード、通知が表示される
- `C-Space o` で sessionx popup が起動、zoxide ディレクトリが候補に含まれる
- `C-Space F` で tmux-fzf メニュー表示 (session 項目が無いこと)
- `C-Space t` で tmux-thumbs ハイライト、選択で pbcopy に入ること
- copy-mode (`C-Space [`) で `v` 選択開始、`y` で pbcopy コピー
- helix 内で `C-h/j/k/l` が pane 境界を越えて透過移動すること

### sesh 単体動作確認

- `sesh list` が zoxide のディレクトリと既存 tmux セッションを列挙すること
- `sesh connect dotfiles` で `~/.dotfiles` セッションがアタッチ（起動時に `hx .` が実行）されること

### リグレッション確認

- `tmux-resurrect` の save (`prefix + C-s`) / restore (`prefix + C-r`) が従来通り動作
- `tmux-continuum` による自動保存が続行
- `tmux-yank` のコピー動作（`prefix + [` → 選択 → `y`）

## 未解決事項 / 将来の拡張

- `sesh.toml` の session 定義は最小限。よく使うプロジェクトが増えたら随時追加
- tmux-sessionx の preview コマンドカスタマイズ（現状はデフォルト）
- tmux-thumbs の hints カスタマイズ（現状はデフォルト文字セット）
- Linux 対応（クリップボード統合を xclip/wl-copy に切り替え）は必要になった時点で追加
