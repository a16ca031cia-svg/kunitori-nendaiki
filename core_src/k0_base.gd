# 国盗り年代記 — 定数・データ・道具（元 823〜1046行）
extends Node

const INF := 1.0e30

func rnd(a: float, b: float) -> float: return a + randf() * (b - a)
func ri(a: int, b: int) -> int: return int(floor(rnd(a, b + 1)))
func pick(a: Array): return a[int(floor(randf() * a.size()))]
func clamp_f(v: float, a: float, b: float) -> float: return a if v < a else (b if v > b else v)
## 3桁区切りの整数
func fmt(n) -> String:
	var v := int(round(float(n)))
	var neg := v < 0
	var s := str(abs(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out
func shuffled(a: Array) -> Array:
	var b := a.duplicate()
	b.shuffle()
	return b

const TK := ["inf", "spe", "arc", "cav"]
const TROOP := {
	"inf": {"n": "歩兵", "atk": 105, "def": 110, "chg": 0.02, "c": "#d3c096"},
	"spe": {"n": "槍兵", "atk": 95, "def": 130, "chg": 0.00, "c": "#8fb6cc"},
	"arc": {"n": "弓兵", "atk": 140, "def": 70, "chg": 0.03, "c": "#cf9c8c"},
	"cav": {"n": "騎兵", "atk": 120, "def": 90, "chg": 0.30, "c": "#b9a2d6"},
}
const BLD := {
	"farm": {"n": "農場", "cost": 1500, "eff": "食料 +500"},
	"market": {"n": "市場", "cost": 1500, "eff": "ゴールド +500", "cityOnly": true},
	"gov": {"n": "役所", "cost": 2000, "eff": "治安 +5 / ターン"},
	"house": {"n": "住宅地", "cost": 2000, "eff": "人口上限 +3,000・増加 +50%", "cityOnly": true},
	"inf": {"n": "歩兵舎", "cost": 1500, "eff": "歩兵 +400"},
	"spe": {"n": "槍兵舎", "cost": 2000, "eff": "槍兵 +300"},
	"arc": {"n": "弓兵舎", "cost": 2000, "eff": "弓兵 +250"},
	"cav": {"n": "厩舎", "cost": 3000, "eff": "騎兵 +150"},
	"mf": {"n": "軍需工場", "cost": 2500, "eff": "軍需品 +300（兵の生産に要る）"},
	"cf": {"n": "民需工場", "cost": 2500, "eff": "ゴールド +300・建設費 -2%"},
}
const BLD_OUT := {"market": {"gold": 500}, "farm": {"food": 500}, "inf": {"inf": 400}, "spe": {"spe": 300}, "arc": {"arc": 250}, "cav": {"cav": 150}}
const BLD_KEYS := ["farm", "market", "gov", "house", "inf", "spe", "arc", "cav", "mf", "cf"]
const TRAIT := {
	"fertile": {"n": "肥沃な土地", "d": "農場の食料 +30%", "c": "#6d9c63"},
	"trade": {"n": "商業都市", "d": "市場の収入 +30%", "c": "#c9a227", "city": true},
	"iron": {"n": "鉄鉱地", "d": "歩兵・槍兵の生産 +20%", "c": "#9aa3ad"},
	"horse": {"n": "馬産地", "d": "騎兵の生産 +30%", "c": "#b9a2d6"},
	"mount": {"n": "山岳要衝", "d": "防御 +15%", "c": "#8d8272"},
	"road": {"n": "宿場町", "d": "インフラによる収入効果 +10%", "c": "#cf9c8c"},
	"dense": {"n": "人口密集地", "d": "人口上限 +30%", "c": "#8fb6cc"},
}
const TRAIT_KEYS := ["fertile", "trade", "iron", "horse", "road", "dense"]   # 山岳要衝は地形「山地」に置き換え
const TERRAIN := {
	"plain": {"n": "平地", "c": "#e2d6aa", "def": 0.0, "pop": 1.0, "food": 1.1, "slow": false, "troop": {}, "d": "暮らしやすい土地。農場の食料 +10%"},
	"grass": {"n": "草原", "c": "#d2d99c", "def": -0.05, "pop": 0.9, "food": 1.0, "slow": false, "troop": {"cav": 1.3}, "d": "騎兵の生産 +30%・守りにくい（防御 -5%）・人口上限 -10%"},
	"forest": {"n": "森林", "c": "#a9c08f", "def": 0.15, "pop": 0.8, "food": 0.9, "slow": true, "troop": {"arc": 1.2}, "d": "防御 +15%・弓兵の生産 +20%・人口上限 -20%・食料 -10%・入るのに2ターン（インフラで短縮）"},
	"hill": {"n": "丘陵", "c": "#d6bf8e", "def": 0.15, "pop": 0.85, "food": 0.9, "slow": false, "troop": {"spe": 1.15}, "d": "防御 +15%・槍兵の生産 +15%・人口上限 -15%・食料 -10%・入るのに2ターン（インフラで短縮）"},
	"mount": {"n": "山地", "c": "#bcae96", "def": 0.35, "pop": 0.55, "food": 0.7, "slow": true, "troop": {"inf": 1.15}, "d": "防御 +35%・歩兵の生産 +15%・人口上限 -45%・食料 -30%・入るのに3ターン（インフラで短縮）"},
	"marsh": {"n": "湿地", "c": "#b3c6b4", "def": 0.2, "pop": 0.7, "food": 0.8, "slow": true, "troop": {}, "d": "防御 +20%・人口上限 -30%・食料 -20%・入るのに2ターン（インフラで短縮）"},
}
const TERRAIN_KEYS := ["plain", "grass", "forest", "hill", "mount", "marsh"]
const TERRAIN_KEYS_IDX := {"plain": 0, "grass": 1, "forest": 2, "hill": 3, "mount": 4, "marsh": 5}
func terrOf(t: Dictionary) -> Dictionary: return TERRAIN.get(t.get("terrain", "plain"), TERRAIN.plain)
const TERR_COST := {"plain": 1, "grass": 1, "hill": 2, "forest": 2, "marsh": 2, "mount": 3}
const TRAIT_RATE := 0.45
const DEV_COST := [0, 2000, 5000, 10000, 20000, 0]
const ROAD_COST := [0, 5000, 12000, 0]
const INFRA_COST := [0, 0, 12000, 30000]
const INFRA_RATE := {"econ": 0.22, "bal": 0.14, "def": 0.12, "aggr": 0.08, "neutral": 0.22, "democracy": 0.18, "communism": 0.14, "fascism": 0.08}
const INFRA_N := ["", "乏しい", "整った", "主要街道"]
const FORT_DEV_DEF := [0, 0, 0.05, 0.10, 0.15, 0.20]
const GEN_ABIL := [
	{"k": "atk", "n": "攻撃力 +5%"}, {"k": "def", "n": "防御力 +5%"}, {"k": "chg", "n": "突撃率 +3%"},
	{"k": "inf", "n": "歩兵効果 +8%"}, {"k": "spe", "n": "槍兵効果 +8%"},
	{"k": "arc", "n": "弓兵効果 +8%"}, {"k": "cav", "n": "騎兵効果 +8%"},
]
const GEN_COST := 5000
const GEN_MAX := 24
const ARMY_MAX := 20
const TURN_MAX := 9999
const NCOL_BASE := ["#b03a3a", "#3a6ea5", "#4c8a52", "#7f5aa8", "#c07f2a",
	"#2f8f8a", "#a8467f", "#86953a", "#d0b040", "#8a5c3a", "#c2757f", "#5a6b7d"]
const NCOL_WILD := "#8f8672"   # 無主の地（JS の NCOL[-1]）
var NCOL: Array = NCOL_BASE.duplicate()
func ncol(i: int) -> String: return NCOL_WILD if i < 0 or i >= NCOL.size() else NCOL[i]
func resetColors(list = null) -> void:
	NCOL = (list if list != null and list.size() > 0 else NCOL_BASE).duplicate()
const SIZES := {"small": {"n": 250, "nat": 8}, "mid": {"n": 400, "nat": 10}, "large": {"n": 600, "nat": 12}}

const PERSONA := {
	"fascism": IDEO_PERSONA.fascism, "communism": IDEO_PERSONA.communism, "democracy": IDEO_PERSONA.democracy, "neutral": IDEO_PERSONA.neutral,
	"aggr": {"n": "攻勢型", "d": "軍団と侵攻を優先", "army": 1, "goal": 0.85, "atkTh": 1.05, "guard": 0.34, "mkt": 0.22, "devG": 9000, "roadG": 21000, "mix": {"inf": 0.42, "spe": 0.13, "arc": 0.20, "cav": 0.25}, "settle": 0.8,
		"tradeW": -10, "pactW": -25, "fab": 0.45, "noCB": 0.12, "peaceW": -0.03, "dd": "口実を作ってでも弱い隣国を狙う。条約は好まない"},
	"def": {"n": "防衛型", "d": "砦と国境を重視", "army": 0, "goal": 1.10, "atkTh": 1.50, "guard": 0.62, "mkt": 0.40, "devG": 7000, "roadG": 15000, "mix": {"inf": 0.40, "spe": 0.32, "arc": 0.20, "cav": 0.08}, "settle": 1.0,
		"tradeW": 5, "pactW": 20, "fab": 0.0, "noCB": 0.0, "peaceW": 0.05, "dd": "大義のある戦しかしない。不可侵条約で背後を固める"},
	"econ": {"n": "内政型", "d": "都市とインフラを優先", "army": -1, "goal": 1.15, "atkTh": 1.45, "guard": 0.50, "mkt": 0.62, "devG": 3500, "roadG": 10000, "mix": {"inf": 0.45, "spe": 0.20, "arc": 0.22, "cav": 0.13}, "settle": 1.5,
		"tradeW": 15, "pactW": 10, "fab": 0.0, "noCB": 0.0, "peaceW": 0.08, "dd": "開拓と通商で富を築く。戦は避け、早く講和する"},
	"bal": {"n": "均衡型", "d": "攻守のつり合いを取る", "army": 0, "goal": 1.0, "atkTh": 1.20, "guard": 0.50, "mkt": 0.42, "devG": 6000, "roadG": 16000, "mix": {"inf": 0.45, "spe": 0.20, "arc": 0.20, "cav": 0.15}, "settle": 1.1,
		"tradeW": 5, "pactW": 0, "fab": 0.2, "noCB": 0.0, "peaceW": 0.02, "dd": "大義があり勝てる時に限って戦う"},
}

## 調整用パラメータ（すべて仮値・デバッグから変更可）
var CFG := {
	"chaosTurns": 3, "chaosMul": 0.5, "supplyPenalty": 0.10, "eventRate": 0.09,
	"showCpuBattle": true, "showDip": true,
	"dmgK": 0.008, "sizeExp": 0.80, "chargeIgnore": 0.5, "baseGold": 100, "fortBase": 0.30,
	"assaultLoss": 1.35, "siegeTurns": 3, "siegeBleed": 0.14, "siegeSec": 7, "siegeFood": 4,
	"cpuStop": false, "minDmg": 4,
	"cpuDelay": 340, "autoTurnMs": 700, "phaseDelay": 480,
	"taxRate": 0.02, "popCity": 6000, "popFort": 2500, "popGrow": 0.10, "levyPop": 1, "levyFloor": 0.30,
	"disbandBack": 0.8, "stockCapPop": 0.25, "houseCap": 3000, "foodPop": 4, "foodTroop": 6, "farmOut": 500,
	"secStart": 70, "secRecover": 2, "secGov": 5, "secWar": -1, "secChaos": -4, "secStarve": -6, "secCapture": 25,
	"revoltSec": 15, "revoltRate": 0.12,
	"roadBonus": [0, 0, 0.10, 0.20],
	"fatWar": 2, "fatPeace": -4, "fatLose": 5, "fatTerr": 8,
	"fatMid": 50, "fatMidMul": 0.10, "fatHigh": 80, "fatHighMul": 0.25,
}
## 序盤：無主の地と開拓
var FRONT := {"startTerr": 0, "wildPop": 0.55, "settleGold": 3000, "settleGrow": 120, "settleTurns": 3, "settleMax": 3, "settleSec": 60}

var G = null   # ゲーム状態（Dictionary）
## 画面側の状態（JS の UI のうちロジックが参照するもの）
var UI := {"sel": null, "selArmy": null, "selRoad": null, "moveMode": null, "size": "japan", "busy": false,
	"actArmy": null, "mapMode": "pol", "selNat": null, "speed": 1, "logOn": true}

## 画面への通知（UI 側がつなぐ）。ロジックからは emit するだけ
signal log_changed
signal notified(msg: String, cls: String)
signal map_changed(kind: String, arg)   # "terr"(tid) / "all" / "edge"
signal fx(kind: String, arg)            # "move"(army,from) / "flash"(tid)

# ---------- 名前生成 ----------
const NA := ["ヴァル", "エル", "グラン", "ザル", "メル", "オル", "カル", "ディ", "ノル", "ラム", "テュ", "ブラン"]
const NB := ["ドリア", "ガルド", "ハイム", "ティア", "メルク", "ローデ", "バーン", "シュタット", "フェルト", "ネス"]
const NC := ["王国", "公国", "帝国", "侯国", "同盟"]
const CA := ["アル", "ベル", "クレ", "ドラ", "エス", "フィ", "ゴル", "ハル", "イル", "ジェ", "ケル", "ラン", "ミル",
	"ノヴ", "オス", "プラ", "リヴ", "サル", "トル", "ウル", "ヴェ", "ワル", "ザン", "ヒル", "モン",
	"カル", "セル", "ネル", "ロウ", "ダン", "エル", "グラ", "ティ", "バル", "メル"]
const CB := ["ム", "ン", "ス", "ト", "ク", "ラ", "ダ", "グ", "ベル", "ハイム", "ポート", "フェン", "ロード", "ブルク", "ヴィル",
	"ドール", "ミア", "リア", "ノール", "タス"]
const FA := ["鷹", "黒", "白", "鉄", "灰", "古", "赤", "銀", "狼", "竜", "碑", "霧", "朝", "涯", "槍",
	"青", "金", "烏", "鹿", "雪", "月", "星", "風", "嵐", "石"]
const FB := ["の門", "の峰", "の渡し", "ノ関", "の丘", "の辻", "の岩", "の谷",
	"の森", "の淵", "の原", "の坂", "の塔", "の湊", "の牙", "の尾"]
const GN_A := ["アル", "ベル", "コン", "ドル", "エギ", "ファ", "ガル", "ハウ", "イグ", "ジル", "クラ", "ルー", "マル", "ノ", "オー"]
const GN_B := ["ヴィン", "トス", "ラート", "ミル", "ドルフ", "ザーク", "ハルト", "ネス", "グレン", "ヴィス", "ベルト"]

func uniqName(used: Dictionary, f: Callable) -> String:
	for i in 200:
		var s: String = f.call()
		if not used.has(s):
			used[s] = true
			return s
	return f.call() + str(used.size())

func d2(x: float, y: float, p) -> float: return (x - p[0]) * (x - p[0]) + (y - p[1]) * (y - p[1])
func bkey(a: int, b: int) -> String: return (str(a) + "_" + str(b)) if a < b else (str(b) + "_" + str(a))

# ---------- 参照ヘルパ ----------
func T(id) -> Dictionary: return G.terrs[int(id)]
func NAT(id) -> Dictionary: return G.nations[int(id)]
func total(t: Dictionary) -> int: return int(t.inf + t.spe + t.arc + t.cav)
func followNat():
	return UI.selNat if G.observer else 0
func concerns(ids: Array) -> bool:
	var f = followNat()
	return f != null and f >= 0 and ids.has(f)
func logWar(msg: String, ids: Array, cls := "") -> void:
	if concerns(ids): logMsg(msg, cls)
func logMsg(s: String, cls := "") -> void:
	G.log.append({"s": s, "cls": cls, "t": G.turn})
	if G.log.size() > 60: G.log.pop_front()
	log_changed.emit()
func notify(msg: String, cls := "") -> void:
	notified.emit(msg, cls)
	if G != null: logMsg(msg, "war" if cls == "err" else cls)
var CHRON_BIG: bool = OS.get_environment("KN_TRACE") != ""
func chron(text: String, nid = null, kind := "") -> void:
	if G == null or not G.has("chron"): return
	G.chron.append({"t": G.turn, "s": text, "n": -1 if nid == null else nid, "k": kind})
	if G.chron.size() > (20000 if CHRON_BIG else 800): G.chron.pop_front()

func genOf(na: Dictionary, gid):
	if gid == null: return null
	for x in na.gens:
		if x.id == gid: return x
	return null
## 領地ごとの軍団の索引（軍団が動いた・増えた・消えた時に ARMY_REV を上げると作り直す）
var ARMY_REV := 0
var AIDX_REV := -1
var AIDX_G = null
var AIDX := {}
const EMPTY_ARR := []
func armiesAt(tid: int) -> Array:
	if AIDX_REV != ARMY_REV or AIDX_G != G:
		AIDX = {}
		for na in G.nations:
			for a in na.armies:
				if a == null: continue
				if AIDX.has(a.at): AIDX[a.at].append(a)
				else: AIDX[a.at] = [a]
		AIDX_REV = ARMY_REV
		AIDX_G = G
	return AIDX.get(tid, EMPTY_ARR)
func myArmies(nid: int) -> Array:
	var r := []
	for a in G.nations[nid].armies:
		if a != null: r.append(a)
	return r

## 色の文字列 → Color
func col(hex: String, a := 1.0) -> Color:
	var c := Color.html(hex)
	c.a = a
	return c
