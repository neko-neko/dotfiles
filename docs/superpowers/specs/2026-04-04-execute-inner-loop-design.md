# Execute Inner Loop + Test Hierarchy Design

## Overview

feature-dev / debug-flow の Execute フェーズに開発者のインナーループを導入する。
TDD 実装後にテストを要件と突合して拡充し、全検証を通してから Audit Gate に進む構造。

### 解決する問題

現行の Execute フェーズでは:

1. **TestEnrich が存在しない** — 要件/設計書とテストコードの突合・拡充ステップがない。Done criteria D5-09 で「要件カバレッジ」を監査しているが、実行ステップとしては未定義
2. **Verify がインナーループではなく Audit Gate** — test+lint+fmt の確認は Audit Gate 時に初めて行われ、失敗すると Regate（Phase 全体の巻き戻し）になる
3. **テスト階層が未定義** — Unit / Integration / Smoke / E2E の区分と必須レベルが明文化されていない

### 設計方針

- Execute フェーズ内部のサブステップとして実装（Phase 分割はしない）
- `references/inner-loop-protocol.md` を新設し、feature-dev と debug-flow の両方から参照（DRY）
- テスト階層を3層に整理: Unit（必須）、Integration（必須）、Acceptance（オプション）

## Inner Loop 構造

### 全体フロー

```
Execute Phase 開始
  │
  ├─ Sub-step 1: Impl (TDD)
  │    feature-implementer x N タスク（既存の subagent-driven-development）
  │    各タスクで RED→GREEN→REFACTOR
  │    成果物: 実装コード + タスク単位の Unit Test
  │
  ├─ Sub-step 2: TestEnrich ◄─────────────────┐
  │    入力: 設計書/計画書の要件 + 現在のテストコード   │
  │    処理:                                       │
  │      1. 要件 → テストのトレーサビリティマップ作成  │
  │      2. ギャップ検出（正常系/異常系/境界値）       │
  │      3. Unit Test 拡充（不足分）                 │
  │      4. Integration Test 新規作成               │
  │      5. 破壊的テストケース追加                    │
  │    実行者: feature-implementer（継続）            │
  │                                                │
  ├─ Sub-step 3: Verify                            │
  │    1. 全テストスイート実行                        │
  │    2. lint                                      │
  │    3. fmt                                       │
  │    4. 型チェック                                 │
  │                                                │
  ├─ 判定                                           │
  │    ALL PASS → Exit Loop → Audit Gate            │
  │    FAIL ────→ Failure Router ─────────────────┘
  │               (max 3 iterations, 超過で PAUSE)
  │
  → Audit Gate (done-criteria で独立検証)
```

**制約**:

- Impl は1回のみ実行。ループ対象は TestEnrich → Verify の区間
- ただし Verify の失敗が実装バグに起因する場合、Failure Router が実装修正を指示する
- Audit Gate は Inner Loop とは独立。Inner Loop 通過後も Audit Gate で FAIL する可能性がある（独立検証の価値を維持）

## テスト階層

### 定義

| レベル | 定義 | 保証 |
|--------|------|------|
| Unit Test | 単一の関数/メソッド/モジュールの振る舞い検証。外部依存はモック/スタブ可。正常系・異常系・境界値を網羅 | Execute 内で必須 |
| Integration Test | 複数コンポーネント間の結合検証。実際の依存（DB, API, ファイルシステム等）を使用。データフロー・エラー伝播・状態遷移を検証 | Execute 内で必須 |
| Acceptance Test (Smoke/E2E 統合) | プロジェクト固有のランタイム環境を使ったユーザーシナリオレベルの検証。Web: ブラウザ E2E / Mobile: シミュレータ / CLI: コマンド実行シナリオ / Library: 省略可 | 後続フェーズ、`--accept` フラグでオプション |

### TestEnrich が書くテストの基準

**実践的であること（非トートロジー）**:

- 実装を読んでテストを書くのではなく、要件/設計書からテストを導出する
- 「この関数は X を返す」ではなく「ユーザーが Y した時に Z が起きる」

**破壊的であること**:

- 不正入力、null/undefined、型境界、空コレクション
- 競合状態、タイムアウト、リソース枯渇（該当する場合）
- 権限不足、認証切れ、ネットワーク断（該当する場合）

**トレーサビリティ**:

- 設計書/計画書の要件ID → テストケースの対応が追跡可能

### プロジェクト依存の判断

テスト階層の適用はプロジェクトのテスト基盤に依存する:

1. プロジェクトのテスト実行コマンドを自動検出（package.json scripts, Makefile, pytest.ini, etc.）
2. 検出できない場合は PAUSE してユーザーに確認
3. Integration Test の「実際の依存」がローカルで利用不可能な場合、concern として Acceptance Test フェーズに伝播

## TestEnrich 実行詳細

### 入力コンテキスト

TestEnrich 開始時に以下を収集し、feature-implementer に注入:

```yaml
test_enrich_context:
  # 1. 要件ソース（feature-dev / debug-flow で異なる）
  requirements_source:
    feature-dev: spec_file + implementation_plan  # 設計書 + 計画書
    debug-flow:  rca_report + fix_plan            # RCA レポート + 修正計画

  # 2. 現在のテストコード一覧
  existing_tests:
    - git diff で追加/変更されたテストファイル
    - 関連する既存テストファイル（impact 範囲）

  # 3. 現在の実装コード
  implementation:
    - git diff の code_changes 範囲

  # 4. テスト階層の要求
  required_levels:
    - unit: true
    - integration: true
```

### 実行ステップ

**Step 1: トレーサビリティマップ作成**

要件 → テストの対応表を作成:

```
要件ID/セクション → [テストファイル:テスト名] or [GAP]
```

- feature-dev: 設計書の要件 + 計画書のテストケース（Given/When/Then）
- debug-flow: RCA の根本原因 + 修正計画のテストケース

**Step 2: ギャップ分析**

マップ上の GAP を分類:

| カテゴリ | 例 |
|---------|---|
| 正常系の不足 | 主要ユースケースにテストがない |
| 異常系の不足 | エラーパス、例外、不正入力の検証がない |
| 境界値の不足 | 空配列、0、max値、null の検証がない |
| Integration の不足 | コンポーネント間のデータフローが未検証 |

**Step 3: テスト執筆**

ギャップに対してテストを追加:

- Unit Test: モック/スタブを使い、1テスト1アサーションの原則
- Integration Test: 実依存を使い、データフロー全体を検証
- 破壊的テスト: 不正入力・リソース枯渇・権限不足など、壊しにいくテスト
- テスト名は要件との対応が分かる命名（`test_[要件]_[条件]_[期待結果]`）

**Step 4: 自己検証**

テスト追加後、feature-implementer 自身が実行して結果を確認してから Verify に渡す。ここでの失敗は feature-implementer 内で解決（Failure Router に回さない）。

## Failure Router

### ルーティングロジック

```
Verify FAIL
  │
  ├─ テスト失敗
  │    ├─ 実装バグ（テストは正しいが実装が要件を満たしていない）
  │    │    → 実装修正 → Verify へ
  │    │
  │    ├─ テスト不備（テスト自体の記述ミス、前提条件の誤り）
  │    │    → テスト修正 → Verify へ
  │    │
  │    └─ 要件の曖昧さ（テストも実装も正しいが要件の解釈が割れている）
  │         → PAUSE（ユーザー判断）
  │
  ├─ lint / fmt 失敗
  │    → 自動修正（--fix 相当）→ Verify へ
  │    　（自動修正不可の場合は手動修正 → Verify へ）
  │
  ├─ 型チェック失敗
  │    → 実装修正 → Verify へ
  │
  └─ ビルド失敗
       → 実装修正 → Verify へ
```

### ループ制御

| 条件 | 動作 |
|------|------|
| iteration < max (3) | Failure Router で分類 → 修正 → Verify 再実行 |
| iteration = max | PAUSE — 失敗履歴をユーザーに提示し判断を仰ぐ |
| 同一テストが2回連続で同じ理由で失敗 | PAUSE — 根本原因の再検討が必要 |
| 要件の曖昧さ検出 | 即 PAUSE — iteration 回数に関係なく |

### 判定方法

1. Verify の出力をパース — テスト失敗メッセージ、lint エラー、型エラー、ビルドエラーを分類
2. テスト失敗の場合、失敗テストと変更コードの対応を特定 — git diff とテストの対象ファイルを照合
3. 実装バグ vs テスト不備の判定 — 設計書/計画書の要件と照合し、テストの期待値が要件に合致しているかを確認。合致していれば実装バグ、乖離があればテスト不備または要件曖昧

### 修正の実行者

- lint/fmt 自動修正: オーケストレーターが直接実行
- 実装修正/テスト修正: feature-implementer を継続（修正対象と失敗コンテキストを注入）

## ファイル構造と変更箇所

### 新規ファイル

| ファイル | 内容 |
|---------|------|
| `feature-dev/references/inner-loop-protocol.md` | Inner Loop Protocol 本体（テスト階層、TestEnrich 手順、Failure Router、ループ制御） |
| `debug-flow/references/inner-loop-protocol.md` | 同一内容のコピー |

各スキルの `references/` 配下にそれぞれ配置。`phase_references` は相対パスで解決するため、共有ディレクトリの新設は行わない。

### 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `feature-dev/phases/phase-05-execute.md` | Impl 後に TestEnrich → Verify → Loop を追記。`phase_references` に `inner-loop-protocol.md` を追加 |
| `feature-dev/done-criteria/phase-05-execute.md` | テスト階層（Unit/Integration）の明示的基準を追加・既存基準の文言調整 |
| `feature-dev/pipeline.yml` | Phase 6 の名称を `smoke-test` → `accept-test` に変更。`skip_unless` フラグを `--smoke` → `--accept` に変更 |
| `feature-dev/phases/phase-06-smoke-test.md` | ファイル名を `phase-06-accept-test.md` に変更。内容を Acceptance Test に汎化 |
| `feature-dev/done-criteria/phase-06-smoke-test.md` | ファイル名を `phase-06-accept-test.md` に変更。基準を汎化 |
| `debug-flow/phases/phase-04-execute.md` | 同上（feature-dev と同じ Inner Loop を追記） |
| `debug-flow/done-criteria/phase-04-execute.md` | 同上 |
| `debug-flow/pipeline.yml` | Phase 5 の名称・フラグを同様に変更 |
| `debug-flow/phases/phase-05-smoke-test.md` | ファイル名・内容を同様に変更 |
| `debug-flow/done-criteria/phase-05-smoke-test.md` | ファイル名・内容を同様に変更 |
| `feature-dev/SKILL.md` | フラグ解析で `--smoke` → `--accept` のリネーム |
| `debug-flow/SKILL.md` | フラグ解析で `--smoke` → `--accept` のリネーム |

### 変更しないもの

- `references/audit-gate-protocol.md` — Inner Loop は Audit Gate の前段。Audit Gate 自体のプロトコルは不変
- `regate/` — Regate は Audit Gate 失敗時のフロー。Inner Loop とは独立
- Done criteria の `audit` フィールド — 引き続き `required`
