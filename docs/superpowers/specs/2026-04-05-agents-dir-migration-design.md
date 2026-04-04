# プロジェクトローカル `.claude/` → `.agents/` 移行

## 概要

スキルがプロジェクトローカルの `.claude/` ディレクトリに依存している。このパスを `.agents/` に置換し、Claude Code 固有のディレクトリ構造への結合を排除する。

## スコープ

- **対象**: プロジェクトローカル `{project}/.claude/handover/` → `{project}/.agents/handover/`
- **対象外**: ホームディレクトリ `~/.claude/`（Claude Code 本体が管理するパス）
- **移行方式**: クリーンカット（フォールバックなし）

## 変更対象ファイル

### スキル (SKILL.md / modules)

| ファイル | 変更内容 | 箇所数 |
|---------|---------|-------|
| `skills/handover/SKILL.md` | `.claude/handover/` → `.agents/handover/`、`.claude/` ディレクトリ作成 → `.agents/` | 8 |
| `skills/continue/SKILL.md` | `.claude/handover/` → `.agents/handover/` | 7 |
| `skills/kanban/SKILL.md` | `.claude/handover/` → `.agents/handover/` | 1 |
| `skills/workflow-engine/modules/resume.md` | `.claude/handover/` → `.agents/handover/` | 1 |
| `skills/workflow-engine/modules/phase-summary.md` | `.claude/handover/` → `.agents/handover/` | 1 |

### シェルスクリプト

| ファイル | 変更内容 | 箇所数 |
|---------|---------|-------|
| `hooks/session-start.sh` | `${PROJECT_DIR}/.claude/handover` → `${PROJECT_DIR}/.agents/handover` | 1 |
| `skills/handover/scripts/handover-lib.sh` | `.claude/handover/` → `.agents/handover/` | 3 |

### テスト

| ファイル | 変更内容 | 箇所数 |
|---------|---------|-------|
| `hooks/post_commit_spec.sh` | `.claude/handover/` → `.agents/handover/` | 4 |
| `skills/handover/scripts/handover_lib_spec.sh` | `.claude/handover/` → `.agents/handover/` | 5 |

### その他

| ファイル | 変更内容 | 箇所数 |
|---------|---------|-------|
| `.gitignore` | `.agents` エントリを追加 | 1 |

**合計: 10ファイル、32箇所**

## 変更しないもの

| ファイル / パス | 理由 |
|----------------|------|
| `agents/claude-md-analyzer.md` | Claude Code 本体の `.claude/` 設定を監査する目的。プロジェクトデータ格納先とは無関係 |
| `handover-lib.sh` の `~/.claude/projects` | Claude Code の auto memory ディレクトリ参照 |
| `handover/SKILL.md` の `~/.claude/teams/` | Claude Code のチーム設定参照 |
| `kanban/SKILL.md` の `~/.claude/kanban/`, `~/.claude/tools/` | kanban データ・サーバー（ホームディレクトリ、別課題） |
| `code-review/SKILL.md` 等の `~/.claude/plugins/cache/` | Codex プラグインキャッシュパス |

## ディレクトリ構造

変更前後で内部構造は同一。パスプレフィックスのみ変更。

```
{project}/.agents/handover/{branch}/{fingerprint}/
  ├── project-state.json
  ├── handover.md
  └── phase-summaries/{phase_id}.yml
```

## 副作用と注意点

1. **他プロジェクトの `.gitignore`**: 各プロジェクトで `.agents/` を `.gitignore` に追加する必要がある。本 dotfiles リポジトリでは対応するが、他プロジェクトはプロジェクト側の責務
2. **既存データ**: 各プロジェクトの `.claude/handover/` に残る既存データは参照されなくなる。`mv .claude/handover .agents/handover` で手動移行するか放置
3. **worktree**: continue の worktree 走査・orphan コピー・切り替え時の読み込みは全てパス文字列の置換で対応。`git worktree` / `wt` コマンド自体には影響なし

## テスト方針

- `handover_lib_spec.sh` のパス修正後、テストが PASS することを確認
- `post_commit_spec.sh` のパス修正後、テストが PASS することを確認
