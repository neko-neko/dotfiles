---
phase: 4
name: plan-review
max_retries: 3
---

## Criteria

### D4-01: レビューが全3観点で実行された
- **severity**: quality
- **verify_type**: automated
- **verification**:
  レビュー結果ファイル（`artifacts/reviews/phase-4-review.json` またはレビューログ）を読み取り、3観点（clarity, feasibility, consistency）の実行記録を確認する。
- **pass_condition**: 3観点全ての実行記録が存在すること。記録された観点数が3
- **fail_diagnosis_hint**: 欠落している観点を特定し、/implementation-review の起動オプションを確認。観点の指定漏れか、レビューエージェントの実行途中中断かを切り分ける
- **depends_on_artifacts**: [artifacts/reviews/]

### D4-02: コンセンサス findings が全て解消済み
- **severity**: quality
- **verify_type**: automated
- **verification**:
  レビュー結果から severity: consensus の findings を抽出し、各 finding に対応する修正コミットまたは計画書内の対応記述を検索する。
- **pass_condition**: consensus findings の未解消件数が 0
- **fail_diagnosis_hint**: 未解消の finding ID を特定し、計画書の該当セクションを確認。修正が反映されていない場合は /implementation-review のフィードバックループが完了しているか確認する
- **depends_on_artifacts**: [artifacts/reviews/, docs/plans/*-plan.md]

### D4-03: 計画書と設計書の整合性が保たれている
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. 設計書の要件リストと計画書のタスクリストを並べて照合する
  2. 計画書で使用されているコンポーネント名、ファイルパス、データ型が設計書の定義と一致しているか確認する
  3. 計画書のタスク完了条件が設計書の要件を逸脱していないか（設計書にない機能の追加、設計書の制約の無視）確認する
  4. 設計書で定義されたインターフェース（関数シグネチャ、API エンドポイント等）が計画書で正しく参照されているか確認する
- **pass_condition**: 手順2でコンポーネント名/パス/型の不一致が0件、手順3で逸脱が0件、手順4で参照不整合が0件
- **fail_diagnosis_hint**: 不整合箇所の設計書側と計画書側の記述を並べ、レビュー修正で片方だけ更新されたケースを確認。`git log --oneline -- docs/plans/` で直近の変更履歴から原因を追跡する
- **depends_on_artifacts**: [docs/plans/*-design.md, docs/plans/*-plan.md]

### D4-04: 各タスクの完了条件が検証可能な形で記述されている
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. 計画書の各タスクから完了条件（done condition / acceptance criteria）を抽出する
  2. 各完了条件に主観語（「適切」「十分」「具体的」「正しい」）が含まれていないか確認する
  3. 各完了条件が以下のいずれかの形式で記述されているか確認する: ファイルの存在確認、コマンド実行結果の数値比較、パターンマッチ、状態の真偽判定
  4. 完了条件が記述されていないタスクがないか確認する
- **pass_condition**: 手順2で主観語を含む完了条件が0件、手順3で検証形式を満たさない完了条件が0件、手順4で完了条件なしのタスクが0件
- **fail_diagnosis_hint**: 主観語を含む完了条件は数値閾値やパターンマッチに書き換える。完了条件のないタスクは設計書の対応要件から導出する。検証不能な条件は「コマンド X の exit code が 0」「ファイル Y に文字列 Z が含まれる」等の形式に変換する
- **depends_on_artifacts**: [docs/plans/*-plan.md]
- **forward_check**: Phase 5 Executor がタスク完了を自己判定できる粒度であること
