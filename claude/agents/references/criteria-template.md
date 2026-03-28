---
name: criteria-template
description: done-criteria ファイルのテンプレートと品質ルール。新規 done-criteria 作成時に参照する。
---

# Done Criteria Template

## File Format

```markdown
---
phase: {N}
name: {phase_name}
max_retries: 3
---

## Criteria

### {ID}: {基準タイトル}
- **severity**: blocker | quality
- **verify_type**: automated | inspection
- **verification**:
  {Audit Agent が実行する具体的な手順。inspection の場合は番号付きステップ必須}
- **pass_condition**: {主観語禁止。数値閾値 or パターンマッチで判定可能な条件}
- **fail_diagnosis_hint**: {FAIL 時に何を調べれば解消するかの方向性}
- **depends_on_artifacts**: [{検証に必要な成果物パス}]
- **forward_check**: {次フェーズの入力として十分かの観点。省略可}
```

## Template Rules

These rules are enforced by the template structure itself:

1. **pass_condition に主観語禁止**: 「適切」「十分」「具体的」「正しい」は使えない。数値閾値（例: "2件以上"）またはパターンマッチ（例: "ファイルパスが含まれる"）で記述する。
2. **inspection 型は番号付きステップ必須**: verification に "1. ... 2. ... 3. ..." の形式で判定手順を列挙する。
3. **fail_diagnosis_hint 必須**: FAIL 時に「何を調べれば解消するか」の方向性を必ず記述する。
4. **severity の使い分け**:
   - `blocker`: 未達なら必ず FAIL。修正→再監査のリトライ対象。
   - `quality`: 未達でも全 blocker が PASS なら警告のみで通過可能。リトライ対象にしない。

## Human Review: 3-Point Scan

done-criteria ファイルの作成・変更時、以下の3点を確認:

1. **pass_condition を読んで、PASS/FAIL が自分でも判断できるか？** → できなければ曖昧
2. **blocker 基準が多すぎないか？** → 全部 blocker だとリトライ地獄になる
3. **このフェーズで本当に検証すべきことが漏れていないか？** → カバレッジ

所要時間の目安: 1ファイルあたり2-3分。

## ID Convention

- Phase N の基準: `DN-01`, `DN-02`, ...
- Evidence-derived 基準（動的合成）: `DN-E1`, `DN-E2`, ...
