#!/bin/bash
# 旧MacBookProを開く — バッファローHDDのTime Machineバックアップを「読み取り専用」で開き、
# 旧MacBook Proのホームフォルダ（書類・写真・デスクトップ等）をFinderで表示する。
# ・バックアップを変更・削除することはありません（読み取り専用）
# ・編集したいファイルは、Mac Studio側へコピーしてから使ってください
MNT="$HOME/旧MacBookPro"
if mount | grep -q " on $MNT "; then open "$MNT"; exit 0; fi

VOL=$(ls -d /Volumes/HD-LE-B* 2>/dev/null | head -1)
if [ -z "$VOL" ]; then
  osascript -e 'display dialog "バッファローのHDDが見つかりません。\nUSBでつなぎ、暗号化パスワードを入力してから、もう一度開いてください。" buttons {"OK"} with title "旧MacBookPro"' >/dev/null
  exit 1
fi
DEV=$(diskutil info "$VOL" | awk '/Device Node/{print $NF}')
SNAP=$(diskutil apfs listSnapshots "$DEV" | awk '/Name:/{print $NF}' | grep 'com.apple.TimeMachine' | tail -1)
[ -z "$SNAP" ] && { echo "バックアップが見つかりません"; exit 1; }
echo "旧MacBookProのバックアップ（${SNAP#com.apple.TimeMachine.}）を読み取り専用で開きます。"
echo "このMacのログインパスワードを入力してください（画面には表示されません。先に「英数」キー）"
mkdir -p "$MNT"
sudo mount_apfs -o rdonly,noowners -s "$SNAP" "$DEV" "$MNT" 2>/dev/null || sudo mount_apfs -o rdonly -s "$SNAP" "$DEV" "$MNT" || exit 1
HOMEDIR=$(ls -d "$MNT"/*/*/Users/* 2>/dev/null | grep -v '/Shared$' | head -1)
open "${HOMEDIR:-$MNT}"
echo "開きました。終わったら「close_old_macbook.command」を開くか、HDDを取り出してください。"
