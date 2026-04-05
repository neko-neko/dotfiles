---
phase: 1
phase_name: rca
phase_references: []
invoke_agents:
  - code-explorer
  - code-architect
  - impact-analyzer
phase_flags:
  swarm: optional
  linear: optional
---

## 実行手順

1. **症状の構造化:** エラーメッセージ、スタックトレース、再現手順を整理
2. **並列探索エージェント起動:**
   - `code-explorer`: 障害箇所のコードフロー（entry point -> データ層）をトレース
   - `code-architect`: 関連するアーキテクチャパターン・制約・暗黙ルールを抽出
   - `impact-analyzer`: 障害箇所からの逆方向依存追跡、副作用リスクの特定
3. **探索結果の統合 -> 根本原因の特定:**
   - 各エージェントの結果を統合し、仮説を立案
   - 1つの仮説を最小変更で検証（max 3 rounds）
   - 仮説棄却時は新仮説を立案（3回失敗でアーキテクチャ問題として PAUSE）
4. **再現テスト作成:** 根本原因を証明する最小再現テスト（failing test）を作成
5. **RCA Report 作成:** 調査結果を構造化文書にまとめる（symptoms / investigation / root-cause / fix-strategy / evidence-plan の 5 セクション。構成詳細は「RCA Report 構成」セクション参照）
6. **worktree 作成:** `worktrunk:worktrunk` を invoke し、修正用 worktree とブランチを作成
7. **コミット:** RCA Report と再現テストを worktree 内にコミット

### --swarm 時（Investigation Team）

TeamCreate で "investigation-{bug}" チームを作成:
- メンバー: code-explorer, code-architect, impact-analyzer
- メンバー間通信を有効化: Explorer の発見 -> Architect がパターン分析 -> Impact が依存先を深掘り
- 共有タスク: RCA Report の Investigation Record 各セクションをタスクとして割り当て

### --linear 時

rca フェーズ開始前に:
1. `/linear-sync` の `resolve_ticket` セクションを Read し実行
2. チケット確定後、`sync_workflow_start` を実行

### GATE 条件

- 仮説検証3回失敗 -> PAUSE（アーキテクチャ問題エスカレーション）
- 再現テスト作成不可 -> PAUSE（手動再現を提案）
- worktree テスト失敗 -> PAUSE（続行 or STOP をユーザーに提案）

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| rca_report | file | `docs/debug/YYYY-MM-DD-{bug}-rca.md` |
| reproduction_test | file | テストファイル |

## RCA Report 構成

rca_report は以下 5 セクションを含む（`pipeline.yml` の `rca_report.contract.verification.sections_present` で強制）:

1. **symptoms** — 症状（エラー、再現条件、影響範囲）
2. **investigation** — 調査記録（Code Flow Trace, Architecture Context, Impact Scope, Symmetry Check の 4 サブセクション）
3. **root-cause** — 根本原因（ファイルパス+行番号+メカニズム、除外仮説の記録を含む）
4. **fix-strategy** — 修正方針（影響範囲・対パス修正の要否を明記）
5. **evidence-plan** — execute フェーズで収集すべき evidence の計画

### Evidence Plan セクションの記述内容

execute フェーズで収集すべき evidence を列挙する:

- **回帰テスト結果**: reproduction_test が fix 適用後に PASS することを示すログ
- **根本原因メカニズムの計測値**: (該当する場合) race condition の再現頻度、メモリ使用量、タイミング差等の定量データ
- **修正前後の挙動比較**: (該当する場合) ログ diff、スクリーンショット、トレース等

各項目について type（log / metric / screenshot 等）と location（ファイルパスまたは外部 URL）を記載する。

**注記**: 現時点では debug-flow のみ Evidence Plan を生成する。将来 feature-dev の design フェーズにも Evidence Plan を導入予定（**follow-up (Linear 未起票 TODO)**: feature-dev design Evidence Plan 導入を追跡する Linear issue を別途作成すること）。それまでは feature-dev/phases/execute.md が参照する "design Audit Gate 完了後に生成された Evidence Plan" は dangling reference である点に留意する。

### Evidence Plan の markdown 例

rca_report 内の `## evidence-plan` セクション（kebab-case ヘッダーで `pipeline.yml` の `sections_present` check と一致）は、以下のような形式で記述する:

```markdown
## evidence-plan

- type: log
  location: docs/debug/2026-04-05-null-deref/regression.log
  description: reproduction_test が fix 適用後に PASS することの CI ログ

- type: metric
  location: docs/debug/2026-04-05-null-deref/race-freq.json
  description: race condition 再現頻度 (修正前 0.12 → 修正後 0.00)

- type: screenshot
  location: docs/debug/2026-04-05-null-deref/before-after/
  description: UI state 修正前後の比較
```

各エントリは `type` / `location` / `description` の 3 フィールドを持つマークダウンリスト項目とし、done-criteria の `rca_report.additional` バリデーション（「Evidence Plan セクションに、type と location を伴う具体的な evidence エントリが最低 1 項目記述されているか」）を満たす形式とする。

## Phase Summary テンプレート

```yaml
artifacts:
  rca_report:
    type: file
    value: "<RCA Report パス>"
  reproduction_test:
    type: file
    value: "<再現テストファイルパス>"
```
