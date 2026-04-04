---
trigger: audit_failure
---

# Audit Failure Regate Strategy

## 判定ロジック

1. phase-auditor の fix_instruction を取得
2. fix_instruction の分類:
   - コード変更を伴う（テスト追加、実装修正等）→ verification_chain
   - コード変更を伴わない（エビデンス不足、ドキュメント不備等）→ 現フェーズの re-audit のみ

## Rerun チェーン

### コード変更を伴う場合

1. fix_instruction を execute フェーズに注入
2. verification_chain をフル実行: execute → review → smoke-test（--smoke 時）

### コード変更を伴わない場合

1. fix_instruction に基づいて現フェーズ内で修正
2. 現フェーズの Audit Gate のみ再実行

## Escalation

max_retries（done-criteria で定義、デフォルト 3）超過時:

1. 全 attempt の fail_reasons を集約
2. linear-sync に escalation イベントを記録（--linear 時）
3. ユーザーに判断を委ねる:
   ```
   Phase {N} が {max_retries} 回の Audit Gate に失敗しました。
   
   累積診断:
   - Attempt 1: <fail_reason>
   - Attempt 2: <fail_reason>
   - Attempt 3: <fail_reason>
   
   選択肢:
   (1) 追加リトライ
   (2) このフェーズをスキップして続行
   (3) ワークフローを中止
   ```

## コンテキスト注入

```yaml
regate_context:
  trigger: audit_failure
  source_phase: <current_phase>
  fix_instructions:
    - criteria_id: <基準ID>
      what: <何を修正するか>
      how: <どう修正するか>
      verify: <検証方法>
  attempt: N
  cumulative_diagnosis: [<過去の診断>]
```
