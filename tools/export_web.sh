#!/bin/sh
# core_src をまとめて、Web 版を build/web に書き出す
cd "$(dirname "$0")/.."
sh tools/build_core.sh
G=/c/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe
mkdir -p build/web
"$G" --headless --path . --export-release Web build/web/index.html 2>&1 | grep -E "ERROR|SCRIPT|savepack" | grep -v "^\s*$" | tail -5
ls -la build/web | awk '{print $5, $9}'
