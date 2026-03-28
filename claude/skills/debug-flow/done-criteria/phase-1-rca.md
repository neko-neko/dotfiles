---
phase: 1
name: rca
max_retries: 3
audit: required
---

## Criteria

### D1-01: RCA Report ファイルが存在し必須セクションを含む
- **severity**: blocker
- **verify_type**: automated + inspection
- **verification**:
  1. `Glob("docs/debug/YYYY-MM-DD-*-rca.md")` で RCA Report ファイルを検索する
  2. ファイル内に5セクション見出し（`## 1. Symptom`, `## 2. Investigation Record`, `## 3. Root Cause`, `## 4. Reproduction Test`, `## 5. Fix Strategy`）が存在するか `Grep` で確認する
- **pass_condition**: Glob 結果が1件以上、かつ5セクション見出しが全て存在すること
- **fail_diagnosis_hint**: Phase 1 Executor が RCA Report を `docs/debug/` 配下に出力しているか確認。ファイル名が `YYYY-MM-DD-*-rca.md` パターンに合致しているか確認。セクション見出しの記法（`##` + 番号 + タイトル）が設計書の RCA Report 構造と一致しているか確認する
- **depends_on_artifacts**: [docs/debug/]
- **forward_check**: Phase 2 (Fix Plan) の入力として RCA Report パスが渡される

### D1-02: Investigation Record の3サブセクションに実質的な内容がある
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  Investigation Record の各サブセクションを順に読み、以下を判定:
  1. Code Flow Trace: entry point からの呼び出しチェーンが1件以上記述されているか（ファイルパス + 関数名の組が1組以上）
  2. Architecture Context: 関連するパターン・規約・暗黙ルールが1件以上記述されているか
  3. Impact Scope: 影響を受けるファイルまたはモジュールが1件以上列挙されているか
- **pass_condition**: 上記3項目全てが各基準を満たすこと。見出しのみ・汎用的な記述のみの項目が0件
- **fail_diagnosis_hint**: FAIL した項目番号を特定し、RCA Report の Investigation Record セクションで該当サブセクションの内容を確認。code-explorer / code-architect / impact-analyzer の出力結果と照合して不足情報を補完する
- **depends_on_artifacts**: [docs/debug/*-rca.md]

### D1-03: Impact Scope のファイルパスがコードベースに実在する
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  1. RCA Report の Impact Scope セクションからファイルパスを正規表現で抽出する
  2. 各パスに対して `Glob` でファイルの存在を確認する
- **pass_condition**: 抽出された全パスが Glob で存在すること。存在しないパスが0件
- **fail_diagnosis_hint**: 存在しないパスをリストアップし、タイポか削除済みファイルかを確認。コードベースの最新状態と RCA Report の記述時点の差異も確認する
- **depends_on_artifacts**: [docs/debug/*-rca.md]

### D1-04: 除外した仮説が1件以上記録されている
- **severity**: blocker
- **verify_type**: inspection
- **verification**:
  1. RCA Report の Excluded Hypotheses セクションを読み取る
  2. 各仮説に「仮説」「検証方法」「棄却理由」の3要素が含まれているか確認する
  3. 最初の仮説が正解だった場合でも、なぜ他の可能性を除外したかの記録があるか確認する
- **pass_condition**: Excluded Hypotheses セクションに1件以上の記録があり、各記録に3要素が含まれていること
- **fail_diagnosis_hint**: 仮説が0件の場合、調査過程で代替原因を検討しなかった可能性がある。根本原因の特定過程で「他に何が原因となり得たか」を列挙し、それぞれの棄却理由を記録する
- **depends_on_artifacts**: [docs/debug/*-rca.md]

### D1-05: 再現テストが存在し実行結果が FAIL である
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  1. RCA Report の Reproduction Test セクションからテストファイルパスを抽出する
  2. `Glob` でテストファイルの存在を確認する
  3. テストコマンドを実行し、該当テストの結果が FAIL であることを確認する
- **pass_condition**: テストファイルが存在し、テストコマンドの実行結果で該当テストが FAIL であること
- **fail_diagnosis_hint**: テストファイルが存在しない場合は Phase 1 Executor が再現テストを作成したか確認する。テストが PASS する場合は再現テストがバグを正しく捕捉していない（テスト対象が間違っている）可能性がある。根本原因のメカニズムを再確認し、テストの assertion を修正する
- **depends_on_artifacts**: [docs/debug/*-rca.md, tests/]

### D1-06: Root Cause に具体的なファイルパス・行番号・メカニズムが記述されている
- **severity**: quality
- **verify_type**: inspection
- **verification**:
  1. RCA Report の Root Cause セクションを読み取る
  2. ファイルパス（`/` または `.` を含む文字列）が1件以上含まれているか確認する
  3. 行番号（`:` + 数字、または「行」+ 数字）が1件以上含まれているか確認する
  4. メカニズム（「なぜその行のコードが問題を引き起こすのか」の説明）が1文以上含まれているか確認する
- **pass_condition**: ファイルパス1件以上、行番号1件以上、メカニズム説明1文以上が Root Cause セクションに含まれること
- **fail_diagnosis_hint**: ファイルパスや行番号が欠落している場合は、code-explorer の出力から障害箇所を特定して追記する。メカニズムが不明な場合は、コードフロートレースの結果から「入力 X が処理 Y を経て状態 Z になる」形式で記述する
- **depends_on_artifacts**: [docs/debug/*-rca.md]

### D1-07: RCA Report が git コミット済み
- **severity**: blocker
- **verify_type**: automated
- **verification**:
  `git status --porcelain -- docs/debug/*-rca.md` を実行し、RCA Report ファイルが未コミット変更リストに含まれないことを確認する。
- **pass_condition**: `git status --porcelain` の出力に RCA Report パスが含まれないこと（出力行数 0）
- **fail_diagnosis_hint**: RCA Report が未コミットの場合、`git add` + `git commit` が実行されていない可能性がある。Phase 1 Executor の最終ステップでコミット処理を確認する
- **depends_on_artifacts**: [docs/debug/*-rca.md]
