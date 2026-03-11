---
name: spec-review
description: >-
  設計書レビューワークフロー。4つの観点（requirements, design-judgment, feasibility, consistency）で
  設計書を並列レビューし、統合レポートから承認された指摘を修正する。
  --codex 指定時は MCP Codex によるレビューとメタレビューを追加する。
user-invocable: true
---

# Spec Review Orchestrator

4つの観点で設計書を並列レビューし、統合レポートを生成する。ユーザーが承認した指摘のみを設計書に反映する。

**開始時アナウンス:** 「Spec Review を開始します。Phase 1: Scope Detection」

## Phase 1: Scope Detection

引数を解析し、レビュー対象の設計書を特定する。

### 引数パース

| 引数 | 動作 |
|------|------|
| (なし) | `docs/plans/*-design.md` から最終更新日時が最新のファイルを自動検出 |
| `<path>` | 指定されたパスの設計書を使用 |
| `--codex` | Phase 2 に Codex 並列実行を追加し、Phase 3.5 メタレビューを有効化する。パス引数と組み合わせ可能 |
| `--ui` | Phase 2 に UI 設計レビューエージェントを追加する。パス引数・`--codex` と組み合わせ可能 |

`--codex` はパス引数と組み合わせて使用できる。`--codex` が指定された場合、変数 `codex_enabled` を true とし、Phase 2 と Phase 3.5 で参照する。`--codex` が指定されていない場合、4観点のみでレビューする。

`--ui` が指定された場合、変数 `ui_enabled` を true とし、Phase 2 で参照する。

### 設計書取得

自動検出の場合、Bash ツールで以下を実行する:

```bash
ls -t docs/plans/*-design.md | head -1
```

検出されたファイル、または引数で指定されたファイルを Read で読み込み、`doc_path`（ファイルパス）と `doc_content`（全文）を取得する。

**ファイルが見つからない場合** → 「No design document found in the specified scope」と報告して終了。

## Phase 2: Parallel Review (4+1+ui perspectives)

4つ（`codex_enabled` 時は+1、`ui_enabled` 時はさらに+1）のレビューを **並列** で起動する。すべて `run_in_background: true` を使用し、結果を収集する。

### 2-1. spec-review-requirements

Agent tool を使用する。`subagent_type` に `spec-review-requirements` を指定し、prompt に `doc_path` と `doc_content` を含め、以下の観点でレビューさせる:

- 要件・ゴールが実装可能かつ検証可能なレベルまで具体化されているか
- 設計書が暗黙に前提としている業務ルール・制約がないか

findings を JSON で返すよう指示する。

### 2-2. spec-review-design-judgment

Agent tool を使用する。`subagent_type` に `spec-review-design-judgment` を指定し、prompt に `doc_path` と `doc_content` を含め、以下の観点でレビューさせる:

- 選択されたアプローチの判断根拠が十分か
- 設計が要件を充足するか（正常系・エッジケース・異常系）

findings を JSON で返すよう指示する。

### 2-3. spec-review-feasibility

Agent tool を使用する。`subagent_type` に `spec-review-feasibility` を指定し、prompt に `doc_path` と `doc_content` を含め、以下の観点でレビューさせる:

- 技術的に実現困難な設計
- パフォーマンス・スケーラビリティ上の懸念
- 依存関係の不整合
- 見積もりの妥当性

findings を JSON で返すよう指示する。

### 2-4. spec-review-consistency

Agent tool を使用する。`subagent_type` に `spec-review-consistency` を指定し、prompt に `doc_path` と `doc_content` を含め、以下の観点でレビューさせる:

- セクション間の矛盾
- 用語の不統一
- 図表と本文の不一致
- 既存の設計・アーキテクチャとの矛盾（プロジェクト内の関連ファイルを参照）
- 設計変更の影響範囲の見落とし（呼び出し元・依存先・関連テーブルの調査）

findings を JSON で返すよう指示する。

### 2-5. Codex レビュー（`codex_enabled` 時のみ）

`codex_enabled` が true の場合のみ実行する。`mcp__codex__codex` ツールを `run_in_background: true` で呼び出す。

共通パターンは `references/mcp-codex-patterns.md` のパターン1（ドキュメントレビュー）を参照。

```yaml
tool: mcp__codex__codex
params:
  prompt: |
    以下の設計書をレビューしてください。技術的実現可能性、明確さ、一貫性の観点で問題点を指摘してください。

    <doc_content>
  sandbox: "read-only"
  approval-policy: "on-failure"
```

レスポンスから `threadId` を保持し、Phase 3.5 のメタレビューで使用する。

MCP 呼び出しが失敗した場合は「MCP Codex への接続に失敗しました。--codex をスキップします。」と警告し、`codex_enabled` を false に変更して続行する。

Codex の出力はフリーテキスト形式。

### 2-6. spec-review-ui-design（`ui_enabled` 時のみ）

`ui_enabled` が true の場合のみ実行する。Agent tool を使用する。`subagent_type` に `spec-review-ui-design` を指定し、prompt に `doc_path` と `doc_content` を含め、以下の観点でレビューさせる:

- UI 設計判断の妥当性（画面構成・インタラクション・状態遷移）
- 既存 UI パターン・デザインシステムとの整合

findings を JSON で返すよう指示する。

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
   trace_agent_end "$TRACE_FILE" "spec-review" "<agent_name>" 2 $duration_ms <findings_count> "<parse_method>"
   ```

4. エージェントエラー時は `trace_error` を呼ぶ:
   ```bash
   trace_error "$TRACE_FILE" "spec-review" "<agent_name>" "<error_type>" "<message>"
   ```

### 結果収集

すべて（4つ、`codex_enabled` 時は+1、`ui_enabled` 時はさらに+1）の完了を待つ。いずれかのエージェントがエラーを返した場合:
- エラー内容をログに記録する
- そのエージェントの findings は空として扱い、レポートに「[category] エージェントエラー: <概要>」と注記する
- 他のエージェントの結果は正常に処理を続ける

各エージェントの応答から JSON `{"findings": [...]}` をパースする。失敗した場合は正規表現フォールバックを試み、それでも失敗ならエラーとして扱う。

Codex の出力はフリーテキストの可能性がある。JSON `{"findings": [...]}` のパースを試み、失敗した場合はテキストから個別の指摘事項を抽出し、category `"codex"` で正規化する。

## Phase 3: Report

### マージとソート

全エージェントの findings を1つのリストに統合する。各 finding は以下のフォーマットに正規化する:

```json
{
  "section": "セクション名または行範囲",
  "severity": "high | medium | low",
  "category": "requirements | design-judgment | feasibility | consistency | codex | ui-design",
  "description": "指摘内容",
  "suggestion": "改善案"
}
```

severity で降順ソート: high > medium > low

### レポート出力

```
## Spec Review Report (target: <doc_path>)

### High
1. [category] section — description
   suggestion: ...

### Medium
2. [category] section — description
   suggestion: ...

### Low
3. [category] section — description
   suggestion: ...

---
```

findings が 0 件の場合 → 「指摘事項はありません。レビュー完了です。」と報告して終了する。

### Phase 3.5: Meta Review（`codex_enabled` 時のみ）

`codex_enabled` が true の場合のみ実行する。Phase 3 で生成したレポートと設計書を Codex に渡し、メタレビューを実行する。

**開始時アナウンス:** 「Phase 3.5: Codex Meta Review」

#### 実行

`mcp__codex__codex-reply` ツールで Phase 2 の Codex セッションを継続する。共通パターンは `references/mcp-codex-patterns.md` のパターン3（メタレビュー）を参照。

```yaml
tool: mcp__codex__codex-reply
params:
  threadId: <Phase 2 で取得した threadId>
  prompt: |
    先ほどのレビュー結果を踏まえ、以下の2つの観点で分析してください。

    ## 観点1: 見落とし検出
    レビューレポートに含まれていない問題があれば指摘してください。

    ## 観点2: False Positive 検証
    レビューレポートの各 finding が正当かどうか検証してください。
    false positive の疑いがあるものを指摘してください。

    ## Review Report
    <Phase 3 で生成したレポート全文>

    ## Design Document
    <doc_content>
```

`threadId` が取得できなかった場合（Phase 2 の Codex 失敗）はメタレビューをスキップする。

#### 結果の統合

Codex の出力をパースし、レポートに以下を追記する:

```
### Meta Review (by Codex)
#### Additional Findings
N+1. [codex-meta] section — description
     suggestion: ...

#### False Positive Suspects
- Finding #N: reason
```

追加 findings はユーザーの選択対象に含める（番号を既存 findings の続きから振る）。false positive 指摘は参考情報として表示するのみ（自動除外しない）。

#### エラー時

- `mcp__codex__codex-reply` が失敗またはタイムアウトした場合 → 「Codex メタレビューをスキップします」と表示し、Phase 3 のレポートのみで続行する
- 出力パースが失敗した場合 → Codex の生テキストをそのまま「Meta Review (by Codex)」セクションに表示する

### Phase 3.7: Dialogue（対話的解決）

Phase 3（および Phase 3.5）で生成されたレポートの findings を2グループに分類する:

| グループ | 条件 | フロー |
|---------|------|--------|
| **対話グループ** | category が `requirements` or `design-judgment`、かつ severity が `high` or `medium` | 本 Phase で対話的に解決 |
| **選択グループ** | 上記以外 | 従来通り番号選択 |

対話グループが空の場合、本 Phase をスキップしてユーザー選択に進む。

#### 対話フロー

対話グループの findings を severity 順（high → medium）に1件ずつ処理する:

1. finding の description と suggestion を提示する
2. 「この指摘について確認させてください: [finding の本質に踏み込んだ具体的な質問]」で質疑を開始する
3. ユーザーの回答に基づき、必要なら追加質問する（最大3往復）
4. 合意した解決方針を1-2文で要約し、「この方針で設計書を修正してよろしいですか？」と確認する
5. 承認された解決方針を記録し、次の finding に進む

#### 対話完了後

対話グループの全 findings が完了した後:

- 選択グループの findings がある場合 → 選択グループのみを番号付きリストで提示し、「対応する指摘番号を選択してください（例: 1,2,4 / all / none）」と案内する
- 選択グループが空の場合 → Phase 4 に進む

### ユーザー選択（選択グループ）

選択グループの findings がある場合のみ実行する。AskUserQuestion ツールを使用してユーザーの選択を取得する。受け付ける入力:
- `none` → 選択グループの findings は修正しない
- `all` → 選択グループの全 findings を Phase 4 に渡す
- カンマ区切りの番号（例: `1,2,4`） → 該当番号の findings を Phase 4 に渡す
- 範囲指定（例: `1-3`） → 展開して処理

対話グループで合意済みの findings は自動的に Phase 4 に渡す（ユーザー選択不要）。

### Trace 記録（ユーザー判断）

ユーザーの選択・対話が確定したら、findings の全件スナップショットとともに trace を記録する。

1. findings 全件を JSON 配列に変換する。各 finding に `selected: true/false` と `resolution_method: "dialogue" | "selection"` を付与:
   ```json
   [
     {"index": 1, "severity": "high", "category": "requirements", "description": "...", "selected": true, "resolution_method": "dialogue"},
     {"index": 2, "severity": "medium", "category": "feasibility", "description": "...", "selected": false, "resolution_method": "selection"}
   ]
   ```

2. Bash で trace を書き込む:
   ```bash
   source ~/.dotfiles/claude/skills/handover/scripts/trace-lib.sh
   TRACE_SESSION_ID="${SESSION_ID:-unknown}"
   trace_user_decision "$TRACE_FILE" "spec-review" <total_findings> '<selected_json>' '<rejected_json>' '<snapshot_json>'
   ```

`none` が選択された場合も記録する（`selected: []`, `rejected: [全番号]`）。

## Phase 4: Approve & Fix

ユーザーが選択した findings を設計書に反映する。

### 修正方法

ユーザーが選択・合意した findings を設計書に反映する。

#### 判定基準

- **対話グループ findings** — Phase 3.7 で合意した解決方針に基づいて修正する。suggestion ではなく合意済み解決方針を使用する
- **選択グループの自明な修正** — suggestion の内容だけで修正が完結するもの。オーケストレーターが設計書を直接修正する

#### 修正手順

1. 対象の設計書を Read で読み込む
2. finding の解決方針（対話グループ）または suggestion（選択グループ）を参照して修正内容を決定する
3. Edit で修正を適用する
4. 同一セクションに複数の findings がある場合は後方（行番号の大きい方）から修正する（行ずれ防止）

### エラー時

修正中にエラーが発生した場合（セクションが見つからない、想定と異なる構造など）:
- エラー内容をユーザーに報告する
- 該当 finding をスキップして次の finding に進む

## Phase 5: Verify

修正完了後、変更を検証する。

### 差分表示

```bash
git diff
```

変更内容をユーザーに提示する。

### 整合性チェック

設計書の修正後、以下を確認する:
- マークダウンの構文が壊れていないか
- 修正箇所が他のセクションと矛盾していないか
- frontmatter が正しく保たれているか

### 結果報告

```
## Verification Results

- git diff: <変更セクション数> sections modified
- markdown syntax: OK / WARN (詳細)
- cross-reference consistency: OK / WARN (詳細)
```

問題が検出された場合:
- 問題内容を表示する
- 「修正を試みますか？」とユーザーに確認する
- 承認された場合、問題を修正して再度検証する（最大2回）
- 2回修正しても問題がある場合 → 「手動対応が必要です」と報告して終了

全て問題なしの場合 → 「レビュー完了。設計書の修正が完了しました。」と報告して終了する。

## Error Handling

| フェーズ | エラー | リカバリ |
|---------|--------|---------|
| 1 | 設計書が見つからない | パスを確認するようユーザーに報告 |
| 1 | `docs/plans/` ディレクトリが存在しない | ディレクトリ構成を確認するよう報告 |
| 2 | エージェントタイムアウト | 該当エージェント結果を空として続行 |
| 2 | JSON パース失敗 | 正規表現フォールバック、それでも失敗なら空 |
| 2 | MCP Codex 接続失敗 | 警告表示し Codex なしで続行 |
| 2 | `mcp__codex__codex` タイムアウト/失敗 | 該当結果を空として続行 |
| 3 | ユーザー入力が不正 | 再入力を求める |
| 3.5 | `mcp__codex__codex-reply` 失敗 | メタレビューをスキップし Phase 3 レポートで続行 |
| 3.5 | 出力パース失敗 | 生テキストをそのまま表示 |
| 4 | セクション/構造不正 | スキップして次の finding へ |
| 5 | 整合性チェックで問題検出 | 修正提案、最大2回リトライ |

## Red Flags

**Never:**
- ユーザー承認なしに設計書を修正する
- レビュー対象外のファイルを変更する
- findings を勝手にフィルタリング・省略する（全件レポートする）
- 整合性の問題を無視して完了とする

**Always:**
- Phase 遷移時にアナウンスする
- 全エージェント（`--codex` 指定時は Codex 含む）の結果を待ってからレポートする
- 修正前にユーザーの選択を得る
- 修正後に検証を実行する
