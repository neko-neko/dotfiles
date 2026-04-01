---
name: code-review
description: >-
  多角的コードレビューワークフロー。7つの観点（simplify, code-quality, code-security,
  code-performance, code-test, ai-antipattern, code-impact）で並列レビューし、統合レポートから承認された指摘を修正する。
  --codex 指定時は Codex (companion.mjs) による並列レビューを追加する。
  --iterations N 指定時は各観点を N 回独立レビューし、過半数一致の findings のみ採用する（デフォルト: 3）。
user-invocable: true
---

# Code Review Orchestrator

6つの観点で変更コードを並列レビューし、統合レポートを生成する。ユーザーが承認した指摘のみを修正し、linter/テストで検証する。

**開始時アナウンス:** 「Code Review を開始します。Phase 1: Scope Detection」

## Coordinator Discipline

- 複数観点レビューは parallel に実行してよいが、何を直すかの最終判断はオーケストレーターが行う
- 各 review agent への prompt は自己完結にし、対象 diff、目的、期待出力を明示する
- findings をそのまま修正せず、重複除去・優先度整理・修正対象ファイルの確定を行ってから着手する
- 同一ファイル群への修正は直列に行い、verify は修正完了後に独立フェーズとして扱う
- verification ではテストや linter の結果を正直に扱い、失敗を「一部成功」で済ませない

## Phase 1: Scope Detection

引数を解析し、レビュー対象の差分を取得する。

### 引数パース

| 引数 | diff 範囲 |
|------|----------|
| (なし) | `HEAD~1..HEAD` |
| `--branch` | `$(git merge-base HEAD main)..HEAD` (`main` がなければ `master` にフォールバック) |
| `--staged` | staged changes (`git diff --cached`) |
| その他の値 | そのまま git commit range として使用 |
| `--codex` | Phase 2 に Codex 並列レビューを追加する。他の引数と組み合わせ可能 |
| `--iterations N` | N-way 投票を有効化する（デフォルト: 3）。各観点エージェントを N 回独立に起動し、過半数一致の findings のみ採用する。他の引数と組み合わせ可能 |

`--codex` は他の引数（`--branch`, `--staged`, commit range）と組み合わせて使用できる。`--codex` が指定された場合、変数 `codex_enabled` を true とし、Phase 2 で参照する。`--codex` が指定されていない場合、従来通り6観点のみでレビューする。

`--iterations N` が指定された場合、変数 `iterations` に N を格納する。未指定の場合 `iterations = 3`（デフォルト）。`iterations < 1` の場合は `1` に補正する。`iterations == 1` の場合、Phase 2.5 をスキップし従来動作と同一になる。

### 差分取得

`--staged` → `git diff --cached [--name-only]`、それ以外 → `git diff <range> [--name-only]` で `changed_files`（ファイル一覧）と `diff_content`（全差分）を取得する。

**ファイル一覧が空の場合** → 「No changes found in the specified scope」と報告して終了。

## Phase 2: Parallel Review (7+1 perspectives)

6つの Agent 観点を `iterations` 回ずつ、simplify ×1（`codex_enabled` 時は Codex ×1 を追加）で **並列** 起動する。合計エージェント数: 6 × iterations + 1 (simplify) + (codex ? 1 : 0)。すべて `run_in_background: true` を使用し、結果を収集する。

### 2-1. simplify

Skill tool で `/simplify` を invoke する。引数にスコープ情報を渡す:
- `--staged` の場合: `args: "--staged"`
- `--branch` の場合: `args: "--branch"`
- commit range の場合: `args: "<range>"`
- 引数なしの場合: `args` なし（デフォルト動作）

simplify は独自のフォーマットで結果を返す。テキストとして受け取り、Phase 3 で手動パースする。

simplify は Skill invoke のため N-way 投票の対象外。`iterations` の値に関わらず 1 回のみ実行する。

### 2-2 ~ 2-7. code-review-quality / code-review-security / code-review-performance / code-review-test / code-review-ai-antipattern / code-review-impact

各エージェントに対して Agent tool を使用する。`subagent_type` にエージェント名（`code-review-quality`, `code-review-security`, `code-review-performance`, `code-review-test`, `code-review-ai-antipattern`, `code-review-impact`）を指定し、prompt に `changed_files` と `diff_content` を含め、findings を JSON で返すよう指示する。

`code-review-impact` エージェントには、設計書の Impact Analysis セクション（存在する場合）も追加コンテキストとして渡す。設計書パスは feature-dev パイプラインから `artifacts.design_doc` で伝播される。設計書が見つからない場合は Impact Analysis コンテキストなしで起動する（Must-Verify 消化チェックはスキップされる）。

`iterations > 1` の場合、各エージェント（code-review-quality, code-review-security, code-review-performance, code-review-test, code-review-ai-antipattern, code-review-impact）について、同一の prompt で `iterations` 回起動する。各イテレーションは独立した Agent tool 呼び出しとし、全て `run_in_background: true` で並列起動する。

### 2-7. Codex レビュー（`codex_enabled` 時のみ）

`codex_enabled` が true の場合のみ実行する。Bash tool を `run_in_background: true` で呼び出す。

```bash
node "/Users/nishikataseiichi/.claude/plugins/cache/openai-codex/codex/1.0.1/scripts/codex-companion.mjs" \
  review --wait <scope_flag>
```

| スコープ | `<scope_flag>` |
|---------|----------------|
| `--staged` | `--scope working-tree` |
| `--branch` | `--scope branch` |
| commit range | `--scope auto` |
| デフォルト | `--scope auto` |

Bash 実行が失敗した場合は「Codex への接続に失敗しました。--codex をスキップします。」と警告し、`codex_enabled` を false に変更して続行する。

Codex の出力はフリーテキスト形式。

Codex は N-way 投票の対象外。`iterations` の値に関わらず 1 回のみ実行する。

### 結果収集

すべて（7つ、または `codex_enabled` 時は8つ）の完了を待つ。いずれかのエージェントがエラーを返した場合:
- エラー内容をログに記録する
- そのエージェントの findings は空として扱い、レポートに「[category] エージェントエラー: <概要>」と注記する
- 他のエージェントの結果は正常に処理を続ける

各エージェント（simplify 以外）の応答から JSON `{"findings": [...]}` をパースする。失敗した場合は正規表現フォールバックを試み、それでも失敗ならエラーとして扱う。

Codex の出力はフリーテキストの可能性がある。JSON `{"findings": [...]}` のパースを試み、失敗した場合は simplify と同様にテキストから個別の指摘事項を抽出し、category `"codex"` で正規化する。

## Phase 2.5: Consensus Vote（`iterations > 1` の場合のみ）

`iterations == 1` の場合、本 Phase をスキップし Phase 3 へ進む。

**開始時アナウンス:** 「Phase 2.5: Consensus Vote (iterations=N)」

### 投票アルゴリズム

観点ごとに以下を実行する:

1. **基準イテレーション選択**: findings 数が最多のイテレーションを基準（base）とする
2. **投票**: base の各 finding について、他イテレーションに意味的に同一の finding があるかチェックする。`vote_count` が `ceil(iterations / 2)` 以上なら `consensus = true`
3. **補完**: base にないが他イテレーション間で過半数一致する finding を追加採用する

### Semantic Similarity 判定

2つの findings が「同じ問題を指摘している」かの判定基準:

1. **同一 file**: findings の `file` フィールドが一致する
2. **近接 line**: findings の `line` が近い（差 ±10 行以内）、または同一関数内
3. **意味的類似**: description の核心（何が問題か）が一致する。完全一致は不要
4. **severity は不問**: 同じ問題でも severity が異なることがある。consensus に入った場合は最も高い severity を採用する

判定はメインエージェント（スキル実行者）自身が行う。findings は構造化 JSON で返されるため、file の一致で候補を絞り、line の近接度と description を比較する。

### エラーハンドリング

| 状態 | 処理 |
|------|------|
| 成功イテレーション >= 2 | 成功分のみで投票（過半数基準は成功数ベース） |
| 成功イテレーション == 1 | 投票不可。フォールバック: 単一結果をそのまま使用。ユーザーに警告表示 |
| 成功イテレーション == 0 | 全失敗。既存のエラーハンドリングに移行 |
| findings 0 件のイテレーション | 「問題なし」と投票したとみなす。他の finding の vote_count は下がる |
| consensus_findings が 0 件 | レビュー「合格」として Phase 3 へ進む |

### 出力

consensus_findings を Phase 3 に渡す。各 finding に `vote_count` フィールドを付与する。simplify の findings は投票対象外のため、そのまま Phase 3 に渡す。

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
1. [category] file:line — description
   suggestion: ...

### Medium
2. [category] file:line — description
   suggestion: ...

### Low
3. [category] file:line — description
   suggestion: ...

---
対応する指摘番号を選択してください（例: 1,2,4 / all / none）
```

`iterations > 1` の場合、各 finding に vote count を付記する: `(N/N votes)`。simplify の findings には vote count を表示しない。`iterations == 1` の場合は vote count を表示しない。

findings が 0 件の場合 → 「指摘事項はありません。レビュー完了です。」と報告して終了する。

### ユーザー選択

AskUserQuestion ツールを使用してユーザーの選択を取得する。受け付ける入力:
- `none` → 「レビュー完了です。修正は行いません。」と報告して終了
- `all` → 全 findings を Phase 4 に渡す
- カンマ区切りの番号（例: `1,2,4`） → 該当番号の findings を Phase 4 に渡す
- 範囲指定（例: `1-3`） → 展開して処理

## Phase 4: Approve & Fix

ユーザーが選択した findings を修正する。

### category 別の修正方法

**simplify findings の場合:**
Skill tool で `/simplify` を再度 invoke し、対象ファイルを明示的に指定する。

**その他の findings (quality, security, performance, test, ai-antipattern, impact, codex) の場合:**
指摘内容と suggestion に基づき、オーケストレーター自身が直接修正を実装する。修正手順:
1. 選択された findings を重複除去し、1つの修正ブリーフに正規化する
2. 対象ファイルを Read で読み込む
3. finding の description と suggestion を参照して修正内容を決定する
4. Edit で修正を適用する
5. 同一ファイルに複数の findings がある場合は行番号の大きい方から修正する（行ずれ防止）

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
| 2 | Codex (companion.mjs) 実行失敗 | 警告表示し Codex なしで続行 |
| 2 | Codex 出力パース失敗 | 生テキストをそのまま codex カテゴリで正規化 |
| 3 | ユーザー入力が不正 | 再入力を求める |
| 4 | ファイル/行番号不正 | スキップして次の finding へ |
| 5 | テスト/linter 失敗 | 修正提案、最大2回リトライ |

## Red Flags

**Never:**
- ユーザー承認なしに修正を適用する
- レビュー対象外のファイルを変更する
- findings を勝手にフィルタリング・省略する（全件レポートする）
- iterations > 1 で consensus 投票結果を無視する
- テスト失敗を無視して完了とする

**Always:**
- Phase 遷移時にアナウンスする
- 全エージェント（ai-antipattern 含む。`--codex` 指定時は Codex も含む）の結果を待ってからレポートする
- 修正前にユーザーの選択を得る
- 修正後に検証を実行する
