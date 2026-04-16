# Skills Best Practices 準拠化 — Design

> Date: 2026-04-16
> Status: Approved
> Scope: `claude/skills/` 配下 8 スキルの SKILL.md を Anthropic Skill Authoring Best Practices に準拠させる

## 背景

`claude/skills/` には 8 つのスキル（linear-refresh, handover, triage, doc-check, weekly-sync, continue, doc-audit, slackcli）が存在する。Anthropic の [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) に沿って点検した結果、以下の逸脱が発見された:

| 重大度 | 件数 | 内容 |
|-------|------|------|
| Critical | 1 | doc-audit の YAML frontmatter が完全に欠落 |
| Medium | 2 | handover の JSON Schema が SKILL.md に 90 行インライン / handover, continue の description に When が不明確 |
| Minor | 2 | linear-refresh の description に自己参照語 "スキル" / slackcli の `metadata` ブロックは独自拡張で削除対象 |

## ベストプラクティスの参照ルール

1. **frontmatter**: `name` (≤64字、小文字/数字/ハイフン) と `description` (≤1024字) が必須
2. **description**: 第三者視点で What + When を含める。key terms を含める
3. **naming**: 動名詞形推奨。vague 名 (`helper`, `utils`, `tools`) は避ける
4. **size**: SKILL.md 本体 500 行以下
5. **progressive disclosure**: 詳細は別ファイル、参照は 1 階層のみ
6. **簡潔性**: Claude が既に知っていることは書かない
7. **time-sensitive 禁止**: "After August 2025" 等の相対記述は避ける

## 修正項目

### 1. [Critical] doc-audit — frontmatter 追加

**現状**: `claude/skills/doc-audit/SKILL.md` の 1 行目から本文 (`ドキュメント監査スキル。...`) が始まり、YAML frontmatter が無い。

**修正**: ファイル冒頭に以下の frontmatter を追加する。

```yaml
---
name: doc-audit
description: >-
  md ドキュメントの陳腐化・欠落・矛盾を 4 Layer 構造で検出し、ユーザー承認後に修正する。
  depends-on 検証、coverage チェック、business-rule/architecture の未文書化知識検出、
  readme/CLAUDE.md のメタ整合検査を行う。/doc-audit で起動、または大規模なコード変更後に
  ドキュメント整合性を確認したい時に使用する。
---
```

既存の 1 行目（`ドキュメント監査スキル。4 Layer 構造で...`）は frontmatter の直後の本文冒頭として保持する。

### 2. [Medium] handover — JSON Schema 外出し

**現状**: `claude/skills/handover/SKILL.md` (305 行) のうち、45 行目から 135 行目にかけて project-state.json の JSON スキーマがインラインで 90 行記述されている。加えて、マージルール (140-154 行) と Phase Summary フォーマット (170-203 行) も構造化された参照資料の性格が強い。

**修正**:

1. 新ファイル `claude/skills/handover/references/project-state-schema.md` を作成
2. 以下のセクションを SKILL.md から移動:
   - `project-state.json` の JSON スキーマ
   - マージルール（手順 4 の中身）
   - Phase Summary YAML フォーマット
   - handover.md の出力フォーマット
3. SKILL.md 内の該当箇所を以下のような参照文に置換:

   ```markdown
   project-state.json の完全な JSON スキーマ、マージルール、Phase Summary YAML フォーマット、
   handover.md 出力フォーマットは [references/project-state-schema.md](references/project-state-schema.md) を参照する。
   ```

4. SKILL.md は手順とフロー制御に集中させる（約 200 行に短縮）

### 3. [Medium] handover — description の When 強化

**現状**:
> 現在のセッション内容を振り返り、project-state.json と handover.md を生成する

**修正**:
> 現在のセッションで行った作業・決定事項・アーキテクチャ変更を project-state.json に記録し、handover.md を生成する。コンテキスト圧縮の直前、/handover の明示呼び出し、ツール呼び出し累計 50 回超過時、または応答が遅延した時に使用する。

加えて `user-invocable: true` は現状の frontmatter に含まれているため維持する。

### 4. [Medium] continue — description の When 強化

**現状**:
> handover.md から未完了タスクを確認し、承認後に作業を再開する

**修正**:
> 前セッションの project-state.json から未完了タスク（in_progress/blocked）を特定し、ユーザー承認後に作業を再開する。/continue の明示呼び出し、"continue from handover" のような継続指示、handover.md への言及を検出した時に使用する。worktree 切り替えと Pipeline Detection も含む。

### 5. [Minor] linear-refresh — description 微調整

**現状**:
> Linearチームのチケット棚卸し・構造整理・新規検出を一気通貫で実行するスキル。チケットに紐付いた外部リンクの探索に加え、キーワード検索とチケット逆引きで未紐付きの外部ソースも発見する。

**修正** (自己参照語 "スキル" 削除 + 5 ステップ明示 + When 追加):
> Linear チケットの棚卸し・構造整理・未登録ソース発見を Collect/Discover/Analyze/Approve/Execute の 5 ステップで一気通貫実行する。既存の外部リンク探索に加え、Slack/GitHub のキーワード検索と逆引きで未紐付きの外部ソースも発見する。定期的な Linear メンテナンス、または「棚卸し」「リフレッシュ」「整理」の依頼時に使用する。

### 6. [Minor] slackcli — metadata ブロック削除

**現状**: frontmatter 内に以下の独自拡張がある。

```yaml
metadata:
  version: 0.3.1
  openclaw:
    category: "productivity"
    requires:
      bins:
        - slackcli
    cliHelp: "slackcli --help"
```

**修正**: `metadata` ブロック全体を削除する。frontmatter は `name` と `description` のみを残す。バージョンや CLI 要件は本文の Prerequisites セクションで既に言及されており、frontmatter からの削除は情報損失を伴わない。

## 変更しない項目（明示）

| 対象 | 理由 |
|------|------|
| continue の name | ユーザー指示により保持（"continue" は vague 名だが運用上の理由で保持） |
| 各スキルの Workflow/Phase 本文 | 動作仕様に関わるため本タスクのスコープ外 |
| references/*.md の内部構造 | 今回は SKILL.md レベルの整合性修正に集中。再帰的改善は別タスク |
| triage, doc-check, weekly-sync の frontmatter | ベストプラクティス準拠済み |
| slackcli の本文 | Command Reference 等は現状維持 |

## 実装順序

1. **doc-audit**: frontmatter 追加（Edit）
2. **handover**:
   a. `references/project-state-schema.md` 新設（Write）
   b. SKILL.md から JSON スキーマ・マージルール・Phase Summary フォーマット・handover.md 出力フォーマットを削除し、参照文に置換（Edit）
   c. description を更新（Edit）
3. **continue**: description 更新（Edit）
4. **linear-refresh**: description 更新（Edit）
5. **slackcli**: frontmatter から metadata ブロック削除（Edit）
6. **最終検証**: 全 SKILL.md を Read し、以下を確認
   - frontmatter の `name` と `description` が存在
   - SKILL.md 本体が 500 行以下
   - description に XML タグが含まれない
   - name が lowercase/数字/ハイフンのみ

## 想定インパクト

- SKILL.md 総行数: 1,564 → 約 1,450 行（handover の約 90 行削減が主因）
- description の discovery 精度向上（When の明示により Claude がスキル選択時に適切にマッチする確率が上がる）
- doc-audit がベストプラクティス準拠となり、Claude Code 側の name/description 推測処理に依存しなくなる
- slackcli の frontmatter が簡潔化され、ベストプラクティスの範囲に収まる

## 非範囲（Out of Scope）

- references/*.md 配下のファイル内部構造の見直し
- scripts/ 配下のシェルスクリプトのレビュー
- done-criteria/, phases/ 等のワークフロー関連ディレクトリの再編
- 新スキルの追加
- 既存スキルの workflow/phase ロジックの変更
- 英語化（description は日本語のまま維持）

## 検証方法

本修正の完了後、以下を確認する:

1. `grep -L "^---$" claude/skills/*/SKILL.md` で frontmatter 欠落ファイルが無いことを確認
2. 各 SKILL.md の行数を `wc -l` で測定し、500 行以下であることを確認
3. frontmatter の `name` 値が、ディレクトリ名と一致することを目視で確認
4. handover の `references/project-state-schema.md` が存在し、SKILL.md からリンクされていることを確認
5. slackcli の frontmatter に `metadata:` キーが残っていないことを確認
