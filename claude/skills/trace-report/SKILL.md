---
name: trace-report
description: >-
  trace.jsonl を分析し、パイプラインの振り返りレポートを生成する。
  セッション単位またはブランチ/全体で集約分析が可能。
user-invocable: true
---

# Trace Report

trace.jsonl を読み込み、パイプラインの実行状況・レビュー効果・エージェント性能を分析するレポートを生成する。

**開始時アナウンス:** 「Trace Report を生成します。」

## 引数パース

| 引数 | 動作 |
|------|------|
| (なし) | 現在のセッションの trace.jsonl を分析 |
| `--all` | `.claude/handover/` 配下の全 trace.jsonl を集約分析 |
| `--branch <name>` | 指定ブランチの全セッションの trace.jsonl を集約分析 |

## trace.jsonl の検出

### 単体セッション（引数なし）

1. Bash で現在のセッションの trace.jsonl を検出する:
   ```bash
   source ~/.dotfiles/claude/skills/handover/scripts/handover-lib.sh
   session_dir=$(find_active_session_dir 2>/dev/null)
   if [[ -n "$session_dir" ]]; then
     echo "${session_dir}/trace.jsonl"
   fi
   ```
2. ファイルが見つからない場合 → 「trace.jsonl が見つかりません。レビュースキルでの trace 記録が有効になっているか確認してください。」と報告して終了

### 集約分析（`--all` / `--branch`）

```bash
# --all の場合
find .claude/handover -name trace.jsonl 2>/dev/null

# --branch <name> の場合
find .claude/handover/<name> -name trace.jsonl 2>/dev/null
```

複数ファイルが見つかった場合は全て結合して分析する。

## レポート生成

trace.jsonl を `jq` で集計し、以下のセクションを含むマークダウンレポートを生成する。レポートはファイルに保存せず、そのまま出力する。

### 1. Pipeline Summary

```bash
jq -s '
  [.[] | select(.event == "phase_start")] |
  group_by(.data.pipeline) |
  map({
    pipeline: .[0].data.pipeline,
    phases_started: length,
    first_ts: (sort_by(.ts) | first.ts),
    last_ts: (sort_by(.ts) | last.ts)
  })
' trace.jsonl
```

出力フォーマット:
```
## Pipeline Summary
| Pipeline | Phases completed | Total duration | Handovers |
|----------|-----------------|----------------|-----------|
```

### 2. Phase Breakdown

```bash
jq -s '
  [.[] | select(.event == "phase_start" or .event == "phase_end")] |
  group_by(.data.pipeline + "-" + (.data.phase | tostring)) |
  map({
    phase: .[0].data.phase,
    phase_name: .[0].data.phase_name,
    duration_ms: ([.[] | select(.event == "phase_end") | .data.duration_ms] | first // null)
  }) | sort_by(.phase)
' trace.jsonl
```

出力フォーマット:
```
## Phase Breakdown
| Phase | Duration | Retries | Result |
|-------|----------|---------|--------|
```

### 3. Review Effectiveness

```bash
jq -s '
  [.[] | select(.event == "user_decision")] |
  group_by(.data.pipeline) |
  map({
    pipeline: .[0].data.pipeline,
    total_presented: ([.[] | .data.total_findings] | add),
    total_accepted: ([.[] | .data.selected | length] | add),
    total_rejected: ([.[] | .data.rejected | length] | add)
  })
' trace.jsonl
```

出力フォーマット:
```
## Review Effectiveness
| Pipeline | Findings presented | Accepted | Rejected | Accept rate |
|----------|-------------------|----------|----------|-------------|
```

### 4. Agent Performance

```bash
jq -s '
  [.[] | select(.event == "agent_end")] |
  group_by(.data.agent) |
  map({
    agent: .[0].data.agent,
    runs: length,
    avg_duration_ms: ([.[] | .data.duration_ms] | add / length | round),
    avg_findings: ([.[] | .data.findings_count] | add / length * 10 | round / 10),
    parse_success_rate: (([.[] | select(.data.parse_method == "json_direct")] | length) / length * 100 | round)
  })
' trace.jsonl
```

出力フォーマット:
```
## Agent Performance
| Agent | Runs | Avg duration | Avg findings | Parse success rate |
|-------|------|-------------|-------------|-------------------|
```

### 5. Top Rejected Categories

```bash
jq -s '
  [.[] | select(.event == "user_decision") | .data.findings_snapshot[] | select(.selected == false)] |
  group_by(.category) |
  map({category: .[0].category, count: length, example: .[0].description}) |
  sort_by(-.count) | .[0:5]
' trace.jsonl
```

出力フォーマット:
```
## Top Rejected Categories (false positive candidates)
| Category | Rejected count | Example |
|----------|---------------|---------|
```

### 6. Anomalies

以下のイベントを抽出してリスト表示する:
- `event == "retry"` — リトライ発生
- `event == "error"` — エージェントエラー
- `event == "agent_end"` where `parse_method != "json_direct"` — パースフォールバック
- `event == "handover"` where `reason == "context_pressure"` — コンテキスト逼迫

```
## Anomalies
- Phase N retried M time(s) (reason)
- Agent X used regex_fallback N/M times
- Agent Y errored: error_type
- Handover triggered at Phase N due to context_pressure
```

## エラーハンドリング

| ケース | 対応 |
|--------|------|
| trace.jsonl が空 | 「trace データがありません」と報告 |
| jq パースエラー | 不正な行をスキップし、パース可能な行のみで集計 |
| --branch で指定ブランチが存在しない | 「ブランチ <name> の trace.jsonl が見つかりません」と報告 |

## 制約

- レポートはファイルに保存せず、そのまま会話に出力する
- trace.jsonl の内容を変更しない（読み取り専用）
- 設定されている言語で出力する
