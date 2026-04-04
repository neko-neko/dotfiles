---
name: brainstorming-supplement
description: >-
  feature-dev Phase 1 専用。superpowers:brainstorming の **前に** invoke し、
  brainstorming プロセスにインタラクティブ制約・コードベース調査・テスト観点ステップを注入する。
---

# Brainstorming Constraints for Feature Dev

このスキルは `superpowers:brainstorming` の **前に** invoke される。brainstorming が読み込まれた時点で、以下の制約と追加ステップが context 上に存在する状態になる。

## 制約: インタラクティブ実行

以下の制約は brainstorming の全プロセスに適用される:

- brainstorming のチェックリスト項目を **TaskCreate でサブエージェントに委譲しない**。全ステップをこの会話内で逐次実行する
- 全ての質問はユーザーに直接投げ、回答を待つ。自動回答禁止
- 1問ずつ質問する原則を厳守する

## 追加ステップ（brainstorming の step 2 と step 3 の間に挿入）

brainstorming のステップ2（Ask clarifying questions）が完了した後、ステップ3（Propose 2-3 approaches）に進む **前** に、以下の S1〜S3 を実行すること。

### S1: コードベース並列探索

clarifying questions の回答内容から探索テーマを決定し、3つのサブエージェントを **並列** で起動する。

**手順:**

1. clarifying questions で特定した変更対象と目的から、3つの探索プロンプトを構成する:
   - **code-explorer**: 「<機能名/領域> に関連する既存コードのフローをトレースし、依存関係・パターン・制約を報告せよ」
   - **code-architect**: 「<機能領域> のアーキテクチャパターン・規約・再利用候補を報告せよ」
   - **impact-analyzer**: 「<変更対象> の逆方向依存を追跡し、共有状態・暗黙の制約・副作用リスクを報告せよ」

2. Agent tool で 3 エージェントを **単一メッセージ内で** 並列起動する（subagent_type は指定しない）:
   ```
   Agent call 1: prompt="...", description="コードフロー探索"
   Agent call 2: prompt="...", description="アーキテクチャ分析"
   Agent call 3: prompt="...", description="影響範囲分析"
   ```

3. 全エージェントの結果を受け取り、以下を設計書用に整理する:
   - 発見したパターン・規約（code-explorer, code-architect）
   - 再利用候補のコンポーネント（code-architect）
   - 影響範囲（ファイル + 依存関係）（全エージェント）
   - 既存の制約・バリデーションルール（code-explorer, impact-analyzer）
   - 逆方向依存・共有状態・暗黙の制約（impact-analyzer）
   - 副作用リスクシナリオ（impact-analyzer）

**失敗時のフォールバック:**
エージェントが失敗した場合（タイムアウト、エラー等）は、従来通りメイン context で Grep/Read による最低限の調査を行う。一部のみ失敗した場合は、成功した方の結果のみ使用する。

### S2: 暗黙ルールの抽出

S1 の調査で見つけた既存コードから、以下を抽出する:

- バリデーションルール（値の範囲制約、必須チェック等）
- 条件分岐（ステータスによる処理の分岐等）
- ビジネスロジック（計算式、権限チェック等）

抽出した各ルールについて、ユーザーに **1問ずつ** 確認する:

> 「既存コードに [具体的なルール] がありますが、この制約は新機能でも適用されますか？」

全ルールの確認が完了するまで次に進まない。

### S3: 調査結果の記録

S1・S2 で確認した内容を、設計書に以下のセクションとして含める:

- **前提条件** — 新機能が依存する既存の制約・ルール
- **影響範囲** — 変更が波及する可能性のあるモジュール・テーブル一覧
- **Impact Analysis** — impact-analyzer の出力を構造化して記録する。以下のサブセクションを含む:
  - **Reverse Dependencies** — 変更対象の呼び出し元一覧（ファイル:行番号、依存の強さ）
  - **Shared State** — 共有リソース一覧（種別、制約、使われ方）
  - **Implicit Contracts** — 暗黙の制約一覧（ファイル:行番号、依存先、違反時の影響）
  - **Side Effect Risks** — 副作用リスクシナリオ（severity、発生条件、影響範囲）
- **Must-Verify Checklist** — 実装・テスト時に確認すべき事項のチェックリスト（impact-analyzer の出力から生成）。後続フェーズ（Phase 4 の implementation-review-consistency、{review} の code-review-impact）で参照される

## 追加ステップ（brainstorming の step 4 の設計書に含める）

### S4: テスト観点の列挙

設計書に「テスト観点」セクションを追加し、以下を含める:

- 正常系テストケース名の列挙
- 異常系・境界値テストケース名の列挙
- 非機能要件（パフォーマンス、セキュリティ）の観点があれば列挙

**品質基準（Phase 3 の Given/When/Then 展開時に適用）:**
各機能の入力パラメータについて、以下のカテゴリを最低1つずつカバーすること:
- 正常値（代表値）
- 境界値（最小値、最大値、ちょうど境界）
- 異常値（型違い、null/undefined、範囲外）
- 状態遷移（前提条件が異なるケース）

この基準を満たさないテストケースは Phase 4 の implementation-review-feasibility で REJECT される。

※ Given/When/Then レベルの詳細化は Phase 3（Plan）で行う。設計書内のテスト観点は Phase 3 で `docs/plans/*-test-cases.md` に展開される。

## Workspace 作成（設計書コミット直前）

brainstorming の step 5（Write design doc）で設計書をコミットする **前に**、以下を実行する:

1. `worktrunk:worktrunk` を invoke し、`wt switch -c <branch> [-b <base>]` で開発用 worktree とブランチを作成する
   - ブランチ名はフィーチャー名から自動生成される
   - ベースブランチは設計フェーズのコンテキストから判断する（`/continue` 時は handover の記録から復元。新規時はデフォルト=メインブランチ）
2. worktrunk の pre-start フックが依存関係インストールを自動処理する（プロジェクトの `.config/wt.toml` に定義済みの場合）
3. ベースラインテストを実行する
   - テスト通過 → 設計書を worktree 内にコミットし、次へ進む
   - テスト失敗 → PAUSE。続行 or STOP をユーザーに提案
4. 以降の全作業（設計書コミット、レビュー、計画、実装等）は worktree 内で行う
5. worktree パスとブランチ名を `artifacts.worktree_path` と `artifacts.branch_name` に記録する

## 完了条件

S1〜S4 が完了したら、brainstorming のステップ3（Propose 2-3 approaches）に戻る。approaches の提案時には、調査結果とテスト観点を考慮に入れること。設計書ドラフト完成後は、上記「Workspace 作成」の手順に従い worktree を作成してから設計書をコミットする。
