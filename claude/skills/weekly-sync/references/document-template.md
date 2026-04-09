# 定例 Document テンプレート

Phase 4 Step 3 で作成する Linear Document のデフォルトテンプレート。

## Linear Document

### タイトル

```
[{document_prefix} {to}] {customer_facing_title}
```

例: `[定例 2026-04-09] 地代家賃（賃料設定）フルリニューアル`

### 本文テンプレート

```markdown
## 今週の進捗
{期間内に何が進んだか。config の rewrite_principles と terminology を適用。}

## 現在の状況
{今どこにいるか。ステータスを顧客向け言語で。}

## 次のアクション
{次に何をするか / 何を待っているか。}
```

### 作成コマンド

```bash
linear document create \
  --title "[{document_prefix} {to}] {customer_facing_title}" \
  --content-file {draft_file_path} \
  --issue {identifier}
```

## 出力先コメント

### テンプレート

```markdown
### {to} 定例アップデート

**進捗:** {progress}

**現在の状況:** {status}

**次のアクション:** {next_action}
```

### 新規アイテムの body テンプレート

初めて出力先に作成するアイテムには、ベースライン情報を含む body を設定する:

```markdown
## 概要
{1-2文で何をするか/何が起きているか}

## 背景
{なぜこの対応が必要か}

## 対応方針
{どういうアプローチで解決するか。技術用語なし}

## 現在の状況
{今どこまで進んでいるか}
```

## ドラフト生成ガイドライン

1. **入力:** scan.json のチケット詳細（コメント、外部リンク）
2. **変換:** config の `rewrite_principles` と `terminology` を適用
3. **外部リンク:** 顧客に有用なもの（公開 Slack スレッド、Google Sheets 等）は `[Slack](url)` 形式で含める。内部専用リンクは含めない
4. **Done チケット:** 「対応完了」+ 何をしたかの1-2文。次のアクション: 「なし」
5. **Backlog チケット:** 経緯の説明 + 現在の検討状況。次のアクション: 「対応時期を調整」等
6. **ベースラインとの重複回避:** `[{baseline_prefix}]` Document がある場合、概要・背景・対応方針は繰り返さず、今週の差分のみ記述
