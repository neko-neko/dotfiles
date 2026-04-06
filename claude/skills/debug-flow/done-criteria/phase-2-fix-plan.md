---
phase: 2
name: fix-plan
max_retries: 3
audit: required
---

## Criteria

### D2-01: 修正計画書ファイルが存在する
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  `Glob("docs/plans/YYYY-MM-DD-*-fix-plan.md")` で修正計画書ファイルを検索する。
- **pass_condition**: Glob 結果が1件以上
- **fail_diagnosis_hint**: Phase 2 Executor が修正計画書を `docs/plans/` 配下に出力しているか確認。ファイル名が `YYYY-MM-DD-*-fix-plan.md` パターンに合致しているか確認
- **depends_on_artifacts**: [docs/plans/]

### D2-02: RCA Report の Fix Strategy からタスクへのトレーサビリティ
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. RCA Report の Fix Strategy セクションから修正対象ファイル・関数をリストアップする
  2. 修正計画書のタスクセクションから全タスクを列挙する
  3. Fix Strategy の各修正対象に対し、計画書内に対応するタスクが1件以上存在するか照合する
  4. 対応タスクが存在しない修正対象をリストアップする
- **pass_condition**: 手順3で全修正対象に対応タスクが1件以上存在し、手順4のリストが0件
- **fail_diagnosis_hint**: 対応タスクのない修正対象を特定し、計画書にタスクの追加が必要。RCA Report の Fix Strategy と計画書のタスクIDの対応表を作成して漏れを可視化する
- **depends_on_artifacts**: [docs/debug/*-rca.md, docs/plans/*-fix-plan.md]

### D2-03: タスク粒度が sub-agent で実行可能
- **severity**: quality
- **verify_type**: inspection
- **verification**:
  1. 計画書の各タスクの記述量（行数）と含まれるステップ数をカウントする
  2. 1タスクあたりのステップ数が10以下であるか確認する
  3. 1タスクが複数の独立した機能変更を含んでいないか確認する（ファイル変更対象が3モジュール以上にまたがるタスクを検出）
- **pass_condition**: 全タスクのステップ数が10以下、かつ1タスクの変更対象モジュールが3未満。超過タスクが0件
- **fail_diagnosis_hint**: ステップ数超過のタスクを分割候補として特定。変更対象モジュールが多いタスクは、モジュール単位でのタスク分割を検討する
- **depends_on_artifacts**: [docs/plans/*-fix-plan.md]

### D2-04: タスク依存関係が明示かつ整合（循環なし）
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. 計画書から全タスクIDと各タスクの依存先タスクIDを抽出する
  2. 依存先として参照されるタスクIDが計画書内に全て存在するか確認する（存在しないID参照がないか）
  3. 依存グラフを構築し、循環依存がないか確認する（A→B→C→A のようなパスがないか）
  4. 依存関係が明示されていないタスク（依存先の記述がない）で、実際には他タスクの出力を前提としているものがないか確認する
- **pass_condition**: 手順2で不在ID参照が0件、手順3で循環パスが0件、手順4で暗黙依存が0件
- **fail_diagnosis_hint**: 循環依存が検出された場合はタスクの分割または依存方向の見直しが必要。不在ID参照はタイポか欠落タスクかを確認。暗黙依存はタスク間の入出力を明示化する
- **depends_on_artifacts**: [docs/plans/*-fix-plan.md]

### D2-05: テストケースが Given/When/Then で具体化
- **severity**: blocker
- **verify_type**: automated + inspection
- **verification**:
  1. 計画書のテストケースセクションを `Grep` で検索し、Given/When/Then パターンの有無を確認する
  2. 各テストケースに Given（前提条件）、When（操作）、Then（期待結果）が全て含まれているか確認する
  3. Then 句に数値閾値またはパターンマッチ可能な期待値が記述されているか確認する
- **pass_condition**: 全テストケースが Given/When/Then の3要素を含み（手順2）、Then 句に検証可能な期待値を持つこと（手順3）。3要素欠落のテストケースが0件
- **fail_diagnosis_hint**: Given/When/Then が欠落しているテストケースを特定し、RCA Report のテスト観点を参照して具体的な前提条件・操作・期待結果を補完する
- **depends_on_artifacts**: [docs/plans/*-fix-plan.md]
- **forward_check**: Phase 4 でテストコード実装時に、Given/When/Then から直接テストコードに変換可能であること

### D2-06: 修正計画書が git commit 済み
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  `git status --porcelain -- docs/plans/*-fix-plan.md` を実行し、修正計画書ファイルが未コミット変更リストに含まれないことを確認する。
- **pass_condition**: `git status --porcelain` の出力に修正計画書パスが含まれないこと（出力行数 0）
- **fail_diagnosis_hint**: 修正計画書が未コミットの場合、`git add` + `git commit` が実行されていない可能性がある。Phase 2 Executor の最終ステップでコミット処理を確認する
- **depends_on_artifacts**: [docs/plans/*-fix-plan.md]

## Observation Collection

phase-auditor は verdict 出力時に observations[] を必ず含めること。
PASS 判定の criteria でも quality/warning レベルの所見があれば記録する。
observations は project-state.json の phase_observations[] に蓄積される。
