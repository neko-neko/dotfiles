---
name: test-review
description: >-
  E2E観点でのテストレビューワークフロー。2つの観点（coverage, quality）で
  テストコードを並列レビューし、統合レポートから承認された指摘を修正する。
  --codex 指定時は Codex CLI によるメタレビューを追加する。
user-invocable: true
---

# Test Review Orchestrator

2つの観点でテストコードを並列レビューし、統合レポートを生成する。ユーザーが承認した指摘のみを修正し、テストスイートで検証する。

**開始時アナウンス:** 「Test Review を開始します。Phase 1: Scope Detection」

## Phase 1: Scope Detection

引数を解析し、レビュー対象の差分を取得する。

### 引数パース

| 引数 | diff 範囲 |
|------|----------|
| (なし) | `HEAD~1..HEAD` |
| `--branch` | `$(git merge-base HEAD main)..HEAD` (`main` がなければ `master` にフォールバック) |
| `--staged` | staged changes (`git diff --cached`) |
| その他の値 | そのまま git commit range として使用 |
| `--codex` | Phase 2 に Codex 並列実行を追加し、Phase 3.5 メタレビューを有効化する。他の引数と組み合わせ可能 |

`--codex` は他の引数（`--branch`, `--staged`, commit range）と組み合わせて使用できる。`--codex` が指定された場合、変数 `codex_enabled` を true とし、Phase 2 と Phase 3.5 で参照する。`--codex` が指定されていない場合、従来通り2観点のみでレビューする。

### 差分取得

`--staged` → `git diff --cached [--name-only]`、それ以外 → `git diff <range> [--name-only]` で `changed_files`（ファイル一覧）と `diff_content`（全差分）を取得する。

**ファイル一覧が空の場合** → 「No changes found in the specified scope」と報告して終了。

## Phase 2: Parallel Review (2+1 perspectives)

2つ（`codex_enabled` が true の場合は3つ）のレビューを **並列** で起動する。すべて `run_in_background: true` を使用し、結果を収集する。

### 2-1. test-review-coverage

Agent tool を使用する。`subagent_type` に `test-review-coverage` を指定し、prompt に `changed_files` と `diff_content` を含め、findings を JSON で返すよう指示する。

レビュー観点:
- テストケースの網羅性（正常系・異常系・境界値）
- 未テストのコードパス・分岐の検出
- E2E シナリオの抜け漏れ
- テスト対象の変更に対するテストの追従状況

### 2-2. test-review-quality

Agent tool を使用する。`subagent_type` に `test-review-quality` を指定し、prompt に `changed_files` と `diff_content` を含め、findings を JSON で返すよう指示する。

レビュー観点:
- テストの可読性・保守性
- テストの独立性（他テストへの依存、実行順序依存）
- アサーションの適切性（曖昧なアサーション、過剰・過少な検証）
- テストデータの管理（ハードコード、フィクスチャの適切性）
- フレイキーテストのリスク（タイミング依存、外部依存）
- テスト命名規則の一貫性

### 2-3. codex review（`codex_enabled` 時のみ）

`codex_enabled` が true の場合のみ実行する。Bash ツールで `run_in_background: true` を使用して `codex review` を実行する。

**実行前チェック:** `which codex` でコマンドの存在を確認する。存在しない場合は「codex コマンドが見つかりません。--codex をスキップします。」と警告し、`codex_enabled` を false に変更して続行する。

コマンドは diff スコープに応じて分岐する。**注意:** Codex CLI はスコープフラグとカスタムプロンプトを併用できないため、ビルトインのレビュー機能をそのまま使用する。

| スコープ | コマンド |
|---------|---------|
| `--staged` | `codex review --uncommitted` |
| `--branch` | `codex review --base <base_branch>` |
| commit range / デフォルト | `codex review --commit <sha>` |

Codex はビルトインで diff の取得・解析・レビューを行う。出力はフリーテキスト形式。

### 結果収集

すべて（2つ、または `codex_enabled` 時は3つ）の完了を待つ。いずれかのエージェントがエラーを返した場合:
- エラー内容をログに記録する
- そのエージェントの findings は空として扱い、レポートに「[category] エージェントエラー: <概要>」と注記する
- 他のエージェントの結果は正常に処理を続ける

各エージェントの応答から JSON `{"findings": [...]}` をパースする。失敗した場合は正規表現フォールバックを試み、それでも失敗ならエラーとして扱う。

codex review の出力はフリーテキストの可能性がある。JSON `{"findings": [...]}` のパースを試み、失敗した場合はテキストから個別の指摘事項を抽出し、category `"codex"` で正規化する。

## Phase 3: Report

### マージとソート

全エージェントの findings を1つのリストに統合する。各 finding は以下のフォーマットに正規化する:

```json
{
  "file": "path/to/file",
  "line": 0,
  "severity": "medium",
  "category": "test-coverage | test-quality",
  "description": "指摘内容",
  "suggestion": "改善案"
}
```

severity で降順ソート: high > medium > low

### レポート出力

```
## Test Review Report (scope: <scope_description>)

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

findings が 0 件の場合 → 「指摘事項はありません。テストレビュー完了です。」と報告して終了する。

### Phase 3.5: Meta Review（`codex_enabled` 時のみ）

`codex_enabled` が true の場合のみ実行する。Phase 3 で生成したレポートと diff を Codex に渡し、メタレビューを実行する。

**開始時アナウンス:** 「Phase 3.5: Codex Meta Review」

#### 実行

Bash ツールで `codex exec` を実行する（タイムアウト: 5分）:

```bash
codex exec "以下のテストレビューレポートと差分を確認し、2つの観点で分析してください。

## 観点1: 見落とし検出
レビューレポートに含まれていないテストの問題があれば指摘してください。

## 観点2: False Positive 検証
レビューレポートの各 finding が正当かどうか検証してください。false positive の疑いがあるものを指摘してください。

## Test Review Report
<Phase 3 で生成したレポート全文>

## Diff
<diff_content>"
```

#### 結果の統合

Codex の出力をパースし、レポートに以下を追記する:

```
### Meta Review (by Codex)
#### Additional Findings
N+1. [codex-meta] file:line — description
     suggestion: ...

#### False Positive Suspects
- Finding #N: reason
```

追加 findings はユーザーの選択対象に含める（番号を既存 findings の続きから振る）。false positive 指摘は参考情報として表示するのみ（自動除外しない）。

#### エラー時

- `codex exec` が失敗またはタイムアウトした場合 → 「Codex メタレビューをスキップします」と表示し、Phase 3 のレポートのみで続行する
- 出力パースが失敗した場合 → Codex の生テキストをそのまま「Meta Review (by Codex)」セクションに表示する

### ユーザー選択

AskUserQuestion ツールを使用してユーザーの選択を取得する。受け付ける入力:
- `none` → 「テストレビュー完了です。修正は行いません。」と報告して終了
- `all` → 全 findings を Phase 4 に渡す
- カンマ区切りの番号（例: `1,2,4`） → 該当番号の findings を Phase 4 に渡す
- 範囲指定（例: `1-3`） → 展開して処理

## Phase 4: Approve & Fix

ユーザーが選択した findings に基づき、テストコードを修正する。

### 修正方法

指摘内容と suggestion に基づき、オーケストレーター自身が直接修正を実装する。修正手順:
1. 対象ファイルを Read で読み込む
2. finding の description と suggestion を参照して修正内容を決定する
3. Edit で修正を適用する
4. 同一ファイルに複数の findings がある場合は行番号の大きい方から修正する（行ずれ防止）

### 修正の種類

- **test-coverage findings:** テストケースの追加・拡充（正常系・異常系・境界値の補完）
- **test-quality findings:** 既存テストの改善（アサーション強化、テストデータ整理、命名修正、フレイキーテスト対策）
- **codex / codex-meta findings:** 指摘内容に応じてテストコードを追加・修正・削除

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

### テストスイート実行

プロジェクトのテストコマンドを自動検出して実行する:

| 検出ファイル | テストコマンド |
|-------------|---------------|
| `package.json` | `npm test` |
| `Makefile` | `make test` |
| `Cargo.toml` | `cargo test` |
| `pyproject.toml` / `setup.py` | `pytest` |
| `go.mod` | `go test ./...` |

検出できない場合 → 「テストコマンドが検出できませんでした。手動で確認してください。」

### 結果報告

```
## Verification Results

- git diff: <変更ファイル数> files changed
- tests: PASS / FAIL (詳細)
```

テストが失敗した場合:
- 失敗内容を表示する
- 「修正を試みますか？」とユーザーに確認する
- 承認された場合、失敗を修正して再度検証する（最大2回）
- 2回修正しても失敗する場合 → 「手動対応が必要です」と報告して終了

全て成功した場合 → 「テストレビュー完了。全検証パスしました。」と報告して終了する。

## Error Handling

| フェーズ | エラー | リカバリ |
|---------|--------|---------|
| 1 | git diff 失敗 | コミット範囲を確認するようユーザーに報告 |
| 1 | merge-base 失敗 | main/master どちらも存在しない旨を報告 |
| 2 | エージェントタイムアウト | 該当エージェント結果を空として続行 |
| 2 | JSON パース失敗 | 正規表現フォールバック、それでも失敗なら空 |
| 2 | `codex` コマンド未インストール | 警告表示し Codex なしで続行 |
| 2 | `codex review` タイムアウト/失敗 | 該当結果を空として続行 |
| 3 | ユーザー入力が不正 | 再入力を求める |
| 3.5 | `codex exec` 失敗 | メタレビューをスキップし Phase 3 レポートで続行 |
| 3.5 | 出力パース失敗 | 生テキストをそのまま表示 |
| 4 | ファイル/行番号不正 | スキップして次の finding へ |
| 5 | テスト失敗 | 修正提案、最大2回リトライ |

## Red Flags

**Never:**
- ユーザー承認なしに修正を適用する
- レビュー対象外のファイルを変更する
- findings を勝手にフィルタリング・省略する（全件レポートする）
- テスト失敗を無視して完了とする

**Always:**
- Phase 遷移時にアナウンスする
- 全エージェント（`--codex` 指定時は Codex 含む）の結果を待ってからレポートする
- 修正前にユーザーの選択を得る
- 修正後にテストスイートを実行して検証する
