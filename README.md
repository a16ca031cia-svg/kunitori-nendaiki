# 国盗り年代記（Godot版）

国々の興亡を見届ける観戦型の国盗りストラテジー。すべての国を CPU が動かし、気になる国を選んでその目線で観戦する。

**遊ぶ:** https://a16ca031cia-svg.github.io/kunitori-nendaiki/

- 地図は「日本（47都道府県）」と「架空の大陸（小・中・大）」
- 元は1ファイルの HTML 版（`reference/kunitori_nendaiki.html`）。Godot 4.7.2（GDScript）で作り直し、Web 書き出しで公開している

## 構成

| 場所 | 中身 |
|---|---|
| `core_src/k*.gd` | ゲームの中身（計算・CPU・外交・戦闘など）。ここを編集する |
| `scripts/core.gd` | 上をまとめた自動生成ファイル（autoload `S`）。直接は編集しない |
| `scripts/main.gd` | 画面（上の帯・右の欄・窓・キー操作） |
| `scripts/ui/map_view.gd` | 地図の描画と操作 |
| `scripts/jp_data.gd`・`data/` | 日本地図のデータ（地点・街道・川、県の形、初期状態4種類） |
| `fonts/` | Zen Kaku Gothic New・Shippori Mincho B1（SIL Open Font License） |
| `audio/` | BGM（平時・戦時）と効果音。素材は使わず `tools/gen_audio.gd` で合成したもの |
| `tools/` | まとめ・書き出し・公開・確認用のスクリプト |

## 遊び方の確認（ローカル）

```powershell
sh tools/export_web.sh
powershell -ExecutionPolicy Bypass -File tools\serve.ps1
```

http://localhost:8771/ を開く。`#size=japan&ff=40&sel=war` を付けると、40ターン早送りして戦争中の国を選んだ状態から始まる（確認用）。

画面なしでターンを回す：

```powershell
C:\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --sim japan 30
```

## 公開

```powershell
powershell -ExecutionPolicy Bypass -File tools\publish.ps1 -Message "変更内容"
```

ソースを `main` に push し、書き出した Web 版を `gh-pages` ブランチに置く（GitHub Pages は `gh-pages` から配信）。

## ライセンス表記

- フォント：Zen Kaku Gothic New、Shippori Mincho B1（SIL Open Font License 1.1、`fonts/OFL_*.txt`）
- 日本地図の県の形：元の HTML 版に含まれていたデータ（利用者提供の japan.geojson を変換したもの）
