#!/bin/bash
# 旧MacBookProを閉じる — 読み取り専用で開いたバックアップを閉じる
MNT="$HOME/旧MacBookPro"
if mount | grep -q " on $MNT "; then sudo umount "$MNT" && echo "閉じました。HDDを取り出せます。"; else echo "開いていません。"; fi
