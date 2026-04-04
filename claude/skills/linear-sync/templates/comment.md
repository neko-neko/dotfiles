# Comment Template: Phase Complete

各フェーズ完了時に Linear チケットのコメントとして投稿する内容の生成仕様。

## 生成ルール

1. 見出しは `## Phase {N}: {phase_name} — {verdict}` の形式
2. test_results が null の場合、テスト行は省略
3. audit_observations が空の場合、Observations セクションは省略
4. evidence_files が空の場合、Evidence セクションは省略
5. 簡潔に。各行は1行で完結させる
6. decisions が空の場合、Decisions セクションは省略
7. concerns が空の場合、Concerns セクションは省略
8. directives が空の場合、Directives セクションは省略
9. session 情報は sync_handover 時のみ含める。通常フェーズでは省略

## 出力フォーマット

~~~
## Phase {phase_number}: {phase_name} — {verdict}

**Summary**: {summary}
**テスト**: {passed}/{passed+failed} passed (coverage {coverage})
**Audit**: {verdict} — {observations_count} 件の observations

**Evidence:**
- {filename} — {label}
- {filename} — {label}

**Observations:**
- {criteria_id}: {observation} ({severity})
- {criteria_id}: {observation} ({severity})

### Decisions
{decisions を箇条書き}

### Concerns
{concerns を target_phase 付きで箇条書き}

### Directives
{directives を target_phase 付きで箇条書き}

### Evidence
{evidence を種別ごとに表示}

### Session
- Session ID: {session_id}
- Context Usage: {context_usage}
- Handover Reason: {handover_reason}
~~~

## verdict ごとの表記

- PASS: そのまま "PASS"
- FAIL: "FAIL" + 失敗理由があれば付記
- Done: "Done"（Audit Gate がないフェーズ）
- Skipped: "Skipped"（--accept 未指定時の Acceptance Test 等）
