---
phase: 8
name: code-review
max_retries: 3
audit: required
---

## Criteria

### D8-01: レビューが全7観点で実行された
- **severity**: quality
- **verify_type**: automated
- **verification**:
  レビュー結果ファイル（`artifacts/reviews/phase-8-review.json` またはレビューログ）を読み取り、7観点（simplify, code-quality, code-security, code-performance, code-test, ai-antipattern, code-impact）の実行記録を確認する。
- **pass_condition**: 7観点全ての実行記録が存在すること。記録された観点数が7
- **fail_diagnosis_hint**: 欠落している観点を特定し、/code-review の起動オプションを確認。観点の指定漏れか、レビューエージェントの実行途中中断かを切り分ける
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
- **depends_on_artifacts**: [artifacts/reviews/, src/]

### D8-03: 未コミット変更なし + ブランチが最新 main から乖離 50 commit 以内
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  1. `git status --porcelain` を実行し、未コミット変更を検出する
  2. `git rev-list --count HEAD ^main` を実行し（main が存在しない場合は master）、ブランチの乖離コミット数を取得する
- **pass_condition**: 手順1の出力が空（未コミット変更0件）、かつ手順2のコミット数が50以下
- **fail_diagnosis_hint**: 未コミット変更がある場合は `git add` + `git commit` の実行漏れを確認。乖離が50超の場合は main ブランチとの rebase を検討。長期ブランチでのコンフリクトリスクが高いため、早期のマージまたはブランチ分割を推奨する
- **depends_on_artifacts**: []

### D8-04: impact severity high 以上の findings がユーザー判断を経ている
- **severity**: blocker
- **verify_type**: automated + inspection
- **verification**:
  1. レビュー結果ファイルから category: code-impact かつ severity: high または critical の findings を抽出する
  2. 該当 findings が0件の場合 → PASS
  3. 該当 findings が1件以上の場合、各 finding について以下のいずれかの記録があるか確認する:
     a. 修正済み: 対応するコード変更がコミットに含まれる
     b. ユーザー明示承認の延期: ユーザーの承認発言が会話ログに存在する
     c. ユーザー承認の却下: 誤検出の根拠がユーザーに提示され、ユーザーが却下を承認している
  4. オーケストレーターが自己判断で延期・却下した findings（ユーザー確認なし）がないか確認する
- **pass_condition**: 手順3の全 findings がa/b/cのいずれかに該当し、手順4でユーザー未確認の延期/却下が0件
- **fail_diagnosis_hint**: ユーザー未確認の findings を特定し、PAUSE してユーザーに判断を求める。オーケストレーターが自動延期した findings がないか確認する
- **depends_on_artifacts**: [artifacts/reviews/]

## Observation Collection

phase-auditor は verdict 出力時に observations[] を必ず含めること。
PASS 判定の criteria でも quality/warning レベルの所見があれば記録する。
observations は project-state.json の phase_observations[] に蓄積される。
