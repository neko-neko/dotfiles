# tmux / sesh エイリアス整備と Claude Code セッション識別

- **Date:** 2026-04-24
- **Status:** Design — awaiting user review before implementation plan
- **Scope:** `aliases` / `bin/` / `spec/` への追加。`config/tmux/tmux.conf` と `config/sesh/sesh.toml` は変更しない

## 1. 背景と問題

- 直近のコミットで tmux / sesh / zoxide を導入済み（`c713109`, `3165531`, `c3da0fa`, `b77d927`）
- tmux/sesh を便利に扱うエイリアスがまだ存在しない（`aliases` にセクションなし）
- 生 `tmux` / `tmux new` で作ったセッションは数値名（`0`, `1`, ...）になり、Claude Code を複数同時起動したときに識別できない
- ワークフローは **主に worktree 単位**（`wt` 使用）、まれに用途別サブセッション（`review`, `impl` など）

## 2. 目標

1. worktree を開くたびに自動で識別可能な名前のセッションが作られる
2. Claude Code 用セッションを他のセッションと視覚的に分離する（`tmux ls` 一発で仕分け可能）
3. 生 `tmux new` を明示的に使わなくても、常に意味のある名前が付く状態にする
4. 既存の `aliases` 命名規約（`repo`/`repoc`、`ghi`/`ghp`、`dvrm`、2〜4 文字）に整合させる

## 非目標（YAGNI）

- 生 `tmux` コマンドを `sesh connect` に差し替え（挙動差が大きい）
- zsh completion（`s <TAB>` でセッション候補）
- セッションごとの status bar 色分け
- `wt remove` と連動した一括 kill

## 3. 設計方針

### 3.1 Hybrid: sesh 主軸 + `cc/` プレフィックス

- 通常セッション: sesh（fzf で zoxide / tmux / sesh.toml の統合リスト）を第一市民に
- Claude Code セッション: `cc/<repo>-<branch>[-<suffix>]` の命名で tmux ネイティブに立てる
- `cc/` プレフィックスが `^cc/` grep 一発の識別性を担保（tmux はセッション名に `/` を許容）

### 3.2 ファイル配置

既存の分業規約（`bin/hash_port` が bash + shellspec の見本）に揃える。

| パス | 役割 | 言語 |
|---|---|---|
| `bin/tmux-session-name` | 現在の cwd と git 状態から tmux セッション名を算出して stdout に出す | bash |
| `bin/cc-session` | `tmux-session-name` を呼び、`cc/<name>` の tmux セッションで `claude` を起動 / attach | bash |
| `aliases`（既存ファイル追記） | `s`, `sa`, `sn`, `sk`, `sls`, `ccs`, `ccl`, `cck` を追加 | zsh |
| `spec/tmux-session-name_spec.sh`（新規） | shellspec テスト | bash |

**変更しないもの:**

- `config/tmux/tmux.conf`: sessionx / catppuccin など既存のまま
- `config/sesh/sesh.toml`: worktree は動的で fixed session に入れない
- `zshrc` / `zshenv`: `aliases` ファイル経由でしかロード変更は発生しない

## 4. セッション命名ルール（`bin/tmux-session-name`）

**インターフェース:**

```
tmux-session-name [suffix]
```

引数 `suffix` はオプション（1 個）。結果は 1 行で stdout へ。エラー時は stderr にメッセージを出し exit 1（ただし「エラー」は起こりにくい — § 4.2 参照）。

### 4.1 算出ロジック

```
1. repo / branch 判定:
     git リポジトリ内なら:
       common_dir = git rev-parse --path-format=absolute --git-common-dir
       repo_root  = dirname(common_dir)                  # worktree でも main repo でも同じ値
       repo       = basename(repo_root) の先頭 "." を除去  # ".dotfiles" → "dotfiles"
       branch     = git rev-parse --abbrev-ref HEAD
       detached の場合は branch = "HEAD-$(git rev-parse --short=7 HEAD)"
       name       = "<repo>-<branch>"
     リポジトリ外なら:
       name = basename("$PWD")（先頭 "." 除去）
2. suffix が与えられた場合: name = "<name>-<suffix>"
3. 区切り文字の正規化:
     `/` `.` `:` ` ` `\t` → `-` に置換
     連続した `-` は 1 個に圧縮
     先頭・末尾の `-` を除去
4. 空になった場合は "root" にフォールバック
```

**備考:** `git rev-parse --path-format=absolute --git-common-dir` は worktree 内でも main repo の `.git` ディレクトリの絶対パスを返すため、main repo と worktree で同じ `repo_root` になる。これにより `flowrail` / `flowrail-worktree-X` どちらの cwd でも `repo=flowrail` に統一される。

### 4.2 命名例

| cwd | ブランチ | 引数 | 出力 |
|---|---|---|---|
| `~/.dotfiles` | `master` | なし | `dotfiles-master` |
| `~/.dotfiles` | `feature/foo` | なし | `dotfiles-feature-foo` |
| `~/.dotfiles` | `master` | `review` | `dotfiles-master-review` |
| `~/go/src/github.com/neko-neko/flowrail` | `main` | なし | `flowrail-main` |
| `~/go/src/.../flowrail-worktree-X`（wt で作った worktree） | `feat-x` | なし | `flowrail-feat-x` |
| `~/Downloads`（git 外） | — | なし | `Downloads` |
| detached HEAD（`~/.dotfiles`, SHA `abc1234`） | — | なし | `dotfiles-HEAD-abc1234` |

### 4.3 エッジケース

| ケース | 挙動 |
|---|---|
| git リポジトリ外 | `basename "$PWD"` にフォールバック（exit 0） |
| basename が空（`/` で実行） | `root` を返す |
| detached HEAD | `<repo>-HEAD-<短SHA7>` |
| bare repo | `$PWD` の basename にフォールバック（起こりにくい、適切な挙動） |

## 5. コマンド表面（`aliases` に追加）

### 5.1 セッション系

| エイリアス | 実体 | 説明 |
|---|---|---|
| `s` | `sesh connect "$(sesh list -tzc \| fzf)"` | fzf で sesh 候補（tmux / zoxide / sesh.toml）から選択 |
| `sa` | `sesh connect --last` | 直前セッションへトグル |
| `sn` | zsh function: `_tmux_session_new [suffix]` | `tmux-session-name` で名前算出 → 既存なら attach/switch、無ければ新規 |
| `sk` | `tmux ls \| fzf --multi \| cut -d: -f1 \| xargs -n1 tmux kill-session -t` | fzf 複数選択 kill |
| `sls` | `tmux ls` | そのまま表示（慣用名として alias 化） |

`sn` は引数を受けるため alias では不便。aliases ファイル内に inline で zsh function を定義し alias で呼び出す（既存の `__encode`/`__decode` と同パターン）。

### 5.2 Claude Code 系

| エイリアス | 実体 | 説明 |
|---|---|---|
| `cc` | **既存のまま**: `claude --effort max --enable-auto-mode` | 変更なし |
| `ccs` | `cc-session [suffix]` | `cc/<name>` のセッションに入り claude 実行（既存なら attach のみ） |
| `ccl` | `tmux ls \| grep '^cc/'` \|\| true | Claude Code セッション一覧（空のときもエラーにしない） |
| `cck` | `ccl` + `fzf --multi` + kill | Claude Code セッションから選択 kill |

### 5.3 `bin/cc-session` の挙動（擬似コード）

```bash
#!/usr/bin/env bash
set -euo pipefail
suffix="${1:-}"
base="$("$(dirname "$0")/tmux-session-name" ${suffix:+"$suffix"})"
name="cc/${base}"

if tmux has-session -t "$name" 2>/dev/null; then
  # 既存セッション: claude を再送信しない（二重起動防止）
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$name"
  else
    tmux attach -t "$name"
  fi
else
  # 新規作成: startup で claude を送る
  tmux new-session -d -s "$name" -c "$PWD"
  tmux send-keys -t "$name" 'claude' C-m
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$name"
  else
    tmux attach -t "$name"
  fi
fi
```

**重要:**

- tmux ネスト防止のため `$TMUX` 環境変数で分岐
- `send-keys 'claude'` は pane 内 zsh で実行されるため、既存 `alias claude='claude --effort max --enable-auto-mode'` がそのまま展開される
- 既存セッション再 attach 時は `send-keys` しない → claude 二重起動防止

### 5.4 aliases ファイルへの追記セクション

既存の `# claude code` セクションの直前（もしくは独立セクションとして）に挿入する:

```zsh
# ------------------------------
# tmux / sesh
# ------------------------------
alias s='sesh connect "$(sesh list -tzc | fzf)"'
alias sa='sesh connect --last'
alias sk='tmux ls 2>/dev/null | fzf --multi | cut -d: -f1 | xargs -r -n1 tmux kill-session -t'
alias sls='tmux ls'

# sn [suffix]: worktree/cwd-aware named session
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

既存 `# claude code` セクションを拡張:

```zsh
# ------------------------------
# claude code
# ------------------------------
alias claude='claude --effort max --enable-auto-mode'
alias ccs='cc-session'
alias ccl='tmux ls 2>/dev/null | grep "^cc/" || true'
alias cck='ccl | fzf --multi | cut -d: -f1 | xargs -r -n1 tmux kill-session -t'
```

## 6. テスト

### 6.1 自動（shellspec、CI で実行）

`spec/tmux-session-name_spec.sh` を `spec/hash_port_spec.sh` と同構造で追加:

**カバーするケース:**

1. 通常の git repo、ブランチ名をそのまま反映
2. ブランチ名に `/` が含まれる → `-` に置換
3. suffix 引数あり → 末尾に付く
4. git 外 → basename("$PWD")
5. detached HEAD → `<repo>-HEAD-<短SHA7>`
6. worktree（`git worktree add` で作ったもの）→ main と同じ repo 名、別 branch

`bin/cc-session` は tmux サーバー操作を伴うため shellspec では扱わない（手動スモークで担保）。

### 6.2 手動スモーク（受け入れ基準）

§ 4（設計会話の Edge Cases）の 10 項目を実施:

1. `~/.dotfiles` で `sn` → セッション `dotfiles-master` で入れる
2. 同じ場所で再度 `sn` → 既存に attach（新規作成されない）
3. `ccs` → `cc/dotfiles-master` が作られ claude が自動起動
4. 抜けて再度 `ccs` → 既存セッションへ復帰、claude は二重起動しない
5. `ccs review` → `cc/dotfiles-master-review` が別枠で立つ
6. `sls` で両方見える／`ccl` は `cc/*` のみ
7. `sk` fzf で複数選択 → 選んだぶん kill
8. git 外（`~/Downloads`）で `sn` → `Downloads` で起動
9. `feature/foo` ブランチに `wt switch --create` → `ccs` が `cc/<repo>-feature-foo` 生成
10. `sesh` を一時 rename → `s` がエラー案内を出す

## 7. セキュリティ / 破壊リスク

- tmux セッション kill はユーザー選択（`fzf --multi`）なので誤爆はユーザー操作前提
- `bin/cc-session` は `set -euo pipefail`、外部コマンドは `tmux` のみ
- 引数は `send-keys` に直接渡さない（`claude` 文字列はハードコード）→ 引数注入リスクなし
- 既存 `aliases` の挙動を一切変えない（`claude` alias も含め既存維持）

## 8. 変更するファイル一覧

**新規:**

- `bin/tmux-session-name`
- `bin/cc-session`
- `spec/tmux-session-name_spec.sh`

**追記:**

- `aliases`（tmux/sesh セクション新設、claude code セクション拡張）

**変更しない:**

- `config/tmux/tmux.conf`
- `config/sesh/sesh.toml`
- `zshrc` / `zshenv` / `sheldon` plugins
- `.github/workflows/ci.yml`（shellspec は既存ジョブが `spec/` を拾うため）

## 9. ロールアウト / ロールバック

ロールアウト: 追加のみで既存挙動を変えないため、段階的導入不要。インストールは `reload` alias（既存）で `.aliases` を再読込。

ロールバック: 追加したファイルの削除と aliases の該当セクション削除のみ。他コンポーネントへの副作用なし。

## 10. オープン質問

なし（§ 1〜5 のブレスト合意済み）。

---

## Appendix A: 既存命名規約との整合チェック

| 既存例 | パターン | 今回の対応 |
|---|---|---|
| `repo` / `repoc` / `repob` | 名詞 + 動詞接尾 (c=cd, b=browser) | `cc` / `ccs` / `ccl` / `cck` は同構造（s=session, l=list, k=kill） |
| `ghi` / `ghp` / `ghpc` | ツール + リソース + 動詞 | OK |
| `dvrm` / `killf` | ツール / fzf 呼び出しは `xxxf` or 動詞付き | `sk` / `cck` は `_k`（kill）サフィックス — shortest な 2 文字を優先 |
| `alias -g KP` 等 | uppercase global alias は fzf 動的置換 | 今回は global alias 不要 |

## Appendix B: 代替案（採用せず）

- **案 A: 薄いエイリアスのみ** — `cc/` プレフィックスなし、sesh 任せ。Claude Code 識別要件に半分しか答えない
- **案 B: Claude Code 専用ランチャー中心** — 通常セッションの数値名問題を放置
- **`alias tmux='sesh connect'`** — 挙動差が大きく副作用が読めない。却下
