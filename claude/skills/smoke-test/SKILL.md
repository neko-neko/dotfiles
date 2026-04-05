---
name: smoke-test
description: >-
  ローカルスモークテスト。dev サーバー起動 → アドホックテスト生成・実行 →
  VRT 差分チェック → E2E 実行 + フレーキー検出の4ステップを実行する。
  単体でも他のワークフローからの invoke でも利用可能。
skills: [agent-browser]
user-invocable: true
---

# Smoke Test

起動時に `/agent-browser` をinvokeする。実装した機能の動作確認・VRT 差分チェック・E2E フレーキー検出を自律的に実行する。

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
| `--perspectives <list>` | カンマ区切りで追加テスト観点を指定（standalone 用）。値: security, performance, coverage |

## 出力

- **終了ステータス:** PASS / FAIL / PAUSE
- **レポート:** smoke-test-report.md（作業ディレクトリ、コミット対象外）
- **副作用:** VRT ベースライン更新時のみコミット（ユーザー承認後）

## Verification Doctrine

Smoke Test は「たぶん動く」を確認する手順ではない。変更を直接動かし、壊れ方まで含めて検証する独立 verification である。

- browser-use による実操作を必須とし、既存テストスイートを代替にしない
- happy path だけでなく、少なくとも1件は adversarial probe を含める
- PASS を出すには、実行したコマンド / 操作内容 / 観測結果をレポートに残す
- 環境要因で実行不能な場合のみ PAUSE とし、未確認を PASS にしない

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

サーバー起動にはバックグラウンドプロセスとして起動する（`run_in_background: true`）。

起動確認: browser-use CLI でサーバーにアクセスし、ページ読み込みとページ要素の取得を確認する。30秒タイムアウト → PAUSE。

**アナウンス:** 「Step 1 完了。サーバー起動確認済み (port: <N>)。Step 2: Ad-hoc Smoke Test に進みます」

---

## Step 2: Ad-hoc Smoke Test

設計書と実装差分からスモークテストシナリオを自動生成し、Browser Use CLI で直接実行する。

### 前提条件チェック

browser-use CLI がインストールされているか確認する。未インストールの場合は PAUSE し、インストール方法を案内する。

### 差分取得

| 条件 | diff コマンド |
|------|-------------|
| `--diff-base <branch>` 指定 | `git diff <branch>...HEAD` |
| (なし) | `git diff HEAD~1` |

`--design <path>` 指定時は設計書も Read で読み込み、Impact Analysis セクションを抽出してシナリオ生成の精度と影響範囲テストに活用する。

### テスト観点拡張

基本の5観点に加え、以下の方法でテスト観点を動的に拡張する。

#### パイプライン経由（`--design` 指定時）

設計書から以下を抽出し、シナリオ生成の入力に追加する:

| 抽出対象 | 設計書内の位置 | 用途 |
|---------|--------------|------|
| テスト観点セクション | 「テスト観点」or 「Test Perspectives」 | シナリオの網羅性を拡張 |
| Must-Verify Checklist | Investigation Record 内 | 必須検証項目としてシナリオ化 |
| Impact Analysis | Reverse Dependencies / Side Effect Risks | 影響波及テスト（観点5）を強化 |

#### スタンドアロン（`--perspectives` 指定時）

各 perspective に対応するエージェントを Agent ツールで並列起動し、diff を渡してスモークテストで検証すべき観点を収集する。

| perspective | エージェント | 収集する観点 |
|-------------|------------|-------------|
| security | `subagent_type: "code-review-security"` | XSS, CSRF, 認証バイパス, インジェクション |
| performance | `subagent_type: "code-review-performance"` | レンダリング速度, 大量データ表示, N+1 |
| coverage | `subagent_type: "test-review-coverage"` | 境界値, エラーパス, 状態遷移網羅 |

**エージェントへの共通プロンプト構造:**

> 以下の diff に対して、{perspective} の観点からスモークテストで
> ブラウザ操作を通じて検証すべき項目を列挙してください。
> コードレベルの指摘ではなく、ユーザー操作で確認可能な項目に限定すること。
>
> [diff]
>
> 出力: テスト観点のリスト（各項目: 観点名、検証内容、優先度 high/medium）

収集した観点はシナリオ生成の入力に統合する。

#### 両方指定時

設計書の観点 + perspectives エージェントの観点を統合する。同一の検証内容を指す観点が重複した場合、設計書側の記述を採用し、エージェント側は除外する。

### シナリオ生成

以下の5観点でシナリオを自然言語で生成する。

1. **ナビゲーション確認** — ページ遷移・表示が正常であること
2. **ユーザーインタラクション** — クリック、入力、フォーム送信が動作すること
3. **エラー不在確認** — コンソールエラー・ネットワークエラーが発生しないこと
4. **レスポンシブ確認** — desktop: 1280x720, mobile: 375x667 の両方で表示が崩れないこと
5. **影響波及テスト** — Impact Analysis の Reverse Dependencies / Side Effect Risks に基づき、変更の波及先が正常に動作すること

加えて、上記から最低1件は adversarial probe を選定または追加する。例:
- 空入力 / 異常入力
- 同じ操作の連続実行（idempotency）
- 存在しない対象への遷移・操作
- refresh / relaunch 後の状態保持確認
- 変更箇所以外の依存画面・導線の逆方向確認

### 実行

`skills: [browser-use]` により注入された browser-use CLI の知識を使い、各シナリオを検証する。

各シナリオは **reconnaissance-then-action** で実行する:
先にページ状態を取得し、要素を確認してから操作する。
遷移後・操作後は状態が安定するまで待機してから次の検証に進む。

**実行フロー（各シナリオ）:**
1. 対象ページに遷移
2. ページ状態を取得（reconnaissance）
3. 操作を実行（action）
4. 操作結果を確認
5. スクリーンショットを `smoke-<scenario_name>.png` として保存
6. browser-use の実行内容、観測結果、スクリーンショットから PASS/FAIL を判定

各シナリオについて、レポートには少なくとも以下を残す:
- check 名
- 実行コマンドまたは browser-use invocation
- 実際に観測した結果
- PASS/FAIL 判定

**失敗時:** シナリオを修正し再実行する（最大2回）。2回失敗 → FAIL。

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

### Evidence Log

#### Check: <scenario>
- Command run: <browser-use invocation or equivalent>
- Output observed: <state / key observation / console / network summary>
- Result: PASS / FAIL

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

### Verification Notes
- Adversarial probe executed: <yes/no + summary>
- Environment limitations: <none or details>
```

### Overall Status

| Condition | Status |
|-----------|--------|
| 全ステップ PASS（フレーキー許容） | PASS |
| Step 2 が2回リトライ後も失敗 | FAIL |
| Step 2 で adversarial probe が未実行 | FAIL |
| Step 4 で実装起因の失敗（2回とも FAIL） | FAIL |
| サーバー起動不可 | PAUSE |
| フレーキーのみ検出（他は PASS） | PASS（レポートに記録） |

---

## Execution Evidence

スモークテストの有効な実行を証明するため、以下のアーティファクトが**必須**で生成されなければならない。
これらが欠けている場合、監査ゲートは FAIL とする。

| アーティファクト | 説明 | 生成元 |
|---------------|------|-------|
| `smoke-test-report.md` | 所定フォーマットのレポート（Step 2 テーブル必須） | Report Generation |
| `smoke-*.png` (1枚以上) | browser-use screenshot で取得した証跡 | Step 2 実行時 |

### 無効な実行パターン

以下のいずれかに該当する場合、監査ゲートは実行を無効と判定する:

1. `smoke-test-report.md` が存在しない、または所定フォーマット（Step 2 テーブルにシナリオ・観点・結果・スクリーンショット列）に準拠していない
2. `smoke-*.png` スクリーンショットが1枚も存在しない
3. レポート内のシナリオ結果が browser-use 以外のツール（rspec, jest, pytest 等）の出力に基づいている
4. レポートに adversarial probe の記録が存在しない

---

## Error Handling

| Step | エラー | リカバリ |
|------|--------|---------|
| 1 | サーバー起動コマンド検出不可 | AskUserQuestion → 回答なし → PAUSE |
| 1 | サーバー起動タイムアウト（30秒） | PAUSE |
| 2 | Browser Use CLI 実行エラー | 修正 → 再実行（最大2回） |
| 2 | アプリケーションバグ | レポートに記録、FAIL |
| 3 | VRT コマンド実行エラー | レポートに記録、スキップ |
| 4 | E2E テスト実行エラー（テスト外の問題） | レポートに記録、スキップ |
| 全体 | Browser Use CLI 未インストール | `uvx browser-use install` を提案、PAUSE |

---

## Red Flags

### Never

- スモークテスト失敗を黙って PASS にする
- VRT ベースラインをユーザー承認なしに更新する
- フレーキーテストを実装バグとして FAIL にする
- feature-dev の内部状態（artifacts, phase 番号等）に直接アクセスする
- rspec / jest / vitest / pytest 等の既存テストスイートを browser-use ベースのスモークテストの代替として実行する。スモークテストは browser-use CLI による UI 操作検証であり、既存のユニットテスト・統合テストとは別物である
- 環境問題（Docker 起動失敗、サーバー起動不可等）を理由に smoke-test の手順を独自に変更・簡略化する。環境問題は PAUSE で報告し、ユーザーに解決を委ねること
- `--smoke` がパイプラインから指定されている場合に Phase をスキップする提案をする。`--smoke` はユーザーの明示的な意思表示であり、スキップ判断はユーザーにのみ許される

### Always

- Step 遷移時にアナウンスする
- スクリーンショットを取得しレポートに含める
- フレーキーテストには推定原因と修正提案を付ける
- サーバープロセスを確実にクリーンアップする
