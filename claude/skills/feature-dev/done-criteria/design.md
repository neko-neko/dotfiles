---
name: design
max_retries: 3
audit: required
---

## Criteria

### DSN-01: 設計書ファイルが存在する
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  `Glob("docs/plans/YYYY-MM-DD-*-design.md")` で設計書ファイルを検索する。
- **pass_condition**: Glob 結果が1件以上
- **fail_diagnosis_hint**: 当フェーズ Executor が設計書を `docs/plans/` 配下に出力しているか確認。ファイル名が `YYYY-MM-DD-*-design.md` パターンに合致しているか確認
- **depends_on_artifacts**: [docs/plans/]
- **forward_check**: spec-review の入力として設計書パスが渡される

### DSN-02: 必須セクションが実質的な内容を持つ
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  Investigation Record の各サブセクションを順に読み、以下を判定:
  1. prerequisites: 依存ライブラリ名/バージョン or ファイルパスの記述が1件以上含まれるか
  2. impact_scope: 変更対象モジュール/ファイルが1件以上列挙されているか
  3. reverse_dependencies: 変更を参照する側のコードが1件以上特定されているか
  4. shared_state: グローバル状態・DB・キャッシュ等への影響が記述されているか（影響がない場合は「なし」の明記でも可）
  5. implicit_contracts: 暗黙の前提条件が1件以上列挙されているか
  6. side_effect_risks: 副作用の可能性とその軽減策が1組以上記述されているか
- **pass_condition**: 上記6項目全てが各基準を満たすこと。見出しのみ・汎用的な記述のみの項目が0件
- **fail_diagnosis_hint**: FAIL した項目番号を特定し、設計書の Investigation Record セクションで該当サブセクションの内容を確認。impact-analyzer の出力結果と照合して不足情報を補完する
- **depends_on_artifacts**: [docs/plans/*-design.md]

### DSN-03: 影響範囲がコードベースと整合している
- **severity**: blocker
- **verify_type**: automated + inspection
- **verification**:
  1. 設計書の impact_scope に列挙されたファイル/ディレクトリパスを抽出する
  2. 各パスに対して `Glob` でファイルの存在を確認する
  3. 存在しないパスがある場合、新規作成予定か設計書に明記されているか確認する
- **pass_condition**: 列挙された全パスが Glob で存在するか、または設計書内で新規作成予定として明記されていること。存在せず新規作成の明記もないパスが0件
- **fail_diagnosis_hint**: 存在しないパスをリストアップし、タイポか新規作成ファイルの記載漏れかを確認。コードベースの最新状態と設計書の記述時点の差異も確認する
- **depends_on_artifacts**: [docs/plans/*-design.md]

### DSN-04: テスト観点が4区分x各2件以上
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  設計書のテスト観点セクションを読み取り、4区分（正常系、異常系、エッジケース、非機能）それぞれの件数をカウントする。`Grep` で各区分の見出しまたはラベルを検索し、配下の項目数を数える。
- **pass_condition**: 4区分全てにおいて項目が2件以上。合計8件以上
- **fail_diagnosis_hint**: 不足している区分を特定し、設計書のテスト観点セクションに追記が必要。正常系/異常系が不足する場合は要件定義を、エッジケースが不足する場合は境界値を、非機能が不足する場合はパフォーマンス/セキュリティを検討する
- **depends_on_artifacts**: [docs/plans/*-design.md]

### DSN-05: 代替案が検討されている
- **severity**: quality
- **verify_type**: inspection
- **verification**:
  1. 設計書内に「代替案」「Alternative」「Option」等のセクションまたは記述を検索する
  2. 代替案が記述されている場合、各案に採用/不採用の理由が付記されているか確認する
- **pass_condition**: 代替案セクションが存在し、各案に理由（1文以上）が付記されていること。代替案なしの場合は「代替案なし」の理由が明記されていること
- **fail_diagnosis_hint**: 設計書に代替案セクションが見つからない場合は追記を検討。理由が付記されていない場合はトレードオフ観点（コスト、複雑度、保守性）で補足する
- **depends_on_artifacts**: [docs/plans/*-design.md]

### DSN-06: worktree 作成済み + ベースラインテスト通過
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  1. `git worktree list` を実行し、現在のブランチがメインブランチ以外の worktree であることを確認
  2. テストコマンド（package.json の test スクリプト、Cargo test、pytest 等）を実行し、exit code を記録する
- **pass_condition**: worktree が存在し（`git worktree list` の出力行数が2以上）、テストコマンドの exit code が 0
- **fail_diagnosis_hint**: worktree が存在しない場合は `wt switch -c` の実行を確認。テスト失敗の場合はベースブランチ（main/master）に未修正の既存テスト失敗がないか `git stash && テスト実行` で切り分ける
- **depends_on_artifacts**: []

### DSN-07: 設計書が git commit 済み
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  `git status --porcelain -- docs/plans/*-design.md` を実行し、設計書ファイルが未コミット変更リストに含まれないことを確認する。
- **pass_condition**: `git status --porcelain` の出力に設計書パスが含まれないこと（出力行数 0）
- **fail_diagnosis_hint**: 設計書が未コミットの場合、`git add` + `git commit` が実行されていない可能性がある。当フェーズ Executor の最終ステップでコミット処理を確認する
- **depends_on_artifacts**: [docs/plans/*-design.md]

## Observation Collection

phase-auditor は verdict 出力時に observations[] を必ず含めること。
PASS 判定の criteria でも quality/warning レベルの所見があれば記録する。
observations は project-state.json の phase_observations[] に蓄積される。
