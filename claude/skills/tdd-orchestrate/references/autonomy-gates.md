# Autonomy Gates — 判断テーブル

Phase ごとの自律判断ルール。SKILL.md の Autonomy Summary から参照される。

## Gate Decision Table

| Phase | 状況 | アクション | 根拠 |
|-------|------|-----------|------|
| 1 | brainstorming が設計質問をする | **PAUSE:** ユーザーに転送 | 設計品質はドメイン知識に依存 |
| 1 | brainstorming が「実装準備OK？」と確認 | **AUTO:** 「Yes」→ Phase 2 | オーケストレーターの目的 |
| 2 | writing-plans が実行方式を提案 | **AUTO:** 「Subagent-Driven」 | 同一セッション完結が前提 |
| 3 | worktree ディレクトリが未設定 | **AUTO:** `.worktrees/` を使用 | 安全なデフォルト |
| 3 | ベースラインテストが失敗 | **PAUSE:** ユーザーに報告 | リスク判断が必要 |
| 4 | implementer が設計書から回答可能な質問 | **AUTO:** 設計書から回答 | レイテンシ低減 |
| 4 | implementer が設計書にない質問 | **PAUSE:** ユーザーに転送 | 知識ギャップ |
| 4 | spec reviewer が問題を検出 | **AUTO:** implementer が修正 | 通常の TDD ループ |
| 4 | code quality reviewer が問題を検出 | **AUTO:** implementer が修正 | 通常の TDD ループ |
| 4 | タスクが fix+review を3回失敗 | **PAUSE:** ユーザーにエスカレーション | 設計ギャップの可能性 |
| 4 | 全タスク完了、最終レビュー通過 | **AUTO:** Phase 5 へ進行 | 通常フロー |
| 5 | テスト検証が通過 | **AUTO:** オプション提示へ | 通常フロー |
| 5 | merge/PR/keep/discard の選択 | **PAUSE:** ユーザーが選択 | 不可逆操作 |
