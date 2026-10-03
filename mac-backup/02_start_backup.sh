#!/bin/bash
# 02_start_backup.sh — Time Machine のバックアップ先と暗号化を確認し、バックアップを開始・完了まで見守る
# ・ディスクの初期化/削除は行いません（バックアップ先の追加と暗号化パスワード設定は
#   「システム設定 > 一般 > Time Machine」で本人が行います）
# 使い方: bash 02_start_backup.sh
set -u
OUT="$HOME/Desktop/backup_report_run_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$OUT") 2>&1

echo "=== バックアップ先 ==="
if ! tmutil destinationinfo 2>/dev/null | grep -q 'Name'; then
  echo "バックアップ先が未設定です。README の「手順2」を行ってから再実行してください。"; exit 1
fi
tmutil destinationinfo
MP=$(tmutil destinationinfo | awk -F': ' '/Mount Point/{print $2; exit}')
if [ -n "$MP" ]; then
  echo "=== 暗号化の確認 ($MP) ==="
  ENC=$(diskutil info "$MP" | grep -E 'FileVault|Encrypted' )
  echo "$ENC"
  echo "$ENC" | grep -qE 'Yes' || echo "⚠ 暗号化が確認できません。Time Machine設定で「バックアップを暗号化」を有効にしてください（バックアップは続行します）"
fi

echo "=== バックアップ開始: $(date '+%F %T') ==="
tmutil startbackup --auto 2>&1 || tmutil startbackup 2>&1
sleep 10
while tmutil status | grep -q 'Running = 1'; do
  P=$(tmutil status | awk -F'= ' '/Percent =|"_raw_Percent"/{gsub(/[";]/,"",$2); print $2; exit}')
  PH=$(tmutil status | awk -F'= ' '/BackupPhase/{gsub(/[";]/,"",$2); print $2; exit}')
  printf '%s  phase=%s  progress=%s\n' "$(date '+%T')" "${PH:-?}" "${P:-?}"
  sleep 60
done
echo "=== 終了: $(date '+%F %T') ==="
tmutil status
echo "--- 直近のTime Machineエラー（24時間）---"
log show --last 24h --style compact --predicate 'subsystem == "com.apple.TimeMachine"' 2>/dev/null \
  | grep -iE 'error|fail|could not|unable' | tail -30
echo "次は bash 03_verify.sh で中身を検証してください。「完了」表示だけでは判断しません。"
