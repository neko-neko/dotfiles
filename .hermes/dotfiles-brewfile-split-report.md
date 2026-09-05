# dotfiles Brewfile split — 実施レポート

Mission brief: `.hermes/dotfiles-brewfile-split-brief.md`

## FILES_CHANGED

Tracked ファイルの変更（`git diff --stat`）:

```
 Brewfile                           | 129 +++++--------------------------------
 README.md                          |  10 +++
 aliases                            |  23 ++++---
 setup/install.zsh                  |   7 ++
 setup/layers/home-network/Brewfile |   1 +
```

新規ファイル（untracked）:

```
.aliases.local.example
.hermes/dotfiles-brewfile-split-brief.md
.hermes/dotfiles-brewfile-split-report.md
setup/layers/hermes-server/Brewfile
setup/layers/hermes-server/install.zsh
setup/layers/mac-client/Brewfile
setup/layers/mac-client/install.zsh
```

## 構成

| ファイル | 用途 |
|---|---|
| `Brewfile`（ルート） | 共通（Hermesサーバー + Macクライアント両方で使うCLIツール） |
| `setup/layers/hermes-server/Brewfile` | Hermesサーバー専用 |
| `setup/layers/mac-client/Brewfile` | Macクライアント専用（GUI・モバイル開発・デスクトップアプリ） |
| `setup/layers/home-network/Brewfile` | 既存Home Networkレイヤー。Jellyfin (`cask 'jellyfin'`) を追加 |

`setup/install.zsh` は従来どおり共通 `Brewfile` のみを対象とし（`setup/setup.zsh` のフルインストールでもサーバーへGUI/mobile/mediaパッケージを入れない）、コメントで各レイヤー install スクリプトへの誘導を追記。`README.md` の Installation セクションにレイヤー選択手順を追記。`hermes-server` / `mac-client` の `install.zsh` は既存 `home-network/install.zsh` と同一パターンで新規作成（実行権限付与済み）。

## 分類の根拠（主な判断）

- **mac-client へ移動**: 全GUI cask、モバイル開発（fastlane, firebase-cli, cocoapods, flutter, dart tap, fvm）、フォント、`mas`（App Store CLI本体＋対象アプリ）、Cursor拡張機能一式。
- **common に残置/追加**: CLI系ツール全般（GNU utils, shell/terminal, git, cloud/devops CLI, LSP, bat/ripgrep等）。`cask 'codex'`（OpenAI Codex CLIエージェント、GUIではない）と `cask '1password-cli'`、`cask 'gcloud-cli'` は cask 形式だが実体はCLIのため common に区分。
- **hermes-server へ移動**: `brew 'ghidra', link: false`（headless/batch解析用途、対をなすGUI版 `cask 'ghidra'` は mac-client）。現時点で明確にサーバー専用と判断できたパッケージはこれのみ。他候補（k8s/cloud CLI群）はクライアント側でも同様に使われうるため common に残した。
- **home-network**: 既存 `tailscale`/`adguardhome`/`syncthing` に加え `cask 'jellyfin'` を追加（`brew info --cask jellyfin` で存在確認）。

Supervisor検証で、旧 `Brewfile` + 旧 `setup/layers/home-network/Brewfile` の `tap`/`brew`/`cask`/`mas`/`vscode` 行と、新4 Brewfileを突き合わせ済み。**旧218行→新219行、欠落なし、重複なし、追加は `cask 'jellyfin'` のみ**。

## aliases

- ユーザーが未コミットで無効化していた4エイリアス（`grep --color=auto` / `ls --color` / `top='btm'` / `cat='bat'`）は無効化状態を保持。
- Supervisor追加修正として、`l`/`la`/`ll`/`lt` 等のList系エイリアスからも既定の `--color` を外し、HermesサーバーでAIエージェントが読む出力をplainに寄せた。
- Macクライアント向けの色付き/置換aliasは新規 `.aliases.local.example` に集約。`cp .aliases.local.example ~/.aliases.local` で再有効化できる（既存の `aliases` 末尾の `~/.aliases.local` 読み込み機構を利用）。
- `# Override` コメント行に混入していた制御文字（`0x10` / DLE）を `# Override` に修正。

## COMMANDS_RUN / 検証結果

```
$ for f in Brewfile setup/layers/hermes-server/Brewfile setup/layers/mac-client/Brewfile setup/layers/home-network/Brewfile; do ruby -c "$f" || exit 1; done
Syntax OK  (全4ファイル)

$ for f in aliases setup/install.zsh setup/setup.zsh setup/layers/hermes-server/install.zsh setup/layers/mac-client/install.zsh setup/layers/home-network/install.zsh; do zsh -n "$f" || exit 1; done
(exit 0, エラーなし)

$ brew info --cask jellyfin >/dev/null
(exit 0, cask存在確認)

$ package-line parity script（旧Brewfile+旧home-network vs 新4 Brewfile）
old_count=218, new_count=219, missing=[], added=["cask 'jellyfin'"], dups=[]
```

`brew bundle` / `brew install` 等のインストール系コマンドは一切実行していない。push / merge / commit も未実施（ローカル編集のみ）。

## BLOCKER（要注意事項・要ユーザー確認）

**Claude Code worker が検証作業中に一時的な `git stash` / `git stash pop` を実行し、既存の未コミット変更を巻き込みました。** 現在の作業ツリーは本タスクの変更として整っていますが、`git stash list` に既存 `stash@{0}` が残っています。

Supervisor確認:

```
$ git stash show --stat stash@{0}
.claude/settings.local.json | 5 +++--
aliases                     | 4 ++--
gitconfig                   | 6 ++++++
gitignore_global            | 2 ++
```

`aliases` も含むため、Hermes側で勝手に `git stash drop` はしていません。必要であれば内容を確認してから削除してください。

## RESULT

`PASS with caution` — Brewfile分割・aliasesサーバー安全化・構文検証・パッケージ欠落検証は完了。ただし残存stashはユーザー確認待ち。

## NEXT_ACTION

- ユーザー: `stash@{0}` の内容確認・要否判断。
- ユーザー: hermes-server / mac-client への分類が実際の利用実態と合っているか一読し、必要なら該当行を該当 Brewfile 間で移動。
- 実機反映時は各マシンで `setup/install.zsh` の後、該当 `setup/layers/<role>/install.zsh` を実行。
