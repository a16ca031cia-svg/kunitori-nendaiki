# 国盗り年代記

ブラウザで遊べる国盗りストラテジーゲーム。

**遊ぶ:** https://a16ca031cia-svg.github.io/kunitori-nendaiki/

## 構成

- `index.html` — ゲーム本体（1ファイル完結。d3-delaunay v6.0.4 を同梱、フォントは Google Fonts）
- `publish.ps1` — 変更をコミットして GitHub に push する（GitHub Pages が自動で更新される）

## 更新のしかた

`index.html` を編集してから:

```powershell
powershell -ExecutionPolicy Bypass -File publish.ps1 -Message "変更内容"
```

## ライセンス表記

d3-delaunay (ISC License) — Copyright 2018-2021 Observable, Inc., 2021 Mapbox
