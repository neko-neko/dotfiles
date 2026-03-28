ドキュメント監査スキル。4 Layer 構造でドキュメントの陳腐化・欠落・矛盾を検出し、ユーザー承認後に修正する。

## インターフェース

`/doc-audit` の引数で実行モードを指定する。

| 引数 | 動作 |
|------|------|
| (なし) | Scope B（全体棚卸し）で全 Layer 実行 |
| `--deps` | depends-on 検証のみ（Layer 1 + deps-analyzer） |
| `--hygiene` | 衛生チェックのみ（Layer 1 + coherence-analyzer） |
| `--coverage` | ドキュメント欠落検出のみ（Layer 0 + Layer 1 + coverage-analyzer） |
| `--knowledge` | 未文書化知識検出のみ（Layer 0 + business-rule + architecture） |
| `--meta` | メタドキュメント検査のみ（readme-analyzer + claude-md-analyzer） |
| `--range <commit>..<commit>` | commit 範囲に限定（Scope A 相当） |
| `--full` | 全 md 対象（デフォルト） |
| `--swarm` | エージェントチーム構成で実行 |

## 実行フロー

### Layer 0: Exploration

既存の並列探索エージェントをドキュメント観点の入力スコープで起動する:

```
code-explorer:    git diff 変更ファイル起点のコードフロー → 公開インターフェース特定
code-architect:   プロジェクト構造 + CLAUDE.md → アーキテクチャパターン全体像
impact-analyzer:  git diff 逆依存 → depends-on 未宣言のドキュメント候補
```

`--swarm` 有効時は Exploration Team（TeamCreate）で実行。`--deps`/`--hygiene` モードではスキップ。

### Layer 1: Script

スキルディレクトリからの相対パスで実行:

````bash
# 全 md 対象
bash "$(dirname "$SKILL_PATH")/scripts/doc-audit.sh" --full --json

# commit 範囲指定
bash "$(dirname "$SKILL_PATH")/scripts/doc-audit.sh" --range HEAD~5..HEAD --json

# undeclared チェックのみ（Audit Gate 再検証用）
bash "$(dirname "$SKILL_PATH")/scripts/doc-audit.sh" --check-undeclared --json
````

### Layer 2: Analysis

Layer 1 の JSON 結果 + Layer 0 の探索結果をエージェントにフィードする。

**構造系:**
- deps-analyzer（Layer 1 の broken_deps/undeclared_deps が 0 件ならスキップ）
- coverage-analyzer（常時起動）
- coherence-analyzer（Layer 1 の stale_signals/orphaned_docs が 0 件ならスキップ）

**知識系:**
- business-rule-analyzer（常時起動、Scope B のみ）
- architecture-analyzer（常時起動、Scope B のみ）
- readme-analyzer（常時起動）
- claude-md-analyzer（常時起動）

`--swarm` 有効時は7エージェントを Audit Team（TeamCreate）で実行し、メンバー間相互検証を行う。

非 swarm 時は並列 Agent 呼び出し。

### Layer 3: Fix

統合レポートをユーザーに提示し、各 finding について:

- **修正する** → fix_type に応じた修正を実行:
  - `deps_fix`: depends-on を Edit で修正
  - `content_update`: `/doc-check` に委譲
  - `new_doc`: feature-implementer エージェントでドキュメント新規作成
  - `delete`: ユーザー確認後にファイル削除
  - `merge`: ユーザー確認後にドキュメント統合
- **スキップ** → この finding は対応不要
- **後で対応** → 記録だけ残す

### doc-check 連携

depends-on 修正後、自動的に `/doc-check` を実行して内容更新を行う:

```
depends-on 修正完了
    ↓
/doc-check 実行（修正済み depends-on で影響検出）
    ↓
影響ドキュメントの内容更新
    ↓
新規ドキュメント作成（fix_type=new_doc の findings）
    ↓
doc-audit.sh --check-undeclared（新規ドキュメントの整合性確認）
```

one-shot 実行時は doc-check 連携は推奨のみ（自動実行しない）。

## feature-dev 統合

`/feature-dev --doc` で Phase 6 として実行される。詳細は feature-dev SKILL.md を参照。

## 制約

- ドキュメント更新前に必ずユーザー承認を得る。自動更新は禁止
- スクリプト（Layer 1）の出力をそのまま解釈する。独自にファイル走査しない
- エージェントの findings は confidence 0.80 未満を除外
- 設定されている言語で出力する
