---
phase: 8
name: integrate
max_retries: 3
---

## Criteria

### D8-01: ユーザーが統合方法を選択済み
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  オーケストレーターのセッション状態から、ユーザーが統合方法（merge, PR, branch-keep のいずれか）を選択したことを確認する。選択がない場合はユーザーに PAUSE して選択を促す。
- **pass_condition**: 統合方法の選択値が "merge", "pr", "branch-keep" のいずれかであること
- **fail_diagnosis_hint**: ユーザーへの選択肢提示が行われたか確認。提示されたが応答がない場合は PAUSE 状態を確認する
- **depends_on_artifacts**: []

### D8-02: 選択されたアクションが完了
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  選択された統合方法に応じて完了を確認する:
  - merge: `git log --oneline -1` でマージコミットが存在するか確認
  - pr: `gh pr view --json url` で PR URL が取得できるか確認
  - branch-keep: `git branch --list` で作業ブランチが存在するか確認
- **pass_condition**: merge の場合はマージコミットの存在、pr の場合は PR URL の取得成功、branch-keep の場合はブランチの存在。いずれか該当する1つが成立
- **fail_diagnosis_hint**: merge 失敗の場合はコンフリクトを確認（`git status`）。PR 作成失敗の場合は `gh auth status` で認証状態を確認。ブランチが存在しない場合は `git branch -a` で全ブランチを確認する
- **depends_on_artifacts**: []

### D8-03: マージコンフリクトがない + 未コミット変更がない
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  1. `git status --porcelain` を実行し、未コミット変更とコンフリクトマーカー（UU ステータス）を検出する
  2. `Grep("^<<<<<<<|^=======|^>>>>>>>")` で作業ツリー内のコンフリクトマーカー残存を検索する
- **pass_condition**: 手順1の出力が空（未コミット変更0件、コンフリクト0件）、かつ手順2の検出結果が0件
- **fail_diagnosis_hint**: コンフリクトがある場合は `git diff --diff-filter=U` で対象ファイルを特定。未コミット変更がある場合はコミット漏れか意図的な除外かを確認。コンフリクトマーカーが残存している場合はマージ解決の不完全を示す
- **depends_on_artifacts**: []
