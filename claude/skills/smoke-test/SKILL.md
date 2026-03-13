---
name: smoke-test
description: >-
  Playwright ベースのローカルスモークテスト。dev サーバー起動 → アドホックテスト生成・実行 →
  VRT 差分チェック → E2E 実行 + フレーキー検出の4ステップを実行する。
  単体でも他のワークフローからの invoke でも利用可能。
user-invocable: true
---

# Smoke Test

ローカル環境で Playwright を使い、実装した機能の動作確認・VRT 差分チェック・E2E フレーキー検出を自律的に実行する。

**開始時アナウンス:** 「Smoke Test を開始します。Step 1: Environment Setup」

## 引数

| 引数 | 説明 |
|------|------|
| (なし) | 全ステップ実行（自動検出） |
| `--diff-base <branch>` | 差分取得のベースブランチを指定 |
| `--design <path>` | 設計書パスを指定（アドホックテスト生成の精度向上） |
| `--server "<cmd>" --port <N>` | サーバー起動コマンドとポートを明示指定 |
| `--skip-vrt` | Step 3（VRT 差分チェック）をスキップ |
| `--skip-e2e` | Step 4（E2E 実行 + フレーキー検出）をスキップ |
| `--adhoc-only` | Step 2 のみ実行（`--skip-vrt --skip-e2e` と同等） |
| `--full-e2e` | 全 E2E テストを2回実行（デフォルトは変更関連のみ） |

## 出力

- **終了ステータス:** PASS / FAIL / PAUSE
- **レポート:** smoke-test-report.md（作業ディレクトリ、コミット対象外）
- **副作用:** VRT ベースライン更新時のみコミット（ユーザー承認後）

---

## Step 1: Environment Setup

Dev サーバーを起動しアクセス可能にする。

### サーバー起動コマンドの決定

`--server` / `--port` が引数で指定されている場合はそのまま使用する。

指定がない場合、以下の順序で自動検出する。

| 検出対象 | 条件 | コマンド | デフォルトポート |
|---------|------|---------|---------------|
| package.json | `scripts.dev` が存在 | `npm run dev` | 3000 or 5173 |
| package.json | `scripts.start` が存在（dev がない場合） | `npm start` | 3000 |
| Makefile | `dev` ターゲットが存在 | `make dev` | 8080 |
| Makefile | `serve` ターゲットが存在（dev がない場合） | `make serve` | 8080 |
| manage.py | ファイルが存在 | `python manage.py runserver` | 8000 |
| docker-compose.yml | ファイルが存在 | `docker compose up` | 最初の ports マッピング |

検出できない場合: AskUserQuestion で確認する。回答なし → PAUSE。

### サーバー起動と確認

サーバー起動には webapp-testing スキルの `with_server.py` パターンを活用する。

起動確認: Playwright で `localhost:<port>` にアクセスし、`networkidle` 待機する。30秒タイムアウト → PAUSE。

**アナウンス:** 「Step 1 完了。サーバー起動確認済み (port: <N>)。Step 2: Ad-hoc Smoke Test に進みます」

---

## Step 2: Ad-hoc Smoke Test

設計書と実装差分からスモークテストシナリオを自動生成・実行する。

### 差分取得

| 条件 | diff コマンド |
|------|-------------|
| `--diff-base <branch>` 指定 | `git diff <branch>...HEAD` |
| (なし) | `git diff HEAD~1` |

`--design <path>` 指定時は設計書も Read で読み込み、シナリオ生成の精度を向上させる。

### シナリオ生成

以下の4観点でシナリオを生成する。

1. **ナビゲーション確認** — ページ遷移・表示が正常であること
2. **ユーザーインタラクション** — クリック、入力、フォーム送信が動作すること
3. **エラー不在確認** — コンソールエラー・ネットワークエラーが発生しないこと
4. **レスポンシブ確認** — desktop: 1280x720, mobile: 375x667 の両方で表示が崩れないこと

### 実行

Playwright Python スクリプトとして `/tmp/smoke-test-<timestamp>/` に生成する（1シナリオ = 1ファイル）。

各ステップでスクリーンショットを取得する。

失敗時: スクリプトを修正し再実行する（最大2回）。2回失敗 → FAIL。

**アナウンス:** 「Step 2 完了。<N>/<M> シナリオ PASS。Step 3: VRT Diff Check に進みます」

---

## Step 3: VRT Diff Check

`--skip-vrt` 指定時はスキップする。

### VRT 設定の自動検出

| 検出対象 | 判定条件 | 実行コマンド |
|---------|---------|------------|
| Playwright snapshots | `playwright.config.*` に `toMatchSnapshot` or `snapshotDir` 設定 | `npx playwright test --grep snapshot` |
| reg-suit | `.reg/` or `regconfig.json` 存在 | `npx reg-suit run` |
| Storycap + reg-suit | `storycap` が devDependencies | `npx storycap && npx reg-suit run` |
| Loki | `loki` が devDependencies or `.lokirc` 存在 | `npx loki test` |
| Percy | `@percy/cli` が devDependencies | スキップ（CI 専用） |

未検出 → スキップ。

### 差分発生時の対応

差分あり → 差分画像を Read で提示 → AskUserQuestion で更新確認:

- **承認** → ベースライン更新 & コミット
- **拒否** → レポートに記録のみ

**アナウンス:** 「Step 3 完了。VRT: <PASS/SKIP/DIFF_DETECTED>。Step 4: E2E + Flaky Detection に進みます」

---

## Step 4: E2E + Flaky Detection

`--skip-e2e` 指定時はスキップする。

### E2E テストスイート自動検出

| 検出対象 | 判定条件 | 実行コマンド |
|---------|---------|------------|
| Playwright | `playwright.config.*` 存在 | `npx playwright test` |
| Cypress | `cypress.config.*` 存在 | `npx cypress run` |
| その他 | `package.json` の `scripts.test:e2e` 存在 | `npm run test:e2e` |

未検出 → スキップ。

### テスト対象の決定

| 条件 | 対象 |
|------|------|
| `--full-e2e` | 全テストファイル |
| デフォルト | 変更関連のみ |

デフォルトの変更関連テスト特定: `git diff` で変更ファイルを取得し、`*.spec.ts`, `*.e2e.ts`, `*.test.ts` を抽出する。ソースファイルに対応するテストファイルも検索する。特定できない場合はフルスイートを1回実行し、失敗テストのみ再実行する。

### フレーキー検出

2回実行して結果を比較する。

| 1回目 | 2回目 | 判定 | アクション |
|-------|-------|------|----------|
| PASS | PASS | 安定 | 通過 |
| FAIL | FAIL | 実装起因 | FAIL。修正提案を生成 |
| PASS | FAIL | フレーキー | 報告のみ（ブロックしない） |
| FAIL | PASS | フレーキー | 報告のみ（ブロックしない） |

### フレーキーテスト報告

フレーキー検出時、以下を報告する。

- テスト名・パス
- エラーメッセージ・スタックトレース
- 推定原因（タイミング依存 / 外部依存 / 非決定的データ / DOM 状態依存）
- 修正提案

### 実装起因の失敗

レポートに記録する。修正提案を生成する。FAIL ステータスとする。

**アナウンス:** 「Step 4 完了。E2E: <PASS/FAIL/SKIP>。レポート生成に進みます」

---

## Report Generation

全ステップ完了後に `smoke-test-report.md` を作業ディレクトリに生成する。

### レポートフォーマット

```markdown
# Smoke Test Report

**Date:** YYYY-MM-DD HH:MM
**Diff Base:** <branch or HEAD~1>
**Server:** <command> (port: <N>)
**Status:** PASS / FAIL / PAUSE

## Step 2: Ad-hoc Smoke Test

| シナリオ | 観点 | 結果 | スクリーンショット |
|---------|------|------|-----------------|
| ... | ... | PASS/FAIL | パス |

## Step 3: VRT Diff Check

SKIP / PASS / DIFF_DETECTED

## Step 4: E2E + Flaky Detection

### Test Results
| テスト | 1回目 | 2回目 | 判定 |
|-------|-------|-------|------|
| ... | PASS/FAIL | PASS/FAIL | 安定/実装起因/フレーキー |

### Flaky Tests
| テスト | 推定原因 | 修正提案 |
|-------|---------|---------|
| ... | ... | ... |

### Implementation Failures
| テスト | エラー | 修正提案 |
|-------|--------|---------|
| ... | ... | ... |
```

### Overall Status

| Condition | Status |
|-----------|--------|
| 全ステップ PASS（フレーキー許容） | PASS |
| Step 2 が2回リトライ後も失敗 | FAIL |
| Step 4 で実装起因の失敗（2回とも FAIL） | FAIL |
| サーバー起動不可 | PAUSE |
| フレーキーのみ検出（他は PASS） | PASS（レポートに記録） |

---

## Error Handling

| Step | エラー | リカバリ |
|------|--------|---------|
| 1 | サーバー起動コマンド検出不可 | AskUserQuestion → 回答なし → PAUSE |
| 1 | サーバー起動タイムアウト（30秒） | PAUSE |
| 2 | Playwright スクリプト実行エラー | 修正 → 再実行（最大2回） |
| 2 | アプリケーションバグ | レポートに記録、FAIL |
| 3 | VRT コマンド実行エラー | レポートに記録、スキップ |
| 4 | E2E テスト実行エラー（テスト外の問題） | レポートに記録、スキップ |
| 全体 | Playwright 未インストール | インストール提案、PAUSE |

---

## Red Flags

### Never

- スモークテスト失敗を黙って PASS にする
- VRT ベースラインをユーザー承認なしに更新する
- フレーキーテストを実装バグとして FAIL にする
- feature-dev の内部状態（artifacts, phase 番号等）に直接アクセスする

### Always

- Step 遷移時にアナウンスする
- スクリーンショットを取得しレポートに含める
- フレーキーテストには推定原因と修正提案を付ける
- サーバープロセスを確実にクリーンアップする
