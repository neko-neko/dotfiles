---
name: evidence-catalog
description: エビデンスカタログ。Audit Agent が Evidence Plan 生成時に参照する全エビデンス種別と適用条件の定義。
---

# Evidence Catalog

Evidence Plan 生成時に Audit Agent が参照するカタログ。各エビデンスの適用条件は observable な事実（glob/grep で検証可能）に基づく。

## Activity Types

| Activity | Description |
|----------|------------|
| implementation | コード実装を行うステップ |
| smoke-test | 動作確認を行うステップ |
| review-fix | レビュー指摘の修正を行うステップ |
| test-fix | テスト追加/修正を行うステップ |
| integration | コードの統合を行うステップ |

## Evidence Layers

- **Claimed (Layer 1)**: Executor が収集・保存するファイル。「こうなりました」の記録。
- **Verified (Layer 2)**: Audit Agent が独立に確認する検証。「本当にそうなっているか」の検証。

## Universal（全プロジェクト共通）

### E-TEST: テスト実行ログ
- **applies_to**: [implementation, review-fix, test-fix]
- **condition**: always
- **claimed**: `artifacts/test-results/phase-{N}-test.log`
- **verified**: テストコマンドを自ら再実行し、結果を照合
- **required_capabilities**: [bash]
- **collection**: テスト実行コマンドの stdout/stderr をファイルにリダイレクト

### E-BUILD: ビルドログ
- **applies_to**: [implementation]
- **condition**: always
- **claimed**: `artifacts/build/phase-{N}-build.log`
- **verified**: ビルドコマンドを自ら再実行し exit code 0 を確認
- **required_capabilities**: [bash]
- **collection**: ビルドコマンドの stdout/stderr をファイルにリダイレクト

### E-LINT: lint/型チェックログ
- **applies_to**: [implementation, review-fix]
- **condition**: always
- **claimed**: `artifacts/lint/phase-{N}-lint.log`
- **verified**: linter を自ら再実行し結果を照合
- **required_capabilities**: [bash]
- **collection**: linter の stdout/stderr をファイルにリダイレクト

### E-REVIEW: レビュー結果
- **applies_to**: [review-fix, test-fix]
- **condition**: always
- **claimed**: `artifacts/reviews/phase-{N}-review.json`
- **verified**: N/A（レビュー結果自体の再実行は非現実的）
- **required_capabilities**: []
- **collection**: レビューエージェントの出力を JSON に集約して保存

### E-DIFF: git diff スナップショット
- **applies_to**: [implementation, review-fix, test-fix]
- **condition**: always
- **claimed**: `artifacts/diff/phase-{N}.diff`
- **verified**: `git diff` を自ら再取得し一致を確認
- **required_capabilities**: [bash]
- **collection**: `git diff > artifacts/diff/phase-{N}.diff`

### E-TRACE: トレーサビリティマトリクス
- **applies_to**: [implementation]
- **condition**: always
- **claimed**: `artifacts/traceability/phase-{N}-trace.md`
- **verified**: 設計書要件と実装ファイルの対応を独立に検証
- **required_capabilities**: [bash]
- **collection**: 設計書の要件リストと実装ファイルの対応表を生成

## Conditional（プロジェクト特性で有効化）

### E-SCREENSHOT: 画面スクリーンショット
- **applies_to**: [smoke-test]
- **condition**:
  - require_all:
    - `glob("**/*.{html,jsx,tsx,vue,svelte}")` の結果が1件以上
    - 設計書に「画面」「ページ」「UI」「コンポーネント」のいずれかの記述がある
- **claimed**: `artifacts/smoke-test/screenshots/{screen}_{state}.png`
- **verified**: 同じ URL にブラウザでアクセスしページが表示されるか確認
- **required_capabilities**: [browser-automation]
- **variants**: [desktop, mobile]
- **if_unavailable**: skip_with_warning
- **collection**: ブラウザ自動化ツールでスクリーンショットを撮影

### E-SCREENSHOT-MOBILE: モバイルスクリーンショット
- **applies_to**: [smoke-test]
- **condition**:
  - require_all:
    - E-SCREENSHOT が有効
    - 設計書に「responsive」「モバイル」「mobile」のいずれかの記述がある
- **claimed**: `artifacts/smoke-test/screenshots/{screen}_{state}_mobile.png`
- **verified**: モバイルビューポート（≤428px幅）でアクセスし表示確認
- **required_capabilities**: [browser-automation]
- **if_unavailable**: skip_with_warning
- **collection**: モバイルビューポートでスクリーンショットを撮影

### E-API-LOG: API レスポンスログ
- **applies_to**: [implementation, smoke-test]
- **condition**:
  - `grep -r "router\|app\.\(get\|post\|put\|delete\)\|@app\.route\|@router" **/*.{ts,js,py,go,rb}` の結果が1件以上
- **claimed**: `artifacts/api/phase-{N}-api.log`
- **verified**: エンドポイントに HTTP リクエストを送信しレスポンスを確認
- **required_capabilities**: [bash]
- **if_unavailable**: skip_with_warning
- **collection**: curl/httpie でエンドポイントを叩き結果をログに保存

### E-MIGRATION: DB マイグレーションログ
- **applies_to**: [implementation]
- **condition**:
  - `glob("**/migrations/**/*")` または `glob("**/migrate/**/*")` の結果が1件以上
- **claimed**: `artifacts/migration/phase-{N}-migration.log`
- **verified**: DB に接続しマイグレーション対象のテーブル/カラムが存在するか確認
- **required_capabilities**: [database-access]
- **if_unavailable**: manual_fallback
- **collection**: マイグレーションコマンドの出力をログに保存

### E-PERF: パフォーマンスメトリクス
- **applies_to**: [smoke-test]
- **condition**:
  - 設計書に「性能」「パフォーマンス」「performance」「latency」「throughput」のいずれかの記述がある
- **claimed**: `artifacts/perf/phase-{N}-perf.log`
- **verified**: 負荷テストを自ら再実行し結果を照合
- **required_capabilities**: [bash]
- **if_unavailable**: skip_with_warning
- **collection**: 負荷テストツールの出力をログに保存

### E-CONSOLE: ブラウザコンソールログ
- **applies_to**: [smoke-test]
- **condition**:
  - E-SCREENSHOT が有効
- **claimed**: `artifacts/smoke-test/console.log`
- **verified**: ページアクセス時のコンソール出力を取得し error レベルがないか確認
- **required_capabilities**: [browser-automation]
- **if_unavailable**: skip_with_warning
- **collection**: ブラウザ自動化ツールでコンソールログをキャプチャ

## if_unavailable Policies

- **skip_with_warning**: エビデンスを除外し、ユーザーに警告。verdict に影響しない
- **manual_fallback**: ユーザーに手動収集を依頼。PAUSE してユーザーがエビデンスを提供するのを待つ
