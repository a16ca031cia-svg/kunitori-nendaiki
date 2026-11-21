#!/bin/sh
# 軍の動きの評価：2つの種で 3回×50ターンずつ回し、無駄の点数と占領の平均を出す
cd "$(dirname "$0")/.."
sh tools/build_core.sh >/dev/null
GD=/c/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe
A=$($GD --headless --path . -- --armyeval 3 50 7000 2>&1 | grep "SUM\|SCORE\|SCRIPT ERROR")
B=$($GD --headless --path . -- --armyeval 3 50 9000 2>&1 | grep "SUM\|SCORE\|SCRIPT ERROR")
echo "$A" | sed 's/^/[7000] /'
echo "$B" | sed 's/^/[9000] /'
echo "$A
$B" | grep SCORE | sed 's/.*無駄=\([0-9.]*\).*=\([0-9.]*\)$/\1 \2/' | awk '{s+=$1; c+=$2; n++} END {printf "平均 無駄=%.2f 占領=%.1f\n", s/n, c/n}'
