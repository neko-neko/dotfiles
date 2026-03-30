# Comment Template: Phase Complete

各フェーズ完了時に Linear チケットのコメントとして投稿する内容の生成仕様。

## 生成ルール

1. 見出しは `## Phase {N}: {phase_name} — {verdict}` の形式
2. test_results が null の場合、テスト行は省略
3. audit_observations が空の場合、Observations セクションは省略
4. evidence_files が空の場合、Evidence セクションは省略
5. 簡潔に。各行は1行で完結させる

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
~~~

## verdict ごとの表記

- PASS: そのまま "PASS"
- FAIL: "FAIL" + 失敗理由があれば付記
- Done: "Done"（Audit Gate がないフェーズ）
- Skipped: "Skipped"（--smoke 未指定時の Smoke Test 等）
