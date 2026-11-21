#!/bin/sh
# core_src/k*.gd を1つの scripts/core.gd（autoload S）にまとめる
#  - extends 行は除き、先頭に extends Node を1つだけ置く
#  - 「var x := 式」は型の推論に失敗しやすいので「var x = 式」にする（中身は JS 由来の動的な処理のため）
cd "$(dirname "$0")/.."
out=scripts/core.gd
{
  echo "# 自動生成：core_src/*.gd をまとめたもの（直接編集しない。tools/build_core.sh で作り直す）"
  echo "extends Node"
  for f in $(ls core_src/k*.gd | sort); do
    echo
    echo "# ==================== $(basename $f) ===================="
    grep -v "^extends " "$f" | perl -pe 's/\bvar (\w+) := /var $1 = /g'
  done
} > "$out"
echo "built $out ($(wc -l < $out) lines)"
