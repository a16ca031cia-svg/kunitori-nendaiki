#!/bin/sh
# 軍の動きの評価：8つの種で 3回×50ターンずつ（同時に回す）
# 戦時・平時の無駄、占領（攻める力）、前線の手当て（守る力）の平均を出す
cd "$(dirname "$0")/.."
sh tools/build_core.sh >/dev/null
GD=/c/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe
TMP=$(mktemp -d)
for s in 7000 9000 11000 13000 15000 17000 19000 21000; do
  $GD --headless --path . -- --armyeval 3 50 $s > $TMP/$s.txt 2>&1 &
done
wait
for s in 7000 9000 11000 13000 15000 17000 19000 21000; do grep "SCORE2\|SCRIPT ERROR" $TMP/$s.txt | sed "s/^/[$s] /"; done
W=$(cat $TMP/*.txt | grep -o "戦時の無駄=[0-9.]*" | cut -d= -f2 | awk '{s+=$1;n++} END {if (n) printf "%.2f", s/n}')
P=$(cat $TMP/*.txt | grep -o "平時の無駄=[0-9.]*" | cut -d= -f2 | awk '{s+=$1;n++} END {if (n) printf "%.3f", s/n}')
C=$(cat $TMP/*.txt | grep -o "占領/戦争100国ターン=[0-9.]*" | cut -d= -f2 | awk '{s+=$1;n++} END {if (n) printf "%.1f", s/n}')
F=$(cat $TMP/*.txt | grep -o "前線の手当て=[0-9.]*" | cut -d= -f2 | awk '{s+=$1;n++} END {if (n) printf "%.2f", s/n}')
echo "平均 戦時=$W 平時=$P 占領=$C 前線の手当て=$F"
rm -rf $TMP
