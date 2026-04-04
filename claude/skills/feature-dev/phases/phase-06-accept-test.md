---
phase: 6
phase_name: accept-test
requires_artifacts:
  - code_changes
phase_references: []
invoke_agents: []
phase_flags: {}
---

## 実行手順

このフェーズは `--accept` フラグ指定時のみ有効。未指定時はスキップ。

プロジェクト固有のランタイム環境を使った Acceptance Test（Smoke/E2E 統合）を実行する。
テスト方法はプロジェクト種別により異なる:

- **Web アプリ**: Skill invoke: `/smoke-test`（dev サーバー起動 → アドホックテスト → VRT → E2E + フレーキー検出）
- **Mobile アプリ**: シミュレータ/エミュレータでの UI テスト
- **CLI ツール**: コマンド実行シナリオテスト
- **Library**: Integration Test で十分な場合は省略可（PAUSE してユーザーに確認）

プロジェクト種別の判定:
1. プロジェクトルートの構成ファイル（package.json, Podfile, pubspec.yaml, Cargo.toml 等）からプロジェクト種別を推定
2. 推定できない場合は PAUSE してユーザーに確認
3. Execute フェーズの concerns に「Integration Test でローカル依存が不可」がある場合、ここで対応

マージ前のローカル最終確認として位置づける。

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| accept_test_results | file | `accept-test-report.md` |

## Phase Summary テンプレート

```yaml
artifacts:
  accept_test_results:
    type: file
    value: "<accept-test-report.md パス>"
```
