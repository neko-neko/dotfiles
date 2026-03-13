# Kanban TUI 設計書

- **Date**: 2026-03-14
- **Status**: Approved

## 概要

既存の kanban Web UI (Deno + Hono + Preact) に対して、ターミナル内で軽量に操作できる TUI クライアントを追加する。ターミナルから離れずにタスクの確認・追加・編集・ステータス変更を行うことが目的。

## 設計判断

### アプローチ: Split Pane + ステータスサマリーバー

- 左ペインにステータスグループ別タスクツリー、右ペインに選択中タスクの詳細表示
- 上部にステータスサマリーバー（各ステータスのタスク数を一覧表示）
- vim ライクなキーバインド + マウス操作対応

**選定理由**:
- Terminal Luxe テーマとの相性が良い（ボーダー装飾、ペイン分割）
- 一覧と詳細を同時に確認でき、素早い操作に最適
- 幅80カラムでも破綻しない（カンバン型は5カラム表示が困難）
- 右ペインを Handover / Session 表示に切り替えれば拡張可能

### ロジック共通化: リポジトリ層の直接 import

- TUI は HTTP API を経由せず、`json-file-*-repository.ts` / `sync-service.ts` を直接 import
- Web UI と TUI でリポジトリ/サービス層を完全共通化。レンダラーだけが異なる構成
- サーバー起動不要で TUI 単体で動作

### `/kanban` スキル統合

- `/kanban` → TUI 起動のエントリポイントに変更
- `/kanban add` / `/kanban move` / `/kanban sync` はワンショットコマンドとして残す（TUI 起動なし、リポジトリ直接操作）
- `/kanban show` は削除（TUI に統合）
- `/kanban serve` は変更なし（Web サーバー起動）

## アーキテクチャ

```
~/.claude/tools/kanban-server/
├── src/
│   ├── repositories/          # 既存 — 共通ロジック (変更なし)
│   │   ├── board-repository.ts
│   │   ├── json-file-board-repository.ts
│   │   ├── task-repository.ts
│   │   └── json-file-task-repository.ts
│   ├── services/              # 既存 — 共通サービス (変更なし)
│   │   ├── sync-service.ts
│   │   └── git-sync-service.ts
│   ├── routes/                # 既存 — Web API 用
│   └── tui/                   # 新規 — TUI レイヤー
│       ├── app.tsx            # Ink <App> ルート、キーバインド管理
│       ├── theme.ts           # Terminal Luxe カラー定義 (ANSI 256/truecolor)
│       ├── views/
│       │   ├── board-view.tsx       # Split Pane メイン画面
│       │   ├── board-select.tsx     # ボード選択画面
│       │   ├── task-editor.tsx      # タスク編集 (インラインフォーム)
│       │   └── handover-view.tsx    # Handover/Session ブラウザ
│       ├── components/
│       │   ├── summary-bar.tsx      # ステータスサマリーバー
│       │   ├── task-tree.tsx        # 左ペイン: ツリーリスト
│       │   ├── task-detail.tsx      # 右ペイン: 詳細パネル
│       │   ├── status-badge.tsx     # ステータス/優先度アイコン
│       │   └── keybind-bar.tsx      # 下部キーバインドヘルプ
│       └── hooks/
│           ├── use-board.ts         # リポジトリ直接参照でボードデータ取得
│           ├── use-task-actions.ts  # CRUD 操作
│           ├── use-keybinds.ts      # グローバルキーバインド
│           └── use-mouse-input.ts   # マウスイベントパーサー
├── cli.ts                     # 新規 — TUI エントリポイント
├── server.ts                  # 既存 — Web サーバーエントリポイント
└── public/                    # 既存 — Web UI
```

## 画面構成

### メイン画面 (Board View)

```
╭─ kanban ─────────────────────────────────────────────────────────────────────╮
│  ◆ 2 backlog   ◆ 3 todo   ◇ 1 active   ◆ 0 review   ◆ 4 done    Σ 10     │
├──────────────────────────────┬────────────────────────────────────────────────┤
│ TASKS                        │ DETAIL                                        │
│                              │                                                │
│ ▾ In Progress (1)            │ ╭─ SSH設定整理 ──────────────────────────────╮ │
│   ▶ ● SSH設定整理            │ │                                            │ │
│ ▾ Todo (3)                   │ │  Status    in_progress  ▸ todo             │ │
│     ● API認証追加            │ │  Priority  ● high                          │ │
│     ○ Webhook連携            │ │  Labels    #infra #ssh                     │ │
│     ○ DB移行検討             │ │  Worktree  feature/ssh-config              │ │
│ ▾ Backlog (2)                │ │  Updated   3h ago                          │ │
│     ○ TUI版kanban            │ │                                            │ │
│     ○ ログ集約               │ │  ── Description ────────────────────────── │ │
│ ▸ Done (4)                   │ │  Tailscale + SSH の設定を整理し、          │ │
│                              │ │  kanban gitリモートのインフラを             │ │
│                              │ │  セットアップする。                        │ │
│                              │ │                                            │ │
│                              │ │  ── Session ─────────────────────────────  │ │
│                              │ │  Last: master/20260313-191517              │ │
│                              │ │  Hint: /continue で再開可能                │ │
│                              │ ╰────────────────────────────────────────────╯ │
├──────────────────────────────┴────────────────────────────────────────────────┤
│ [a]dd  [m]ove  [e]dit  [d]elete  [s]ync  [/]search  [b]oards  [q]uit       │
╰──────────────────────────────────────────────────────────────────────────────╯
```

### タスク編集モード

右ペインがフォームに切り替わる。`Tab` でフィールド間移動、`Enter` で確定、`Esc` でキャンセル。

```
╭─ Edit: SSH設定整理 ─────────────────────────────╮
│                                                  │
│  Title     [SSH設定整理                      ]   │
│  Status    [▼ in_progress                    ]   │
│  Priority  [▼ high                           ]   │
│  Labels    [infra, ssh                       ]   │
│  Worktree  [feature/ssh-config               ]   │
│                                                  │
│  Description                                     │
│  ┌──────────────────────────────────────────┐    │
│  │Tailscale + SSH の設定を整理し、          │    │
│  │kanban gitリモートのインフラを             │    │
│  │セットアップする。                        │    │
│  └──────────────────────────────────────────┘    │
│                                                  │
│         [Enter] Save    [Esc] Cancel             │
╰──────────────────────────────────────────────────╯
```

### 画面遷移

```
Board Select ──→ Board View (Split Pane) ──→ Task Editor (インライン)
     ↑                │                              │
     └── [b] ─────────┘          [Esc] ──────────────┘
                      │
                      ├──→ Handover View ([h]andover)
                      └──→ Search Overlay ([/])
```

## キーバインド

| キー | 画面 | 操作 |
|------|------|------|
| `j/k` | 左ペイン | タスク上下移動 |
| `J/K` | 左ペイン | ステータスグループ間ジャンプ |
| `l / Enter` | 左ペイン | 右ペインにフォーカス移動 |
| `h` | 右ペイン | 左ペインに戻る |
| `o` | 左ペイン | グループ折りたたみ/展開 |
| `a` | どこでも | タスク追加 (インラインフォーム) |
| `m` | 左ペイン | ステータス移動 (選択メニュー) |
| `e` | どこでも | 選択中タスクの編集モード |
| `d` | どこでも | 削除 (確認プロンプト付き) |
| `s` | どこでも | handover sync 実行 |
| `/` | どこでも | インクリメンタルサーチ |
| `b` | どこでも | ボード選択画面へ |
| `1-5` | サマリーバー | 該当ステータスにジャンプ |
| `q / Ctrl+C` | どこでも | 終了 |

## マウス操作

| マウス操作 | 動作 |
|-----------|------|
| 左ペインのタスクをクリック | タスク選択 (フォーカス移動) |
| 右ペインのフィールドをクリック | 編集モードで該当フィールドにフォーカス |
| サマリーバーのステータスをクリック | 該当ステータスにジャンプ |
| グループヘッダをクリック | 折りたたみ/展開 |
| 下部キーバインドバーの項目をクリック | 該当アクション実行 |
| ホイールスクロール | 左ペイン/右ペインをスクロール |

マウスは SGR mouse mode (`\x1b[?1006h`) で有効化し、`use-mouse-input.ts` hook で ANSI エスケープシーケンスをパースする自作実装。

## テーマ: Terminal Luxe for TUI

Web UI の Terminal Luxe テーマを TUI に翻訳。Truecolor (24bit) 対応ターミナル前提、ANSI 256色フォールバック。

```typescript
const terminalLuxe = {
  // Surfaces
  bg:           '#0D0D0D',
  surface:      '#1A1A1A',
  surfaceHover: '#242424',

  // Text
  text:         '#E8E4D9',   // warm white
  textMuted:    '#6B6560',
  textDim:      '#3D3A36',

  // Accents (Web UI と統一)
  amber:        '#D4A574',   // in_progress
  sage:         '#7D9B76',   // done
  coral:        '#C47A6C',   // priority: high
  sky:          '#6B9BC3',   // todo
  violet:       '#9B8EC4',   // review
  rose:         '#B5727E',   // priority: medium

  // Borders
  border:       '#2A2725',
  borderActive: '#D4A574',   // フォーカス中ペイン
}
```

### ビジュアル要素

- **ボーダー**: Unicode Box Drawing (`╭╮╰╯│─`) で角丸風、フォーカス中ペインは amber に変化
- **優先度**: `●` high (coral) / `◐` medium (rose) / `○` low (textMuted)
- **ステータス**: `▶` active (amber) / `○` todo (sky) / `◆` backlog (textMuted) / `◎` review (violet) / `✓` done (sage)
- **ラベル**: `#tag` をハッシュベースで色付け（Web UI と同じアルゴリズム）
- **選択行**: `surfaceHover` 背景 + 左端に amber `▌` バー
- **サマリーバー**: `◇` = フォーカス中ステータス、`◆` = その他

## 依存パッケージ

| パッケージ | 用途 |
|-----------|------|
| `npm:ink` | React ベース TUI フレームワーク |
| `npm:@inkjs/ui` | UI コンポーネント集 (Select, TextInput, Spinner) |
| `npm:fullscreen-ink` | フルスクリーンモード、`useScreenSize` でレスポンシブ対応 |
| `npm:react` | Ink の依存 |

### Deno 互換性

Deno の `npm:` specifier で import。既存の kanban-server が `npm:hono` 等を使っているため同じパターン。実装前に最小動作確認を行う。

## データフロー

```
cli.ts (エントリポイント)
  │
  ├── リポジトリ初期化
  │   ├── JsonFileBoardRepository(dataDir)
  │   └── JsonFileTaskRepository(dataDir)
  │
  └── withFullScreen(<App />) で起動
        │
        useBoard(boardId)
        ├── 初回: repo.getTasks(boardId) → state にセット
        ├── 変更: repo.updateTask() → state 更新 → Ink 再描画
        └── ファイル監視: Deno.watchFs(boardFile) → 外部変更を検知して再読み込み
```

### 同時書き込みの競合対策

既存の version フィールドによる楽観的ロックを利用：

1. タスク読み込み時に `updatedAt` を保持
2. 書き込み時にファイル上の `updatedAt` と比較
3. 不一致なら再読み込みしてトースト通知

### レスポンシブ対応

- `useScreenSize` でターミナルサイズを監視
- 幅 < 60: 右ペインを非表示、リスト単独表示にフォールバック
- `COLORTERM` 環境変数で truecolor / 256色を判定

## エラーハンドリング

| シナリオ | 対応 |
|---------|------|
| データファイルが存在しない | ボード選択画面で新規作成を促す |
| JSON パースエラー | エラーメッセージ表示 + 該当ボードをスキップ |
| ファイル書き込み失敗 | トースト通知、操作をロールバック |
| ターミナル幅が狭すぎる (<60) | 右ペイン非表示にフォールバック |
| Truecolor 非対応ターミナル | ANSI 256色にフォールバック |

## テスト方針

| レイヤー | テスト手法 |
|---------|-----------|
| リポジトリ層 | 既存テストがそのまま有効 |
| hooks | リポジトリをモックして単体テスト |
| コンポーネント | `ink-testing-library` でスナップショットテスト |
| キーバインド | `ink-testing-library` + `stdin.write()` でキー入力シミュレーション |
| 統合テスト | 一時ディレクトリに JSON 配置 → TUI 起動 → 操作 → JSON 検証 |

## スコープ外 (YAGNI)

- リモート実行 (SSH) — Web UI のみで十分
- Sessions Dashboard — 初期版では省略
- ドラッグ&ドロップ — キーボード/クリック操作で代替
- マルチボード同時表示 — ボード切り替えで対応
