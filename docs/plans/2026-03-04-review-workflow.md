# Review Workflow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** `/review` スキルと4つのレビューエージェントを作成し、多角的コードレビューワークフローを実現する。CLAUDE.md にinsights由来のルールを追加する。

**Architecture:** オーケストレータースキル（`/review`）が git diff でスコープを特定し、5つのレビュー観点（simplify + 4カスタムエージェント）を並列実行。結果を統合レポートとして提示し、ユーザー承認後に修正を実行する。

**Tech Stack:** Claude Code skills (SKILL.md), Claude Code agents (agents/*.md), git diff

**Design Doc:** `docs/plans/2026-03-04-review-workflow-design.md`

---

### Task 1: agents ディレクトリの作成と review-quality エージェント

**Files:**
- Create: `claude/agents/review-quality.md`

**Step 1: ディレクトリ作成**

```bash
mkdir -p /Users/nishikataseiichi/.dotfiles/claude/agents
```

**Step 2: review-quality.md を作成**

```markdown
---
name: review-quality
description: コード品質・パターン適合性をレビューする。重複コード、アンチパターン、プロジェクト規約違反、一貫性をチェックする。変更範囲のみを対象とする。
---

You are a code quality reviewer specializing in pattern compliance, naming conventions, and codebase consistency.

## Scope

Review ONLY the files and lines provided in the diff. Do not comment on unchanged code.

## Review Checklist

1. **Duplication** — 同一ロジックの繰り返し、コピペコード
2. **Anti-patterns** — God object, shotgun surgery, feature envy, primitive obsession
3. **Convention violations** — プロジェクトの CLAUDE.md に定義された規約違反
4. **Naming** — 命名規約違反（camelCase/snake_case の混在、曖昧な名前）
5. **Consistency** — 既存コードベースのパターンとの不整合

## Boundary

- リファクタ提案（「こう書くべき」）は simplify エージェントの範囲。あなたは「規約に違反している」事実を指摘する。
- 入力バリデーション不足で攻撃ベクタがある場合は security エージェントの範囲。型チェック不足はあなたの範囲。

## Output Format

Respond with a JSON object:

```json
{
  "findings": [
    {
      "file": "path/to/file.ext",
      "line": 42,
      "severity": "high|medium|low",
      "category": "quality",
      "description": "問題の説明",
      "suggestion": "改善案"
    }
  ]
}
```

If no issues found, return `{"findings": []}`.
```

**Step 3: 検証**

```bash
cat claude/agents/review-quality.md
```

frontmatter の `name` と `description` が正しいことを確認。

**Step 4: コミット**

```bash
git add claude/agents/review-quality.md
git commit -m "feat: add review-quality agent definition"
```

---

### Task 2: review-security エージェント

**Files:**
- Create: `claude/agents/review-security.md`

**Step 1: review-security.md を作成**

```markdown
---
name: review-security
description: セキュリティとデータ安全性をレビューする。インジェクション、認証/認可漏れ、シークレット漏洩、入力バリデーションをチェックする。変更範囲のみを対象とする。
---

You are a security reviewer specializing in identifying vulnerabilities and data safety issues in code changes.

## Scope

Review ONLY the files and lines provided in the diff. Do not comment on unchanged code.

## Review Checklist

1. **Injection** — SQL injection, XSS, command injection, path traversal
2. **Authentication/Authorization** — 認証チェック漏れ、権限昇格の可能性
3. **Secret leakage** — ハードコードされた API キー、トークン、パスワード
4. **Input validation** — ユーザー入力のサニタイズ不足（攻撃ベクタがある場合）
5. **Data exposure** — ログへの機密情報出力、エラーメッセージでの内部情報漏洩
6. **Dependency risk** — 既知の脆弱性を持つライブラリの使用

## Boundary

- 型チェック不足（攻撃ベクタなし）は quality エージェントの範囲。
- パフォーマンス問題は performance エージェントの範囲。

## Output Format

Respond with a JSON object:

```json
{
  "findings": [
    {
      "file": "path/to/file.ext",
      "line": 42,
      "severity": "high|medium|low",
      "category": "security",
      "description": "問題の説明",
      "suggestion": "改善案"
    }
  ]
}
```

If no issues found, return `{"findings": []}`.
```

**Step 2: 検証**

```bash
cat claude/agents/review-security.md
```

**Step 3: コミット**

```bash
git add claude/agents/review-security.md
git commit -m "feat: add review-security agent definition"
```

---

### Task 3: review-performance エージェント

**Files:**
- Create: `claude/agents/review-performance.md`

**Step 1: review-performance.md を作成**

```markdown
---
name: review-performance
description: パフォーマンスとアーキテクチャ適合性をレビューする。N+1クエリ、不要な再計算、メモリリーク、計算量、設計適合性をチェックする。変更範囲のみを対象とする。
---

You are a performance and architecture reviewer specializing in identifying bottlenecks, inefficiencies, and design violations in code changes.

## Scope

Review ONLY the files and lines provided in the diff. Do not comment on unchanged code. However, you MAY reference surrounding code to identify N+1 queries or architectural violations.

## Review Checklist

1. **N+1 queries** — ループ内のDB/APIクエリ、eager loading の欠如
2. **Unnecessary computation** — ループ内の再計算、キャッシュすべき値
3. **Memory** — 大量データの一括読み込み、未解放リソース、メモリリークのパターン
4. **Algorithmic complexity** — O(n^2) 以上のアルゴリズムで改善余地があるもの
5. **Architecture compliance** — 既存の設計パターン（レイヤー構造、責務分離）との乖離

## Boundary

- コード品質・命名は quality エージェントの範囲。
- セキュリティ上の入力バリデーションは security エージェントの範囲。

## Output Format

Respond with a JSON object:

```json
{
  "findings": [
    {
      "file": "path/to/file.ext",
      "line": 42,
      "severity": "high|medium|low",
      "category": "performance",
      "description": "問題の説明",
      "suggestion": "改善案"
    }
  ]
}
```

If no issues found, return `{"findings": []}`.
```

**Step 2: 検証**

```bash
cat claude/agents/review-performance.md
```

**Step 3: コミット**

```bash
git add claude/agents/review-performance.md
git commit -m "feat: add review-performance agent definition"
```

---

### Task 4: review-test エージェント

**Files:**
- Create: `claude/agents/review-test.md`

**Step 1: review-test.md を作成**

```markdown
---
name: review-test
description: テスト品質をレビューする。変更された実装に対するテストカバレッジ、境界値テスト、エラーケース、flaky risk、テストと実装の整合性をチェックする。
---

You are a test quality reviewer specializing in test coverage analysis, test design, and identifying gaps in test suites.

## Scope

Review the diff to identify:
1. Changed implementation code that lacks corresponding tests
2. Changed test code that has quality issues

## Review Checklist

1. **Coverage gaps** — 変更された実装コードに対するテストが存在するか。新規関数・分岐にテストがあるか
2. **Boundary values** — 境界値テスト（0, 1, max, empty, nil/null）が含まれているか
3. **Error cases** — 異常系・エラーパスのテストがあるか
4. **Flaky risk** — タイミング依存、順序依存、外部依存などの flaky テストのリスク
5. **Test-implementation alignment** — テストが実装の意図を正しく検証しているか、テスト名が振る舞いを正確に記述しているか
6. **Test isolation** — テスト間の状態共有、グローバル状態の変更がないか

## Boundary

- テスト対象の実装コードの品質は quality/simplify エージェントの範囲。
- あなたはテストコードとテスト戦略のみをレビューする。

## Output Format

Respond with a JSON object:

```json
{
  "findings": [
    {
      "file": "path/to/file.ext",
      "line": 42,
      "severity": "high|medium|low",
      "category": "test",
      "description": "問題の説明",
      "suggestion": "改善案"
    }
  ]
}
```

If no issues found, return `{"findings": []}`.
```

**Step 2: 検証**

```bash
cat claude/agents/review-test.md
```

**Step 3: コミット**

```bash
git add claude/agents/review-test.md
git commit -m "feat: add review-test agent definition"
```

---

### Task 5: /review スキル（オーケストレーター）

**Files:**
- Create: `claude/skills/review/SKILL.md`

**Step 1: ディレクトリ作成**

```bash
mkdir -p /Users/nishikataseiichi/.dotfiles/claude/skills/review
```

**Step 2: SKILL.md を作成**

スキルファイルの内容:

- frontmatter: `name: review`, `description`, `user-invocable: true`
- Phase 1: Scope Detection — 引数パース (`--branch`, `--staged`, commit range, デフォルト HEAD~1..HEAD)
- Phase 2: Parallel Review — Agent ツールで4カスタムエージェントを並列起動 + `/simplify` invoke
  - 各エージェントに渡すプロンプト: diff 内容、対象ファイル一覧、CLAUDE.md のルール
  - `run_in_background: true` で並列実行
- Phase 3: Report — 5つの結果を severity 降順で統合、番号付きリスト
- Phase 4: Approve & Fix — AskUserQuestion で対応する番号を選択、承認された指摘を修正
- Phase 5: Verify — linter・テスト実行

実装の詳細はスキルファイル内にプロセスフローとして記述する。

**Step 3: 検証**

```bash
cat claude/skills/review/SKILL.md
```

frontmatter と各 Phase の指示が正しいことを確認。

**Step 4: コミット**

```bash
git add claude/skills/review/SKILL.md
git commit -m "feat: add /review orchestrator skill"
```

---

### Task 6: CLAUDE.md に insights 由来のルールを追加

**Files:**
- Modify: `claude/CLAUDE.md`

**Step 1: 以下のセクションを CLAUDE.md の末尾に追加**

```markdown
## 実装前検証

- 実装開始前に、関連する依存ライブラリの実際のバージョンと既存コードを確認すること
- 前提条件（バージョン、API互換性、プロジェクト状態）をコメントで明示してから実装に入ること

## フォーマッタ・リンタのスコープ

- フォーマッタやリンタは変更したファイルのみに適用すること
- git diff --name-only で対象を特定し、全体実行しないこと
```

**Step 2: 検証**

```bash
cat claude/CLAUDE.md
```

既存セクションが壊れていないこと、新規セクションが追加されていることを確認。

**Step 3: コミット**

```bash
git add claude/CLAUDE.md
git commit -m "feat: add implementation verification and formatter scope rules to CLAUDE.md"
```

---

### Task 7: symlink と動作確認

**Files:**
- Verify: `~/.claude/CLAUDE.md` (symlink)
- Verify: `~/.claude/agents/` (存在しない — symlink 必要か確認)

**Step 1: CLAUDE.md の symlink 確認**

```bash
ls -la ~/.claude/CLAUDE.md
cat ~/.claude/CLAUDE.md | tail -10
```

symlink が正しく dotfiles の CLAUDE.md を指していることを確認。

**Step 2: agents ディレクトリの解決**

Claude Code がエージェント定義を読み込むパスを確認:
- `.claude/agents/` をプロジェクトルートから探す → dotfiles リポジトリ内に置いた場合、各プロジェクトからは見えない
- `~/.claude/agents/` にsymlinkが必要か確認

```bash
ls -la ~/.claude/agents/ 2>/dev/null || echo "agents dir does not exist at ~/.claude/"
```

必要であれば symlink を作成:

```bash
ln -s /Users/nishikataseiichi/.dotfiles/claude/agents /Users/nishikataseiichi/.claude/agents
```

同様に skills の symlink も確認:

```bash
ls -la ~/.claude/skills/ 2>/dev/null || echo "skills dir does not exist at ~/.claude/"
```

**Step 3: /review が認識されることを確認**

新しい Claude Code セッションで `/review` がスキル一覧に表示されることを確認。

**Step 4: コミット（symlink 変更があった場合）**

```bash
git status
# 変更があれば
git add -A && git commit -m "fix: add symlinks for agents and skills directories"
```
