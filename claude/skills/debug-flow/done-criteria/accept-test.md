---
phase: 5
name: accept-test
max_retries: 3
audit: required
---

## Criteria

### D5-01: 全 Acceptance Test ステップが PASS
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  Acceptance Test 結果ファイル（`artifacts/accept-test/` 配下のログ/レポート）を読み取り、各ステップの PASS/FAIL ステータスを確認する。結果ファイルが存在しない場合は Acceptance Test を再実行する。
- **pass_condition**: 全ステップのステータスが PASS。FAIL ステップが0件
- **fail_diagnosis_hint**: FAIL したステップ名とエラーメッセージを確認。プロジェクト種別に応じて: Web → セレクタ不一致/タイムアウト/HTTP エラーを切り分け。Mobile → シミュレータ起動失敗/UI 要素未検出を切り分け。CLI → コマンド exit code/stdout 不一致を確認
- **depends_on_artifacts**: [artifacts/accept-test/]

### D5-02: flaky test が未検出または報告済み
- **severity**: quality
- **verify_type**: automated
- **verification**:
  Acceptance Test 結果ログを読み取り、同一ステップが再実行で結果が変わったケース（1回目 FAIL → 2回目 PASS、またはその逆）を検出する。検出された場合、flaky として報告リストに記録されているか確認する。
- **pass_condition**: flaky 検出件数が0件、または検出された全件が報告リストに記録済み
- **fail_diagnosis_hint**: flaky ステップを特定し、タイミング依存、外部サービス依存、テストデータ依存のいずれかを調査する
- **depends_on_artifacts**: [artifacts/accept-test/]

### D5-03: テストシナリオがプロジェクト特性を反映している
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
  4. RCA Report の主要影響フローを列挙し、各フローに対応するシナリオが1件以上存在するか照合する
- **pass_condition**: 手順3の全必須カテゴリにシナリオが1件以上存在し、かつ手順4の全ユーザーフローにシナリオが対応していること
- **fail_diagnosis_hint**: 欠落しているカテゴリを特定し、該当カテゴリの Acceptance Test シナリオを追加する
- **depends_on_artifacts**: [artifacts/accept-test/, docs/plans/*-rca.md]

### D5-04: Acceptance Test 実行証跡が有効である
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

## Observation Collection

phase-auditor は verdict 出力時に observations[] を必ず含めること。
PASS 判定の criteria でも quality/warning レベルの所見があれば記録する。
observations は project-state.json の phase_observations[] に蓄積される。
