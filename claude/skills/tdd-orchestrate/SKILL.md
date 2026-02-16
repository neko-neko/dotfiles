---
name: tdd-orchestrate
description: >-
  featureスペックを受け取り、設計→計画→TDD実行→統合を1セッションで完結させる
  オーケストレーター。5つのsuperpowersスキルを順次invokeし、フェーズ間遷移を
  自動化する。/tdd-orchestrate で起動、または feature 実装の依頼時に発動する。
user-invocable: true
---

# TDD Orchestrate

5つの superpowers スキルを1セッションで順次 invoke し、feature spec から merge-ready なコードまでを一気通貫で実行する。

**コア原則:** フェーズ間遷移を自動化し、ユーザー判断が必要な箇所のみ対話する。

**開始時アナウンス:** 「TDD Orchestrate パイプラインを開始します。Phase 1/5: Design から始めます。」

## Input

`/tdd-orchestrate` の引数、または会話で提供された feature spec。最低要件:
- **何を作るか**（機能の説明）
- **なぜ作るか**（ユーザー価値または解決する問題）

不足している場合は Phase 1 に入る前に確認する。

## The Pipeline

```
Feature Spec
    │
    ▼
Phase 1: Design ──── superpowers:brainstorming [INTERACTIVE]
    │                  ユーザーと対話しながら設計
    │ 設計書コミット済み → 自動遷移
    ▼
Phase 2: Plan ────── superpowers:writing-plans [AUTONOMOUS]
    │                  設計書から TDD 実装計画を生成
    │ 計画書コミット済み → 自動遷移（Subagent-Driven 自動選択）
    ▼
Phase 3: Workspace ─ superpowers:using-git-worktrees [AUTONOMOUS+GATE]
    │                  worktree 作成・依存インストール
    │ テスト通過 → 自動遷移 / テスト失敗 → PAUSE
    ▼
Phase 4: Execute ─── superpowers:subagent-driven-development [AUTONOMOUS+GATE]
    │                  タスクごとに TDD 実行・レビュー
    │ 全タスク完了・最終レビュー通過 → 自動遷移
    │ 設計外の質問 or 3回失敗 → PAUSE
    ▼
Phase 5: Integrate ─ superpowers:finishing-a-development-branch [INTERACTIVE]
    │                  テスト検証 → merge/PR/keep/discard 選択
    ▼
  Complete
```

## Phase 1: Design

**INVOKE:** `superpowers:brainstorming`

**Autonomy:** INTERACTIVE — brainstorming の質問はすべてユーザーに転送する。設計の質を決めるのはユーザーのドメイン知識であり、自動回答しない。

**Auto-transition:** brainstorming が「実装の準備に進みますか？」等の遷移確認をした場合、ユーザーに確認せず「Yes」と回答し Phase 2 へ自動進行する。

**Required output:**
- 設計書: `docs/plans/YYYY-MM-DD-<topic>-design.md`（git commit 済み）

**Transition:** 設計書コミット完了 → Phase 2

## Phase 2: Plan

**INVOKE:** `superpowers:writing-plans`

**Autonomy:** AUTONOMOUS — writing-plans は設計書を入力として計画を生成する。対話的チェックポイントはない。

**Auto-transition:** writing-plans が実行方式を提案した場合（「Subagent-Driven vs Parallel Session」）、自動で「Subagent-Driven (this session)」を選択する。

**Required output:**
- 実装計画: `docs/plans/YYYY-MM-DD-<feature-name>.md`（git commit 済み）
- 全タスクが TDD 形式（failing test → verify fail → implement → verify pass → commit）

**Transition:** 計画書コミット完了 → Phase 3

## Phase 3: Workspace

**INVOKE:** `superpowers:using-git-worktrees`

**Autonomy:** AUTONOMOUS + GATE

- worktree ディレクトリ選択: using-git-worktrees の優先順位に従う
- ディレクトリが存在せず CLAUDE.md にも設定がない場合は `.worktrees/` をデフォルト使用
- 依存インストール: 自動実行
- **GATE:** ベースラインテストが失敗した場合 → PAUSE してユーザーに報告。続行判断を仰ぐ。

**Required output:**
- worktree 作成済み（feature ブランチ）
- 依存インストール済み
- ベースラインテスト通過（またはユーザーが失敗を承認）

**Transition:** テスト通過 → Phase 4

## Phase 4: Execute

**INVOKE:** `superpowers:subagent-driven-development`

**Autonomy:** AUTONOMOUS + EXCEPTION GATES

通常フローは完全自律:
- タスクごとに implementer サブエージェントをディスパッチ
- spec compliance review → code quality review を自動実行
- fix ループも自動実行
- タスク間でユーザー確認なし

**GATE 1 — 未知の質問:** implementer が設計書にない質問をした場合 → PAUSE してユーザーに転送。

オーケストレーターが**回答できる**質問:
- 設計書に記載された設計判断
- コードベースから読み取れるプロジェクト規約
- 計画内のタスク間依存

オーケストレーターが**回答できない**質問（PAUSE 必須）:
- 設計書にないビジネスロジック
- スコープ変更・優先度判断
- 外部依存・インテグレーション判断

**GATE 2 — 反復失敗:** タスクが fix+review を3回繰り返しても通過しない場合 → PAUSE してユーザーにエスカレーション。設計とのギャップの可能性。

**GATE 3 — 最終レビュー後:** 全タスク完了・最終コードレビュー通過後、Phase 5 へ自動進行。

**Required output:**
- 全タスク完了（TodoWrite で complete）
- 最終コードレビュー承認済み
- 全テスト通過

**Transition:** 最終レビュー通過 → Phase 5

## Phase 5: Integrate

**INVOKE:** `superpowers:finishing-a-development-branch`

**Autonomy:** INTERACTIVE — merge/PR/keep/discard の選択はユーザーに委ねる。リポジトリへの不可逆操作であり、自動判断しない。

**Required output:**
- ユーザー選択の統合オプション実行済み
- worktree クリーンアップ（該当する場合）

**Transition:** 統合完了 → パイプライン終了

## Phase Artifacts

| Phase | 成果物 | 次の消費者 |
|-------|--------|-----------|
| 1 | `docs/plans/*-design.md` | Phase 2（計画の入力） |
| 2 | `docs/plans/*-plan.md` | Phase 4（タスクリスト） |
| 3 | worktree パス、ブランチ名 | Phase 4（作業ディレクトリ）、Phase 5（ブランチ） |
| 4 | コミット済みコード、テスト結果 | Phase 5（検証） |
| 5 | merge/PR/kept ブランチ | ユーザー |

## Autonomy Summary

詳細な判断テーブルは [references/autonomy-gates.md](references/autonomy-gates.md) を参照。

| Phase | モード | ユーザー介入 |
|-------|--------|-------------|
| 1: Design | INTERACTIVE | 設計質問への回答 |
| 2: Plan | AUTONOMOUS | なし（失敗時のみ） |
| 3: Workspace | AUTONOMOUS+GATE | テスト失敗時 |
| 4: Execute | AUTONOMOUS+GATE | 未知の質問、3回失敗 |
| 5: Integrate | INTERACTIVE | merge/PR/keep/discard 選択 |

## Error Handling

| Phase | エラー | リカバリ |
|-------|--------|---------|
| 1 | ユーザーが設計を中断 | STOP。クリーンアップ不要。 |
| 3 | ブランチが既存 | 既存 worktree の再利用または新ブランチ名を提案 |
| 3 | 依存インストール失敗 | 失敗コマンドを報告。スキップまたは STOP を提案 |
| 3 | テスト失敗 | PAUSE。続行（既存の問題として承認）または STOP を提案 |
| 4 | implementer が3回失敗 | PAUSE。設計ギャップの可能性をエスカレーション |
| 4 | reviewer が3回リジェクト | PAUSE。計画の問題をエスカレーション |
| 5 | テスト失敗 | Phase 4 に戻り fix サブエージェントをディスパッチ |
| 5 | マージコンフリクト | コンフリクトを報告。手動解決またはブランチ保持を提案 |

### Rollback

- **Phase 1-2:** ドキュメント追加のみ。ロールバック不要。
- **Phase 3:** パイプライン中断時は `git worktree remove <path>` で worktree 削除。
- **Phase 4:** タスクごとにアトミックコミット。部分的な進捗は worktree に保持。
- **Phase 5:** finishing-a-development-branch の discard オプションで対応。

### Context Exhaustion

パイプライン実行中にコンテキスト圧縮が発生した場合:
1. 現在の Phase とタスク進捗を TodoWrite に記録
2. handover スキルを invoke してパイプライン状態を保存
3. handover 文書に記録: 現在の Phase、完了した成果物パス、残タスク
4. 新セッションで handover を読み込み、中断した Phase から再開

## Progress Reporting

Phase 遷移ごとに1行で報告:
```
[Phase N/5 complete] <成果物> | Next: Phase N+1
```

Phase 間で冗長なレポートを出さない。最終サマリーは Phase 5 完了時に出力。

## Red Flags

**Never:**
- Phase 1（設計）をスキップする（「簡単な機能」でも）
- brainstorming の設計質問に自動回答する
- merge/PR/keep/discard をユーザーに代わって選択する
- テスト失敗のまま Phase 4 に進む（ユーザー承認なし）
- 設計書にない回答を implementer に推測させる
- Phase 4 の spec/code quality review をスキップする
- main/master ブランチで直接作業する

**Always:**
- Phase 遷移時に現在の Phase をアナウンスする
- 成果物を次の Phase に引き継ぐ（設計書パス → 計画、計画パス → SDD）
- worktree で作業を隔離する
- invoke した各スキルの指示に正確に従う
- GATE 条件に該当したら PAUSE する（サイレント失敗禁止）

## Integration

**オーケストレート対象（実行順）:**
1. `superpowers:brainstorming`
2. `superpowers:writing-plans`
3. `superpowers:using-git-worktrees`
4. `superpowers:subagent-driven-development`
5. `superpowers:finishing-a-development-branch`

**SDD 内部で使用（継承）:**
- `superpowers:test-driven-development`
- `superpowers:requesting-code-review`
- `superpowers:verification-before-completion`
