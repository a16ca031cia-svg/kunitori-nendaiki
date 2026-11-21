#!/bin/sh
# 計算の速さの比較：種を固定して日本地図を N ターン回し、合計時間を出す（3つの種を同時に）
cd "$(dirname "$0")/.."
sh tools/build_core.sh >/dev/null
GD=/c/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe
N=${1:-80}
TMP=$(mktemp -d)
for s in 4242 5353 6464; do KN_SEED=$s $GD --headless --path . -- --sim japan $N > $TMP/$s.txt 2>&1 & done
wait
for s in 4242 5353 6464; do grep "SIMTOTAL\|SCRIPT ERROR" $TMP/$s.txt | sed "s/^/[$s] /"; grep "^turn" $TMP/$s.txt | tail -1 | sed "s/^/[$s] 最後 /"; done
cat $TMP/*.txt | grep SIMTOTAL | sed 's/.*ms=//' | awk '{s+=$1;n++} END {printf "合計 %.1f 秒（1ターン平均 %d ms）\n", s/1000, s/n/'"$N"'}'
rm -rf $TMP
