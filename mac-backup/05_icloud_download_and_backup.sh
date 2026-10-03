#!/bin/bash
# 05_icloud_download_and_backup.sh
# iCloudにしか無いファイル・写真原本をMacへダウンロード → 追加バックアップ → 検証 を自動で行う
# ・削除や初期化は行いません。変更するのは写真アプリの「オリジナルをこのMacにダウンロード」設定のみ
# 使い方: bash 05_icloud_download_and_backup.sh
set -u
OUT="$HOME/Desktop/backup_report_icloud_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$OUT") 2>&1
caffeinate -dimsu -w $$ &
ICD="$HOME/Library/Mobile Documents"
LIB=$(ls -d "$HOME"/Pictures/*.photoslibrary 2>/dev/null | head -1)
free_gb(){ df -g /System/Volumes/Data | awk 'NR==2{print $4}'; }
orig_count(){ find "$LIB/originals" -type f 2>/dev/null | wc -l | tr -d ' '; }

echo "■ 1/4 iCloud Drive のファイルをダウンロード"
BEFORE=$(find "$ICD" -type f -flags +dataless 2>/dev/null | wc -l | tr -d ' ')
echo "  iCloudのみ: $BEFORE 件"
find "$ICD" -type f -flags +dataless -print0 2>/dev/null | while IFS= read -r -d '' f; do
  brctl download "$f" >/dev/null 2>&1
  cat "$f" > /dev/null 2>&1      # 読み込みでダウンロードを確実に発生させる
done
sleep 20
AFTER=$(find "$ICD" -type f -flags +dataless 2>/dev/null | wc -l | tr -d ' ')
echo "  ダウンロード後のiCloudのみ: $AFTER 件"

echo "■ 2/4 写真の原本を「このMacにダウンロード」に設定"
RES=$(osascript <<'OSA' 2>&1
tell application "Photos" to activate
delay 3
tell application "System Events"
  tell process "Photos"
    keystroke "," using command down
    delay 3
    set w to front window
    try
      repeat with b in (buttons of toolbar 1 of w)
        if name of b contains "iCloud" then click b
      end repeat
    end try
    delay 2
    repeat with e in (entire contents of w)
      try
        if class of e is radio button then
          set n to name of e
          if (n contains "ダウンロード") or (n contains "Download") then
            click e
            return "OK"
          end if
        end if
      end try
    end repeat
  end tell
end tell
return "NOTFOUND"
OSA
)
echo "  結果: $RES"
if [ "$RES" != "OK" ]; then
  osascript -e 'display dialog "写真の設定画面を開きました。\n\n上の「iCloud」を押し、\n「オリジナルをこのMacにダウンロード」を1回クリックしてください。\n\n押したら「OK」を押してください。" buttons {"OK"} default button 1 with title "バックアップの準備"' >/dev/null 2>&1
fi

echo "■ 3/4 写真の原本ダウンロード完了を待機（自動判定）"
echo "  開始時の原本: $(orig_count) 件 / Mac空き: $(free_gb) GB"
SAME=0; PREV=-1
while [ $SAME -lt 5 ]; do
  sleep 120
  C=$(orig_count); F=$(free_gb)
  echo "  $(date +%H:%M) 原本 $C 件 / 空き ${F}GB"
  if [ "$F" -lt 25 ]; then
    echo "  ⚠ Macの空きが25GBを切りました。ここで止めます。この画面を送ってください。"
    osascript -e 'display notification "Macの空き容量が少なくなったため停止しました" with title "バックアップ"'
    exit 1
  fi
  [ "$C" -eq "$PREV" ] && SAME=$((SAME+1)) || SAME=0
  PREV=$C
done
echo "  10分間増えなかったため完了と判断: 原本 $PREV 件"

echo "■ 4/4 追加バックアップ → 検証"
tmutil startbackup --block
echo "  バックアップ終了: $(date '+%F %T')"
cd "$(dirname "$0")" 2>/dev/null || cd "$HOME/Desktop/mac-backup"
bash "$HOME/Desktop/mac-backup/03_verify.sh"
osascript -e 'display notification "iCloud分の追加バックアップと検証が終わりました" with title "バックアップ"'
echo "完了。この画面の内容（またはデスクトップの backup_report_icloud_*.txt と verify）を送ってください。"
