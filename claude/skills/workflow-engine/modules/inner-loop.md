---
name: inner-loop-protocol
description: >-
  Execute フェーズ内の開発者インナーループ定義。Impl(TDD) → TestEnrich → Verify のサイクル、
  テスト階層（Unit/Integration/Acceptance）、Failure Router、ループ制御を規定する。
---

# Inner Loop Protocol

Execute フェーズ内で開発者のインナーループを再現するプロトコル。
全タスクの TDD 実装完了後、テストを要件と突合して拡充し、全検証を通してから Audit Gate に進む。

<HARD-GATE>
Inner Loop の Verify ステップを通過せずに Audit Gate に遷移してはならない。
Verify FAIL 状態での Audit Gate 実行は無効とする。
</HARD-GATE>

## 1. Inner Loop フロー

```
Execute Phase 開始
  │
  ├─ Sub-step 1: Impl (TDD)
  │    feature-implementer x N タスク（subagent-driven-development）
  │    各タスクで RED→GREEN→REFACTOR
  │    成果物: 実装コード + タスク単位の Unit Test
  │
  ├─ Sub-step 2: TestEnrich ◄─────────────────┐
  │    入力: 要件ソース + 現在のテストコード       │
  │    処理:                                     │
  │      1. トレーサビリティマップ作成              │
  │      2. ギャップ検出                           │
  │      3. Unit Test 拡充                        │
  │      4. Integration Test 新規作成             │
  │      5. 破壊的テストケース追加                  │
  │    実行者: feature-implementer（継続）          │
  │                                              │
  ├─ Sub-step 3: Verify                          │
  │    1. 全テストスイート実行                      │
  │    2. lint                                    │
  │    3. fmt                                     │
  │    4. 型チェック                               │
  │                                              │
  ├─ 判定                                         │
  │    ALL PASS → Exit Loop → Audit Gate          │
  │    FAIL ────→ Failure Router ───────────────┘
  │               (max 3 iterations, 超過で PAUSE)
  │
  → Audit Gate (done-criteria で独立検証)
```

制約:
- Impl は1回のみ実行。ループ対象は TestEnrich → Verify の区間
- ただし Verify の失敗が実装バグに起因する場合、Failure Router が実装修正を指示する
- Audit Gate は Inner Loop とは独立。Inner Loop 通過後も Audit Gate で FAIL する可能性がある

## 2. テスト階層

### 定義

| レベル | 定義 | 保証 |
|--------|------|------|
| Unit Test | 単一の関数/メソッド/モジュールの振る舞い検証。外部依存はモック/スタブ可。正常系・異常系・境界値を網羅 | Execute 内で必須 |
| Integration Test | 複数コンポーネント間の結合検証。実際の依存（DB, API, ファイルシステム等）を使用。データフロー・エラー伝播・状態遷移を検証 | Execute 内で必須 |
| Acceptance Test | プロジェクト固有のランタイム環境を使ったユーザーシナリオレベルの検証。Web: ブラウザ E2E / Mobile: シミュレータ / CLI: コマンド実行シナリオ / Library: 省略可 | 後続フェーズ、`--accept` フラグでオプション |

### TestEnrich が書くテストの基準

**実践的であること（非トートロジー）**:
- 実装を読んでテストを書くのではなく、要件/設計書からテストを導出する
- 「この関数は X を返す」ではなく「ユーザーが Y した時に Z が起きる」

**破壊的であること**:
- 不正入力、null/undefined、型境界、空コレクション
- 競合状態、タイムアウト、リソース枯渇（該当する場合）
- 権限不足、認証切れ、ネットワーク断（該当する場合）

**トレーサビリティ**:
- 要件ID → テストケースの対応が追跡可能
- テスト名は要件との対応が分かる命名: `test_[要件]_[条件]_[期待結果]`

### プロジェクト依存の判断

1. プロジェクトのテスト実行コマンドを自動検出（package.json scripts, Makefile, pytest.ini 等）
2. 検出できない場合は PAUSE してユーザーに確認
3. Integration Test の「実際の依存」がローカルで利用不可能な場合、concern として Acceptance Test フェーズに伝播

## 3. TestEnrich 実行手順

### 入力コンテキスト

TestEnrich 開始時に以下を収集し、feature-implementer に注入:

```yaml
test_enrich_context:
  requirements_source:
    feature-dev: spec_file + implementation_plan
    debug-flow:  rca_report + fix_plan
  existing_tests:
    - git diff で追加/変更されたテストファイル
    - 関連する既存テストファイル（impact 範囲）
    - reproduction_test（debug-flow の場合、pipeline.yml artifacts から解決）
  implementation:
    - git diff の code_changes 範囲
  required_levels:
    - unit: true
    - integration: true
```

### Step 1: トレーサビリティマップ作成

要件 → テストの対応表を作成:
```
要件ID/セクション → [テストファイル:テスト名] or [GAP]
```

- feature-dev: 設計書の要件 + 計画書のテストケース（Given/When/Then）
- debug-flow: RCA の根本原因 + 修正計画のテストケース

### Step 2: ギャップ分析

マップ上の GAP を分類:

| カテゴリ | 例 |
|---------|---|
| 正常系の不足 | 主要ユースケースにテストがない |
| 異常系の不足 | エラーパス、例外、不正入力の検証がない |
| 境界値の不足 | 空配列、0、max値、null の検証がない |
| Integration の不足 | コンポーネント間のデータフローが未検証 |

### Step 3: テスト執筆

ギャップに対してテストを追加:
- Unit Test: モック/スタブを使い、1テスト1アサーションの原則
- Integration Test: 実依存を使い、データフロー全体を検証
- 破壊的テスト: 不正入力・リソース枯渇・権限不足など、壊しにいくテスト

### Step 4: 自己検証

テスト追加後、feature-implementer 自身が実行して結果を確認してから Verify に渡す。
ここでの失敗は feature-implementer 内で解決（Failure Router に回さない）。

## 4. Failure Router

### ルーティングロジック

```
Verify FAIL
  │
  ├─ テスト失敗
  │    ├─ 実装バグ（テストは正しいが実装が要件を満たしていない）
  │    │    → 実装修正 → TestEnrich へ（テストとの整合を再確認）
  │    │
  │    ├─ テスト不備（テスト自体の記述ミス、前提条件の誤り）
  │    │    → テスト修正 → Verify へ（実装は変わらないため）
  │    │
  │    └─ 要件の曖昧さ（テストも実装も正しいが要件の解釈が割れている）
  │         → PAUSE（ユーザー判断）
  │
  ├─ lint / fmt 失敗
  │    → 自動修正（--fix 相当）→ Verify へ
  │    　（自動修正不可の場合は手動修正 → Verify へ）
  │
  ├─ 型チェック失敗
  │    → 実装修正 → TestEnrich へ（型変更がテストに影響する可能性）
  │
  └─ ビルド失敗
       → 実装修正 → TestEnrich へ（構造変更がテストに影響する可能性）
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
3. 実装バグ vs テスト不備の判定 — 要件と照合し、テストの期待値が要件に合致しているかを確認。合致していれば実装バグ、乖離があればテスト不備または要件曖昧

### 修正の実行者

- lint/fmt 自動修正: オーケストレーターが直接実行（変更ファイルのみ対象）
- 実装修正/テスト修正: feature-implementer を継続（修正対象と失敗コンテキストを注入）

## 5. Resume からの再開

handover 後に resume.md が `inner_loop_state` を検出した場合、以下のフローで再開する。

### Impl から再開

`current_substep: Impl` の場合:

1. `impl_progress.remaining_tasks` を implementation_plan/fix_plan と照合
2. `completed_tasks` に該当するタスクをスキップ
3. `remaining_tasks` のみで `subagent-driven-development` を起動
4. `last_commit` から git diff で完了済み実装を確認（存在検証）
5. 全 remaining_tasks 完了後、通常フローで TestEnrich に進む

### TestEnrich から再開

`current_substep: TestEnrich` の場合:

1. `impl_progress` の全タスクが実装済みであることを git diff で確認
2. TestEnrich の入力コンテキストを構築（セクション3の手順に従う）
3. TestEnrich を先頭から実行（トレーサビリティマップ作成から）

### Verify から再開

`current_substep: Verify` の場合:

1. `failure_history` を Failure Router に注入
2. `loop_iteration` を復元
3. Verify を先頭から実行（全テストスイート実行から）
