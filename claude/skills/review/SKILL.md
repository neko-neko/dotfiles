---
name: review
description: >-
  多角的コードレビューワークフロー。5つの観点（simplify, quality, security,
  performance, test）で並列レビューし、統合レポートから承認された指摘を修正する。
user-invocable: true
---

# Review Orchestrator

5つの観点で変更コードを並列レビューし、統合レポートを生成する。ユーザーが承認した指摘のみを修正し、linter/テストで検証する。

**開始時アナウンス:** 「Review を開始します。Phase 1: Scope Detection」

## Phase 1: Scope Detection

引数を解析し、レビュー対象の差分を取得する。

### 引数パース

| 引数 | diff 範囲 |
|------|----------|
| (なし) | `HEAD~1..HEAD` |
| `--branch` | `$(git merge-base HEAD main)..HEAD` (`main` がなければ `master` にフォールバック) |
| `--staged` | staged changes (`git diff --cached`) |
| その他の値 | そのまま git commit range として使用 |

### 差分取得

`--staged` → `git diff --cached [--name-only]`、それ以外 → `git diff <range> [--name-only]` で `changed_files`（ファイル一覧）と `diff_content`（全差分）を取得する。

**ファイル一覧が空の場合** → 「No changes found in the specified scope」と報告して終了。

## Phase 2: Parallel Review (5 perspectives)

5つのレビューを **並列** で起動する。すべて `run_in_background: true` を使用し、結果を収集する。

### 2-1. simplify

Skill tool で `/simplify` を invoke する。引数にスコープ情報を渡す:
- `--staged` の場合: `args: "--staged"`
- `--branch` の場合: `args: "--branch"`
- commit range の場合: `args: "<range>"`
- 引数なしの場合: `args` なし（デフォルト動作）

simplify は独自のフォーマットで結果を返す。テキストとして受け取り、Phase 3 で手動パースする。

### 2-2 ~ 2-5. review-quality / review-security / review-performance / review-test

各エージェントに対して Agent tool を使用する。`subagent_type` にエージェント名（`review-quality`, `review-security`, `review-performance`, `review-test`）を指定し、prompt に `changed_files` と `diff_content` を含め、findings を JSON で返すよう指示する。

### 結果収集

5つすべての完了を待つ。いずれかのエージェントがエラーを返した場合:
- エラー内容をログに記録する
- そのエージェントの findings は空として扱い、レポートに「[category] エージェントエラー: <概要>」と注記する
- 他のエージェントの結果は正常に処理を続ける

各エージェント（simplify 以外）の応答から JSON `{"findings": [...]}` をパースする。失敗した場合は正規表現フォールバックを試み、それでも失敗ならエラーとして扱う。

## Phase 3: Report

### マージとソート

全エージェントの findings を1つのリストに統合する。simplify の結果はテキスト形式のため、個別の指摘事項を抽出し、以下のフォーマットに正規化する:

```json
{
  "file": "path/to/file",
  "line": 0,
  "severity": "medium",
  "category": "simplify",
  "description": "指摘内容",
  "suggestion": "改善案"
}
```

severity で降順ソート: high > medium > low

### レポート出力

```
## Review Report (scope: <scope_description>)

### High
1. [category] file:line -- description
   suggestion: ...

### Medium
2. [category] file:line -- description
   suggestion: ...

### Low
3. [category] file:line -- description
   suggestion: ...

---
対応する指摘番号を選択してください（例: 1,2,4 / all / none）
```

findings が 0 件の場合 → 「指摘事項はありません。レビュー完了です。」と報告して終了する。

### ユーザー選択

ユーザーの入力を待つ。受け付ける入力:
- `none` → 「レビュー完了です。修正は行いません。」と報告して終了
- `all` → 全 findings を Phase 4 に渡す
- カンマ区切りの番号（例: `1,2,4`） → 該当番号の findings を Phase 4 に渡す
- 範囲指定（例: `1-3`） → 展開して処理

## Phase 4: Approve & Fix

ユーザーが選択した findings を修正する。

### category 別の修正方法

**simplify findings の場合:**
Skill tool で `/simplify` を再度 invoke し、対象ファイルを明示的に指定する。

**その他の findings (quality, security, performance, test) の場合:**
指摘内容と suggestion に基づき、オーケストレーター自身が直接修正を実装する。修正手順:
1. 対象ファイルを Read で読み込む
2. finding の description と suggestion を参照して修正内容を決定する
3. Edit で修正を適用する
4. 同一ファイルに複数の findings がある場合は行番号の大きい方から修正する（行ずれ防止）

### エラー時

修正中にエラーが発生した場合（ファイルが存在しない、行番号が範囲外など）:
- エラー内容をユーザーに報告する
- 該当 finding をスキップして次の finding に進む

## Phase 5: Verify

修正完了後、変更を検証する。

### 差分表示

```bash
git diff
```

変更内容をユーザーに提示する。

### Linter / テスト実行

プロジェクトの linter・テストコマンドを自動検出して実行する:

| 検出ファイル | テスト | Lint |
|-------------|--------|------|
| `package.json` | `npm test` | `npm run lint` |
| `Makefile` | `make test` | `make lint` |
| `Cargo.toml` | `cargo test` | `cargo clippy` |
| `pyproject.toml` / `setup.py` | `pytest` | `ruff check .` / `flake8` |
| `go.mod` | `go test ./...` | `golangci-lint run` |

検出できない場合 → 「テスト/linter コマンドが検出できませんでした。手動で確認してください。」

### 結果報告

```
## Verification Results

- git diff: <変更ファイル数> files changed
- linter: PASS / FAIL (詳細)
- tests: PASS / FAIL (詳細)
```

テストまたは linter が失敗した場合:
- 失敗内容を表示する
- 「修正を試みますか？」とユーザーに確認する
- 承認された場合、失敗を修正して再度検証する（最大2回）
- 2回修正しても失敗する場合 → 「手動対応が必要です」と報告して終了

全て成功した場合 → 「レビュー完了。全検証パスしました。」と報告して終了する。

## Error Handling

| フェーズ | エラー | リカバリ |
|---------|--------|---------|
| 1 | git diff 失敗 | コミット範囲を確認するようユーザーに報告 |
| 1 | merge-base 失敗 | main/master どちらも存在しない旨を報告 |
| 2 | エージェントタイムアウト | 該当エージェント結果を空として続行 |
| 2 | JSON パース失敗 | 正規表現フォールバック、それでも失敗なら空 |
| 3 | ユーザー入力が不正 | 再入力を求める |
| 4 | ファイル/行番号不正 | スキップして次の finding へ |
| 5 | テスト/linter 失敗 | 修正提案、最大2回リトライ |

## Red Flags

**Never:**
- ユーザー承認なしに修正を適用する
- レビュー対象外のファイルを変更する
- findings を勝手にフィルタリング・省略する（全件レポートする）
- テスト失敗を無視して完了とする

**Always:**
- Phase 遷移時にアナウンスする
- 全5エージェントの結果を待ってからレポートする
- 修正前にユーザーの選択を得る
- 修正後に検証を実行する
