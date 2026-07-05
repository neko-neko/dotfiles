---
name: review-pack
description: >-
  AI が実装した変更の「受け入れ判定」を1画面で行うためのレビューパックを生成する。
  diff 要約・テスト/リンタ実行証跡・リスクフラグ・Verification Contract 準拠状況を
  1つのレポートに集約し、APPROVE / REWORK の判断材料を揃える。
  実装完了後・コミット前・PR 作成前のレビュー依頼時、または /review-pack で起動。
user-invocable: true
argument-hint: "[base-ref] [--no-tests] [--html]"
---

# Review Pack — AI 出力の受け入れ判定パック

/code-review や belt のレビューが「問題を**探す**」のに対し、本スキルは「人間が**受け入れ判定を下す**」ための証跡パックを作る。
出力の原則: **✅ 自動確認済み**（機械的に検証できた事実）と **👀 要人間判断**（判断が必要な箇所）を明確に分離し、人間の目を後者だけに向けさせる。

**開始時アナウンス:** 「Review Pack を生成します（base: {base-ref}）」

## Options

| Option | 効果 |
|--------|------|
| `base-ref` | 比較基点（既定: デフォルトブランチとの merge-base。ブランチが同一なら HEAD との working diff） |
| `--no-tests` | テスト実行をスキップ（証跡セクションに「未実行」と明記） |
| `--html` | terminal 出力に加えて HTML レポートを生成し SendUserFile で送る |

## Security Rules

- 本スキルは対象リポジトリのコードを**変更しない**。書き込みは `.agents/review-pack/` 配下のレポートのみ
- `git commit` / `git push` / デプロイ系コマンドは実行禁止（判定後の操作はユーザーの指示を待つ)
- テスト・リンタの実行は許可（read + 実行のみ）。DB マイグレーション実行やコンテナ再作成など環境を変えるコマンドは禁止

## Phase 1: Scope 確定

1. base-ref の決定:
   - 引数で指定があればそれを使う
   - なければ `git remote show origin | grep 'HEAD branch'` でデフォルトブランチを特定し、`git merge-base HEAD origin/<default>` を基点とする
   - 現在ブランチ = デフォルトブランチ の場合は working diff（`git diff HEAD` + untracked）を対象にする
2. `git diff --stat <base>` で変更ファイル一覧・規模を取得する
3. 変更ファイル数が 30 を超える場合はディレクトリ単位に要約する（全ファイル列挙しない）

## Phase 2: Evidence 収集（テスト・リンタ実行証跡）

**アナウンス:** 「Phase 2: 検証コマンドを実行します」

1. プロジェクトの検証コマンドを特定する。探索順: CLAUDE.md の記載 → package.json scripts / Makefile / Taskfile / justfile → 言語慣習（go test ./..., pytest, etc.）
2. lint / typecheck / test を実行し、**実際のコマンドと出力の要点（末尾 20 行程度）を記録する**。コード読解だけで PASS 扱いにしない
3. テストが 5 分を超えそうな場合、diff に関連するパッケージ/ディレクトリに絞って実行し、絞ったことをレポートに明記する
4. `--no-tests` 時は全項目「未実行（--no-tests 指定）」と記録する

## Phase 3: Risk Scan（機械的リスク検出）

diff に対して以下を機械的にチェックし、該当項目を 👀 リストに載せる:

| チェック | 方法 |
|---------|------|
| 秘密情報の混入疑い | `git diff <base> \| grep -inE '(password\|secret\|token\|api[_-]?key\|BEGIN.*PRIVATE)'`（変数名だけの hit は文脈確認の上で除外可） |
| マイグレーション/スキーマ変更 | migrations/, schema, DDL を含むファイルの変更有無 |
| 設定・環境変数の変更 | *.env*, config/, *.yml, *.toml, Dockerfile の変更有無 |
| テストの削除・skip 追加 | diff 内の削除行に test 関数、追加行に `skip`/`xit`/`t.Skip` |
| 大規模変更ファイル | 1 ファイルで ±300 行超 |
| 新規 TODO/FIXME | 追加行の `TODO\|FIXME\|HACK` |
| 公開 API/IF の変更 | エクスポートされた関数シグネチャ・エンドポイント定義の変更 |

## Phase 4: Verification Contract 照合

ユーザーのグローバル規約（Verification Contract）に対する準拠状況を判定する:

- [ ] 検証は実コマンド実行に基づくか（Phase 2 の証跡があるか）
- [ ] happy path 以外の確認（境界値・異常系・idempotency）が少なくとも 1 件あるか。**なければ、diff から最もリスクの高い箇所に対する adversarial probe を 1 つ提案し、可能なら実行する**
- [ ] 3 ファイル以上の編集 or backend/API/infra 変更に該当する場合、「独立 verification 推奨」フラグを立てる

## Phase 5: Output

1. レポートを `.agents/review-pack/{branch}-{YYYY-MM-DD}.md` に保存し、terminal に要約を出力する
2. `--html` 時は同内容の HTML を生成して SendUserFile で送る

```markdown
# Review Pack — {branch} @ {sha7} (YYYY-MM-DD)

## 概要
{この変更が何をするものか 2〜3 行。ユーザーが依頼した内容との対応}

## ✅ 自動確認済み
- lint: `{実行コマンド}` → PASS
- typecheck: `{実行コマンド}` → PASS
- test: `{実行コマンド}` → {n} passed / {m} failed（failed 時は出力抜粋）
- 秘密情報スキャン: 検出なし

## 👀 要人間判断（ここだけ見ればよい）
1. {file:line} — {なぜ人間の判断が要るか 1 行}（例: マイグレーションが本番データに不可逆）
2. ...

## ⚠ Verification Contract
- adversarial probe: {実行した/提案のみ} — {内容と結果}
- 独立 verification: {推奨/不要}（{理由}）

## 判定テンプレート
- APPROVE する場合: このままコミットへ
- REWORK する場合（コピペ用）:
  > 以下を修正してください: {👀 項目のうち差し戻すものを列挙}
```

## 完了条件

- [ ] テスト/リンタの実行証跡（コマンド + 出力）がレポートに含まれる、または未実行の理由が明記されている
- [ ] 👀 要人間判断 が 0 件の場合、「機械的リスク検出はすべて陰性」と明示されている
- [ ] レポートが `.agents/review-pack/` に保存されている
- [ ] 対象リポジトリのコードに変更を加えていない（`git status` が Phase 1 時点と同じ）
