#!/bin/bash
# 06_final_check.sh — 最終確認（読み取り専用）：最新バックアップに写真原本・重要フォルダが入っているか
set -u
OUT="$HOME/Desktop/backup_report_final_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$OUT") 2>&1
LATEST=$(tmutil latestbackup 2>/dev/null)
find_root(){ for d in "$LATEST" "$LATEST"/* "$LATEST"/*/*; do [ -d "$d/Users/$USER" ] && { echo "$d"; return; }; done; }
ROOT=$(find_root)
MNT=""
if [ -z "$ROOT" ]; then
  # 最新バックアップ（APFSスナップショット）を読み取り専用で一時マウント
  MP=$(tmutil destinationinfo | awk -F': ' '/Mount Point/{print $2; exit}')
  DEV=$(diskutil info "$MP" | awk '/Device Node/{print $NF}')
  SNAP=$(diskutil apfs listSnapshots "$DEV" | awk '/Name:/{print $NF}' | grep "$(basename "$LATEST")" | tail -1)
  MNT="$HOME/.tm_verify_mnt"; mkdir -p "$MNT"
  echo "（バックアップを読み取り専用で開きます。Macのログインパスワードを求められたら入力してください。画面には表示されません）"
  sudo umount "$MNT" 2>/dev/null
  sudo mount_apfs -o rdonly -s "$SNAP" "$DEV" "$MNT" && { LATEST="$MNT"; ROOT=$(find_root); }
fi
[ -z "$ROOT" ] && { echo "最新バックアップの中身を開けません: ${LATEST##*/}"; exit 1; }
BH="$ROOT/Users/$USER"
echo "最新バックアップ: ${LATEST##*/}"
echo
LIB=$(ls -d "$HOME"/Pictures/*.photoslibrary | head -1); LN=$(basename "$LIB")
echo "[写真]"
echo "  写真アプリの項目数   : $(osascript -e 'tell application "Photos" to count of media items' 2>&1)"
echo "  Mac上の原本ファイル数 : $(find "$LIB/originals" -type f | wc -l | tr -d ' ')"
echo "  バックアップの原本数 : $(find "$BH/Pictures/$LN/originals" -type f 2>/dev/null | wc -l | tr -d ' ')"
OK=0; NG=0
IFS=$'\n'
for f in $(find "$LIB/originals" -type f | awk 'BEGIN{srand()}{print rand()"\t"$0}' | sort | head -20 | cut -f2-); do
  cmp -s "$f" "$BH/Pictures/${f#$HOME/Pictures/}" && OK=$((OK+1)) || NG=$((NG+1))
done; unset IFS
echo "  原本の抜き取り照合(20件): 一致 $OK / 不一致 $NG"
echo
echo "[iCloud Drive] iCloudのみ: $(find "$HOME/Library/Mobile Documents" -type f -flags +dataless 2>/dev/null | wc -l | tr -d ' ') 件 / Mac $(find "$HOME/Library/Mobile Documents" -type f | wc -l | tr -d ' ') / バックアップ $(find "$BH/Library/Mobile Documents" -type f 2>/dev/null | wc -l | tr -d ' ')"
echo
echo "[主要フォルダ] Mac / バックアップ"
for f in Desktop Documents Movies Music Downloads Library/Keychains Library/Mail Library/Messages .ssh; do
  [ -e "$HOME/$f" ] && printf '  %-20s %7s / %7s\n' "$f" "$(find "$HOME/$f" -type f 2>/dev/null | wc -l | tr -d ' ')" "$(find "$BH/$f" -type f 2>/dev/null | wc -l | tr -d ' ')"
done
echo
echo "[暗号化] $(diskutil info "$(tmutil destinationinfo | awk -F': ' '/Mount Point/{print $2; exit}')" | grep -E 'FileVault' | xargs)"
[ -n "$MNT" ] && sudo umount "$MNT" 2>/dev/null && rmdir "$MNT"
echo "レポート: $OUT"
