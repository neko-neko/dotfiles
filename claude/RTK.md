# RTK - Rust Token Killer

Claude Code の hook が dev コマンドを自動で rtk 経由に書き換える（透過・追加作業不要）。rtk を直接使うのは分析・デバッグ時のみ:

```bash
rtk gain              # トークン節約の分析
rtk discover          # 見逃し機会の分析
rtk proxy <cmd>       # フィルタ無しの生実行（デバッグ用）
```
