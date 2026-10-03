#!/bin/bash
# 01_survey.sh — 売却前バックアップのための「読み取り専用」調査スクリプト
# ・ディスクの初期化/削除/パーティション変更/設定変更は一切行いません
# ・パスワード・鍵の中身は読みません（存在・件数・場所のみ）
# ・結果はデスクトップの backup_report_survey_*.txt に保存されます
# 使い方: ターミナルで  bash 01_survey.sh
set -u
OUT="$HOME/Desktop/backup_report_survey_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$OUT") 2>&1
h(){ printf '\n==================== %s ====================\n' "$1"; }

h "1. Mac本体"
# シリアル番号・UUID は記録しない
system_profiler SPHardwareDataType 2>/dev/null | grep -vE 'Serial|UUID|Provisioning'
sw_vers
echo "FileVault: $(fdesetup status 2>/dev/null)"

h "2. 内蔵ディスク使用量"
df -H / /System/Volumes/Data 2>/dev/null
echo "--- ホーム直下フォルダのサイズ（数分かかることがあります）---"
for d in "$HOME"/* "$HOME"/Library; do
  [ -d "$d" ] && du -sh "$d" 2>/dev/null
done
echo "--- ホーム全体 ---"; du -sh "$HOME" 2>/dev/null

h "3. 外付けディスク（USB/物理）"
diskutil list external physical 2>/dev/null || echo "外付け物理ディスクが見つかりません"
echo "--- USB機器（メーカー確認）---"
system_profiler SPUSBDataType 2>/dev/null | grep -iE 'BUFFALO|Manufacturer|Vendor ID|Product ID|Capacity|^ {8}[^ ].*:$' | grep -v Serial
EXT=$(diskutil list external physical 2>/dev/null | awk '/^\/dev\/disk/{print $1}')
N=0
for dev in $EXT; do
  N=$((N+1))
  echo; echo "### $dev"
  diskutil info "$dev" | grep -E 'Device / Media Name|Protocol|Disk Size|Partition Type|Content \(IOContent\)|Removable|Solid State|SMART'
  # 各パーティション/ボリューム
  for p in $(diskutil list "$dev" | awk '/disk[0-9]+s[0-9]+$/{print $NF}'); do
    echo "  --- /dev/$p"
    diskutil info "$p" | grep -E 'Volume Name|Mounted|Mount Point|File System Personality|Type \(Bundle\)|Disk Size|Volume Used Space|Container Free Space|Volume Free Space|Encrypted|FileVault|Owners' | sed 's/^/    /'
  done
done
echo; echo "外付け物理ディスク数: $N"
echo "--- APFSコンテナ（外付けがAPFSの場合のボリューム構成）---"
for dev in $EXT; do diskutil apfs list "$dev" 2>/dev/null | grep -E 'Container|Volume disk|Name:|Role|Capacity Consumed|FileVault' ; done
echo "--- マウント中の外付けボリュームの既存データ（最上位のみ・中身は読まない）---"
for mp in /Volumes/*; do
  [ "$mp" = "/Volumes/Macintosh HD" ] && continue
  [ -d "$mp" ] || continue
  echo "## $mp"; df -H "$mp" | tail -1
  ls -la "$mp" 2>/dev/null | head -40
done
echo "※ 上の名前に児童名などが含まれる場合、共有時は伏せてください"

h "4. Time Machine 設定"
tmutil destinationinfo 2>&1
echo "--- 自動バックアップ/除外設定 ---"
defaults read /Library/Preferences/com.apple.TimeMachine AutoBackup 2>&1
defaults read /Library/Preferences/com.apple.TimeMachine SkipPaths 2>&1
defaults read /Library/Preferences/com.apple.TimeMachine ExcludeByPath 2>&1
echo "--- 既存バックアップ ---"
tmutil listbackups 2>&1 | tail -5
tmutil latestbackup 2>&1
echo "--- ファイル単位の除外属性（ホーム内・最大30件）---"
mdfind -onlyin "$HOME" "com_apple_backup_excludeItem = 'com.apple.backupd'" 2>/dev/null | head -30

h "5. iCloudにしか無いファイル（Macストレージ最適化）"
ICD="$HOME/Library/Mobile Documents"
if [ -d "$ICD" ]; then
  echo "iCloud Drive フォルダあり"
  CNT=$(find "$ICD" -type f -flags +dataless 2>/dev/null | wc -l | tr -d ' ')
  echo "ローカルに実体の無い(dataless)ファイル数: $CNT"
  echo "--- フォルダ別件数（上位）---"
  find "$ICD" -type f -flags +dataless 2>/dev/null | sed "s|$ICD/||" | cut -d/ -f1-2 | sort | uniq -c | sort -rn | head -15
else
  echo "iCloud Drive は使われていないようです"
fi
echo "--- デスクトップ/書類のdatalessファイル数 ---"
for d in "$HOME/Desktop" "$HOME/Documents"; do
  echo "$d: $(find "$d" -type f -flags +dataless 2>/dev/null | wc -l | tr -d ' ')"
done
echo "--- 写真ライブラリ ---"
for lib in "$HOME/Pictures/"*.photoslibrary; do
  [ -d "$lib" ] || continue
  echo "$lib : $(du -sh "$lib" 2>/dev/null | cut -f1)"
  echo "  originals内ファイル数: $(find "$lib/originals" -type f 2>/dev/null | wc -l | tr -d ' ')"
done
echo "※「Macのストレージを最適化」がオンだと、原本はiCloudにだけ存在します（写真アプリ>設定>iCloudで確認）"

h "6. パスワード・鍵の保管場所（中身は読まない）"
echo "--- キーチェーン ---"
security list-keychains 2>&1
ls -1 "$HOME/Library/Keychains" 2>/dev/null | head
echo "--- パスワード管理アプリ ---"
for a in "1Password" "1Password 7" "Bitwarden" "Dashlane" "LastPass" "KeePassXC" "Enpass" "NordPass" "Keeper Password Manager" "Proton Pass" "Strongbox" "MacPass"; do
  [ -d "/Applications/$a.app" ] && echo "インストール済: $a"
done
echo "KeePass系ローカル保管庫(.kdbx)の件数: $(mdfind -onlyin "$HOME" 'kMDItemFSName == "*.kdbx"' 2>/dev/null | wc -l | tr -d ' ')"
echo "--- Chrome ---"
CH="$HOME/Library/Application Support/Google/Chrome"
if [ -d "$CH" ]; then
  for p in "$CH"/Default "$CH"/Profile*; do
    [ -d "$p" ] || continue
    LD="なし"; [ -f "$p/Login Data" ] && LD="あり"
    SIGNED="不明"; grep -q '"account_info":\[{' "$p/Preferences" 2>/dev/null && SIGNED="Googleアカウントでログイン中"
    echo "$(basename "$p"): 保存パスワードDB=$LD / $SIGNED"
  done
else echo "Chrome なし"; fi
echo "--- その他ブラウザ ---"
for a in "Firefox" "Microsoft Edge" "Brave Browser" "Arc"; do [ -d "/Applications/$a.app" ] && echo "インストール済: $a"; done
echo "--- SSH/GPG鍵（ファイル名のみ）---"
ls -1 "$HOME/.ssh" 2>/dev/null
[ -d "$HOME/.gnupg" ] && echo ".gnupg あり"

h "7. 注意が必要なデータ"
for d in "$HOME/Library/Containers/com.docker.docker" "$HOME/Parallels" "$HOME/Virtual Machines.localized" "$HOME/Library/Mail" "$HOME/Library/Messages"; do
  [ -e "$d" ] && echo "$d : $(du -sh "$d" 2>/dev/null | cut -f1)"
done

h "完了"
echo "レポート: $OUT"
echo "このスクリプトは何も変更していません。"
