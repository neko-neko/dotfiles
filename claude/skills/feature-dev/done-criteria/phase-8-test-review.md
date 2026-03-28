---
phase: 8
name: test-review
max_retries: 3
---

## Criteria

### D8-01: レビューが全3観点で実行された
- **severity**: quality
- **verify_type**: automated
- **verification**:
  レビュー結果ファイル（`artifacts/reviews/phase-8-review.json` またはレビューログ）を読み取り、3観点（coverage, quality, design-alignment）の実行記録を確認する。
- **pass_condition**: 3観点全ての実行記録が存在すること。記録された観点数が3
- **fail_diagnosis_hint**: 欠落している観点を特定し、/test-review の起動オプションを確認。観点の指定漏れか、レビューエージェントの実行途中中断かを切り分ける
- **depends_on_artifacts**: [artifacts/reviews/]

### D8-02: ユーザー承認済み findings の修正が全て適用済み
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. レビュー結果からユーザーが承認した findings をリストアップする
  2. 各 finding の指摘内容と対象ファイル/行を特定する
  3. 対象ファイルの該当箇所を `Read` で読み取り、指摘内容に対応する修正が適用されているか確認する
  4. 修正が適用されていない finding をリストアップする
- **pass_condition**: 手順4のリストが0件（ユーザー承認済み findings 全件に修正が適用済み）
- **fail_diagnosis_hint**: 未適用の finding を特定し、対象ファイルの該当行を確認。修正の適用漏れか、修正が別の形で反映されているかを確認。`git log --oneline` で修正コミットが存在するか確認する
- **depends_on_artifacts**: [artifacts/reviews/, tests/]

### D8-03: 設計書の全テスト観点がテストコードでカバーされている
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. 設計書のテスト観点セクションから全テスト観点を4区分（正常系、異常系、エッジケース、非機能）ごとにリストアップする
  2. テストコードディレクトリ（tests/, __tests__/, spec/ 等）の全テスト関数/メソッドを `Grep` で抽出する
  3. 各テスト観点に対応するテスト関数が1件以上存在するか照合する
  4. テスト観点でカバーされていないテスト関数がないか確認する（カバレッジの逆方向チェック）
  5. カバーされていないテスト観点をリストアップする
- **pass_condition**: 手順5のリストが0件（全テスト観点に対応テストコードあり）
- **fail_diagnosis_hint**: カバーされていないテスト観点を特定し、テスト区分（正常系/異常系/エッジケース/非機能）ごとの偏りを確認。テスト観点のタイトルとテスト関数名の命名規則が異なる場合は、テスト関数の内容ベースで対応を確認する
- **depends_on_artifacts**: [docs/plans/*-design.md, tests/]
