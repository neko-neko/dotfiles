# Daily Brief — 設定テンプレート

`--setup` 時にこのテンプレートに沿って AskUserQuestion で設定を収集し、
`~/.claude/daily-brief/config.md` に書き出す。**このファイル自体は編集しない**（git 管理下のテンプレート）。

設定ファイルにはクライアント名・チャンネル名が含まれるため、git 管理外（`~/.claude/` 配下）に置く。

## 収集する項目

1. **Slack ワークスペースと監視チャンネル**
   - `slackcli auth list` で認証済みワークスペースを列挙し、ブリーフに含めるものを選択させる
   - ワークスペースごとに監視チャンネル（問い合わせ・障害報告が流れるチャンネル）を 1〜5 個。
     チャンネル名は `slackcli search channels <name> --json` で ID に解決して保存する
   - 自分の user_id（メンション検索のフォールバック用）。`slackcli search people <自分の名前> --json` で解決する
2. **Linear ワークスペース**
   - `linear auth list` で認証済み slug を列挙し、ブリーフに含めるものを選択させる
3. **プロジェクトルート**
   - 現在アクティブなリポジトリの絶対パス（3〜10 個）。
     候補提示には `ls ~/go/src/github.com/*/* -d` の結果と `~/.claude/projects/` の履歴を使ってよい
4. **カレンダー連携の有無**（既定: off）

## 出力フォーマット（~/.claude/daily-brief/config.md）

```markdown
# Daily Brief Config
# generated: YYYY-MM-DD by /daily-brief --setup

## slack
- workspace: rakmy
  user_id: UXXXXXXXX
  mention_query: "to:me"
  channels:
    - id: CXXXXXXXX
      name: dev-support
    - id: CYYYYYYYY
      name: incident
- workspace: another-ws
  ...

## linear
- workspace: neko-neko
- workspace: nishisoft

## projects
- /Users/nishikataseiichi/go/src/github.com/rakmy/rakmy_server
- /Users/nishikataseiichi/go/src/github.com/nishisoft/zamaa-career-chat
- /Users/nishikataseiichi/.dotfiles

## calendar
enabled: false
```
