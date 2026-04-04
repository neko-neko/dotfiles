# Execute Inner Loop + Test Hierarchy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** feature-dev / debug-flow の Execute フェーズに開発者のインナーループ（Impl→TestEnrich→Verify→Loop）を導入し、テスト階層を3層（Unit/Integration/Acceptance）に整理する

**Architecture:** 共有リファレンス `references/inner-loop-protocol.md` を新設し、両スキルの Execute フェーズから参照。Smoke Test フェーズを汎用 Acceptance Test フェーズにリネーム・汎化

**Tech Stack:** Markdown (skill definitions), YAML (pipeline config)

---

## File Structure

### 新規ファイル

| ファイル | 責務 |
|---------|------|
| `claude/skills/feature-dev/references/inner-loop-protocol.md` | Inner Loop Protocol 本体（テスト階層・TestEnrich 手順・Failure Router・ループ制御） |
| `claude/skills/debug-flow/references/inner-loop-protocol.md` | 同一内容のコピー |
| `claude/skills/feature-dev/phases/phase-06-accept-test.md` | Acceptance Test フェーズ（旧 smoke-test の汎化） |
| `claude/skills/feature-dev/done-criteria/phase-06-accept-test.md` | Acceptance Test の監査基準（旧 smoke-test の汎化） |
| `claude/skills/debug-flow/phases/phase-05-accept-test.md` | debug-flow 版 Acceptance Test フェーズ |
| `claude/skills/debug-flow/done-criteria/phase-05-accept-test.md` | debug-flow 版 Acceptance Test 監査基準 |

### 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `claude/skills/feature-dev/phases/phase-05-execute.md` | Inner Loop サブステップ追記、phase_references に inner-loop-protocol.md 追加 |
| `claude/skills/feature-dev/done-criteria/phase-05-execute.md` | テスト階層（Unit/Integration）の明示的基準を追加 |
| `claude/skills/feature-dev/pipeline.yml` | Phase 6 を smoke-test → accept-test にリネーム、フラグを --smoke → --accept に変更 |
| `claude/skills/feature-dev/SKILL.md` | フラグ解析で --smoke → --accept にリネーム、description 更新 |
| `claude/skills/debug-flow/phases/phase-04-execute.md` | Inner Loop サブステップ追記、phase_references に inner-loop-protocol.md 追加 |
| `claude/skills/debug-flow/done-criteria/phase-04-execute.md` | テスト階層の明示的基準を追加 |
| `claude/skills/debug-flow/pipeline.yml` | Phase 5 を smoke-test → accept-test にリネーム |
| `claude/skills/debug-flow/SKILL.md` | フラグ解析で --smoke → --accept にリネーム、description 更新 |

### 削除ファイル

| ファイル | 理由 |
|---------|------|
| `claude/skills/feature-dev/phases/phase-06-smoke-test.md` | accept-test に置換 |
| `claude/skills/feature-dev/done-criteria/phase-06-smoke-test.md` | accept-test に置換 |
| `claude/skills/debug-flow/phases/phase-05-smoke-test.md` | accept-test に置換 |
| `claude/skills/debug-flow/done-criteria/phase-05-smoke-test.md` | accept-test に置換 |

---

## Task 1: Inner Loop Protocol リファレンス作成（feature-dev）

**Files:**
- Create: `claude/skills/feature-dev/references/inner-loop-protocol.md`

- [ ] **Step 1: inner-loop-protocol.md を作成**

```markdown
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
```

- [ ] **Step 2: 作成したファイルのフロントマターと構造を確認**

ファイルを Read し、以下を確認:
- フロントマター（name, description）が存在すること
- 4つのメインセクション（Inner Loop フロー、テスト階層、TestEnrich 実行手順、Failure Router）が存在すること
- HARD-GATE タグが存在すること

- [ ] **Step 3: コミット**

```bash
git add claude/skills/feature-dev/references/inner-loop-protocol.md
git commit -m "add inner loop protocol reference for feature-dev"
```

---

## Task 2: Inner Loop Protocol リファレンス作成（debug-flow）

**Files:**
- Create: `claude/skills/debug-flow/references/inner-loop-protocol.md`

- [ ] **Step 1: feature-dev の inner-loop-protocol.md を debug-flow にコピー**

```bash
cp claude/skills/feature-dev/references/inner-loop-protocol.md \
   claude/skills/debug-flow/references/inner-loop-protocol.md
```

- [ ] **Step 2: 両ファイルの内容が同一であることを確認**

```bash
diff claude/skills/feature-dev/references/inner-loop-protocol.md \
     claude/skills/debug-flow/references/inner-loop-protocol.md
```

Expected: 差分なし

- [ ] **Step 3: コミット**

```bash
git add claude/skills/debug-flow/references/inner-loop-protocol.md
git commit -m "add inner loop protocol reference for debug-flow"
```

---

## Task 3: feature-dev Execute フェーズに Inner Loop を追加

**Files:**
- Modify: `claude/skills/feature-dev/phases/phase-05-execute.md`

- [ ] **Step 1: フロントマターに inner-loop-protocol.md を phase_references に追加**

`phase-05-execute.md` のフロントマターを以下に変更:

```yaml
---
phase: 5
phase_name: execute
requires_artifacts:
  - implementation_plan
phase_references:
  - references/audit-gate-protocol.md
  - references/inner-loop-protocol.md
invoke_agents:
  - feature-implementer
phase_flags:
  codex: optional
  swarm: optional
---
```

変更点: `phase_references` に `references/inner-loop-protocol.md` を追加

- [ ] **Step 2: 実行手順セクションを Inner Loop 構造に書き換え**

`## 実行手順` セクションを以下に置換:

```markdown
## 実行手順

`references/inner-loop-protocol.md` を Read し、以下の3サブステップで実行する。

### Sub-step 1: Impl (TDD)

1. `requires_artifacts` の `implementation_plan` を Read
2. Evidence Plan が存在する場合、Evidence Collection 要件を抽出
3. Skill invoke: `superpowers:subagent-driven-development`
   - 計画書のタスクを分解
   - 各タスクに `feature-implementer` エージェントを起動
   - feature-implementer は TDD で実装（superpowers:test-driven-development 自動注入）

#### --swarm 時

TeamCreate で "impl-{feature}" チームを作成:
- メンバー: feature-implementer x N（タスク数に応じて）

### Sub-step 2: TestEnrich

全タスク完了後、`inner-loop-protocol.md` セクション3の手順に従い実行:

1. テスト拡充コンテキストを構築:
   - requirements_source: `spec_file` + `implementation_plan`（Phase Summary から解決）
   - existing_tests: `git diff --name-only -- tests/ __tests__/ spec/` + impact 範囲の既存テスト
   - implementation: `git diff` の code_changes 範囲
2. `feature-implementer` を継続起動し、テスト拡充コンテキストを注入
3. feature-implementer がトレーサビリティマップ作成 → ギャップ分析 → テスト執筆 → 自己検証を実行

### Sub-step 3: Verify

1. プロジェクトのテスト実行コマンドで全テストスイートを実行
2. lint を実行（変更ファイルのみ）
3. fmt を実行（変更ファイルのみ）
4. 型チェックを実行
5. ALL PASS → Audit Gate へ進む
6. FAIL → `inner-loop-protocol.md` セクション4の Failure Router に従いルーティング

### Inner Loop 制御

- TestEnrich → Verify のループは最大3回
- 超過時は PAUSE（失敗履歴をユーザーに提示）
- 要件の曖昧さ検出時は即 PAUSE

### Evidence Collection

Phase 1 Audit Gate 完了後に生成された Evidence Plan に基づき:
- テスト coverage
- スクリーンショット/ビデオ（UI 変更時）
- パフォーマンスメトリクス
- セキュリティスキャン結果
```

- [ ] **Step 3: 成果物定義と Phase Summary テンプレートはそのまま維持されていることを確認**

ファイル末尾の `## 成果物定義` と `## Phase Summary テンプレート` セクションが変更されていないことを確認。

- [ ] **Step 4: コミット**

```bash
git add claude/skills/feature-dev/phases/phase-05-execute.md
git commit -m "add inner loop (TestEnrich + Verify) to feature-dev execute phase"
```

---

## Task 4: feature-dev Execute done-criteria にテスト階層基準を追加

**Files:**
- Modify: `claude/skills/feature-dev/done-criteria/phase-05-execute.md`

- [ ] **Step 1: D5-05 の文言をテスト階層を反映した形に更新**

既存の D5-05 を以下に置換:

```markdown
### D5-05: Unit Test + Integration Test が要件に対応して存在する
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. 計画書のテストケースセクションから全テストケースをリストアップする
  2. テストコードディレクトリ（tests/, __tests__/, spec/ 等）から全テスト関数/メソッド名を `Grep` で抽出する
  3. 各計画書テストケースに対応する Unit Test が1件以上存在するか照合する
  4. コンポーネント間のデータフロー・エラー伝播を検証する Integration Test が存在するか確認する
  5. 対応テストコードが存在しないテストケースをリストアップする
- **pass_condition**: 手順5のリストが0件。Unit Test と Integration Test の両レベルが存在すること
- **fail_diagnosis_hint**: 対応テストコードのないテストケースを特定。Unit Test のみで Integration Test が欠落しているケースに注意。モック/スタブのみのテストは Unit Test として扱い、Integration Test には実依存を使ったテストが必要
- **depends_on_artifacts**: [docs/plans/*-plan.md, tests/]
```

- [ ] **Step 2: D5-09 にテスト階層と破壊的テストの基準を追加**

既存の D5-09 を以下に置換:

```markdown
### D5-09: テストケースが要件カバレッジ・影響範囲の網羅性・テスト階層を満たす
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. 設計書の要件リストを列挙し、各要件にIDを付与する
  2. impact-analyzer 出力の影響範囲（ファイル/モジュール）を列挙する
  3. 各要件IDに対応するテストケースが1件以上存在するか照合する
  4. 各影響範囲のファイル/モジュールに対するテストが存在するか照合する
  5. 影響を受ける既存コードの既存テストが削除・無効化されていないか確認する（`git diff` で `.skip`, `.only` の追加、テスト関数のコメントアウト/削除を検出）
  6. 正常系・異常系・境界値の3カテゴリがそれぞれ1件以上のテストケースを持つか確認する
  7. 破壊的テスト（不正入力、null/undefined、型境界、空コレクション等）が1件以上存在するか確認する
- **pass_condition**: 手順3-7の全条件を満たすこと。手順3で全要件に対応テストあり、手順4で全影響範囲に対応テストあり、手順5で既存テストの削除/無効化が0件、手順6で3カテゴリ各1件以上、手順7で破壊的テスト1件以上
- **fail_diagnosis_hint**: 手順3-5は既存と同様。手順6で欠落カテゴリがある場合、inner-loop-protocol.md の TestEnrich ギャップ分析表を参照し該当カテゴリのテストを追加する。手順7で破壊的テストがない場合、不正入力・境界値に対する異常系テストを追加する
- **depends_on_artifacts**: [docs/plans/*-design.md, tests/, src/]
- **forward_check**: Phase 8 (Code Review) で指摘される「テスト不足」を事前に防止する
```

- [ ] **Step 3: 変更後のファイルを Read し、D5-01〜D5-09 が全て存在することを確認**

- [ ] **Step 4: コミット**

```bash
git add claude/skills/feature-dev/done-criteria/phase-05-execute.md
git commit -m "update feature-dev execute done-criteria with test hierarchy requirements"
```

---

## Task 5: feature-dev Acceptance Test フェーズ作成 + pipeline.yml 更新

**Files:**
- Create: `claude/skills/feature-dev/phases/phase-06-accept-test.md`
- Create: `claude/skills/feature-dev/done-criteria/phase-06-accept-test.md`
- Modify: `claude/skills/feature-dev/pipeline.yml`
- Delete: `claude/skills/feature-dev/phases/phase-06-smoke-test.md`
- Delete: `claude/skills/feature-dev/done-criteria/phase-06-smoke-test.md`

- [ ] **Step 1: phase-06-accept-test.md を作成**

```markdown
---
phase: 6
phase_name: accept-test
requires_artifacts:
  - code_changes
phase_references: []
invoke_agents: []
phase_flags: {}
---

## 実行手順

このフェーズは `--accept` フラグ指定時のみ有効。未指定時はスキップ。

プロジェクト固有のランタイム環境を使った Acceptance Test（Smoke/E2E 統合）を実行する。
テスト方法はプロジェクト種別により異なる:

- **Web アプリ**: Skill invoke: `/smoke-test`（dev サーバー起動 → アドホックテスト → VRT → E2E + フレーキー検出）
- **Mobile アプリ**: シミュレータ/エミュレータでの UI テスト
- **CLI ツール**: コマンド実行シナリオテスト
- **Library**: Integration Test で十分な場合は省略可（PAUSE してユーザーに確認）

プロジェクト種別の判定:
1. プロジェクトルートの構成ファイル（package.json, Podfile, pubspec.yaml, Cargo.toml 等）からプロジェクト種別を推定
2. 推定できない場合は PAUSE してユーザーに確認
3. Execute フェーズの concerns に「Integration Test でローカル依存が不可」がある場合、ここで対応

マージ前のローカル最終確認として位置づける。

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| accept_test_results | file | `accept-test-report.md` |

## Phase Summary テンプレート

```yaml
artifacts:
  accept_test_results:
    type: file
    value: "<accept-test-report.md パス>"
```
```

- [ ] **Step 2: done-criteria/phase-06-accept-test.md を作成**

```markdown
---
phase: 6
name: accept-test
max_retries: 3
audit: required
---

## Criteria

### D6-01: 全 Acceptance Test ステップが PASS
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  Acceptance Test 結果ファイル（`artifacts/accept-test/` 配下のログ/レポート）を読み取り、各ステップの PASS/FAIL ステータスを確認する。結果ファイルが存在しない場合は Acceptance Test を再実行する。
- **pass_condition**: 全ステップのステータスが PASS。FAIL ステップが0件
- **fail_diagnosis_hint**: FAIL したステップ名とエラーメッセージを確認。プロジェクト種別に応じて: Web → セレクタ不一致/タイムアウト/HTTP エラーを切り分け。Mobile → シミュレータ起動失敗/UI 要素未検出を切り分け。CLI → コマンド exit code/stdout 不一致を確認
- **depends_on_artifacts**: [artifacts/accept-test/]

### D6-02: flaky test が未検出または報告済み
- **severity**: quality
- **verify_type**: automated
- **verification**:
  Acceptance Test 結果ログを読み取り、同一ステップが再実行で結果が変わったケース（1回目 FAIL → 2回目 PASS、またはその逆）を検出する。検出された場合、flaky として報告リストに記録されているか確認する。
- **pass_condition**: flaky 検出件数が0件、または検出された全件が報告リストに記録済み
- **fail_diagnosis_hint**: flaky ステップを特定し、タイミング依存、外部サービス依存、テストデータ依存のいずれかを調査する
- **depends_on_artifacts**: [artifacts/accept-test/]

### D6-03: テストシナリオがプロジェクト特性を反映している
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. プロジェクト種別（Web/Mobile/CLI/Library 等）を特定する
  2. Acceptance Test のシナリオリストを読み取る
  3. プロジェクト種別ごとの必須シナリオカテゴリが存在するか判定する:
     - Web: ナビゲーション、フォーム操作、レスポンシブ表示の各カテゴリに1件以上
     - API: 正常レスポンス（2xx）、異常レスポンス（4xx/5xx）の各カテゴリに1件以上
     - Mobile: 画面遷移、入力操作、通知の各カテゴリに1件以上
     - CLI: 正常実行、不正引数、ヘルプ表示の各カテゴリに1件以上
  4. 設計書/RCA Report の主要ユーザーフローを列挙し、各フローに対応するシナリオが1件以上存在するか照合する
- **pass_condition**: 手順3の全必須カテゴリにシナリオが1件以上存在し、かつ手順4の全ユーザーフローにシナリオが対応していること
- **fail_diagnosis_hint**: 欠落しているカテゴリを特定し、該当カテゴリの Acceptance Test シナリオを追加する
- **depends_on_artifacts**: [artifacts/accept-test/, docs/plans/*-design.md]

### D6-04: Acceptance Test 実行証跡が有効である
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  以下を機械的に検証する:
  1. `accept-test-report.md` が作業ディレクトリに存在し、テスト結果を含むこと
  2. プロジェクト種別に応じた証跡が存在すること:
     - Web: スクリーンショット（`accept-*.png`）が1枚以上
     - Mobile: シミュレータスクリーンショットまたはログ
     - CLI: コマンド実行ログ（stdout/stderr）
     - API: レスポンスボディのスナップショット
  3. レポートが実在する証跡ファイルを参照していること
- **pass_condition**: 上記を満たすこと
- **fail_diagnosis_hint**: レポート未存在 → Acceptance Test が正しく実行されていない。証跡未存在 → テスト実行環境の問題。環境問題であれば PAUSE としてユーザーに報告する
- **depends_on_artifacts**: [accept-test-report.md]

## Observation Collection

phase-auditor は verdict 出力時に observations[] を必ず含めること。
PASS 判定の criteria でも quality/warning レベルの所見があれば記録する。
observations は project-state.json の phase_observations[] に蓄積される。
```

- [ ] **Step 3: pipeline.yml の Phase 6 を更新**

`pipeline.yml` の smoke-test エントリを以下に置換:

```yaml
  - id: accept-test
    phase_file: phases/phase-06-accept-test.md
    done_criteria: done-criteria/phase-06-accept-test.md
    skip_unless: --accept
    produces:
      - accept_test_results
```

同時に `regate.verification_chain` を更新:

```yaml
  verification_chain: [execute, accept-test, review]
```

- [ ] **Step 4: 旧 smoke-test ファイルを削除**

```bash
git rm claude/skills/feature-dev/phases/phase-06-smoke-test.md
git rm claude/skills/feature-dev/done-criteria/phase-06-smoke-test.md
```

- [ ] **Step 5: pipeline.yml を Read し、Phase 6 が accept-test になっていること、verification_chain が更新されていることを確認**

- [ ] **Step 6: コミット**

```bash
git add claude/skills/feature-dev/phases/phase-06-accept-test.md \
        claude/skills/feature-dev/done-criteria/phase-06-accept-test.md \
        claude/skills/feature-dev/pipeline.yml
git commit -m "replace smoke-test with accept-test phase in feature-dev pipeline"
```

---

## Task 6: feature-dev SKILL.md のフラグ更新

**Files:**
- Modify: `claude/skills/feature-dev/SKILL.md`

- [ ] **Step 1: description の --smoke を --accept に変更**

フロントマターの description を以下に更新:

```yaml
description: >-
  品質ゲート付き開発オーケストレーター。9フェーズで設計→レビュー→計画→レビュー→
  実装→Acceptanceテスト→ドキュメント監査→レビュー→統合を一気通貫で実行する。
  --codex 指定時は全レビューフェーズで Codex を有効化。
  --e2e 指定時は Review フェーズで test-review 観点を有効化。
  --accept 指定時は accept-test フェーズを有効化。
  --doc 指定時は doc-audit フェーズを有効化。
```

- [ ] **Step 2: 引数パースセクションの --smoke を --accept に変更**

```markdown
- `--accept`: accept-test フェーズを有効化
```

- [ ] **Step 3: ファイル内に `--smoke` が残っていないことを Grep で確認**

```bash
grep -n "\-\-smoke" claude/skills/feature-dev/SKILL.md
```

Expected: 0件

- [ ] **Step 4: コミット**

```bash
git add claude/skills/feature-dev/SKILL.md
git commit -m "rename --smoke to --accept flag in feature-dev SKILL.md"
```

---

## Task 7: debug-flow Execute フェーズに Inner Loop を追加

**Files:**
- Modify: `claude/skills/debug-flow/phases/phase-04-execute.md`

- [ ] **Step 1: フロントマターに inner-loop-protocol.md を phase_references に追加**

`phase-04-execute.md` のフロントマターを以下に変更:

```yaml
---
phase: 4
phase_name: execute
requires_artifacts:
  - fix_plan
phase_references:
  - references/audit-gate-protocol.md
  - references/inner-loop-protocol.md
invoke_agents:
  - feature-implementer
phase_flags:
  codex: optional
  swarm: optional
---
```

- [ ] **Step 2: 実行手順セクションを Inner Loop 構造に書き換え**

`## 実行手順` セクションを以下に置換:

```markdown
## 実行手順

`references/inner-loop-protocol.md` を Read し、以下の3サブステップで実行する。

### Sub-step 1: Impl (TDD)

1. `requires_artifacts` の `fix_plan` を Read
2. Evidence Plan が存在する場合、Evidence Collection 要件を抽出
3. Skill invoke: `superpowers:subagent-driven-development`
   - 修正対象・根本原因・完了条件・検証方法を self-contained な実装 spec に再構成
   - 各タスクに `feature-implementer` エージェントを起動
   - feature-implementer は TDD で実装（superpowers:test-driven-development 自動注入）

#### --swarm 時

TeamCreate で "impl-{bug}" チームを作成:
- メンバー: feature-implementer x N（タスク数に応じて）

### Sub-step 2: TestEnrich

全タスク完了後、`inner-loop-protocol.md` セクション3の手順に従い実行:

1. テスト拡充コンテキストを構築:
   - requirements_source: `rca_report` + `fix_plan`（Phase Summary から解決）
   - existing_tests: `git diff --name-only -- tests/ __tests__/ spec/` + impact 範囲の既存テスト
   - implementation: `git diff` の code_changes 範囲
2. `feature-implementer` を継続起動し、テスト拡充コンテキストを注入
3. feature-implementer がトレーサビリティマップ作成 → ギャップ分析 → テスト執筆 → 自己検証を実行

### Sub-step 3: Verify

1. プロジェクトのテスト実行コマンドで全テストスイートを実行
2. lint を実行（変更ファイルのみ）
3. fmt を実行（変更ファイルのみ）
4. 型チェックを実行
5. ALL PASS → Audit Gate へ進む
6. FAIL → `inner-loop-protocol.md` セクション4の Failure Router に従いルーティング

### Inner Loop 制御

- TestEnrich → Verify のループは最大3回
- 超過時は PAUSE（失敗履歴をユーザーに提示）
- 要件の曖昧さ検出時は即 PAUSE

### Evidence Collection

Phase 1 Audit Gate 完了後に生成された Evidence Plan に基づき:
- テスト coverage
- スクリーンショット/ビデオ（UI 変更時）
- パフォーマンスメトリクス
- セキュリティスキャン結果
```

- [ ] **Step 3: 成果物定義と Phase Summary テンプレートが維持されていることを確認**

- [ ] **Step 4: コミット**

```bash
git add claude/skills/debug-flow/phases/phase-04-execute.md
git commit -m "add inner loop (TestEnrich + Verify) to debug-flow execute phase"
```

---

## Task 8: debug-flow Execute done-criteria にテスト階層基準を追加

**Files:**
- Modify: `claude/skills/debug-flow/done-criteria/phase-04-execute.md`

- [ ] **Step 1: D4-05 の文言をテスト階層を反映した形に更新**

既存の D4-05 を以下に置換:

```markdown
### D4-05: Unit Test + Integration Test が要件に対応して存在する
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. 計画書のテストケースセクションから全テストケースをリストアップする
  2. テストコードディレクトリ（tests/, __tests__/, spec/ 等）から全テスト関数/メソッド名を `Grep` で抽出する
  3. 各計画書テストケースに対応する Unit Test が1件以上存在するか照合する
  4. コンポーネント間のデータフロー・エラー伝播を検証する Integration Test が存在するか確認する
  5. 対応テストコードが存在しないテストケースをリストアップする
- **pass_condition**: 手順5のリストが0件。Unit Test と Integration Test の両レベルが存在すること
- **fail_diagnosis_hint**: 対応テストコードのないテストケースを特定。Unit Test のみで Integration Test が欠落しているケースに注意。モック/スタブのみのテストは Unit Test として扱い、Integration Test には実依存を使ったテストが必要
- **depends_on_artifacts**: [docs/plans/*-fix-plan.md, tests/]
```

- [ ] **Step 2: D4-09 にテスト階層と破壊的テストの基準を追加**

既存の D4-09 を以下に置換:

```markdown
### D4-09: テストケースが要件カバレッジ・影響範囲の網羅性・テスト階層を満たす
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. RCA Report の Impact Scope を列挙し、各要件にIDを付与する
  2. impact-analyzer 出力の影響範囲（ファイル/モジュール）を列挙する
  3. 各要件IDに対応するテストケースが1件以上存在するか照合する
  4. 再現テストが修正後に PASS に変わることを確認する
  5. 各影響範囲のファイル/モジュールに対するテストが存在するか照合する
  6. 影響を受ける既存コードの既存テストが削除・無効化されていないか確認する（`git diff` で `.skip`, `.only` の追加、テスト関数のコメントアウト/削除を検出）
  7. 正常系・異常系・境界値の3カテゴリがそれぞれ1件以上のテストケースを持つか確認する
  8. 破壊的テスト（不正入力、null/undefined、型境界、空コレクション等）が1件以上存在するか確認する
- **pass_condition**: 手順3-8の全条件を満たすこと。手順3で全要件に対応テストあり、手順4で再現テストが PASS、手順5で全影響範囲に対応テストあり、手順6で既存テストの削除/無効化が0件、手順7で3カテゴリ各1件以上、手順8で破壊的テスト1件以上
- **fail_diagnosis_hint**: 手順3-6は既存と同様。手順7で欠落カテゴリがある場合、inner-loop-protocol.md の TestEnrich ギャップ分析表を参照し該当カテゴリのテストを追加する。手順8で破壊的テストがない場合、不正入力・境界値に対する異常系テストを追加する
- **depends_on_artifacts**: [docs/plans/*-rca.md, tests/, src/]
- **forward_check**: Phase 7 (Code Review) で指摘される「テスト不足」を事前に防止する
```

- [ ] **Step 3: 変更後のファイルを Read し、D4-01〜D4-09 が全て存在することを確認**

- [ ] **Step 4: コミット**

```bash
git add claude/skills/debug-flow/done-criteria/phase-04-execute.md
git commit -m "update debug-flow execute done-criteria with test hierarchy requirements"
```

---

## Task 9: debug-flow Acceptance Test フェーズ作成 + pipeline.yml 更新

**Files:**
- Create: `claude/skills/debug-flow/phases/phase-05-accept-test.md`
- Create: `claude/skills/debug-flow/done-criteria/phase-05-accept-test.md`
- Modify: `claude/skills/debug-flow/pipeline.yml`
- Delete: `claude/skills/debug-flow/phases/phase-05-smoke-test.md`
- Delete: `claude/skills/debug-flow/done-criteria/phase-05-smoke-test.md`

- [ ] **Step 1: phase-05-accept-test.md を作成**

feature-dev の `phase-06-accept-test.md` と同一内容で、フロントマターの phase 番号のみ変更:

```yaml
---
phase: 5
phase_name: accept-test
requires_artifacts:
  - code_changes
phase_references: []
invoke_agents: []
phase_flags: {}
---
```

本文は feature-dev の `phase-06-accept-test.md` と同一。ただし「設計書/RCA Report」の参照箇所で debug-flow では RCA Report を優先参照する。

- [ ] **Step 2: done-criteria/phase-05-accept-test.md を作成**

feature-dev の `done-criteria/phase-06-accept-test.md` と同一内容で、フロントマターの phase 番号のみ変更:

```yaml
---
phase: 5
name: accept-test
max_retries: 3
audit: required
---
```

本文の D6-03 で「設計書」を参照する箇所を「RCA Report」に変更:

```markdown
  4. RCA Report の主要影響フローを列挙し、各フローに対応するシナリオが1件以上存在するか照合する
```

`depends_on_artifacts` も対応更新:

```markdown
- **depends_on_artifacts**: [artifacts/accept-test/, docs/plans/*-rca.md]
```

さらに、debug-flow 固有の D5-05（Cross-View Consistency）を追加する。これは現行の `done-criteria/phase-05-smoke-test.md` に存在する基準で、RCA の Symmetry Check に基づくコンシューマ間整合性検証:

```markdown
### D5-05: 同一データのコンシューマ間整合性が検証されている（Cross-View Consistency）
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. RCA Report の Symmetry Check（または Impact Scope）から、同一データを異なるコンシューマ（画面、API、レポート等）で公開するケースを列挙する
  2. 該当ケースが0件の場合、Acceptance Test のシナリオリストと主要影響フローを照合し、コンシューマ間整合性チェックが不要である根拠を確認する
  3. 該当ケースが1件以上の場合、各ケースについて Acceptance Test シナリオに以下が含まれるか確認する:
     a. コンシューマAで指標の値を取得
     b. コンシューマBで同一条件の同指標の値を取得
     c. 両者が一致することの検証
  4. 検証結果（一致/不一致）がレポートに記録されているか確認する
- **pass_condition**: 該当ケース0件（根拠あり）、または全該当ケースにシナリオが存在しレポートに結果が記録されていること
- **fail_diagnosis_hint**: 該当ケースのコンシューマペアを特定し、各コンシューマのアクセス方法を確認。Acceptance Test シナリオにコンシューマ間比較ステップを追加する
- **depends_on_artifacts**: [docs/debug/*-rca.md, artifacts/accept-test/]
```

- [ ] **Step 3: pipeline.yml の Phase 5 を更新**

`pipeline.yml` の smoke-test エントリを以下に置換:

```yaml
  - id: accept-test
    phase_file: phases/phase-05-accept-test.md
    done_criteria: done-criteria/phase-05-accept-test.md
    skip_unless: --accept
    produces:
      - accept_test_results
```

同時に `regate.verification_chain` を更新:

```yaml
  verification_chain: [execute, accept-test, review]
```

- [ ] **Step 4: 旧 smoke-test ファイルを削除**

```bash
git rm claude/skills/debug-flow/phases/phase-05-smoke-test.md
git rm claude/skills/debug-flow/done-criteria/phase-05-smoke-test.md
```

- [ ] **Step 5: コミット**

```bash
git add claude/skills/debug-flow/phases/phase-05-accept-test.md \
        claude/skills/debug-flow/done-criteria/phase-05-accept-test.md \
        claude/skills/debug-flow/pipeline.yml
git commit -m "replace smoke-test with accept-test phase in debug-flow pipeline"
```

---

## Task 10: debug-flow SKILL.md のフラグ更新

**Files:**
- Modify: `claude/skills/debug-flow/SKILL.md`

- [ ] **Step 1: description の --smoke を --accept に変更**

フロントマターの description を以下に更新:

```yaml
description: >-
  品質ゲート付きデバッグオーケストレーター。8フェーズで根本原因分析→修正計画→レビュー→
  実装→Acceptanceテスト→ドキュメント監査→レビュー→統合を品質ゲート付きで実行する。
  --codex 指定時は全レビューフェーズで Codex を有効化。
  --e2e 指定時は Review フェーズで test-review 観点を有効化。
  --accept 指定時は accept-test フェーズを有効化。
  --doc 指定時は doc-audit フェーズを有効化。
```

- [ ] **Step 2: 引数パースセクションの --smoke を --accept に変更**

```markdown
- `--accept`: accept-test フェーズを有効化
```

- [ ] **Step 3: ファイル内に `--smoke` が残っていないことを Grep で確認**

```bash
grep -n "\-\-smoke" claude/skills/debug-flow/SKILL.md
```

Expected: 0件

- [ ] **Step 4: コミット**

```bash
git add claude/skills/debug-flow/SKILL.md
git commit -m "rename --smoke to --accept flag in debug-flow SKILL.md"
```

---

## Task 11: 全体整合性検証

**Files:** 全変更ファイル

- [ ] **Step 1: feature-dev の全参照パスが有効であることを確認**

```bash
# pipeline.yml が参照するファイルが全て存在するか
for f in \
  claude/skills/feature-dev/phases/phase-06-accept-test.md \
  claude/skills/feature-dev/done-criteria/phase-06-accept-test.md \
  claude/skills/feature-dev/references/inner-loop-protocol.md; do
  test -f "$f" && echo "OK: $f" || echo "MISSING: $f"
done
```

Expected: 全て OK

- [ ] **Step 2: debug-flow の全参照パスが有効であることを確認**

```bash
for f in \
  claude/skills/debug-flow/phases/phase-05-accept-test.md \
  claude/skills/debug-flow/done-criteria/phase-05-accept-test.md \
  claude/skills/debug-flow/references/inner-loop-protocol.md; do
  test -f "$f" && echo "OK: $f" || echo "MISSING: $f"
done
```

Expected: 全て OK

- [ ] **Step 3: 旧 smoke-test ファイルが存在しないことを確認**

```bash
for f in \
  claude/skills/feature-dev/phases/phase-06-smoke-test.md \
  claude/skills/feature-dev/done-criteria/phase-06-smoke-test.md \
  claude/skills/debug-flow/phases/phase-05-smoke-test.md \
  claude/skills/debug-flow/done-criteria/phase-05-smoke-test.md; do
  test -f "$f" && echo "STILL EXISTS: $f" || echo "OK (deleted): $f"
done
```

Expected: 全て OK (deleted)

- [ ] **Step 4: --smoke がどのファイルにも残っていないことを確認**

```bash
grep -r "\-\-smoke" claude/skills/feature-dev/ claude/skills/debug-flow/ || echo "No --smoke references found"
```

Expected: "No --smoke references found"

- [ ] **Step 5: inner-loop-protocol.md が両スキルで同一であることを確認**

```bash
diff claude/skills/feature-dev/references/inner-loop-protocol.md \
     claude/skills/debug-flow/references/inner-loop-protocol.md
```

Expected: 差分なし

- [ ] **Step 6: pipeline.yml の verification_chain が accept-test を参照していることを確認**

```bash
grep "verification_chain" claude/skills/feature-dev/pipeline.yml claude/skills/debug-flow/pipeline.yml
```

Expected: 両方とも `[execute, accept-test, review]`
