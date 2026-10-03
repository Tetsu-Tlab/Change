#!/bin/bash
# run_all.sh — 調査 → バックアップ先設定の待機 → バックアップ → 検証 を一括実行
# ・HDDの初期化/削除/パーティション変更は行いません（必要な場合は画面で本人が判断）
# ・暗号化パスワードは本人がTime Machine設定画面で入力します
# 使い方: bash run_all.sh
set -u
cd "$(dirname "$0")"
caffeinate -dimsu -w $$ &   # 作業中のスリープ防止

echo "■ 1/4 読み取り専用の調査"
bash 01_survey.sh >/dev/null 2>&1
echo "  → デスクトップに backup_report_survey_*.txt を保存しました"

N=$(diskutil list external physical 2>/dev/null | grep -c '^/dev/disk')
B=$(system_profiler SPUSBDataType 2>/dev/null | grep -ci buffalo)
echo "  外付け物理ディスク: ${N}台 / BUFFALO表記: ${B}件"
if [ "$N" -ne 1 ]; then
  echo "  ⚠ 外付けディスクが1台ではありません。バッファローHDD以外を外してから再実行してください。"; exit 1
fi

echo "■ 2/4 Time Machine のバックアップ先"
if ! tmutil destinationinfo 2>/dev/null | grep -q 'Name'; then
  echo "  Time Machine設定を開きます。次を行ってください："
  echo "   1) 「バックアップディスクを追加」→ バッファローのディスクを選択"
  echo "   2) 「バックアップを暗号化」をオン → パスワードを設定（パスワード管理アプリ＋紙に保管）"
  echo "   ※「消去」の確認が出たら一度止まり、README手順2の表で既存データへの影響を確認してから判断"
  open "x-apple.systempreferences:com.apple.Time-Machine-Settings.extension" 2>/dev/null \
    || open /System/Library/PreferencePanes/TimeMachine.prefPane
  echo "  設定が終わるのを待っています…（自動で検知します）"
  until tmutil destinationinfo 2>/dev/null | grep -q 'Name'; do sleep 15; done
  echo "  → バックアップ先を検知しました"
fi

echo "■ 3/4 バックアップ（数時間かかります。蓋を開けたまま電源接続で）"
bash 02_start_backup.sh

echo "■ 4/4 検証"
bash 03_verify.sh
echo
echo "すべて終了しました。デスクトップの backup_report_*.txt（3種類）を送ってください。"
echo "（児童名などを含む行は伏せてください）"
