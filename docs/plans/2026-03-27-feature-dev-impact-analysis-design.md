# feature-dev 既存コード考慮漏れ補強 — 設計書

## 背景と課題

feature-dev パイプラインの出力品質は概ね良好だが、中〜大規模プロジェクトにおいて**既存コードの考慮漏れ**が発生しやすい。

### 問題の種類

1. **暗黙の制約・共有状態の見落とし** — 既存コードが前提としている不変条件、共有ユーティリティ、グローバル状態への影響を見落とす
2. **周辺機能への副作用の予測不足** — 変更が別のモジュールや機能に波及する影響を予測できていない
3. **E2E/スモークテストの質** — diff ベースのシナリオ生成では影響波及先のテストが生成されない。また Playwright テストコード生成ではなく LLM 直接操作（Browser Use）が望ましい

### 問題の発生フェーズ

設計フェーズと実装フェーズの**両方**で漏れが発生。根本的に既存コードの理解が浅い。

## 成功基準

- 設計品質の向上（影響範囲が設計時点で正しく把握される）
- レビューでの検出率向上（今まで見落としていた種類の問題がレビューで捕捉される）
- テスト網羅性の向上（影響範囲をカバーする E2E/スモークテストが自動生成される）

## コスト許容度

品質優先。トークンコスト・実行時間の増加は許容。

## アプローチ: 多層防御

「知る」（探索強化）と「見つける」（レビュー・テスト強化）の両方を強化し、パイプライン全体に影響分析を織り込む。

### ギャップ分析

| 既存の仕組み | ギャップ |
|---|---|
| Phase 1: code-explorer（コードフロー追跡）+ code-architect（パターン抽出） | 逆方向依存追跡（呼び出し元・共有状態・副作用）を明示的に行うエージェントがない |
| Phase 2: spec-review-consistency（影響範囲見落とし検出） | 設計書の記述をチェックするが、実コードの依存関係グラフを走査しない |
| Phase 6: smoke-test（diff ベースシナリオ生成） | 影響波及先のテストが生成されない。Playwright コード生成方式 |
| Phase 7: code-review（6観点） | 実装後の波及影響を専門的に検証するエージェントがない |

---

## 設計詳細

### 1. `impact-analyzer` エージェント（新規）

#### 役割

変更対象コードから**逆方向に依存関係を追跡**し、影響範囲・暗黙の制約・副作用リスクを網羅的に抽出する。

#### 起動タイミング

Phase 1 の S1 ステップで code-explorer, code-architect と**並列起動**（3並列）。

#### 分析観点（4軸）

| 観点 | 内容 | 出力例 |
|------|------|--------|
| **Reverse Dependency** | 変更対象の関数/クラス/モジュールの呼び出し元を再帰的に特定（Grep/LSP） | `UserService.update()` → 呼び出し元: `AuthController`, `AdminPanel`, `BatchJob` |
| **Shared State** | 変更対象が読み書きする共有状態（DB テーブル、キャッシュ、設定値、グローバル変数、環境変数） | `users テーブルの email カラムに UNIQUE 制約あり` |
| **Implicit Contracts** | 他コードが前提としている不変条件・バリデーションルール・型の制約 | `downstream の NotificationService は user.email が non-null を前提` |
| **Side Effect Surface** | 変更による波及影響の具体的なリスクシナリオ | `email フォーマット変更 → 既存の email 正規表現フィルターが不一致になる可能性` |

#### 出力フォーマット

```markdown
## Impact Analysis

### Reverse Dependencies
- [ファイル:行番号] 関数/クラス名 — 呼び出し理由・依存の強さ

### Shared State
- [リソース種別] 名前 — 制約・現在の使われ方

### Implicit Contracts
- [ファイル:行番号] 前提条件 — 依存先・違反時の影響

### Side Effect Risks
- [severity: high/medium/low] シナリオ — 発生条件・影響範囲

### Must-Verify Checklist
- [ ] チェック項目（実装・テスト時に確認すべき事項）
```

#### ツール使用

- **LSP**: シンボル参照・定義元追跡（利用可能な場合優先）
- **Grep**: 関数名・クラス名・変数名の参照箇所検索
- **Read**: 呼び出し元のコンテキスト理解
- **Glob**: 関連ファイルのパターン検索

---

### 2. feature-dev パイプライン改修

#### 改修箇所 1: `brainstorming-supplement.md` の S1 ステップ

現状の S1（code-explorer + code-architect の2並列）に impact-analyzer を追加:

```
S1: コードベース並列探索（改修後）
├─ code-explorer    → コードフロー・実行パス・データフロー
├─ code-architect   → パターン・規約・再利用候補・設計制約
└─ impact-analyzer  → 逆依存・共有状態・暗黙制約・副作用リスク ← NEW
```

#### 改修箇所 2: S3（調査結果の記録）

設計書に追加するセクションを拡張:

- 既存: 「前提条件」「影響範囲」
- **追加**: impact-analyzer の出力を「Impact Analysis」セクションとして構造化して記録
- **追加**: 「Must-Verify Checklist」を設計書末尾に配置（後続フェーズで参照）

#### 改修箇所 3: Phase 5（実装）への影響分析の伝播

superpowers:subagent-driven-development に渡す実装コンテキストに impact-analyzer の出力を含める。各タスクの description に「影響分析から導出された注意事項」を注入。

#### 改修しない箇所

- フェーズ数は9のまま（新フェーズ追加なし）
- autonomy-gates.md の GATE 判定ルールは変更不要
- Trace 記録のフォーマットも変更なし

---

### 3. レビューエージェント強化

#### 3-A: `spec-review-consistency` の強化

**追加する REJECT 基準:**

| 基準 | severity |
|------|----------|
| Impact Analysis セクションが存在しない、または不完全 | high |
| Must-Verify Checklist が存在しない | medium |
| 影響範囲の記述が抽象的（具体的な呼び出し元/共有状態の記載なし） | high |

**追加するチェック観点:**

- Impact Analysis の各項目について、実際にコードを Grep/Read して記述の正確性を検証
- 設計書の「前提条件」と Impact Analysis の「Implicit Contracts」に矛盾がないか確認

#### 3-B: `implementation-review-consistency` の強化

**追加する REJECT 基準:**

| 基準 | severity |
|------|----------|
| Impact Analysis の Side Effect Risks に対応するタスクが計画にない | high |
| Must-Verify Checklist の項目がテストケースにマッピングされていない | high |

#### 3-C: `code-review-impact` エージェント（新規）

Phase 7 (Code Review) に追加する **6番目のレビュー観点**。

**役割:** 実装後のコードが、設計書の Impact Analysis で特定された影響範囲を適切に考慮しているか検証。

**チェック観点:**

| 観点 | 内容 |
|------|------|
| **呼び出し元の整合性** | 変更した関数/クラスの全呼び出し元が、変更後も正しく動作するか |
| **共有状態の一貫性** | 共有リソース（DB、キャッシュ等）への変更が、他の読み取り側と整合しているか |
| **契約の遵守** | 暗黙の制約（不変条件、前提条件）が維持されているか |
| **Must-Verify 消化** | 設計書の Must-Verify Checklist が全て対応済みか |

**REJECT 基準:**

| 基準 | severity |
|------|----------|
| 呼び出し元が壊れる変更（シグネチャ変更で呼び出し元未修正） | critical |
| 共有状態の制約違反（UNIQUE 制約の暗黙依存を破壊等） | high |
| Must-Verify 未消化項目あり | high |

**ツール使用:** Grep でシンボル参照を追跡、Read で呼び出し元のコンテキストを確認。LSP 利用可能時は優先。

---

### 4. スモークテスト改修

#### 現状の問題

1. Playwright のテストコードを生成して実行する設計 → LLM が Browser Use CLI で直接ブラウザ操作する設計に変更
2. diff ベースのシナリオ生成 → 影響範囲を加味したシナリオ生成に変更

#### 改修後のフロー

```
diff 取得 + Impact Analysis 取得
  → テストシナリオ生成（自然言語）
  → LLM が browser-use CLI を Bash 経由で直接操作してテスト実行
  → 結果を報告
```

#### Browser Use CLI の活用

LLM が Bash ツールで以下のコマンドを逐次実行:

```bash
browser-use open http://localhost:3000/target-page  # ページ遷移
browser-use state                                    # 要素一覧取得
browser-use click 5                                  # 要素クリック
browser-use type "テスト入力"                         # テキスト入力
browser-use screenshot smoke-test-result.png          # スクリーンショット
browser-use close                                     # 終了
```

#### 実行フロー

1. **サーバー起動** — package.json/Makefile 等からコマンド自動検出（既存のまま）
2. **シナリオ生成** — diff + Impact Analysis から自然言語テストシナリオを生成
3. **CLI 実行** — LLM が `browser-use` CLI を Bash で直接実行。`state` で画面状態を取得 → 判断 → `click`/`type` で操作 → `screenshot` で証跡
4. **結果報告** — 各シナリオの PASS/FAIL を自然言語で報告、スクリーンショット添付

#### テストシナリオの観点（5つ）

| # | 観点 | 内容 |
|---|------|------|
| 1 | ナビゲーション確認 | 変更対象の画面への遷移が正常か |
| 2 | ユーザーインタラクション | 変更した機能のUI操作が動作するか |
| 3 | エラー不在確認 | コンソールエラー・ネットワークエラーがないか |
| 4 | レスポンシブ確認 | desktop/mobile での表示崩れがないか |
| 5 | **影響波及テスト** | Impact Analysis に基づく波及先の動作確認 |

#### 前提条件

- `browser-use` がインストール済み（`uvx browser-use install`）
- `ANTHROPIC_API_KEY` が環境変数に設定済み
- smoke-test 初回実行時に `browser-use` コマンドの存在チェック、未インストールなら案内

#### Step 3 (VRT) / Step 4 (E2E + Flaky) について

- VRT: `browser-use screenshot` で代替可能
- E2E: 既存の E2E テストスイート実行は変更なし（`--full-e2e` フラグ）
- Flaky Detection: 2回実行ロジックは維持

---

## 改修対象ファイル一覧

| ファイル | 改修内容 |
|---------|---------|
| `~/.claude/agents/impact-analyzer.md` | **新規作成** — 影響分析エージェント定義 |
| `~/.claude/agents/code-review-impact.md` | **新規作成** — 影響検証レビューエージェント定義 |
| `~/.dotfiles/claude/skills/feature-dev/references/brainstorming-supplement.md` | S1 に impact-analyzer 追加、S3 に Impact Analysis セクション追加 |
| `~/.claude/agents/spec-review-consistency.md` | REJECT 基準・チェック観点追加 |
| `~/.claude/agents/implementation-review-consistency.md` | REJECT 基準追加 |
| `~/.dotfiles/claude/skills/code-review/SKILL.md` | Phase 2 に code-review-impact エージェント追加 |
| `~/.dotfiles/claude/skills/smoke-test/SKILL.md` | Step 2 を Browser Use CLI ベースに再設計 |
