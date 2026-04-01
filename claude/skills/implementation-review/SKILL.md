---
name: implementation-review
description: >-
  実装計画書レビューワークフロー。3つの観点（clarity, feasibility, consistency）で
  実装計画書を並列レビューし、統合レポートから承認された指摘を修正する。
  --codex 指定時は Codex (companion.mjs adversarial-review) による設計判断レビューを追加する。
  --iterations N 指定時は各観点を N 回独立レビューし、過半数一致の findings のみ採用する（デフォルト: 3）。
user-invocable: true
---

# Implementation Review Orchestrator

3つの観点で実装計画書を並列レビューし、統合レポートを生成する。ユーザーが承認した指摘のみを実装計画書に反映する。

**開始時アナウンス:** 「Implementation Review を開始します。Phase 1: Scope Detection」

## Coordinator Discipline

- 各 review agent は parallel に動かしてよいが、計画の理解責任はオーケストレーターが持つ
- 各 agent への prompt は自己完結にし、対象文書、目的、期待出力を明示する
- review findings をそのまま編集根拠にせず、重複除去・優先度整理・解決方針の正規化を行ってから修正する
- verify フェーズでは markdown の妥当性だけでなく、計画全体の整合性を見直す

## Phase 1: Scope Detection

引数を解析し、レビュー対象の実装計画書を特定する。

### 引数パース

| 引数 | 動作 |
|------|------|
| (なし) | `docs/plans/*.md`（`*-design.md` を除く）から最終更新日時が最新のファイルを自動検出 |
| `<path>` | 指定されたパスの実装計画書を使用 |
| `--codex` | Phase 2 に Codex 設計判断レビュー (adversarial-review) を追加する。パス引数と組み合わせ可能 |
| `--ui` | Phase 2 に UI タスク仕様レビューエージェントを追加する。パス引数・`--codex` と組み合わせ可能 |
| `--iterations N` | N-way 投票を有効化する（デフォルト: 3）。各観点エージェントを N 回独立に起動し、過半数一致の findings のみ採用する。パス引数・`--codex`・`--ui` と組み合わせ可能 |

`--codex` はパス引数と組み合わせて使用できる。`--codex` が指定された場合、変数 `codex_enabled` を true とし、Phase 2 で参照する。`--codex` が指定されていない場合、3観点のみでレビューする。

`--ui` が指定された場合、変数 `ui_enabled` を true とし、Phase 2 で参照する。

`--iterations N` が指定された場合、変数 `iterations` に N を格納する。未指定の場合 `iterations = 3`（デフォルト）。`iterations < 1` の場合は `1` に補正する。`iterations == 1` の場合、Phase 2.5 をスキップし従来動作と同一になる。

### 実装計画書取得

自動検出の場合、Bash ツールで以下を実行する:

```bash
ls -t docs/plans/*.md | grep -v '\-design\.md$' | head -1
```

検出されたファイル、または引数で指定されたファイルを Read で読み込み、`doc_path`（ファイルパス）と `doc_content`（全文）を取得する。

**ファイルが見つからない場合** → 「No implementation plan found in the specified scope」と報告して終了。

### 関連設計書の検出

実装計画書のファイル名から日付プレフィックス（例: `2026-03-06`）を抽出し、同じプレフィックスを持つ設計書 `docs/plans/<prefix>*-design.md` を検索する。

```bash
ls docs/plans/$(echo "$doc_path" | grep -oP '\d{4}-\d{2}-\d{2}' | head -1)*-design.md 2>/dev/null
```

見つかった場合、`design_doc_path` と `design_doc_content` を取得し、Phase 2 の consistency エージェントに追加コンテキストとして渡す。見つからない場合は設計書なしで続行する。

## Phase 2: Parallel Review (3+1+ui perspectives)

3つの観点を `iterations` 回ずつ（`codex_enabled` 時は Codex ×1、`ui_enabled` 時は UI ×1 を追加）**並列** で起動する。合計エージェント数: 3 × iterations + (codex ? 1 : 0) + (ui ? 1 : 0)。すべて `run_in_background: true` を使用し、結果を収集する。

### 2-1. implementation-review-clarity

Agent tool を使用する。`subagent_type` に `implementation-review-clarity` を指定し、prompt に `doc_path` と `doc_content` を含め、以下の観点でレビューさせる:

- 曖昧な実装手順・未定義の用語
- 矛盾する記述
- 実装者が誤解しうる箇所
- 不足しているステップ・前提条件の説明

findings を JSON で返すよう指示する。

`iterations > 1` の場合、同一の prompt で `iterations` 回起動する。各イテレーションは独立した Agent tool 呼び出しとし、全て `run_in_background: true` で並列起動する。

### 2-2. implementation-review-feasibility

Agent tool を使用する。`subagent_type` に `implementation-review-feasibility` を指定し、prompt に `doc_path` と `doc_content` を含め、以下の観点でレビューさせる:

- 技術的に実現困難な実装手順
- パフォーマンス・スケーラビリティ上の懸念
- 依存関係の不整合・バージョン互換性
- 工数見積もりの妥当性

findings を JSON で返すよう指示する。

`iterations > 1` の場合、同一の prompt で `iterations` 回起動する。各イテレーションは独立した Agent tool 呼び出しとし、全て `run_in_background: true` で並列起動する。

### 2-3. implementation-review-consistency

Agent tool を使用する。`subagent_type` に `implementation-review-consistency` を指定し、prompt に `doc_path` と `doc_content` を含め、以下の観点でレビューさせる:

- セクション間の矛盾
- 用語の不統一
- 図表と本文の不一致
- 既存の設計書・アーキテクチャとの矛盾（プロジェクト内の関連ファイルを参照）

`design_doc_path` が存在する場合、prompt に `design_doc_path` と `design_doc_content` も含め、実装計画書と設計書の間の整合性も検証させる:

- 設計書で定義された仕様が実装計画に正しく反映されているか
- 設計書の制約・要件が実装手順で考慮されているか
- 設計書と実装計画書の間で用語・命名が統一されているか

findings を JSON で返すよう指示する。

`iterations > 1` の場合、同一の prompt で `iterations` 回起動する。各イテレーションは独立した Agent tool 呼び出しとし、全て `run_in_background: true` で並列起動する。

### 2-4. Codex レビュー（`codex_enabled` 時のみ）

`codex_enabled` が true の場合のみ実行する。Bash tool を `run_in_background: true` で呼び出す。

```bash
node "/Users/nishikataseiichi/.claude/plugins/cache/openai-codex/codex/1.0.1/scripts/codex-companion.mjs" \
  adversarial-review --wait "実装計画書 ${doc_path} の設計判断と前提条件を検証してください"
```

Bash 実行が失敗した場合は「Codex への接続に失敗しました。--codex をスキップします。」と警告し、`codex_enabled` を false に変更して続行する。

Codex の出力はフリーテキスト形式。

Codex は N-way 投票の対象外。`iterations` の値に関わらず 1 回のみ実行する。

### 2-5. implementation-review-ui-spec（`ui_enabled` 時のみ）

`ui_enabled` が true の場合のみ実行する。Agent tool を使用する。`subagent_type` に `implementation-review-ui-spec` を指定し、prompt に `doc_path` と `doc_content` を含め、以下の観点でレビューさせる:

- UI タスク記述の具体性（レイアウト・コンポーネント構成・状態遷移・エラー表示）

`design_doc_path` が存在する場合、prompt に設計書の内容も含め、設計書の UI 仕様がタスクに正しく反映されているか検証させる。

findings を JSON で返すよう指示する。

UI は N-way 投票の対象外。`iterations` の値に関わらず 1 回のみ実行する。

### 結果収集

すべて（3つ、`codex_enabled` 時は+1、`ui_enabled` 時はさらに+1）の完了を待つ。いずれかのエージェントがエラーを返した場合:
- エラー内容をログに記録する
- そのエージェントの findings は空として扱い、レポートに「[category] エージェントエラー: <概要>」と注記する
- 他のエージェントの結果は正常に処理を続ける

各エージェントの応答から JSON `{"findings": [...]}` をパースする。失敗した場合は正規表現フォールバックを試み、それでも失敗ならエラーとして扱う。

Codex の出力はフリーテキストの可能性がある。JSON `{"findings": [...]}` のパースを試み、失敗した場合はテキストから個別の指摘事項を抽出し、category `"codex-adversarial"` で正規化する。

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

1. **同一 section**: findings の `section` フィールドが一致または近接する
2. **意味的類似**: description の核心（何が問題か）が一致する。完全一致は不要
3. **severity は不問**: 同じ問題でも severity が異なることがある。consensus に入った場合は最も高い severity を採用する

判定はメインエージェント（スキル実行者）自身が行う。findings は構造化 JSON で返されるため、section の一致で候補を絞り、description を比較する。

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

## Phase 3: Report

### マージとソート

全エージェントの findings を1つのリストに統合する。各 finding は以下のフォーマットに正規化する:

```json
{
  "section": "セクション名または行範囲",
  "severity": "high | medium | low",
  "category": "impl-clarity | impl-feasibility | impl-consistency | codex-adversarial | impl-ui-spec",
  "description": "指摘内容",
  "suggestion": "改善案"
}
```

severity で降順ソート: high > medium > low

### レポート出力

```
## Implementation Review Report (target: <doc_path>)

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

`iterations > 1` の場合、各 finding に vote count を付記する: `(N/N votes)`。`iterations == 1` の場合は vote count を表示しない。

findings が 0 件の場合 → 「指摘事項はありません。レビュー完了です。」と報告して終了する。

### Phase 3.7: Dialogue（対話的解決）

Phase 3 で生成されたレポートの findings を2グループに分類する:

| グループ | 条件 | フロー |
|---------|------|--------|
| **対話グループ** | category が `impl-clarity` かつ severity が `high` or `medium`、または category が `impl-feasibility` かつ severity が `high` | 本 Phase で対話的に解決 |
| **選択グループ** | 上記以外 | 従来通り番号選択 |

対話グループが空の場合、本 Phase をスキップしてユーザー選択に進む。

#### 対話フロー

対話グループの findings を severity 順（high → medium）に1件ずつ処理する:

1. finding の description と suggestion を提示する
2. 「この指摘について確認させてください: [finding の本質に踏み込んだ具体的な質問]」で質疑を開始する
3. ユーザーの回答に基づき、必要なら追加質問する（最大3往復）
4. 合意した解決方針を1-2文で要約し、「この方針で計画書を修正してよろしいですか？」と確認する
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

## Phase 4: Approve & Fix

ユーザーが選択した findings を実装計画書に反映する。

### 修正方法

ユーザーが選択・合意した findings を実装計画書に反映する。

#### 判定基準

- **対話グループ findings** — Phase 3.7 で合意した解決方針に基づいて修正する。suggestion ではなく合意済み解決方針を使用する
- **選択グループ findings** — suggestion の内容に基づいて修正する

#### 修正手順

1. 選択・合意された findings を重複除去し、1つの修正ブリーフに正規化する
2. 対象の実装計画書を Read で読み込む
3. finding の解決方針（対話グループ）または suggestion（選択グループ）を参照して修正内容を決定する
4. Edit で修正を適用する
5. 同一セクションに複数の findings がある場合は後方（行番号の大きい方）から修正する（行ずれ防止）

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

実装計画書の修正後、以下を確認する:
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

全て問題なしの場合 → 「レビュー完了。実装計画書の修正が完了しました。」と報告して終了する。

## Error Handling

| フェーズ | エラー | リカバリ |
|---------|--------|---------|
| 1 | 実装計画書が見つからない | パスを確認するようユーザーに報告 |
| 1 | `docs/plans/` ディレクトリが存在しない | ディレクトリ構成を確認するよう報告 |
| 2 | エージェントタイムアウト | 該当エージェント結果を空として続行 |
| 2 | JSON パース失敗 | 正規表現フォールバック、それでも失敗なら空 |
| 2 | Codex (companion.mjs) 実行失敗 | 警告表示し Codex なしで続行 |
| 2 | Codex 出力パース失敗 | 生テキストをそのまま codex-adversarial カテゴリで正規化 |
| 3 | ユーザー入力が不正 | 再入力を求める |
| 4 | セクション/構造不正 | スキップして次の finding へ |
| 5 | 整合性チェックで問題検出 | 修正提案、最大2回リトライ |

## Red Flags

**Never:**
- ユーザー承認なしに実装計画書を修正する
- レビュー対象外のファイルを変更する
- findings を勝手にフィルタリング・省略する（全件レポートする）
- 整合性の問題を無視して完了とする
- iterations > 1 で consensus 投票結果を無視する

**Always:**
- Phase 遷移時にアナウンスする
- 全エージェント（`--codex` 指定時は Codex 含む）の結果を待ってからレポートする
- 修正前にユーザーの選択を得る
- 修正後に検証を実行する
