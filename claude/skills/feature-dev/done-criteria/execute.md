---
phase: 5
name: execute
max_retries: 3
audit: required
---

## Criteria

### D5-01: 全タスクに対応するコード変更が存在する
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. 計画書の全タスクIDをリストアップする
  2. `git diff --name-only` で変更されたファイル一覧を取得する
  3. 各タスクIDに対し、変更ファイルの中に対応するコード変更が1件以上存在するか照合する
  4. コード変更が存在しないタスクIDをリストアップする
- **pass_condition**: 手順4のリストが0件（全タスクに対応するコード変更あり）
- **fail_diagnosis_hint**: コード変更のないタスクIDを特定し、計画書の該当タスクを確認。実装漏れか、タスクの内容がドキュメントのみの変更で git diff に現れない形式かを切り分ける
- **depends_on_artifacts**: [docs/plans/*-plan.md]

### D5-02: ビルド/コンパイルが成功する
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  プロジェクトのビルドコマンド（`npm run build`, `cargo build`, `go build ./...` 等）を実行し、exit code を記録する。ビルドコマンドは package.json, Cargo.toml, go.mod, Makefile 等から特定する。
- **pass_condition**: ビルドコマンドの exit code が 0
- **fail_diagnosis_hint**: ビルドエラーログの最初のエラーメッセージを確認。型エラー、import 解決失敗、依存パッケージ不在のいずれかを特定し、該当ファイルと行番号を報告する
- **depends_on_artifacts**: [src/, artifacts/build/]

### D5-03: lint/型チェックにエラーがない
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  プロジェクトの linter/型チェッカー（`npm run lint`, `eslint`, `tsc --noEmit`, `cargo clippy`, `ruff check` 等）を実行し、エラー件数を記録する。
- **pass_condition**: linter/型チェッカーの exit code が 0、かつ error レベルの指摘が 0件
- **fail_diagnosis_hint**: エラー指摘のファイルパスと行番号を確認。型エラーは型定義の不整合、lint エラーはコーディング規約違反を確認。`--fix` オプションで自動修正可能か判定する
- **depends_on_artifacts**: [src/, artifacts/lint/]

### D5-04: 全テストスイートが通過
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  プロジェクトのテストコマンド（`npm test`, `cargo test`, `pytest`, `go test ./...` 等）を実行し、テスト結果サマリー（total, passed, failed, skipped）を記録する。
- **pass_condition**: テストコマンドの exit code が 0、かつ failed テスト数が 0
- **fail_diagnosis_hint**: 失敗したテスト名とエラーメッセージを確認。既存テストの退行か新規テストの初回失敗かを `git diff -- tests/` で切り分ける。退行の場合は `git stash && テスト実行` でベースラインとの差分を確認する
- **depends_on_artifacts**: [tests/, artifacts/test-results/]

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

### D5-06: 実装がコンポーネント境界を遵守している
- **severity**: quality
- **verify_type**: inspection
- **verification**:
  1. 設計書で定義されたコンポーネント境界（モジュール分割、レイヤー構成）を読み取る
  2. `git diff --name-only` で変更ファイルを取得し、各ファイルが属するコンポーネントを特定する
  3. 変更がコンポーネント境界を越えた直接依存（import/require）を新規に追加していないか確認する
- **pass_condition**: 設計書で定義された境界を越える新規直接依存の追加が0件
- **fail_diagnosis_hint**: 境界違反の import/require 文を特定し、設計書のコンポーネント図と照合。インターフェース層を経由すべき依存が直接参照になっているケースを確認する
- **depends_on_artifacts**: [docs/plans/*-design.md, src/]

### D5-07: 設計書→計画書→実装の一気通貫トレーサビリティ
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. 設計書の要件リストを全件列挙する
  2. 各要件に対応する計画書タスクIDを特定する
  3. 各タスクIDに対応する実装ファイル/関数を特定する（`git diff` + コード検索）
  4. 要件→タスク→実装の3段マッピングに欠落がないか確認する
  5. 実装に存在するが要件・タスクに対応しない「余剰実装」がないか確認する
- **pass_condition**: 手順4で3段マッピングの欠落が0件、手順5で計画書タスクに対応しない余剰実装ファイルが0件
- **fail_diagnosis_hint**: マッピング欠落の箇所（要件→タスク間か、タスク→実装間か）を特定。余剰実装がある場合は設計書/計画書への追記か、余剰コードの削除かを判断する
- **depends_on_artifacts**: [docs/plans/*-design.md, docs/plans/*-plan.md, src/]

### D5-08: 新規追加テストがトートロジーでない
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. `git diff --name-only -- tests/ __tests__/ spec/` で新規追加/変更されたテストファイルを列挙する
  2. 各テストファイルの assertion 文（expect, assert, should 等）を抽出する
  3. assertion が実装コードのロジックを経由しているか確認する（テスト対象の関数/メソッドを呼び出した結果を検証しているか）
  4. assertion が定数同士の比較（`expect(1).toBe(1)`）、モック戻り値の検証のみ（実コードパスを通らない）、空テスト（assertion なし）でないか確認する
- **pass_condition**: 手順4に該当するトートロジーテストが0件。全テストが実装コードパスを1つ以上通過する assertion を含む
- **fail_diagnosis_hint**: トートロジーテストのファイルパスと行番号を特定。モックの過剰使用、assertion の欠落、テスト対象関数の未呼び出しのいずれかを確認。実装コードの実際の振る舞いを検証する assertion に書き換える
- **depends_on_artifacts**: [tests/, src/]

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

## Observation Collection

phase-auditor は verdict 出力時に observations[] を必ず含めること。
PASS 判定の criteria でも quality/warning レベルの所見があれば記録する。
observations は project-state.json の phase_observations[] に蓄積される。
