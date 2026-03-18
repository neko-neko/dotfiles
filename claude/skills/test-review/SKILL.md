---
name: test-review
description: >-
  E2E観点でのテストレビューワークフロー。3つの観点（coverage, quality, design-alignment）で
  テストコードを並列レビューし、統合レポートから承認された指摘を修正する。
  --design 指定時は設計書も加味する。
  --codex 指定時は MCP Codex による並列レビューとメタレビューを追加する。
  --iterations N 指定時は各観点を N 回独立レビューし、過半数一致の findings のみ採用する（デフォルト: 3）。
user-invocable: true
---

# Test Review Orchestrator

3つの観点でテストコードを並列レビューし、統合レポートを生成する。ユーザーが承認した指摘のみを修正し、テストスイートで検証する。

**開始時アナウンス:** 「Test Review を開始します。Phase 1: Scope Detection」

## Phase 1: Scope Detection

引数を解析し、レビュー対象の差分を取得する。

### 引数パース

| 引数 | 効果 |
|------|------|
| (なし) | diff 範囲: `HEAD~1..HEAD` |
| `--branch` | diff 範囲: `$(git merge-base HEAD main)..HEAD` (`main` がなければ `master` にフォールバック) |
| `--staged` | diff 範囲: staged changes (`git diff --cached`) |
| その他の値 | そのまま git commit range として使用 |
| `--design <path>` | 設計書パスを指定。`test-review-design-alignment` エージェントに渡す。他の引数と組み合わせ可能 |
| `--codex` | Phase 2 に Codex 並列実行を追加し、Phase 3.5 メタレビューを有効化する。他の引数と組み合わせ可能 |
| `--iterations N` | N-way 投票を有効化する（デフォルト: 3）。各観点エージェントを N 回独立に起動し、過半数一致の findings のみ採用する。他の引数と組み合わせ可能 |

`--design` と `--codex` は他の引数（`--branch`, `--staged`, commit range）と組み合わせて使用できる。`--design <path>` が指定された場合、パスの存在を `test -f` で検証する。存在しなければ「指定された設計書が見つかりません: <path>。設計書なしモードで続行します。」と警告し、`design_doc_path` を空にする。存在すれば変数 `design_doc_path` にパスを格納し、Phase 2 で `test-review-design-alignment` エージェントに渡す。`--codex` が指定された場合、変数 `codex_enabled` を true とし、Phase 2 と Phase 3.5 で参照する。

`--iterations N` が指定された場合、変数 `iterations` に N を格納する。未指定の場合 `iterations = 3`（デフォルト）。`iterations < 1` の場合は `1` に補正する。`iterations == 1` の場合、Phase 2.5 をスキップし従来動作と同一になる。

### 差分取得

`--staged` → `git diff --cached [--name-only]`、それ以外 → `git diff <range> [--name-only]` で `changed_files`（ファイル一覧）と `diff_content`（全差分）を取得する。

**ファイル一覧が空の場合** → 「No changes found in the specified scope」と報告して終了。

## Phase 2: Parallel Review (3+1 perspectives)

3つの観点を `iterations` 回ずつ（`codex_enabled` 時は Codex ×1 を追加）で **並列** 起動する。合計エージェント数: 3 × iterations + (codex ? 1 : 0)。すべて `run_in_background: true` を使用し、結果を収集する。

### 2-1. test-review-coverage

Agent tool を使用する。`subagent_type` に `test-review-coverage` を指定し、prompt に `changed_files` と `diff_content` を含め、findings を JSON で返すよう指示する。

`iterations > 1` の場合、同一の prompt で `iterations` 回起動する。各イテレーションは独立した Agent tool 呼び出しとし、全て `run_in_background: true` で並列起動する。

レビュー観点:
- テストケースの網羅性（正常系・異常系・境界値）
- 未テストのコードパス・分岐の検出
- E2E シナリオの抜け漏れ
- テスト対象の変更に対するテストの追従状況

### 2-2. test-review-quality

Agent tool を使用する。`subagent_type` に `test-review-quality` を指定し、prompt に `changed_files` と `diff_content` を含め、findings を JSON で返すよう指示する。

`iterations > 1` の場合、同一の prompt で `iterations` 回起動する。各イテレーションは独立した Agent tool 呼び出しとし、全て `run_in_background: true` で並列起動する。

レビュー観点:
- テストの可読性・保守性
- テストの独立性（他テストへの依存、実行順序依存）
- アサーションの適切性（曖昧なアサーション、過剰・過少な検証）
- テストデータの管理（ハードコード、フィクスチャの適切性）
- フレイキーテストのリスク（タイミング依存、外部依存）
- テスト命名規則の一貫性

### 2-3. test-review-design-alignment

Agent tool を使用する。`subagent_type` に `test-review-design-alignment` を指定し、prompt に `changed_files` と `diff_content` を含め、`requirement_map` と findings を JSON で返すよう指示する。`design_doc_path` が設定されている場合は prompt に含める。

`iterations > 1` の場合、同一の prompt で `iterations` 回起動する。各イテレーションは独立した Agent tool 呼び出しとし、全て `run_in_background: true` で並列起動する。`requirement_map` は投票対象外。N 回のイテレーション中、最も詳細な `requirement_map`（エントリ数が最多のもの）を Phase 3 で使用する。

レビュー観点:
- 設計要件・実装ロジックとテストケースの整合性
- ユースケース/要件ごとのテスト存在チェック（マッピング表）
- 設計要件・業務制約に由来するエラーパスのテスト漏れ（一般的なコードパスカバレッジは test-review-coverage の範囲）
- 業務制約のテスト検証

### 2-4. Codex レビュー（`codex_enabled` 時のみ）

`codex_enabled` が true の場合のみ実行する。`mcp__codex__codex` ツールを `run_in_background: true` で呼び出す。

共通パターンは Read tool で `./references/mcp-codex-patterns.md`（このスキルのディレクトリからの相対パス）を読み込み、 のパターン2（コードレビュー）を参照。

diff はプロンプトに埋め込まず、Codex 自身に git diff コマンドを実行させる。

```yaml
tool: mcp__codex__codex
params:
  prompt: |
    <スコープに応じた指示（下表参照）>
    変更内容をレビューし、問題点を指摘してください。
  sandbox: "read-only"
  approval-policy: "on-failure"
  cwd: <作業ディレクトリ>
```

| スコープ | プロンプト指示 |
|---------|--------------|
| `--staged` | 「`git diff --cached` を実行し、ステージ済みの変更をレビューしてください」 |
| `--branch` | 「`git diff $(git merge-base HEAD <base_branch>)..HEAD` を実行し、ブランチの全変更をレビューしてください」 |
| commit range | 「`git diff <range>` を実行し、指定範囲の変更をレビューしてください」 |
| デフォルト | 「`git diff HEAD~1..HEAD` を実行し、最新コミットの変更をレビューしてください」 |

レスポンスから `threadId` を保持し、Phase 3.5 のメタレビューで使用する。

MCP 呼び出しが失敗した場合は「MCP Codex への接続に失敗しました。--codex をスキップします。」と警告し、`codex_enabled` を false に変更して続行する。

Codex の出力はフリーテキスト形式。

Codex は N-way 投票の対象外。`iterations` の値に関わらず 1 回のみ実行する。

### Trace 記録（Phase 2 エージェントトレース）

各エージェント起動時に trace を記録する。handover セッションディレクトリが存在する場合のみ実行する。

1. Bash で handover ディレクトリを解決する:
   ```bash
   source ~/.dotfiles/claude/skills/handover/scripts/trace-lib.sh
   source ~/.dotfiles/claude/skills/handover/scripts/handover-lib.sh
   TRACE_FILE=$(_trace_resolve_path "$(find_active_session_dir 2>/dev/null || echo '')")
   echo "$TRACE_FILE"
   ```
   ディレクトリが空文字の場合、trace 記録をスキップする。

2. 各 Agent tool 呼び出し前に `agent_start_time=$(date +%s%3N)` を記録する（Bash で実行）

3. 各エージェントの結果受信後、以下を Bash で実行:
   ```bash
   source ~/.dotfiles/claude/skills/handover/scripts/trace-lib.sh
   TRACE_SESSION_ID="${SESSION_ID:-unknown}"
   duration_ms=$(( $(date +%s%3N) - agent_start_time ))
   trace_agent_end "$TRACE_FILE" "test-review" "<agent_name>" 2 $duration_ms <findings_count> "<parse_method>" "<iteration_number>"
   ```

4. エージェントエラー時は `trace_error` を呼ぶ:
   ```bash
   trace_error "$TRACE_FILE" "test-review" "<agent_name>" "<error_type>" "<message>"
   ```

### 結果収集

すべて（3つ、または `codex_enabled` 時は4つ）の完了を待つ。いずれかのエージェントがエラーを返した場合:
- エラー内容をログに記録する
- そのエージェントの findings は空として扱い、レポートに「[category] エージェントエラー: <概要>」と注記する
- 他のエージェントの結果は正常に処理を続ける

test-review-coverage、test-review-quality の応答から JSON `{"findings": [...]}` をパースする。失敗した場合は正規表現フォールバックを試み、それでも失敗ならエラーとして扱う。

test-review-design-alignment の応答から JSON `{"requirement_map": [...], "findings": [...]}` をパースする。`requirement_map` は Phase 3 のレポートで使用する。`findings` は他エージェントの findings と統合する。パース失敗時は正規表現フォールバックを試み、それでも失敗ならエラーとして扱う。

Codex の出力はフリーテキストの可能性がある。JSON `{"findings": [...]}` のパースを試み、失敗した場合はテキストから個別の指摘事項を抽出し、category `"codex"` で正規化する。

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

consensus_findings を Phase 3 に渡す。各 finding に `vote_count` フィールドを付与する。

### Trace 記録

```bash
source ~/.dotfiles/claude/skills/handover/scripts/trace-lib.sh
TRACE_SESSION_ID="${SESSION_ID:-unknown}"
trace_consensus "$TRACE_FILE" "test-review" "<perspective>" <iterations> <total_findings> <consensus_count> <rejected_count> '<rejection_reasons_json>'
```

## Phase 3: Report

### マージとソート

全エージェントの findings を1つのリストに統合する。各 finding は以下のフォーマットに正規化する:

```json
{
  "file": "path/to/file",
  "line": 0,
  "severity": "medium",
  "category": "test-coverage | test-quality | test-design-alignment",
  "description": "指摘内容",
  "suggestion": "改善案"
}
```

severity で降順ソート: high > medium > low

### レポート出力

```
## Test Review Report (scope: <scope_description>)

### Requirement Map
| # | Requirement | Source | Test | Gap |
|---|-------------|--------|------|-----|
| 1 | ユースケース説明 | design | test_xxx | -- |
| 2 | ユースケース説明 | implementation | -- | テスト未作成 |

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

Requirement Map は `test-review-design-alignment` の `requirement_map` から生成する。Test 列には `test_name` を表示する（`test_file` は省略）。エージェントエラーで `requirement_map` が取得できなかった場合はこのセクションを省略する。マッピング表は情報提示のみで、findings の番号振り・ユーザー選択の対象外。

`iterations > 1` の場合、各 finding に vote count を付記する: `(N/N votes)`。`iterations == 1` の場合は vote count を表示しない。

findings が 0 件の場合 → 「指摘事項はありません。テストレビュー完了です。」と報告して終了する。

### Phase 3.5: Meta Review（`codex_enabled` 時のみ）

`codex_enabled` が true の場合のみ実行する。Phase 3 で生成したレポートと diff を Codex に渡し、メタレビューを実行する。

**開始時アナウンス:** 「Phase 3.5: Codex Meta Review」

#### 実行

`mcp__codex__codex-reply` ツールで Phase 2 の Codex セッションを継続する。共通パターンは Read tool で `./references/mcp-codex-patterns.md`（このスキルのディレクトリからの相対パス）を読み込み、 のパターン3（メタレビュー）を参照。

```yaml
tool: mcp__codex__codex-reply
params:
  threadId: <Phase 2 で取得した threadId>
  prompt: |
    先ほどのレビュー結果を踏まえ、以下の2つの観点で分析してください。

    ## 観点1: 見落とし検出
    レビューレポートに含まれていないテストの問題があれば指摘してください。

    ## 観点2: False Positive 検証
    レビューレポートの各 finding が正当かどうか検証してください。
    false positive の疑いがあるものを指摘してください。

    ## Test Review Report
    <Phase 3 で生成したレポート全文>
```

diff は Codex が Phase 2 で既に取得済みなのでプロンプトに含めない。`threadId` が取得できなかった場合はメタレビューをスキップする。

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

- `mcp__codex__codex-reply` が失敗またはタイムアウトした場合 → 「Codex メタレビューをスキップします」と表示し、Phase 3 のレポートのみで続行する
- 出力パースが失敗した場合 → Codex の生テキストをそのまま「Meta Review (by Codex)」セクションに表示する

### ユーザー選択

AskUserQuestion ツールを使用してユーザーの選択を取得する。受け付ける入力:
- `none` → 「テストレビュー完了です。修正は行いません。」と報告して終了
- `all` → 全 findings を Phase 4 に渡す
- カンマ区切りの番号（例: `1,2,4`） → 該当番号の findings を Phase 4 に渡す
- 範囲指定（例: `1-3`） → 展開して処理

### Trace 記録（ユーザー判断）

ユーザーの選択が確定したら、findings の全件スナップショットとともに trace を記録する。

1. findings 全件を JSON 配列に変換する。各 finding に `selected: true/false` を付与:
   ```json
   [
     {"index": 1, "severity": "high", "category": "test-coverage", "description": "...", "selected": true},
     {"index": 2, "severity": "medium", "category": "test-quality", "description": "...", "selected": false}
   ]
   ```

2. Bash で trace を書き込む:
   ```bash
   source ~/.dotfiles/claude/skills/handover/scripts/trace-lib.sh
   TRACE_SESSION_ID="${SESSION_ID:-unknown}"
   trace_user_decision "$TRACE_FILE" "test-review" <total_findings> '<selected_json>' '<rejected_json>' '<snapshot_json>'
   ```

`none` が選択された場合も記録する（`selected: []`, `rejected: [全番号]`）。

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
- **test-design-alignment findings:** 設計要件・実装ロジックに基づくテストケースの追加。ユースケースの抜け漏れ補完、業務制約の検証追加
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
| 1 | `--design` のパスが存在しない | 警告表示し、設計書なしモードで続行 |
| 2 | MCP Codex 接続失敗 | 警告表示し Codex なしで続行 |
| 2 | `mcp__codex__codex` タイムアウト/失敗 | 該当結果を空として続行 |
| 3 | ユーザー入力が不正 | 再入力を求める |
| 3.5 | `mcp__codex__codex-reply` 失敗 | メタレビューをスキップし Phase 3 レポートで続行 |
| 3.5 | 出力パース失敗 | 生テキストをそのまま表示 |
| 4 | ファイル/行番号不正 | スキップして次の finding へ |
| 5 | テスト失敗 | 修正提案、最大2回リトライ |

## Red Flags

**Never:**
- ユーザー承認なしに修正を適用する
- レビュー対象外のファイルを変更する
- findings を勝手にフィルタリング・省略する（全件レポートする）
- テスト失敗を無視して完了とする
- iterations > 1 で consensus 投票結果を無視する

**Always:**
- Phase 遷移時にアナウンスする
- 全エージェント（`--codex` 指定時は Codex 含む）の結果を待ってからレポートする
- 修正前にユーザーの選択を得る
- 修正後にテストスイートを実行して検証する
