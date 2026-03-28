---
phase: 7
name: smoke-test
max_retries: 3
---

## Criteria

### D7-01: 全スモークテストステップが PASS
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  スモークテスト結果ファイル（`artifacts/smoke-test/` 配下のログ/レポート）を読み取り、各ステップの PASS/FAIL ステータスを確認する。結果ファイルが存在しない場合はスモークテストを再実行する。
- **pass_condition**: 全ステップのステータスが PASS。FAIL ステップが0件
- **fail_diagnosis_hint**: FAIL したステップ名とエラーメッセージを確認。ブラウザ操作の失敗（セレクタ不一致、タイムアウト）か、アプリケーションエラー（HTTP 5xx、例外）かを切り分ける。`artifacts/smoke-test/screenshots/` のスクリーンショットがあれば画面状態を確認する
- **depends_on_artifacts**: [artifacts/smoke-test/]

### D7-02: flaky test が未検出または報告済み
- **severity**: quality
- **verify_type**: automated
- **verification**:
  スモークテスト結果ログを読み取り、同一ステップが再実行で結果が変わったケース（1回目 FAIL → 2回目 PASS、またはその逆）を検出する。検出された場合、flaky として報告リストに記録されているか確認する。
- **pass_condition**: flaky 検出件数が0件、または検出された全件が報告リストに記録済み
- **fail_diagnosis_hint**: flaky ステップを特定し、タイミング依存（setTimeout, アニメーション待ち）、外部サービス依存（API レスポンス遅延）、テストデータ依存（ランダムデータ）のいずれかを調査する
- **depends_on_artifacts**: [artifacts/smoke-test/]

### D7-03: テストシナリオがプロジェクト特性を反映している
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. Evidence Plan のプロジェクト特性（project_type, UI有無, API有無等）を読み取る
  2. スモークテストのシナリオリストを読み取る
  3. プロジェクト特性ごとの必須シナリオカテゴリが存在するか判定する:
     - web-frontend: ナビゲーション、フォーム操作、レスポンシブ表示の各カテゴリに1件以上のシナリオが存在するか
     - API: エンドポイントの正常レスポンス（2xx）、異常レスポンス（4xx/5xx）の各カテゴリに1件以上存在するか
     - DB: データの書き込み、読み取りの各カテゴリに1件以上存在するか
  4. 設計書の主要ユーザーフローを列挙し、各フローに対応するシナリオが1件以上存在するか照合する
- **pass_condition**: 手順3の全必須カテゴリにシナリオが1件以上存在し、かつ手順4の全ユーザーフローにシナリオが対応していること。カテゴリ欠落が0件、フロー未対応が0件
- **fail_diagnosis_hint**: 欠落しているカテゴリを特定し、該当カテゴリのスモークテストシナリオを追加する。ユーザーフロー未対応の場合は設計書の該当フローを参照してシナリオを作成する。Evidence Plan のプロジェクト特性が実態と異なる場合は Evidence Plan の更新を検討する
- **depends_on_artifacts**: [artifacts/smoke-test/, docs/plans/*-design.md]

### D7-04: スモークテスト実行証跡が有効である
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  以下の3点を機械的に検証する:
  1. `smoke-test-report.md` が作業ディレクトリに存在し、所定フォーマット（Step 2 テーブルに「シナリオ」「観点」「結果」「スクリーンショット」列が存在）に準拠している
  2. `smoke-*.png` ファイルが1枚以上存在する
  3. レポート内の Step 2 テーブルの「スクリーンショット」列が実在する `smoke-*.png` ファイルを参照している
- **pass_condition**: 3点すべてを満たすこと
- **fail_diagnosis_hint**:
  - レポート未存在 → smoke-test スキルが正しく実行されていない。既存テストスイート（rspec, jest 等）の実行で代替されていないか確認する。代替されていた場合、それは無効な実行であり、smoke-test スキルを正しく再実行する必要がある
  - フォーマット不備 → レポートを再生成する
  - スクリーンショット未存在 → browser-use CLI が実行されていない可能性。環境問題であれば PAUSE としてユーザーに報告する
- **depends_on_artifacts**: [smoke-test-report.md, smoke-*.png]
