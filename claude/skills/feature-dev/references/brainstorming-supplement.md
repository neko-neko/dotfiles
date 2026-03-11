---
name: brainstorming-supplement
description: >-
  feature-dev Phase 1 専用。superpowers:brainstorming invoke 直後に invoke し、
  brainstorming プロセスにコードベース調査・暗黙ルール抽出ステップを挿入する。
---

# Brainstorming Supplement for Feature Dev

このスキルは `superpowers:brainstorming` と併用する。brainstorming のプロセスに以下のステップを挿入する。

## 挿入位置

brainstorming のステップ2（Ask clarifying questions）が完了した後、ステップ3（Propose 2-3 approaches）に進む **前** に、以下の全ステップを実行すること。

## 挿入ステップ

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

## 完了条件

S1〜S3 が完了したら、brainstorming のステップ3（Propose 2-3 approaches）に戻る。approaches の提案時には、この調査結果を考慮に入れること。
