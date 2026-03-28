---
phase: 6
name: code-review
max_retries: 3
---

## Criteria

### D6-01: レビューが全7観点で実行された
- **severity**: quality
- **verify_type**: automated
- **verification**:
  レビュー結果ファイル（`artifacts/reviews/phase-6-review.json` またはレビューログ）を読み取り、7観点（simplify, code-quality, code-security, code-performance, code-test, ai-antipattern, code-impact）の実行記録を確認する。
- **pass_condition**: 7観点全ての実行記録が存在すること。記録された観点数が7
- **fail_diagnosis_hint**: 欠落している観点を特定し、/code-review の起動オプションを確認。観点の指定漏れか、レビューエージェントの実行途中中断かを切り分ける
- **depends_on_artifacts**: [artifacts/reviews/]

### D6-02: ユーザー承認済み findings の修正が全て適用済み
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. レビュー結果からユーザーが承認した findings をリストアップする
  2. 各 finding の指摘内容と対象ファイル/行を特定する
  3. 対象ファイルの該当箇所を `Read` で読み取り、指摘内容に対応する修正が適用されているか確認する
  4. 修正が適用されていない finding をリストアップする
- **pass_condition**: 手順4のリストが0件（ユーザー承認済み findings 全件に修正が適用済み）
- **fail_diagnosis_hint**: 未適用の finding を特定し、対象ファイルの該当行を確認。修正の適用漏れか、修正が別の形で反映されているかを確認。`git log --oneline` で修正コミットが存在するか確認する
- **depends_on_artifacts**: [artifacts/reviews/, src/]

### D6-03: 未コミット変更なし + ブランチが最新 main から乖離 50 commit 以内
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  1. `git status --porcelain` を実行し、未コミット変更を検出する
  2. `git rev-list --count HEAD ^main` を実行し（main が存在しない場合は master）、ブランチの乖離コミット数を取得する
- **pass_condition**: 手順1の出力が空（未コミット変更0件）、かつ手順2のコミット数が50以下
- **fail_diagnosis_hint**: 未コミット変更がある場合は `git add` + `git commit` の実行漏れを確認。乖離が50超の場合は main ブランチとの rebase を検討。長期ブランチでのコンフリクトリスクが高いため、早期のマージまたはブランチ分割を推奨する
- **depends_on_artifacts**: []
