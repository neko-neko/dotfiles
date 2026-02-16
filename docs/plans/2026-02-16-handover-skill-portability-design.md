# Handover/Continue スキル可搬性リファクタリング設計

> Date: 2026-02-16
> Status: Approved

## 背景

handover/continue スキルの実装が `bin/` 配下のシェルスクリプト群に依存しており、skill creator のボイラープレート構造に準拠していない。dotfiles を別環境に持ち込んだ際に bin スクリプトのセットアップが別途必要になる可搬性の問題がある。

## 決定事項

- bin/ から handover 関連スクリプトを完全除去し、skill creator のボイラープレート構造に移行
- post-commit hook は `claude/hooks/` ディレクトリに分離
- 共有ライブラリ（handover-lib.sh）は handover skill の scripts/ に配置し、hooks から相対パスで参照

## ディレクトリ構造（After）

```
claude/
├── skills/
│   ├── handover/
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── claude-handover.sh      # bin/claude-handover から移動
│   │       └── handover-lib.sh         # bin/claude-handover-lib.sh から移動
│   ├── continue/
│   │   └── SKILL.md                    # 変更なし
│   └── tdd-orchestrate/
│       ├── SKILL.md
│       └── references/
└── hooks/
    └── post-commit.sh                  # bin/claude-post-commit から移動
```

## パス解決

### hooks/post-commit.sh → handover-lib.sh

```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../skills/handover/scripts/handover-lib.sh"
```

### settings.json hook command

```json
"command": "if echo \"$CLAUDE_TOOL_INPUT\" | jq -r '.command' 2>/dev/null | grep -qE 'git commit'; then \"${HOME}/.dotfiles/claude/hooks/post-commit.sh\"; fi"
```

## 削除対象（bin/）

- `bin/claude-handover`
- `bin/claude-handover-lib.sh`
- `bin/claude-post-commit`

## スクリプト内 source パス修正

| ファイル | 変更後の source |
|---------|----------------|
| `claude-handover.sh` | `source "${SCRIPT_DIR}/handover-lib.sh"` |
| `post-commit.sh` | `source "${SCRIPT_DIR}/../skills/handover/scripts/handover-lib.sh"` |

## 変更しないもの

- `claude/skills/continue/SKILL.md` — bin スクリプトへの依存なし
- `claude/skills/tdd-orchestrate/` — 無関係
- symlink 構造（`~/.claude/skills/` → dotfiles）
