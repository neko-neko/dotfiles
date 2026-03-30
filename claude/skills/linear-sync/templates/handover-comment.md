# Comment Template: Handover

ワークフロー中断（handover）時に Linear チケットのコメントとして投稿する内容の生成仕様。

## 生成ルール

1. 見出しは `## Handover — Phase {N} ({phase_name})`
2. 中断理由を明示する
3. project-state.json を添付した場合はその旨を記載
4. 未完了タスクの概要を簡潔に記載

## 出力フォーマット

~~~
## Handover — Phase {current_phase} ({phase_name})

**理由**: {reason: フェーズ完了 | コンテキスト逼迫 | ユーザー指示}
**添付**: project-state.json

**未完了タスク:**
- {task_description} ({status})
- {task_description} ({status})

**次のアクション:**
{next_action_summary}
~~~

## reason の判定

- フェーズ完了後の計画的 handover → "フェーズ完了"
- コンテキストウィンドウ逼迫 → "コンテキスト逼迫"
- ユーザーが明示的に中断を指示 → "ユーザー指示"
