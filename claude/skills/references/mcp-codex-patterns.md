# MCP Codex 共通パターン

レビュースキルの `--codex` フラグで使用する MCP Codex ツールの共通呼び出しパターン。

## 基本設定

全パターン共通:

| パラメータ | 値 | 理由 |
|-----------|-----|------|
| `sandbox` | `"read-only"` | レビュー用途のため書き込み不要 |
| `approval-policy` | `"on-failure"` | シェルコマンド（git diff 等）の実行を許可 |
| `cwd` | 作業ディレクトリ | worktree パスがあればそれを使用 |

## パターン1: ドキュメントレビュー

対象: spec-review, implementation-review

ドキュメント内容をプロンプトに直接埋め込み、MCP Codex でレビューする。

ツール: `mcp__codex__codex`

パラメータ:
- `prompt`: ドキュメント種別に応じたレビュー指示 + ドキュメント全文
- `sandbox`: `"read-only"`
- `approval-policy`: `"on-failure"`

実行方法: `run_in_background: true` で起動し、レスポンスから `threadId` を保持する。

## パターン2: コードレビュー

対象: code-review, test-review

diff はプロンプトに埋め込まず、Codex 自身に git diff コマンドを実行させる。

ツール: `mcp__codex__codex`

パラメータ:
- `prompt`: スコープに応じた git diff コマンド実行指示 + レビュー指示
- `sandbox`: `"read-only"`
- `approval-policy`: `"on-failure"`
- `cwd`: 作業ディレクトリ

スコープ別のプロンプト指示:

| スコープ | プロンプト指示 |
|---------|--------------|
| `--staged` | 「`git diff --cached` を実行し、ステージ済みの変更をレビューしてください」 |
| `--branch` | 「`git diff $(git merge-base HEAD <base_branch>)..HEAD` を実行し、ブランチの全変更をレビューしてください」 |
| デフォルト | 「`git diff HEAD~1..HEAD` を実行し、最新コミットの変更をレビューしてください」 |
| commit range | 「`git diff <range>` を実行し、指定範囲の変更をレビューしてください」 |

実行方法: `run_in_background: true` で起動し、レスポンスから `threadId` を保持する。

## パターン3: メタレビュー（スレッド継続）

対象: 全レビュースキル共通

Phase 2 の Codex セッションを `threadId` で継続し、メタレビューを実行する。

ツール: `mcp__codex__codex-reply`

パラメータ:
- `threadId`: Phase 2 で取得した threadId
- `prompt`: 見落とし検出 + False Positive 検証の指示 + Phase 3 のレポート全文

Codex は Phase 2 でレビューした内容のコンテキストを保持しているため、ドキュメントレビューの場合のみプロンプトにドキュメント全文を再度含める。コードレビューの場合は diff を Codex が既に取得済みなのでレポートのみ渡す。

## エラーハンドリング

| 状況 | 対応 |
|-----|------|
| MCP 呼び出し失敗（サーバー未起動等） | 「MCP Codex への接続に失敗しました。--codex をスキップします。」と警告し、`codex_enabled` を false に変更して続行 |
| メタレビュー（codex-reply）失敗 | 「Codex メタレビューをスキップします」と表示し、Phase 3 のレポートのみで続行 |
| `threadId` 取得不可（Phase 2 の Codex 失敗） | メタレビューをスキップ |
| 出力パース失敗 | Codex の生テキストをそのまま表示 |
