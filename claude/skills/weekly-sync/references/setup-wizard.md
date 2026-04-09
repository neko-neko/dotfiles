# Setup Wizard

初回セットアップまたは `--setup` 指定時に実行するウィザード。
`.weekly-sync/config.md` を対話的に生成する。

## フロー

### Step 1: Linear チーム選択

```bash
linear team list
```

- 1チーム → 自動選択
- 複数チーム → ユーザーに選択を求める
- 0チーム → エラー終了

workspace は `linear` CLI の設定から自動取得。

### Step 2: 出力先アダプタ選択

「顧客向けの出力先はどれですか？」

| 選択肢 | 説明 |
|--------|------|
| `github` | GitHub Project（Issue + Project Board） |
| `notion` | Notion Database（未実装） |
| `gdocs` | Google Docs（未実装） |

未実装のアダプタが選択された場合は「現在 github のみ対応しています」と案内。

### Step 3: アダプタ固有設定

**GitHub の場合:**

1. 「GitHub Organization 名を入力してください」
2. 「リポジトリ名を入力してください（{org}/{repo} 形式）」
3. 「GitHub Project の番号を入力してください」
   - `gh project list --owner {org}` で候補を表示してもよい
4. 「あなたの GitHub ユーザー名を入力してください（スキャンで除外するため）」

入力後、接続確認:
```bash
gh project view {project_number} --owner {org} --format json
```

### Step 4: カスタムフィールド自動検出

```bash
gh project field-list {project_number} --owner {org} --format json
```

検出されたフィールドを表示し、config の `custom_fields` へのマッピングを提案:
- `Status` → ステータスマッピング
- Single Select フィールド → カテゴリ/種別/優先度の候補
- Text フィールド → Linear ID の候補

ユーザーに確認・調整を求める。

### Step 5: ステータスマッピング

Linear の6ステータスに対応する出力先のステータスラベルを設定。
デフォルト値を提案:

```
Backlog    → 検討中
Todo       → 対応予定
In Progress → 対応中
In Review  → 確認中
Done       → 完了
Canceled   → 対応見送り
```

### Step 6: ラベルマッピング

Linear のラベル一覧を取得:
```bash
linear label list --team {team} --json
```

出力先のラベルと対応付け。1対1でなくてもよい（複数→1、無視 等）。

### Step 7: リライト原則

デフォルトテンプレートを提示:

```
1. 技術モデル名は画面名・機能名に置換する
2. 症状ベースで書く（「〇〇が表示されない」「〇〇できない」）
3. Phase N → 第N段階
4. PR番号・ブランチ名・クラス名は一切書かない
5. 開発者名は除外。ビジネス側の名前は残す
```

「このまま使いますか？カスタマイズする場合は修正内容を教えてください」

### Step 8: 用語対応表

「プロジェクト固有の技術用語 → 顧客向け表現の対応表を作成します。入力してください（空でもOK）」

例:
```
ShopRent: 地代家賃
BVA: 予実対比
```

### Step 9: Document 設定

- `document_prefix`: 定例 Document のプレフィックス（デフォルト: `定例`）
- `baseline_prefix`: ベースライン Document のプレフィックス（デフォルト: `顧客向け`）

### Step 10: 確認と保存

生成した config.md の内容を表示し、ユーザーに確認:

「以下の内容で `.weekly-sync/config.md` を作成します。問題ありませんか？」

- `ok` → ファイル作成
- 修正指示 → 該当部分を更新し再提示
