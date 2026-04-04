---
name: spec-review
max_retries: 3
audit: required
---

## Criteria

### SPR-01: レビューが全4観点で実行された
- **severity**: quality
- **verify_type**: automated
- **verification**:
  レビュー結果ファイル（`artifacts/reviews/spec-review.json` またはレビューログ）を読み取り、4観点（requirements, design-judgment, feasibility, consistency）の実行記録を確認する。
- **pass_condition**: 4観点全ての実行記録が存在すること。記録された観点数が4
- **fail_diagnosis_hint**: 欠落している観点を特定し、/spec-review の起動オプションを確認。観点の指定漏れか、レビューエージェントの実行途中中断かを切り分ける
- **depends_on_artifacts**: [artifacts/reviews/]

### SPR-02: コンセンサス findings が全て解消済み
- **severity**: quality
- **verify_type**: automated
- **verification**:
  レビュー結果から severity: consensus の findings を抽出し、各 finding に対応する修正コミットまたは設計書内の対応記述を検索する。
- **pass_condition**: consensus findings の未解消件数が 0
- **fail_diagnosis_hint**: 未解消の finding ID を特定し、設計書の該当セクションを確認。修正が反映されていない場合は /spec-review のフィードバックループが完了しているか確認する
- **depends_on_artifacts**: [artifacts/reviews/, docs/plans/*-design.md]

### SPR-03: 指摘に基づく修正が設計書に反映されている
- **severity**: quality
- **verify_type**: inspection
- **verification**:
  1. レビュー結果の承認済み findings をリストアップする
  2. 各 finding の指摘内容と設計書の該当セクションを照合する
  3. 指摘内容に対応する変更が設計書のテキストに反映されているか判定する
- **pass_condition**: 承認済み findings 全件に対し、設計書内に対応する変更が存在すること。未反映件数が 0
- **fail_diagnosis_hint**: 未反映の finding を特定し、設計書の該当セクションと finding の指摘内容を並べて差分を確認。修正の適用漏れか、意図的なスキップかを判断する
- **depends_on_artifacts**: [artifacts/reviews/, docs/plans/*-design.md]

### SPR-04: 修正後の設計書が内部整合性を保っている
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. 設計書内で相互参照している箇所（要件番号、コンポーネント名、ファイルパス、データ型）をリストアップする
  2. 各参照先が設計書内に存在し、名称が一致しているか照合する
  3. 要件セクションで定義された機能が、設計セクションのコンポーネントで言及されているか確認する
  4. テスト観点セクションの対象が、要件セクションの機能と一致しているか確認する
- **pass_condition**: 手順2で全参照先が存在し名称が一致、手順3で全要件に対応コンポーネント記述あり、手順4でテスト観点の対象が要件と一致。不整合箇所が 0件
- **fail_diagnosis_hint**: 不整合箇所のセクション名と参照元/参照先を特定し、レビュー修正時に片方だけ更新して他方を更新し忘れたケースを確認。`git diff` で直近の変更差分から修正漏れを追跡する
- **depends_on_artifacts**: [docs/plans/*-design.md]
- **forward_check**: plan で設計要件をタスクに分解する際に、要件リストが一意に列挙可能であること

### SPR-05: 次フェーズの入力として要件が列挙可能な粒度まで具体化されている
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. 設計書の要件セクションから全要件を列挙する
  2. 各要件に一意の識別子（番号、ラベル等）が付与されているか確認する
  3. 各要件の記述に「何を」「どのように」が含まれているか確認する（入出力、振る舞い、制約のいずれかが記述されている）
  4. plan フェーズで「この要件からタスクを導出できる」か、要件の記述だけで判断する
- **pass_condition**: 全要件に識別子があり（手順2）、各要件に入出力・振る舞い・制約のいずれかが1つ以上記述されており（手順3）、識別子なし or 記述が曖昧な要件が 0件
- **fail_diagnosis_hint**: 識別子のない要件や、「何を」しか書かれていない要件を特定し、設計書の該当箇所に「どのように」の観点（入出力定義、振る舞い記述、制約条件）を追記する
- **depends_on_artifacts**: [docs/plans/*-design.md]
- **forward_check**: plan で設計要件からタスクへの分解が可能な粒度であること

## Observation Collection

phase-auditor は verdict 出力時に observations[] を必ず含めること。
PASS 判定の criteria でも quality/warning レベルの所見があれば記録する。
observations は project-state.json の phase_observations[] に蓄積される。
