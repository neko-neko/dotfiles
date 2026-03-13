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

### S1: 影響範囲の調査

clarifying questions で特定した変更対象（モデル・コントローラ・ジョブ・テーブル等）を起点に、Grep/Read で以下を探索する:

- 呼び出し元（そのモジュール/関数を使っている箇所）
- 依存先（そのモジュール/関数が使っている外部依存）
- 同じテーブル/リソースを参照する他の箇所

調査結果を箇条書きで整理する。

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

## 追加ステップ（brainstorming の step 4 の設計書に含める）

### S4: テスト観点の列挙

設計書に「テスト観点」セクションを追加し、以下を含める:

- 正常系テストケース名の列挙
- 異常系・境界値テストケース名の列挙
- 非機能要件（パフォーマンス、セキュリティ）の観点があれば列挙

※ Given/When/Then レベルの詳細化は Phase 3（Plan）で行う。設計書内のテスト観点は Phase 3 で `docs/plans/*-test-cases.md` に展開される。

## Workspace 作成（設計書コミット直前）

brainstorming の step 5（Write design doc）で設計書をコミットする **前に**、以下を実行する:

1. `superpowers:using-git-worktrees` を invoke し、開発用 worktree とブランチを作成する
   - ブランチ名はフィーチャー名から自動生成される
2. worktree 作成後、ベースラインテストを実行する（using-git-worktrees が自動実行）
   - テスト通過 → 設計書を worktree 内にコミットし、次へ進む
   - テスト失敗 → PAUSE。続行 or STOP をユーザーに提案
3. 以降の全作業（設計書コミット、レビュー、計画、実装等）は worktree 内で行う
4. worktree パスとブランチ名を `artifacts.worktree_path` と `artifacts.branch_name` に記録する

## 完了条件

S1〜S4 が完了したら、brainstorming のステップ3（Propose 2-3 approaches）に戻る。approaches の提案時には、調査結果とテスト観点を考慮に入れること。設計書ドラフト完成後は、上記「Workspace 作成」の手順に従い worktree を作成してから設計書をコミットする。
