# Claude Code 設定改善設計

## 概要

Claude Code の dotfiles 管理における3つの改善と1つの新機能追加を行う。

- post-commit.sh のパス解決バグ修正
- notify.sh の通知リッチ化
- CLAUDE.md の簡素化
- SessionStart フックの新規追加

## 1. post-commit.sh パス解決バグ修正

### 問題

`handover-lib.sh` の `get_current_branch()` が `git rev-parse --abbrev-ref HEAD` を CWD ベースで呼んでいる。PostToolUse フックのコンテキストでは CWD が `$PROJECT_DIR` と一致しない場合があり、dotfiles リポジトリ以外のプロジェクトでブランチ名の取得に失敗する。

### 修正

**`handover-lib.sh`**:

- `get_current_branch()` にオプション引数 `$1` (project_dir) を追加
- 指定があれば `git -C "$1" rev-parse --abbrev-ref HEAD` を使用
- `find_active_session_dir()` 内の呼び出しを `get_current_branch "$root"` に変更

**影響を受ける関数**:
- `get_current_branch()` — 引数追加（後方互換: 引数なしなら従来通り CWD ベース）
- `find_active_session_dir()` — `get_current_branch` に `$root` を渡す

**テスト**: `post_commit_spec.sh` の git mock で CWD != PROJECT_DIR のケースを追加

## 2. notify.sh の通知リッチ化

### 現状

通知タイプ（idle/permission/question）を問わず同じフォーマット。タイプの違いが視覚的にわからない。

### 改善

タイプ別にアイコンプレフィックスを付与:

| タイプ | アイコン | 用途 |
|--------|--------|------|
| idle | ✅ | タスク完了通知 |
| permission | 🔐 | 承認待ち |
| question | 💬 | 質問回答待ち |
| その他 | 📢 | 汎用通知 |

- `TITLE` にアイコンを含めて `"✅ Claude Code"` のように表示
- WezTerm toast_notification / osascript 両方で同じアイコンを使用
- 引数インターフェース変更なし（TYPE 引数から自動判定）

## 3. CLAUDE.md の簡素化

### 現状

60行中、Handover Protocol が約30行。スキル固有の実装詳細がコアルールと混在。

### 改善方針

**CLAUDE.md に残す（コアルール）**:
- コミュニケーション方針
- 出力方針
- 実装規律
- マルチエージェント
- Intent Guard
- セッション管理（1-2行に圧縮）
- Document Dependency Check

**スキルに移動**:
- Handover Protocol の全詳細 → `claude/skills/handover/SKILL.md` に統合
  - パス解決ルール
  - handover.md の生成ルール
  - マルチエージェント時の自律的 Handover
  - マイグレーション手順

**結果**: CLAUDE.md は約30行に短縮

## 4. SessionStart フックの追加

### 目的

CLAUDE.md の「セッション開始時に handover セッションを確認すること」を LLM の記憶に頼らず自動化する。

### 設計

**新規スクリプト: `claude/hooks/session-start.sh`**

1. `git rev-parse --show-toplevel` でプロジェクトルートを取得
2. `${PROJECT_DIR}/.claude/handover/` を走査
3. READY ステータスのセッションがあれば情報を stdout に出力:
   - ブランチ名
   - タスク総数 / 完了数
   - 次のアクション（最初の未完了タスクの description）
4. セッションがなければ何も出力しない（ノイズゼロ）

**`settings.json` への追加**:

```json
"SessionStart": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "\"${HOME}/.dotfiles/claude/hooks/session-start.sh\"",
        "timeout": 10
      }
    ]
  }
]
```

**依存**: `handover-lib.sh` の `scan_sessions()` を再利用

## ファイル変更一覧

| ファイル | 変更種別 |
|---------|---------|
| `claude/skills/handover/scripts/handover-lib.sh` | 修正（get_current_branch + find_active_session_dir） |
| `claude/hooks/notify.sh` | 修正（アイコン追加） |
| `claude/CLAUDE.md` | 修正（Handover 詳細を削除・簡素化） |
| `claude/skills/handover/SKILL.md` | 修正（Handover 詳細を移動・統合） |
| `claude/hooks/session-start.sh` | 新規作成 |
| `claude/settings.json` | 修正（SessionStart フック追加） |
| `claude/hooks/post_commit_spec.sh` | 修正（テストケース追加） |
