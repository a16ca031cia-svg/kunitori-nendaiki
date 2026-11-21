# 国盗り年代記 Godot版 — 移植の記録

元：`reference/kunitori_nendaiki.html`（1ファイルのHTML/JS、約8,700行）を Godot 4.7.2（標準版・GDScript）へ移植し、Web書き出しで GitHub Pages に載せる。

## 環境
- Godot：`C:\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`（標準版。mono版はWeb書き出し不可のため使わない）
- Web書き出しテンプレート：`%APPDATA%\Godot\export_templates\4.7.2.stable\web_*`（スレッドなし＝GitHub Pagesでそのまま動く）
- フォント：`fonts/`（Google Fonts、OFL）ZenKakuGothicNew Regular/Bold、ShipporiMinchoB1-SemiBold
- perl が Git Bash にある（データ変換に使える）。python/node はない
- 確認：`sh tools/export_web.sh` → ブラウザ確認（launch.json の kunitori-web、ポート8771）。`#size=japan&ff=40&sel=war` で早送り
- 画面なし：`--headless --path . -- --sim japan 30`（ターンごとの時間と PROF を表示）
- 公開：`tools\publish.ps1 -Message "..."`（main に push ＋ build/web を gh-pages に強制 push）

## 設計
- 状態 `G` は JS と同じ形の Dictionary（キー名も同じ）。無いキーは `d.get("k", 既定)`
- ロジックは `core_src/k*.gd` に分けて書き、`tools/build_core.sh`（publish.ps1 にも同じ処理）で `scripts/core.gd` 1本にまとめて autoload `S` にする
  - 理由：GDScript は親クラスから子クラスの関数を呼べないので継承の鎖は使えない。1ファイルならJSと同じく関数を自由に呼び合える
  - まとめる時に `var x := 式` を `var x = 式` にする（JS由来の動的な値で型推論が失敗するため）
  - 鎖の順：k0_base（定数・道具・ログ・軍団の索引）→ k1_map（架空の大陸・日本地図の読み込み・segNbrs）→ k2_rules（経路・補給・国力・軍団・攻城・占領・戦闘）→ k3_dip → k3b_dip → k3c_dip（外交）→ k4_strat（蜂起・CPU外交）→ k5_econ（内政・講和条件）→ k6_turn（ターン進行・CPUの軍）→ k7_game（開始・速さ・セーブ）
- 日本地図：元の JS を Edge headless で動かし、4つの種で作った初期状態（領地の形・つながり・地形など）を `data/jp/map0〜3.bin`（ZSTD圧縮の store_var）に。作り直しは `tools/convert_jp.gd`。国の性格はゲーム開始時に振り直す
- 観戦専用（全勢力CPU）なので、元の `!G.observer` の枝（プレイヤー操作）は移植していない
- 戦闘画面・外交の知らせは signal（battle_show / battle_done、dip_show / dip_closed）で画面に出し、await で待つ
- 地図の描画（map_view.gd）
  - 世界座標の絵を Node2D に置き、拡大・移動は変形だけで行う
  - 動かない層（海・陸・領地・国境・記号・拠点…）と動く層（軍団・軌跡）を別々の SubViewport に描き、変わった時だけ描き直す（`kick()`）
  - 領地の塗りは全領地で1つの三角形の束（色だけ差し替え）。線・円・記号は `scripts/ui/batch.gd` で三角形にまとめて1回で描く
  - 日本地図は県の形で clip_children（元の canvas の clip と同じ）
- 速さの工夫：経路探索は詰めた配列（PF_*）、軍団の索引（ARMY_REV を上げると作り直す）、平時は全領地の走査を省く。日本47国で1ターン 0.3〜1秒（デスクトップ）

## JS の行と移植先
| 元の行 | 内容 | 移植先 | 状態 |
|---|---|---|---|
| 410–807 | 日本の地点・湖・街道・川 | scripts/jp_data.gd | ✓ |
| 809 | 県の形 TopoJSON | data/jp_geo.json | ✓ |
| 823–1442 | 定数・架空大陸の生成 | k0_base / k1_map | ✓ |
| 1443–1600 | 参照・経路・補給・国力 | k2_rules | ✓ |
| 1602–2910 | 描画・入力 | ui/map_view.gd | ✓ |
| 2910–3525 | 画面（帯・欄・記録） | main.gd・ui/hist_chart.gd | ✓ |
| 3575–4048 | 軍団・攻城・占領・戦闘 | k2_rules・main.gd（戦闘画面） | ✓ |
| 4048–5622 | 外交・戦争・陣営・欲求 | k3*・k4_strat | ✓ |
| 5622–6008 | 蜂起・CPUの外交戦略 | k4_strat | ✓ |
| 6008–6440 | 内政・開拓・講和 | k5_econ | ✓ |
| 6439–7220 | ターン進行・出来事・CPU軍 | k6_turn | ✓ |
| 7220–7400 | セーブ | k7_game（user:// に3スロット） | ✓ |
| 7398–7605 | デバッグ画面 | — | 未移植（調整用の画面） |
| 7608–7785 | 起動・メニュー・キー | k7_game・main.gd | ✓ |
| 7785–8677 | 日本地図の生成 | 事前生成（data/jp） | ✓ |

## 既知の点・これから
- デバッグ画面（数値の調整）は未移植
- 日本地図は4種類の初期配置から選ぶ（元は毎回作り直し）
- ブラウザのペインが隠れていると1秒1フレームに落ち、ターンが遅く見える（実際のタブでは問題ない）

## 音（2026-11-21）
- BGM 2曲（平時＝都節の箏と持続音、戦時＝太鼓と撥音）と効果音8種を `tools/gen_audio.gd` で合成（素材のダウンロードなし）。作り直しは `godot --headless --path . --script res://tools/gen_audio.gd`
- 選んだ国が戦争中なら戦時の曲（選んでいなければ戦争が多い時）。切り替えは1.5秒で重ねる
- 効果音：ボタン・ターン終わり・外交の知らせ（宣戦系／和平系／その他）・戦闘画面・選んだ国の占領・滅亡。同じ音は短い間に重ねない
- メニューの「音楽」「効果音」で切り替え（表示の好みと一緒に保存）

## 軍団の移動を軽く（2026-11-21）
- 軍団が一手動くたびの描き直しを `beat` 信号の軽い更新に（右の欄は作り直さない・地図は持ち主が変わった時だけ）
- 国境の線を持ち主が変わるまで使い回し（選んだ国の関係の縁取りが重かった）
- 軍団の盾・兵種の印を三角形の束にまとめて1回で描く
