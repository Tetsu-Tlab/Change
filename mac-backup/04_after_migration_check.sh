#!/bin/bash
# 04_after_migration_check.sh — Mac Studio へ移行した後、新しいMac上で実行する確認スクリプト（読み取り専用）
# 使い方: Mac Studio のターミナルで  bash 04_after_migration_check.sh
set -u
OUT="$HOME/Desktop/migration_check_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$OUT") 2>&1
echo "=== 機種/OS ==="; system_profiler SPHardwareDataType | grep -E 'Model Name|Chip|Memory'; sw_vers
echo; echo "=== ホームの主要フォルダ（ファイル数）==="
for f in Desktop Documents Pictures Movies Music Downloads .ssh Library/Keychains; do
  printf '%-22s %s\n' "$f" "$(find "$HOME/$f" -type f 2>/dev/null | wc -l | tr -d ' ')"
done
echo; echo "=== アプリ ==="
ls /Applications | sed 's/\.app$//' | wc -l | xargs echo "アプリ数:"
echo "--- Intel専用（Apple Silicon で Rosetta が必要/動かない可能性）---"
for a in /Applications/*.app; do
  b="$a/Contents/MacOS/$(defaults read "$a/Contents/Info" CFBundleExecutable 2>/dev/null)"
  [ -f "$b" ] && file "$b" | grep -q arm64 || { [ -f "$b" ] && echo "  $(basename "$a")"; }
done
echo; echo "=== キーチェーン ==="; security list-keychains
echo "（ログインキーチェーンのロック解除を求められたら、旧MacBookのログインパスワードを入力）"
echo; echo "=== Rosetta ==="; /usr/bin/pgrep -q oahd && echo "Rosetta 有効" || echo "Rosetta 未導入（Intel専用アプリ初回起動時に案内が出ます）"
echo; echo "レポート: $OUT"
