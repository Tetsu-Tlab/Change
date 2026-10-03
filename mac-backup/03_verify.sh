#!/bin/bash
# 03_verify.sh — 最新のTime Machineバックアップの中身を検証（読み取り専用）
# 事前に: システム設定 > プライバシーとセキュリティ > フルディスクアクセス で「ターミナル」をオン
# 使い方: bash 03_verify.sh
set -u
OUT="$HOME/Desktop/backup_report_verify_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$OUT") 2>&1
NG=0; warn(){ echo "⚠ $*"; NG=$((NG+1)); }

LATEST=$(tmutil latestbackup 2>/dev/null)
if [ -z "$LATEST" ]; then
  echo "最新バックアップが取得できません。原因の切り分け情報:"
  echo "--- バックアップ先 ---"; tmutil destinationinfo 2>&1
  echo "--- 状態 ---"; tmutil status 2>&1
  echo "--- latestbackup のエラー内容 ---"; tmutil latestbackup 2>&1
  echo "--- バックアップ一覧 ---"; tmutil listbackups 2>&1 | tail -5
  echo "--- マウント中のボリューム ---"; ls /Volumes
  echo "対処: ①フルディスクアクセスでターミナルをオン→ターミナルを⌘Qで完全終了→開き直す ②HDDが接続・マウントされているか確認"
  exit 1
fi
echo "最新バックアップ: $LATEST"
echo "バックアップ一覧（最新5件）:"; tmutil listbackups 2>/dev/null | tail -5

# バックアップ内のデータボリューム（Users/<自分> がある場所）を探す
ROOT=""
for d in "$LATEST" "$LATEST"/*; do
  [ -d "$d/Users/$USER" ] && { ROOT="$d"; break; }
done
[ -z "$ROOT" ] && { echo "バックアップ内にホームフォルダが見つかりません"; exit 1; }
BH="$ROOT/Users/$USER"
echo "バックアップ内ホーム: $BH"

echo; echo "=== 1. 重要フォルダのファイル数比較（現在のMac vs バックアップ）==="
printf '%-28s %10s %10s %10s\n' フォルダ Mac側 バックアップ うちiCloudのみ
for f in Desktop Documents Pictures Movies Music Downloads .ssh Library/Keychains "Library/Mobile Documents" Library/Mail Library/Messages "Library/Application Support"; do
  [ -e "$HOME/$f" ] || continue
  A=$(find "$HOME/$f" -type f 2>/dev/null | wc -l | tr -d ' ')
  B=$(find "$BH/$f" -type f 2>/dev/null | wc -l | tr -d ' ')
  C=$(find "$HOME/$f" -type f -flags +dataless 2>/dev/null | wc -l | tr -d ' ')
  printf '%-28s %10s %10s %10s\n' "$f" "$A" "$B" "$C"
  [ "$B" -eq 0 ] && [ "$A" -gt 0 ] && warn "$f がバックアップに含まれていません"
  # バックアップ後に増えた分や除外分で多少の差は正常。大きな差のみ警告
  [ "$A" -gt 0 ] && [ $(( (A-C-B)*100 / A )) -gt 5 ] && warn "$f の件数差が5%超（バックアップ後の追加・除外・iCloudのみの可能性）"
done

echo; echo "=== 2. 抜き取り検査：書類・デスクトップ・写真から最大20ファイルを内容比較 ==="
OKC=0; NGC=0
SAMPLES=$( { find "$HOME/Documents" "$HOME/Desktop" -type f -size +0 ! -flags +dataless -mtime +1 2>/dev/null; \
             find "$HOME/Pictures" -path '*originals*' -type f -mtime +1 2>/dev/null; } | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort | head -20 | cut -f2-)
IFS=$'\n'
for s in $SAMPLES; do
  rel="${s#$HOME/}"
  if cmp -s "$s" "$BH/$rel"; then OKC=$((OKC+1)); else NGC=$((NGC+1)); echo "  不一致/欠落: (ホーム)/${rel%%/*}/…"; fi
done
unset IFS
echo "一致: $OKC  不一致: $NGC"
[ "$NGC" -gt 0 ] && warn "抜き取り検査で不一致あり"

echo; echo "=== 3. 除外設定 ==="
defaults read /Library/Preferences/com.apple.TimeMachine SkipPaths 2>&1

echo; echo "=== 4. 直近7日のTime Machineエラー ==="
log show --last 7d --style compact --predicate 'subsystem == "com.apple.TimeMachine"' 2>/dev/null \
  | grep -iE 'error|fail|could not|unable' | tail -30

echo; echo "=== 5. バックアップ先の暗号化 ==="
MP=$(tmutil destinationinfo | awk -F': ' '/Mount Point/{print $2; exit}')
[ -n "$MP" ] && diskutil info "$MP" | grep -E 'FileVault|Encrypted'

echo; echo "=== 結果 ==="
echo "警告: $NG 件"
echo "※ iCloudのみのファイル（上表の右列）と写真の最適化分はTime Machineに入りません。README「手順4」で対応してください。"
echo "レポート: $OUT"
