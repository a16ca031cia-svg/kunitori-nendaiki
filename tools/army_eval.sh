#!/bin/sh
# 軍の動きの評価：8つの種で 3回×50ターンずつ（同時に回す）。戦時・平時の無駄と占領の平均を出す
cd "$(dirname "$0")/.."
sh tools/build_core.sh >/dev/null
GD=/c/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe
TMP=$(mktemp -d)
for s in 7000 9000 11000 13000 15000 17000 19000 21000; do
  $GD --headless --path . -- --armyeval 3 50 $s > $TMP/$s.txt 2>&1 &
done
wait
for s in 7000 9000 11000 13000 15000 17000 19000 21000; do grep "SCORE2\|SCRIPT ERROR" $TMP/$s.txt | sed "s/^/[$s] /"; done
W=$(cat $TMP/*.txt | grep SCORE2 | sed 's/.*戦時の無駄=\([0-9.]*\).*平時の無駄=\([0-9.]*\).*/\1 \2/' | awk '{w+=$1; p+=$2; n++} END {printf "戦時=%.2f 平時=%.3f", w/n, p/n}')
C=$(cat $TMP/*.txt | grep "^SCORE 無駄" | sed 's/.*=\([0-9.]*\)$/\1/' | awk '{c+=$1; n++} END {printf "%.1f", c/n}')
F=$(cat $TMP/*.txt | grep SCORE3 | sed 's/.*前線の手当て=([0-9.]*).*/echo "平均 $W 占領=$C"
/' | awk '{s+=$1;n++} END {printf "%.2f", s/n}')
echo "平均 $W 占領=$C 前線の手当て=$F"
rm -rf $TMP
