# 自動生成：core_src/*.gd をまとめたもの（直接編集しない。tools/build_core.sh か publish.ps1 で作り直す）
extends Node

# ==================== k0_base.gd ====================
# 国盗り年代記 — 定数・データ・道具（元 823〜1046行）

const INF := 1.0e30

func rnd(a: float, b: float) -> float: return a + randf() * (b - a)
func ri(a: int, b: int) -> int: return int(floor(rnd(a, b + 1)))
func pick(a: Array): return a[int(floor(randf() * a.size()))]
func clamp_f(v: float, a: float, b: float) -> float: return a if v < a else (b if v > b else v)
## 3桁区切りの整数
func fmt(n) -> String:
	var v = int(round(float(n)))
	var neg = v < 0
	var s = str(abs(v))
	var out = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out
func shuffled(a: Array) -> Array:
	var b = a.duplicate()
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
var CFG = {
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
var FRONT = {"startTerr": 0, "wildPop": 0.55, "settleGold": 3000, "settleGrow": 120, "settleTurns": 3, "settleMax": 3, "settleSec": 60}

var G = null   # ゲーム状態（Dictionary）
## 画面側の状態（JS の UI のうちロジックが参照するもの）
var UI = {"sel": null, "selArmy": null, "selRoad": null, "moveMode": null, "size": "japan", "busy": false,
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
var ARMY_REV = 0
var AIDX_REV = -1
var AIDX_G = null
var AIDX = {}
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
	var r = []
	for a in G.nations[nid].armies:
		if a != null: r.append(a)
	return r

## 色の文字列 → Color
func col(hex: String, a := 1.0) -> Color:
	var c = Color.html(hex)
	c.a = a
	return c

# ==================== k1_map.gd ====================
# 地図：架空の大陸の生成（元 1048〜1418）・日本地図の読み込み・領地の形の道具

const JP := {"U": 6.5, "S": 4, "lon0": 127.6, "lat1": 45.9}
func jpProj(lon: float, lat: float) -> Vector2:
	var kx: float = 111.32 * cos(deg_to_rad(36.5)) * JP.U
	var ky: float = 110.95 * JP.U
	return Vector2((lon - JP.lon0) * kx, (JP.lat1 - lat) * ky)

# ---------- 幾何 ----------
## 多角形を長方形で切る
func clipRect(poly: Array, x0: float, y0: float, x1: float, y1: float) -> Array:
	var p = poly
	p = _clipEdge(p, 0, x0, true); if p.size() < 3: return p
	p = _clipEdge(p, 0, x1, false); if p.size() < 3: return p
	p = _clipEdge(p, 1, y0, true); if p.size() < 3: return p
	return _clipEdge(p, 1, y1, false)
func _clipEdge(pts: Array, axis: int, v: float, keepGreater: bool) -> Array:
	var out = []
	var n = pts.size()
	for i in n:
		var A: Vector2 = pts[i]
		var B: Vector2 = pts[(i + 1) % n]
		var ia: bool = (A[axis] >= v) if keepGreater else (A[axis] <= v)
		var ib: bool = (B[axis] >= v) if keepGreater else (B[axis] <= v)
		if ia: out.append(A)
		if ia != ib:
			var t: float = (v - A[axis]) / (B[axis] - A[axis])
			out.append(A + (B - A) * t)
	return out
func _circum(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var d = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if abs(d) < 1e-12: return (a + b + c) / 3.0
	var a2 = a.length_squared()
	var b2 = b.length_squared()
	var c2 = c.length_squared()
	return Vector2((a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d,
		(a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d)
## ドロネー分割から作るボロノイ（JS の voronoiD3 と同じ形で返す）
func buildVoronoi(sites: Array, W: float, H: float) -> Dictionary:
	var n = sites.size()
	var pts = PackedVector2Array()
	for s in sites: pts.append(s)
	pts.append(Vector2(-10 * W, -10 * H)); pts.append(Vector2(11 * W, -10 * H))
	pts.append(Vector2(11 * W, 11 * H)); pts.append(Vector2(-10 * W, 11 * H))
	var tri = Geometry2D.triangulate_delaunay(pts)
	var inc = []
	var nbs = []
	for i in n:
		inc.append([])
		nbs.append({})
	var cc = []
	for k in range(0, tri.size(), 3):
		var ia = tri[k]
		var ib = tri[k + 1]
		var ic = tri[k + 2]
		var c = _circum(pts[ia], pts[ib], pts[ic])
		var ti = cc.size()
		cc.append(c)
		for v in [ia, ib, ic]:
			if v < n: inc[v].append(ti)
		for e in [[ia, ib], [ib, ic], [ic, ia]]:
			if e[0] < n and e[1] < n:
				nbs[e[0]][e[1]] = true
				nbs[e[1]][e[0]] = true
	var polys = []
	var nb = []
	var edgeNb = []
	for i in n:
		var s: Vector2 = sites[i]
		var ring = []
		for ti in inc[i]: ring.append(cc[ti])
		ring.sort_custom(func(p, q): return (p - s).angle() < (q - s).angle())
		var dd = []
		for p in ring:
			if dd.is_empty() or (p - dd[-1]).length() > 1e-3: dd.append(p)
		if dd.size() > 1 and (dd[0] - dd[-1]).length() <= 1e-3: dd.pop_back()
		var poly = clipRect(dd, 0, 0, W, H)
		var clean = []
		for p in poly:
			if clean.is_empty() or (p - clean[-1]).length() > 1e-3: clean.append(p)
		if clean.size() > 1 and (clean[0] - clean[-1]).length() <= 1e-3: clean.pop_back()
		polys.append(clean)
		nb.append({})
		edgeNb.append([])
	for i in n:
		var p: Array = polys[i]
		var cand: Array = nbs[i].keys()
		for e in p.size():
			var A: Vector2 = p[e]
			var B: Vector2 = p[(e + 1) % p.size()]
			var m = (A + B) / 2.0
			var di = m.distance_squared_to(sites[i])
			var best = -1
			var bd = INF
			for j in cand:
				var dj = m.distance_squared_to(sites[j])
				if dj < bd:
					bd = dj
					best = j
			var shared: bool = best >= 0 and abs(bd - di) < max(1.0, di) * 1e-3   # Vector2 は単精度なので緩めに（候補はドロネーの隣だけ）
			edgeNb[i].append(best if shared else -1)
			if shared:
				nb[i][best] = true
				nb[best][i] = true
	return {"polys": polys, "nb": nb, "edgeNb": edgeNb}

# ---------- 境界の曲線化 ----------
func wobbleEdge(A: Vector2, B: Vector2) -> Array:
	var d = B - A
	var len: float = max(d.length(), 1.0)
	var n = int(clamp_f(round(len / 34), 2, 7))
	var pn = Vector2(-d.y / len, d.x / len)
	var amp: float = min(17.0, len * 0.14)
	var pts = [A]
	var o = 0.0
	for i in range(1, n):
		var t = float(i) / n
		o = o * 0.5 + (randf() * 2 - 1) * amp
		var w = o * sin(PI * t)
		pts.append(A + d * t + pn * w)
	pts.append(B)
	return pts
# ---------- なめらかなノイズ ----------
func waveNoise(n: int, minL: float, maxL: float) -> Callable:
	var w = []
	for i in n:
		var a = randf() * TAU
		var L = rnd(minL, maxL)
		w.append([cos(a) * TAU / L, sin(a) * TAU / L, randf() * 7, rnd(0.5, 1)])
	return func(x: float, y: float) -> float:
		var v = 0.0
		var s2 = 0.0
		for q in w:
			v += sin(x * q[0] + y * q[1] + q[2]) * q[3]
			s2 += q[3]
		return v / s2
func assignTerrain(sites: Array) -> Array:
	var n = sites.size()
	var el = waveNoise(7, 900, 2600)
	var mo = waveNoise(7, 800, 2400)
	var fine = waveNoise(5, 350, 700)
	var E = []
	var Mo = []
	for s in sites:
		E.append(el.call(s.x, s.y) + fine.call(s.x, s.y) * 0.35)
		Mo.append(mo.call(s.x, s.y) + fine.call(s.y, s.x) * 0.3)
	var res = []
	res.resize(n)
	res.fill("plain")
	var rest = range(n)
	var take = func(list: Array, cnt: int, key: Callable, kind: String) -> Array:
		list.sort_custom(func(a, b): return key.call(a) > key.call(b))
		for i in min(cnt, list.size()): res[list[i]] = kind
		return list.slice(cnt)
	rest = take.call(rest, int(round(n * 0.10)), func(i): return E[i], "mount")
	rest = take.call(rest, int(round(n * 0.15)), func(i): return E[i], "hill")
	rest = take.call(rest, int(round(n * 0.08)), func(i): return Mo[i] - E[i] * 0.8, "marsh")
	rest = take.call(rest, int(round(n * 0.20)), func(i): return Mo[i], "forest")
	rest = take.call(rest, int(round(n * 0.15)), func(i): return -Mo[i], "grass")
	return res
# ---------- 大陸の輪郭 ----------
func makeContinent() -> Callable:
	var ph = [rnd(0, 6.28), rnd(0, 6.28), rnd(0, 6.28), rnd(0, 6.28), rnd(0, 6.28)]
	var a = [rnd(0.11, 0.19), rnd(0.08, 0.15), rnd(0.05, 0.10), rnd(0.03, 0.07), rnd(0.02, 0.05)]
	var base = rnd(0.70, 0.78)
	return func(th: float) -> float:
		return clamp_f(base + a[0] * sin(th * 2 + ph[0]) + a[1] * sin(th * 3 + ph[1]) + a[2] * sin(th * 5 + ph[2]) \
			+ a[3] * sin(th * 7 + ph[3]) + a[4] * sin(th * 11 + ph[4]), 0.30, 0.985)
func inLand(shape: Callable, x: float, y: float, W: float, H: float) -> bool:
	var dx = (x - W / 2) / (W / 2)
	var dy = (y - H / 2) / (H / 2)
	return Vector2(dx, dy).length() <= shape.call(atan2(dy, dx))
func keepMainland(keep: Array, nb: Array) -> Array:
	var seen = []
	seen.resize(keep.size())
	seen.fill(false)
	var best = null
	for i in keep.size():
		if not keep[i] or seen[i]: continue
		var q = [i]
		seen[i] = true
		var h = 0
		while h < q.size():
			for j in nb[q[h]]:
				if keep[j] and not seen[j]:
					seen[j] = true
					q.append(j)
			h += 1
		if best == null or q.size() > best.size(): best = q
	if best == null: return keep
	var ok = []
	ok.resize(keep.size())
	ok.fill(false)
	for i in best: ok[i] = true
	return ok

func _newNation(k: int, name: String, color: String, capital: int, persona: String) -> Dictionary:
	var arm = []
	arm.resize(ARMY_MAX)
	return {"id": k, "name": name, "color": color, "gold": 10000, "stock": {"inf": 3000, "spe": 0, "arc": 0, "cav": 0},
		"gens": [], "armies": arm, "alive": true, "capital": capital, "player": false, "persona": persona,
		"wins": 0, "losses": 0, "recLed": 0, "badHarv": 0, "mile": {}, "threat": 0,
		"food": 0, "foodIn": 0, "foodNeed": 0, "fatigue": 0,
		"lord": null, "unrest": 0, "revoltBuff": 0, "policy": "none", "policyAt": -99}
func _newTerr(i: int, pos: Vector2, segs: Array, owner: int, cap: bool, type: String, name: String, dev: int, terrain: String) -> Dictionary:
	return {"id": i, "x": pos.x, "y": pos.y, "segs": segs, "owner": owner, "cap": cap, "type": type, "name": name,
		"dev": dev, "devP": false, "bld": [], "chaos": 0, "pop": 0, "sec": CFG.secStart, "link": 1, "trait": null,
		"terrain": terrain, "infra": 1, "siege": null}
## 最後の仕上げ：国の初期の食料・将軍と第1軍団
func _finishNations(g: Dictionary) -> void:
	var popBy = {}
	for t in g.terrs: popBy[t.owner] = popBy.get(t.owner, 0) + t.pop
	for na in g.nations:
		na.food = int(round((popBy.get(na.id, 0) / 1000.0 * CFG.foodPop + 3 * CFG.foodTroop) * 10))
	initDip(g)
	for na in g.nations:
		var gen = mkGen(g, na, randomPts())
		var a = mkArmy(na.id, 0, na.capital)
		a.t.inf = 3000
		a.target.inf = 3000
		a.gen = gen.id
		gen.army = 0
		na.armies[0] = a; ARMY_REV += 1
		na.stock.inf = 0

## 架空の大陸
func genMap(size: String) -> Dictionary:
	var SZ: Dictionary = SIZES.get(size, SIZES.mid)
	var N: int = SZ.n
	var NN: int = SZ.nat
	var shape = makeContinent()
	var mult = 1.85
	var cols = 1
	var rows = 1
	var W = 0.0
	var H = 0.0
	var pts = []
	var land = []
	for it in 9:
		var M: int = max(NN * 3, int(round(N * mult)))
		cols = int(round(sqrt(M * 2.1)))
		rows = max(3, int(round(float(M) / cols)))
		W = 190.0 * cols
		H = 190.0 * rows
		pts = []
		for r in rows:
			for c in cols:
				var cw = W / cols
				var ch = H / rows
				pts.append(Vector2(cw * (c + 0.5) + rnd(-cw * 0.32, cw * 0.32), ch * (r + 0.5) + rnd(-ch * 0.32, ch * 0.32)))
		land = []
		var k = 0
		for p in pts:
			var v = inLand(shape, p.x, p.y, W, H)
			land.append(v)
			if v: k += 1
		if abs(k - N) <= max(2, N * 0.03): break
		mult *= float(N) / max(1, k)
	var sites0 = pts
	var V = buildVoronoi(sites0, W, H)
	var polys0: Array = V.polys
	var nb0 = []
	for s in V.nb: nb0.append(s.keys())
	var edgeNb0: Array = V.edgeNb
	var n0 = sites0.size()
	# 境界線を曲線化（隣り合う領地で同じ線を共有する）
	var borders = {}
	for i in n0:
		var p: Array = polys0[i]
		for e in p.size():
			var j: int = edgeNb0[i][e]
			if j < 0 or i > j: continue
			borders[bkey(i, j)] = wobbleEdge(p[e], p[(e + 1) % p.size()])
	var outlines0 = []
	for i in n0:
		var p: Array = polys0[i]
		var segs = []
		for e in p.size():
			var A: Vector2 = p[e]
			var B: Vector2 = p[(e + 1) % p.size()]
			var j: int = edgeNb0[i][e]
			if j < 0:
				segs.append([A, B])
				continue
			if not borders.has(bkey(i, j)):
				segs.append([A, B])
				continue
			var line: Array = borders[bkey(i, j)]
			if i < j: segs.append(line.duplicate())
			else:
				var r = line.duplicate()
				r.reverse()
				segs.append(r)
		outlines0.append(segs)
	# 海の部分を捨てて番号を振り直す
	var keep = keepMainland(land, nb0)
	var remap = []
	remap.resize(n0)
	remap.fill(-1)
	var pick0 = []
	for i in n0:
		if keep[i]:
			remap[i] = pick0.size()
			pick0.append(i)
	var sites = []
	var outlines = []
	var nb = []
	for i in pick0:
		sites.append(sites0[i])
		outlines.append(outlines0[i])
		var l = []
		for j in nb0[i]:
			if keep[j]: l.append(remap[j])
		nb.append(l)
	var n = sites.size()
	# 国の種（互いに離れた点）
	var seeds = [ri(0, n - 1)]
	while seeds.size() < NN:
		var best = -1
		var bd = -1.0
		for i in n:
			if seeds.has(i): continue
			var d = INF
			for s in seeds: d = min(d, sites[i].distance_squared_to(sites[s]))
			if d > bd:
				bd = d
				best = i
		seeds.append(best)
	# 多元BFSで領地を分配
	var owner = []
	owner.resize(n)
	owner.fill(-1)
	var front = []
	for k in NN:
		owner[seeds[k]] = k
		front.append([seeds[k]])
	var placed = NN
	while placed < n:
		var moved = false
		for k in NN:
			var f: Array = front[k]
			while f.size():
				var cur: int = f[0]
				var free = []
				for j in nb[cur]:
					if owner[j] < 0: free.append(j)
				if free.is_empty():
					f.pop_front()
					continue
				var j2: int = free[ri(0, free.size() - 1)]
				owner[j2] = k
				f.append(j2)
				placed += 1
				moved = true
				break
			if placed >= n: break
		if not moved:
			for i in n:
				if owner[i] < 0:
					owner[i] = ri(0, NN - 1)
					placed += 1
	# 領地
	var terrain = assignTerrain(sites)
	for sd in seeds:
		if TERRAIN[terrain[sd]].slow: terrain[sd] = "plain"
	var usedC = {}
	var usedF = {}
	var terrs = []
	for i in n:
		var border = false
		for j in nb[i]:
			if owner[j] != owner[i]: border = true
		var isCap = seeds.has(i)
		var rough: bool = terrain[i] == "mount" or terrain[i] == "hill"
		var fort: bool = not isCap and randf() < (0.55 if border else 0.20) + (0.15 if rough else 0.0)
		var nm: String = uniqName(usedF, func(): return pick(FA) + pick(FB) + "砦") if fort else uniqName(usedC, func(): return pick(CA) + pick(CB))
		var segs = []
		for sg in outlines[i]: segs.append(PackedVector2Array(sg))
		terrs.append(_newTerr(i, sites[i], segs, owner[i], isCap, "fort" if fort else "city", nm, 3 if isCap else ri(1, 2), terrain[i]))
	for t in terrs:
		t.pop = int(round((CFG.popCity if t.type == "city" else CFG.popFort) * t.dev * 0.7 * terrOf(t).pop))
		if randf() < TRAIT_RATE:
			var keys = []
			for k in TRAIT_KEYS:
				if not (TRAIT[k].get("city", false) and t.type != "city"): keys.append(k)
			t.trait = pick(keys)
	# 地形障壁（険しい山脈は越えられない）
	var bars = []
	for a in n:
		for b in nb[a]:
			if a >= b: continue
			var mt: bool = terrain[a] == "mount" or terrain[b] == "mount" or (terrain[a] == "hill" and terrain[b] == "hill")
			var kind = "mtn" if mt or randf() < 0.3 else "river"
			var line = borders.get(bkey(pick0[a], pick0[b]))
			if line == null: continue
			bars.append({"a": a, "b": b, "kind": kind, "pts": PackedVector2Array(line)})
	# 開始時は首都の周りだけを治め、残りは無主の地
	var blocked = {}
	for b in bars:
		if b.kind == "mtn": blocked[bkey(b.a, b.b)] = true
	var rn = []
	for i in n:
		var l = []
		for j in nb[i]:
			if not blocked.has(bkey(i, j)): l.append(j)
		rn.append(l)
	for k in NN:
		var keepN: int = FRONT.startTerr if FRONT.startTerr > 0 else max(4, int(round(float(N) / NN * 0.15)))
		var seen = {seeds[k]: true}
		var q = [seeds[k]]
		var i = 0
		while i < q.size() and seen.size() < keepN:
			var nx = []
			for j in rn[q[i]]:
				if terrs[j].owner == k and not seen.has(j): nx.append(j)
			var sp: Vector2 = sites[seeds[k]]
			nx.sort_custom(func(x, y): return sites[x].distance_squared_to(sp) < sites[y].distance_squared_to(sp))
			for j in nx:
				if seen.size() >= keepN: break
				seen[j] = true
				q.append(j)
			i += 1
		for t in terrs:
			if t.owner == k and not seen.has(t.id):
				t.owner = -1
				t.dev = 1
				t.bld = []
				t.pop = int(round((CFG.popCity if t.type == "city" else CFG.popFort) * 0.7 * FRONT.wildPop * terrOf(t).pop))
	# 国家
	var usedN = {}
	var nations = []
	var pk = shuffled(["aggr", "def", "econ", "bal"])
	for k in NN:
		nations.append(_newNation(k, uniqName(usedN, func(): return pick(NA) + pick(NB) + pick(NC)), NCOL[k], seeds[k], pk[k % 4]))
	# つながり：隣り合う領地はどこへでも（険しい山脈だけは越えられない）。インフラは首都と大きな町ほど高い
	var edges = []
	for a in n:
		for b in nb[a]:
			if a < b and not blocked.has(bkey(a, b)):
				edges.append({"a": a, "b": b, "lv": 3, "pend": false, "cx": 0.0, "cy": 0.0})
	var capN = {}
	for e in edges:
		if terrs[e.a].cap: capN[e.b] = true
		if terrs[e.b].cap: capN[e.a] = true
	for t in terrs:
		t.infra = 3 if t.cap else (2 if capN.has(t.id) or (t.type == "city" and t.dev >= 3) else 1)
	# 陸地に合わせて地図の広さを詰める
	var x0 = INF
	var y0 = INF
	var x1 = -INF
	var y1 = -INF
	for t in terrs:
		for sg in t.segs:
			for p in sg:
				x0 = min(x0, p.x); x1 = max(x1, p.x); y0 = min(y0, p.y); y1 = max(y1, p.y)
	var M2 = 130.0
	var off = Vector2(M2 - x0, M2 - y0)
	for t in terrs:
		t.x += off.x
		t.y += off.y
		var ns = []
		for sg in t.segs:
			var q = PackedVector2Array()
			for p in sg: q.append(p + off)
			ns.append(q)
		t.segs = ns
	for b in bars:
		var q = PackedVector2Array()
		for p in b.pts: q.append(p + off)
		b.pts = q
	W = round(x1 - x0 + M2 * 2)
	H = round(y1 - y0 + M2 * 2)
	var g = {"turn": 1, "size": size, "W": W, "H": H, "terrs": terrs, "edges": edges, "bars": bars, "nations": nations,
		"nb": nb, "gid": 1, "log": [], "over": null, "chron": [], "hist": [], "observer": true, "supply": null}
	_finishNations(g)
	return g

## 日本地図：元の JS で作った初期状態（4種類）から1つ選び、国の性格などはここで振り直す
## 日本地図の初期状態のファイル（ブラウザ版は書き出しに含めず、使う時に取ってきて user:// に置く）
var NEXT_JP_MAP = -1
func jpMapPath(i: int) -> String:
	var r = "res://data/jp/map%d.bin" % i
	if FileAccess.file_exists(r) and OS.get_environment("KN_FAKEWEB") == "": return r
	return "user://jpmap%d.bin" % i
func genJapan(which := -1) -> Dictionary:
	if which < 0: which = NEXT_JP_MAP if NEXT_JP_MAP >= 0 else randi() % 4
	NEXT_JP_MAP = -1
	var f = FileAccess.open_compressed(jpMapPath(which), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var m: Dictionary = f.get_var()
	f.close()
	var terrs: Array = m.terrs
	for t in terrs:
		t.devP = false
		t.bld = []
		t.chaos = 0
		t.siege = null
		if not t.has("trait"): t.trait = null
		t.link = 1
		t.sec = CFG.secStart
	var cols = []
	for n in m.nat: cols.append(n.color)
	resetColors(cols)
	var NN: int = m.nat.size()
	var pk = []
	for i in NN: pk.append(["aggr", "def", "econ", "bal"][i % 4])
	pk.shuffle()
	var nations = []
	for k in NN:
		nations.append(_newNation(k, m.nat[k].name, m.nat[k].color, m.nat[k].capital, pk[k]))
	var g = {"turn": 1, "size": "japan", "W": m.W, "H": m.H, "terrs": terrs, "edges": m.edges, "bars": [], "nations": nations,
		"nb": m.nb, "gid": 1, "log": [], "over": null, "chron": [], "hist": [], "observer": true, "supply": null,
		"geo": m.geo, "jpMap": which}
	_finishNations(g)
	return g

# ---------- 領地の形の道具 ----------
func terrBounds(t: Dictionary) -> Rect2:
	if t.has("bb"): return t.bb
	var x0 = INF
	var y0 = INF
	var x1 = -INF
	var y1 = -INF
	for sg in t.segs:
		for p in sg:
			x0 = min(x0, p.x); x1 = max(x1, p.x); y0 = min(y0, p.y); y1 = max(y1, p.y)
	t.bb = Rect2(x0, y0, x1 - x0, y1 - y0)
	return t.bb
## 各辺がどの領地と接しているか（端点が一致する辺は同じ境）
var SEGN_DONE = null
func segNbrs() -> void:
	if SEGN_DONE == G: return
	var m = {}
	for t in G.terrs:
		if t.has("sn") and t.sn.size() == t.segs.size():
			t.segN = Array(t.sn)
			continue
		var sn = []
		sn.resize(t.segs.size())
		sn.fill(-1)
		t.segN = sn
		for i in t.segs.size():
			var sg: PackedVector2Array = t.segs[i]
			var a = "%d,%d" % [round(sg[0].x), round(sg[0].y)]
			var b = "%d,%d" % [round(sg[-1].x), round(sg[-1].y)]
			var k = (a + "|" + b) if a < b else (b + "|" + a)
			if not m.has(k): m[k] = []
			m[k].append([t, i])
	for arr in m.values():
		if arr.size() != 2: continue
		arr[0][0].segN[arr[0][1]] = arr[1][0].id
		arr[1][0].segN[arr[1][1]] = arr[0][0].id
	SEGN_DONE = G

# ==================== k2_rules.gd ====================
# 参照・経路・補給・国力（元 1443〜1600）／軍団・戦闘・占領（元 3554〜4046）

var NBR = null
var NBR_G = null
func buildNbrs() -> void:
	NBR = []
	NBR.resize(G.terrs.size())
	for i in NBR.size(): NBR[i] = []
	for e in G.edges:
		NBR[e.a].append({"to": e.b, "e": e})
		NBR[e.b].append({"to": e.a, "e": e})
	NBR_G = G
func roadNbrs(id: int) -> Array:
	if NBR_G != G or NBR == null: buildNbrs()
	return NBR[id] if id >= 0 and id < NBR.size() else []
func edgeBetween(a: int, b: int):
	for n in roadNbrs(a):
		if n.to == b: return n.e
	return null
func ownRoad(e: Dictionary, nid := 0) -> bool: return T(e.a).owner == nid or T(e.b).owner == nid

## 隣の領地へ入るのにかかるターン数
func stepCost(tid: int, e) -> int:
	var t = T(tid)
	var c: int = TERR_COST.get(t.terrain, 1) - (int(t.get("infra", 1)) - 1)
	if c < 1: c = 1
	if e != null and e.get("sea", false) and c < 2: c = 2
	if e != null and e.get("river", false) and int(t.get("infra", 1)) < 3: c += 1
	return c
func infraChanged(t: Dictionary) -> void:
	invalidateTerr(t.id)
	G.roadRev = G.get("roadRev", 0) + 1
	invalidateSupply()

func armyStats(a: Dictionary) -> Dictionary:
	var na = NAT(a.owner)
	var g = genOf(na, a.gen) if a.gen != null else null
	var tot = 0.0; var atk = 0.0; var def = 0.0; var chg = 0.0
	for k in TK:
		var c: float = a.t[k]
		if c == 0: continue
		var tm: float = 1.0 + 0.08 * g.pts[k] if g != null else 1.0
		tot += c; atk += c * TROOP[k].atk * tm; def += c * TROOP[k].def * tm; chg += c * TROOP[k].chg
	if tot == 0: return {"tot": 0.0, "atk": 0.0, "def": 0.0, "chg": 0.0}
	atk /= tot; def /= tot; chg /= tot
	if g != null:
		atk *= 1 + 0.05 * g.pts.atk; def *= 1 + 0.05 * g.pts.def; chg += 0.03 * g.pts.chg
	if a.get("sup", true) == false:
		var m: float = 1 - CFG.supplyPenalty
		atk *= m; def *= m
	if na.get("revoltBuff", 0) > 0:
		atk *= 1 + DIP.revoltAtk; def *= 1 + DIP.revoltDef; chg += DIP.revoltChg
	atk *= 1 + nmod(a.owner, "atk") + (0.05 if na.get("eqMul", 1.0) >= 0.99 and na.get("eq", 0) > 6000 else 0.0)
	def *= 1 + nmod(a.owner, "def")
	chg += nmod(a.owner, "chg")
	# 組織率・将軍の特性・この戦いの空と海（bmod）
	var om = orgMul(a)
	var gtm = genTraitMods(a, T(a.at))
	var bm: float = a.get("bmod", 0.0)
	atk *= om * (1.0 + gtm.atk + bm)
	def *= om * (1.0 + gtm.def + bm)
	chg += gtm.chg
	return {"tot": tot, "atk": atk, "def": def, "chg": min(0.5, chg)}
func fortMul(t: Dictionary) -> float:
	var m: float = 1 + CFG.fortBase + FORT_DEV_DEF[t.dev] if t.type == "fort" else 1.0
	if t.get("trait") == "mount": m += 0.15
	m += terrOf(t).def
	if t.type == "fort": m += nmod(t.owner, "fort")
	# 本土（ゲーム開始時からの自国の領地）を守る時は防御 +25%（HOI4 の中核州のように、一気に滅ぶのを防ぐ）
	if t.owner >= 0 and t.get("home", -1) == t.owner: m += 0.25
	return max(0.5, m)

## 経路探索の下ごしらえ：隣の番号・入るのにかかるターン・持ち主を詰めた配列（地図・インフラ・持ち主が変わったら作り直す）
var PF_G = null
var PF_KEY = ""
var PF_TO = []          # 領地ごとの PackedInt32Array（隣の領地）
var PF_EF = []          # 同じ並びの辺の印（1=海峡 2=川）
var PF_COST = PackedInt32Array()
var PF_INF3 = PackedByteArray()
var PF_OWN = PackedInt32Array()
var PF_OWN_KEY = -1
func _pfPrep() -> void:
	var key = str(G.edges.size()) + "_" + str(G.get("roadRev", 0))
	if PF_G != G or PF_KEY != key:
		var n: int = G.terrs.size()
		var to = []
		var ef = []
		for i in n:
			to.append(PackedInt32Array())
			ef.append(PackedInt32Array())
		for e in G.edges:
			var f = (1 if e.get("sea", false) else 0) | (2 if e.get("river", false) else 0)
			to[e.a].append(e.b); ef[e.a].append(f)
			to[e.b].append(e.a); ef[e.b].append(f)
		PF_TO = to
		PF_EF = ef
		PF_COST.resize(n)
		PF_INF3.resize(n)
		for t in G.terrs:
			var inf: int = int(t.get("infra", 1))
			PF_COST[t.id] = max(1, TERR_COST.get(t.terrain, 1) - (inf - 1))
			PF_INF3[t.id] = 1 if inf >= 3 else 0
		PF_G = G
		PF_KEY = key
		PF_OWN_KEY = -1
	var ok: int = G.get("ownRev", 0)
	if PF_OWN_KEY != ok or PF_OWN.size() != G.terrs.size():
		PF_OWN.resize(G.terrs.size())
		for t in G.terrs: PF_OWN[t.id] = t.owner
		PF_OWN_KEY = ok
## 経路探索：かかるターン数が最短の道（重みが小さな整数なので、ターン数ごとの箱で順に広げる）
## 返り値 d[領地]＝かかるターン（届かなければ -1）、prev＝ひとつ前、n＝届く領地の数
func bfsFrom(start: int, _size = null, nid = null, maxD := 1 << 30) -> Dictionary:
	_pfPrep()
	var n: int = G.terrs.size()
	var dist = PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var prev = PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	dist[start] = 0
	var reach = 1
	var bk = [PackedInt32Array([start])]
	var free: bool = nid == null or nid < 0
	var enter = PackedInt32Array()
	if not free:
		enter.resize(G.nations.size() + 1)
		enter.fill(-1)
	var d = 0
	while d < bk.size():
		var B: PackedInt32Array = bk[d]
		var i = 0
		while i < B.size():
			var u: int = B[i]
			i += 1
			if dist[u] != d: continue
			var tos: PackedInt32Array = PF_TO[u]
			var efs: PackedInt32Array = PF_EF[u]
			for j in tos.size():
				var to: int = tos[j]
				if not free:
					var o: int = PF_OWN[to]
					var ok: int = enter[o + 1]
					if ok < 0:
						ok = 1 if canEnter(nid, to) else 0
						enter[o + 1] = ok
					if ok == 0: continue
				var c: int = PF_COST[to]
				var f: int = efs[j]
				if f & 1 and c < 2: c = 2
				if f & 2 and PF_INF3[to] == 0: c += 1
				var nd: int = d + c
				if nd > maxD: continue
				var od: int = dist[to]
				if od >= 0 and od <= nd: continue
				if od < 0: reach += 1
				dist[to] = nd
				prev[to] = u
				while bk.size() <= nd: bk.append(PackedInt32Array())
				bk[nd].append(to)
		d += 1
	return {"d": dist, "prev": prev, "start": start, "n": reach}
## 届くならターン数、届かなければ null
func bget(b: Dictionary, id: int):
	var v: int = b.d[id]
	return v if v >= 0 else null
func bhas(b: Dictionary, id: int) -> bool: return b.d[id] >= 0
func pathFrom(b: Dictionary, to: int):
	if b.d[to] < 0: return null
	var p = []
	var c = to
	while c != b.start:
		p.push_front(c)
		c = b.prev[c]
	return p
func findPath(from: int, to: int, size = null, nid = null):
	if from == to: return []
	return pathFrom(bfsFrom(from, size, nid), to)

# ---------- 補給線（自国領を伝って首都と繋がっているか） ----------
var SUP_DIRTY = true
var SUP_TERR_KEY = ""
func invalidateSupply() -> void: SUP_DIRTY = true
func _armySup(a: Dictionary, set: Dictionary) -> bool:
	if set.is_empty(): return false
	if set.has(a.at): return true
	for n in roadNbrs(a.at):
		if set.has(n.to): return true
	return false
func refreshSupply(force := false) -> void:
	if G == null: return
	if not force and not SUP_DIRTY: return
	SUP_DIRTY = false
	var caps = []
	for n in G.nations: caps.append(n.capital if n.alive else -1)
	var key = "%d_%d_%s" % [G.get("ownRev", 0), G.get("roadRev", 0), caps]
	var allSets = true
	for na in G.nations:
		if not (na.get("supSet") is Dictionary): allSets = false
	if not force and key == SUP_TERR_KEY and allSets:
		for na in G.nations:
			for a in na.armies:
				if a != null: a.sup = _armySup(a, na.supSet)
		return
	SUP_TERR_KEY = key
	for t in G.terrs: t.link = 0
	for na in G.nations:
		var set = {}
		if na.alive and T(na.capital).owner == na.id:
			set[na.capital] = true
			var q = [na.capital]
			var i = 0
			while i < q.size():
				for n in roadNbrs(q[i]):
					if not set.has(n.to) and T(n.to).owner == na.id:
						set[n.to] = true
						q.append(n.to)
				i += 1
		na.supSet = set
		for tid in set: T(tid).link = T(tid).get("infra", 1)
		for a in na.armies:
			if a != null: a.sup = _armySup(a, set)

# ---------- 国力の目安 ----------
var PW_CACHE = {}
var PW_KEY = -1
var PW_G = null
## 鍵は整数（文字列を毎回作ると重い）
func powKey() -> int: return G.turn * 1000000 + int(G.get("ownRev", 0))
## 戦略の見積もり（隣り合い・距離・脅威・危険度）の鍵：ターンの区切りごとに1回だけ作り直す（占領のたびには作り直さない。国が滅んだ時は作り直す）
var STRAT_REV = 0
var _sbOwn = -1
var _sbTurn = -1
func stratBump() -> void:
	var o: int = int(G.get("ownRev", 0))
	if o == _sbOwn and G.turn == _sbTurn: return
	_sbOwn = o
	_sbTurn = G.turn
	STRAT_REV += 1
## 国力：鍵（ターン・持ち主の変化）が変わったら、全領地を1回だけなめて全部の国をまとめて計算する
var OWN_N = {}
var OWN_L = {}
var NO_OWNL: bool = OS.get_environment("KN_NOOWNL") != ""
func _powAll() -> void:
	OWN_L = {}
	PW_CACHE = {}
	OWN_N = {}
	PW_KEY = powKey()
	PW_G = G
	var acc = {}
	for t in G.terrs:
		var o: int = t.owner
		if o < 0: continue
		if not OWN_L.has(o): OWN_L[o] = []
		OWN_L[o].append(t)
		var nb = 0
		for b in t.bld:
			if b: nb += 1
		acc[o] = acc.get(o, 0.0) + t.dev * (120 if t.type == "city" else 80) + nb * 60 + t.pop * 0.006
		OWN_N[o] = OWN_N.get(o, 0) + 1
	for na in G.nations:
		PW_CACHE[na.id] = round(acc.get(na.id, 0.0) + nationTroops(na.id) * 0.6 + na.gold * 0.05)
func nationPower(nid: int) -> float:
	if PW_KEY != powKey() or PW_G != G: _powAll()
	if PW_CACHE.has(nid): return PW_CACHE[nid]
	var v = nationPowerCalc(nid)
	PW_CACHE[nid] = v
	return v
## 自国の領地の一覧（全領地の並び順のまま。持ち主が変わると作り直す）
func ownList(nid: int) -> Array:
	if NO_OWNL:
		var r = []
		for t in G.terrs:
			if t.owner == nid: r.append(t)
		return r
	if PW_KEY != powKey() or PW_G != G: _powAll()
	return OWN_L.get(nid, [])
## 領地の数（国力と同じ鍵で覚えておく）
func ownCount(nid: int) -> int:
	if PW_KEY != powKey() or PW_G != G: _powAll()
	return OWN_N.get(nid, 0)
func nationPowerCalc(nid: int) -> float:
	var p = 0.0
	for t in ownList(nid):
		var nb = 0
		for b in t.bld:
			if b: nb += 1
		p += t.dev * (120 if t.type == "city" else 80) + nb * 60 + t.pop * 0.006
	p += nationTroops(nid) * 0.6
	p += NAT(nid).gold * 0.05
	return round(p)
func nationTroops(nid: int) -> int:
	var na = NAT(nid)
	var s = total(na.stock)
	for a in na.armies:
		if a != null: s += total(a.t)
	return s

# ---------- 軍団編成・将軍 ----------
func reinforce(a: Dictionary) -> void:
	var p = NAT(a.owner)
	if T(a.at).owner != a.owner: return
	for k in TK:
		var need: int = max(0, a.target[k] - a.t[k])
		var give: int = min(need, p.stock[k])
		a.t[k] += give
		p.stock[k] -= give
func genDesc(g: Dictionary) -> String:
	var s = []
	if g.pts.atk: s.append("攻+%d%%" % (g.pts.atk * 5))
	if g.pts.def: s.append("防+%d%%" % (g.pts.def * 5))
	if g.pts.chg: s.append("突+%d%%" % (g.pts.chg * 3))
	for k in TK:
		if g.pts[k]: s.append(TROOP[k].n + "+%d%%" % (g.pts[k] * 8))
	return " ".join(s) if s.size() else "—"
func randomPts() -> Dictionary:
	var p = {"atk": 0, "def": 0, "chg": 0, "inf": 0, "spe": 0, "arc": 0, "cav": 0}
	for i in 3: p[pick(GEN_ABIL).k] += 1
	return p
func mkGen(g: Dictionary, na: Dictionary, pts: Dictionary) -> Dictionary:
	var gen = {"id": g.gid, "name": pick(GN_A) + pick(GN_B), "pts": pts, "army": null, "maxLed": 0}
	g.gid += 1
	na.gens.append(gen)
	return gen
func mkArmy(owner: int, idx: int, at: int) -> Dictionary:
	return {"owner": owner, "idx": idx, "name": "第%d軍団" % (idx + 1), "at": at, "gen": null,
		"t": {"inf": 0, "spe": 0, "arc": 0, "cav": 0}, "target": {"inf": 0, "spe": 0, "arc": 0, "cav": 0},
		"path": [], "moved": false, "join": true, "wins": 0, "sup": true, "siege": null}

# ============================================================
#   進軍・戦闘・占領
# ============================================================
func _aliveFoes(tid: int, nid: int) -> Array:
	var r = []
	for x in armiesAt(tid):
		if total(x.t) > 0 and atWar(x.owner, nid): r.append(x)
	return r
func advanceArmy(a: Dictionary) -> void:
	if a.moved or a.path.is_empty() or total(a.t) <= 0: return
	var next: int = a.path[0]
	var e = edgeBetween(a.at, next)
	var from: int = a.at
	if e == null:
		a.path = []
		return
	var t = T(next)
	if not canEnter(a.owner, next):
		a.path = []
		return
	a.moved = true
	if a.get("prog") != next:
		a.prog = next
		a.progN = 0
	a.progN = a.get("progN", 0) + 1
	var need = stepCost(next, e)
	if a.progN < need: return
	a.prog = null
	a.progN = 0
	if not canOccupy(a.owner, next):       # 自国領・通行許可のある領地を通過する
		var foes = _aliveFoes(next, a.owner)
		if foes.size():
			if powerOf([a], t, false) < powerOf(foes, t, true) * 0.9:
				a.path = []
				return
			var r = await runBattle([a], foes, t)
			invalidateSupply()
			if r != "A":
				a.path = []
				return
		a.at = next; ARMY_REV += 1
		a.path.pop_front()
		animMove(a, from)
		invalidateSupply()
		return
	var def = _aliveFoes(next, a.owner)
	if def.is_empty():
		capture(next, a.owner, a)
		a.at = next; ARMY_REV += 1
		a.path.pop_front()
		animMove(a, from)
		return
	if t.type == "fort":
		var mode = cpuSiegeChoice(a, t, def)
		if mode == "siege":
			startSiege(a, t, from)
			return
		UI.assault = true
	var mates = joinCandidates(a, from, next, e)
	if mates.size(): mates = cpuJoiners(a, mates, def, t)
	var force = [a] + mates
	if powerOf(force, t, false) < powerOf(def, t, true) * 0.9:
		UI.assault = false
		a.path = []
		return
	for m in mates:
		m.moved = true
		m.path = []
	var res = await runBattle(force, def, t)
	UI.assault = false
	var alive = []
	for x in force:
		if total(x.t) > 0: alive.append(x)
	if res == "A":
		capture(next, a.owner, a)
		for x in alive:
			var f2: int = x.at
			x.at = next; ARMY_REV += 1
			animMove(x, f2)
		if a.path.size(): a.path.pop_front()
	else:
		a.path = []
	invalidateSupply()

# ---------- 攻城戦 ----------
func startSiege(a: Dictionary, t: Dictionary, from: int) -> void:
	for x in armiesAt(from):
		if x.owner == a.owner and total(x.t) > 0 and (x == a or not x.moved):
			x.moved = true
			x.path = []
			x.siege = t.id
	t.siege = {"by": a.owner, "t0": G.turn}
	a.path = []
	var msg = "%s が %s を包囲した（%dターンで陥落）" % [NAT(a.owner).name, t.name, CFG.siegeTurns]
	logWar(msg, [a.owner, t.owner], "war")
	chron(msg, a.owner, "fall")
	map_changed.emit("fx", null)
func siegeArmies(t: Dictionary) -> Array:
	if t.get("siege") == null: return []
	var out = []
	for n in roadNbrs(t.id):
		for x in armiesAt(n.to):
			if x.owner == t.siege.by and x.get("siege") == t.id and total(x.t) > 0: out.append(x)
	return out
func siegeTurn() -> void:
	for t in G.terrs:
		if t.get("siege") == null: continue
		var by: int = t.siege.by
		if by < 0 or not NAT(by).alive or not atWar(by, t.owner):
			liftSiege(t, "戦いが終わった")
			continue
		var force = siegeArmies(t)
		if force.is_empty():
			liftSiege(t, "包囲軍が去った")
			continue
		var gar = []
		for x in armiesAt(t.id):
			if total(x.t) > 0: gar.append(x)
		for g in gar:
			for k in TK: g.t[k] = max(0, int(round(g.t[k] * (1 - CFG.siegeBleed))))
		t.sec = clamp_f(t.sec - CFG.siegeSec, 0, 100)
		var tot = 0
		for x in force: tot += total(x.t)
		NAT(by).food -= int(round(tot / 1000.0 * CFG.siegeFood))
		destroyDead(gar)
		var left = []
		for x in armiesAt(t.id):
			if total(x.t) > 0: left.append(x)
		var over: bool = (G.turn - t.siege.t0) >= CFG.siegeTurns - 1
		if left.is_empty() or over:
			var lead = force[0]
			var old: int = t.owner
			capture(t.id, by, lead)
			for x in left:
				for k in TK: x.t[k] = 0
			destroyDead(left)
			lead.at = t.id; ARMY_REV += 1
			for x in force: x.siege = null
			t.siege = null
			var msg = "%s が包囲の末に陥落（%s → %s）" % [t.name, NAT(old).name, NAT(by).name]
			logWar(msg, [old, by], "war")
			chron(msg, by, "fall")
			invalidateSupply()
func liftSiege(t: Dictionary, why: String) -> void:
	if t.get("siege") == null: return
	for na in G.nations:
		for x in na.armies:
			if x != null and x.get("siege") == t.id: x.siege = null
	var msg = "%s の包囲が解かれた（%s）" % [t.name, why]
	logWar(msg, [t.owner, t.siege.by])
	chron(msg, t.owner, "gov")
	t.siege = null
func cpuSiegeChoice(a: Dictionary, t: Dictionary, def: Array) -> String:
	var list = [a]
	for x in armiesAt(a.at):
		if x != a and x.owner == a.owner and not x.moved: list.append(x)
	var mine = powerOf(list, t, false)
	var dp = powerOf(def, t, true)
	if mine >= dp * 1.6: return "assault"
	if NAT(a.owner).food < 1500: return "assault"
	return "siege"
func joinCandidates(a: Dictionary, from: int, _next: int, _e) -> Array:
	var list = []
	for x in armiesAt(from):
		if x == a or x.owner != a.owner or x.moved or total(x.t) <= 0: continue
		list.append(x)
	return list
func cpuJoiners(a: Dictionary, mates: Array, defs: Array, t: Dictionary) -> Array:
	var need = powerOf(defs, t, true) * 1.15
	var out = []
	var mine = powerOf([a], t, false)
	for m in mates:
		if mine >= need: break
		out.append(m)
		mine = powerOf([a] + out, t, false)
	return out

# ---------- 占領 ----------
func capture(tid: int, nid: int, _byArmy = null) -> void:
	var t = T(tid)
	var old: int = t.owner
	if old == nid: return
	_ownMove(t, old, nid)
	var nm: String = NAT(nid).name
	var on: String = NAT(old).name if old >= 0 else "無主の地"
	logWar("%s が %s を占領しました（旧領主 %s）" % [nm, t.name, on], [nid, old], "good" if nid == followNat() else "war")
	t.chaos = CFG.chaosTurns
	t.sec = min(t.sec, CFG.secCapture)
	t.pop = int(round(t.pop * 0.85))
	if old >= 0:
		addFatigue(old, CFG.fatTerr)
		addFavor(old, nid, DIP.captureFavor)
	addThreat(nid, DIP.threatCapture)
	if old >= 0: grantCB(old, nid, "%s の奪還" % t.name, CASUS.lostTurns)
	if old >= 0:
		t.former = old
		t.formerAt = G.turn
		if t.cap: t.wasCap = old
		# 首都の陥落は大きな見出しに
		if t.cap and t.id == NAT(old).get("capital", -1) and newsworthy([old, nid]):
			headline("%s の首都 %s 陥落" % [natLabel(old), t.name], "%s 軍が入城する" % natLabel(nid))
	if old >= 0 and atWar(nid, old) and warOf(nid, old):
		var wid = warOf(nid, old)
		if t.get("wTag") != wid:
			t.wTag = wid
			t.wOrig = old
		if t.get("wOrig") == nid:
			t.erase("wTag")
			t.erase("wOrig")
	if old >= 0 and atWar(nid, old):
		addWarScore(nid, old, WAR.scoreTerr + (WAR.scoreCapital if t.cap else 0))
		G.dip.taken[nid][old] = G.dip.taken[nid][old] + 1
	chron("%s 陥落 — %s が %s より奪取" % [t.name, nm, on], nid, "fall")
	captured.emit(tid, nid, old)
	invalidateTerr(tid)
	flashTerr(tid)
	if t.cap and old >= 0:
		chron("%s の首都 %s が落ちる" % [on, t.name], old, "fall")
		t.cap = false
		var rest = []
		for x in G.terrs:
			if x.owner == old and x.type == "city": rest.append(x)
		if rest.is_empty():
			for x in G.terrs:
				if x.owner == old: rest.append(x)
		if rest.size():
			rest.sort_custom(func(x, y): return x.dev > y.dev)
			var best = rest[0]
			best.cap = true
			NAT(old).capital = best.id
			logMsg("%s は首都を %s へ移しました" % [on, best.name])
			chron("%s が首都を %s へ遷す" % [on, best.name], old, "gov")
	invalidateSupply()
	checkNations()
func setCapital(nid: int, tid: int) -> void:
	var na = NAT(nid)
	for t in G.terrs:
		if t.owner == nid and t.cap:
			t.cap = false
			invalidateTerr(t.id)
	T(tid).cap = true
	na.capital = tid
	invalidateTerr(tid)
	logMsg("%s の首都を %s に定めました" % [na.name, T(tid).name])
func checkNations() -> void:
	var all: int = G.terrs.size()
	var cnt = {}
	for t in G.terrs: cnt[t.owner] = cnt.get(t.owner, 0) + 1
	for na in G.nations:
		if not na.alive: continue
		if cnt.get(na.id, 0) == 0:
			na.alive = false
			STRAT_REV += 1
			for i in na.armies.size(): na.armies[i] = null; ARMY_REV += 1
			na.lord = null
			na.diedAt = G.turn
			na.rebel = 0
			if facOf(na.id) != null: leaveFaction(na.id, "quiet")
			logMsg("%s は滅亡しました" % na.name, "war")
			chron("%s 滅亡" % na.name, na.id, "end")
			nation_fell.emit(na.id)
			headline("%s 滅亡" % natLabel(na.id), "")
			for v in G.nations:
				if v.alive and v.lord == na.id: freeVassal(v.id, "主君の滅亡")
	warSuccession()
	for na in G.nations:
		if not na.alive or lordOf(na.id) != null: continue
		var side = [na.id] + vassalsOf(na.id)
		var ok = true
		var n = 0
		for t in G.terrs:
			if t.owner >= 0 and not side.has(t.owner):
				ok = false
				break
			if side.has(t.owner): n += 1
		if ok and n >= all * 0.5:
			endGame(na.id)
			return
func endGame(winner: int) -> void:
	if G.over != null: return
	G.over = "end"
	G.winner = winner
	if vassalsOf(winner).size():
		chron("%s が属国とともに全土を平定し、天下を統一した" % NAT(winner).name, winner, "end")
	else:
		chron("%s が全領地を制覇し、天下を統一した" % NAT(winner).name, winner, "end")
	UI.auto = false
	game_over.emit(winner)
signal game_over(winner: int)
signal captured(tid: int, nid: int, old: int)
signal nation_fell(nid: int)

# ---------- 戦闘計算 ----------
func sideStats(list: Array, t: Dictionary, isDef: bool) -> Dictionary:
	var tot = 0.0; var atk = 0.0; var def = 0.0; var chg = 0.0
	for a in list:
		var s = armyStats(a)
		tot += s.tot; atk += s.atk * s.tot; def += s.def * s.tot; chg += s.chg * s.tot
	if tot == 0: return {"tot": 0.0, "atk": 0.0, "def": 0.0, "chg": 0.0}
	atk /= tot; def /= tot; chg /= tot
	if isDef: def *= fortMul(t)
	return {"tot": tot, "atk": atk, "def": def, "chg": chg}
func sumTroops(list: Array) -> float:
	var s = 0.0
	for a in list: s += a.t.inf + a.t.spe + a.t.arc + a.t.cav
	return s
func applyLoss(list: Array, amount: float) -> void:
	var tot = sumTroops(list)
	if tot <= 0: return
	amount = min(amount, tot)
	for a in list:
		var at: float = a.t.inf + a.t.spe + a.t.arc + a.t.cav
		if at <= 0: continue
		var share = amount * at / tot
		for k in TK:
			if not a.t[k]: continue
			a.t[k] = max(0.0, a.t[k] - share * (a.t[k] / at))
func battleTick(A: Array, D: Array, t: Dictionary):
	var sa = sideStats(A, t, false)
	var sd = sideStats(D, t, true)
	if not sa.tot or not sd.tot: return null
	var ca = randf() < sa.chg
	var cd = randf() < sd.chg
	var n: float = CFG.sizeExp
	var m = 1 - n
	var powA = pow(sa.tot, n) * pow(sd.tot, m)
	var powD = pow(sd.tot, n) * pow(sa.tot, m)
	var dToD: float = powA * CFG.dmgK * (sa.atk / (sd.def * (1 - CFG.chargeIgnore if ca else 1.0))) + CFG.minDmg
	var dToA: float = powD * CFG.dmgK * (sd.atk / (sa.def * (1 - CFG.chargeIgnore if cd else 1.0))) + CFG.minDmg
	var am: float = CFG.assaultLoss if UI.get("assault", false) else 1.0
	applyLoss(D, dToD)
	applyLoss(A, dToA * am)
	return {"ca": ca, "cd": cd, "dToD": dToD, "dToA": dToA * am, "sa": sa, "sd": sd}
func recordBattle(A: Array, D: Array, res: String) -> void:
	orgAfterBattle(A, D, res)
	var bt = T(D[0].at) if D.size() and D[0] != null else (T(A[0].at) if A.size() and A[0] != null else null)
	if bt != null: genAfterBattle(A, D, res, bt)
	for x in A + D:
		if x != null: x.erase("bmod")
	var win = A if res == "A" else D
	var lose = D if res == "A" else A
	if win.size(): NAT(win[0].owner).wins += 1
	if lose.size():
		NAT(lose[0].owner).losses += 1
		addFatigue(lose[0].owner, CFG.fatLose)
	if win.size() and lose.size() and atWar(win[0].owner, lose[0].owner): addWarScore(win[0].owner, lose[0].owner, WAR.scoreBattle)
	for a in win:
		if total(a.t) > 0: a.wins = a.get("wins", 0) + 1
func tidy(list: Array) -> void:
	for a in list:
		for k in TK: a.t[k] = max(0, int(round(a.t[k])))
func destroyDead(list: Array) -> void:
	for a in list:
		if total(a.t) > 0: continue
		var na = NAT(a.owner)
		if na.armies[a.idx] != a: continue
		if a.gen != null:
			var g = genOf(na, a.gen)
			if g != null: g.army = null
		na.armies[a.idx] = null; ARMY_REV += 1
		if UI.selArmy == a: UI.selArmy = null
		logWar("%s %s は壊滅しました" % [na.name, a.name], [a.owner], "war")
		for o in G.nations:
			if o.alive and atWar(o.id, a.owner):
				for x in armiesAt(a.at):
					if x.owner == o.id:
						addWarScore(o.id, a.owner, WAR.scoreArmy)
						break
		chron("%s %s 壊滅（通算%d勝）" % [na.name, a.name, a.get("wins", 0)], a.owner, "war")
func fleeArmies(list: Array, _tid: int) -> void:
	for a in list:
		if total(a.t) <= 0: continue
		var opt = []
		for n in roadNbrs(a.at):
			if T(n.to).owner == a.owner: opt.append(n)
		if opt.size():
			a.at = pick(opt).to; ARMY_REV += 1
			a.path = []
		else:
			for k in TK: a.t[k] = 0

## CPU 同士（画面なし）
func autoBattle(A: Array, D: Array, t: Dictionary) -> String:
	for i in 8000:
		var r = battleTick(A, D, t)
		if r == null: break
		if sumTroops(A) <= 0 or sumTroops(D) <= 0: break
	tidy(A); tidy(D)
	var aw = sumTroops(A) > 0
	recordBattle(A, D, "A" if aw else "D")
	destroyDead(A); destroyDead(D)
	return "A" if aw else "D"

## 戦闘画面：観戦中は選んだ国の戦いだけ見せる（UI が battle_finish を呼ぶまで待つ）
signal battle_show(A: Array, D: Array, t: Dictionary)
signal battle_done(res: String)
var BATTLE_SPENT = 0
var BATTLE_N = 0
func runBattle(atts: Array, defs: Array, t: Dictionary):
	refreshSupply()
	var A = []
	for a in atts:
		if a != null and total(a.t) > 0: A.append(a)
	var lead = A[0]
	# 制空権（空軍力 1.5 倍で攻防 ±10%）と、海峡越しの攻めの制海権（無いと攻撃 -25%）
	if defs.size() and defs[0] != null:
		var ae = airEdge(lead.owner, defs[0].owner)
		var sp = seaEdgePenalty(lead.owner, defs[0].owner, lead.at, t.id)
		for x in A: x.bmod = ae + sp
		for x in defs:
			if x != null: x.bmod = -ae
	var watch: bool = CFG.showCpuBattle and UI.speed != 3 and (concerns([lead.owner, defs[0].owner]) or UI.get("watchAll", false)) and battle_show.get_connections().size() > 0
	# 自動進行中は、戦闘画面を見せる時間を1ターンあたりの上限で区切る（ターンが長く止まらないように）
	if watch and UI.get("auto", false) and BATTLE_SPENT + BEAT_SPENT + 1500 > BEAT_MAX: watch = false
	var _bt0 = Time.get_ticks_msec()
	if not watch or str(CFG.cpuStop) == "auto":
		var r = autoBattle(A, defs, t)
		logWar("%sの戦い：%s" % [t.name, (NAT(lead.owner).name + " が勝利") if r == "A" else (NAT(defs[0].owner).name + " が防衛")], [lead.owner, defs[0].owner], "war")
		return r
	UI.busy = true
	battle_show.emit(A, defs, t)
	var res = await battle_done
	BATTLE_SPENT += Time.get_ticks_msec() - _bt0
	BATTLE_N += 1
	UI.busy = false
	return res
## 戦闘画面の終わり（UI から呼ぶ）
func battleFinish(A: Array, D: Array, kind: String) -> String:
	tidy(A); tidy(D)
	var res: String
	if kind == "retA": res = "D"
	elif kind == "retD":
		fleeArmies(D, -1)
		res = "A"
	else: res = "A" if sumTroops(A) > 0 else "D"
	recordBattle(A, D, res)
	destroyDead(A); destroyDead(D)
	return res

# ---------- 演出（UI に知らせるだけ） ----------
func fxOff() -> bool: return CFG.cpuDelay <= 0
func animMove(a: Dictionary, from: int) -> void:
	if fxOff():
		a.anim = null
		return
	a.anim = {"from": from, "t0": Time.get_ticks_msec(), "dur": 470}
	fx.emit("move", [a, from])
func flashTerr(tid: int) -> void:
	if fxOff(): return
	fx.emit("flash", tid)
func invalidateTerr(tid: int) -> void: map_changed.emit("terr", tid)
func invalidateMap() -> void: map_changed.emit("all", null)

## 占領で持ち主が1つ変わる時：全領地をなめ直さず、2国の一覧・数・国力だけを直す（軽さのため）
## 一覧は作り直して入れ替える（ほかの所で一覧を回している最中でも壊れないように）
func _terrPow(t: Dictionary) -> float:
	var nb = 0
	for b in t.bld:
		if b: nb += 1
	return t.dev * (120 if t.type == "city" else 80) + nb * 60 + t.pop * 0.006
func _ownMove(t: Dictionary, old: int, nid: int) -> void:
	var valid: bool = PW_G == G and PW_KEY == powKey()
	t.owner = nid
	G.ownRev = G.get("ownRev", 0) + 1
	if not valid: return
	PW_KEY = powKey()
	var c = _terrPow(t)
	if old >= 0 and OWN_L.has(old):
		var l: Array = OWN_L[old].duplicate()
		l.erase(t)
		OWN_L[old] = l
		OWN_N[old] = OWN_N.get(old, 1) - 1
		if PW_CACHE.has(old): PW_CACHE[old] -= c
	if nid >= 0:
		var l2: Array = OWN_L.get(nid, []).duplicate()
		var i = l2.bsearch_custom(t, func(a, b): return a.id < b.id)
		l2.insert(i, t)
		OWN_L[nid] = l2
		OWN_N[nid] = OWN_N.get(nid, 0) + 1
		if PW_CACHE.has(nid): PW_CACHE[nid] += c

# ==================== k3_dip.gd ====================
# 外交（元 4048〜）：好感度・大義・通商・不可侵・従属・脅威・戦争と講和

var DIP = {
	"passMin": 60, "allyMin": 80, "peaceMin": 15,
	"giftCost": 5000, "giftFavor": 12, "giftCool": 3,
	"warFavor": -100, "warOthers": -26, "warAllyOthers": -8, "justMul": 0.35, "captureFavor": -6,
	"driftPeace": 0.5, "driftAlly": 1.2, "driftWar": -1.5, "driftCap": 62,
	"driftCommon": 1.6, "driftCommonCap": 95,
	"cpuWarChance": {"aggr": 0.28, "bal": 0.14, "def": 0.07, "econ": 0.05, "fascism": 0.32, "communism": 0.14, "neutral": 0.06, "democracy": 0.03},
	"cpuWarNeed": {"aggr": 40, "bal": 58, "def": 75, "econ": 85, "fascism": 35, "communism": 58, "neutral": 80, "democracy": 95},
	"cpuAmbition": 0.8, "cpuAmbitionMax": 30, "cpuPeaceTurns": 12,
	"allyTurns": 20, "allyRenewMin": 70, "peaceCool": 5, "reach": 2,
	"vassalRatio": 1.7, "vassalWarRatio": 1.3, "vassalFavor": 35, "tribute": 0.15,
	"unrestBase": 2.2, "unrestPower": 6, "unrestWar": 1.5, "unrestMax": 100,
	"revoltTurns": 15, "revoltFree": 20, "revoltAtk": 0.45, "revoltDef": 0.35, "revoltChg": 0.05, "revoltProd": 0.25,
	"cpuVassalAsk": 0.25,
	"annexRatio": 4.0, "annexHold": 30, "annexUnrest": 30, "absorbRate": 2, "annexEdge": 100, "annexThreat": 40,
	"annexOthers": -30, "annexTroop": 0.3, "annexGold": 0.5, "annexGens": 2, "cpuAnnexChance": 0.5,
	"aidCool": 3, "aidGold": 10000, "aidGoldFav": 10, "aidGoldUnrest": -14,
	"aidFood": 2000, "aidFoodFav": 8, "aidFoodUnrest": -10,
	"aidTroop": 3000, "aidTroopFav": 12, "aidTroopUnrest": -16,
	"threatWar": 34, "threatCapture": 9, "threatDecay": 0.94, "threatPowerW": 110, "threatMin": 35,
	"threatDrift": -1.4, "threatAllyEase": 16, "threatWarBonus": 0.85, "dangerWeight": 90, "guardDanger": 0.30, "threatPrep": 10,
	"calmTurns": 10, "calmThreatMul": 2.5, "prepTurns": 2, "prepExpire": 6, "prepFavor": -32, "prepOthers": -10,
	"truceTurns": 10, "fatiguePeace": 60,
}
var CASUS = {"lostTurns": 30, "betrayTurns": 30, "unjustTurns": 20, "fabGold": 6000, "fabTurns": 6, "fabKeep": 25,
	"fabSpot": 0.3, "noSec": 15, "noFat": 25, "noFavor": -20, "noThreat": 1.8, "disputeRate": 0.004, "disputeTurns": 20}
var TRADE = {"min": 30, "max": 4, "rate": 0.10, "favor": 1, "favorCap": 80}
var PACT = {"min": 40, "turns": 20, "renewMin": 50, "breakFavor": -25, "breakOthers": -10, "favor": 0.5, "favorCap": 70}
const REL_NAME := {"peace": "平和", "tense": "緊張", "war": "戦争中", "ally": "同盟"}
const REL_COL := {"peace": "#9b9484", "tense": "#d29b3c", "war": "#c0504a", "ally": "#6d9c63"}

func _mk(n: int, v) -> Array:
	var out = []
	for a in n:
		var row = []
		row.resize(n)
		row.fill(v)
		out.append(row)
	return out
func initDip(g: Dictionary) -> Dictionary:
	var n: int = g.nations.size()
	var favor = []
	for a in n:
		var row = []
		for b in n: row.append(100 if a == b else ri(25, 55))
		favor.append(row)
	g.dip = {
		"state": _mk(n, "peace"), "favor": favor,
		"pass": _mk(n, false), "since": _mk(n, 1), "gift": _mk(n, -9),
		"prepAt": _mk(n, 0), "prepBy": _mk(n, -1), "truce": _mk(n, 0), "cool": _mk(n, 0), "allyUntil": _mk(n, 0),
		"goal": _mk(n, "defend"), "score": _mk(n, 0), "taken": _mk(n, 0), "capId": _mk(n, null), "aid": _mk(n, -9),
		"cbUntil": _mk(n, 0), "cbWhy": _mk(n, ""), "fab": _mk(n, 0), "trade": _mk(n, false), "pact": _mk(n, 0),
		"feud": _mk(n, 0), "warId": _mk(n, 0), "peaceAt": _mk(n, -99),
	}
	g.wars = {}
	g.warSeq = 0
	for na in g.nations:
		na.lord = null; na.unrest = 0; na.revoltBuff = 0; na.freeUntil = 0; na.threat = 0
	g.topThreat = null
	return g

func relState(a: int, b: int) -> String: return "self" if a == b else G.dip.state[a][b]
func isTense(a: int, b: int) -> bool: return a != b and G.dip.state[a][b] == "tense"
func inCalm() -> bool: return G.turn <= DIP.calmTurns
func truceLeft(a: int, b: int) -> int: return 0 if a == b else max(0, G.dip.truce[a][b] - G.turn)
func coolLeft(a: int, b: int) -> int: return 0 if a == b else max(0, G.dip.cool[a][b] - G.turn)
func prepLeft(a: int, b: int) -> int: return max(0, G.dip.prepAt[a][b] + DIP.prepTurns - G.turn)
func prepBy(a: int, b: int) -> int: return G.dip.prepBy[a][b]
func canPrepare(a: int, b: int) -> bool:
	return a != b and NAT(a).alive and NAT(b).alive and relState(a, b) == "peace" \
		and truceLeft(a, b) <= 0 and coolLeft(a, b) <= 0 and pactLeft(a, b) <= 0 and not sameFaction(a, b)
func canDeclareWar(a: int, b: int) -> bool: return isTense(a, b) and prepBy(a, b) == a and prepLeft(a, b) <= 0
func atWar(a: int, b: int) -> bool: return a != b and a >= 0 and b >= 0 and G.dip.state[a][b] == "war"
func isAlly(a: int, b: int) -> bool: return a != b and a >= 0 and b >= 0 and G.dip.state[a][b] == "ally"
func favorOf(a: int, b: int) -> float: return G.dip.favor[a][b]
func canPass(mover: int, owner: int) -> bool:
	return owner < 0 or mover == owner or G.dip.pass[owner][mover] or isAlly(mover, owner) or sameFaction(mover, owner)
func addFavor(a: int, b: int, v: float) -> void:
	if a == b or a < 0 or b < 0: return
	G.dip.favor[a][b] = clamp_f(G.dip.favor[a][b] + v, -100, 100)
func setRel(a: int, b: int, st: String) -> void:
	G.dip.state[a][b] = st; G.dip.state[b][a] = st
	G.dip.since[a][b] = G.turn; G.dip.since[b][a] = G.turn

# ---------- 大義名分 ----------
func cbOf(a: int, b: int) -> String:
	if a == b or a < 0 or b < 0 or not NAT(b).alive: return ""
	if isTopThreat(b): return "最大の脅威への対抗"
	if prepBy(a, b) == b: return "相手が軍備を進めている"
	if G.dip.cbUntil[a][b] > G.turn: return G.dip.cbWhy[a][b] if G.dip.cbWhy[a][b] != "" else "大義"
	for c in campOf(a):
		if c != a and atWar(c, b): return "%s が戦っている相手" % NAT(c).name
	return ""
func hasCB(a: int, b: int) -> bool: return cbOf(a, b) != ""
func cbLeft(a: int, b: int) -> int: return max(0, G.dip.cbUntil[a][b] - G.turn)
func fabLeft(a: int, b: int) -> int: return max(0, G.dip.fab[a][b] - G.turn)
func grantCB(a: int, b: int, why: String, turns: int) -> void:
	if a == b or a < 0 or b < 0: return
	if G.turn + turns < G.dip.cbUntil[a][b]: return
	G.dip.cbUntil[a][b] = G.turn + turns
	G.dip.cbWhy[a][b] = why
func fabReason(a: int, b: int) -> String:
	if atWar(a, b): return "戦争中です"
	if hasCB(a, b): return "すでに大義があります（%s）" % cbOf(a, b)
	if fabLeft(a, b) > 0: return "口実を用意しています（あと%dターン）" % fabLeft(a, b)
	if NAT(a).gold < CASUS.fabGold: return "ゴールドが足りません（%sG）" % fmt(CASUS.fabGold)
	return ""
func startFabricate(a: int, b: int) -> bool:
	if fabReason(a, b) != "": return false
	NAT(a).gold -= CASUS.fabGold
	G.dip.fab[a][b] = G.turn + CASUS.fabTurns
	return true
func fabTurn() -> void:
	var n: int = G.nations.size()
	for a in n:
		for b in n:
			var f: int = G.dip.fab[a][b]
			if not f: continue
			if not NAT(a).alive or not NAT(b).alive:
				G.dip.fab[a][b] = 0
				continue
			if G.turn < f - 1: continue
			G.dip.fab[a][b] = 0
			grantCB(a, b, "領有権の主張", CASUS.fabKeep)
			var spot = randf() < CASUS.fabSpot
			if spot:
				addFavor(b, a, -20)
				for c in G.nations:
					if c.alive and c.id != a and c.id != b: addFavor(c.id, a, -4)
			var msg = "%s が %s への領有権を主張%s" % [NAT(a).name, NAT(b).name, "（工作が露見）" if spot else ""]
			logMsg(msg)
			chron(msg, a, "dip")

# ---------- 通商協定 ----------
func isTrade(a: int, b: int) -> bool: return a != b and G.dip.trade[a][b]
func tradePartners(a: int) -> Array:
	var r = []
	for o in G.nations:
		if o.alive and isTrade(a, o.id): r.append(o.id)
	return r
func tradeEase(nid: int) -> float: return PERSONA.get(NAT(nid).persona, PERSONA.neutral).tradeW
func tradeReason(a: int, b: int) -> String:
	if isTrade(a, b): return "すでに通商しています"
	var st = relState(a, b)
	if st == "war" or st == "tense": return "戦争・緊張中は結べません"
	if not natNear(a, b): return "遠すぎて通商できません（隣国とその隣の国まで）"
	if tradePartners(a).size() >= TRADE.max: return "通商協定は %d 国までです" % TRADE.max
	if tradePartners(b).size() >= TRADE.max: return "%s は通商相手が埋まっています" % NAT(b).name
	return ""
func tradeNeed(b: int) -> float: return TRADE.min - tradeEase(b)
func tradeSwap(b: int, a: int):
	var ps = tradePartners(b)
	if ps.size() < TRADE.max or favorOf(b, a) < tradeNeed(b) + 15: return null
	ps.sort_custom(func(x, y): return favorOf(b, x) < favorOf(b, y))
	var worst = ps[0]
	return worst if worst != null and favorOf(b, worst) < favorOf(b, a) else null
func makeTrade(a: int, b: int) -> void:
	G.dip.trade[a][b] = true; G.dip.trade[b][a] = true
	var msg = "%s と %s が通商協定を結ぶ" % [NAT(a).name, NAT(b).name]
	logMsg(msg)
	chron(msg, a, "dip")
func endTrade(a: int, b: int, why := "") -> void:
	if not isTrade(a, b): return
	G.dip.trade[a][b] = false; G.dip.trade[b][a] = false
	var msg = "%s と %s の通商が途絶える%s" % [NAT(a).name, NAT(b).name, ("（" + why + "）") if why != "" else ""]
	logMsg(msg)
	chron(msg, a, "dip")
func tradeIncome(nid: int) -> int:
	var me = NAT(nid)
	if not me.alive: return 0
	var g = 0.0
	for o in tradePartners(nid): g += min(me.get("goldIn", 0), NAT(o).get("goldIn", 0)) * TRADE.rate
	return int(round(g))

# ---------- 不可侵条約 ----------
func pactLeft(a: int, b: int) -> int: return 0 if a == b else max(0, G.dip.pact[a][b] - G.turn)
func pactEase(nid: int) -> float: return PERSONA.get(NAT(nid).persona, PERSONA.neutral).pactW
func pactNeed(b: int) -> float: return PACT.min - pactEase(b)
func makePact(a: int, b: int) -> void:
	G.dip.pact[a][b] = G.turn + PACT.turns; G.dip.pact[b][a] = G.turn + PACT.turns
	var msg = "%s と %s が不可侵条約を結ぶ（%dターン）" % [NAT(a).name, NAT(b).name, PACT.turns]
	logMsg(msg)
	chron(msg, a, "dip")
func breakPact(a: int, b: int) -> void:
	if pactLeft(a, b) <= 0: return
	G.dip.pact[a][b] = 0; G.dip.pact[b][a] = 0
	addFavor(b, a, PACT.breakFavor)
	for c in G.nations:
		if c.alive and c.id != a and c.id != b: addFavor(c.id, a, PACT.breakOthers)
	grantCB(b, a, "不可侵条約の破棄", CASUS.betrayTurns)
	addThreat(a, 10)
	var msg = "%s が %s との不可侵条約を破棄" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "war")
	chron(msg, a, "dip")
	dipReport("unpact", a, b, true, "%s は %dターンの大義を得た" % [NAT(b).name, CASUS.betrayTurns])
func peaceTiesTurn() -> void:
	var n: int = G.nations.size()
	for a in n:
		for b in range(a + 1, n):
			if not NAT(a).alive or not NAT(b).alive:
				G.dip.trade[a][b] = false; G.dip.trade[b][a] = false
				G.dip.pact[a][b] = 0; G.dip.pact[b][a] = 0
				continue
			if isTrade(a, b) and not natNear(a, b): endTrade(a, b, "国が遠く隔たった")
			if isTrade(a, b):
				if favorOf(a, b) < TRADE.favorCap: addFavor(a, b, TRADE.favor)
				if favorOf(b, a) < TRADE.favorCap: addFavor(b, a, TRADE.favor)
			var fric = clamp_f(1 + (60 - (favorOf(a, b) + favorOf(b, a)) / 2) / 40, 0.4, 2.5)
			if relState(a, b) == "peace" and pactLeft(a, b) <= 0 \
					and randf() < CASUS.disputeRate * fric and nationsAdjacent(a, b):
				grantCB(a, b, "国境紛争", CASUS.disputeTurns); grantCB(b, a, "国境紛争", CASUS.disputeTurns)
				addFavor(a, b, -8); addFavor(b, a, -8)
				var msg = "%s と %s の国境で紛争 — 互いに大義を得る" % [NAT(a).name, NAT(b).name]
				logMsg(msg)
				chron(msg, a, "dip")
			var p: int = G.dip.pact[a][b]
			if p:
				if favorOf(a, b) < PACT.favorCap: addFavor(a, b, PACT.favor)
				if favorOf(b, a) < PACT.favorCap: addFavor(b, a, PACT.favor)
				if G.turn >= p - 1:
					if favorOf(a, b) >= PACT.renewMin and favorOf(b, a) >= PACT.renewMin and relState(a, b) == "peace" and pactOK(a, b):
						G.dip.pact[a][b] = G.turn + 1 + PACT.turns; G.dip.pact[b][a] = G.turn + 1 + PACT.turns
						chron("%s と %s が不可侵条約を更新" % [NAT(a).name, NAT(b).name], a, "dip")
					else:
						G.dip.pact[a][b] = 0; G.dip.pact[b][a] = 0
						var msg2 = "%s と %s の不可侵条約が満了" % [NAT(a).name, NAT(b).name]
						logMsg(msg2)
						chron(msg2, a, "dip")

# ---------- 同盟・従属 ----------
func lordOf(nid: int):
	if nid < 0: return null
	var n = NAT(nid)
	return n.lord if n.lord != null and NAT(n.lord).alive else null
func vassalsOf(nid: int) -> Array:
	var r = []
	for n in G.nations:
		if n.alive and n.lord == nid: r.append(n.id)
	return r
func isVassal(a: int, b: int) -> bool: return lordOf(a) == b
func allyUntil(a: int, b: int) -> int: return G.dip.allyUntil[a][b]
func allyLeft(a: int, b: int) -> float:
	if not isAlly(a, b): return 0
	if isVassal(a, b) or isVassal(b, a): return INF
	return max(0, allyUntil(a, b) - G.turn)
func campOf(nid: int) -> Array:
	var set = {nid: true}
	var l = lordOf(nid)
	if l != null: set[l] = true
	for v in vassalsOf(nid): set[v] = true
	for o in G.nations:
		if o.alive and isAlly(nid, o.id): set[o.id] = true
	return set.keys()
func relLabel(a: int, b: int) -> String:
	if a == b: return "自国"
	if isVassal(b, a): return "属国"
	if isVassal(a, b): return "主君"
	return REL_NAME.get(relState(a, b), "—")
func relLabelCol(a: int, b: int) -> String:
	if isVassal(b, a) or isVassal(a, b): return "#c9a227"
	return REL_COL.get(relState(a, b), "#9b9484")

# ---------- 脅威度 ----------
var THR_KEY = -1
var THR_G = null
var THR_C = {"t": {}}
func thrCache() -> Dictionary:
	if THR_KEY != STRAT_REV or THR_G != G:
		THR_KEY = STRAT_REV
		THR_G = G
		THR_C = {"t": {}}
	return THR_C
func addThreat(nid: int, v: float) -> void:
	if nid < 0: return
	var n = NAT(nid)
	n.threat = clamp_f(n.get("threat", 0) + v, 0, 400)
	THR_KEY = -1
func threatOf(nid: int) -> float:
	var c = thrCache()
	if c.t.has(nid): return c.t[nid]
	var v = threatCalc(nid)
	c.t[nid] = v
	return v
func threatCalc(nid: int) -> float:
	var n = NAT(nid)
	if not n.alive: return 0.0
	var tot = 0.0
	var live = 0
	for x in G.nations:
		if x.alive:
			tot += nationPower(x.id)
			live += 1
	if tot == 0: tot = 1
	var over: float = max(0.0, nationPower(nid) / tot - 1.0 / max(1, live))
	return n.get("threat", 0) + over * DIP.threatPowerW
func topThreat():
	var c = thrCache()
	if c.has("top"): return c.top
	c.top = topThreatCalc()
	return c.top
func topThreatCalc():
	var id = null
	var v = 0.0
	for n in G.nations:
		if not n.alive: continue
		var t = threatOf(n.id)
		if t > v:
			v = t
			id = n.id
	var cur = G.topThreat
	if cur != null and NAT(cur).alive:
		var cv = threatOf(cur)
		if cv >= DIP.threatMin * 0.75 and cv >= v * 0.87: return {"id": cur, "v": cv}
	return {"id": id, "v": v} if v >= DIP.threatMin else null
func isTopThreat(nid: int) -> bool:
	var t = topThreat()
	return t != null and t.id == nid
func threatLabel(v: float) -> String:
	return "静穏" if v < 20 else ("警戒" if v < 40 else ("脅威" if v < 70 else "大いなる脅威"))
func threatColor(v: float) -> String:
	return "#9b9484" if v < 20 else ("#4d5666" if v < 40 else ("#c9a227" if v < 70 else "#c0504a"))
func decayThreat() -> void:
	THR_KEY = -1
	for n in G.nations: n.threat = max(0.0, n.get("threat", 0) * DIP.threatDecay)
	var t = topThreat()
	var cur = t.id if t != null else null
	if cur != G.topThreat:
		if cur != null:
			var msg = "%s が諸国から最大の脅威とみなされる" % NAT(cur).name
			logMsg(msg, "war")
			chron(msg, cur, "dip")
		G.topThreat = cur

# 侵入・占領の可否
func canEnter(nid: int, tid: int) -> bool:
	var o: int = T(tid).owner
	return o < 0 or o == nid or atWar(nid, o) or canPass(nid, o)
func canOccupy(nid: int, tid: int) -> bool:
	var o: int = T(tid).owner
	return o >= 0 and o != nid and atWar(nid, o)
func enterReason(nid: int, tid: int) -> String:
	var o: int = T(tid).owner
	if o < 0 or o == nid or atWar(nid, o) or canPass(nid, o): return ""
	return "%s とは平和状態です。通行許可を得るか宣戦布告が必要です" % NAT(o).name
func warJust(a: int, b: int) -> float: return DIP.justMul if hasCB(a, b) else 1.0

# ============================================================
#   戦争（陣営）
# ============================================================
func warOf(x: int, y: int) -> int:
	if x < 0 or y < 0: return 0
	return G.dip.warId[x][y]
func warObj(x: int, y: int):
	return G.wars.get(warOf(x, y))
func newWar(a: int, b: int) -> int:
	G.warSeq = G.get("warSeq", 0) + 1
	var id: int = G.warSeq
	G.wars[id] = {"id": id, "a": a, "b": b, "sA": [a], "sB": [b], "t0": G.turn, "sc": {}, "vp0": {a: natVP(a), b: natVP(b)}}
	setWarId(a, b, id)
	return id
func setWarId(x: int, y: int, id: int) -> void:
	G.dip.warId[x][y] = id; G.dip.warId[y][x] = id
func joinSide(id: int, nid: int, enemy: int) -> void:
	var W = G.wars.get(id)
	if W == null: return
	var side: Array = W.sB if W.sA.has(enemy) else W.sA
	if not side.has(nid): side.append(nid)
	if not W.vp0.has(nid): W.vp0[nid] = natVP(nid)
	setWarId(nid, enemy, id)
func sideOf(W: Dictionary, nid: int):
	if W.sA.has(nid): return W.sA
	if W.sB.has(nid): return W.sB
	return null
func otherSide(W: Dictionary, nid: int) -> Array: return W.sB if W.sA.has(nid) else W.sA
func warLeaders(x: int, y: int) -> bool:
	var W = warObj(x, y)
	return W == null or (W.a == x and W.b == y) or (W.a == y and W.b == x)
func addWarPts(x: int, y: int, v: float) -> void:
	var W = warObj(x, y)
	if W != null and v > 0:
		W.sc[x] = W.sc.get(x, 0) + v
		W.act = G.turn
func warTurn() -> void:
	for W in G.wars.values().duplicate():
		if not G.wars.has(W.id): continue
		for n in W.sA + W.sB:
			if not inThisWar(W, n): continue
			if not W.vp0.has(n): W.vp0[n] = natVP(n)
			var sp = surrenderProg(W, n)
			if sp >= surrenderLimit(n): capitulate(W, n, "国の %d%% を占領された" % int(round(sp * 100)))
		if not G.wars.has(W.id): continue
		warSuccession()
		if not G.wars.has(W.id): continue
		var age: int = G.turn - W.t0
		var idle: int = G.turn - W.get("act", W.t0)
		if (age >= 20 and idle >= 10) or age >= 50:
			var lines = endWar(W, null)
			dipReport("peace", W.a, W.b, true, ("長い戦に双方が疲れ果てた" if age >= 50 else "戦線が膠着した") + (("／" + "／".join(lines)) if lines.size() else ""))
func _lostSide(W: Dictionary, S_: Array) -> bool:
	for n in S_:
		if NAT(n).alive and not W.get("capd", []).has(n): return false
	return true
func _actSide(W: Dictionary, S_: Array) -> Array:
	var r = []
	for n in S_:
		if inThisWar(W, n): r.append(n)
	return r
func warSuccession() -> void:
	for W in G.wars.values().duplicate():
		if not G.wars.has(W.id): continue
		var lA = _lostSide(W, W.sA)
		var lB = _lostSide(W, W.sB)
		if lA and not lB:
			endWar(W, {"winner": W.sB, "full": true})
			continue
		if lB and not lA:
			endWar(W, {"winner": W.sA, "full": true})
			continue
		var aA = _actSide(W, W.sA)
		var aB = _actSide(W, W.sB)
		if aA.is_empty() or aB.is_empty():
			if aA.size() and aB.is_empty(): endWar(W, {"winner": W.sA, "full": lB})
			elif aB.size() and aA.is_empty(): endWar(W, {"winner": W.sB, "full": lA})
			else: endWar(W, null)
			continue
		for k in ["a", "b"]:
			if inThisWar(W, W[k]): continue
			var cand = aA if k == "a" else aB
			cand.sort_custom(func(x, y): return W.sc.get(x, 0) > W.sc.get(y, 0))
			if cand.size(): W[k] = cand[0]

# ---------- 降伏と講和会議 ----------
const VP_K := 3
func vpOf(t: Dictionary) -> float: return 1 + t.dev * 1.5 + (12 if t.cap else 0) + (1 if t.type == "city" else 0) + t.pop / 8000.0
func natVP(n: int) -> float:
	var s = 0.0
	for t in G.terrs:
		if t.owner == n: s += vpOf(t)
	return s
func surrenderLimit(n: int) -> float:
	var na = NAT(n)
	var base: float = {"def": 0.78, "aggr": 0.7, "bal": 0.66, "econ": 0.58, "democracy": 0.78, "fascism": 0.7, "communism": 0.66, "neutral": 0.6}.get(na.persona, 0.66)
	return clamp_f(base - na.get("fatigue", 0) / 250.0, 0.35, 0.85)
func surrenderProg(W: Dictionary, n: int) -> float:
	var base: float = W.vp0.get(n, 0)
	if not base: base = natVP(n)
	if not base: base = 1
	var foe = otherSide(W, n)
	var occ = 0.0
	for t in G.terrs:
		if t.get("wTag") == W.id and t.get("wOrig") == n and foe.has(t.owner): occ += vpOf(t)
	return clamp_f(occ / base, 0, 1)
func inThisWar(W: Dictionary, n: int) -> bool:
	if n < 0 or not NAT(n).alive: return false
	for o in G.nations:
		if o.alive and warOf(n, o.id) == W.id and atWar(n, o.id): return true
	return false
func capitulate(W: Dictionary, n: int, why := "") -> void:
	for o in G.nations:
		if warOf(n, o.id) != W.id or not atWar(n, o.id): continue
		setRel(n, o.id, "peace")
		setWarId(n, o.id, 0)
		G.dip.truce[n][o.id] = G.turn + DIP.truceTurns; G.dip.truce[o.id][n] = G.turn + DIP.truceTurns
	if not W.has("capd"): W.capd = []
	if not W.capd.has(n): W.capd.append(n)
	var msg = "%s が降伏する%s" % [NAT(n).name, ("（" + why + "）") if why != "" else ""]
	if concerns([n] + otherSide(W, n)): logMsg(msg, "war")
	chron(msg, n, "fall")
	dipReport("surrender", n, otherSide(W, n)[0], true, why)
	invalidateSupply()

# ==================== k3b_dip.gd ====================
# 外交 続き（元 4570〜5097）：講和会議・宣戦・和平・同盟・知らせ・従属

## 戦争の終わり：講和会議。opts.winner = 勝った陣営の配列（なければ現状のままの講和）、opts.full = 相手陣営が全員降伏した
func endWar(W, opts) -> Array:
	if W == null or not G.wars.has(W.id): return []
	if opts == null: opts = {}
	var lines = []
	var got = {}
	var back = {}
	var winner = opts.get("winner")
	var full: bool = opts.get("full", false)
	for S_ in [W.sA, W.sB]:
		var O: Array = W.sB if S_ == W.sA else W.sA
		var winning: bool = winner != null and winner == S_
		var losing: bool = winner != null and winner != S_
		if losing: continue
		var mem = []
		for n in S_:
			if NAT(n).alive: mem.append(n)
		mem.sort_custom(func(x, y): return W.sc.get(x, 0) > W.sc.get(y, 0))
		if mem.is_empty(): continue
		var pool = {}
		for t in G.terrs:
			if t.get("wTag") == W.id and O.has(t.get("wOrig")) and S_.has(t.owner): pool[t.id] = t
		if winning and full:
			for t in G.terrs:
				if O.has(t.owner) and NAT(t.owner).alive and not t.cap: pool[t.id] = t
		var budget = {}
		var mine = {}
		for n in mem:
			budget[n] = W.sc.get(n, 0) * (1.0 if winning else 0.6)
			mine[n] = {}
		for round_ in 400:
			if pool.is_empty(): break
			var any = false
			for n in mem:
				var best = null
				var bs = -INF
				var bc = 0.0
				for t in pool.values():
					var held: bool = t.owner == n
					var cost: float = vpOf(t) * VP_K * (0.5 if held else 1.0)
					if cost > budget[n]: continue
					var adj = held
					if not adj:
						for nb in roadNbrs(t.id):
							if T(nb.to).owner == n or mine[n].has(nb.to):
								adj = true
								break
					if not adj: continue
					var sc: float = vpOf(t) / cost + (1 if held else 0)
					if sc > bs:
						bs = sc; best = t; bc = cost
				if best == null: continue
				budget[n] -= bc
				pool.erase(best.id)
				mine[n][best.id] = true
				if best.owner != n:
					_giveTerr(best, n)
					best.chaos = max(best.chaos, 2)
					best.sec = min(best.sec, CFG.secCapture + 10)
				got[n] = got.get(n, 0) + 1
				any = true
			if not any: break
		for t in pool.values():
			if t.get("wTag") == W.id and t.owner != t.wOrig and NAT(t.wOrig).alive:
				_giveTerr(t, t.wOrig)
				back[t.wOrig] = back.get(t.wOrig, 0) + 1
		if winning and full:
			var top = mem[0]
			var lead: int = W.b if S_ == W.sA else W.a
			if top != null and NAT(lead).alive and lordOf(lead) == null and budget[top] >= natVP(lead) * VP_K * 0.5 and canAskVassal(top, lead):
				W.puppet = [top, lead]
	if winner != null:
		var L: Array = W.sB if winner == W.sA else W.sA
		for t in G.terrs:
			if t.get("wTag") == W.id and L.has(t.owner) and winner.has(t.get("wOrig")) and NAT(t.wOrig).alive:
				_giveTerr(t, t.wOrig)
				back[t.wOrig] = back.get(t.wOrig, 0) + 1
	if got.size():
		var parts = []
		for n in got: parts.append("%s %d領地" % [NAT(n).name, got[n]])
		lines.append("講和会議：" + "、".join(parts))
	if back.size():
		var parts2 = []
		for n in back: parts2.append("%s へ %d領地" % [NAT(n).name, back[n]])
		lines.append("返還：" + "、".join(parts2))
	for x in G.nations:
		for y in G.nations:
			if x.id >= y.id or warOf(x.id, y.id) != W.id: continue
			setWarId(x.id, y.id, 0)
			if not atWar(x.id, y.id): continue
			setRel(x.id, y.id, "peace")
			G.dip.truce[x.id][y.id] = G.turn + DIP.truceTurns; G.dip.truce[y.id][x.id] = G.turn + DIP.truceTurns
			G.dip.favor[x.id][y.id] = max(G.dip.favor[x.id][y.id], 10)
			G.dip.favor[y.id][x.id] = max(G.dip.favor[y.id][x.id], 10)
	for n in W.sA + W.sB:
		if NAT(n).alive: addFatigue(n, -15)
	for t in G.terrs:
		if t.get("wTag") == W.id:
			t.erase("wTag"); t.erase("wOrig")
	G.wars.erase(W.id)
	if W.has("puppet"):
		makeVassal(W.puppet[0], W.puppet[1], "講和会議による従属")
		lines.append("%s は %s の属国に" % [NAT(W.puppet[1]).name, NAT(W.puppet[0]).name])
	var sa = []
	var sb = []
	for n in W.sA:
		if NAT(n).alive: sa.append(NAT(n).name)
	for n in W.sB:
		if NAT(n).alive: sb.append(NAT(n).name)
	var head: String = ("%s 陣営の勝利" % NAT(W.a if winner == W.sA else W.b).name) if winner != null else "現状のままの講和"
	var msg = "%s と %s の戦争が終わる — %s（%s 対 %s）" % [NAT(W.a).name, NAT(W.b).name, head, "・".join(sa), "・".join(sb)]
	if lines.size(): msg += "：" + "／".join(lines)
	if concerns(W.sA + W.sB): logMsg(msg, "good")
	chron(msg, W.a, "dip")
	if newsworthy([W.a, W.b]):
		var wn = W.a if winner == W.sA else W.b
		headline(("%s、講和で勝利" % natLabel(wn)) if winner != null else ("%s と %s、痛み分けの講和" % [natLabel(W.a), natLabel(W.b)]), "/".join(lines) if lines.size() else "領土の変更なし")
	invalidateSupply()
	return lines
func _giveTerr(t: Dictionary, n: int) -> void:
	if t.owner != n:
		t.owner = n
		invalidateTerr(t.id)
		G.ownRev = G.get("ownRev", 0) + 1

func declareWar(a: int, b: int, _byPlayer := false) -> void:
	if a == b or atWar(a, b): return
	var wasAlly = isAlly(a, b)
	var why = cbOf(a, b)
	var just = warJust(a, b)
	if pactLeft(a, b) > 0: breakPact(a, b)
	endTrade(a, b, "開戦")
	G.dip.feud[a][b] += 1; G.dip.feud[b][a] += 1
	G.dip.prepBy[a][b] = -1; G.dip.prepBy[b][a] = -1
	setRel(a, b, "war")
	newWar(a, b)
	G.dip.pass[a][b] = false; G.dip.pass[b][a] = false
	addFavor(b, a, DIP.warFavor + (-20 if wasAlly else 0))
	for c in G.nations:
		if c.id == a or c.id == b or not c.alive: continue
		var base: float = DIP.warAllyOthers if isAlly(c.id, a) else DIP.warOthers
		addFavor(c.id, a, base * (DIP.justMul if isTopThreat(b) and c.id != b else 1.0))
	addThreat(a, DIP.threatWar * (DIP.calmThreatMul if inCalm() else 1.0) * just)
	if why == "":
		for t in G.terrs:
			if t.owner == a: t.sec = clamp_f(t.sec - CASUS.noSec, 0, 100)
		addFatigue(a, CASUS.noFat)
		addThreat(a, DIP.threatWar * (CASUS.noThreat - 1))
		for c in G.nations:
			if not c.alive or c.id == a or c.id == b: continue
			addFavor(c.id, a, CASUS.noFavor)
			if nationsAdjacent(c.id, a): grantCB(c.id, a, "%s の不義の戦" % NAT(a).name, CASUS.unjustTurns)
	G.declN = G.get("declN", 0) + 1
	warInit(a, b, cpuWarGoal(a, b))
	var msg = "%s が %s に宣戦布告（目標：%s）" % [NAT(a).name, NAT(b).name, goalLabel(a, b)]
	if newsworthy([a, b]): headline("%s、%s に宣戦布告" % [natLabel(a), natLabel(b)], "目標：%s" % goalLabel(a, b))
	logMsg(msg, "war")
	chron(msg, a, "dip")
	var note = ("同盟を破っての開戦／" if wasAlly else "") + (("大義：" + why) if why != "" else "大義なき開戦（国内の治安・諸国の評判が大きく下がる）") + "／目標：" + goalLabel(a, b)
	var dv = desireVs(a, b)
	if dv != null: note += "／望み：" + desireText(dv)
	dipReport("war", a, b, true, note)
	joinWarByPact(a, b)
	factionCallToArms(a, b)
	hoiGuarantee(a, b)
	invalidateSupply()
func makePeace(a: int, b: int) -> void:
	if not atWar(a, b): return
	if lordOf(a) != null or lordOf(b) != null: return
	setRel(a, b, "peace")
	G.dip.truce[a][b] = G.turn + DIP.truceTurns; G.dip.truce[b][a] = G.turn + DIP.truceTurns
	addFatigue(a, -20); addFatigue(b, -20)
	G.dip.favor[a][b] = max(G.dip.favor[a][b], 12)
	G.dip.favor[b][a] = max(G.dip.favor[b][a], 12)
	var msg = "%s と %s が和平を結ぶ" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "good")
	chron(msg, a, "dip")
	dipReport("peace", a, b, true, "")
	for pr in [[a, b], [b, a]]:
		for v in vassalsOf(pr[0]):
			if atWar(v, pr[1]):
				setRel(v, pr[1], "peace")
				G.dip.truce[v][pr[1]] = G.turn + DIP.truceTurns; G.dip.truce[pr[1]][v] = G.turn + DIP.truceTurns
				G.dip.favor[v][pr[1]] = max(G.dip.favor[v][pr[1]], 10)
func makeAlly(a: int, b: int, forced := false) -> void:
	setRel(a, b, "ally")
	G.dip.pass[a][b] = true; G.dip.pass[b][a] = true
	var u: int = 0 if forced else G.turn + DIP.allyTurns
	G.dip.allyUntil[a][b] = u; G.dip.allyUntil[b][a] = u
	var msg = "%s と %s が同盟を結ぶ" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "good")
	chron(msg, a, "dip")
	if not forced:
		dipReport("ally", a, b, true, "期限 %dターン" % DIP.allyTurns)
		shareWars(a, b)
func renewAlly(a: int, b: int) -> bool:
	if not isAlly(a, b): return false
	G.dip.allyUntil[a][b] = G.turn + DIP.allyTurns; G.dip.allyUntil[b][a] = G.turn + DIP.allyTurns
	var msg = "%s と %s が同盟を更新" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "good")
	chron(msg, a, "dip")
	dipReport("renew", a, b, true, "期限 %dターン" % DIP.allyTurns)
	return true
func expireAlly(a: int, b: int) -> void:
	if not isAlly(a, b): return
	setRel(a, b, "peace")
	G.dip.pass[a][b] = false; G.dip.pass[b][a] = false
	var msg = "%s と %s の同盟が期限切れ" % [NAT(a).name, NAT(b).name]
	logMsg(msg)
	chron(msg, a, "dip")
	dipReport("allyEnd", a, b, true, "")
func shareWars(a: int, b: int) -> void:
	for pr in [[a, b], [b, a]]:
		var x: int = pr[0]
		var y: int = pr[1]
		for o in G.nations:
			if not o.alive or o.id == x or o.id == y: continue
			if not atWar(x, o.id) or atWar(y, o.id): continue
			if isAlly(y, o.id): breakAlly(y, o.id)
			if isVassal(y, o.id) or isVassal(o.id, y): continue
			if not (isVassal(y, x) or isVassal(x, y)) and not natNear(y, o.id): continue
			enterWar(y, o.id, "%s との同盟により参戦" % NAT(x).name, warOf(x, o.id))
func enterWar(a: int, b: int, why: String, wid: int) -> void:
	if a == b or atWar(a, b) or not NAT(a).alive or not NAT(b).alive: return
	# 1つの戦争で片方に加わる国は、主役を含めて4か国まで（遠くの国まで一斉に袋だたきにする連鎖を防ぐ）。属国は主君に従う
	if wid and G.wars.has(wid):
		var Wj: Dictionary = G.wars[wid]
		var mySide: Array = Wj.sB if Wj.sA.has(b) else Wj.sA
		var bound = false
		for m in mySide:
			if isVassal(a, m): bound = true
		if mySide.size() >= WAR_SIDE_MAX and not bound: return
	setRel(a, b, "war")
	if wid and G.wars.has(wid): joinSide(wid, a, b)
	else: newWar(a, b)
	warInit(a, b, "cede")
	G.dip.goal[b][a] = "cede"
	G.dip.pass[a][b] = false; G.dip.pass[b][a] = false
	addFavor(b, a, -45)
	var msg = "%s が %s との戦争に加わる" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "war")
	chron(msg, a, "dip")
	dipReport("join", a, b, true, why)
const WAR_SIDE_MAX := 4
func _joinCamp(x: int, y: int, attacker: bool) -> void:
	for id in campOf(x):
		if id == x or id == y: continue
		if not NAT(id).alive or atWar(id, y): continue
		if isAlly(id, y) or isVassal(id, y) or isVassal(y, id): continue
		var bound = isVassal(id, x) or isVassal(x, id)
		if not bound and pactLeft(id, y) > 0: continue
		if not bound and not natNear(id, y): continue
		if not bound and attacker and favorOf(id, x) < 45:
			breakAlly(id, x)
			dipReport("join", id, y, false, "%s の戦に加わらず、同盟を解消した" % NAT(x).name)
			continue
		var why: String
		if isVassal(id, x): why = "%s の属国として参戦" % NAT(x).name
		elif isVassal(x, id): why = "属国 %s を支援" % NAT(x).name
		elif attacker: why = "%s との同盟により参戦" % NAT(x).name
		else: why = "%s を守るため参戦" % NAT(x).name
		enterWar(id, y, why, warOf(x, y))
func joinWarByPact(a: int, b: int) -> void:
	_joinCamp(a, b, true)
	_joinCamp(b, a, false)
func breakAlly(a: int, b: int) -> void:
	if not isAlly(a, b): return
	if isVassal(a, b) or isVassal(b, a): return
	G.dip.allyUntil[a][b] = 0; G.dip.allyUntil[b][a] = 0
	setRel(a, b, "peace")
	G.dip.pass[a][b] = false; G.dip.pass[b][a] = false
	addFavor(b, a, -30)
	var msg = "%s が %s との同盟を破棄" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "war")
	chron(msg, a, "dip")
	dipReport("unally", a, b, true, "")
func grantPass(owner: int, to: int) -> void:
	G.dip.pass[owner][to] = true
	var msg = "%s が %s に領内通行を許可" % [NAT(owner).name, NAT(to).name]
	logMsg(msg, "good")
	chron(msg, owner, "dip")
	dipReport("pass", to, owner, true, "")
func startWarPrep(a: int, b: int, _byPlayer := false) -> bool:
	if not canPrepare(a, b): return false
	G.dip.state[a][b] = "tense"; G.dip.state[b][a] = "tense"
	G.dip.prepAt[a][b] = G.turn; G.dip.prepAt[b][a] = G.turn
	G.dip.prepBy[a][b] = a; G.dip.prepBy[b][a] = a
	G.dip.pass[a][b] = false; G.dip.pass[b][a] = false
	if isTrade(a, b):
		endTrade(a, b, "開戦準備")
		addFavor(b, a, -10)
	var just = warJust(a, b)
	addFavor(b, a, DIP.prepFavor)
	for c in G.nations:
		if c.id == a or c.id == b or not c.alive: continue
		addFavor(c.id, a, DIP.prepOthers * just)
	addThreat(a, DIP.threatPrep * (DIP.calmThreatMul if inCalm() else 1.0) * just)
	var msg = "%s が %s に対し軍備を進めています" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "war")
	chron(msg, a, "dip")
	dipReport("prep", a, b, true, ("大義：" + cbOf(a, b)) if hasCB(a, b) else "大義なし — 宣戦すれば国内の治安と諸国の評判が大きく下がる")
	return true
func cancelWarPrep(a: int, b: int, quiet := false) -> void:
	if not isTense(a, b): return
	G.dip.state[a][b] = "peace"; G.dip.state[b][a] = "peace"
	G.dip.prepBy[a][b] = -1; G.dip.prepBy[b][a] = -1
	if quiet: return
	var msg = "%s と %s の緊張が解ける" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "good")
	chron(msg, a, "dip")
func dipTurn() -> void:
	var n: int = G.nations.size()
	for a in n:
		for b in range(a + 1, n):
			if not isAlly(a, b) or isVassal(a, b) or isVassal(b, a): continue
			if allyUntil(a, b) and G.turn >= allyUntil(a, b):
				var keep = favorOf(a, b) >= DIP.allyRenewMin and favorOf(b, a) >= DIP.allyRenewMin and natNear(a, b) and ideoCompat(a, b)
				if keep: renewAlly(a, b)
				else: expireAlly(a, b)
	vassalTurn()
	fabTurn()
	peaceTiesTurn()
	if G.turn == DIP.calmTurns:
		var msg = "平穏の時代が終わる — 諸国が牙を研ぎ始める"
		logMsg(msg, "war")
		chron(msg, -1, "end")
	for a in n:
		for b in range(a + 1, n):
			if G.dip.state[a][b] != "tense": continue
			var by: int = G.dip.prepBy[a][b]
			if by < 0:
				cancelWarPrep(a, b, true)
				continue
			var over: int = G.turn - (G.dip.prepAt[a][b] + DIP.prepTurns)
			if over > DIP.prepExpire:
				cancelWarPrep(by, b if by == a else a)
				G.dip.cool[a][b] = G.turn + 5; G.dip.cool[b][a] = G.turn + 5

# ============================================================
#   外交の知らせ
# ============================================================
var DIPQ = []
const DIP_KIND := {
	"prep": {"n": "開戦準備", "v": "軍備を進めた", "col": "#d8a03c"},
	"war": {"n": "宣戦布告", "v": "宣戦を布告した", "col": "#c94b44"},
	"peace": {"n": "和平", "v": "和平を申し入れた", "col": "#5f9c57"},
	"ally": {"n": "同盟", "v": "同盟を申し入れた", "col": "#5f9c57"},
	"unally": {"n": "同盟破棄", "v": "同盟の破棄を通告した", "col": "#c94b44"},
	"pass": {"n": "通行許可", "v": "領内の通行を求めた", "col": "#7fa8cf"},
	"join": {"n": "参戦", "v": "同盟にもとづき参戦した", "col": "#c94b44"},
	"renew": {"n": "同盟の更新", "v": "同盟の更新に合意した", "col": "#5f9c57"},
	"allyEnd": {"n": "同盟の満了", "v": "との同盟が期限を迎えた", "col": "#9b9484"},
	"vassal": {"n": "従属", "v": "従属を求めた", "col": "#c9a227"},
	"revolt": {"n": "独立戦争", "v": "に反旗を翻した", "col": "#c94b44"},
	"surrender": {"n": "降伏", "v": "に降伏した", "col": "#c94b44"},
	"faction": {"n": "陣営", "v": "が陣営への参加を呼びかけた", "col": "#9b7fd0"},
	"unfaction": {"n": "陣営の離脱", "v": "の陣営を離れた", "col": "#9b9484"},
	"annex": {"n": "併合", "v": "併合を求めた", "col": "#c94b44"},
	"trade": {"n": "通商協定", "v": "通商を申し入れた", "col": "#c9a227"},
	"untrade": {"n": "通商の途絶", "v": "との通商が途絶えた", "col": "#9b9484"},
	"pact": {"n": "不可侵条約", "v": "不可侵条約を申し入れた", "col": "#7fa8cf"},
	"unpact": {"n": "条約破棄", "v": "との不可侵条約を破棄した", "col": "#c94b44"},
	"pactEnd": {"n": "条約の満了", "v": "との不可侵条約が期限を迎えた", "col": "#9b9484"},
	"fab": {"n": "領有権の主張", "v": "への領有権を主張した", "col": "#d8a03c"},
	"dispute": {"n": "国境紛争", "v": "との国境で衝突した", "col": "#d8a03c"},
}
signal dip_show(ev: Dictionary)
signal dip_closed
func dipReport(kind: String, from: int, to: int, ok := true, note := "") -> void:
	if G == null or not CFG.showDip: return
	DIPQ.append({"kind": kind, "from": from, "to": to, "ok": ok, "note": note, "turn": G.turn})
	if DIPQ.size() > 12: DIPQ.pop_front()
## 溜まった外交の知らせを、選んだ国に関わるものだけ順に見せる（OK まで進行は止まる）
func flushDip() -> void:
	while DIPQ.size():
		var ev = DIPQ.pop_front()
		if not CFG.showDip: continue
		if not concerns([ev.from, ev.to]): continue
		if dip_show.get_connections().is_empty(): continue
		if ev.from < 0 or ev.to < 0: continue
		dip_show.emit(ev)
		await dip_closed
func dipResultText(ev: Dictionary) -> String:
	if not ev.ok:
		match ev.kind:
			"ally": return "同盟は断られた"
			"peace": return "和平は退けられ、戦いは続く"
			"vassal": return "従属の要求は拒まれた"
			"annex": return "併合の要求は拒まれた"
			"pass": return "通行は認められなかった"
			"trade": return "通商は断られた"
			"pact": return "条約は断られた"
		return "受け入れられなかった"
	match ev.kind:
		"join": return "同盟・従属の義務により戦列に加わった"
		"renew": return "同盟はさらに %dターン続く" % DIP.allyTurns
		"allyEnd": return "同盟は解け、ふたたび別々の道を行く"
		"vassal": return "従属が成立した。強制同盟となり、毎ターン貢納が行われる"
		"revolt": return "独立戦争が始まった（%dターンの高揚）" % DIP.revoltTurns
		"annex": return "国は併合され、地図から消えた"
		"prep": return "%dターン後には宣戦できる。周辺国にも伝わった" % DIP.prepTurns
		"war": return "両国は戦争状態に入った"
		"peace": return "和平が成立した（%dターンは再び戦えない）" % DIP.truceTurns
		"ally": return "同盟が成立した。互いの領内を通行できる"
		"unally": return "同盟は破棄された"
		"pass": return "領内の通行が認められた"
		"trade": return "通商協定が成立した。互いに毎ターン収入を得る"
		"untrade": return "通商協定は打ち切られた"
		"pact": return "不可侵条約が成立した（%dターン）" % PACT.turns
		"unpact": return "条約は破られ、相手は大義を得た"
		"pactEnd": return "条約は期限を迎えた"
		"fab": return "攻め込む口実が整った"
		"dispute": return "小競り合いが起き、両国は互いに大義を得た"
	return ""

# ============================================================
#   属国（従属）
# ============================================================
func freeLeft(nid: int) -> int: return max(0, NAT(nid).get("freeUntil", 0) - G.turn)
func canAskVassal(a: int, b: int) -> bool:
	if a == b or not NAT(a).alive or not NAT(b).alive: return false
	if lordOf(b) != null or lordOf(a) == b: return false
	if vassalsOf(b).size(): return false
	if freeLeft(b) > 0: return false
	var pa = nationPower(a)
	var pb: float = max(1.0, nationPower(b))
	var need: float = DIP.vassalWarRatio if atWar(a, b) else DIP.vassalRatio
	return pa / pb >= need
func vassalAccept(a: int, b: int) -> bool:
	if isMajor(NAT(b)) and not atWar(a, b): return false
	var ratio = nationPower(a) / max(1.0, nationPower(b))
	var war = atWar(a, b)
	var fav = favorOf(b, a)
	var nb2 = NAT(b)
	var sc: float = (ratio - 1) * 45 + (nb2.get("fatigue", 0) * 0.6 if war else 0.0) + (fav - DIP.vassalFavor) * 0.4
	if war: sc += 18
	sc += cpuDanger(b) * 30
	if not war and fav < DIP.vassalFavor: sc -= 40
	var terr = 0
	for t in G.terrs:
		if t.owner == b: terr += 1
	if terr <= 2: sc += 25
	return sc >= 30
func makeVassal(lord: int, sub: int, note := "") -> void:
	var L = NAT(lord)
	var S_ = NAT(sub)
	if atWar(lord, sub) and warObj(lord, sub) != null:
		capitulate(warObj(lord, sub), sub, "属国となる")
		warSuccession()
	S_.vassalAt = G.turn
	if facOf(sub) != null: leaveFaction(sub, "quiet")
	if atWar(lord, sub):
		G.dip.truce[lord][sub] = G.turn + DIP.truceTurns; G.dip.truce[sub][lord] = G.turn + DIP.truceTurns
		addFatigue(lord, -20); addFatigue(sub, -20)
	S_.lord = lord; S_.unrest = 0; S_.revoltBuff = 0
	setRel(lord, sub, "ally")
	G.dip.pass[lord][sub] = true; G.dip.pass[sub][lord] = true
	G.dip.allyUntil[lord][sub] = 0; G.dip.allyUntil[sub][lord] = 0
	G.dip.favor[sub][lord] = max(G.dip.favor[sub][lord], 20)
	var msg = "%s が %s の属国となる" % [S_.name, L.name]
	logMsg(msg, "war")
	chron(msg, lord, "gov")
	dipReport("vassal", lord, sub, true, note)
	shareWars(lord, sub)
	invalidateSupply()
func freeVassal(sub: int, why := "") -> void:
	var S_ = NAT(sub)
	if S_.lord == null: return
	var lord: int = S_.lord
	S_.lord = null; S_.unrest = 0
	if NAT(lord).alive and isAlly(lord, sub):
		G.dip.allyUntil[lord][sub] = G.turn + DIP.allyTurns; G.dip.allyUntil[sub][lord] = G.turn + DIP.allyTurns
	var msg = "%s が独立を取り戻す%s" % [S_.name, ("（" + why + "）") if why != "" else ""]
	logMsg(msg, "good")
	chron(msg, sub, "gov")
func startRevolt(sub: int) -> void:
	var S_ = NAT(sub)
	if S_.lord == null: return
	var lord: int = S_.lord
	S_.lord = null; S_.unrest = 0
	S_.revoltBuff = DIP.revoltTurns
	S_.freeUntil = G.turn + DIP.revoltFree
	G.dip.allyUntil[lord][sub] = 0; G.dip.allyUntil[sub][lord] = 0
	G.dip.truce[lord][sub] = 0; G.dip.truce[sub][lord] = 0
	setRel(lord, sub, "war")
	newWar(sub, lord)
	G.dip.pass[lord][sub] = false; G.dip.pass[sub][lord] = false
	addFavor(lord, sub, -100); addFavor(sub, lord, -100)
	for c in G.nations:
		if not c.alive or c.id == sub or c.id == lord: continue
		addFavor(c.id, sub, 4)
	var msg = "%s が %s に反旗を翻す — 独立戦争" % [S_.name, NAT(lord).name]
	logMsg(msg, "war")
	chron(msg, sub, "fall")
	dipReport("revolt", sub, lord, true, "%dターンのあいだ 攻撃+%d%%・防御+%d%%・生産+%d%%／%dターンは再び属国にならない" % [DIP.revoltTurns, int(round(DIP.revoltAtk * 100)), int(round(DIP.revoltDef * 100)), int(round(DIP.revoltProd * 100)), DIP.revoltFree])
	joinWarByPact(sub, lord)
	invalidateSupply()

# ==================== k3c_dip.gd ====================
# 外交 続き（元 5098〜5621）：支援・併合・危うさ・欲求・陣営

# ---------- 属国・同盟国への支援 ----------
func aidLeft(a: int, b: int) -> int: return max(0, G.dip.aid[a][b] + DIP.aidCool - G.turn)
func canAid(a: int, b: int) -> bool:
	if a == b or b < 0 or not NAT(b).alive: return false
	if not isVassal(b, a) and not isAlly(a, b): return false
	return aidLeft(a, b) <= 0
func sendAid(a: int, b: int, kind: String) -> bool:
	var A = NAT(a)
	var B = NAT(b)
	if not canAid(a, b): return false
	var fav = 0
	var un = 0
	var what = ""
	if kind == "gold":
		if A.gold < DIP.aidGold: return false
		A.gold -= DIP.aidGold; B.gold += DIP.aidGold
		fav = DIP.aidGoldFav; un = DIP.aidGoldUnrest; what = "資金 %s G" % fmt(DIP.aidGold)
	elif kind == "food":
		if A.food < DIP.aidFood + 500: return false
		A.food -= DIP.aidFood; B.food = min(foodCap(b), B.food + DIP.aidFood)
		fav = DIP.aidFoodFav; un = DIP.aidFoodUnrest; what = "兵糧 %s" % fmt(DIP.aidFood)
	else:
		if total(A.stock) < DIP.aidTroop: return false
		var left: int = DIP.aidTroop
		var st = float(max(1, total(A.stock)))
		for k in TK:
			var n: int = min(A.stock[k], int(ceil(DIP.aidTroop * (A.stock[k] / st))), left)
			A.stock[k] -= n; B.stock[k] += n; left -= n
		fav = DIP.aidTroopFav; un = DIP.aidTroopUnrest; what = "兵 %s" % fmt(DIP.aidTroop - left)
	G.dip.aid[a][b] = G.turn
	addFavor(b, a, fav)
	if isVassal(b, a): B.unrest = clamp_f(B.get("unrest", 0) + un, 0, DIP.unrestMax)
	var msg = "%s が %s へ %s を援助（好感度 +%d%s）" % [A.name, B.name, what, fav, ("／不満 %d" % un) if isVassal(b, a) else ""]
	logMsg(msg)
	chron(msg, a, "gov")
	return true
func cpuAid(nid: int) -> void:
	var na = NAT(nid)
	for v in vassalsOf(nid):
		var B = NAT(v)
		if not canAid(nid, v): continue
		if B.get("unrest", 0) < 45 and favorOf(v, nid) > 40: continue
		if na.gold > DIP.aidGold * 3:
			sendAid(nid, v, "gold"); return
		if na.food > DIP.aidFood * 4:
			sendAid(nid, v, "food"); return
		if total(na.stock) > DIP.aidTroop * 2:
			sendAid(nid, v, "troop"); return

# ---------- 併合 ----------
func inWar(nid: int) -> bool:
	for o in G.nations:
		if o.alive and o.id != nid and atWar(nid, o.id): return true
	return false
func canAnnex(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0 or not NAT(a).alive or not NAT(b).alive: return false
	if lordOf(a) != null: return false
	if not nationsAdjacent(a, b): return false
	if nationPower(a) / max(1.0, nationPower(b)) < DIP.annexRatio: return false
	if not isVassal(b, a) or NAT(b).get("absorbBy") != null: return false
	if G.turn - NAT(b).get("vassalAt", 0) < DIP.annexHold: return false
	if NAT(b).get("unrest", 0) > DIP.annexUnrest: return false
	if inWar(a) or inWar(b): return false
	return true
func annexAccept(a: int, b: int) -> bool:
	var nb = NAT(b)
	var ratio = nationPower(a) / max(1.0, nationPower(b))
	var terr = 0
	for t in G.terrs:
		if t.owner == b: terr += 1
	var will: float = (ratio - DIP.annexRatio) * 10 + 12
	if isVassal(b, a): will += (DIP.unrestMax - nb.get("unrest", 0)) * 0.45 + favorOf(b, a) * 0.2
	if atWar(a, b): will += warEdge(a, b) * 0.18 + nb.get("fatigue", 0) * 0.35
	will += cpuDanger(b) * 14 - terr * 2.5
	if terr <= 3: will += 20
	return will >= 30
func annex(a: int, b: int, note := "") -> void:
	var A = NAT(a)
	var B = NAT(b)
	var terrs = []
	for t in G.terrs:
		if t.owner == b: terrs.append(t)
	for t in terrs:
		t.owner = a
		t.chaos = max(t.chaos, CFG.chaosTurns)
		t.sec = min(t.sec, CFG.secCapture + 15)
		if t.cap: t.cap = false
		invalidateTerr(t.id)
	G.ownRev = G.get("ownRev", 0) + 1
	var got = 0
	for x in B.armies:
		if x == null: continue
		for k in TK:
			var n = int(round(x.t[k] * DIP.annexTroop))
			A.stock[k] += n; got += n; x.t[k] = 0
	for k in TK:
		var n = int(round(B.stock[k] * DIP.annexTroop))
		A.stock[k] += n; got += n; B.stock[k] = 0
	for i in B.armies.size(): B.armies[i] = null; ARMY_REV += 1
	var gens = []
	for g in B.gens:
		if g != null and gens.size() < DIP.annexGens: gens.append(g)
	for g in gens:
		g.army = null
		if A.gens.size() < GEN_MAX: A.gens.append(g)
	B.gens = []
	A.gold += int(round(B.gold * DIP.annexGold)); B.gold = 0
	A.food += int(round(max(0, B.food) * DIP.annexGold)); B.food = 0
	for v in G.nations:
		if v.alive and v.lord == b: freeVassal(v.id, "主君の併合")
	var wasV = isVassal(b, a)
	B.lord = null; B.unrest = 0
	setRel(a, b, "peace")
	addThreat(a, DIP.annexThreat * 0.5 if wasV else DIP.annexThreat)
	for c in G.nations:
		if not c.alive or c.id == a or c.id == b: continue
		addFavor(c.id, a, DIP.annexOthers)
	var msg = "%s が %s を併合した（%d領地・兵 %s）" % [A.name, B.name, terrs.size(), fmt(got)]
	logMsg(msg, "war")
	chron(msg, a, "end")
	dipReport("annex", a, b, true, note if note != "" else "%d領地と将軍%d名を継承" % [terrs.size(), gens.size()])
	invalidateSupply()
	checkNations()
func cpuAnnex(nid: int) -> bool:
	if randf() > DIP.cpuAnnexChance: return false
	for o in G.nations:
		if o.id == nid or not o.alive: continue
		if not canAnnex(nid, o.id): continue
		if annexAccept(nid, o.id):
			startAbsorb(nid, o.id)
			return true
		dipReport("annex", nid, o.id, false, "国力比 %.2f 倍では呑ませられなかった" % (nationPower(nid) / max(1.0, nationPower(o.id))))
		if isVassal(o.id, nid): NAT(o.id).unrest = clamp_f(NAT(o.id).get("unrest", 0) + 25, 0, DIP.unrestMax)
		else: addFavor(o.id, nid, -12)
		return true
	return false
func startAbsorb(a: int, b: int) -> void:
	NAT(b).absorbBy = a
	var msg = "%s が属国 %s の併合を始める（毎ターン少しずつ組み込む）" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "war")
	chron(msg, a, "gov")
	dipReport("annex", a, b, true, "毎ターン %d 領地ずつ" % DIP.absorbRate)
func absorbTurn() -> void:
	for na in G.nations:
		if not na.alive or na.get("absorbBy") == null: continue
		var a: int = na.absorbBy
		if lordOf(na.id) != a or not NAT(a).alive:
			na.absorbBy = null
			continue
		var own = []
		for t in G.terrs:
			if t.owner == na.id: own.append(t)
		if own.size() <= DIP.absorbRate:
			na.absorbBy = null
			annex(a, na.id, "属国の併合")
			continue
		var cand = []
		for t in own:
			if not t.cap: cand.append(t)
		cand.sort_custom(func(x, y): return contig(x, a) > contig(y, a))
		var pk = cand.slice(0, DIP.absorbRate)
		var names = []
		for t in pk:
			t.owner = a
			t.chaos = max(t.chaos, 1)
			t.sec = min(t.sec, CFG.secCapture + 20)
			invalidateTerr(t.id)
			names.append(t.name)
			for x in na.armies:
				if x != null and x.at == t.id: x.path = []
		G.ownRev = G.get("ownRev", 0) + 1
		if concerns([a, na.id]): logMsg("%s が %s に組み込まれた（%s 残り %d 領地）" % ["・".join(names), NAT(a).name, na.name, own.size() - pk.size()])
func vassalTurn() -> void:
	absorbTurn()
	rebelTurn()
	warTurn()
	for na in G.nations:
		if not na.alive: continue
		if na.get("revoltBuff", 0) > 0: na.revoltBuff -= 1
		var lord = lordOf(na.id)
		if na.lord != null and lord == null:
			freeVassal(na.id, "主君の滅亡")
			continue
		if lord == null:
			na.unrest = max(0, na.get("unrest", 0) - 3)
			continue
		var pw = nationPower(na.id) / max(1.0, nationPower(lord))
		var war = inWar(na.id)
		var up: float = DIP.unrestBase + clamp_f(pw, 0, 2) * DIP.unrestPower + (DIP.unrestWar if war else 0.0)
		if na.get("fatigue", 0) >= CFG.fatMid: up += 1.5
		if hasDesire(na.id, "indep"): up += 2.5
		na.unrest = clamp_f(na.get("unrest", 0) + up, 0, DIP.unrestMax)

# ---------- 生き残りの見立て（0＝安全 / 1以上＝危機） ----------
var DG_CACHE = {}
var DG_KEY = -1
var DG_G = null
func cpuDanger(nid: int) -> float:
	if DG_KEY != STRAT_REV or DG_G != G:
		DG_CACHE = {}
		DG_KEY = STRAT_REV
		DG_G = G
	if DG_CACHE.has(nid): return DG_CACHE[nid]
	var na = NAT(nid)
	if not na.alive:
		DG_CACHE[nid] = 0.0
		return 0.0
	var mine: float = max(1.0, nationPower(nid))
	var foe = 0.0
	var nearFoe = 0.0
	var wars = 0
	for o in G.nations:
		if not o.alive or o.id == nid: continue
		var adj = nationsAdjacent(nid, o.id)
		if atWar(nid, o.id):
			wars += 1
			foe += nationPower(o.id) * (1.0 if adj else 0.4)
		elif adj and (isTense(nid, o.id) or isTopThreat(o.id)):
			nearFoe += nationPower(o.id) * 0.5
	var own = ownCount(nid)
	var d: float = min(1.9, (foe + nearFoe) / mine * 0.5)
	d += max(0, wars - 1) * 0.18
	d += na.get("fatigue", 0) / 180.0
	if na.food <= 0: d += 0.25
	if own <= 3: d += 0.35
	var supply: int = na.supSet.size() if na.get("supSet") is Dictionary else own
	if supply < own * 0.7: d += 0.15
	if lordOf(nid) != null: d -= 0.2
	var v = clamp_f(d, 0, 3)
	DG_CACHE[nid] = v
	return v
func dangerLabel(d: float) -> String: return "安泰" if d < 0.5 else ("警戒" if d < 0.9 else ("危険" if d < 1.4 else "存亡の危機"))
func dangerColor(d: float) -> String: return "#6d9c63" if d < 0.5 else ("#d29b3c" if d < 0.9 else "#c0504a")

# ============================================================
#   国ごとの欲求
# ============================================================
const DESIRE := {
	"port": {"n": "港が欲しい", "war": true, "d": "海への出口や渡し口となる港町を手に入れたい"},
	"land": {"n": "領土が欲しい", "war": true, "d": "豊かな隣の土地を手に入れたい"},
	"reclaim": {"n": "旧領奪還", "war": true, "d": "奪われた土地を取り戻したい"},
	"feud": {"n": "因縁に決着", "war": true, "d": "幾度も争った宿敵を屈服させたい"},
	"indep": {"n": "独立したい", "war": false, "d": "主君のくびきから逃れたい"},
	"protect": {"n": "属国を守りたい", "war": false, "d": "属国を狙う国から守りたい"},
	"prosper": {"n": "国を豊かに", "war": false, "d": "しばらく戦を避け、開発と整備に力を入れたい"},
	"guard": {"n": "守りを固めたい", "war": false, "d": "迫る脅威に備えて国境を固めたい"},
}
var DES = {"max": 2, "review": 6, "life": 40, "warBonus": 45, "warChanceMul": 1.0, "noWishMul": 0.2}
func desiresOf(nid) -> Array:
	if nid == null or nid < 0: return []
	return NAT(nid).get("desires", [])
func hasDesire(nid: int, k: String) -> bool:
	for d in desiresOf(nid):
		if d.k == k: return true
	return false
func desireNat(d: Dictionary) -> int:
	if d.get("t") != null: return T(d.t).owner
	if d.get("o") != null: return d.o
	return -1
func desireVs(nid: int, o: int):
	var best = null
	for d in desiresOf(nid):
		if DESIRE[d.k].war or d.k == "protect" or d.k == "guard":
			if desireNat(d) == o and (best == null or d.w > best.w): best = d
	return best
func desireText(d: Dictionary) -> String:
	var t = T(d.t) if d.get("t") != null else null
	var o = NAT(d.o) if d.get("o") != null else null
	match d.k:
		"port": return "%s の港が欲しい" % t.name
		"land": return "%s の土地が欲しい" % t.name
		"reclaim": return "旧領 %s を取り戻したい" % t.name
		"feud": return "宿敵 %s と決着をつけたい" % o.name
		"indep": return "%s から独立したい" % o.name
		"protect": return "属国 %s を %s から守りたい" % [NAT(d.v).name, o.name]
		"prosper": return "国を豊かにしたい"
		"guard": return "%s に備えて守りを固めたい" % o.name
	return DESIRE[d.k].n
var COAST_G = null
var COAST = {}
var SEA_END = {}
func coastInfo() -> void:
	if COAST_G == G: return
	segNbrs()
	COAST = {}
	SEA_END = {}
	for t in G.terrs:
		for j in t.segN:
			if j < 0:
				COAST[t.id] = true
				break
	for e in G.edges:
		if e.get("sea", false):
			SEA_END[e.a] = true
			SEA_END[e.b] = true
	COAST_G = G
func portValue(t: Dictionary) -> float:
	coastInfo()
	if not COAST.has(t.id): return 0.0
	return 10 + (25 if SEA_END.has(t.id) else 0) + (15 if t.get("trait") == "trade" else 0) + (8 if t.type == "city" and t.dev >= 3 else 0)
func landValue(t: Dictionary) -> float:
	return t.pop / 1000.0 + t.dev * 4 + (12 if ["fertile", "iron", "horse", "trade", "dense"].has(t.get("trait")) else 0) + (15 if t.cap else 0)
func borderTargets(nid: int) -> Array:
	var out = {}
	for t in ownList(nid):
		for n in roadNbrs(t.id):
			var o: int = T(n.to).owner
			if o >= 0 and o != nid: out[n.to] = true
	return out.keys()
func _okTarget(nid: int, o: int, lord) -> bool:
	return o >= 0 and o != nid and NAT(o).alive and lordOf(o) != nid and o != lord and not isAlly(nid, o) and not sameFaction(nid, o)
func desireCands(nid: int) -> Array:
	var na = NAT(nid)
	var c = []
	var mine: float = max(1.0, nationPower(nid))
	var P: String = na.persona
	var lord = lordOf(nid)
	if lord != null:
		var pw = mine / max(1.0, nationPower(lord))
		c.append({"k": "indep", "o": lord, "w": 30 + na.get("unrest", 0) * 0.4 + clamp_f(pw, 0, 1.5) * 25 + (10 if P == "aggr" or P == "fascism" else 0)})
	for v in vassalsOf(nid):
		for o in G.nations:
			if not o.alive or o.id == nid or o.id == v or lordOf(o.id) == nid: continue
			var hostile: bool = atWar(o.id, v) or (isTense(o.id, v) and prepBy(o.id, v) == o.id) or desireVs(o.id, v) != null
			if hostile: c.append({"k": "protect", "o": o.id, "v": v, "w": 55})
	if lord == null:
		for t in G.terrs:
			if t.get("former") != nid or t.owner == nid or not _okTarget(nid, t.owner, lord): continue
			if G.turn - t.get("formerAt", 0) > 60: continue
			c.append({"k": "reclaim", "t": t.id, "w": 35 + landValue(t) * 0.8 + (30 if t.get("wasCap") == nid else 0) - (G.turn - t.get("formerAt", 0)) * 0.3})
		var bt = borderTargets(nid)
		coastInfo()
		var ports = 0
		for t in G.terrs:
			if t.owner == nid and portValue(t) >= 10: ports += 1
		var warlike: float = 8 if P == "aggr" else (0 if P == "bal" else -15)
		for id in bt:
			var t = T(id)
			var o: int = t.owner
			if not _okTarget(nid, o, lord): continue
			var ratio = mine / max(1.0, nationPower(o))
			if ratio < 0.85 or not (atWar(nid, o) or canPrepare(nid, o) or isTense(nid, o)): continue
			var pv = portValue(t)
			if pv > 0: c.append({"k": "port", "t": id, "w": pv + (30 if ports == 0 else (8 if ports < 2 else -10)) + clamp_f(ratio - 1, -1, 1) * 15 + warlike * 0.5})
			c.append({"k": "land", "t": id, "w": landValue(t) + warlike + clamp_f(ratio - 1, -1, 1) * 18})
		for o in G.nations:
			if not _okTarget(nid, o.id, lord) or not natNear(nid, o.id): continue
			var f: int = G.dip.feud[nid][o.id]
			if f >= 2: c.append({"k": "feud", "o": o.id, "w": 25 + f * 12 + (60 - favorOf(nid, o.id)) * 0.2})
	var fat: float = na.get("fatigue", 0)
	c.append({"k": "prosper", "w": 18 + fat * 0.5 + (18 if P == "econ" else (6 if P == "def" else (-12 if P == "aggr" else 0))) + (10 if na.gold < 8000 else 0)})
	var dg = cpuDanger(nid)
	for o in G.nations:
		if not o.alive or o.id == nid or not nationsAdjacent(nid, o.id) or isAlly(nid, o.id): continue
		var r = nationPower(o.id) / mine
		var aim = desireVs(o.id, nid)
		if r >= 1.4 or aim != null or (isTense(o.id, nid) and prepBy(o.id, nid) == o.id):
			c.append({"k": "guard", "o": o.id, "w": 20 + clamp_f(r - 1, 0, 2) * 15 + (18 if aim != null else 0) + dg * 20 + (12 if P == "def" else 0)})
	return c
func desireKey(d: Dictionary) -> String:
	if d.get("t") != null: return d.k + ":t" + str(d.t)
	if d.get("o") != null: return d.k + ":o" + str(d.o)
	return d.k + ":"
func desireDone(nid: int, d: Dictionary) -> bool:
	match d.k:
		"port", "land", "reclaim": return T(d.t).owner == nid
		"feud": return not NAT(d.o).alive or lordOf(d.o) == nid
		"indep": return lordOf(nid) == null
		"protect": return not NAT(d.v).alive or lordOf(d.v) != nid or (not atWar(d.o, d.v) and not isTense(d.o, d.v) and G.turn - d.at >= 8)
		"prosper": return G.turn - d.at >= 25
		"guard": return not NAT(d.o).alive or G.turn - d.at >= 25
	return false
func desireDoneText(d: Dictionary) -> String:
	var t = T(d.t) if d.get("t") != null else null
	var o = NAT(d.o) if d.get("o") != null else null
	match d.k:
		"port": return "%s の港を手に入れた" % t.name
		"land": return "%s を手に入れた" % t.name
		"reclaim": return "旧領 %s を取り戻した" % t.name
		"feud": return ("宿敵 %s を屈服させた" if o.alive else "宿敵 %s は滅んだ") % o.name
		"indep": return "%s から独立した" % o.name
		"protect": return ("属国 %s を守り抜いた" % NAT(d.v).name) if NAT(d.v).alive and lordOf(d.v) != null else ""
	return ""
func desireLost(nid: int, d: Dictionary) -> bool:
	if G.turn >= d.until: return true
	var o = desireNat(d)
	if DESIRE[d.k].war and (o < 0 or o == nid or not NAT(o).alive): return d.k != "feud"
	if DESIRE[d.k].war and o >= 0 and (isAlly(nid, o) or lordOf(o) == nid or lordOf(nid) == o): return true
	return false
func desireLog(nid: int, msg: String, others := [], cls := "") -> void:
	chron(msg, nid, "gov")
	if concerns([nid] + others): logMsg(msg, cls)
func desireTurn(nid: int) -> void:
	var na = NAT(nid)
	if not na.alive: return
	if not na.has("desires"): na.desires = []
	for d in na.desires.duplicate():
		if desireDone(nid, d):
			na.desires.erase(d)
			var txt = desireDoneText(d)
			if txt != "": desireLog(nid, "%s、望みを果たす — %s" % [na.name, txt], [desireNat(d)], "good")
		elif desireLost(nid, d):
			na.desires.erase(d)
			if concerns([nid]): logMsg("%s は「%s」を諦めた" % [na.name, desireText(d)])
	var due: bool = (G.turn + nid) % DES.review == 0 or na.desires.is_empty()
	if not due or na.desires.size() >= DES.max: return
	var have = {}
	for d in na.desires: have[desireKey(d)] = true
	var peaceful = false
	var warlike = false
	for d in na.desires:
		if d.k == "prosper": peaceful = true
		if DESIRE[d.k].war: warlike = true
	var pool = []
	for x in desireCands(nid):
		if have.has(desireKey(x)) or x.w < 30: continue
		if peaceful and DESIRE[x.k].war: continue
		if warlike and x.k == "prosper": continue
		var dup = false
		if x.get("t") != null:
			for d in na.desires:
				if d.get("t") != null and T(d.t).owner == T(x.t).owner and d.k == x.k: dup = true
		if dup: continue
		pool.append(x)
	if pool.is_empty(): return
	pool.sort_custom(func(a, b): return a.w > b.w)
	var top3 = pool.slice(0, 3)
	var pickD: Dictionary = top3[0] if randf() < 0.6 else top3[randi() % top3.size()]
	var d = pickD.duplicate()
	d.at = G.turn
	d.until = G.turn + DES.life + ri(-8, 8)
	na.desires.append(d)
	if d.k == "feud" or d.k == "reclaim":
		grantCB(nid, desireNat(d), ("%s との因縁" % NAT(d.o).name) if d.k == "feud" else ("%s の奪還" % T(d.t).name), DES.life)
	if d.k == "protect": grantCB(nid, d.o, "属国 %s の防衛" % NAT(d.v).name, 30)
	desireLog(nid, "%s の望み：%s" % [na.name, desireText(d)], [desireNat(d)])

# ============================================================
#   陣営
# ============================================================
var FAC = {"ratio": 1.5, "createChance": 0.08, "inviteChance": 0.3, "leaveFavor": -20, "inviteFavor": 50}
func facOf(n):
	if n == null or n < 0: return null
	var na = NAT(n)
	var f = na.get("faction")
	if f == null or not G.has("factions"): return null
	return G.factions.get(f)
func sameFaction(a: int, b: int) -> bool:
	if a == b: return false
	var fa = facOf(a)
	return fa != null and fa == facOf(b)
func avgPower() -> float:
	var s = 0.0
	var n = 0
	for x in G.nations:
		if x.alive:
			s += nationPower(x.id)
			n += 1
	return s / max(1, n)
func canMakeFaction(n: int) -> bool:
	var na = NAT(n)
	return na.alive and facOf(n) == null and lordOf(n) == null and nationPower(n) >= avgPower() * FAC.ratio
func makeFaction(n: int, name0 := "") -> void:
	if not G.has("factions"): G.factions = {}
	G.facSeq = G.get("facSeq", 0) + 1
	var id: int = G.facSeq
	var nm: String = NAT(n).name
	if nm.ends_with("都") or nm.ends_with("道") or nm.ends_with("府") or nm.ends_with("県"): nm = nm.substr(0, nm.length() - 1)
	nm += "陣営"
	if name0 != "": nm = name0
	G.factions[id] = {"id": id, "name": nm, "leader": n, "members": [n], "t0": G.turn}
	NAT(n).faction = id
	var msg = "%s が「%s」を結成する" % [NAT(n).name, nm]
	headline("「%s」結成" % nm, "盟主 %s" % natLabel(n))
	logMsg(msg, "good")
	chron(msg, n, "dip")
	dipReport("faction", n, n, true, "盟主として近くの国を招きます")
func joinFaction(F: Dictionary, n: int) -> void:
	if not F.members.has(n): F.members.append(n)
	NAT(n).faction = F.id
	for m in F.members:
		if m != n:
			addFavor(m, n, 10); addFavor(n, m, 10)
	var msg = "%s が「%s」に加わる" % [NAT(n).name, F.name]
	if concerns([n] + F.members): logMsg(msg, "good")
	chron(msg, n, "dip")
func leaveFaction(n: int, why := "") -> void:
	var F = facOf(n)
	if F == null: return
	F.members.erase(n)
	NAT(n).faction = null
	if why != "quiet":
		for m in F.members:
			addFavor(m, n, FAC.leaveFavor); addFavor(n, m, FAC.leaveFavor)
		var msg = "%s が「%s」を離脱する%s" % [NAT(n).name, F.name, ("（" + why + "）") if why != "" else ""]
		if concerns([n] + F.members): logMsg(msg, "war")
		chron(msg, n, "dip")
		dipReport("unfaction", n, F.leader, true, why)
	facCheck(F)
func facCheck(F: Dictionary) -> void:
	var mem = []
	for m in F.members:
		if NAT(m).alive and NAT(m).get("faction") == F.id: mem.append(m)
	F.members = mem
	if mem.is_empty():
		G.factions.erase(F.id)
		chron("「%s」が解散する" % F.name, F.leader, "dip")
		return
	if not mem.has(F.leader):
		var s = mem.duplicate()
		s.sort_custom(func(x, y): return nationPower(x) > nationPower(y))
		F.leader = s[0]
		chron("「%s」の盟主が %s に代わる" % [F.name, NAT(F.leader).name], F.leader, "dip")
func _facWorth(nid: int, F: Dictionary, o: Dictionary, facPow: float, top0) -> float:
	var w = favorOf(nid, o.id) + favorOf(o.id, nid) * 0.5
	var front = false
	for c in G.nations:
		if not c.alive or not nationsAdjacent(o.id, c.id): continue
		for m in F.members:
			if atWar(m, c.id):
				front = true
				break
		if front: break
	if front: w += 20
	if top0 != null and not F.members.has(top0.id) and nationsAdjacent(o.id, top0.id): w += 12
	for c in G.nations:
		if c.alive and isTense(o.id, c.id) and nationPower(c.id) > facPow * 0.6:
			w -= 40
			break
	w += nationPower(o.id) / max(1.0, facPow) * 30
	w -= max(0, F.members.size() - 3) * 12
	return w
func cpuFaction(nid: int) -> void:
	var na = NAT(nid)
	if not na.alive: return
	if lordOf(nid) != null:
		if facOf(nid) != null: leaveFaction(nid, "quiet")
		return
	var F = facOf(nid)
	if F == null and canMakeFaction(nid) and randf() < FAC.createChance:
		makeFaction(nid)
		F = facOf(nid)
	if F != null and F.leader == nid and randf() < FAC.inviteChance:
		var cand = []
		for o in G.nations:
			if not o.alive or o.id == nid or facOf(o.id) != null or lordOf(o.id) != null: continue
			var near = false
			var war = false
			for m in F.members:
				if natNear(m, o.id): near = true
				if atWar(m, o.id): war = true
			if not near or war: continue
			if favorOf(nid, o.id) < FAC.inviteFavor - 10: continue
			cand.append(o)
		var facPow = 0.0
		for m in F.members: facPow += nationPower(m)
		var top0 = topThreat()
		var smart = smartAI(nid)
		if smart:
			var ws = {}
			for o in cand: ws[o.id] = _facWorth(nid, F, o, facPow, top0)
			cand.sort_custom(func(x, y): return ws[x.id] > ws[y.id])
		else:
			cand.sort_custom(func(x, y): return favorOf(x.id, nid) > favorOf(y.id, nid))
		var o = null
		if cand.size() and (not smart or _facWorth(nid, F, cand[0], facPow, top0) > 40): o = cand[0]
		if o != null:
			var common = false
			for c in G.nations:
				if not c.alive or not atWar(o.id, c.id): continue
				for m in F.members:
					if atWar(m, c.id): common = true
			var top = topThreat()
			var vsTop: bool = top != null and not F.members.has(top.id) and natHops(o.id, top.id) <= 2
			var sc = (favorOf(o.id, nid) - 50) * 0.8 + cpuDanger(o.id) * 35 + (20 if common else 0) + (15 if vsTop else 0) \
				+ (25 if o.get("ideo") == na.get("ideo") else -20) - (25 if nationPower(o.id) > nationPower(nid) * 0.8 else 0) + 10
			for d in desiresOf(o.id):
				if DESIRE[d.k].war and F.members.has(desireNat(d)):
					sc -= 40
					break
			if not facFit(o.id, F.leader): sc = -999
			if sc >= 20:
				joinFaction(F, o.id)
				dipReport("faction", nid, o.id, true, "「%s」への招待に応じた" % F.name)
			else:
				dipReport("faction", nid, o.id, false, "「%s」への招待を断った" % F.name)
				addFavor(nid, o.id, -2)
	if F != null and F.leader != nid and G.factions.has(F.id):
		var wantOut = favorOf(nid, F.leader) < 25
		if NAT(F.leader).get("ideo") != na.get("ideo") and randf() < 0.3: wantOut = true
		if not wantOut:
			for d in desiresOf(nid):
				if DESIRE[d.k].war and F.members.has(desireNat(d)): wantOut = true
		if wantOut and randf() < 0.3:
			leaveFaction(nid, "盟主との不和" if favorOf(nid, F.leader) < 25 else "加盟国の土地を望んで")
	F = facOf(nid)
	if F != null:
		for m in F.members:
			if m != nid and favorOf(nid, m) < 80: addFavor(nid, m, 0.8)
func factionCallToArms(a: int, b: int) -> void:
	var wid = warOf(a, b)
	var Fb = facOf(b)
	if Fb != null:
		for m in Fb.members.duplicate():
			if m == b or not NAT(m).alive or atWar(m, a) or sameFaction(m, a): continue
			# 敵から遠い加盟国は戦わない（遠くの国まで一斉に参戦する連鎖を防ぐ）
			if not natNear(m, a): continue
			enterWar(m, a, "「%s」の加盟国 %s を守るため参戦" % [Fb.name, NAT(b).name], wid)
	var Fa = facOf(a)
	if Fa != null:
		for m in Fa.members.duplicate():
			if m == a or not NAT(m).alive or atWar(m, b) or sameFaction(m, b): continue
			var ok: bool = favorOf(m, a) >= 50 and pactLeft(m, b) <= 0 and natNear(m, b) and not isAlly(m, b) and NAT(m).get("fatigue", 0) < DIP.fatiguePeace
			if ok: enterWar(m, b, "「%s」の呼びかけに応じて参戦" % Fa.name, wid)
			elif concerns([m, a]): dipReport("join", m, b, false, "「%s」の呼びかけに応じなかった" % Fa.name)

# ==================== k4_strat.gd ====================
# 滅びた国の蜂起・CPUの外交戦略（元 5622〜6006）

var REB = {"base": 0.6, "lowSec": 1.4, "war": 0.7, "need": 100, "minDead": 20, "takeRate": 0.25, "takeMin": 2, "takeMax": 6}
func rebelTurn() -> void:
	for D in G.nations:
		if D.alive: continue
		var home = []
		for t in G.terrs:
			if t.get("home") == D.id and t.owner >= 0 and t.owner != D.id: home.append(t)
		if home.size() < 2: continue
		var low = 0
		var war = 0
		for t in home:
			if t.sec < 50: low += 1
			if inWar(t.owner): war += 1
		D.rebel = clamp_f(D.get("rebel", 0) + REB.base + float(low) / home.size() * REB.lowSec + float(war) / home.size() * REB.war, 0, REB.need)
		if D.rebel >= REB.need and G.turn - D.get("diedAt", 0) >= REB.minDead:
			var sd = rebelSeed(home)
			if sd == null: continue
			var X: int = sd.owner
			var near = {}
			for t in home:
				if t.owner == X: near[t.id] = true
			var guard = 0
			for a in NAT(X).armies:
				if a == null: continue
				var hit: bool = near.has(a.at)
				if not hit:
					for n in roadNbrs(a.at):
						if near.has(n.to):
							hit = true
							break
				if hit: guard += total(a.t)
			var levy = 0.0
			for t in home: levy += t.pop
			levy *= REB.takeRate * 0.18
			D.rebelWait = D.get("rebelWait", 0) + 1
			if inWar(X) or guard < levy * 1.5 or D.rebelWait >= 15:
				D.rebelWait = 0
				reviveNation(D, home)
func rebelSeed(home: Array):
	for t in home:
		if t.get("homeCap", false) and not t.cap: return t
	var c = []
	for t in home:
		if not t.cap: c.append(t)
	if c.is_empty(): return null
	c.sort_custom(func(x, y): return x.dev > y.dev if x.dev != y.dev else x.pop > y.pop)
	return c[0]
func reviveNation(D: Dictionary, home: Array) -> void:
	var seed = rebelSeed(home)
	if seed == null: return
	var X: int = seed.owner
	var n = int(clamp_f(round(home.size() * REB.takeRate), REB.takeMin, REB.takeMax))
	var take = [seed]
	var seen = {seed.id: true}
	var i = 0
	while i < take.size() and take.size() < n:
		for nb in roadNbrs(take[i].id):
			var t = T(nb.to)
			if take.size() >= n or seen.has(nb.to) or t.get("home") != D.id or t.owner != X or t.cap: continue
			seen[nb.to] = true
			take.append(t)
		i += 1
	for t in take:
		t.owner = D.id
		t.chaos = max(t.chaos, 2)
		t.sec = max(t.sec, 55)
		for na in G.nations:
			for a in na.armies:
				if a != null and a.at == t.id and a.owner == X: a.at = nearestOwnTerr(X, t.id); ARMY_REV += 1
		invalidateTerr(t.id)
	G.ownRev = G.get("ownRev", 0) + 1
	for t in G.terrs:
		if t.owner == D.id: t.cap = false
	seed.cap = true
	D.alive = true; D.capital = seed.id; D.lord = null; D.faction = null; D.unrest = 0; D.rebel = 0
	D.fatigue = 0; D.desires = []; D.revoltBuff = DIP.revoltTurns; D.freeUntil = G.turn + DIP.revoltFree
	D.gold = max(D.get("gold", 0), 8000); D.food = max(D.get("food", 0), 3000)
	var arm = []
	arm.resize(ARMY_MAX)
	D.armies = arm; ARMY_REV += 1
	D.gens = []
	var pop = 0.0
	for t in take: pop += t.pop
	var levy = int(round(pop * 0.18))
	var g = mkGen(G, D, randomPts())
	var a0 = mkArmy(D.id, 0, seed.id)
	a0.t.inf = int(round(levy * 0.6)); a0.t.spe = int(round(levy * 0.25)); a0.t.arc = levy - a0.t.inf - a0.t.spe
	a0.target = a0.t.duplicate()
	a0.gen = g.id
	g.army = 0
	D.armies[0] = a0; ARMY_REV += 1
	for o in G.nations:
		if o.id != D.id:
			G.dip.state[D.id][o.id] = "peace"; G.dip.state[o.id][D.id] = "peace"
			G.dip.favor[D.id][o.id] = 30; G.dip.favor[o.id][D.id] = 30
			setWarId(D.id, o.id, 0)
	setRel(D.id, X, "war")
	newWar(D.id, X)
	G.dip.pass[D.id][X] = false; G.dip.pass[X][D.id] = false
	addFavor(D.id, X, -100); addFavor(X, D.id, -60)
	var names = []
	for t in take: names.append(t.name)
	var msg = "%s、旧領 %s で蜂起し復活 — %s と独立戦争" % [D.name, "・".join(names), NAT(X).name]
	logMsg(msg, "war")
	chron(msg, D.id, "fall")
	dipReport("revolt", D.id, X, true, "旧領の民が立ち上がった（%d領地・兵 %s）" % [take.size(), fmt(levy)])
	nations_changed.emit()
	invalidateSupply()
signal nations_changed
func nearestOwnTerr(n: int, from: int) -> int:
	var b = bfsFrom(from)
	var best = from
	var bd = INF
	for t in G.terrs:
		if t.owner == n and bhas(b, t.id) and b.d[t.id] < bd:
			bd = b.d[t.id]
			best = t.id
	return best

# ---------- CPU の戦略：戦う前に「相手の陣営ごと」の力を見積もる ----------
func smartAI(nid: int) -> bool: return not G.has("abTest") or G.abTest == null or G.abTest.get(nid, false)
func busyFrac(o: int) -> float:
	var foe = 0.0
	for x in G.nations:
		if x.alive and x.id != o and atWar(o, x.id) and nationsAdjacent(o, x.id): foe += nationPower(x.id)
	return clamp_f(foe / max(1.0, nationPower(o) + foe), 0, 0.6) if foe else 0.0
func defCoalition(a: int, b: int) -> float:
	var p = nationPower(b) * (1 - busyFrac(b) * 0.6)
	var seen = {a: true, b: true}
	var Fb = facOf(b)
	if Fb != null:
		for m in Fb.members:
			if not seen.has(m) and NAT(m).alive and not sameFaction(m, a):
				seen[m] = true
				p += nationPower(m) * (0.8 if natNear(m, a) else 0.35)
	for id in campOf(b):
		if seen.has(id) or not NAT(id).alive or atWar(id, a) or isAlly(id, a): continue
		var bound = isVassal(id, b) or isVassal(b, id)
		if not bound and (pactLeft(id, a) > 0 or not natNear(id, a)): continue
		seen[id] = true
		p += nationPower(id) * 0.8
	return max(1.0, p)
func atkCoalition(a: int, b: int) -> float:
	var p = nationPower(a)
	var seen = {a: true, b: true}
	var Fa = facOf(a)
	if Fa != null:
		for m in Fa.members:
			if not seen.has(m) and NAT(m).alive and favorOf(m, a) >= 50 and natNear(m, b) and pactLeft(m, b) <= 0 and not isAlly(m, b):
				seen[m] = true
				p += nationPower(m) * 0.5
	for id in campOf(a):
		if seen.has(id) or not NAT(id).alive or isAlly(id, b): continue
		var bound = isVassal(id, a) or isVassal(a, id)
		if not bound and (favorOf(id, a) < 45 or not natNear(id, b) or pactLeft(id, b) > 0): continue
		seen[id] = true
		p += nationPower(id) * (0.8 if bound else 0.5)
	return p
func cpuDiplomacy(nid: int) -> void:
	var na = NAT(nid)
	if not na.alive: return
	_tp("desire")
	await yieldMaybe()
	desireTurn(nid)
	_tp("faction")
	await yieldMaybe()
	cpuFaction(nid)
	_tp("vassal")
	await yieldMaybe()
	var myLord = lordOf(nid)
	if myLord != null:
		cpuVassal(nid, myLord)
		return
	cpuAid(nid)
	if cpuAnnex(nid): return
	cpuVassalOffer(nid)
	var P: Dictionary = PERSONA.get(na.persona, PERSONA.neutral)
	var top = topThreat()
	var iAmTop: bool = top != null and top.id == nid
	var myTgt = {}
	for d in desiresOf(nid):
		if DESIRE[d.k].war: myTgt[desireNat(d)] = true
	var myWars = []
	for c in G.nations:
		if c.alive and atWar(nid, c.id): myWars.append(c.id)
	_tp("drift")
	await yieldMaybe()
	# 好感度の自然変動
	for o in G.nations:
		if o.id == nid or not o.alive: continue
		var st = relState(nid, o.id)
		var dvs = desireVs(o.id, nid)
		var aimsMe: bool = st != "war" and dvs != null and DESIRE[dvs.k].war
		var sameTgt = false
		if st != "war" and natNear(nid, o.id):
			for d in desiresOf(o.id):
				if DESIRE[d.k].war and myTgt.has(desireNat(d)):
					sameTgt = true
					break
		var common = false
		for c in myWars:
			if c != o.id and atWar(o.id, c):
				common = true
				break
		var d: float = DIP.driftWar if st == "war" else (DIP.driftAlly if st == "ally" else DIP.driftPeace)
		var cap: float = DIP.driftCap
		if st != "war" and common and natNear(nid, o.id):
			d = DIP.driftCommon; cap = DIP.driftCommonCap
		if top != null and top.id == o.id and st != "ally":
			d = min(d, DIP.threatDrift * (1 + top.v / 120.0)); cap = -100
		elif top != null and not iAmTop and top.id != o.id and st != "war" and natNear(nid, o.id) \
				and natHops(nid, top.id) <= DIP.reach and natHops(o.id, top.id) <= DIP.reach:
			d = max(d, DIP.driftCommon); cap = DIP.driftCommonCap
		if sameTgt:
			d = max(d, DIP.driftCommon); cap = max(cap, 80)
		if aimsMe:
			d = min(d, -0.5); cap = min(cap, 40)
		var f = favorOf(nid, o.id)
		if d > 0 and f >= cap: continue
		if aimsMe and d < 0 and st != "war" and f <= 25: continue
		addFavor(nid, o.id, d)
	_tp("peace")
	await yieldMaybe()
	# 和平を考える
	for o in G.nations:
		if o.id == nid or not o.alive or not atWar(nid, o.id): continue
		if not warLeaders(nid, o.id): continue
		if G.turn - G.dip.peaceAt[nid][o.id] < DIP.peaceCool: continue
		if warObj(nid, o.id) == null and lordOf(o.id) != null: continue
		var turns: int = G.turn - G.dip.since[nid][o.id]
		var mine = nationPower(nid)
		var theirs = nationPower(o.id)
		var minT: int = 3 if goalDone(nid, o.id) else (min(4, DIP.cpuPeaceTurns) if cpuDanger(nid) >= 1.1 else DIP.cpuPeaceTurns)
		if turns < minT: continue
		var fat: float = na.get("fatigue", 0)
		var dg = cpuDanger(nid)
		var Wp = warObj(nid, o.id)
		var nearCap: bool = Wp != null and surrenderProg(Wp, nid) >= surrenderLimit(nid) * 0.7
		var fascP: bool = na.get("ideo") == "fascism"
		# ファシズムの国は負けていても粘る（国力が相手の5割を切るまで講和に応じにくい）
		var wantPeace: bool = goalDone(nid, o.id) or nearCap or mine < theirs * (0.5 if fascP else 0.8) or fat >= DIP.fatiguePeace or dg >= 0.9 \
			or (dg >= 0.6 and not isTopThreat(o.id)) \
			or randf() < (0.08 + fat / 400.0 + P.peaceW + ((G.turn - Wp.t0) / 80.0 if Wp != null else 0.0)) * (0.4 if fascP else 1.0)
		if not wantPeace: continue
		var terms = cpuPeaceTerms(nid, o.id)
		G.dip.peaceAt[nid][o.id] = G.turn; G.dip.peaceAt[o.id][nid] = G.turn
		if peaceAccept(nid, o.id, terms) and favorOf(o.id, nid) >= -60:
			var lines: Array = settlePeace(nid, o.id, terms)
			dipReport("peace", nid, o.id, true, "／".join(lines) if lines.size() else "白紙和平")
		else:
			dipReport("peace", nid, o.id, false, "戦勝点差 %d ／ 戦って%dターン" % [warEdge(nid, o.id), turns])
	_tp("ally")
	await yieldMaybe()
	# 同盟（近くの国と、共通の敵がいる時だけ）
	for o in G.nations:
		if o.id == nid or not o.alive or relState(nid, o.id) != "peace": continue
		if not natNear(nid, o.id): continue
		var common = false
		for c in myWars:
			if c != o.id and atWar(o.id, c) and natNear(nid, c) and natNear(o.id, c):
				common = true
				break
		if not common:
			for d in desiresOf(o.id):
				if DESIRE[d.k].war and myTgt.has(desireNat(d)):
					common = true
					break
		if not common and smartAI(nid):
			for c in G.nations:
				if c.alive and c.id != o.id and isTense(nid, c.id) and prepBy(nid, c.id) == c.id \
						and natNear(o.id, c.id) and not isAlly(o.id, c.id) and nationPower(c.id) > nationPower(nid) * 0.8:
					common = true
					break
		var vsTop: bool = top != null and not iAmTop and top.id != o.id and natHops(nid, top.id) <= DIP.reach and natHops(o.id, top.id) <= DIP.reach
		if not common and not vsTop: continue
		if allyDrags(nid, o.id): continue
		if not ideoCompat(nid, o.id): continue
		var need: float = DIP.allyMin - (8 if common else 0) - (DIP.threatAllyEase if vsTop else 0)
		var need2: float = need - 6 if vsTop and nationsAdjacent(nid, top.id) else need
		if favorOf(nid, o.id) < need2: continue
		if favorOf(o.id, nid) >= need2:
			makeAlly(nid, o.id)
			break
		if randf() < 0.5:
			dipReport("ally", nid, o.id, false, "先方の好感度 %d ／ 必要 %d" % [int(round(favorOf(o.id, nid))), int(round(need2))])
			addFavor(nid, o.id, -2)
			break
	_tp("ties")
	await yieldMaybe()
	cpuPeaceTies(nid, P)
	_tp("declare")
	await yieldMaybe()
	# 準備していた相手へ宣戦布告
	for o in G.nations:
		if o.id == nid or not o.alive: continue
		if not canDeclareWar(nid, o.id): continue
		var sm2 = smartAI(nid)
		var mine2: float = atkCoalition(nid, o.id) if sm2 else nationPower(nid)
		var th2: float = defCoalition(nid, o.id) if sm2 else max(1.0, nationPower(o.id))
		var forced: bool = na.get("forceWar", -1) == o.id and mine2 >= th2 * 0.8
		if (not forced and mine2 < th2 * ((0.6 if na.persona == "fascism" else 0.85) if sm2 else 0.7)) or na.get("fatigue", 0) >= DIP.fatiguePeace:
			cancelWarPrep(nid, o.id)
			G.dip.cool[nid][o.id] = G.turn + 5; G.dip.cool[o.id][nid] = G.turn + 5
			continue
		na.forceWar = -1
		declareWar(nid, o.id)
		return
	_tp("prep")
	await yieldMaybe()
	# 開戦準備
	for o in G.nations:
		if o.alive and (atWar(nid, o.id) or isTense(nid, o.id)): return
	if inCalm(): return
	if na.get("fatigue", 0) >= DIP.fatiguePeace: return
	var danger = cpuDanger(nid)
	if danger >= 1.0: return
	if not hoiWarOK(nid): return
	if na.food <= 0: return
	if smartAI(nid):
		var ownN = 0
		for t in ownList(nid): ownN += 1
		var goalT: float = clamp_f(3500 + ownN * 700, 3500, 34000) * P.goal
		if nationTroops(nid) < goalT * 2: return
	var des = desiresOf(nid)
	var wantWar = false
	var guarding = false
	var fasc0: bool = na.persona == "fascism"
	for d in des:
		# 富国の望みがあると戦わない（ファシズムの国と、世界の緊張が高い時は別）
		if d.k == "prosper" and not fasc0 and tension() < 60: return
		if DESIRE[d.k].war or d.k == "protect": wantWar = true
		if d.k == "guard": guarding = true
	var chanceMul: float = DES.warChanceMul if wantWar else (0.4 if guarding else (DES.noWishMul if G.nations.size() > 16 else 0.8))
	var fasc: bool = na.persona == "fascism"
	if randf() > DIP.cpuWarChance.get(na.persona, 0.2) * (max(0.7, crowdMul()) if fasc else crowdMul()) * (max(1.0, chanceMul) if fasc else chanceMul) * (1.0 + tension() / 35.0): return
	var mine = nationPower(nid)
	var ambition: float = min(DIP.cpuAmbitionMax, G.turn * DIP.cpuAmbition)
	var needW: float = DIP.cpuWarNeed.get(na.persona, 34)
	var cand = []
	var topT = topThreat()
	for o in G.nations:
		if o.id == nid or not o.alive or not canPrepare(nid, o.id): continue
		if not nationsAdjacent(nid, o.id): continue
		var dv = desireVs(nid, o.id)
		var sm = smartAI(nid)
		var th: float = defCoalition(nid, o.id) if sm else max(1.0, nationPower(o.id))
		var mineC: float = atkCoalition(nid, o.id) if sm else mine
		# 守りを固めたい時は、望みのある相手だけを狙う（ファシズムの国は、相手より1.3倍以上強ければ構わず狙う）
		if guarding and dv == null and not (fasc0 and mineC >= th * 1.3): continue
		var cb = hasCB(nid, o.id)
		if not cb and na.get("ideo") == "democracy": continue
		if not cb and not (mineC >= th * 1.8 and randf() < P.noCB): continue
		if sm and mineC < th * (0.7 if fasc else 0.95): continue
		var sc: float = (mineC / th - 1) * 100 + (60 - favorOf(nid, o.id)) + ambition \
			+ (15 if sm and busyFrac(o.id) > 0.2 else 0) \
			+ threatOf(o.id) * DIP.threatWarBonus - danger * DIP.dangerWeight
		if topT != null and topT.id != o.id and nationsAdjacent(nid, topT.id): sc -= 45
		if isTopThreat(o.id): sc += 20
		if isTrade(nid, o.id): sc -= 15
		if not cb: sc -= 15
		elif fasc: sc += 25
		if resWant(nid, o.id): sc += 12   # 足りない資源を持つ隣国を狙う
		if dv != null: sc += 10 if dv.k == "guard" else DES.warBonus
		if sc >= needW: cand.append({"id": o.id, "sc": sc})
	if cand.is_empty():
		cpuFabricate(nid, P, mine)
		return
	cand.sort_custom(func(x, y): return x.sc > y.sc)
	startWarPrep(nid, cand[0].id)
func allyDrags(a: int, b: int) -> bool:
	for o in G.nations:
		if not o.alive or o.id == a or o.id == b: continue
		if atWar(a, o.id) != atWar(b, o.id): return true
	return false
func crowdMul() -> float:
	var n = 0
	for x in G.nations:
		if x.alive: n += 1
	return min(1.0, pow(10.0 / max(1, n), 0.65))
func cpuPeaceTies(nid: int, P: Dictionary) -> void:
	var war = inWar(nid)
	if tradePartners(nid).size() < TRADE.max and randf() < 0.12 + P.tradeW / 150.0:
		var cs = []
		for x in G.nations:
			if x.alive and x.id != nid and tradeReason(nid, x.id) == "" and favorOf(nid, x.id) >= tradeNeed(nid) - 5: cs.append(x)
		cs.sort_custom(func(x, y): return favorOf(x.id, nid) > favorOf(y.id, nid))
		if cs.size():
			var o = cs[0]
			if favorOf(o.id, nid) >= tradeNeed(o.id): makeTrade(nid, o.id)
	if P.pactW > -20 and randf() < 0.25 + P.pactW / 80.0:
		var mine = nationPower(nid)
		var cs2 = []
		for x in G.nations:
			if x.alive and x.id != nid and relState(nid, x.id) == "peace" and pactLeft(nid, x.id) <= 0 and nationsAdjacent(nid, x.id) \
					and not hasCB(nid, x.id) and not wantsLand(nid, x.id) and not wantsLand(x.id, nid) and favorOf(nid, x.id) >= pactNeed(nid) - 10 \
					and (nationPower(x.id) > mine * 0.9 or war or cpuDanger(nid) >= 0.6):
				cs2.append(x)
		cs2.sort_custom(func(x, y): return nationPower(x.id) > nationPower(y.id))
		if cs2.size():
			var o = cs2[0]
			var greedy: bool = (o.persona == "aggr" or o.persona == "fascism") and nationPower(o.id) > mine * 1.3
			if favorOf(o.id, nid) >= pactNeed(o.id) and not greedy: makePact(nid, o.id)
func cpuFabricate(nid: int, P: Dictionary, mine: float) -> void:
	if not (P.fab > 0) or randf() > P.fab * crowdMul(): return
	var na = NAT(nid)
	if na.has("ideo") and na.ws < wsNeedOf(na) - 10: return
	if na.gold < CASUS.fabGold + 4000: return
	for o in G.nations:
		if o.alive and fabLeft(nid, o.id) > 0: return
	for d in desiresOf(nid):
		if not DESIRE[d.k].war: continue
		var x = desireNat(d)
		if x >= 0 and NAT(x).alive and canPrepare(nid, x) and nationsAdjacent(nid, x) and not hasCB(nid, x) and mine >= nationPower(x) * 1.1:
			startFabricate(nid, x)
			return
	var cs = []
	for x in G.nations:
		if x.alive and x.id != nid and canPrepare(nid, x.id) and nationsAdjacent(nid, x.id) \
				and not hasCB(nid, x.id) and favorOf(nid, x.id) < 45 and mine >= nationPower(x.id) * 1.25:
			cs.append(x)
	cs.sort_custom(func(x, y): return nationPower(x.id) < nationPower(y.id))
	if cs.size(): startFabricate(nid, cs[0].id)
func cpuVassal(nid: int, lord: int) -> void:
	var na = NAT(nid)
	if na.get("unrest", 0) < DIP.unrestMax: return
	var pw = nationPower(nid) / max(1.0, nationPower(lord))
	var lordWar = 0
	for o in G.nations:
		if o.alive and atWar(lord, o.id) and o.id != nid: lordWar += 1
	var ch = 0.12 + clamp_f(pw - 0.5, 0, 1.2) * 0.5 + lordWar * 0.12
	if na.persona == "aggr" or na.persona == "fascism": ch += 0.12
	if na.persona == "econ" or na.persona == "neutral": ch -= 0.06
	if hasDesire(nid, "indep"): ch += 0.15
	if randf() < ch: startRevolt(nid)
func cpuVassalOffer(nid: int) -> void:
	if inCalm(): return
	var warring = inWar(nid)
	if not warring and wildCount() > G.terrs.size() * 0.15: return
	if randf() > DIP.cpuVassalAsk: return
	var cand = []
	for o in G.nations:
		if o.id == nid or not o.alive: continue
		if not canAskVassal(nid, o.id): continue
		if not atWar(nid, o.id) and not nationsAdjacent(nid, o.id): continue
		if atWar(nid, o.id) and warEdge(nid, o.id) < WAR.vassalEdge: continue
		cand.append(o.id)
	if cand.is_empty(): return
	cand.sort_custom(func(x, y): return nationPower(x) > nationPower(y))
	var target: int = cand[0]
	if vassalAccept(nid, target):
		makeVassal(nid, target, "降伏による従属" if atWar(nid, target) else "力の差による従属")
	else:
		dipReport("vassal", nid, target, false, "国力比 %.2f 倍 ／ 好感度 %d" % [nationPower(nid) / max(1.0, nationPower(target)), int(round(favorOf(target, nid)))])
		addFavor(target, nid, -8)

# 国どうしの近さ：国境をいくつ越えれば届くか
var HOP_G = null
var HOP_KEY = -1
var HOPS = []
func natHops(a: int, b: int) -> int:
	if a == b: return 0
	if a < 0 or b < 0: return 99
	var k = STRAT_REV
	if HOP_G != G or HOP_KEY != k:
		var n: int = G.nations.size()
		var adj = []
		for i in n: adj.append({})
		for e in G.edges:
			var oa: int = T(e.a).owner
			var ob: int = T(e.b).owner
			if oa >= 0 and ob >= 0 and oa != ob:
				adj[oa][ob] = true
				adj[ob][oa] = true
		HOPS = []
		for s0 in n:
			var d = []
			d.resize(n)
			d.fill(99)
			d[s0] = 0
			var q = [s0]
			var i = 0
			while i < q.size():
				for v in adj[q[i]]:
					if d[v] == 99:
						d[v] = d[q[i]] + 1
						q.append(v)
				i += 1
			HOPS.append(d)
		HOP_G = G
		HOP_KEY = k
	return HOPS[a][b] if a < HOPS.size() else 99
func natNear(a: int, b: int) -> bool: return natHops(a, b) <= DIP.reach
var ADJ_KEY = -1
var ADJ_G = null
var ADJ_SET = {}
func nationsAdjacent(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0: return false
	var k = STRAT_REV
	if ADJ_G != G or ADJ_KEY != k:
		ADJ_SET = {}
		ADJ_G = G
		ADJ_KEY = k
		for e in G.edges:
			var oa: int = T(e.a).owner
			var ob: int = T(e.b).owner
			if oa >= 0 and ob >= 0 and oa != ob: ADJ_SET[min(oa, ob) * 4096 + max(oa, ob)] = true
	return ADJ_SET.has(min(a, b) * 4096 + max(a, b))
func cpuPeaceTerms(a: int, b: int) -> Dictionary:
	var opt = peaceOptions(a, b)
	var goal = warGoal(a, b)
	var terms = {"cede": 0, "gold": 0, "vassal": false}
	if goal == "vassal" and opt.vassal: terms.vassal = true
	else:
		var want = 3 if goal == "three" else (2 if goal == "capital" else 1)
		terms.cede = min(opt.cede, want)
		if opt.gold and randf() < 0.6: terms.gold = opt.gold
	if cpuDanger(a) >= 1.0 or NAT(a).get("fatigue", 0) >= DIP.fatiguePeace:
		terms.cede = min(terms.cede, 1)
		terms.vassal = false
	return terms

# ==================== k5_econ.gd ====================
# 内政・方針・疲労・開拓・戦争目標・講和（元 6008〜6438）

func bldCount(t: Dictionary, k: String) -> int:
	var n = 0
	for b in t.bld:
		if b == k: n += 1
	return n
func popCap(t: Dictionary) -> int:
	var base: float = (CFG.popCity if t.type == "city" else CFG.popFort) * t.dev + bldCount(t, "house") * CFG.houseCap
	return int(round(base * (1.3 if t.get("trait") == "dense" else 1.0) * terrOf(t).pop * max(0.3, 1.0 + nmod(t.owner, "pop"))))
func popRatio(t: Dictionary) -> float: return clamp_f(t.pop / max(1.0, popCap(t)), 0, 1.2)
func secMul(t: Dictionary) -> float:
	if t.sec >= 90: return 1.05
	if t.sec >= 60: return 1.0
	return clamp_f(0.40 + t.sec / 100.0, 0.40, 1)
func secLabel(v: float) -> String:
	return "安泰" if v >= 80 else ("平穏" if v >= 60 else ("不安" if v >= 40 else ("険悪" if v >= CFG.revoltSec else "暴動寸前")))
func secColor(v: float) -> String: return "#6d9c63" if v >= 60 else ("#d29b3c" if v >= 40 else "#c0504a")
func linkBonus(t: Dictionary) -> float:
	var l = int(clamp_f(t.get("link", 0), 0, 3))
	return CFG.roadBonus[l] + (0.10 if t.get("trait") == "road" and t.get("link", 0) else 0.0)
func foodGain(nid: int) -> int:
	var f = 0.0
	for t in ownList(nid): f += bldCount(t, "farm") * CFG.farmOut * (1.3 if t.get("trait") == "fertile" else 1.0) * terrOf(t).food
	return int(round(f))
func traitTroop(t: Dictionary, k: String) -> float:
	var m: float = terrOf(t).troop.get(k, 1.0)
	if t.get("trait") == "iron" and (k == "inf" or k == "spe"): m *= 1.2
	if t.get("trait") == "horse" and k == "cav": m *= 1.3
	return m
func contig(t: Dictionary, nid: int) -> int:
	var n = 0
	for nb in roadNbrs(t.id):
		if T(nb.to).owner == nid: n += 1
	return n
func reconnect(t: Dictionary, nid: int) -> int:
	var n = 0
	for nb in roadNbrs(t.id):
		var o = T(nb.to)
		if o.owner == nid and not o.get("link", 0): n += 1
	return n
func foeNbrs(t: Dictionary, nid: int) -> int:
	var n = 0
	for nb in roadNbrs(t.id):
		var o: int = T(nb.to).owner
		if o != nid and atWar(nid, o): n += 1
	return n
func _natPop(nid: int) -> float:
	var pop = 0.0
	for t in ownList(nid): pop += t.pop
	return pop
func stockCap(nid: int) -> int: return int(round(_natPop(nid) * CFG.stockCapPop * (1.0 + nmod(nid, "cap"))))
func levyRoom(t: Dictionary) -> int: return max(0, int(round(t.pop - popCap(t) * CFG.levyFloor)))
func foodNeed(nid: int) -> int: return int(round(_natPop(nid) / 1000.0 * CFG.foodPop + nationTroops(nid) / 1000.0 * CFG.foodTroop))
func isStarving(na: Dictionary) -> bool: return na.food <= 0
func foodCap(nid: int) -> int: return int(round(3000 + foodNeed(nid) * 12))

# ---------- 国家方針 ----------
const POLICY := {
	"none": {"n": "方針なし", "d": "特に方針を定めない", "e": {}},
	"agri": {"n": "農業重視", "d": "食料 +20%／税収 -10%", "e": {"food": 1.2, "gold": 0.9}},
	"trade": {"n": "商業重視", "d": "税収 +15%／兵の生産 -10%", "e": {"gold": 1.15, "troop": 0.9}},
	"mil": {"n": "富国強兵", "d": "兵の生産 +15%／人口の伸び -10%", "e": {"troop": 1.15, "grow": 0.9}},
	"civil": {"n": "民生重視", "d": "人口の伸び +25%／治安 +2／兵の生産 -15%", "e": {"grow": 1.25, "sec": 2, "troop": 0.85}},
	"total": {"n": "総動員", "d": "兵の生産 +45%／食料 -20%・治安 -3・人口の伸び -40%", "e": {"troop": 1.45, "food": 0.8, "sec": -3, "grow": 0.6}},
}
const POLICY_KEYS := ["none", "agri", "trade", "mil", "civil", "total"]
const POLICY_LOCK := 10
func polOf(na) -> Dictionary: return POLICY.get(na.get("policy", "none") if na != null else "none", POLICY.none)
func polMul(na, key: String) -> float: return polOf(na).e.get(key, 1.0)
func polAdd(na, key: String) -> float: return polOf(na).e.get(key, 0.0)
func polLeft(na: Dictionary) -> int: return max(0, na.get("policyAt", 0) + POLICY_LOCK - G.turn)
func setPolicy(nid: int, key: String) -> bool:
	var na = NAT(nid)
	if not POLICY.has(key) or na.policy == key: return false
	if polLeft(na) > 0: return false
	na.policy = key
	na.policyAt = G.turn
	var msg = "%s が方針を「%s」に定める" % [na.name, POLICY[key].n]
	logMsg(msg)
	chron(msg, nid, "gov")
	return true

# ---------- 戦争疲労 ----------
func fatigueMul(na: Dictionary) -> float:
	var f: float = na.get("fatigue", 0)
	if f >= CFG.fatHigh: return 1 - CFG.fatHighMul
	if f >= CFG.fatMid: return 1 - CFG.fatMidMul
	return 1.0
func fatigueLabel(f: float) -> String:
	return "厭戦" if f >= CFG.fatHigh else ("疲弊" if f >= CFG.fatMid else ("疲れ" if f >= 25 else "健全"))
func addFatigue(nid: int, v: float) -> void:
	if nid < 0: return
	var na = NAT(nid)
	na.fatigue = clamp_f(na.get("fatigue", 0) + v, 0, 100)

# ---------- 領地の毎ターン更新 ----------
func updateTerr(t: Dictionary, na: Dictionary, war: bool) -> void:
	var starve = isStarving(na)
	var d: float = CFG.secRecover + bldCount(t, "gov") * CFG.secGov + polAdd(na, "sec") + nmod(na.id, "sec") + (na.get("stab", 50.0) - 50.0) / 25.0
	if t.chaos > 0: d += CFG.secChaos
	if war: d += CFG.secWar
	if starve: d += CFG.secStarve
	t.sec = clamp_f(round(t.sec + d), 0, 100)
	var cap = popCap(t)
	if starve: t.pop = int(round(t.pop * 0.97))
	elif t.chaos <= 0:
		var rate = clamp_f(CFG.popGrow * (1 + bldCount(t, "house") * 0.5) * (t.sec / 70.0) * polMul(na, "grow") * (1.0 + nmod(na.id, "grow")), 0, 0.4)
		t.pop = int(round(t.pop + (cap - t.pop) * rate))
	if t.pop > cap: t.pop = int(round(t.pop - (t.pop - cap) * 0.25))
	t.pop = max(200, t.pop)
	if t.sec < CFG.revoltSec and randf() < CFG.revoltRate: revolt(t, na)
func revolt(t: Dictionary, na: Dictionary) -> void:
	t.sec = clamp_f(t.sec + 30, 0, 100)
	t.pop = int(round(t.pop * 0.9))
	t.chaos = max(t.chaos, 2)
	var msg = "%s で反乱 — 人口が減り、2ターン混乱" % t.name
	logMsg("【反乱】" + msg, "war")
	chron(msg, na.id, "event")

# ---------- 開拓 ----------
func settleCost(nid: int) -> int:
	var n = 0
	for t in ownList(nid): n += 1
	return int(round(FRONT.settleGold + n * FRONT.settleGrow))
func settlingOf(nid: int) -> Array:
	var r = []
	for t in G.terrs:
		if t.get("settle") != null and t.settle.by == nid: r.append(t)
	return r
func _nextToOwn(tid: int, nid: int) -> bool:
	for nb in roadNbrs(tid):
		if T(nb.to).owner == nid: return true
	return false
func settleReason(nid: int, tid: int) -> String:
	var t = T(tid)
	if t.owner >= 0: return "すでに治める国があります"
	if t.get("settle") != null: return "%s が開拓中です" % NAT(t.settle.by).name
	if not _nextToOwn(tid, nid): return "自領と隣り合う土地だけ開拓できます"
	if settlingOf(nid).size() >= FRONT.settleMax: return "同時に開拓できるのは %d か所までです" % FRONT.settleMax
	if NAT(nid).gold < settleCost(nid): return "ゴールドが足りません（%sG）" % fmt(settleCost(nid))
	return ""
func startSettle(nid: int, tid: int) -> bool:
	if settleReason(nid, tid) != "": return false
	NAT(nid).gold -= settleCost(nid)
	T(tid).settle = {"by": nid, "done": G.turn + FRONT.settleTurns}
	return true
func settleTurn() -> void:
	for t in G.terrs:
		var st = t.get("settle")
		if st == null: continue
		var na = NAT(st.by)
		if t.owner >= 0 or not na.alive:
			t.settle = null
			continue
		if not _nextToOwn(t.id, st.by):
			t.settle = null
			continue
		if G.turn < st.done - 1: continue
		t.settle = null
		t.owner = st.by
		t.sec = FRONT.settleSec
		t.chaos = 0
		G.ownRev = G.get("ownRev", 0) + 1
		infraChanged(t)
		var msg = "%s が %s を開拓" % [na.name, t.name]
		logMsg(msg)
		chron(msg, st.by, "gov")
func cpuSettle(nid: int) -> void:
	if wildCount() == 0: return
	var na = NAT(nid)
	var P: Dictionary = PERSONA.get(na.persona, PERSONA.neutral)
	var slots: int = FRONT.settleMax - settlingOf(nid).size()
	if slots <= 0: return
	var war = inWar(nid)
	var reserve: float = (7000.0 if war else 1200.0) / P.settle
	var cand = []
	for t in G.terrs:
		if t.owner >= 0 or t.get("settle") != null: continue
		var nbs = roadNbrs(t.id)
		var mineN = 0
		var other = false
		for nb in nbs:
			var o: int = T(nb.to).owner
			if o == nid: mineN += 1
			elif o >= 0: other = true
		if not mineN: continue
		var sc: float = mineN * 6 + (10 if t.type == "city" else 4) + (8 if t.get("trait") != null else 0) + t.pop / 1000.0
		if other: sc += 5
		cand.append({"t": t, "sc": sc})
	cand.sort_custom(func(x, y): return x.sc > y.sc)
	for c in cand:
		if slots <= 0: break
		if na.gold < settleCost(nid) + reserve: break
		if startSettle(nid, c.t.id): slots -= 1
var WILD_KEY = ""
var WILD_N = 0
func wildCount() -> int:
	var k = str(G.get("ownRev", 0)) + "_" + str(G.turn) + "_" + str(G.terrs.size())
	if WILD_KEY == k and WILD_G == G: return WILD_N
	var n = 0
	for t in G.terrs:
		if t.owner < 0: n += 1
	WILD_KEY = k
	WILD_G = G
	WILD_N = n
	return n
var WILD_G = null
func terrIncome(t: Dictionary) -> int:
	if t.type != "city" or t.owner < 0: return 0
	var na = NAT(t.owner)
	var m: float = (CFG.chaosMul if t.chaos > 0 else 1.0) * secMul(t) * (1 + linkBonus(t)) * fatigueMul(na) * polMul(na, "gold")
	var mk: float = bldCount(t, "market") * BLD_OUT.market.gold * (1.3 if t.get("trait") == "trade" else 1.0)
	return int(round((t.pop * CFG.taxRate + mk) * m))

# ============================================================
#   戦争目標・戦勝点・講和
# ============================================================
const WGOAL := {
	"cede": {"n": "国境の割譲", "d": "国境の領地を1つ得る", "need": 1, "col": "#c9a227"},
	"three": {"n": "三領地の獲得", "d": "相手から3領地を得る", "need": 3, "col": "#d8a03c"},
	"vassal": {"n": "属国化", "d": "相手を従属させる", "need": 0, "col": "#b06fb0"},
	"capital": {"n": "首都攻略", "d": "相手の首都を落とす", "need": 0, "col": "#c94b44"},
	"defend": {"n": "防衛戦争", "d": "侵攻を退ける", "need": 0, "col": "#5f9c57"},
	"claim": {"n": "要地の獲得", "d": "望んでいた領地を手に入れる", "need": 1, "col": "#e0b64a"},
}
func goalLabel(a: int, b: int) -> String:
	var g = warGoal(a, b)
	var id = G.dip.capId[a][b]
	return WGOAL[g].n + (("（%s）" % T(id).name) if g == "claim" and id != null else "")
var WAR = {"scoreTerr": 14, "scoreBattle": 5, "scoreCapital": 25, "scoreArmy": 6, "decay": 0.97,
	"cedeCost": 25, "vassalEdge": 70, "goldEdge": 15, "goldRate": 0.35, "acceptBase": 18}
func warInit(a: int, b: int, goal: String) -> void:
	var d: Dictionary = G.dip
	d.goal[a][b] = goal if goal != "" else "cede"
	d.goal[b][a] = "defend"
	d.score[a][b] = 0; d.score[b][a] = 0
	d.taken[a][b] = 0; d.taken[b][a] = 0
	d.capId[a][b] = NAT(b).capital; d.capId[b][a] = NAT(a).capital
	if d.goal[a][b] == "claim":
		var dv = desireVs(a, b)
		if dv != null and dv.get("t") != null: d.capId[a][b] = dv.t
		else: d.goal[a][b] = "cede"
func warGoal(a: int, b: int) -> String:
	if a < 0 or b < 0: return "defend"
	var g = G.dip.goal[a][b]
	return g if g else "defend"
func warScore(a: int, b: int) -> float: return G.dip.score[a][b]
func warTaken(a: int, b: int) -> int: return G.dip.taken[a][b]
func warEdge(a: int, b: int) -> int: return int(round(warScore(a, b) - warScore(b, a)))
func addWarScore(a: int, b: int, v: float) -> void:
	if not atWar(a, b): return
	addWarPts(a, b, v)
	G.dip.score[a][b] = max(0, G.dip.score[a][b] + v)
func goalDone(a: int, b: int) -> bool:
	match warGoal(a, b):
		"cede": return warTaken(a, b) >= 1
		"three": return warTaken(a, b) >= 3
		"vassal": return warEdge(a, b) >= WAR.vassalEdge
		"capital", "claim":
			var id = G.dip.capId[a][b]
			return id != null and T(id).owner == a
		"defend": return warEdge(a, b) >= 20 or (G.turn - G.dip.since[a][b] >= 12 and warEdge(a, b) >= 0)
	return false
func goalText(a: int, b: int) -> String:
	var gk = warGoal(a, b)
	var g = WGOAL.get(gk)
	if g == null: return ""
	var extra = ("（%d / %d）" % [warTaken(a, b), g.need]) if gk == "cede" or gk == "three" else ""
	return g.n + extra
func peaceOptions(a: int, b: int) -> Dictionary:
	var edge = warEdge(a, b)
	var maxCede: int = max(0, min(4, floor(edge / float(WAR.cedeCost))))
	return {"edge": edge, "cede": maxCede, "vassal": edge >= WAR.vassalEdge and canAskVassal(a, b),
		"gold": int(round(NAT(b).gold * WAR.goldRate)) if edge >= WAR.goldEdge else 0}
func peaceAccept(a: int, b: int, terms: Dictionary) -> bool:
	var edge = warEdge(a, b)
	var nb = NAT(b)
	var cost: float = terms.get("cede", 0) * WAR.cedeCost + (WAR.vassalEdge if terms.get("vassal", false) else 0) + (WAR.goldEdge if terms.get("gold", 0) else 0)
	var will: float = edge + nb.get("fatigue", 0) * 0.5 + cpuDanger(b) * 25 - WAR.acceptBase
	if nb.food <= 0: will += 15
	var own = 0
	for t in G.terrs:
		if t.owner == b: own += 1
	if own <= 3: will += 20
	return will >= cost
func settlePeace(a: int, b: int, terms: Dictionary) -> Array:
	var W = warObj(a, b)
	if W != null:
		var demands: bool = terms.get("cede", 0) > 0 or terms.get("gold", 0) > 0 or terms.get("vassal", false)
		var win = otherSide(W, b)
		var alive = []
		for n in win:
			if NAT(n).alive: alive.append(n)
		alive.sort_custom(func(x, y): return W.sc.get(x, 0) > W.sc.get(y, 0))
		var top = alive[0] if alive.size() else null
		var vasTo = top if terms.get("vassal", false) and top != null and canAskVassal(top, b) else null
		if terms.get("gold", 0) and top != null:
			var g: int = min(NAT(b).gold, terms.gold)
			var tot = 0.0
			for n in win: tot += W.sc.get(n, 0)
			if tot == 0: tot = 1
			NAT(b).gold -= g
			for n in win:
				if NAT(n).alive: NAT(n).gold += int(round(g * W.sc.get(n, 0) / tot))
		var lines = endWar(W, {"winner": win, "full": false} if demands else null)
		if vasTo != null and canAskVassal(vasTo, b):
			makeVassal(vasTo, b, "講和による従属")
			lines.append("%s は %s の属国に" % [NAT(b).name, NAT(vasTo).name])
		return lines
	var lines2 = []
	if terms.get("cede", 0):
		var list = cedeTerrs(b, a, terms.cede)
		if list.size():
			var names = []
			for t in list: names.append(t.name)
			lines2.append("%s を割譲" % "・".join(names))
	if terms.get("gold", 0):
		var g2: int = min(NAT(b).gold, terms.gold)
		NAT(b).gold -= g2
		NAT(a).gold += g2
		lines2.append("賠償金 %s G" % fmt(g2))
	var vas: bool = terms.get("vassal", false) and canAskVassal(a, b)
	makePeace(a, b)
	if vas: makeVassal(a, b, "講和による従属")
	if lines2.size():
		var msg = "講和条件：%s は %s へ %s" % [NAT(b).name, NAT(a).name, "、".join(lines2)]
		logMsg(msg, "war")
		chron(msg, a, "gov")
	return lines2
func cedeTerrs(from: int, to: int, n: int) -> Array:
	var mine = []
	for t in G.terrs:
		if t.owner == from: mine.append(t)
	var border = []
	for t in mine:
		if _nextToOwn(t.id, to): border.append(t)
	border.sort_custom(func(x, y):
		var a1 = contig(x, to)
		var b1 = contig(y, to)
		if a1 != b1: return a1 > b1
		var a2 = contig(x, from)
		var b2 = contig(y, from)
		if a2 != b2: return a2 < b2
		return x.dev < y.dev)
	var pool = border.duplicate()
	for t in mine:
		if not border.has(t) and not t.cap: pool.append(t)
	var out = []
	for t in pool:
		if out.size() >= n: break
		if t.cap and mine.size() > 1: continue
		out.append(t)
	for t in out:
		t.owner = to
		G.ownRev = G.get("ownRev", 0) + 1
		t.chaos = max(t.chaos, 2)
		t.sec = min(t.sec, CFG.secCapture + 10)
		chron("%s が %s に割譲される" % [t.name, NAT(to).name], to, "gov")
		invalidateTerr(t.id)
	if out.size():
		invalidateSupply()
		checkNations()
	return out
func cpuWarGoal(a: int, b: int) -> String:
	var ratio = nationPower(a) / max(1.0, nationPower(b))
	var P: Dictionary = PERSONA.get(NAT(a).persona, PERSONA.neutral)
	var dv = desireVs(a, b)
	if dv != null and dv.get("t") != null: return "claim"
	if dv != null and dv.k == "feud": return "vassal" if ratio >= DIP.vassalWarRatio else "capital"
	if dv != null and (dv.k == "protect" or dv.k == "guard"): return "defend"
	if ratio >= DIP.vassalWarRatio and randf() < 0.5: return "vassal"
	if ratio >= 1.8 and (P.army > 0 or randf() < 0.4): return "capital"
	if ratio >= 1.25: return "three"
	return "cede"

# ==================== k6_turn.gd ====================
# ターン進行・生産・出来事・節目・CPUの軍（元 6439〜7218）

signal phase_changed(nid, sub: String)   # nid=null で消す
signal refreshed                         # 画面を描き直す
signal beat                              # 軍団が一手動いた（軽い描き直し）
signal turn_ended
## 画面側が「その領地は今見えているか」を答える（無ければ常に見えている扱い）
var onScreenFn: Callable = Callable()

func sleep_ms(ms: int) -> void:
	if ms <= 0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(ms / 1000.0).timeout
func phaseWait(nid: int) -> int:
	return int(round(CFG.phaseDelay * 0.5)) if nid == followNat() else 0
func setPhase(nid, sub := "") -> void: phase_changed.emit(nid, sub)

var YIELD_AT = 0
var BEAT_SPENT = 0
var BEAT_MAX = 2500
var PROF = {}
var _TPT = 0
var _TPL = ""
func _tp(l: String) -> void:
	var now = Time.get_ticks_usec()
	if _TPL != "": PROF["dip:" + _TPL] = PROF.get("dip:" + _TPL, 0) + now - _TPT
	_TPT = now
	_TPL = l
## 計算が長く続いたら画面に順番を譲る（1コマを短く保つ）
var SEGLOG = false
var SEGS = {}
var FRAME_MS = 12
func yieldMaybe() -> void:
	var seg = Time.get_ticks_msec() - YIELD_AT
	if SEGLOG and seg > 90 and seg < 1000:
		var st = get_stack()
		var k = "%s:%d" % [st[1].function, st[1].line] if st.size() > 1 else "?"
		SEGS[k] = SEGS.get(k, []) + [seg]
	if Time.get_ticks_msec() - YIELD_AT > FRAME_MS:
		await get_tree().process_frame
		YIELD_AT = Time.get_ticks_msec()
func endTurn() -> void:
	BEAT_SPENT = 0
	BATTLE_SPENT = 0
	BATTLE_N = 0
	if UI.busy or G == null or G.over != null: return
	UI.busy = true
	var _t0 = Time.get_ticks_msec()
	PROF = {}
	stratBump()
	for n in G.nations.size():
		if G.over != null: break
		if not NAT(n).alive: continue
		var _a = Time.get_ticks_usec()
		setPhase(n, "")
		var _b = Time.get_ticks_usec()
		var pw = phaseWait(n)
		if pw > 0:
			PROF["n:pw"] = PROF.get("n:pw", 0) + 1000
			await sleep_ms(pw)
			YIELD_AT = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - YIELD_AT > FRAME_MS:
			PROF["n:y0"] = PROF.get("n:y0", 0) + 1000
			await sleep_ms(0)
			YIELD_AT = Time.get_ticks_msec()
		var _c = Time.get_ticks_usec()
		await cpuTurn(n)
		var _d = Time.get_ticks_usec()
		PROF["loop:phase"] = PROF.get("loop:phase", 0) + _b - _a
		PROF["loop:yield"] = PROF.get("loop:yield", 0) + _c - _b
		PROF["loop:cpuTurn"] = PROF.get("loop:cpuTurn", 0) + _d - _c
	setPhase(null)
	UI.actArmy = null
	await flushDip()
	var _t1 = Time.get_ticks_msec()
	stratBump()
	await yieldMaybe()
	await production()
	await yieldMaybe()
	settleTurn()
	await yieldMaybe()
	for na in G.nations:
		for a in na.armies:
			if a != null: a.moved = false
	siegeTurn()
	armyUpkeepTurn()
	stratBump()
	occupationTurn()
	randomEvent()
	var nn: int = G.nations.size()
	for a in nn:
		for b2 in nn:
			if a != b2 and G.dip.score[a][b2]: G.dip.score[a][b2] *= WAR.decay
	await yieldMaybe()
	dipTurn()
	await yieldMaybe()
	tensionTurn()
	decayThreat()
	checkMilestones()
	recordHistory()
	await yieldMaybe()
	# 持ち主・道・首都が変わっていなければ、補給の範囲は作り直さず軍の補給だけ見直す
	SUP_DIRTY = true
	refreshSupply()
	G.turn += 1
	yearReviewTurn()
	historyEventsTurn()
	G.log.append({"s": "第 %d ターン" % G.turn, "cls": "sep", "t": G.turn})
	if G.turn > TURN_MAX:
		logMsg("ターン上限に到達しました", "war")
		endGame(-1)
	var _t2 = Time.get_ticks_msec()
	UI.busy = false
	refreshed.emit()
	await flushDip()
	turn_ended.emit()

func production() -> void:
	refreshSupply()
	var tradeG = []
	for n in G.nations: tradeG.append(tradeIncome(n.id))
	var ownBy = {}
	for t in G.terrs:
		if t.owner >= 0:
			if not ownBy.has(t.owner): ownBy[t.owner] = []
			ownBy[t.owner].append(t)
	for na in G.nations:
		if not na.alive: continue
		await yieldMaybe()
		var own: Array = ownBy.get(na.id, [])
		var war = inWar(na.id)
		var starve = isStarving(na)
		var fat = fatigueMul(na)
		var pGold = polMul(na, "gold")
		var pFood = polMul(na, "food")
		var pTroop = polMul(na, "troop")
		var sm = stabMul(na) if na.has("stab") else 1.0
		pGold *= (1.0 + nmod(na.id, "gold")) * sm
		pFood *= max(0.2, 1.0 + nmod(na.id, "food"))
		pTroop *= max(0.2, 1.0 + nmod(na.id, "troop")) * sm * na.get("eqMul", 1.0)
		var mfN = 0
		var cfN = 0
		var gold = 0.0
		var food = 0.0
		var levy = 0.0
		var add = {"inf": 0.0, "spe": 0.0, "arc": 0.0, "cav": 0.0}
		var room2: float = max(0, stockCap(na.id) - total(na.stock))
		for t in own:
			var base: float = (CFG.chaosMul if t.chaos > 0 else 1.0) * secMul(t) * fat * occMul(t)
			var gm: float = base * (1 + linkBonus(t)) * pGold
			var tm: float = base * (0.5 if starve else 1.0) * pTroop
			if t.type == "city": gold += t.pop * CFG.taxRate * gm
			var room: float = levyRoom(t)
			for b in t.bld:
				if not b: continue
				if b == "mf":
					mfN += 1
					continue
				if b == "cf":
					cfN += 1
					gold += CF_GOLD * gm * (1.0 + nmod(na.id, "cf")) * consumerMul(na)
					continue
				if b == "market":
					gold += BLD_OUT.market.gold * gm * (1.3 if t.get("trait") == "trade" else 1.0)
					continue
				if b == "farm":
					food += CFG.farmOut * (1.3 if t.get("trait") == "fertile" else 1.0) * terrOf(t).food * pFood
					continue
				var o = BLD_OUT.get(b)
				if o == null: continue
				for k in TK:
					if not o.has(k): continue
					var n: float = o[k] * tm * traitTroop(t, k)
					n = min(n, room / CFG.levyPop, room2)
					if n <= 0: continue
					add[k] += n
					var used: float = n * CFG.levyPop
					room -= used; room2 -= n; levy += used
					t.pop = max(0, int(round(t.pop - used)))
		if na.has("eq"):
			var sec0 = 1.0
			if own.size(): sec0 = clamp_f(0.6 + na.get("stab", 50.0) / 125.0, 0.6, 1.4)
			na.eqIn = int(round(mfN * EQ_PER_MF * (1.0 + nmod(na.id, "mf")) * sec0 * resMul(na.id)))
			na.eq += na.eqIn
			var troops = 0.0
			for k in TK: troops += add[k]
			var need: float = troops * EQ_COST / max(0.35, na.get("eqMul", 1.0))
			na.eqNeed = int(round(troops * EQ_COST))
			na.eq = max(0, na.eq - na.eqNeed)
			na.eqMul = clamp_f(0.35 + 0.65 * (na.eq + na.eqIn) / max(1.0, need), 0.35, 1.0) if need > 0 else 1.0
			na.eq = min(na.eq, 60000)
		if na.get("badHarv", 0) > 0:
			gold *= 0.6; food *= 0.6; na.badHarv -= 1
		na.goldIn = int(round(gold))
		na.tradeIn = tradeG[na.id]
		gold += na.tradeIn
		if na.get("revoltBuff", 0) > 0: gold *= 1 + DIP.revoltProd
		var lord = lordOf(na.id)
		if lord != null:
			var pay = int(round(gold * DIP.tribute))
			gold -= pay
			NAT(lord).gold += pay
			na.tribute = pay
		else: na.tribute = 0
		na.gold += int(round(gold))
		na.levy = int(round(levy))
		for k in TK: na.stock[k] += int(round(add[k]))
		var need = foodNeed(na.id)
		na.foodIn = int(round(food))
		na.foodNeed = need
		na.food = int(clamp_f(round(na.food + food - need), -3000, foodCap(na.id)))
		for t in own: updateTerr(t, na, war)
		# 戦争支持が高いほど厭戦は溜まりにくい（支持 90 で半分）
		na.fatigue = clamp_f(na.get("fatigue", 0) + (CFG.fatWar * clamp_f(1.4 - na.get("ws", 50.0) / 100.0, 0.5, 1.2) if war else CFG.fatPeace), 0, 100)
	for t in G.terrs:
		if t.chaos > 0: t.chaos -= 1
		if t.get("devP", false):
			t.devP = false
			t.dev = min(5, t.dev + 1)
			invalidateTerr(t.id)
		if t.get("infraP", false):
			t.infraP = false
			t.infra = min(3, t.get("infra", 1) + 1)
			infraChanged(t)
		if t.get("infraBroke", 0):
			t.infraBroke -= 1
			if t.infraBroke <= 0:
				t.infraBroke = 0
				t.infra = min(3, t.get("infra", 1) + 1)
				infraChanged(t)
				if concerns([t.owner]): logMsg("%s の道や橋が復旧しました" % t.name, "good")

# ============================================================
#   出来事（CPU が選ぶ）
# ============================================================
const EVENTS := [
	{"k": "bad", "n": "凶作", "w": 1.1, "opts": [{"n": "国庫を開放する", "need": 5000}, {"n": "各都市に任せる"}]},
	{"k": "plague", "n": "疫病", "w": 0.9, "opts": [{"n": "都市を封鎖する", "need": 4000}, {"n": "成り行きに任せる"}]},
	{"k": "merc", "n": "傭兵団の来訪", "w": 1.0, "opts": [{"n": "雇い入れる", "need": 8000}, {"n": "断る"}]},
	{"k": "bandit", "n": "山賊の跋扈", "w": 1.0, "opts": [{"n": "討伐軍を出す", "need": 3000}, {"n": "放っておく"}]},
	{"k": "good", "n": "豊作", "w": 1.1, "opts": [{"n": "蔵に納める"}, {"n": "民に分け与える"}]},
	{"k": "road", "n": "道や橋の崩落", "w": 1.0, "opts": [{"n": "ただちに修復する", "need": 4000}, {"n": "後回しにする"}]},
	{"k": "gen", "n": "名将の来訪", "w": 0.8, "opts": [{"n": "迎え入れる", "need": 6000}, {"n": "断る"}]},
]
func _evOk(na: Dictionary, ev: Dictionary, i: int) -> bool:
	var o: Dictionary = ev.opts[i]
	if ev.k == "gen" and i == 0: return na.gold >= 6000 and na.gens.size() < GEN_MAX
	return na.gold >= o.get("need", 0)
func _ownOf(nid: int) -> Array:
	var r = []
	for t in ownList(nid): r.append(t)
	return r
func _evRun(na: Dictionary, ev: Dictionary, i: int) -> String:
	var own = _ownOf(na.id)
	match ev.k + str(i):
		"bad0":
			na.gold -= 5000
			for t in own: t.sec = clamp_f(t.sec + 8, 0, 100)
			return "蔵を開き、民を飢えから守った"
		"bad1":
			na.food -= 1500
			for t in own:
				t.pop = int(round(t.pop * 0.97)); t.sec = clamp_f(t.sec - 8, 0, 100)
			return "各地は自力で凌いだが、民は減り不満が残った"
		"plague0":
			na.gold -= 4000
			for t in own:
				if t.type == "city":
					t.pop = int(round(t.pop * 0.98)); t.sec = clamp_f(t.sec - 3, 0, 100)
			return "封鎖によって広がりは抑えられた"
		"plague1":
			for t in own:
				t.pop = int(round(t.pop * 0.93)); t.sec = clamp_f(t.sec - 6, 0, 100)
			return "疫病は広がり、多くの民が失われた"
		"merc0":
			na.gold -= 8000; na.stock.inf += 2500; na.stock.arc += 800
			return "傭兵団が旗の下に加わった"
		"merc1": return "傭兵団は他国へ去っていった"
		"bandit0":
			na.gold -= 3000
			for t in own: t.sec = clamp_f(t.sec + 10, 0, 100)
			return "山賊は討ち払われ、往来に平穏が戻った"
		"bandit1":
			na.gold = int(round(na.gold * 0.9))
			for t in own: t.sec = clamp_f(t.sec - 10, 0, 100)
			return "隊商は荒らされ、民の信頼も損なわれた"
		"good0":
			na.food += 2500
			return "蔵は満ち、当分の憂いはない"
		"good1":
			for t in own:
				t.sec = clamp_f(t.sec + 12, 0, 100); t.pop = int(round(t.pop * 1.04))
			return "民は喜び、村々は賑わった"
		"road0":
			na.gold -= 4000
			return "人夫を集め、道や橋はすぐに直された"
		"road1":
			var cand = []
			for t in own:
				if t.get("infra", 1) > 1 and not t.get("infraBroke", 0): cand.append(t)
			if cand.is_empty(): return "幸い、大きな被害はなかった"
			var t = pick(cand)
			t.infra -= 1
			t.infraBroke = 3
			infraChanged(t)
			return "%s のインフラが3ターン「%s」に落ちた" % [t.name, INFRA_N[t.infra]]
		"gen0":
			na.gold -= 6000
			var pts = randomPts()
			pts[pick(GEN_ABIL).k] += 1
			pts[pick(GEN_ABIL).k] += 1
			var g = mkGen(G, na, pts)
			return "%s が旗下に加わった" % g.name
		"gen1": return "将は静かに去っていった"
	return ""
func randomEvent() -> void:
	if randf() > CFG.eventRate: return
	var alive = []
	for n in G.nations:
		if n.alive: alive.append(n)
	if alive.is_empty(): return
	var na: Dictionary = pick(alive)
	if _ownOf(na.id).is_empty(): return
	var pool = []
	for ev in EVENTS:
		for i in int(round(ev.w * 10)): pool.append(ev)
	var ev: Dictionary = pick(pool)
	var i = cpuEventChoice(na, ev)
	var res = _evRun(na, ev, i)
	var o: Dictionary = ev.opts[i]
	var msg = "%s — %s：%s／%s" % [ev.n, na.name, o.n, res]
	logMsg("【出来事】" + msg)
	chron("%s — %s（%s）" % [ev.n, o.n, res], na.id, "event")
func cpuEventChoice(na: Dictionary, ev: Dictionary) -> int:
	var rich: bool = na.gold > 20000
	var poor: bool = na.gold < 6000
	if not _evOk(na, ev, 0): return 1
	if ev.k == "merc": return 0 if rich and (na.persona == "aggr" or na.persona == "fascism" or cpuDanger(na.id) >= 0.8) else 1
	if ev.k == "gen": return 0 if na.gens.size() < 6 and rich else 1
	if ev.k == "good": return 0 if na.food < foodNeed(na.id) * 6 else 1
	if poor: return 1
	return 0 if na.persona == "econ" or na.persona == "def" or na.persona == "neutral" or na.persona == "democracy" or rich else 1

# ---------- 年代記の節目 ----------
const TERR_MILE := [5, 10, 15, 20, 30, 40, 50, 60, 70]
const WIN_MILE := [5, 10, 20, 30, 50]
func checkMilestones() -> void:
	var cnt = {}
	for t in G.terrs: cnt[t.owner] = cnt.get(t.owner, 0) + 1
	for na in G.nations:
		if not na.alive: continue
		if not na.has("mile"): na.mile = {}
		var own: int = cnt.get(na.id, 0)
		for m in TERR_MILE:
			if own >= m and not na.mile.has("t%d" % m):
				na.mile["t%d" % m] = 1
				chron("%s の版図が %d 領地に達する" % [na.name, m], na.id, "mile")
		for a in na.armies:
			if a == null: continue
			for m in WIN_MILE:
				var key = "w%d_%d" % [a.idx, m]
				if a.get("wins", 0) >= m and not na.mile.has(key):
					na.mile[key] = 1
					chron("%s %s、通算 %d 勝" % [na.name, a.name, m], na.id, "mile")
			var g = genOf(na, a.gen)
			var tot = total(a.t)
			if g == null: continue
			if tot > g.get("maxLed", 0): g.maxLed = tot
			if tot >= 8000 and tot >= na.get("recLed", 0) * 1.25:
				na.recLed = tot
				chron("%s 将軍が最大兵力 %s を率いる" % [g.name, fmt(tot)], na.id, "mile")
func recordHistory() -> void:
	var cnt = {}
	for t in G.terrs: cnt[t.owner] = cnt.get(t.owner, 0) + 1
	var o = []
	var p = []
	for n in G.nations:
		o.append(cnt.get(n.id, 0))
		p.append(nationPower(n.id))
	G.hist.append({"t": G.turn, "o": o, "p": p})
	if G.hist.size() > 600:
		var h = []
		for i in G.hist.size():
			if i % 2 == 0: h.append(G.hist[i])
		G.hist = h

# ---------- CPU ----------
func prodPerTurn(nid: int) -> int:
	var n = 0
	for t in ownList(nid):
		for b in t.bld:
			var o = BLD_OUT.get(b) if b else null
			if o == null: continue
			for k in TK:
				if o.has(k): n += o[k]
	return n
func powerOf(list: Array, t, isDef: bool) -> float:
	if list.is_empty(): return 0.0
	var s = sideStats(list, t if t != null else T(list[0].at), isDef)
	return s.tot * (s.def if isDef else s.atk) / 100.0
var FOCUS_CACHE = {}
var SPROG_MEMO = {}
func stratBonus(nid: int, t: Dictionary) -> float:
	var b = 0.0
	var W = warObj(nid, t.owner)
	if t.get("wTag") != null and t.get("wOrig") == nid: b += 30
	if W != null:
		b += vpOf(t) * 2
		var foe: int = t.wOrig if t.get("wTag") == W.id and t.get("wOrig") != null else t.owner
		var sd = sideOf(W, foe)
		if sd != null and not sd.has(nid):
			var k = "%d_%d_%d_%d" % [W.id, foe, G.turn, G.get("ownRev", 0)]
			var v = SPROG_MEMO.get(k)
			if v == null:
				if SPROG_MEMO.size() > 500: SPROG_MEMO.clear()
				v = surrenderProg(W, foe) / max(0.2, surrenderLimit(foe))
				SPROG_MEMO[k] = v
			b += v * 25
	var foes = FOCUS_CACHE.get(nid)
	if foes != null and foes == t.owner: b += 12
	return b
func focusFoe(nid: int):
	var best = null
	var bs = INF
	for o in G.nations:
		if not o.alive or o.id == nid or not atWar(nid, o.id) or not nationsAdjacent(nid, o.id): continue
		var v = nationPower(o.id) * (1 - busyFrac(o.id) * 0.5)
		if v < bs:
			bs = v
			best = o.id
	return best
func cpuObjective(nid: int, list: Array, bfsOf: Dictionary):
	if not inWar(nid): return null
	var cands = []
	var smart = smartAI(nid)
	if smart: FOCUS_CACHE[nid] = focusFoe(nid)
	var wantT = {}
	for d in desiresOf(nid):
		if d.get("t") != null: wantT[d.t] = true
	for t in G.terrs:
		if t.owner == nid or not atWar(nid, t.owner): continue
		var stage = null
		var sd = INF
		for nb in roadNbrs(t.id):
			if T(nb.to).owner != nid: continue
			var near = INF
			for a in list:
				var dd = bget(bfsOf[a.idx], nb.to)
				if dd != null and dd < near: near = dd
			if near < sd:
				sd = near
				stage = nb.to
		if stage == null or sd == INF: continue
		var gar = []
		for x in armiesAt(t.id):
			if total(x.t) > 0: gar.append(x)
		var dp = powerOf(gar, t, true) if gar.size() else 0.0
		var goalCap: float = (60 if warGoal(nid, t.owner) == "capital" and t.cap else 0) \
			+ (90 if G.dip.capId[nid][t.owner] == t.id and warGoal(nid, t.owner) == "claim" else 0) \
			+ (40 if wantT.has(t.id) else 0)
		var sc: float = (45 if t.cap else 0) + goalCap + t.dev * 5 + (8 if t.get("trait") != null else 0) \
			+ (-8 if t.type == "fort" else 6) + (15 if isTopThreat(t.owner) else 0) \
			+ contig(t, nid) * 10 + reconnect(t, nid) * 14 - foeNbrs(t, nid) * 6 \
			- dp / 900.0 - sd * 7 + (stratBonus(nid, t) if smart else 0.0)
		cands.append({"tid": t.id, "stage": stage, "sc": sc})
	if cands.is_empty(): return null
	cands.sort_custom(func(x, y): return x.sc > y.sc)
	return cands[0]
func nearestOwnCity(_a, bs: Dictionary, nid: int):
	var best = null
	var bd = INF
	for t in ownList(nid):
		var d = bget(bs, t.id)
		if d == null: continue
		var w: float = d - (1 if t.type == "city" else 0) - (1 if t.cap else 0)
		if w < bd:
			bd = w
			best = t.id
	return best
func cpuPolicy(nid: int, P: Dictionary) -> void:
	var na = NAT(nid)
	if polLeft(na) > 0: return
	var war = inWar(nid)
	var danger = cpuDanger(nid)
	var bal = foodGain(nid) - foodNeed(nid)
	var want = "none"
	if bal < 0 and na.food < foodNeed(nid) * 5: want = "agri"
	elif danger >= 1.0: want = "total"
	elif war: want = "total" if P.army > 0 else "mil"
	elif hasDesire(nid, "guard"): want = "mil"
	elif hasDesire(nid, "prosper"): want = "trade" if na.persona == "econ" or na.persona == "neutral" else "civil"
	elif na.persona == "econ" or na.persona == "neutral": want = "trade"
	elif na.persona == "def" or na.persona == "democracy": want = "civil"
	elif na.persona == "aggr" or na.persona == "fascism": want = "mil"
	else: want = "trade" if randf() < 0.5 else "civil"
	if want != na.get("policy", "none"): setPolicy(nid, want)

func _bldN(t: Dictionary) -> int:
	var n = 0
	for b in t.bld:
		if b: n += 1
	return n
func _hasTroopBld(t: Dictionary) -> bool:
	for b in t.bld:
		if TK.has(b): return true
	return false
func _troopBldN(t: Dictionary) -> int:
	var n = 0
	for b in t.bld:
		if TK.has(b): n += 1
	return n
## そこへ入ると、隣の敵に圧倒される（味方を足しても 1.7 倍以上の差）か
func _overwhelmed(tid: int, nid: int, a) -> bool:
	var foeA = []
	for nb in roadNbrs(tid):
		for x in armiesAt(nb.to):
			if x.owner != nid and atWar(nid, x.owner) and total(x.t) > 0: foeA.append(x)
	if foeA.is_empty(): return false
	var here = [a]
	for x in armiesAt(tid):
		if x.owner == nid and x != a and total(x.t) > 0: here.append(x)
	return powerOf(foeA, T(tid), false) > powerOf(here, T(tid), true) * 1.7
func _foeArmyAt(tid: int, nid: int) -> bool:
	for x in armiesAt(tid):
		if x.owner != nid and atWar(nid, x.owner) and total(x.t) > 0: return true
	return false
func _setBld(t: Dictionary, slot: int, k: String) -> void:
	while t.bld.size() <= slot: t.bld.append(null)
	t.bld[slot] = k

## 戦争中の軍の経路は、この先のターン数までだけ調べる（軽さのため。遠い目標は選ばない）
var BFS_WAR_MAX: int = int(OS.get_environment("KN_BFSMAX")) if OS.get_environment("KN_BFSMAX") != "" else 24
func cpuTurn(nid: int) -> void:
	refreshSupply()
	var na = NAT(nid)
	if not na.alive: return
	var own = _ownOf(nid)
	if own.is_empty(): return
	var P: Dictionary = PERSONA.get(na.persona, PERSONA.neutral)
	var _pt = [Time.get_ticks_usec(), "方針"]
	var phase = func(msg: String):
		var now = Time.get_ticks_usec()
		PROF[_pt[1]] = PROF.get(_pt[1], 0) + now - _pt[0]
		_pt[0] = now
		_pt[1] = msg
		var shown = msg.get_slice(":", 0)
		setPhase(nid, P.n + ((" ／ " + shown) if shown != "" else ""))
	hoiTurn(nid)
	phase.call("政策")
	cpuPolicy(nid, P)
	phase.call("外交")
	await yieldMaybe()
	await cpuDiplomacy(nid)
	_tp("")
	await flushDip()
	if not na.alive: return
	phase.call("内政")
	await yieldMaybe()
	cpuSettle(nid)
	# --- 内政：建物 ---
	var mk = 0
	for t in own:
		if t.bld.has("market"): mk += 1
	var troopCap: float = clamp_f(3500 + own.size() * 700, 3500, 34000) * P.goal
	var war = inWar(nid)
	var glut: bool = total(na.stock) > troopCap * 4 and not war
	var cand = []
	for t in own:
		if _bldN(t) < t.dev: cand.append(t)
	cand.sort_custom(func(a, b): return a.dev > b.dev)
	var bal = foodGain(nid) - foodNeed(nid)
	var fcN = factoryCount(nid)
	var cm = costMul(nid)
	var lowSec = 0
	for x in own:
		if x.sec < 45: lowSec += 1
	for t in cand:
		if na.gold < 2500: break
		var k = ""
		if bal <= 0 or na.food < 800: k = "farm"
		elif lowSec > own.size() * 0.25 and randf() < 0.6: k = "gov"
		elif t.type == "city" and mk < max(1, own.size() * P.mkt): k = "market"
		elif t.type == "city" and popRatio(t) > 0.9 and randf() < 0.35 + P.mkt * 0.3: k = "house"
		else:
			var r = randf()
			var acc = 0.0
			k = "inf"
			for kk in TK:
				acc += P.mix[kk]
				if r <= acc:
					k = kk
					break
			if t.type == "city" and randf() < P.mkt * 0.6: k = "market"
		if k != "farm" and k != "gov":
			if na.has("eq") and (na.get("eqMul", 1.0) < 0.9 or (war and na.eq < 4000)) and fcN[0] < own.size() * 0.4 and randf() < 0.6: k = "mf"
			elif fcN[1] < max(1.0, own.size() * 0.12) and randf() < 0.25 + P.mkt * 0.3: k = "cf"
		if TK.has(k) and levyRoom(t) < 900: k = "house" if t.type == "city" else "farm"
		if TK.has(k) and glut: k = "market" if t.type == "city" else "farm"
		if BLD[k].get("cityOnly", false) and t.type == "fort": k = "farm"
		var cost: int = int(round(BLD[k].cost * cm))
		if na.gold < cost: continue
		var slot = -1
		for i in t.dev:
			if i >= t.bld.size() or not t.bld[i]:
				slot = i
				break
		if slot < 0: continue
		na.gold -= cost
		_setBld(t, slot, k)
		if k == "mf": fcN[0] += 1
		if k == "cf": fcN[1] += 1
		if k == "market": mk += 1
		if k == "farm": bal += CFG.farmOut * terrOf(t).food
	if glut and na.gold >= BLD.market.cost * 2:
		for t3 in own:
			if _hasTroopBld(t3):
				var i = -1
				for j in t3.bld.size():
					if TK.has(t3.bld[j]):
						i = j
						break
				var k2 = "market" if t3.type == "city" else "farm"
				na.gold -= BLD[k2].cost
				t3.bld[i] = k2
				break
	if na.food < -200 and na.gold >= BLD.farm.cost:
		var best = null
		for t in own:
			if _hasTroopBld(t) and (best == null or _troopBldN(t) > _troopBldN(best)): best = t
		if best != null:
			for j in best.bld.size():
				if TK.has(best.bld[j]):
					best.bld[j] = "farm"
					break
			na.gold -= BLD.farm.cost
			chron("%s が %s の兵舎を農場に建て替える" % [na.name, best.name], nid, "gov")
	# --- 内政：開発・インフラ ---
	var prosper = hasDesire(nid, "prosper")
	var reserve: float = max(P.devG * (0.4 if prosper else 1.0), na.get("goldIn", 0) * (3 if prosper else 6))
	var devList = []
	for t in own:
		if t.dev < 5 and not t.get("devP", false): devList.append(t)
	devList.sort_custom(func(a, b):
		if a.cap != b.cap: return a.cap
		if (a.type == "city") != (b.type == "city"): return a.type == "city"
		if a.dev != b.dev: return a.dev < b.dev
		return a.pop > b.pop)
	var devMax: int = 1 + own.size() / 10
	var devN = 0
	for t in devList:
		if devN >= devMax or na.gold - DEV_COST[t.dev] < reserve: break
		na.gold -= DEV_COST[t.dev]
		t.devP = true
		devN += 1
	var rich: bool = na.gold > reserve * 1.3
	if na.gold > P.roadG * (0.5 if prosper else 1.0) and (rich or randf() < INFRA_RATE.get(na.persona, 0.12) * (2.5 if prosper else 1.0)):
		var myAt = {}
		for x in na.armies:
			if x != null: myAt[x.at] = true
		var front = {}
		for t in own:
			for nb in roadNbrs(t.id):
				var o: int = T(nb.to).owner
				if o >= 0 and o != nid and atWar(nid, o):
					front[t.id] = true
					break
		var score = func(t): return t.pop / 1500.0 + t.dev * 2 + (8 if t.cap else 0) + TERR_COST.get(t.terrain, 1) * 3 \
			+ (10 if front.has(t.id) else 0) + (4 if myAt.has(t.id) else 0) - t.get("infra", 1) * 4
		var lst = []
		for t in own:
			if t.get("infra", 1) < 3 and not t.get("infraP", false) and not t.get("infraBroke", 0): lst.append(t)
		lst.sort_custom(func(a, b): return score.call(a) > score.call(b))
		var nMax: int = 1 + own.size() / 20 if rich else 1
		var kk2 = 0
		for t in lst:
			if kk2 >= nMax: break
			var c: int = INFRA_COST[t.get("infra", 1) + 1]
			if na.gold - c < (reserve if rich else P.roadG * 0.5): break
			na.gold -= c
			t.infraP = true
			kk2 += 1
	# --- 将軍 ---
	var armed = 0
	for x in na.armies:
		if x != null: armed += 1
	if na.gens.size() < min(GEN_MAX, armed + 1) and na.gold > GEN_COST + 6000:
		na.gold -= GEN_COST
		mkGen(G, na, randomPts())
	# --- 軍団編成 ---
	phase.call("軍団の編成・補充")
	await yieldMaybe()
	var maxA = int(clamp_f(2 + own.size() / 3 + P.army * 2, 1, ARMY_MAX))
	var stockTot = total(na.stock)
	var goalT: float = clamp_f(3500 + own.size() * 700, 3500, 34000) * P.goal * (1.0 + nmod(nid, "cap"))
	if armed < maxA and stockTot > 3000:
		var slot: int = na.armies.find(null)
		if slot >= 0:
			var a = mkArmy(nid, slot, na.capital)
			for k in TK:
				var g: int = min(int(floor(na.stock[k] * 0.8)), int(round(goalT * P.mix[k])))
				a.t[k] = g
				a.target[k] = int(round(goalT * P.mix[k]))
				na.stock[k] -= g
			na.armies[slot] = a; ARMY_REV += 1
	for a in na.armies:
		if a == null: continue
		if a.gen == null:
			for g in na.gens:
				if g.army == null:
					a.gen = g.id
					g.army = a.idx
					break
		for k in TK: a.target[k] = int(round(goalT * P.mix[k]))
		if T(a.at).owner == nid: reinforce(a)
	phase.call("進軍")
	await yieldMaybe()
	# ============ 進軍：守りを固め、主目標に兵を集めて攻める ============
	var list = []
	for x in na.armies:
		if x != null and total(x.t) > 0: list.append(x)
	var danger = cpuDanger(nid)
	var foes = []
	for o in G.nations:
		if o.alive and atWar(nid, o.id): foes.append(o)
	var foeTerrs = []
	if foes.size():
		for t in G.terrs:
			if t.owner != nid and atWar(nid, t.owner): foeTerrs.append(t)
	var RK = {}
	var frontier = []
	for t in own:
		for nb in roadNbrs(t.id):
			if T(nb.to).owner != nid:
				frontier.append(t)
				break
	for t2 in frontier:
		var r = 0
		for nb in roadNbrs(t2.id):
			var o: int = T(nb.to).owner
			if o == nid: continue
			if atWar(nid, o): r += 3
			elif isTense(nid, o): r += 2
			if isTopThreat(o): r += 2
			if atWar(nid, o):
				for x in armiesAt(nb.to):
					if x.owner != nid and total(x.t) > 0:
						r += 2
						break
		if t2.cap: r += 3
		if t2.type == "fort": r += 1
		RK[t2.id] = r
	frontier.sort_custom(func(x, y): return RK[x.id] > RK[y.id] if RK[x.id] != RK[y.id] else x.dev > y.dev)
	var hot = []
	for t in frontier:
		if RK[t.id] > 0: hot.append(t)
	if smartAI(nid) and foes.size():
		var cap = T(na.capital)
		if cap.owner == nid:
			var near2 = {cap.id: true}
			for nb in roadNbrs(cap.id):
				near2[nb.to] = true
				for nb2 in roadNbrs(nb.to): near2[nb2.to] = true
			var threat = false
			for id in near2:
				if _foeArmyAt(id, nid):
					threat = true
					break
			if threat:
				hot.erase(cap)
				hot.push_front(cap)
	var bfsOf = {}
	phase.call("進軍:経路")
	await yieldMaybe()
	var bfsAt = {}
	# 経路（行ける範囲）は要る軍の分だけ計算する。戦争中は目標選びに全軍分が要る
	var getB = func(a):
		if not bfsOf.has(a.idx):
			if not bfsAt.has(a.at): bfsAt[a.at] = bfsFrom(a.at, total(a.t), nid, BFS_WAR_MAX if foes.size() else 1 << 30)
			bfsOf[a.idx] = bfsAt[a.at]
		return bfsOf[a.idx]
	if foes.size():
		for a in list:
			getB.call(a)
			await yieldMaybe()
	phase.call("進軍:目標")
	await yieldMaybe()
	var obj = cpuObjective(nid, list, bfsOf)
	phase.call("進軍:動かす")
	await yieldMaybe()
	var guardRate = clamp_f(P.guard + clamp_f(danger, 0, 1.6) * DIP.guardDanger, 0.2, 0.9)
	if foes.size() and obj != null: guardRate = min(guardRate, 0.55)
	var nDef = int(round(list.size() * guardRate))
	if foes.size() and obj != null: nDef = min(nDef, max(0, list.size() - max(1, int(ceil(list.size() * 0.4)))))
	var guard = {}
	var freeA = list.duplicate()
	var hotSet = {}
	for t in hot: hotSet[t.id] = true
	var postTaken = {}
	for a in list:
		if guard.size() >= nDef: break
		var ps = a.get("post")
		if ps != null and hotSet.has(ps) and not postTaken.has(ps) and (a.at == ps or bhas(getB.call(a), ps)):
			guard[a.idx] = ps
			postTaken[ps] = true
			freeA.erase(a)
	for t in hot:
		if guard.size() >= nDef: break
		if postTaken.has(t.id): continue
		var taken = false
		for x in armiesAt(t.id):
			if guard.has(x.idx) and x.owner == nid:
				taken = true
				break
		if taken: continue
		var bestA = null
		var bd = INF
		for a in freeA:
			var d = bget(getB.call(a), t.id)
			if d == null: continue
			if d < bd:
				bd = d
				bestA = a
		if bestA != null:
			guard[bestA.idx] = t.id
			bestA.post = t.id
			postTaken[t.id] = true
			freeA.erase(bestA)
	# ===== 前線：戦争中は、敵軍の脅威に応じて前線へ軍を回す（1か所に何軍でも）。攻勢の分は残す =====
	var frontSet = {}
	if foes.size() and smartAI(nid):
		var offKeep: int = int(ceil(list.size() * 0.45)) if obj != null else 0
		var fr = []
		for t in frontier:
			var foeA = []
			var warNb = false
			for nb in roadNbrs(t.id):
				var o: int = T(nb.to).owner
				if o >= 0 and o != nid and atWar(nid, o): warNb = true
				for x in armiesAt(nb.to):
					if x.owner != nid and atWar(nid, x.owner) and total(x.t) > 0: foeA.append(x)
			if not warNb and foeA.is_empty(): continue
			fr.append([t, powerOf(foeA, t, false) if foeA.size() else 0.0])
		fr.sort_custom(func(x, y): return x[1] > y[1])
		var myF = 0.0
		var foeF = 0.0
		for e in fr:
			foeF += e[1]
			var mineF = []
			for x in armiesAt(e[0].id):
				if x.owner == nid and total(x.t) > 0: mineF.append(x)
			if mineF.size(): myF += powerOf(mineF, e[0], false)
		for a in list:
			if T(a.at).owner != nid: myF += powerOf([a], T(a.at), false)
		offensiveCheck(nid, myF, foeF)
		# 脅威のない持ち場（首都を除く）の守備軍も、前線へ回せるようにする
		var thrSet = {}
		for e in fr:
			if e[1] > 0: thrSet[e[0].id] = true
		var spare = []
		for aid in guard.keys():
			var gt: int = guard[aid]
			if thrSet.has(gt) or T(gt).cap: continue
			var ga = na.armies[aid]
			if ga != null and not freeA.has(ga): spare.append(ga)
		for e in fr:
			if e[1] <= 0: break
			var t = e[0]
			var mine = []
			for x in armiesAt(t.id):
				if x.owner == nid and total(x.t) > 0: mine.append(x)
			for aid in guard:
				if guard[aid] == t.id and na.armies[aid] != null and not mine.has(na.armies[aid]): mine.append(na.armies[aid])
			var have: float = powerOf(mine, t, true) if mine.size() else 0.0
			while have < e[1] * 0.7 and (freeA.size() > offKeep or spare.size()):
				var bestA = null
				var bd = INF
				for a in (freeA if freeA.size() > offKeep else []) + spare:
					var d = bget(getB.call(a), t.id)
					if d == null or d > 6: continue
					var dd: float = d + (2.0 if spare.has(a) else 0.0)
					if dd < bd:
						bd = dd
						bestA = a
				if bestA == null: break
				guard[bestA.idx] = t.id
				bestA.post = t.id
				frontSet[bestA.idx] = true
				freeA.erase(bestA)
				spare.erase(bestA)
				mine.append(bestA)
				have = powerOf(mine, t, true)
		# 見張り：敵軍のいない前線にも、余裕があれば1軍
		for e in fr:
			if e[1] > 0: continue
			if freeA.size() <= offKeep: break
			var t = e[0]
			var covered = false
			for x in armiesAt(t.id):
				if x.owner == nid: covered = true
			for aid in guard:
				if guard[aid] == t.id: covered = true
			if covered: continue
			var bestA = null
			var bd = INF
			for a in freeA:
				var d = bget(getB.call(a), t.id)
				if d == null or d > 3: continue
				if d < bd:
					bd = d
					bestA = a
			if bestA != null:
				guard[bestA.idx] = t.id
				bestA.post = t.id
				freeA.erase(bestA)
	var order = list.duplicate()
	order.sort_custom(func(x, y):
		var sx = 0 if obj != null and x.at == obj.stage else 1
		var sy = 0 if obj != null and y.at == obj.stage else 1
		if sx != sy: return sx < sy
		return total(x.t) > total(y.t))
	var goal2 = goalT
	for a in order:
		if G.over != null: return
		await yieldMaybe()
		if na.armies[a.idx] != a: continue
		if total(a.t) <= 0 or a.moved: continue
		if a.get("siege") != null:
			a.path = []
			a.stay = "包囲"
			continue
		a.stay = "行き先なし"
		var tot = total(a.t)
		UI.actArmy = a
		# 平時に持ち場にいる軍はそのまま（経路の計算も省く）
		if foes.is_empty() and T(a.at).owner == nid and guard.get(a.idx, a.get("post")) == a.at:
			a.path = []
			a.stay = "守備"
			continue
		var bsA: Dictionary = getB.call(a)
		# どこへも行けない軍団は、同じ場所の味方に合流させる
		if bsA.n <= 1:
			var mate = null
			for x in armiesAt(a.at):
				if x != a and x.owner == nid and total(x.t) > 0 and bfsFrom(x.at, total(x.t) + tot, nid).n > 1:
					mate = x
					break
			if mate != null:
				for k in TK:
					mate.t[k] += a.t[k]
					a.t[k] = 0
				if a.gen != null:
					var g = genOf(na, a.gen)
					if g != null: g.army = null
				na.armies[a.idx] = null; ARMY_REV += 1
				logMsg("%s %s を %s に合流させました" % [na.name, a.name, mate.name])
				continue
		# 損耗した軍団は下がって立て直す
		if tot < goal2 * 0.3 and total(na.stock) > goal2 * 0.3 and T(a.at).owner != nid:
			var back = nearestOwnCity(a, bsA, nid)
			if back != null and back != a.at:
				var p = pathFrom(bsA, back)
				if p != null and p.size():
					a.path = p
					a.why = "後退"
					await advanceArmy(a)
					await cpuBeat(a)
					continue
		# 圧倒的な敵軍が隣に迫っていたら一歩下がる
		if smartAI(nid) and not T(a.at).cap and T(a.at).owner == nid:
			var foeA = []
			for nb in roadNbrs(a.at):
				for x in armiesAt(nb.to):
					if x.owner != nid and atWar(nid, x.owner) and total(x.t) > 0: foeA.append(x)
			if foeA.size():
				var here = []
				for x in armiesAt(a.at):
					if x.owner == nid and total(x.t) > 0: here.append(x)
				var thr = powerOf(foeA, T(a.at), false)
				var dfp = powerOf(here, T(a.at), true)
				if thr > dfp * 2.2:
					var bt = null
					var bsc = -INF
					for nb in roadNbrs(a.at):
						var u = T(nb.to)
						if u.owner != nid: continue
						var exposed = false
						for nb2 in roadNbrs(nb.to):
							if _foeArmyAt(nb2.to, nid):
								exposed = true
								break
						if exposed: continue
						var mineHere = 0.0
						for x in armiesAt(nb.to):
							if x.owner == nid: mineHere += total(x.t)
						var sc: float = (30 if u.cap else 0) + (15 if u.type == "fort" else 0) + mineHere / 1000.0
						if sc > bsc:
							bsc = sc
							bt = nb.to
					if bt != null:
						a.path = [bt]
						a.why = "一歩下がる"
						await advanceArmy(a)
						await cpuBeat(a)
						continue
		# 入るのに何ターンもかかる領地へ歩いている途中なら、そのまま進む（歩みを無駄にしない）
		var pg = a.get("prog")
		if pg != null and a.get("progN", 0) > 0 and edgeBetween(a.at, pg) != null and canEnter(nid, pg) and (T(pg).owner == nid or atWar(nid, T(pg).owner)) and not (smartAI(nid) and _overwhelmed(pg, nid, a)):
			a.path = [pg]
			a.why = "歩みを続ける"
			await advanceArmy(a)
			await cpuBeat(a)
			continue
		# 守備軍：持ち場を固める
		if guard.has(a.idx):
			var dst: int = guard[a.idx]
			if a.at == dst:
				# 最前線の守備軍：隣の敵領地が空か、こちらが2倍以上強ければ取って前に出る（持ち場も移す）
				var grab = null
				if smartAI(nid):
					var myP = powerOf([a], T(a.at), false)
					for nb in roadNbrs(a.at):
						var tg = T(nb.to)
						if tg.owner == nid or tg.owner < 0 or not atWar(nid, tg.owner) or not canEnter(nid, nb.to): continue
						var g3 = []
						for x in armiesAt(nb.to):
							if total(x.t) > 0: g3.append(x)
						var dp3 = powerOf(g3, tg, true) if g3.size() else 0.0
						if myP > 0 and myP >= dp3 * (1.2 if na.get("offensive", false) else 2.0) and orgOf(a) >= 40 and not _overwhelmed(nb.to, nid, a):
							grab = nb.to
							break
				if grab != null:
					a.path = [grab]
					a.why = "守備から前進"
					a.post = grab
					await advanceArmy(a)
					await cpuBeat(a)
					continue
				a.path = []
				a.wait = 0
				a.stay = "守備"
				continue
			if smartAI(nid) and not frontSet.has(a.idx) and _overwhelmed(dst, nid, a):
				a.path = []
				a.stay = "様子見"
				continue
			var p2 = pathFrom(bsA, dst)
			if p2 != null and p2.size():
				a.path = p2
				a.why = "守備へ"
				await advanceArmy(a)
				await cpuBeat(a)
			continue
		# 補充待ち
		if T(a.at).owner == nid and tot < goal2 * 0.55 and total(na.stock) > 1000 and a.get("wait", 0) < 3:
			a.stay = "補充待ち"
			a.wait = a.get("wait", 0) + 1
			a.path = []
			continue
		# 組織率が低い軍は自国の領地で休む
		if orgOf(a) < 35 and T(a.at).owner == nid and not _foeArmyAt(a.at, nid):
			a.path = []
			a.stay = "休養"
			continue
		# 隣に攻められる敵領地があれば取る
		var mine = powerOf([a], T(a.at), false)
		var best = null
		var bestScore = -1.0
		for nb in roadNbrs(a.at):
			var t = T(nb.to)
			if t.owner == nid or not atWar(nid, t.owner): continue
			var gar = []
			for x in armiesAt(nb.to):
				if total(x.t) > 0: gar.append(x)
			var help = []
			for x in armiesAt(a.at):
				if x != a and x.owner == nid and not x.moved and total(x.t) > 0: help.append(x)
			var dp = powerOf(gar, t, true) if gar.size() else 0.0
			var mineAll = powerOf([a] + help, T(a.at), false) if help.size() else mine
			if mineAll >= dp * (P.atkTh + clamp_f(danger, 0, 1.5) * 0.25):
				var sc: float = (40 if t.cap else 0) + t.dev * 6 + (-6 if t.type == "fort" else 4) \
					- dp / max(1.0, mineAll) * 20 + (14 if isTopThreat(t.owner) else 0) \
					+ (25 if obj != null and nb.to == obj.tid else 0) + (6 if t.get("trait") != null else 0) \
					+ contig(t, nid) * 8 + reconnect(t, nid) * 12 - foeNbrs(t, nid) * 5 \
					+ (stratBonus(nid, t) * 0.8 if smartAI(nid) else 0.0)
				if sc > bestScore:
					bestScore = sc
					best = nb.to
		if best != null:
			a.wait = 0
			a.path = [best]
			a.why = "隣を攻める"
			await advanceArmy(a)
			await cpuBeat(a)
			continue
		# 主目標へ：集結地に集まってから攻める
		if obj != null:
			if a.at == obj.stage:
				var force = []
				for x in armiesAt(a.at):
					if x.owner == nid and not x.moved and total(x.t) > 0: force.append(x)
				var gar2 = []
				for x in armiesAt(obj.tid):
					if total(x.t) > 0: gar2.append(x)
				var dp2 = powerOf(gar2, T(obj.tid), true) if gar2.size() else 0.0
				var pw = powerOf(force, T(a.at), false) if force.size() else 0.0
				if force.has(a) and pw >= dp2 * P.atkTh:
					a.wait = 0
					a.path = [obj.tid]
					a.why = "目標を攻める"
					await advanceArmy(a)
					await cpuBeat(a)
					continue
				a.wait = a.get("wait", 0) + 1
				if a.wait >= 4 and pw >= dp2 * 1.05:
					a.wait = 0
					a.path = [obj.tid]
					a.why = "目標を攻める"
					await advanceArmy(a)
					await cpuBeat(a)
					continue
				a.stay = "集結待ち"
				a.path = []
				continue
			if smartAI(nid) and _overwhelmed(obj.stage, nid, a):
				a.path = []
				a.stay = "様子見"
				continue
			var p3 = pathFrom(bsA, obj.stage)
			if p3 != null and p3.size():
				a.wait = 0
				a.path = p3
				a.why = "集結地へ"
				await advanceArmy(a)
				await cpuBeat(a)
				continue
		# 目標が無い／届かない：最寄りの敵拠点、なければ危ない国境へ
		var dest = null
		var bd2 = INF
		for t in foeTerrs:
			if t.owner == nid or not atWar(nid, t.owner): continue
			var dd = bget(bsA, t.id)
			if dd == null: continue
			var d2v: float = dd - (2 if isTopThreat(t.owner) else 0)
			if d2v < bd2:
				bd2 = d2v
				dest = t.id
		if dest == null:
			var ps2 = a.get("post")
			if ps2 != null and T(ps2).owner == nid and bhas(bsA, ps2):
				dest = ps2
			else:
				var usedP = {}
				for x in list:
					if x != a and x.get("post") != null: usedP[x.post] = true
				var bp = null
				var bv = -INF
				for t in frontier:
					if usedP.has(t.id) or not bhas(bsA, t.id) or RK[t.id] <= 0: continue
					var v: float = RK[t.id] * 10 - bget(bsA, t.id)
					if v > bv:
						bv = v
						bp = t.id
				if bp == null: bp = a.at if T(a.at).owner == nid else (na.capital if T(na.capital).owner == nid else a.at)
				a.post = bp
				dest = bp
		if dest != null and dest != a.at:
			var p4 = pathFrom(bsA, dest)
			if p4 != null and p4.size():
				a.path = p4
				a.why = "敵地へ" if foes.size() else "持ち場へ"
				await advanceArmy(a)
				await cpuBeat(a)
	UI.actArmy = null
	phase.call("")

## CPUの一手ごとの演出。観戦中は「選んだ国」とその国の土地での戦いだけを見せる
func cpuBeat(a) -> void:
	if str(CFG.cpuStop) == "auto" or CFG.cpuDelay <= 0: return
	var f = followNat()
	if f == null or f < 0 or a == null: return
	if a.owner != f and not (atWar(a.owner, f) and T(a.at).owner == f): return
	if onScreenFn.is_valid() and not onScreenFn.call(T(a.at)): return
	if BEAT_SPENT + BATTLE_SPENT >= BEAT_MAX: return
	beat.emit()
	var d: int = min(CFG.cpuDelay, BEAT_MAX - BEAT_SPENT - BATTLE_SPENT)
	BEAT_SPENT += d
	await sleep_ms(d)

# ==================== k7_game.gd ====================
# 起動・速さ・セーブ／ロード・表示の好み（元 7220〜7400・7608〜7780）

signal game_started
var auto_on = false

func newGame(size: String) -> void:
	resetColors()
	G = genJapan() if size == "japan" else genMap(size)
	G.observer = true
	for t in G.terrs:
		t.home = t.owner
		t.homeCap = t.cap
	G.factions = {}
	G.ncol = NCOL.duplicate()
	hoiInit(G)
	beginGame()
func _resetCaches() -> void:
	NBR = null; NBR_G = null; SEGN_DONE = null; COAST_G = null; HOP_G = null; ADJ_G = null
	PW_KEY = -1; THR_KEY = -1; DG_KEY = -1; SUP_TERR_KEY = ""; SUP_DIRTY = true
	FOCUS_CACHE = {}; SPROG_MEMO = {}; DIPQ = []
	_treeCache = {}
func beginGame() -> void:
	_resetCaches()
	UI.sel = null; UI.selArmy = null; UI.selRoad = null; UI.busy = false; UI.auto = false; UI.selNat = null
	auto_on = false
	G.log = []
	refreshSupply(true)
	var names = []
	for n in G.nations: names.append(n.name)
	chron("%dつの国が並び立つ — %s" % [G.nations.size(), "、".join(names)], -1, "end")
	for n in G.nations: chron("%s、%s に旗を立てる（%s）" % [n.name, T(n.capital).name, PERSONA[n.persona].n], n.id, "gov")
	recordHistory()
	logMsg("観戦モード：全%dか国をCPUが操作します" % G.nations.size(), "good")
	logMsg("「自動進行」で連続再生、「戦闘表示」で戦闘画面の表示を切り替えられます")
	game_started.emit()
	refreshed.emit()

## 自動進行（もう一度呼ぶと止まる）
signal auto_changed(on: bool)
var _turnEma = 0.0
func toggleAuto() -> void:
	if G == null or G.over != null: return
	auto_on = not auto_on
	UI.auto = auto_on
	auto_changed.emit(auto_on)
	if not auto_on: return
	while auto_on and G != null and G.over == null:
		if UI.busy:
			await sleep_ms(200)
			continue
		var t0 = Time.get_ticks_msec()
		await endTurn()
		# ターンの間隔をなめらかに：最近のターンの長さの平均（戦闘画面の時間は除く）に合わせて待つ
		var el: int = Time.get_ticks_msec() - t0
		var work: float = el - BATTLE_SPENT
		_turnEma = work if _turnEma <= 0 else _turnEma * 0.8 + work * 0.2
		var target: float = max(float(CFG.autoTurnMs), _turnEma * 0.95)
		await sleep_ms(int(max(40, target - el)))
	auto_on = false
	UI.auto = false
	auto_changed.emit(false)
func stopAuto() -> void:
	if auto_on:
		auto_on = false
		UI.auto = false
		auto_changed.emit(false)

# ---------- 速さ ----------
const SPEEDS := [
	{"n": "遅い", "auto": 1600, "cpu": 520, "phase": 700, "beat": 4500},
	{"n": "普通", "auto": 700, "cpu": 340, "phase": 480, "beat": 2500},
	{"n": "速い", "auto": 250, "cpu": 130, "phase": 160, "beat": 900},
	{"n": "最速", "auto": 40, "cpu": 0, "phase": 0, "beat": 0},
]
func setSpeed(i: int, save := true) -> void:
	i = int(clamp_f(i, 0, SPEEDS.size() - 1))
	var s: Dictionary = SPEEDS[i]
	CFG.autoTurnMs = s.auto; CFG.cpuDelay = s.cpu; CFG.phaseDelay = s.phase; BEAT_MAX = s.beat
	UI.speed = i
	if save: savePrefs()

# ---------- 表示の好み（この端末だけ） ----------
const PREF_PATH := "user://prefs.json"
func loadPrefs() -> void:
	var p = {}
	if FileAccess.file_exists(PREF_PATH):
		var v = JSON.parse_string(FileAccess.get_file_as_string(PREF_PATH))
		if v is Dictionary: p = v
	if p.get("battle") is bool: CFG.showCpuBattle = p.battle
	if p.get("dip") is bool: CFG.showDip = p.dip
	if p.get("log") is bool: UI.logOn = p.log
	UI.bgm = p.get("bgm", true) if p.get("bgm") is bool else true
	UI.sfx = p.get("sfx", true) if p.get("sfx") is bool else true
	UI.bgmVol = int(p.get("bgmVol", 70)) if (p.get("bgmVol") is float or p.get("bgmVol") is int) else 70
	UI.sfxVol = int(p.get("sfxVol", 60)) if (p.get("sfxVol") is float or p.get("sfxVol") is int) else 60
	setSpeed(int(p.get("speed", 1)))
func savePrefs() -> void:
	var f = FileAccess.open(PREF_PATH, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({"speed": UI.speed, "battle": CFG.showCpuBattle, "dip": CFG.showDip, "log": UI.logOn, "bgm": UI.get("bgm", true), "sfx": UI.get("sfx", true), "bgmVol": UI.get("bgmVol", 70), "sfxVol": UI.get("sfxVol", 60)}))
	f.close()

# ---------- セーブ／ロード（3スロット） ----------
func _slotPath(i: int) -> String: return "user://slot%d.sav" % i
func _slotInfoPath(i: int) -> String: return "user://slot%d.json" % i
func slotInfo(i: int):
	if not FileAccess.file_exists(_slotInfoPath(i)) or not FileAccess.file_exists(_slotPath(i)): return null
	var v = JSON.parse_string(FileAccess.get_file_as_string(_slotInfoPath(i)))
	return v if v is Dictionary else null
func _stripForSave(g: Dictionary) -> Dictionary:
	var c: Dictionary = g.duplicate(true)
	for na in c.nations: na.erase("supSet")
	for t in c.terrs:
		t.erase("segN"); t.erase("bb")
		if c.size == "japan":
			t.erase("segs"); t.erase("sn")
	if c.size == "japan":
		c.erase("edges"); c.erase("nb")
	for na in c.nations:
		for a in na.armies:
			if a != null: a.erase("anim")
	return c
func saveSlot(i: int) -> bool:
	if G == null: return false
	var dt = Time.get_datetime_dict_from_system()
	G.savedAt = "%02d/%02d %02d:%02d" % [dt.month, dt.day, dt.hour, dt.minute]
	G.savedTs = Time.get_unix_time_from_system()
	var f = FileAccess.open_compressed(_slotPath(i), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null: return false
	f.store_var(_stripForSave(G))
	f.close()
	var alive = 0
	for n in G.nations:
		if n.alive: alive += 1
	var inf = FileAccess.open(_slotInfoPath(i), FileAccess.WRITE)
	inf.store_string(JSON.stringify({"turn": G.turn, "size": G.size, "nat": alive, "all": G.terrs.size(), "date": G.savedAt, "ts": G.savedTs}))
	inf.close()
	logMsg("スロット%d にセーブしました" % i, "good")
	return true
func loadSlot(i: int) -> bool:
	if not FileAccess.file_exists(_slotPath(i)): return false
	var f = FileAccess.open_compressed(_slotPath(i), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null: return false
	var g = f.get_var()
	f.close()
	if not (g is Dictionary): return false
	if g.size == "japan":
		var fm = FileAccess.open_compressed(jpMapPath(int(g.get("jpMap", 0))), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		var m: Dictionary = fm.get_var()
		fm.close()
		for k in g.terrs.size():
			g.terrs[k].segs = m.terrs[k].segs
			g.terrs[k].sn = m.terrs[k].sn
		g.edges = m.edges
		g.nb = m.nb
	if g.nations.size() and not IDEO.has(g.nations[0].get("ideo", "")):
		for n in g.nations:
			n.erase("ideo")
		hoiInit(g)
	for n in g.nations:
		if n.has("ideo"): politicsInit(n)
	resourceInit(g)
	resetColors(g.get("ncol", null))
	stopAuto()
	G = g
	_resetCaches()
	UI.sel = null; UI.selArmy = null; UI.selNat = null; UI.busy = false
	refreshSupply(true)
	game_started.emit()
	refreshed.emit()
	logMsg("スロット%d をロードしました" % i, "good")
	return true
func latestSlot() -> int:
	var best = 0
	var bt = -1.0
	for i in [1, 2, 3]:
		var s = slotInfo(i)
		if s != null and float(s.get("ts", 1)) > bt:
			bt = float(s.get("ts", 1))
			best = i
	return best

## 起動の時間の記録（URL に #boottime を付けた時だけ、ブラウザのコンソールに出す）
func _enter_tree() -> void: bootMark("土台のスクリプトが動き始めた")
func bootMark(what: String) -> void:
	if OS.get_environment("KN_FAKEWEB") != "": print("BOOT ", Time.get_ticks_msec(), "ms ", what)
	if not OS.has_feature("web"): return
	JavaScriptBridge.eval("if (location.hash.indexOf('boottime') >= 0) console.log('BOOT ' + Math.round(performance.now()) + 'ms %s')" % what.replace("'", ""), true)
## セーブが使う日本地図の番号（日本地図でなければ -1）
func slotJpMap(i: int) -> int:
	if not FileAccess.file_exists(_slotPath(i)): return -1
	var f = FileAccess.open_compressed(_slotPath(i), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null: return -1
	var g = f.get_var()
	f.close()
	if not (g is Dictionary) or g.get("size") != "japan": return -1
	return int(g.get("jpMap", 0))

# ==================== k8_hoi.gd ====================
# HOI4を参考にした仕組み：政体・安定度・戦争支持・政治力・国民精神・工場と軍需品・国家方針
# （データは k9_data.gd）

## 工業の盛んな県は、最初から工場を持つ（[軍需, 民需]）
const START_IND := {"群馬県": [3, 2], "東京都": [2, 3], "大阪府": [2, 4], "北海道": [2, 1], "長野県": [2, 2], "愛知県": [1, 2], "福岡県": [2, 2], "栃木県": [2, 1], "神奈川県": [1, 2], "兵庫県": [1, 1], "広島県": [1, 1], "埼玉県": [1, 1], "千葉県": [1, 1]}
const EQ_PER_MF := 300       # 軍需工場1つの軍需品（毎ターン）
const CF_GOLD := 300         # 民需工場1つのゴールド
const EQ_COST := 0.5         # 兵1人に要る軍需品
const FOCUS_UNIQUE_X := 13   # 固有の枝を置く列

# ---------- 初期化 ----------
func hoiInit(g: Dictionary) -> void:
	PW_KEY = -1
	var gen = []
	for sp in GENERIC_SPIRITS: gen.append(sp)
	gen.shuffle()
	for na in g.nations:
		if na.has("ideo"): continue
		var cd = COUNTRY.get(na.name)
		var ideo = ""
		var pop = {}
		if cd != null:
			ideo = cd.ideo
			na.role = cd.r
			for k in IDEO_KEYS: pop[k] = cd.pop.get(k, 2.0)
			var rest = 0.0
			for k in IDEO_KEYS:
				if k != ideo: rest += pop[k]
			pop[ideo] = max(40.0, 100.0 - rest)
		else:
			# 架空の大陸：思想はくじ（非同盟が多め）
			var r = randf()
			ideo = "neutral" if r < 0.4 else ("democracy" if r < 0.62 else ("fascism" if r < 0.82 else "communism"))
			for k in IDEO_KEYS: pop[k] = 8.0 + randf() * 12.0
			pop[ideo] = 55.0
		na.ideo = ideo
		na.persona = ideo
		if G == g: refreshRole(na)
		na.ipop = pop
		_normPop(na)
		na.stab = 55.0 + IDEO[ideo].stab + (cd.get("stab", 0) if cd != null else 0)
		na.ws = 25.0 + IDEO[ideo].ws
		na.pp = 50.0
		na.eq = 3000
		na.spirits = []
		na.guar = []
		na.focus = {"cur": null, "prog": 0, "done": []}
		politicsInit(na)
		na.tech = {}
		na.rsch = []
		if cd != null:
			for sp in cd.sp: _addSpirit(na, sp[0], sp[1], sp[2], "固有")
			# 開始時の底上げ（大国の工業力・兵の蓄え）
			var bo = cd.get("boost", {})
			if bo.has("stock"):
				for k in na.stock: na.stock[k] = int(na.stock[k] * bo.stock)
			if bo.has("dev"):
				for t in g.terrs:
					if t.owner == na.id and t.type == "city": t.dev = min(5, t.dev + int(bo.dev))
		elif gen.size(): _addSpirit(na, gen[na.id % gen.size()][0], gen[na.id % gen.size()][1], gen[na.id % gen.size()][2], "固有")
		hoiRecalc(na)
		na.stab = clamp_f(na.stab + na.mods.get("stab", 0.0), 5, 95)
		na.ws = clamp_f(na.ws + na.mods.get("ws", 0.0), 0, 95)
	resourceInit(g)
	# 領地が多すぎる国は統治が行き届かない
	var cnt = {}
	for t in g.terrs:
		if t.owner >= 0: cnt[t.owner] = cnt.get(t.owner, 0) + 1
	var vals: Array = cnt.values()
	vals.sort()
	if vals.size():
		var med: float = vals[vals.size() / 2]
		for na in g.nations:
			if cnt.get(na.id, 0) >= med * 1.35:
				_addSpirit(na, "広大な辺境", "領地が広すぎて目が届かない：ゴールド -10%・兵の生産 -10%・安定度 -10", {"gold": -0.10, "troop": -0.10, "stab": -10.0}, "固有")
				na.stab = clamp_f(na.stab - 10, 5, 95)
	# 最初の工場：首都に軍需・民需を1つずつ（工業県はもっと）
	var G0 = G
	G = g
	PW_KEY = -1
	for na in g.nations:
		var ind = START_IND.get(na.name, [1, 1])
		_buildFactories(na.id, "mf", ind[0], true)
		_buildFactories(na.id, "cf", ind[1], true)
	G = G0
	PW_KEY = -1
func _normPop(na: Dictionary) -> void:
	var s = 0.0
	for k in IDEO_KEYS: s += max(0.0, na.ipop.get(k, 0.0))
	if s <= 0: s = 1
	for k in IDEO_KEYS: na.ipop[k] = max(0.0, na.ipop.get(k, 0.0)) * 100.0 / s

# ---------- 国民精神と修正 ----------
func _addSpirit(na: Dictionary, n: String, d: String, m: Dictionary, src := "") -> void:
	for sp in na.spirits:
		if sp.n == n: return
	na.spirits.append({"n": n, "d": d, "m": m, "src": src})
	hoiRecalc(na)
func _rmSpirit(na: Dictionary, n: String) -> void:
	for sp in na.spirits.duplicate():
		if sp.n == n: na.spirits.erase(sp)
	hoiRecalc(na)
func hoiRecalc(na: Dictionary) -> void:
	var m = {}
	for sp in na.get("spirits", []):
		for k in sp.m: m[k] = m.get(k, 0.0) + sp.m[k]
	var im: Dictionary = IDEO.get(na.get("ideo", "neutral"), IDEO.neutral).mod
	for k in im: m[k] = m.get(k, 0.0) + im[k]
	politicsMods(na, m)
	techMods(na, m)
	na.mods = m
## 修正の値（国民精神と政体の合計）
func nmod(nid, key: String) -> float:
	if nid == null or nid < 0: return 0.0
	return G.nations[nid].get("mods", {}).get(key, 0.0)
## 安定度による生産の倍率（50で1倍、0で0.75倍、100で1.15倍）
func stabMul(na: Dictionary) -> float: return clamp_f(0.75 + na.get("stab", 50.0) / 200.0, 0.75, 1.15)
## 建設費の倍率（民需工場が多いほど安い）
func costMul(nid: int) -> float:
	var cf = 0
	for t in ownList(nid): cf += bldCount(t, "cf")
	return clamp_f(1.0 + nmod(nid, "build") - cf * 0.02, 0.6, 1.3)

# ---------- 工場 ----------
func _buildFactories(nid: int, kind: String, n: int, start := false) -> int:
	var made = 0
	for k in n:
		var cand = []
		for t in ownList(nid):
			var used = 0
			for b in t.bld:
				if b: used += 1
			if used < t.dev: cand.append(t)
		if cand.is_empty():
			# 空き枠がなければ、町の開発度を上げて枠を作る
			for t in G.terrs:
				if t.owner == nid and t.type == "city" and t.dev < 5: cand.append(t)
			if cand.is_empty(): break
			cand.sort_custom(func(a, b): return a.dev > b.dev)
			cand[0].dev += 1
			cand = [cand[0]]
		cand.sort_custom(func(a, b):
			if a.cap != b.cap: return a.cap
			return a.dev > b.dev)
		var t = cand[0]
		var slot = -1
		for i in t.dev:
			if i >= t.bld.size() or not t.bld[i]:
				slot = i
				break
		if slot < 0: break
		while t.bld.size() <= slot: t.bld.append(null)
		t.bld[slot] = kind
		made += 1
	return made
func factoryCount(nid: int) -> Array:
	var mf = 0
	var cf = 0
	for t in ownList(nid):
		mf += bldCount(t, "mf")
		cf += bldCount(t, "cf")
	return [mf, cf]

# ---------- 毎ターン（国ごと） ----------
func hoiTurn(nid: int) -> void:
	var na = NAT(nid)
	if not na.alive or not na.has("ideo"): return
	var ideo: Dictionary = IDEO[na.ideo]
	var _h0 = Time.get_ticks_usec()
	var war = inWar(nid)
	var dg = cpuDanger(nid)
	politicsTurn(na)
	researchTurn(na)
	civilWarTurn(na)
	supportTurn(na)
	factionApplyTurn(na)
	# 戦争中に達成した開戦の方針は、戦争が終わってから
	var pw = na.get("pendingWar", -1)
	if pw >= 0 and not war:
		na.pendingWar = -1
		if NAT(pw).alive and nationsAdjacent(nid, pw) and canPrepare(nid, pw) and hoiWarOK(nid, pw):
			_turnOn(nid, pw)
			grantCB(nid, pw, "持ち越した開戦の方針", 40)
			startWarPrep(nid, pw)
			na.forceWar = pw
	var _h1 = Time.get_ticks_usec()
	PROF["hoi:危険度"] = PROF.get("hoi:危険度", 0) + _h1 - _h0
	# 政治力
	na.pp = min(400.0, na.pp + ideo.pp + 2.0 + nmod(nid, "pp"))
	# 安定度と戦争支持は目標へ少しずつ寄る
	var st: float = 55.0 + ideo.stab + nmod(nid, "stab") - na.get("fatigue", 0) * 0.3 - (15 if na.food <= 0 else 0) - (5 if lordOf(nid) != null else 0)
	var ws: float = 25.0 + ideo.ws + nmod(nid, "ws") + dg * 30.0 + (10 if war else 0) - na.get("fatigue", 0) * 0.6 + tension() * 0.35
	var _h2 = Time.get_ticks_usec()
	var top = topThreat()
	if top != null and top.id != nid and nationsAdjacent(nid, top.id): ws += 10
	for o in G.nations:
		if o.alive and o.id != nid and isTense(nid, o.id) and prepBy(nid, o.id) == o.id:
			ws += 15
			break
	PROF["hoi:脅威・緊張"] = PROF.get("hoi:脅威・緊張", 0) + Time.get_ticks_usec() - _h2
	var _h3 = Time.get_ticks_usec()
	na.stab = clamp_f(na.stab + (clamp_f(st, 0, 100) - na.stab) * 0.12, 0, 100)
	na.ws = clamp_f(na.ws + (clamp_f(ws, 0, 100) - na.ws) * 0.12, 0, 100)
	# 政体の支持率：与党は安定度が高いほど伸び、隣国の政体にも引っ張られる
	na.ipop[na.ideo] = na.ipop[na.ideo] + (na.stab - 40) * 0.02
	for o in G.nations:
		if o.alive and o.id != nid and nationsAdjacent(nid, o.id) and o.has("ideo"):
			na.ipop[o.ideo] = na.ipop.get(o.ideo, 0.0) + 0.08
	_normPop(na)
	_ideoShift(na)
	PROF["hoi:支持"] = PROF.get("hoi:支持", 0) + Time.get_ticks_usec() - _h3
	var _h4 = Time.get_ticks_usec()
	# 同じ政体どうしは近づき、違う政体とは少し離れる
	for o in G.nations:
		if not o.alive or o.id == nid or not o.has("ideo") or not natNear(nid, o.id): continue
		if o.ideo == na.ideo:
			if favorOf(nid, o.id) < 70: addFavor(nid, o.id, 0.4)
		elif favorOf(nid, o.id) > 20: addFavor(nid, o.id, -0.15)
	PROF["hoi:好感度"] = PROF.get("hoi:好感度", 0) + Time.get_ticks_usec() - _h4
	var _h5 = Time.get_ticks_usec()
	# 思想の合わない同盟は解ける
	for o in G.nations:
		if o.alive and o.id != nid and isAlly(nid, o.id) and not isVassal(o.id, nid) and not isVassal(nid, o.id) and not ideoCompat(nid, o.id) and randf() < 0.15:
			breakAlly(nid, o.id)
			chron("%s と %s の同盟が思想の違いで解消される" % [na.name, o.name], nid, "dip")
	PROF["hoi:同盟"] = PROF.get("hoi:同盟", 0) + Time.get_ticks_usec() - _h5
	var _h6 = Time.get_ticks_usec()
	# 国家方針
	_focusTurn(na)
	PROF["hoi:方針"] = PROF.get("hoi:方針", 0) + Time.get_ticks_usec() - _h6
## 政変：ほかの思想の支持が過半を超え、安定度が低い（または圧倒的な支持）と政権が変わる
func _ideoShift(na: Dictionary) -> void:
	var best: String = na.ideo
	for k in IDEO_KEYS:
		if na.ipop[k] > na.ipop[best]: best = k
	if best == na.ideo: return
	var p: float = na.ipop[best]
	var oneParty: bool = na.ideo == "fascism" or na.ideo == "communism"
	var coup: bool = p >= 50 and na.stab < (25 if oneParty else 40)
	var peaceful: bool = p >= 65 and na.ideo != "fascism" and na.ideo != "communism"
	if not coup and not peaceful: return
	# 安定度がとても低い時の政変は内戦になる
	if coup and na.stab < 20 and not na.has("civil") and ownCount(na.id) >= 6:
		startCivilWar(na, best)
		return
	if na.has("civil"): return
	setGov(na, best, "政変" if coup else "選挙")
## 政権を別の思想に変える（ふるまいも変わる）
func setGov(na: Dictionary, k: String, why: String) -> void:
	if na.ideo == k: return
	var old: String = na.ideo
	na.ideo = k
	na.persona = k
	na.ipop[k] = max(na.ipop.get(k, 0.0), 55.0)
	_normPop(na)
	hoiRecalc(na)
	na.stab = clamp_f(na.stab - (15 if why == "政変" else 5), 0, 100)
	newLeader(na)
	hoiRecalc(na)
	var msg = "%s で%s — %s から %s の政権へ" % [na.name, why, IDEO[old].n, IDEO[k].n]
	if newsworthy([na.id]): headline("%s で%s" % [natLabel(na.id), why], "%s から %s の政権へ" % [IDEO[old].n, IDEO[k].n])
	logMsg(msg, "war" if k == "fascism" or why == "政変" else "")
	chron(msg, na.id, "gov")
	# 盟主と思想が違う陣営からは抜ける
	var F = facOf(na.id)
	if F != null and F.leader != na.id and NAT(F.leader).get("ideo") != k: leaveFaction(na.id, "政権交代")
	refreshRole(na)
## 1ターン＝1か月（1936年1月から）
func dateStr(turn: int) -> String:
	return "%d年%d月" % [1936 + (turn - 1) / 12, (turn - 1) % 12 + 1]
func natByName(nm: String) -> int:
	for o in G.nations:
		if o.alive and o.name == nm: return o.id
	return -1
func roleOf(nid: int) -> String: return NAT(nid).get("role", "")

# ---------- 国家方針 ----------
var _treeCache = {}
## その国の方針ツリー（共通の枝＋固有の枝。大国は産業・軍事の枝と大きな固有ツリー）
func focusTree(na: Dictionary) -> Array:
	if _treeCache.has(na.name): return _treeCache[na.name]
	var cd = COUNTRY.get(na.name) if G.get("size") == "japan" else null
	var major: bool = cd != null and cd.has("tree")
	var out = []
	for f in FOCUS_COMMON:
		if not major or f.br == "ind" or f.br == "mil": out.append(f.duplicate(true))
	if major:
		for f in cd.tree:
			var g: Dictionary = f.duplicate(true)
			g.x = 6.0 + f.x
			g.br = "uniq"
			out.append(g)
	elif cd != null:
		var chain: Array = cd.chain
		var fin: Array = cd.fin
		var prev = ""
		for i in chain.size():
			var id = "u%d" % i
			out.append({"id": id, "n": chain[i][0], "x": FOCUS_UNIQUE_X + 0.5, "y": i, "t": 6 + i, "req": [prev] if prev != "" else [], "br": "uniq", "e": chain[i][1]})
			prev = id
		for j in fin.size():
			var id2 = "u3%s" % ["a", "b"][j]
			out.append({"id": id2, "n": fin[j][0], "x": FOCUS_UNIQUE_X + j, "y": chain.size(), "t": 8, "req": [prev], "ex": ["u3%s" % ["b", "a"][j]], "br": "uniq", "e": fin[j][1]})
	_treeCache[na.name] = out
	return out
func isMajor(na: Dictionary) -> bool:
	return G.get("size") == "japan" and COUNTRY.get(na.name, {}).has("tree")
func focusById(na: Dictionary, id: String):
	for f in focusTree(na):
		if f.id == id: return f
	return null
func focusAvailable(na: Dictionary, f: Dictionary) -> bool:
	var done: Array = na.focus.done
	if done.has(f.id) or na.focus.cur == f.id: return false
	if f.req.size():
		var ok = false
		for r in f.req:
			if done.has(r): ok = true
		if not ok: return false
	for x in f.get("ex", []):
		if done.has(x) or na.focus.cur == x: return false
	return true
func _focusTurn(na: Dictionary) -> void:
	var fc: Dictionary = na.focus
	if fc.cur != null:
		fc.prog += 1
		var f = focusById(na, fc.cur)
		if f == null:
			fc.cur = null
		elif fc.prog >= f.t:
			fc.done.append(f.id)
			fc.cur = null
			fc.prog = 0
			var msg = "%s（%s）が国家方針「%s」を達成" % [na.name, na.get("role", ""), f.n] if na.get("role", "") != "" else "%s が国家方針「%s」を達成" % [na.name, f.n]
			if concerns([na.id]) or (f.br == "uniq" and isMajor(na)): logMsg(msg, "good")
			chron(msg, na.id, "gov")
			_applyFocus(na, f)
	if fc.cur == null: _pickFocus(na)
const WAR_FX := ["warOn", "claimOn", "demand", "claim"]
func _pickFocus(na: Dictionary) -> void:
	var cands = []
	var war = inWar(na.id)
	var id: String = na.ideo
	for f in focusTree(na):
		if not focusAvailable(na, f): continue
		var w: float = 10.0 * f.get("w", 1.0)
		match f.br:
			"uniq": w *= 7.0 if isMajor(na) else 3.0
			"ind": w *= 1.6 if id == "neutral" or id == "democracy" else 1.0
			"mil": w *= (1.8 if id == "fascism" or id == "communism" else 1.0) * (2.0 if war else 1.0)
			"pol": w *= 2.0 if na.stab < 45 else 1.0
			"dip": w *= 1.3 if id == "democracy" or id == "neutral" else 0.8
		var e: Dictionary = f.e
		if e.has("ideo"):
			var k: String = e.ideo[0]
			w *= 2.0 if k == id else (0.6 + na.ipop.get(k, 0.0) / 40.0)
		if e.has("gov"): w *= 1.0 + na.ipop.get(e.gov, 0.0) / 15.0
		for x in WAR_FX:
			if e.has(x):
				w *= 2.0 if id == "fascism" else (0.3 if id == "democracy" else 1.0)
				break
		if e.has("joinFac"):
			var F = _facNamed(e.joinFac)
			if F != null and NAT(F.leader).get("ideo") != id: w *= 0.3
		cands.append([f, w])
	if cands.is_empty(): return
	var sum = 0.0
	for c in cands: sum += c[1]
	var r = randf() * sum
	for c in cands:
		r -= c[1]
		if r <= 0:
			na.focus.cur = c[0].id
			na.focus.prog = 0
			return
func _applyFocus(na: Dictionary, f: Dictionary) -> void:
	var e: Dictionary = f.e
	var nid: int = na.id
	if e.has("rm"): _rmSpirit(na, e.rm)
	# 方針で内戦が決着した（スペイン内戦など）
	if e.get("rm", "") == "内戦" and na.has("civil"): endCivilWarBy(na, f.n)
	if e.has("sp"): _addSpirit(na, e.sp[0], e.sp[1], e.sp[2], "方針")
	if e.has("stab"): na.stab = clamp_f(na.stab + e.stab, 0, 100)
	if e.has("ws"): na.ws = clamp_f(na.ws + e.ws, 0, 100)
	if e.has("pp"): na.pp = min(300.0, na.pp + e.pp)
	if e.has("gold"): na.gold += e.gold
	if e.has("eq"): na.eq += e.eq
	if e.has("mf"): _buildFactories(nid, "mf", e.mf)
	if e.has("cf"): _buildFactories(nid, "cf", e.cf)
	if e.has("gov"): setGov(na, e.gov, "方針「%s」" % f.n)
	if e.has("ideo"):
		na.ipop[e.ideo[0]] = na.ipop.get(e.ideo[0], 0.0) + e.ideo[1]
		_normPop(na)
		_ideoShift(na)
	if e.has("dev"):
		var c = []
		for t in G.terrs:
			if t.owner == nid and t.type == "city" and t.dev < 5: c.append(t)
		c.shuffle()
		for i in min(e.dev, c.size()):
			c[i].dev += 1
			invalidateTerr(c[i].id)
	if e.has("infra"):
		var c2 = []
		for t in G.terrs:
			if t.owner == nid and t.get("infra", 1) < 3: c2.append(t)
		c2.sort_custom(func(a, b): return a.pop > b.pop)
		for i in min(e.infra, c2.size()):
			c2[i].infra = c2[i].get("infra", 1) + 1
			infraChanged(c2[i])
	if e.has("claim"):
		var best = null
		for o in G.nations:
			if not o.alive or o.id == nid or not nationsAdjacent(nid, o.id) or isAlly(nid, o.id) or lordOf(o.id) == nid: continue
			if best == null or nationPower(o.id) < nationPower(best): best = o.id
		if best != null: grantCB(nid, best, "%s の方針" % f.n, 25)
	if e.has("favor"):
		for o in G.nations:
			if o.alive and o.id != nid and nationsAdjacent(nid, o.id): addFavor(o.id, nid, e.favor)
	if e.has("pact"):
		var o = natByName(e.pact)
		if o >= 0 and o != nid and relState(nid, o) == "peace":
			makePact(nid, o)
			chron("%s と %s が不可侵条約を結ぶ（%s）" % [na.name, NAT(o).name, f.n], nid, "dip")
	if e.has("claimOn"):
		for nm in e.claimOn:
			var o = natByName(nm)
			if o >= 0 and o != nid and not sameFaction(nid, o) and lordOf(o) != nid:
				if na.ideo == "fascism" or na.ideo == "communism": _turnOn(nid, o)
				grantCB(nid, o, "「%s」" % f.n, 40)
				chron("%s が %s への領有権を主張（%s）" % [na.name, NAT(o).name, f.n], nid, "dip")
	if e.has("fac"): _facCreate(nid, e.fac)
	if e.has("joinFac"): _facJoin(nid, e.joinFac)
	if e.has("invite"):
		var F = facOf(nid)
		if F != null and F.leader == nid:
			for nm in e.invite:
				var o = natByName(nm)
				if o >= 0 and o != nid and facOf(o) == null and lordOf(o) == null and not atWar(nid, o) and NAT(o).get("ideo") == na.ideo:
					joinFaction(F, o)
	if e.has("guar"):
		for nm in e.guar:
			var o = natByName(nm)
			if o >= 0 and o != nid and not na.guar.has(o):
				na.guar.append(o)
				var msg = "%s が %s の独立を保証する" % [na.name, NAT(o).name]
				if concerns([nid, o]): logMsg(msg, "good")
				chron(msg, nid, "dip")
	if e.has("demand"):
		for nm in e.demand:
			var o = natByName(nm)
			if o >= 0: _demand(na, o, f.n)
	if e.has("warOn"):
		var o = natByName(e.warOn)
		if o >= 0 and o != nid and not sameFaction(nid, o) and lordOf(o) != nid:
			_turnOn(nid, o)
			grantCB(nid, o, "「%s」" % f.n, 40)
			na.ws = clamp_f(na.ws + 10, 0, 100)
			if not inWar(nid) and nationsAdjacent(nid, o) and canPrepare(nid, o) and hoiWarOK(nid, o):
				startWarPrep(nid, o)
				na.forceWar = o
			elif inWar(nid): na.pendingWar = o   # 戦争中なら、終わってから
	nations_changed.emit()
## 併合・従属の要求（アンシュルス・ズデーテンなど）。断られたら大義を得る
func _demand(na: Dictionary, o: int, why: String) -> void:
	var nid: int = na.id
	var B = NAT(o)
	if not B.alive or o == nid or lordOf(o) == nid or sameFaction(nid, o) or atWar(nid, o): return
	var theirs = nationPower(o)
	var F = facOf(o)
	if F != null:
		for m in F.members:
			if m != o and NAT(m).alive: theirs += nationPower(m) * 0.5
	for g in G.nations:
		if g.alive and g.id != nid and g.get("guar", []).has(o): theirs += nationPower(g.id) * 0.5
	var ratio = nationPower(nid) / max(1.0, theirs)
	var same: bool = B.get("ideo") == na.ideo
	var sympathy: float = B.get("ipop", {}).get(na.ideo, 0.0)
	# 宥和（HOI4 のミュンヘン会談のように）：要求された国は自国だけの国力で比べる。陣営に入っておらず、要求した国より強い保証国もいなければ受け入れやすい
	var alone = nationPower(nid) / max(1.0, nationPower(o))
	var strongGuard = false
	for g in G.nations:
		if g.alive and g.id != nid and g.get("guar", []).has(o) and nationPower(g.id) > nationPower(nid): strongGuard = true
	var appease: bool = F == null and not strongGuard
	var annexOK: bool = not inWar(o) and (ratio >= 2.2 or (appease and alone >= 1.4) or (same and alone >= 1.1) or (sympathy >= 35 and alone >= 1.0))
	# 歴史イベント：ミュンヘン会談（ドイツがチェコスロバキアに要求した時）
	if na.name == "群馬県" and B.name == "栃木県" and G.get("size") == "japan" and not G.get("munichDone", false):
		G.munichDone = true
		var mr = munichEvent(nid, o)
		if mr == "appease": annexOK = not inWar(o) and alone >= 1.0
		elif mr == "stand": annexOK = false
	var msg = ""
	if annexOK and nationsAdjacent(nid, o):
		msg = "%s が %s の要求を受け入れ、併合される（%s）" % [B.name, na.name, why]
		logMsg(msg, "war")
		chron(msg, nid, "dip")
		annex(nid, o, why)
		addTension(6)
		headline("%s、%s を併合" % [natLabel(nid), natLabel(o)], why)
	elif not inWar(o) and ratio >= 1.6 and lordOf(o) == null and vassalsOf(o).is_empty():
		msg = "%s が %s の要求を受け入れ、従属する（%s）" % [B.name, na.name, why]
		logMsg(msg, "war")
		chron(msg, nid, "dip")
		makeVassal(nid, o, why)
		addTension(4)
	else:
		grantCB(nid, o, "「%s」の要求を拒否された" % why, 40)
		_turnOn(nid, o)
		na.ws = clamp_f(na.ws + 10, 0, 100)
		msg = "%s が %s の要求（%s）を拒否する" % [B.name, na.name, why]
		logMsg(msg, "war")
		chron(msg, nid, "dip")
		if na.ideo == "fascism" and not inWar(nid) and nationsAdjacent(nid, o) and canPrepare(nid, o) and hoiWarOK(nid, o):
			startWarPrep(nid, o)
			na.forceWar = o
func _facNamed(name: String):
	for F in G.get("factions", {}).values():
		if F.name == name: return F
	return null
const FAC_IDEO := {"枢軸": "fascism", "連合国": "democracy", "コミンテルン": "communism"}
## 盟主と敵対する思想でなければ陣営に入れる
func facFit(a: int, b: int) -> bool:
	var x: String = NAT(a).get("ideo", "")
	var y: String = NAT(b).get("ideo", "")
	if x == y or x == "neutral" or y == "neutral": return true
	return false
func _facCreate(nid: int, name: String) -> void:
	var F = facOf(nid)
	if F != null:
		if F.leader == nid and _facNamed(name) == null: F.name = name
		return
	if _facNamed(name) != null:
		_facJoin(nid, name)
		return
	makeFaction(nid, name)
func _facJoin(nid: int, name: String) -> void:
	var F = _facNamed(name)
	var cur = facOf(nid)
	if F == null:
		if cur == null and isMajor(NAT(nid)) and FAC_IDEO.get(name, NAT(nid).ideo) == NAT(nid).ideo: makeFaction(nid, name)
		return
	if cur == F: return
	if not facFit(nid, F.leader): return
	for m in F.members:
		if atWar(nid, m): return
	if cur != null: leaveFaction(nid, "quiet")
	joinFaction(F, nid)
## 宣戦された国に保証を与えている国は参戦する
func hoiGuarantee(a: int, b: int) -> void:
	var wid = warOf(a, b)
	for g in G.nations:
		if not g.alive or g.id == a or g.id == b: continue
		if not g.get("guar", []).has(b): continue
		if atWar(g.id, a) or sameFaction(g.id, a) or isAlly(g.id, a) or lordOf(g.id) != null: continue
		enterWar(g.id, a, "%s の独立の保証により参戦" % NAT(b).name, wid)
## 方針の効果を文で
func focusDesc(f: Dictionary) -> String:
	var e: Dictionary = f.e
	var s = []
	if e.has("gov"): s.append("%s の政権になる" % IDEO[e.gov].n)
	if e.has("rm"): s.append("「%s」を外す" % e.rm)
	if e.has("sp"): s.append("国民精神「%s」（%s）" % [e.sp[0], e.sp[1]])
	if e.has("stab"): s.append("安定度 %+d" % e.stab)
	if e.has("ws"): s.append("戦争支持 %+d" % e.ws)
	if e.has("pp"): s.append("政治力 +%d" % e.pp)
	if e.has("gold"): s.append("ゴールド +%s" % fmt(e.gold))
	if e.has("eq"): s.append("軍需品 +%s" % fmt(e.eq))
	if e.has("mf"): s.append("軍需工場 +%d" % e.mf)
	if e.has("cf"): s.append("民需工場 +%d" % e.cf)
	if e.has("ideo"): s.append("%s の支持 +%d" % [IDEO[e.ideo[0]].n, e.ideo[1]])
	if e.has("dev"): s.append("町%dか所の開発度 +1" % e.dev)
	if e.has("infra"): s.append("%dか所のインフラ +1" % e.infra)
	if e.has("claim"): s.append("弱い隣国への大義（25ターン）")
	if e.has("favor"): s.append("隣国の好感度 +%d" % e.favor)
	if e.has("pact"): s.append("%s と不可侵条約" % _roleName(e.pact))
	if e.has("claimOn"): s.append("%s への大義" % "・".join(e.claimOn.map(_roleName)))
	if e.has("warOn"): s.append("%s への大義と開戦準備" % _roleName(e.warOn))
	if e.has("demand"): s.append("%s に併合・従属を要求（断られたら大義）" % "・".join(e.demand.map(_roleName)))
	if e.has("guar"): s.append("%s の独立を保証（攻められたら参戦）" % "・".join(e.guar.map(_roleName)))
	if e.has("fac"): s.append("陣営「%s」を結成" % e.fac)
	if e.has("joinFac"): s.append("陣営「%s」に加わる" % e.joinFac)
	if e.has("invite"): s.append("%s を陣営に招く" % "・".join(e.invite.map(_roleName)))
	return "・".join(s)
func _roleName(nm: String) -> String:
	var cd = COUNTRY.get(nm)
	return ("%s（%s）" % [cd.r, nm.trim_suffix("県").trim_suffix("都").trim_suffix("府")]) if cd != null else nm
## 戦を始められるだけの戦争支持があるか（民主主義は大義も要る）
var HOI_GATE = true
func hoiWarOK(nid: int, target := -1) -> bool:
	if not HOI_GATE: return true
	var na = NAT(nid)
	if not na.has("ideo"): return true
	if na.ws < wsNeedOf(na): return false
	if na.ideo == "democracy" and target >= 0 and not hasCB(nid, target): return false
	return true
## 思想の相性：ファシズム・共産主義は同じ思想としか同盟しない
func ideoCompat(a: int, b: int) -> bool:
	var x: String = NAT(a).get("ideo", "")
	var y: String = NAT(b).get("ideo", "")
	if x == "" or y == "" or x == y: return true
	return not (x == "fascism" or x == "communism" or y == "fascism" or y == "communism")
## 不可侵条約を更新してよいか（ファシズムは大義を持つ相手とは更新しない）
func pactOK(a: int, b: int) -> bool:
	if NAT(a).get("ideo") == "fascism" and hasCB(a, b): return false
	if NAT(b).get("ideo") == "fascism" and hasCB(b, a): return false
	return true
## ファシズムの国が方針で狙った相手か（その相手とは不可侵条約を結ばない）
func wantsLand(a: int, b: int) -> bool:
	return NAT(a).get("ideo") == "fascism" and NAT(a).get("claimT", []).has(b)
## 方針で狙う相手とは同盟・条約を解く
func _turnOn(nid: int, o: int) -> void:
	var ct: Array = NAT(nid).get("claimT", [])
	if not ct.has(o):
		ct.append(o)
		NAT(nid).claimT = ct
	if isAlly(nid, o) and not isVassal(o, nid) and not isVassal(nid, o): breakAlly(nid, o)
	if pactLeft(nid, o) > 0:
		G.dip.pact[nid][o] = 0; G.dip.pact[o][nid] = 0
		chron("%s が %s との不可侵条約を破棄する" % [NAT(nid).name, NAT(o).name], nid, "dip")

# ---------- 世界の緊張（HOI4 の World Tension） ----------
## 時代が進むほど、また宣戦・併合が起きるほど高まる（0〜100）。高いほど戦争支持が上がり、宣戦に必要な戦争支持が下がり、開戦しやすい
func tension() -> float: return G.get("wt", 0.0) if G != null else 0.0
func tensionTurn() -> void:
	var d: int = G.get("declN", 0) - G.get("wtDecl", 0)
	G.wtDecl = G.get("declN", 0)
	var w = tension() + 0.18 + d * 2.0
	# 戦争が長く途絶えると、少しずつ早く高まる（膠着を防ぐ）
	if G.wars.is_empty(): w += 0.12
	G.wt = clamp_f(w, 0, 100)
func addTension(v: float) -> void: G.wt = clamp_f(tension() + v, 0, 100)
## 宣戦に必要な戦争支持（世界の緊張で下がる）
func wsNeedOf(na: Dictionary) -> float: return max(20.0, IDEO[na.ideo].wsNeed - tension() * 0.3)
func tensionLabel(w: float) -> String: return "平穏" if w < 20 else ("きな臭い" if w < 45 else ("一触即発" if w < 70 else "世界大戦前夜"))

## 政体に合わせた国名（見立ての国名）を付け直す
func refreshRole(na: Dictionary) -> void:
	var cd = COUNTRY.get(na.name) if G != null and G.get("size") == "japan" else null
	if cd == null: return
	var nm: String = cd.r
	var rn = ROLE_NAMES.get(na.name)
	if rn != null: nm = rn.get(na.ideo, nm)
	elif na.ideo == "communism" and nm.find("共和") < 0 and nm.find("人民") < 0 and nm.find("共産") < 0 and nm != "モンゴル": nm += "人民共和国"
	if na.get("role", "") != nm:
		var old: String = na.get("role", "")
		na.role = nm
		if old != "" and G.turn > 1: chron("%s の国名が %s から %s に変わる" % [na.name, old, nm], na.id, "gov")
## 陣営ごとの色（地図の表示用）
func facColor(F) -> Color:
	if F == null: return Color(0.55, 0.53, 0.5)
	match F.name:
		"枢軸": return Color("#8a6d3b")
		"連合国": return Color("#4f8fd6")
		"コミンテルン": return Color("#c0392b")
	var h = float(abs(hash(F.name)) % 360) / 360.0
	return Color.from_hsv(h, 0.45, 0.8)

# ==================== k8b_politics.gd ====================
# HOI4 を参考にした政治：指導者・国家法（徴兵・経済・貿易）・顧問・決定（政治力の使い道）

# ---------- 国家法 ----------
## 段階の順に並べる。need=必要な戦争支持（war=戦争中でないと選べない）
const LAWS := {
	"conscr": {"n": "徴兵法", "list": [
		{"id": "vol", "n": "志願兵制", "d": "兵の上限 -30%・人口の伸び +5%", "m": {"cap": -0.30, "grow": 0.05}, "need": 0},
		{"id": "lim", "n": "限定徴兵", "d": "標準", "m": {}, "need": 0},
		{"id": "ext", "n": "拡大徴兵", "d": "兵の上限 +30%・人口の伸び -5%・ゴールド -5%", "m": {"cap": 0.30, "grow": -0.05, "gold": -0.05}, "need": 40},
		{"id": "svc", "n": "兵役義務", "d": "兵の上限 +60%・人口の伸び -10%・ゴールド -10%", "m": {"cap": 0.60, "grow": -0.10, "gold": -0.10}, "need": 60, "war": true},
		{"id": "all", "n": "国民総動員", "d": "兵の上限 +100%・人口の伸び -20%・ゴールド -20%・食料 -10%", "m": {"cap": 1.0, "grow": -0.20, "gold": -0.20, "food": -0.10}, "need": 80, "war": true},
	]},
	"econ": {"n": "経済法", "list": [
		{"id": "civ", "n": "民間経済", "d": "消費財 35%・民需工場の出力 +15%・軍需工場の出力 -10%・安定度 +5", "m": {"cf": 0.15, "mf": -0.10, "stab": 5.0}, "need": 0, "cg": 0.35},
		{"id": "early", "n": "初期動員", "d": "消費財 30%・標準", "m": {}, "need": 0, "cg": 0.30},
		{"id": "part", "n": "部分動員", "d": "消費財 25%・軍需工場の出力 +10%・民需工場の出力 -5%", "m": {"mf": 0.10, "cf": -0.05}, "need": 30, "cg": 0.25},
		{"id": "war", "n": "戦時経済", "d": "消費財 20%・軍需工場の出力 +20%・民需工場の出力 -10%・安定度 -5", "m": {"mf": 0.20, "cf": -0.10, "stab": -5.0}, "need": 60, "cg": 0.20},
		{"id": "total", "n": "総力戦", "d": "消費財 10%・軍需工場の出力 +30%・民需工場の出力 -20%・安定度 -10", "m": {"mf": 0.30, "cf": -0.20, "stab": -10.0}, "need": 0, "war": true, "cg": 0.10},
	]},
	"trade": {"n": "貿易法", "list": [
		{"id": "free", "n": "自由貿易", "d": "ゴールド +10%・資源の輸出が多い（国内の資源 -20%）", "m": {"gold": 0.10, "res": -0.20}, "need": 0},
		{"id": "exp", "n": "輸出重視", "d": "ゴールド +5%・資源の輸出（国内の資源 -10%）", "m": {"gold": 0.05, "res": -0.10}, "need": 0},
		{"id": "lim", "n": "輸出制限", "d": "標準", "m": {}, "need": 0},
		{"id": "closed", "n": "閉鎖経済", "d": "ゴールド -10%・国内の資源 +10%・軍需工場の出力 +5%", "m": {"gold": -0.10, "res": 0.10, "mf": 0.05}, "need": 0},
	]},
}
const LAW_KEYS := ["conscr", "econ", "trade"]
const LAW_COST := 100.0

# ---------- 顧問 ----------
## slot：pol（政治顧問・2人）／staff（参謀・1人）／design（設計会社・1つ）
const ADVISORS := [
	{"id": "ind", "slot": "pol", "n": "産業の大家", "d": "民需工場の出力 +10%・建設費 -10%", "m": {"cf": 0.10, "build": -0.10}},
	{"id": "prop", "slot": "pol", "n": "宣伝相", "d": "戦争支持 +10", "m": {"ws": 10.0}},
	{"id": "mod", "slot": "pol", "n": "穏健な調停者", "d": "安定度 +10", "m": {"stab": 10.0}},
	{"id": "dipl", "slot": "pol", "n": "外交の達人", "d": "政治力 +0.5／ターン・安定度 +3", "m": {"pp": 0.5, "stab": 3.0}},
	{"id": "iron", "slot": "pol", "n": "鉄の宰相", "d": "兵の生産 +10%", "m": {"troop": 0.10}, "ideo": ["fascism", "neutral"]},
	{"id": "plan", "slot": "pol", "n": "計画経済の旗手", "d": "軍需工場の出力 +15%", "m": {"mf": 0.15}, "ideo": ["communism"]},
	{"id": "atk", "slot": "staff", "n": "攻勢の参謀", "d": "攻撃 +8%", "m": {"atk": 0.08}},
	{"id": "def", "slot": "staff", "n": "守勢の参謀", "d": "防御 +8%", "m": {"def": 0.08}},
	{"id": "log", "slot": "staff", "n": "兵站の参謀", "d": "兵の上限 +15%・消耗 -30%", "m": {"cap": 0.15, "attr": -0.30}},
	{"id": "fort", "slot": "staff", "n": "築城の参謀", "d": "砦の防御 +20%", "m": {"fort": 0.20}},
	{"id": "arms", "slot": "design", "n": "小火器工廠", "d": "攻撃 +4%・軍需工場の出力 +5%", "m": {"atk": 0.04, "mf": 0.05}},
	{"id": "art", "slot": "design", "n": "重砲工廠", "d": "攻撃 +6%", "m": {"atk": 0.06}},
	{"id": "tank", "slot": "design", "n": "装甲工廠", "d": "攻撃 +5%・防御 +3%", "m": {"atk": 0.05, "def": 0.03}},
	{"id": "aero", "slot": "design", "n": "航空機製作所", "d": "空軍力 +25%", "m": {"air": 0.25}},
]
const ADV_SLOTS := {"pol": 2, "staff": 1, "design": 1}
const ADV_COST := 150.0

# ---------- 決定 ----------
const DECISIONS := [
	{"id": "border", "n": "国境紛争をしかける", "d": "弱い隣国への大義（20ターン）・世界の緊張 +2", "pp": 60},
	{"id": "bonds", "n": "戦時公債", "d": "ゴールドを得る・安定度 -5", "pp": 40},
	{"id": "order", "n": "治安強化", "d": "全領地の治安 +15・安定度 +5", "pp": 50},
	{"id": "diplo", "n": "外交攻勢", "d": "隣国の好感度 +10・世界の緊張 -2", "pp": 50},
	{"id": "mobil", "n": "総動員令", "d": "兵の蓄え +20%・安定度 -5", "pp": 70},
]

# ---------- 指導者 ----------
const LEADER_TITLE := {"democracy": "首相", "communism": "書記長", "fascism": "総統", "neutral": "国家元首"}
const LEADER_TRAITS := [
	{"n": "カリスマ", "d": "安定度 +5・戦争支持 +5", "m": {"stab": 5.0, "ws": 5.0}},
	{"n": "能吏", "d": "政治力 +0.5／ターン", "m": {"pp": 0.5}},
	{"n": "軍人上がり", "d": "攻撃 +3%・兵の生産 +5%", "m": {"atk": 0.03, "troop": 0.05}},
	{"n": "倹約家", "d": "ゴールド +5%", "m": {"gold": 0.05}},
	{"n": "人気者", "d": "安定度 +10", "m": {"stab": 10.0}},
	{"n": "工業通", "d": "軍需・民需工場の出力 +5%", "m": {"mf": 0.05, "cf": 0.05}},
	{"n": "慎重", "d": "防御 +5%・戦争支持 -5", "m": {"def": 0.05, "ws": -5.0}},
	{"n": "野心家", "d": "戦争支持 +10・安定度 -5", "m": {"ws": 10.0, "stab": -5.0}},
]
const NAME_A := ["ハンス", "カール", "フランツ", "アントン", "ミハイル", "ニコライ", "ジョン", "エドワード", "ピエール", "ルイ", "ジュゼッペ", "マリオ", "ヨゼフ", "アレクサンデル", "ウラジミル", "トマス", "ヘンリク", "ステファン", "イシュトヴァン", "コンスタンティン", "ペドロ", "ミゲル", "グスタフ", "オスカー", "ヴィクトル", "エミール"]
const NAME_B := ["ヴェーバー", "シュミット", "ベッカー", "イワノフ", "ペトロフ", "スミス", "ウィルソン", "デュボア", "マルタン", "ロッシ", "コンティ", "ノヴァク", "コヴァルスキ", "ホルヴァート", "ポペスク", "ガルシア", "ロペス", "リンドベリ", "ハンセン", "コーホネン", "ヤンセン", "ペテルセン", "ディミトロフ", "パパドプロス", "ユルドゥズ", "モレノ"]
func newLeader(na: Dictionary) -> void:
	var tr: Dictionary = LEADER_TRAITS[randi() % LEADER_TRAITS.size()]
	na.leader = {"n": "%s・%s" % [NAME_A[randi() % NAME_A.size()], NAME_B[randi() % NAME_B.size()]], "t": tr.n, "since": G.turn if G != null else 1}
func leaderTrait(na: Dictionary):
	var l = na.get("leader")
	if l == null: return null
	for tr in LEADER_TRAITS:
		if tr.n == l.t: return tr
	return null
func leaderTitle(na: Dictionary) -> String: return LEADER_TITLE.get(na.get("ideo", "neutral"), "国家元首")

# ---------- 初期化（hoiInit から） ----------
func politicsInit(na: Dictionary) -> void:
	if not na.has("laws"):
		var lw = {"conscr": "lim", "econ": "early", "trade": "lim"}
		match na.get("ideo", "neutral"):
			"fascism": lw = {"conscr": "ext", "econ": "part", "trade": "closed"}
			"communism": lw = {"conscr": "ext", "econ": "part", "trade": "lim"}
			"democracy": lw = {"conscr": "vol", "econ": "civ", "trade": "free"}
		na.laws = lw
	if not na.has("advisors"): na.advisors = []
	if not na.has("leader"): newLeader(na)
	if not na.has("decCool"): na.decCool = {}
func lawOf(na: Dictionary, k: String) -> Dictionary:
	var id: String = na.get("laws", {}).get(k, "")
	for l in LAWS[k].list:
		if l.id == id: return l
	return LAWS[k].list[1]
func consumerShare(na: Dictionary) -> float: return lawOf(na, "econ").get("cg", 0.3)
## 国民精神・政体のほかに足す修正（hoiRecalc から）
func politicsMods(na: Dictionary, m: Dictionary) -> void:
	for k in LAW_KEYS:
		var l = lawOf(na, k)
		for x in l.m: m[x] = m.get(x, 0.0) + l.m[x]
	for aid in na.get("advisors", []):
		for a in ADVISORS:
			if a.id == aid:
				for x in a.m: m[x] = m.get(x, 0.0) + a.m[x]
	var tr = leaderTrait(na)
	if tr != null:
		for x in tr.m: m[x] = m.get(x, 0.0) + tr.m[x]

# ---------- 毎ターン：CPU が政治力を使う ----------
func politicsTurn(na: Dictionary) -> void:
	var nid: int = na.id
	var war = inWar(nid)
	var hot: bool = war or tension() >= 50
	# 1) 国家法：戦争中・緊張が高ければ段階を上げる。長い平和で疲れていれば下げる
	if na.pp >= LAW_COST + 20:
		for k in ["conscr", "econ"]:
			var lst: Array = LAWS[k].list
			var cur = 0
			for i in lst.size():
				if lst[i].id == na.laws[k]: cur = i
			var want = cur
			var arm: bool = hot or na.ideo == "fascism" or (na.ideo == "communism" and tension() >= 30)
			if arm and cur + 1 < lst.size():
				var nx: Dictionary = lst[cur + 1]
				if na.ws >= nx.need and (not nx.get("war", false) or war): want = cur + 1
			elif not war and tension() < 30 and cur > 1 and na.get("fatigue", 0) > 20: want = cur - 1
			if want != cur:
				na.laws[k] = lst[want].id
				na.pp -= LAW_COST
				hoiRecalc(na)
				var msg = "%s が%sを「%s」に改める" % [na.name, LAWS[k].n, lst[want].n]
				if concerns([nid]): logMsg(msg)
				chron(msg, nid, "gov")
				break
	# 戦争が終わったら、戦時にしか選べない段階からは戻す
	if not war:
		for k in ["conscr", "econ"]:
			var l = lawOf(na, k)
			if l.get("war", false):
				var lst: Array = LAWS[k].list
				for i in lst.size():
					if lst[i].id == l.id:
						na.laws[k] = lst[i - 1].id
						hoiRecalc(na)
	# 2) 顧問：空いた枠に雇う
	if na.pp >= ADV_COST + 30:
		var used = {"pol": 0, "staff": 0, "design": 0}
		for aid in na.advisors:
			for a in ADVISORS:
				if a.id == aid: used[a.slot] += 1
		var best = null
		var bw = 0.0
		for a in ADVISORS:
			if na.advisors.has(a.id) or used[a.slot] >= ADV_SLOTS[a.slot]: continue
			if a.has("ideo") and not a.ideo.has(na.ideo): continue
			var w = 1.0 + randf()
			if a.slot == "staff" or a.slot == "design": w += 1.5 if hot else 0.3
			if a.m.has("stab") and na.stab < 45: w += 2.0
			if a.m.has("ws") and na.ws < wsNeedOf(na) and na.ideo != "democracy": w += 1.5
			if a.m.has("cf") or a.m.has("mf"): w += 0.8
			if w > bw:
				bw = w
				best = a
		if best != null:
			na.advisors.append(best.id)
			na.pp -= ADV_COST
			hoiRecalc(na)
			var msg2 = "%s が%s「%s」を迎える" % [na.name, {"pol": "政治顧問", "staff": "参謀", "design": "設計会社"}[best.slot], best.n]
			if concerns([nid]): logMsg(msg2)
			chron(msg2, nid, "gov")
	# 3) 決定
	for dc in DECISIONS:
		# 急ぎでない決定は、法律や顧問の分を残せる時だけ
		var urgent: bool = dc.id == "bonds" or dc.id == "mobil"
		if na.pp < dc.pp + (30 if urgent else 170): continue
		if na.decCool.get(dc.id, -99) > G.turn: continue
		if not _decisionWanted(na, dc.id, war): continue
		na.pp -= dc.pp
		na.decCool[dc.id] = G.turn + 15
		_decide(na, dc)
		break
func _decisionWanted(na: Dictionary, id: String, war: bool) -> bool:
	match id:
		"border": return not war and (na.ideo == "fascism" or na.ideo == "communism") and na.ws >= wsNeedOf(na) - 10 and randf() < 0.3
		"bonds": return war and na.gold < 4000
		"order":
			var low = 0
			var own = ownList(na.id)
			for t in own:
				if t.sec < 45: low += 1
			return low > own.size() * 0.2
		"diplo": return not war and na.ideo == "democracy" and tension() > 40 and randf() < 0.2
		"mobil": return war and cpuDanger(na.id) >= 0.8
	return false
func _decide(na: Dictionary, dc: Dictionary) -> void:
	var nid: int = na.id
	match dc.id:
		"border":
			var best = null
			for o in G.nations:
				if not o.alive or o.id == nid or not nationsAdjacent(nid, o.id) or sameFaction(nid, o.id) or lordOf(o.id) == nid: continue
				if best == null or nationPower(o.id) < nationPower(best): best = o.id
			if best == null: return
			grantCB(nid, best, "国境紛争", 20)
			addTension(2)
		"bonds":
			na.gold += 3000 + ownCount(nid) * 150
			na.stab = clamp_f(na.stab - 5, 0, 100)
		"order":
			for t in ownList(nid): t.sec = clamp_f(t.sec + 15, 0, 100)
			na.stab = clamp_f(na.stab + 5, 0, 100)
		"diplo":
			for o in G.nations:
				if o.alive and o.id != nid and nationsAdjacent(nid, o.id): addFavor(o.id, nid, 10)
			addTension(-2)
		"mobil":
			for k in na.stock: na.stock[k] = int(na.stock[k] * 1.2)
			na.stab = clamp_f(na.stab - 5, 0, 100)
	var msg = "%s が決定「%s」を行う" % [na.name, dc.n]
	if concerns([nid]): logMsg(msg)
	chron(msg, nid, "gov")

# ==================== k8c_economy.gd ====================
# HOI4 を参考にした経済：研究（技術）・装備の世代・資源（鉄・石油）と貿易・消費財

# ---------- 研究 ----------
## 1段階ごとの効果（5段階まで）。y=その分野の1段階目が出る年（以後1.5年ごと）
const TECHS := {
	"inf": {"n": "歩兵装備", "d": "攻撃 +3%・防御 +3%", "m": {"atk": 0.03, "def": 0.03}, "y": 1936},
	"art": {"n": "砲兵", "d": "攻撃 +5%", "m": {"atk": 0.05}, "y": 1936},
	"armor": {"n": "機甲", "d": "攻撃 +4%・突撃力 +2%", "m": {"atk": 0.04, "chg": 0.02}, "y": 1937},
	"ind": {"n": "工業", "d": "軍需・民需工場の出力 +6%", "m": {"mf": 0.06, "cf": 0.06}, "y": 1936},
	"constr": {"n": "建設", "d": "建設費 -5%", "m": {"build": -0.05}, "y": 1936},
	"fort": {"n": "築城", "d": "砦の防御 +8%・防御 +2%", "m": {"fort": 0.08, "def": 0.02}, "y": 1936},
	"log": {"n": "兵站", "d": "消耗 -15%・兵の上限 +5%", "m": {"attr": -0.15, "cap": 0.05}, "y": 1936},
	"air": {"n": "航空", "d": "空軍力 +20%", "m": {"air": 0.20}, "y": 1936},
	"naval": {"n": "海軍", "d": "海軍力 +20%", "m": {"navy": 0.20}, "y": 1936},
}
const TECH_KEYS := ["inf", "art", "armor", "ind", "constr", "fort", "log", "air", "naval"]
const TECH_MAX := 5
const RES_SLOTS := 2
func techLv(na: Dictionary, k: String) -> int: return int(na.get("tech", {}).get(k, 0))
func techYear(k: String, lv: int) -> float: return TECHS[k].y + (lv - 1) * 1.5
func curYear() -> float: return 1936.0 + (G.turn - 1) / 12.0
func techCost(na: Dictionary, k: String) -> float:
	var lv = techLv(na, k) + 1
	var c: float = 60.0 + lv * 30.0
	if techYear(k, lv) > curYear(): c *= 2.0   # 年代より先の研究は2倍かかる
	return c
## 研究の速さ（毎ターン）：民需工場が多いほど速い
func researchRate(na: Dictionary) -> float:
	var cf: int = factoryCount(na.id)[1]
	return 5.0 + cf * 0.6 + nmod(na.id, "rsch") * 10.0
## 装備の世代（歩兵装備・砲兵・機甲の平均）
func equipGen(na: Dictionary) -> float: return (techLv(na, "inf") + techLv(na, "art") + techLv(na, "armor")) / 3.0
func techMods(na: Dictionary, m: Dictionary) -> void:
	for k in TECH_KEYS:
		var lv = techLv(na, k)
		if lv <= 0: continue
		for x in TECHS[k].m: m[x] = m.get(x, 0.0) + TECHS[k].m[x] * lv
func researchTurn(na: Dictionary) -> void:
	if not na.has("tech"): na.tech = {}
	if not na.has("rsch"): na.rsch = []
	var rate = researchRate(na)
	var done = []
	for r in na.rsch:
		r.p += rate
		if r.p >= techCost(na, r.k):
			na.tech[r.k] = techLv(na, r.k) + 1
			done.append(r)
			var msg = "%s が研究「%s %d」を終える" % [na.name, TECHS[r.k].n, na.tech[r.k]]
			if concerns([na.id]): logMsg(msg)
			if isMajor(na): chron(msg, na.id, "gov")
	for r in done: na.rsch.erase(r)
	if done.size(): hoiRecalc(na)
	while na.rsch.size() < RES_SLOTS:
		var k = _pickTech(na)
		if k == null: break
		na.rsch.append({"k": k, "p": 0.0})
func _pickTech(na: Dictionary):
	var war = inWar(na.id)
	var best = null
	var bw = -1.0
	for k in TECH_KEYS:
		if techLv(na, k) >= TECH_MAX: continue
		var busy = false
		for r in na.rsch:
			if r.k == k: busy = true
		if busy: continue
		var w = 1.0 + randf() * 0.6
		match na.get("ideo", "neutral"):
			"fascism": w *= {"armor": 1.8, "art": 1.5, "air": 1.5}.get(k, 1.0)
			"communism": w *= {"inf": 1.6, "ind": 1.5, "armor": 1.4}.get(k, 1.0)
			"democracy": w *= {"ind": 1.6, "naval": 1.5, "air": 1.3}.get(k, 1.0)
			_: w *= {"ind": 1.5, "fort": 1.5, "constr": 1.3}.get(k, 1.0)
		if war and (k == "inf" or k == "art" or k == "armor"): w *= 1.5
		if techYear(k, techLv(na, k) + 1) > curYear(): w *= 0.4
		if k == "naval" and coastCount(na.id) < 3: w *= 0.2
		if w > bw:
			bw = w
			best = k
	return best

# ---------- 資源（鉄・石油）と貿易 ----------
const RES_KINDS := {"steel": "鉄", "oil": "石油"}
## 領地ごとの産出（ゲーム開始時に一度だけ決める。鉄は山や鉄の産地、石油は平地や湿地に多い）
func resourceInit(g: Dictionary) -> void:
	for t in g.terrs:
		if t.has("ress"): continue
		var r = {}
		var h: int = abs(hash(str(t.id) + "_" + str(g.get("jpMap", 0)) + "_r"))
		var tr: String = str(t.get("terrain", "plain"))
		var steelP: float = 0.10 + (0.25 if tr == "mount" or tr == "hill" else 0.0) + (0.5 if t.get("trait") == "iron" else 0.0)
		var oilP: float = 0.07 + (0.12 if tr == "plain" or tr == "marsh" else 0.0)
		if (h % 1000) / 1000.0 < steelP: r.steel = 1 + h % 3
		if ((h / 1000) % 1000) / 1000.0 < oilP: r.oil = 1 + (h / 7) % 3
		t.ress = r
## 国の資源（産出・必要・不足）。必要：軍需工場1つで鉄 1・石油 0.5、機甲の段階ごとに石油 +1
func resources(nid: int) -> Dictionary:
	var na = NAT(nid)
	var have = {"steel": 0.0, "oil": 0.0}
	for t in ownList(nid):
		for k in t.get("ress", {}): have[k] += t.ress[k]
	var mul: float = 1.0 + nmod(nid, "res")
	for k in have: have[k] *= mul
	var mf: int = factoryCount(nid)[0]
	# 人造石油：軍需工場の一部が石炭から石油を作る（ドイツは多い）
	have.oil += mf * (0.15 + nmod(nid, "synth"))
	var need = {"steel": mf * 1.0, "oil": mf * 0.5 + techLv(na, "armor") * 1.0}
	# 通商相手の余りを輸入する
	var imp = {"steel": 0.0, "oil": 0.0}
	for p in tradePartners(nid):
		var ph = {"steel": 0.0, "oil": 0.0}
		for t in ownList(p):
			for k in t.get("ress", {}): ph[k] += t.ress[k]
		var pmf: int = factoryCount(p)[0]
		var spare = {"steel": ph.steel - pmf * 1.0, "oil": ph.oil - pmf * 0.5}
		for k in imp: imp[k] += max(0.0, spare[k]) * 0.5
	var ratio = 1.0
	for k in need:
		if need[k] > 0: ratio = min(ratio, (have[k] + imp[k]) / need[k])
	return {"have": have, "need": need, "imp": imp, "ratio": clamp_f(ratio, 0, 1)}
## 資源の不足による軍需工場の倍率（足りなければ最低 0.5 倍）
func resMul(nid: int) -> float:
	var c = _resCache.get(nid)
	if c == null or c[0] != G.turn:
		c = [G.turn, 0.5 + 0.5 * resources(nid).ratio]
		_resCache[nid] = c
	return c[1]
var _resCache = {}
## その国に足りない資源を、相手が持っているか（戦の狙いに使う）
func resWant(nid: int, o: int) -> bool:
	if resMul(nid) >= 0.95: return false
	for t in ownList(o):
		if t.get("ress", {}).size(): return true
	return false
## 消費財：民需工場の出力のうち国内の消費に取られる割合（経済法で変わる）。標準（30%）で 1.0 倍
func consumerMul(na: Dictionary) -> float: return clamp_f(1.0 - (consumerShare(na) - 0.30), 0.6, 1.3)
func coastCount(nid: int) -> int:
	coastInfo()
	var n = 0
	for t in ownList(nid):
		if COAST.has(t.id): n += 1
	return n

# ==================== k8d_military.gd ====================
# HOI4 を参考にした軍事：組織率・消耗・包囲殲滅・攻勢計画・空軍・海軍・将軍の特性・占領地の抵抗

# ---------- 組織率 ----------
## 0〜100。戦うと下がり、休むと戻る。低いと攻防が落ちる（100で1倍、0で0.6倍）
func orgOf(a: Dictionary) -> float: return float(a.get("org", 100.0))
func orgMul(a: Dictionary) -> float: return 0.6 + 0.4 * clamp_f(orgOf(a), 0, 100) / 100.0
func orgAfterBattle(A: Array, D: Array, winner: String) -> void:
	for a in A:
		if a != null: a.org = clamp_f(orgOf(a) - (14.0 if winner == "A" else 26.0), 0, 100)
	for a in D:
		if a != null: a.org = clamp_f(orgOf(a) - (14.0 if winner == "D" else 26.0), 0, 100)

# ---------- 毎ターン：組織率の回復・消耗・包囲 ----------
var _yRange = []
func _northFrac(t: Dictionary) -> float:
	if _yRange.is_empty() or _yRange[2] != G:
		var lo = INF
		var hi = -INF
		for x in G.terrs:
			lo = min(lo, x.y)
			hi = max(hi, x.y)
		_yRange = [lo, hi, G]
	return 1.0 - (t.y - _yRange[0]) / max(1.0, _yRange[1] - _yRange[0])
func isWinter() -> bool:
	var m: int = (G.turn - 1) % 12 + 1
	return m == 12 or m == 1 or m == 2
func armyUpkeepTurn() -> void:
	var winter = isWinter()
	for na in G.nations:
		if not na.alive: continue
		var attrMul: float = max(0.2, 1.0 + nmod(na.id, "attr"))
		for a in na.armies:
			if a == null or total(a.t) <= 0: continue
			var t = T(a.at)
			var home: bool = t.owner == na.id
			var sup: bool = a.get("sup", true) != false
			# 組織率の回復
			a.org = clamp_f(orgOf(a) + (12.0 if home and sup else (6.0 if sup else 1.0)), 0, 100)
			# 消耗：補給切れ・敵地の山や森や湿地・冬の北国
			var rate = 0.0
			if not sup: rate += 0.03
			if not home and (t.terrain == "mount" or t.terrain == "forest" or t.terrain == "marsh"): rate += 0.01
			if winter and _northFrac(t) > 0.7 and not home: rate += 0.02
			rate *= attrMul
			if rate > 0:
				for k in TK: a.t[k] = int(a.t[k] * (1.0 - rate))
			# 包囲：補給が5ターン続けて切れたら降伏する
			a.cutN = 0 if sup else a.get("cutN", 0) + 1
			if a.cutN >= 5 and not home:
				var lost = total(a.t)
				for k in TK: a.t[k] = 0
				if a.gen != null:
					var g = genOf(na, a.gen)
					if g != null: g.army = null
				na.armies[a.idx] = null
				ARMY_REV += 1
				var msg = "%s の %s が %s で包囲され降伏する（%s人）" % [na.name, a.name, t.name, fmt(lost)]
				logWar(msg, [na.id, t.owner], "war")
				chron(msg, na.id, "war")
				var cap = t.owner
				if cap >= 0 and cap != na.id: addFavor(na.id, cap, -5)

# ---------- 攻勢計画 ----------
## 前線全体でこちらが 1.3 倍以上強ければ「全面攻勢」。前線の守備軍も 1.2 倍以上の所から一斉に攻める
func offensiveCheck(nid: int, frontPow: float, foePow: float) -> void:
	var na = NAT(nid)
	var was: bool = na.get("offensive", false)
	var now: bool = frontPow >= foePow * 1.3 and frontPow > 0
	if was and frontPow < foePow * 1.1: now = false
	elif was: now = true
	na.offensive = now
	if now and not was:
		var msg = "%s が全面攻勢を開始する" % na.name
		if newsworthy([nid]): headline("%s、全面攻勢" % natLabel(nid), "前線の各地で一斉に攻勢へ")
		if concerns([nid]): logMsg(msg, "war")
		chron(msg, nid, "war")

# ---------- 空軍・海軍 ----------
## 空軍力：軍需工場と航空の研究から。戦いでは、制空権を取った側（1.5倍以上）の攻防 +10%
func airPower(nid: int) -> float: return factoryCount(nid)[0] * (1.0 + nmod(nid, "air"))
## 海軍力：海に面した領地と海軍の研究から。海峡を越えて攻める時、制海権が無いと攻撃 -25%
func navyPower(nid: int) -> float: return coastCount(nid) * (1.0 + nmod(nid, "navy"))
func airEdge(a: int, b: int) -> float:
	var x = airPower(a)
	var y = airPower(b)
	if x >= y * 1.5 and x > 0: return 0.10
	if y >= x * 1.5 and y > 0: return -0.10
	return 0.0
func seaEdgePenalty(att: int, def: int, from: int, to: int) -> float:
	var e = edgeBetween(from, to)
	if e == null or not e.get("sea", false): return 0.0
	return 0.0 if navyPower(att) >= navyPower(def) else -0.25

# ---------- 将軍の特性と昇進 ----------
const GEN_TRAITS := {
	"atk": {"n": "攻勢の名手", "d": "率いる軍の攻撃 +8%"},
	"def": {"n": "守戦の名手", "d": "率いる軍の防御 +8%"},
	"mount": {"n": "山岳戦", "d": "山・丘での攻防 +10%"},
	"mob": {"n": "機動戦", "d": "突撃力 +5%"},
}
## 勝つたびに経験を積み、3勝ごとに特性を1つ得る。10勝で元帥（攻防 +5%）
func genAfterBattle(A: Array, D: Array, winner: String, t: Dictionary) -> void:
	for side in [[A, "A"], [D, "D"]]:
		if side[1] != winner: continue
		for a in side[0]:
			if a == null or a.gen == null: continue
			var g = genOf(NAT(a.owner), a.gen)
			if g == null: continue
			g.vic = g.get("vic", 0) + 1
			if not g.has("traits"): g.traits = []
			if g.vic % 3 == 0 and g.traits.size() < 3:
				var cand = []
				for k in GEN_TRAITS:
					if not g.traits.has(k): cand.append(k)
				if side[1] == "A" and cand.has("atk"): cand.append("atk")
				if side[1] == "D" and cand.has("def"): cand.append("def")
				if (t.terrain == "mount" or t.terrain == "hill") and cand.has("mount"): cand.append("mount")
				if cand.size():
					var k = cand[randi() % cand.size()]
					g.traits.append(k)
					chron("%s の将軍 %s が「%s」を身につける" % [NAT(a.owner).name, g.get("name", "?"), GEN_TRAITS[k].n], a.owner, "war")
			if g.vic == 10:
				g.marshal = true
				chron("%s の将軍 %s が元帥に昇進する" % [NAT(a.owner).name, g.get("name", "?")], a.owner, "war")
func genTraitMods(a: Dictionary, t: Dictionary) -> Dictionary:
	var r = {"atk": 0.0, "def": 0.0, "chg": 0.0}
	if a.gen == null: return r
	var g = genOf(NAT(a.owner), a.gen)
	if g == null: return r
	for k in g.get("traits", []):
		match k:
			"atk": r.atk += 0.08
			"def": r.def += 0.08
			"mob": r.chg += 0.05
			"mount":
				if t.terrain == "mount" or t.terrain == "hill":
					r.atk += 0.10
					r.def += 0.10
	if g.get("marshal", false):
		r.atk += 0.05
		r.def += 0.05
	return r

# ---------- 占領地の抵抗と協力 ----------
## 本土でない領地（取った土地）は、協力度（0〜100）が低いうちは生産が落ち、治安も下がる。協力度は毎ターン少しずつ上がる
func collabOf(t: Dictionary) -> float:
	if t.owner < 0 or t.get("home", -1) == t.owner: return 100.0
	return float(t.get("collab", 0.0))
func occMul(t: Dictionary) -> float: return 0.5 + 0.5 * collabOf(t) / 100.0
func occupationTurn() -> void:
	for t in G.terrs:
		if t.owner < 0 or t.get("home", -1) == t.owner: continue
		var c: float = t.get("collab", 0.0)
		var na = NAT(t.owner)
		var rate: float = 2.0 + (1.0 if na.get("ideo") == "fascism" or na.get("ideo") == "communism" else 0.0)
		t.collab = clamp_f(c + rate, 0, 100)
		if c < 30: t.sec = clamp_f(t.sec - 2, 0, 100)

# ==================== k8e_diplo.gd ====================
# HOI4 を参考にした外交：内戦・義勇軍・レンドリース（軍需品の供与）・陣営への加盟申請

# ---------- 内戦 ----------
## 安定度がとても低い時に政変が起きると、すぐには政権が変わらず内戦になる。
## 内戦の間は兵の生産・ゴールドが落ち、一部の領地が混乱する。終わる時、支持の多い側が政権を取る
const CIVIL_TURNS := 12
func startCivilWar(na: Dictionary, rebel: String, endTurn := -1) -> void:
	if na.has("civil"): return
	na.civil = {"side": rebel, "end": endTurn if endTurn > 0 else G.turn + CIVIL_TURNS}
	_rmSpirit(na, "内戦")
	_addSpirit(na, "内戦", "兵の生産 -30%・ゴールド -30%・安定度 -10", {"troop": -0.30, "gold": -0.30, "stab": -10.0}, "内戦")
	var own = ownList(na.id)
	var cap = T(na.capital)
	var far = own.duplicate()
	far.sort_custom(func(a, b): return Vector2(a.x, a.y).distance_to(Vector2(cap.x, cap.y)) > Vector2(b.x, b.y).distance_to(Vector2(cap.x, cap.y)))
	for i in int(far.size() * 0.3):
		far[i].chaos = max(far[i].chaos, 4)
		far[i].sec = clamp_f(far[i].sec - 25, 0, 100)
	var msg = "%s で内戦が始まる — %s 政権 対 %s 派" % [na.name, IDEO[na.ideo].n, IDEO[rebel].n]
	headline("%s で内戦" % natLabel(na.id), "%s 政権 対 %s 派" % [IDEO[na.ideo].n, IDEO[rebel].n])
	logMsg(msg, "war")
	chron(msg, na.id, "war")
	addTension(4)
## 方針で内戦が決着した時（政権の交代は方針の効果のほうで行う）
func endCivilWarBy(na: Dictionary, why: String) -> void:
	na.erase("civil")
	headline("%s の内戦、終わる" % natLabel(na.id), why)
	chron("%s の内戦が終わる（%s）" % [na.name, why], na.id, "war")
## 歴史イベント：1936年7月、スペイン（京都）で内戦が始まる（終わりは方針「内戦の行方」の結果で決まる）
func historyEventsTurn() -> void:
	if G.get("size") != "japan" or G.turn != 7: return
	var sp = natByName("京都府")
	if sp < 0 or not NAT(sp).alive or NAT(sp).has("civil"): return
	var has = false
	for s in NAT(sp).spirits:
		if s.n == "内戦": has = true
	if has: startCivilWar(NAT(sp), "fascism", G.turn + 999)
func civilWarTurn(na: Dictionary) -> void:
	var cw = na.get("civil")
	if cw == null: return
	# 同じ思想の国が反乱側・政府側を支援する（支持が動く）
	for o in G.nations:
		if not o.alive or o.id == na.id or not natNear(o.id, na.id) or not o.has("ideo"): continue
		if o.ideo == cw.side: na.ipop[cw.side] = na.ipop.get(cw.side, 0.0) + 0.6
		elif o.ideo == na.ideo: na.ipop[na.ideo] = na.ipop.get(na.ideo, 0.0) + 0.6
	_normPop(na)
	if G.turn < cw.end: return
	na.erase("civil")
	_rmSpirit(na, "内戦")
	var win: String = cw.side if na.ipop.get(cw.side, 0.0) >= na.ipop.get(na.ideo, 0.0) else na.ideo
	var msg = "%s の内戦が終わる — %s" % [na.name, ("%s 派が勝ち、政権を取る" % IDEO[win].n) if win != na.ideo else "政府が反乱を抑える"]
	logMsg(msg, "war")
	chron(msg, na.id, "war")
	if win != na.ideo: setGov(na, win, "内戦")
	else: na.ipop[cw.side] = na.ipop.get(cw.side, 0.0) * 0.5
	_normPop(na)

# ---------- 義勇軍・レンドリース ----------
## 毎ターン、国ごとに：戦争していない国が、戦争中の同じ思想の国へ義勇軍（兵）を、
## 軍需品に余裕のある国が、戦争中の同じ陣営・同じ思想の国へ軍需品を送る
func supportTurn(na: Dictionary) -> void:
	var nid: int = na.id
	# 義勇軍も軍需品も送れない国は調べない（軽さのため）
	var canVol: bool = na.get("ws", 0) >= 30 and total(na.stock) > 4000
	var canLL: bool = na.get("eq", 0) > 9000
	if not canVol and not canLL: return
	if not na.has("supCool"): na.supCool = {}
	var war = inWar(nid)
	if war and not canLL: return
	for o in G.nations:
		if not o.alive or o.id == nid or atWar(nid, o.id): continue
		if na.supCool.get(o.id, -99) > G.turn: continue
		var cw = o.get("civil")
		# 内戦中の国：反乱側と同じ思想の国は反乱側へ、政府と同じ思想の国は政府へ義勇軍を送る
		var rebelSide: bool = cw != null and cw.side == na.get("ideo")
		var sameIdeo: bool = o.get("ideo") == na.get("ideo") or rebelSide
		var sameFac = sameFaction(nid, o.id)
		if not sameIdeo and not sameFac: continue
		if not natNear(nid, o.id) or (cw == null and not inWar(o.id)): continue
		if rebelSide:
			if canVol and not war and randf() < 0.12:
				o.ipop[cw.side] = o.ipop.get(cw.side, 0.0) + 3.0
				_normPop(o)
				na.supCool[o.id] = G.turn + 12
				var m0 = "%s が %s の %s 派へ義勇軍を送る" % [na.name, o.name, IDEO[cw.side].n]
				if concerns([nid, o.id]): logMsg(m0)
				chron(m0, nid, "dip")
				if newsworthy([nid]): headline("%s、%s の内戦に義勇軍" % [natLabel(nid), natLabel(o.id)], "%s 派を支援する" % IDEO[cw.side].n)
			continue
		# 義勇軍：自分は戦争しておらず、戦争支持が 30 以上
		if not war and sameIdeo and na.ws >= 30 and total(na.stock) > 4000 and randf() < 0.10:
			var sent = 0
			for k in TK:
				var n = int(na.stock[k] * 0.08)
				na.stock[k] -= n
				o.stock[k] += n
				sent += n
			if sent > 0:
				na.supCool[o.id] = G.turn + 18
				var msg = "%s が %s へ義勇軍 %s人 を送る" % [na.name, o.name, fmt(sent)]
				if concerns([nid, o.id]): logMsg(msg)
				chron(msg, nid, "dip")
				addFavor(o.id, nid, 8)
				continue
		# レンドリース：軍需品に余裕がある
		if na.get("eq", 0) > 9000 and (sameFac or na.get("ideo") == "democracy") and randf() < 0.15:
			var give: int = int(min(na.eq * 0.2, 6000))
			na.eq -= give
			o.eq = o.get("eq", 0) + give
			na.supCool[o.id] = G.turn + 12
			var msg2 = "%s が %s へ軍需品 %s を供与する（レンドリース）" % [na.name, o.name, fmt(give)]
			if concerns([nid, o.id]): logMsg(msg2)
			chron(msg2, nid, "dip")
			addFavor(o.id, nid, 6)

# ---------- 陣営への加盟申請 ----------
## 陣営に入っていない国が、思想の合う近くの陣営に加盟を申請し、盟主が受け入れを決める
func factionApplyTurn(na: Dictionary) -> void:
	var nid: int = na.id
	if facOf(nid) != null or lordOf(nid) != null or randf() > 0.04: return
	var best = null
	var bs = -INF
	for F in G.get("factions", {}).values():
		if not NAT(F.leader).alive or not facFit(nid, F.leader): continue
		var near = false
		var war = false
		for m in F.members:
			if natNear(m, nid): near = true
			if atWar(m, nid): war = true
		if not near or war: continue
		var s: float = favorOf(nid, F.leader) + (25 if NAT(F.leader).get("ideo") == na.get("ideo") else 0) + cpuDanger(nid) * 30
		if s > bs:
			bs = s
			best = F
	if best == null or bs < 40: return
	var ok: bool = favorOf(best.leader, nid) >= 30 and best.members.size() < 8
	var msg = "%s が「%s」への加盟を申請し、%s" % [na.name, best.name, "認められる" if ok else "断られる"]
	if concerns([nid, best.leader]): logMsg(msg, "good" if ok else "")
	chron(msg, nid, "dip")
	if ok: joinFaction(best, nid)
	else: addFavor(nid, best.leader, -5)

# ---------- 新聞の見出し ----------
## 大きな出来事を「国盗り新報」の見出しとして画面に出す（止めずに流す）
signal news(head: String, sub: String)
func headline(head: String, sub := "") -> void:
	if G == null: return
	# 見逃しても後で読めるように、見出しを綴っておく（新しい60件）
	if not G.has("news"): G.news = []
	G.news.append({"t": G.turn, "h": head, "s": sub})
	if G.news.size() > 60: G.news = G.news.slice(-60)
	news.emit(head, sub)

# ---------- 年の振り返り ----------
## 毎年1月に、前の年に最も版図を広げた国・失った国と、宣戦の数を見出しにする
func yearReviewTurn() -> void:
	if (G.turn - 1) % 12 != 0: return
	var now = {}
	for na in G.nations:
		if na.alive: now[na.id] = ownCount(na.id)
	var base: Dictionary = G.get("yearBase", {})
	var decl: int = G.get("declN", 0) - G.get("yearDecl", 0)
	if base.size():
		var up = -1
		var upN = 0
		var dn = -1
		var dnN = 0
		for k in base:
			var d: int = now.get(int(k), 0) - int(base[k])
			if d > upN:
				upN = d
				up = int(k)
			if d < dnN:
				dnN = d
				dn = int(k)
		var parts = []
		if up >= 0: parts.append("躍進：%s（+%d）" % [natLabel(up), upN])
		if dn >= 0: parts.append("後退：%s（%d）" % [natLabel(dn), dnN] if NAT(dn).alive else "滅亡：%s" % natLabel(dn))
		parts.append("宣戦 %d 回" % decl)
		headline("%d年を振り返る" % (int(curYear()) - 1), "・".join(parts))
	G.yearBase = now
	G.yearDecl = G.get("declN", 0)
## 大国（固有の大きな方針ツリーを持つ国）か、選んだ国が関わるか
func newsworthy(ids: Array) -> bool:
	for i in ids:
		if i >= 0 and i < G.nations.size() and (isMajor(NAT(i)) or concerns([i])): return true
	return false
func natLabel(nid: int) -> String:
	var na = NAT(nid)
	var r: String = na.get("role", "")
	return ("%s（%s）" % [r, na.name.trim_suffix("県").trim_suffix("都").trim_suffix("府")]) if r != "" else na.name

# ---------- 歴史イベント：ミュンヘン会談 ----------
## ドイツ（群馬）がチェコスロバキア（栃木）に併合を要求すると、イギリス（東京）が宥和か対決かを選ぶ
func munichEvent(ger: int, cze: int) -> String:
	var uk = natByName("東京都")
	var fr = natByName("長野県")
	if uk < 0 or NAT(uk).get("ideo") != "democracy": return ""
	var ukna = NAT(uk)
	var firm: float = 0.35 + (0.4 if ukna.focus.done.has("b3") else 0.0) - (0.3 if ukna.focus.done.has("b2") else 0.0) + (tension() - 40) / 200.0
	var stand: bool = randf() < clamp_f(firm, 0.05, 0.95)
	if stand:
		for g in [uk, fr]:
			if g >= 0 and not NAT(g).get("guar", []).has(cze):
				if not NAT(g).has("guar"): NAT(g).guar = []
				NAT(g).guar.append(cze)
		headline("ミュンヘン会談、決裂", "%s は %s の要求を拒み、%s の独立を保証" % [natLabel(uk), natLabel(ger), natLabel(cze)])
		chron("ミュンヘン会談：%s は宥和を拒み、%s の独立を保証する" % [NAT(uk).name, NAT(cze).name], uk, "dip")
		return "stand"
	headline("ミュンヘン会談、宥和で妥結", "%s は %s の要求を認める —「我らの時代の平和」" % [natLabel(uk), natLabel(ger)])
	chron("ミュンヘン会談：%s は %s の要求を認める（宥和）" % [NAT(uk).name, NAT(ger).name], uk, "dip")
	return "appease"

# ==================== k9_data.gd ====================
# HOI4を参考にした歴史IFのデータ：思想（政党）・国民精神・国家方針ツリー
# 47都道府県それぞれを1936年の国に見立てる（群馬＝ドイツ、北海道＝ソ連 …）
# 方針の効果のキー：
#   sp=[名前, 説明, {修正}]（国民精神を得る） rm="精神の名前"（外す）
#   stab/ws/pp=安定度・戦争支持・政治力  mf/cf=軍需・民需工場を建てる数  eq=軍需品  gold=ゴールド
#   ideo=[思想, 支持率]（支持を上げる） gov="思想"（その思想の政権に変わる）
#   dev/infra=開発度・インフラを上げる領地の数  favor=隣国の好感度
#   claim=1（弱い隣国への大義） claimOn=[県]（その国への大義） warOn="県"（大義＋開戦準備）
#   demand=[県]（併合・従属の要求。断られたら大義） guar=[県]（独立の保証：攻められたら参戦） pact="県"（不可侵条約）
#   fac="陣営名"（陣営を作る） joinFac="陣営名"（その陣営に入る。なければ作る） invite=[県]（自分の陣営に招く）
# 修正（国民精神）のキー：gold/food/troop（兵の生産）/atk/def/pop（人口上限）/grow（人口の伸び）/sec（毎ターンの治安）
#   stab/ws（安定度・戦争支持の目標）/mf/cf（工場の出力）/build（建設費、負で安く）/fort（砦の防御）/pp（政治力）/cap（兵の上限）

## 思想（与党）。政権を握る思想で国のふるまい（IDEO_PERSONA）が決まる
const IDEO := {
	"democracy": {"n": "民主主義", "c": "#4f8fd6", "d": "選挙で選ばれた政府。大義のない戦はせず、戦争支持がかなり高くないと宣戦しない。条約と保証で守る", "stab": 10, "ws": -15, "wsNeed": 70, "pp": 2.0, "mod": {"gold": 0.05}},
	"communism": {"n": "共産主義", "c": "#c0392b", "d": "党による計画経済。重工業が強く、同じ思想の国を陣営に引き込む", "stab": 0, "ws": 5, "wsNeed": 50, "pp": 2.0, "mod": {"mf": 0.10, "troop": 0.05}},
	"fascism": {"n": "ファシズム", "c": "#8a6d3b", "d": "拡張主義。戦争支持が上がりやすく、口実を作ってでも隣国を狙う。兵の生産 +15%・攻撃 +10%・防御 +5%", "stab": 0, "ws": 20, "wsNeed": 30, "pp": 2.5, "mod": {"troop": 0.15, "atk": 0.10, "def": 0.05}},
	"neutral": {"n": "非同盟", "c": "#9b9484", "d": "王政・軍人政権・権威主義の政府。内政を優先し、攻められた時に戦う", "stab": 5, "ws": 0, "wsNeed": 55, "pp": 2.0, "mod": {}},
}
const IDEO_KEYS := ["democracy", "communism", "fascism", "neutral"]

## 思想ごとの国のふるまい（元の「気質」を置き換える）
const IDEO_PERSONA := {
	"fascism": {"n": "ファシズム", "d": "拡張主義", "army": 1, "goal": 0.85, "atkTh": 1.05, "guard": 0.34, "mkt": 0.22, "devG": 9000, "roadG": 21000, "mix": {"inf": 0.42, "spe": 0.13, "arc": 0.20, "cav": 0.25}, "settle": 0.8,
		"tradeW": -10, "pactW": -10, "fab": 0.5, "noCB": 0.15, "peaceW": -0.03, "dd": "拡張主義：口実を作ってでも弱い隣国を狙う。条約は都合のよい時だけ"},
	"communism": {"n": "共産主義", "d": "世界革命", "army": 0, "goal": 1.0, "atkTh": 1.2, "guard": 0.50, "mkt": 0.30, "devG": 6000, "roadG": 16000, "mix": {"inf": 0.48, "spe": 0.22, "arc": 0.18, "cav": 0.12}, "settle": 1.1,
		"tradeW": 0, "pactW": 5, "fab": 0.25, "noCB": 0.0, "peaceW": 0.02, "dd": "世界革命：大義があり勝てる時に戦う。同じ思想の国を陣営に引き込む"},
	"democracy": {"n": "民主主義", "d": "集団安全保障", "army": 0, "goal": 1.10, "atkTh": 1.50, "guard": 0.62, "mkt": 0.50, "devG": 5000, "roadG": 13000, "mix": {"inf": 0.40, "spe": 0.30, "arc": 0.20, "cav": 0.10}, "settle": 1.2,
		"tradeW": 15, "pactW": 20, "fab": 0.0, "noCB": 0.0, "peaceW": 0.06, "dd": "集団安全保障：大義のない戦はしない。通商・条約・保証で守りを固める"},
	"neutral": {"n": "非同盟", "d": "内政優先", "army": -1, "goal": 1.10, "atkTh": 1.40, "guard": 0.55, "mkt": 0.55, "devG": 4000, "roadG": 11000, "mix": {"inf": 0.45, "spe": 0.22, "arc": 0.20, "cav": 0.13}, "settle": 1.4,
		"tradeW": 10, "pactW": 15, "fab": 0.05, "noCB": 0.0, "peaceW": 0.07, "dd": "内政優先：国を富ませ、攻められた時に戦う。早く講和する"},
}

## 共通の方針ツリー（x=列 y=段。req=前提（どれか1つ） ex=同時に取れない方針）
## 大国（tree を持つ国）は産業・軍事の枝だけを使う
const FOCUS_COMMON := [
	{"id": "c_ind1", "n": "殖産興業", "x": 0, "y": 0, "t": 5, "req": [], "br": "ind", "e": {"cf": 1, "pp": 10}},
	{"id": "c_ind2", "n": "軍需産業の拡充", "x": 0, "y": 1, "t": 6, "req": ["c_ind1"], "br": "ind", "e": {"mf": 1}},
	{"id": "c_ind3", "n": "農業の機械化", "x": 1, "y": 1, "t": 6, "req": ["c_ind1"], "br": "ind", "e": {"sp": ["農業の機械化", "食料 +15%・人口上限 +5%", {"food": 0.15, "pop": 0.05}]}},
	{"id": "c_ind4", "n": "技術者の育成", "x": 0, "y": 2, "t": 7, "req": ["c_ind2"], "br": "ind", "e": {"sp": ["技術者の育成", "軍需工場の出力 +15%・民需工場の出力 +10%", {"mf": 0.15, "cf": 0.10}]}},
	{"id": "c_ind5", "n": "鉄道網の整備", "x": 1, "y": 2, "t": 6, "req": ["c_ind3"], "br": "ind", "e": {"infra": 3, "sp": ["鉄道網", "建設費 -10%・ゴールド +5%", {"build": -0.10, "gold": 0.05}]}},
	{"id": "c_mil1", "n": "陸軍の改革", "x": 3, "y": 0, "t": 5, "req": [], "br": "mil", "e": {"sp": ["陸軍の改革", "攻撃 +5%", {"atk": 0.05}], "ws": 5}},
	{"id": "c_mil2", "n": "兵站の整備", "x": 3, "y": 1, "t": 6, "req": ["c_mil1"], "br": "mil", "e": {"eq": 3000, "mf": 1}},
	{"id": "c_mil3", "n": "国境の要塞化", "x": 4, "y": 1, "t": 6, "req": ["c_mil1"], "br": "mil", "e": {"sp": ["国境の要塞", "砦の防御 +15%・防御 +5%", {"fort": 0.15, "def": 0.05}]}},
	{"id": "c_mil4", "n": "機甲戦の研究", "x": 3, "y": 2, "t": 7, "req": ["c_mil2", "c_mil3"], "br": "mil", "e": {"sp": ["機甲戦の研究", "攻撃 +5%・防御 +5%", {"atk": 0.05, "def": 0.05}], "ws": 5}},
	{"id": "c_pol1", "n": "政治の刷新", "x": 6, "y": 0, "t": 5, "req": [], "br": "pol", "e": {"stab": 10, "pp": 20}},
	{"id": "c_pol_d", "n": "民主主義の擁護", "x": 5, "y": 1, "t": 7, "req": ["c_pol1"], "ex": ["c_pol_c", "c_pol_f", "c_pol_n"], "br": "pol", "e": {"ideo": ["democracy", 30], "stab": 10}},
	{"id": "c_pol_c", "n": "人民戦線", "x": 6, "y": 1, "t": 7, "req": ["c_pol1"], "ex": ["c_pol_d", "c_pol_f", "c_pol_n"], "br": "pol", "e": {"ideo": ["communism", 30], "sp": ["労働者の団結", "軍需工場の出力 +10%", {"mf": 0.10}]}},
	{"id": "c_pol_f", "n": "国民革命", "x": 7, "y": 1, "t": 7, "req": ["c_pol1"], "ex": ["c_pol_d", "c_pol_c", "c_pol_n"], "br": "pol", "e": {"ideo": ["fascism", 30], "ws": 15}},
	{"id": "c_pol_n", "n": "中立の堅持", "x": 8, "y": 1, "t": 7, "req": ["c_pol1"], "ex": ["c_pol_d", "c_pol_c", "c_pol_f"], "br": "pol", "e": {"ideo": ["neutral", 30], "sp": ["中立", "安定度 +10・防御 +5%", {"stab": 10.0, "def": 0.05}]}},
	{"id": "c_dip1", "n": "外交使節", "x": 10, "y": 0, "t": 5, "req": [], "br": "dip", "e": {"favor": 15, "pp": 10}},
	{"id": "c_dip2", "n": "通商協定", "x": 10, "y": 1, "t": 6, "req": ["c_dip1"], "br": "dip", "e": {"sp": ["通商協定", "ゴールド +10%", {"gold": 0.10}]}},
	{"id": "c_dip3", "n": "領有権の主張", "x": 11, "y": 1, "t": 6, "req": ["c_dip1"], "br": "dip", "e": {"claim": 1, "ws": 10}},
]

## 大国の固有ツリー（x・y は固有の枝の中での位置）
const TREE_GER := [
	{"id": "g1", "n": "ヴェルサイユ体制の破棄", "x": 2, "y": 0, "t": 5, "req": [], "e": {"ws": 10, "ideo": ["fascism", 25]}},
	{"id": "g2", "n": "全権委任法", "w": 5.0, "x": 1, "y": 1, "t": 6, "req": ["g1"], "ex": ["g2b", "g2c"], "e": {"gov": "fascism", "stab": 10}},
	{"id": "g2b", "n": "共和国の堅持", "x": 3, "y": 1, "t": 6, "req": ["g1"], "ex": ["g2", "g2c"], "e": {"ideo": ["democracy", 25], "stab": 15}},
	{"id": "g2c", "n": "労働者の蜂起", "x": 4, "y": 1, "t": 6, "req": ["g1"], "ex": ["g2", "g2b"], "e": {"gov": "communism", "stab": -10}},
	{"id": "g3", "n": "再軍備宣言", "x": 0, "y": 2, "t": 7, "req": ["g2"], "e": {"rm": "ヴェルサイユの軛", "mf": 2, "sp": ["再軍備", "兵の生産 +25%・軍需工場の出力 +15%・兵の上限 +50%", {"troop": 0.25, "mf": 0.15, "cap": 0.50}]}},
	{"id": "g4", "n": "ラインラント進駐", "x": 1, "y": 2, "t": 5, "req": ["g2"], "e": {"ws": 15, "stab": 5, "sp": ["電撃戦ドクトリン", "攻撃 +15%", {"atk": 0.15}]}},
	{"id": "g5", "n": "アンシュルス", "x": 0, "y": 3, "t": 6, "req": ["g3"], "e": {"demand": ["新潟県"]}},
	{"id": "g6", "n": "枢軸の結成", "x": 1, "y": 3, "t": 6, "req": ["g4"], "e": {"fac": "枢軸", "ws": 5}},
	{"id": "g7", "n": "ズデーテン問題", "x": 0, "y": 4, "t": 6, "req": ["g5"], "e": {"demand": ["栃木県"]}},
	{"id": "g8", "n": "四か年計画", "x": 1, "y": 4, "t": 7, "req": ["g6"], "e": {"mf": 2, "cf": 1}},
	{"id": "g9", "n": "ダンツィヒか戦争か", "x": 0, "y": 5, "t": 6, "req": ["g7"], "e": {"warOn": "福島県", "ws": 10}},
	{"id": "g10", "n": "独ソ不可侵条約", "x": 1, "y": 5, "t": 5, "req": ["g8"], "ex": ["g11"], "e": {"pact": "北海道", "ws": 5}},
	{"id": "g11", "n": "東方への拡張", "x": 2, "y": 5, "t": 7, "req": ["g8"], "ex": ["g10"], "e": {"claimOn": ["北海道"], "sp": ["東方拡張", "攻撃 +5%", {"atk": 0.05}]}},
	{"id": "g12", "n": "西方への進撃", "x": 0, "y": 6, "t": 7, "req": ["g9"], "e": {"claimOn": ["長野県", "埼玉県", "千葉県"], "ws": 10}},
	{"id": "g13", "n": "社会民主党との連立", "x": 3, "y": 2, "t": 6, "req": ["g2b"], "e": {"cf": 2, "stab": 10}},
	{"id": "g14", "n": "国際連盟への復帰", "x": 3, "y": 3, "t": 6, "req": ["g13"], "e": {"favor": 20, "joinFac": "連合国"}},
	{"id": "g15", "n": "赤色戦線", "x": 4, "y": 2, "t": 6, "req": ["g2c"], "e": {"sp": ["赤色戦線", "兵の生産 +10%・軍需工場の出力 +5%", {"troop": 0.10, "mf": 0.05}], "ws": 10}},
	{"id": "g16", "n": "独ソ同盟", "x": 4, "y": 3, "t": 6, "req": ["g15"], "e": {"joinFac": "コミンテルン"}},
]
const TREE_SOV := [
	{"id": "s1", "n": "第二次五か年計画", "x": 1, "y": 0, "t": 5, "req": [], "e": {"mf": 1, "cf": 1, "pp": 10}},
	{"id": "s2", "n": "重工業の拡張", "x": 0, "y": 1, "t": 6, "req": ["s1"], "e": {"mf": 2}},
	{"id": "s3", "n": "大粛清", "x": 2, "y": 1, "t": 6, "req": ["s1"], "ex": ["s3b"], "e": {"stab": 15, "ideo": ["communism", 20]}},
	{"id": "s3b", "n": "粛清の中止", "x": 3, "y": 1, "t": 6, "req": ["s1"], "ex": ["s3"], "e": {"rm": "大粛清の影", "stab": -5}},
	{"id": "s4", "n": "寒地農法の確立", "x": 0, "y": 2, "t": 8, "req": ["s2"], "e": {"rm": "広大な凍土", "sp": ["寒地の暮らし", "人口上限 -15%・食料 -10%・ゴールド -10%", {"pop": -0.15, "food": -0.1, "gold": -0.10}]}},
	{"id": "s5", "n": "赤軍の再建", "x": 2, "y": 2, "t": 7, "req": ["s3", "s3b"], "e": {"rm": "大粛清の影", "sp": ["赤軍", "防御 +10%・兵の生産 +5%", {"def": 0.10, "troop": 0.05}]}},
	{"id": "s6", "n": "コミンテルンの指導", "x": 3, "y": 2, "t": 6, "req": ["s3", "s3b"], "e": {"fac": "コミンテルン", "invite": ["鳥取県", "岡山県"]}},
	{"id": "s7", "n": "冬戦争", "x": 1, "y": 3, "t": 6, "req": ["s5"], "e": {"warOn": "青森県"}},
	{"id": "s8", "n": "バルト三国の保護", "x": 2, "y": 3, "t": 6, "req": ["s5"], "e": {"demand": ["岩手県", "宮城県", "山形県"]}},
	{"id": "s9", "n": "世界革命", "x": 3, "y": 3, "t": 7, "req": ["s6"], "ex": ["s10"], "e": {"sp": ["世界革命", "戦争支持 +15", {"ws": 15.0}], "claimOn": ["福島県"]}},
	{"id": "s10", "n": "一国社会主義", "x": 4, "y": 3, "t": 7, "req": ["s6"], "ex": ["s9"], "e": {"sp": ["一国社会主義", "安定度 +10・防御 +5%", {"stab": 10.0, "def": 0.05}], "cf": 2}},
	{"id": "s11", "n": "大祖国の盾", "x": 1, "y": 4, "t": 7, "req": ["s7", "s8"], "e": {"sp": ["祖国の盾", "砦の防御 +20%・防御 +5%", {"fort": 0.20, "def": 0.05}]}},
]
const TREE_UK := [
	{"id": "b1", "n": "帝国国防委員会", "x": 1, "y": 0, "t": 5, "req": [], "e": {"mf": 1}},
	{"id": "b2", "n": "宥和政策", "x": 0, "y": 1, "t": 5, "req": ["b1"], "ex": ["b3"], "e": {"stab": 10, "favor": 10}},
	{"id": "b4", "n": "影の工場", "x": 1, "y": 1, "t": 6, "req": ["b1"], "e": {"mf": 1, "cf": 1}},
	{"id": "b3", "n": "対独強硬", "x": 2, "y": 1, "t": 5, "req": ["b1"], "ex": ["b2"], "e": {"rm": "宥和の空気", "ws": 15}},
	{"id": "b5", "n": "連合国の結成", "x": 0, "y": 2, "t": 6, "req": ["b4"], "e": {"fac": "連合国", "invite": ["神奈川県", "徳島県", "香川県", "愛媛県", "高知県"], "pp": 20}},
	{"id": "b6", "n": "海軍の拡張", "x": 1, "y": 2, "t": 7, "req": ["b4"], "e": {"sp": ["ロイヤル・ネイビー", "防御 +8%", {"def": 0.08}]}},
	{"id": "b7", "n": "ポーランドへの保証", "x": 2, "y": 2, "t": 5, "req": ["b3"], "e": {"guar": ["福島県", "富山県", "福井県"]}},
	{"id": "b8", "n": "民主主義の工場", "x": 1, "y": 3, "t": 7, "req": ["b5", "b6"], "e": {"mf": 2, "ws": 10}},
	{"id": "b9", "n": "決して降伏しない", "x": 2, "y": 3, "t": 6, "req": ["b7"], "e": {"sp": ["不屈", "防御 +10%・安定度 +10", {"def": 0.10, "stab": 10.0}]}},
]
const TREE_FRA := [
	{"id": "f1", "n": "人民戦線の行方", "x": 1, "y": 0, "t": 5, "req": [], "e": {"pp": 10}},
	{"id": "f2", "n": "人民戦線政府", "x": 0, "y": 1, "t": 6, "req": ["f1"], "ex": ["f3"], "e": {"ideo": ["communism", 20], "cf": 2}},
	{"id": "f4", "n": "マジノ線の延長", "x": 1, "y": 1, "t": 7, "req": ["f1"], "e": {"sp": ["マジノ線の延長", "砦の防御 +15%", {"fort": 0.15}]}},
	{"id": "f3", "n": "国民連合", "x": 2, "y": 1, "t": 6, "req": ["f1"], "ex": ["f2"], "e": {"rm": "政治の混迷", "stab": 10}},
	{"id": "f5", "n": "英仏協商", "x": 0, "y": 2, "t": 5, "req": ["f2", "f3"], "e": {"joinFac": "連合国"}},
	{"id": "f6", "n": "軍需の国有化", "x": 1, "y": 2, "t": 6, "req": ["f4"], "e": {"mf": 2}},
	{"id": "f7", "n": "小協商の再建", "x": 2, "y": 2, "t": 6, "req": ["f3"], "e": {"guar": ["栃木県", "静岡県"], "favor": 10}},
	{"id": "f8", "n": "共和国の防衛", "x": 1, "y": 3, "t": 6, "req": ["f5", "f6"], "e": {"sp": ["共和国の防衛", "防御 +8%・戦争支持 +10", {"def": 0.08, "ws": 10.0}]}},
]
const TREE_ITA := [
	{"id": "i1", "n": "新ローマ帝国", "x": 1, "y": 0, "t": 5, "req": [], "e": {"ws": 10, "ideo": ["fascism", 10]}},
	{"id": "i2", "n": "アルバニア保護", "x": 0, "y": 1, "t": 5, "req": ["i1"], "e": {"demand": ["三重県"]}},
	{"id": "i4", "n": "鋼鉄協約", "x": 1, "y": 1, "t": 5, "req": ["i1"], "ex": ["i8"], "e": {"joinFac": "枢軸"}},
	{"id": "i3", "n": "工業の振興", "x": 2, "y": 1, "t": 6, "req": ["i1"], "e": {"rm": "貧弱な工業", "mf": 1, "cf": 1}},
	{"id": "i5", "n": "われらの海", "x": 0, "y": 2, "t": 6, "req": ["i2"], "e": {"claimOn": ["福井県", "静岡県"], "ws": 10}},
	{"id": "i6", "n": "エチオピア征服", "x": 2, "y": 2, "t": 7, "req": ["i3"], "e": {"claimOn": ["宮崎県"], "sp": ["帝国の兵", "攻撃 +5%", {"atk": 0.05}]}},
	{"id": "i7", "n": "バルカンへの進出", "x": 0, "y": 3, "t": 6, "req": ["i5"], "e": {"warOn": "静岡県"}},
	{"id": "i8", "n": "王党派の復権", "x": 2, "y": 3, "t": 6, "req": ["i6"], "ex": ["i4"], "e": {"gov": "neutral", "rm": "ローマの夢", "stab": 15}},
]
const TREE_USA := [
	{"id": "a1", "n": "ニューディール", "x": 1, "y": 0, "t": 5, "req": [], "e": {"cf": 2}},
	{"id": "a2", "n": "大恐慌の克服", "x": 0, "y": 1, "t": 6, "req": ["a1"], "e": {"rm": "大恐慌", "cf": 1}},
	{"id": "a3", "n": "中立法の見直し", "x": 2, "y": 1, "t": 6, "req": ["a1"], "e": {"ws": 10}},
	{"id": "a4", "n": "民主主義の兵器廠", "x": 1, "y": 2, "t": 7, "req": ["a2", "a3"], "e": {"mf": 3}},
	{"id": "a5", "n": "武器貸与法", "x": 2, "y": 2, "t": 6, "req": ["a3"], "e": {"rm": "孤立主義", "favor": 15}},
	{"id": "a7", "n": "アメリカ第一", "x": 0, "y": 3, "t": 6, "req": ["a2"], "ex": ["a6"], "e": {"sp": ["アメリカ第一", "安定度 +10・ゴールド +10%", {"stab": 10.0, "gold": 0.10}]}},
	{"id": "a8", "n": "合衆国の産業力", "x": 1, "y": 3, "t": 7, "req": ["a4"], "e": {"sp": ["大量生産", "軍需工場の出力 +20%・民需工場の出力 +10%", {"mf": 0.20, "cf": 0.10}]}},
	{"id": "a6", "n": "連合国への参加", "x": 2, "y": 3, "t": 6, "req": ["a5"], "ex": ["a7"], "e": {"joinFac": "連合国", "ws": 15}},
]
const TREE_JPN := [
	{"id": "j1", "n": "軍部の台頭", "x": 1, "y": 0, "t": 5, "req": [], "e": {"ideo": ["fascism", 20], "ws": 10}},
	{"id": "j2", "n": "統制派の勝利", "w": 2.5, "x": 0, "y": 1, "t": 6, "req": ["j1"], "ex": ["j3"], "e": {"gov": "fascism", "stab": 10}},
	{"id": "j3", "n": "協調外交", "x": 2, "y": 1, "t": 6, "req": ["j1"], "ex": ["j2"], "e": {"ideo": ["democracy", 25], "rm": "軍部の専横", "stab": 10}},
	{"id": "j4", "n": "日独防共協定", "x": 0, "y": 2, "t": 5, "req": ["j2"], "e": {"joinFac": "枢軸"}},
	{"id": "j5", "n": "大陸進出", "x": 1, "y": 2, "t": 6, "req": ["j2"], "e": {"claimOn": ["島根県", "広島県"], "ws": 10}},
	{"id": "j9", "n": "民政の安定", "x": 2, "y": 2, "t": 6, "req": ["j3"], "e": {"cf": 2, "sp": ["民政", "ゴールド +10%", {"gold": 0.10}]}},
	{"id": "j7", "n": "南方進出", "x": 0, "y": 3, "t": 7, "req": ["j4"], "e": {"claimOn": ["長崎県", "佐賀県"]}},
	{"id": "j6", "n": "満洲の開発", "x": 1, "y": 3, "t": 6, "req": ["j5"], "e": {"demand": ["島根県"], "mf": 1}},
	{"id": "j8", "n": "国家総動員法", "x": 1, "y": 4, "t": 7, "req": ["j6"], "e": {"sp": ["国家総動員", "兵の生産 +15%・軍需工場の出力 +10%", {"troop": 0.15, "mf": 0.10}]}},
]
const TREE_CHN := [
	{"id": "c1", "n": "国家統一", "x": 1, "y": 0, "t": 5, "req": [], "e": {"pp": 15}},
	{"id": "c2", "n": "国共合作", "x": 0, "y": 1, "t": 6, "req": ["c1"], "ex": ["c3"], "e": {"favor": 20, "ideo": ["communism", 10], "sp": ["抗日統一戦線", "防御 +10%", {"def": 0.10}]}},
	{"id": "c4", "n": "軍閥の統合", "x": 1, "y": 1, "t": 6, "req": ["c1"], "e": {"demand": ["山口県"], "rm": "軍閥の割拠"}},
	{"id": "c3", "n": "剿共", "x": 2, "y": 1, "t": 6, "req": ["c1"], "ex": ["c2"], "e": {"claimOn": ["岡山県"], "ws": 10}},
	{"id": "c6", "n": "持久戦", "x": 0, "y": 2, "t": 6, "req": ["c2"], "e": {"sp": ["持久戦", "砦の防御 +20%", {"fort": 0.20}]}},
	{"id": "c5", "n": "軍事顧問団の招聘", "x": 1, "y": 2, "t": 7, "req": ["c4"], "e": {"sp": ["近代化された師団", "攻撃 +5%・防御 +5%", {"atk": 0.05, "def": 0.05}], "mf": 1}},
	{"id": "c7", "n": "連合国への接近", "x": 2, "y": 2, "t": 6, "req": ["c5"], "e": {"joinFac": "連合国"}},
]
const TREE_SPA := [
	{"id": "e1", "n": "内戦の行方", "x": 1, "y": 0, "t": 4, "req": [], "e": {"ws": 10}},
	{"id": "e2", "n": "共和派の勝利", "x": 0, "y": 1, "t": 14, "req": ["e1"], "ex": ["e3", "e4"], "e": {"rm": "内戦", "stab": 10, "ideo": ["democracy", 25]}},
	{"id": "e3", "n": "国民派の勝利", "w": 2.0, "x": 1, "y": 1, "t": 14, "req": ["e1"], "ex": ["e2", "e4"], "e": {"rm": "内戦", "gov": "fascism"}},
	{"id": "e4", "n": "人民の戦い", "x": 2, "y": 1, "t": 14, "req": ["e1"], "ex": ["e2", "e3"], "e": {"rm": "内戦", "gov": "communism"}},
	{"id": "e6", "n": "戦後の復興", "x": 0, "y": 2, "t": 6, "req": ["e2", "e4"], "e": {"cf": 2, "mf": 1}},
	{"id": "e5", "n": "イベリアの統一", "x": 1, "y": 2, "t": 6, "req": ["e3"], "e": {"claimOn": ["滋賀県"], "joinFac": "枢軸"}},
]

## 県ごとの見立て：r=国 ideo=最初の政権 pop=思想の支持（与党以外） stab=安定度の補正 sp=最初の国民精神
## tree=大国の固有ツリー／chain=3段の固有方針 fin=最後の2択
const COUNTRY := {
	"北海道": {"r": "ソ連", "ideo": "communism", "pop": {"fascism": 3, "democracy": 5, "neutral": 7}, "tree": TREE_SOV,
		"sp": [["広大な凍土", "人口上限 -20%・食料 -25%・兵の生産 -10%・ゴールド -15%", {"pop": -0.2, "food": -0.25, "troop": -0.1, "gold": -0.15}], ["大粛清の影", "攻撃 -10%・安定度 -10", {"atk": -0.10, "stab": -10.0}]]},
	"群馬県": {"r": "ドイツ", "ideo": "democracy", "pop": {"fascism": 42, "communism": 12, "neutral": 8}, "stab": -12, "boost": {"dev": 1, "stock": 3.0}, "tree": TREE_GER,
		"sp": [["列強", "ゴールド +15%・兵の生産 +15%・軍需工場の出力 +10%・兵の上限 +25%", {"gold": 0.15, "troop": 0.15, "mf": 0.10, "cap": 0.25}], ["プロイセンの伝統", "攻撃 +25%・防御 +15%", {"atk": 0.25, "def": 0.15}], ["工業大国", "軍需工場の出力 +20%・民需工場の出力 +10%・ゴールド +10%・人造石油", {"mf": 0.20, "cf": 0.10, "gold": 0.10, "synth": 0.40}], ["ヴェルサイユの軛", "兵の生産 -15%・軍需工場の出力 -10%", {"troop": -0.15, "mf": -0.10}], ["恐慌の傷跡", "安定度 -5・ゴールド -5%", {"stab": -5.0, "gold": -0.05}]]},
	"東京都": {"r": "イギリス", "ideo": "democracy", "pop": {"fascism": 4, "communism": 6, "neutral": 10}, "tree": TREE_UK,
		"sp": [["列強", "ゴールド +15%・兵の生産 +15%・軍需工場の出力 +10%・兵の上限 +25%", {"gold": 0.15, "troop": 0.15, "mf": 0.10, "cap": 0.25}], ["大英帝国", "ゴールド +10%", {"gold": 0.10}], ["宥和の空気", "戦争支持 -10", {"ws": -10.0}]]},
	"長野県": {"r": "フランス", "ideo": "democracy", "pop": {"fascism": 8, "communism": 18, "neutral": 8}, "tree": TREE_FRA,
		"sp": [["列強", "ゴールド +15%・兵の生産 +15%・軍需工場の出力 +10%・兵の上限 +25%", {"gold": 0.15, "troop": 0.15, "mf": 0.10, "cap": 0.25}], ["政治の混迷", "安定度 -10", {"stab": -10.0}], ["マジノ線", "砦の防御 +20%", {"fort": 0.20}]]},
	"愛知県": {"r": "イタリア", "ideo": "fascism", "pop": {"democracy": 6, "communism": 6, "neutral": 15}, "tree": TREE_ITA,
		"sp": [["列強", "ゴールド +15%・兵の生産 +15%・軍需工場の出力 +10%・兵の上限 +25%", {"gold": 0.15, "troop": 0.15, "mf": 0.10, "cap": 0.25}], ["ローマの夢", "戦争支持 +10", {"ws": 10.0}], ["貧弱な工業", "軍需工場の出力 -15%", {"mf": -0.15}]]},
	"大阪府": {"r": "アメリカ", "ideo": "democracy", "pop": {"fascism": 4, "communism": 4, "neutral": 6}, "tree": TREE_USA,
		"sp": [["列強", "ゴールド +15%・兵の生産 +15%・軍需工場の出力 +10%・兵の上限 +25%", {"gold": 0.15, "troop": 0.15, "mf": 0.10, "cap": 0.25}], ["孤立主義", "戦争支持 -20", {"ws": -20.0}], ["大恐慌", "ゴールド -15%・安定度 -10", {"gold": -0.15, "stab": -10.0}]]},
	"福岡県": {"r": "日本", "ideo": "neutral", "pop": {"fascism": 35, "democracy": 12, "communism": 3}, "tree": TREE_JPN,
		"sp": [["列強", "ゴールド +15%・兵の生産 +15%・軍需工場の出力 +10%・兵の上限 +25%", {"gold": 0.15, "troop": 0.15, "mf": 0.10, "cap": 0.25}], ["軍部の専横", "戦争支持 +10・安定度 -5", {"ws": 10.0, "stab": -5.0}]]},
	"広島県": {"r": "中華民国", "ideo": "neutral", "pop": {"communism": 18, "democracy": 10, "fascism": 6}, "tree": TREE_CHN,
		"sp": [["軍閥の割拠", "安定度 -10・ゴールド -10%", {"stab": -10.0, "gold": -0.10}]]},
	"京都府": {"r": "スペイン", "ideo": "democracy", "pop": {"fascism": 28, "communism": 24, "neutral": 6}, "stab": -10, "tree": TREE_SPA,
		"sp": [["内戦", "安定度 -20・ゴールド -20%・兵の生産 -10%", {"stab": -20.0, "gold": -0.20, "troop": -0.10}]]},
	"青森県": {"r": "フィンランド", "ideo": "democracy", "pop": {"fascism": 8, "neutral": 10}, "sp": [["シス（不屈）", "防御 +10%", {"def": 0.10}]],
		"chain": [["マンネルヘイム線", {"sp": ["マンネルヘイム線", "砦の防御 +20%", {"fort": 0.20}]}], ["白衛軍の伝統", {"ws": 10}], ["北欧との協調", {"favor": 15}]],
		"fin": [["連合国への接近", {"joinFac": "連合国"}], ["継続戦争の備え", {"joinFac": "枢軸", "claimOn": ["北海道"]}]]},
	"秋田県": {"r": "スウェーデン", "ideo": "democracy", "pop": {"neutral": 8, "communism": 5}, "sp": [["武装中立", "防御 +5%・ゴールド +5%", {"def": 0.05, "gold": 0.05}]],
		"chain": [["鉄鉱石の輸出", {"cf": 1, "gold": 3000}], ["ボフォースの工場", {"mf": 1}], ["北欧防衛同盟", {"favor": 15}]],
		"fin": [["永世の中立", {"sp": ["中立の伝統", "安定度 +10", {"stab": 10.0}]}], ["北欧の盾", {"fac": "北欧同盟", "invite": ["青森県", "茨城県"]}]]},
	"岩手県": {"r": "エストニア", "ideo": "neutral", "pop": {"democracy": 15, "communism": 8}, "sp": [["小国の悲哀", "戦争支持 -10", {"ws": -10.0}]],
		"chain": [["国防同盟", {"sp": ["国防同盟", "防御 +5%", {"def": 0.05}]}], ["バルト協商", {"favor": 20}], ["港湾の整備", {"cf": 1}]],
		"fin": [["ソ連への接近", {"ideo": ["communism", 25]}], ["フィンランドとの連帯", {"joinFac": "連合国"}]]},
	"宮城県": {"r": "ラトビア", "ideo": "neutral", "pop": {"democracy": 12, "communism": 8}, "sp": [["権威主義の安定", "安定度 +10", {"stab": 10.0}]],
		"chain": [["体制の固め", {"stab": 10}], ["農業の近代化", {"sp": ["農業の近代化", "食料 +10%", {"food": 0.10}]}], ["リガの港", {"cf": 1}]],
		"fin": [["バルト協商の強化", {"sp": ["バルト協商", "防御 +8%", {"def": 0.08}]}], ["ドイツへの接近", {"ideo": ["fascism", 25]}]]},
	"山形県": {"r": "リトアニア", "ideo": "neutral", "pop": {"democracy": 12, "fascism": 8}, "sp": [["ヴィリニュス問題", "戦争支持 +5", {"ws": 5.0}]],
		"chain": [["国境の防備", {"sp": ["国境の防備", "砦の防御 +15%", {"fort": 0.15}]}], ["農業協同組合", {"sp": ["協同組合", "人口の伸び +10%", {"grow": 0.10}]}], ["バルトの連帯", {"favor": 15}]],
		"fin": [["ヴィリニュス奪還", {"claimOn": ["福島県"], "ws": 15}], ["中立の宣言", {"stab": 15}]]},
	"福島県": {"r": "ポーランド", "ideo": "neutral", "pop": {"democracy": 15, "fascism": 8, "communism": 5}, "sp": [["二大国の狭間", "戦争支持 +10・安定度 -5", {"ws": 10.0, "stab": -5.0}]],
		"chain": [["中央工業地域", {"mf": 1, "cf": 1}], ["ルーマニアとの同盟", {"favor": 15}], ["騎兵の伝統", {"sp": ["ウーラン騎兵", "攻撃 +5%", {"atk": 0.05}]}]],
		"fin": [["インテルマリウム", {"fac": "インテルマリウム", "invite": ["山形県", "宮城県", "岩手県", "富山県"]}], ["連合国への加盟", {"joinFac": "連合国"}]]},
	"茨城県": {"r": "デンマーク", "ideo": "democracy", "pop": {"fascism": 5, "neutral": 6}, "sp": [["非武装の伝統", "兵の生産 -10%・ゴールド +10%", {"troop": -0.10, "gold": 0.10}]],
		"chain": [["酪農の国", {"sp": ["酪農の国", "食料 +15%", {"food": 0.15}]}], ["コペンハーゲンの港", {"cf": 1}], ["国防の見直し", {"rm": "非武装の伝統"}]],
		"fin": [["北欧の協調", {"favor": 15, "stab": 10}], ["連合国への加盟", {"joinFac": "連合国"}]]},
	"栃木県": {"r": "チェコスロバキア", "ideo": "democracy", "pop": {"fascism": 10, "communism": 10, "neutral": 8}, "sp": [["シュコダ工場", "軍需工場の出力 +20%", {"mf": 0.20}]],
		"chain": [["国境要塞群", {"sp": ["国境要塞群", "砦の防御 +25%", {"fort": 0.25}]}], ["小協商", {"favor": 15}], ["兵器の輸出", {"mf": 1, "gold": 3000}]],
		"fin": [["徹底抗戦", {"sp": ["徹底抗戦", "防御 +10%", {"def": 0.10}], "ws": 15}], ["スロバキアの自治", {"stab": 10, "ideo": ["neutral", 20]}]]},
	"埼玉県": {"r": "ベルギー", "ideo": "democracy", "pop": {"fascism": 8, "neutral": 8}, "sp": [["中立の誓い", "戦争支持 -10", {"ws": -10.0}]],
		"chain": [["運河の要塞", {"sp": ["運河の要塞", "砦の防御 +20%", {"fort": 0.20}]}], ["コンゴの資源", {"gold": 4000, "cf": 1}], ["再武装", {"mf": 1, "rm": "中立の誓い"}]],
		"fin": [["フランスとの同盟", {"joinFac": "連合国"}], ["厳正中立", {"stab": 15}]]},
	"千葉県": {"r": "オランダ", "ideo": "democracy", "pop": {"fascism": 5, "neutral": 6}, "sp": [["東インドの富", "ゴールド +10%", {"gold": 0.10}]],
		"chain": [["水の防衛線", {"sp": ["水の防衛線", "砦の防御 +20%・防御 +5%", {"fort": 0.20, "def": 0.05}]}], ["電機の工場", {"cf": 1}], ["海運の国", {"gold": 4000}]],
		"fin": [["東インドの防衛", {"guar": ["長崎県"]}], ["連合国への加盟", {"joinFac": "連合国"}]]},
	"神奈川県": {"r": "カナダ", "ideo": "democracy", "pop": {"neutral": 5, "communism": 4}, "sp": [["自治領", "戦争支持 -5", {"ws": -5.0}]],
		"chain": [["穀倉地帯", {"sp": ["穀倉地帯", "食料 +10%", {"food": 0.10}]}], ["工業の動員", {"mf": 1, "cf": 1}], ["英連邦への忠誠", {"joinFac": "連合国"}]],
		"fin": [["大西洋の橋", {"sp": ["大西洋の橋", "ゴールド +5%・軍需工場の出力 +10%", {"gold": 0.05, "mf": 0.10}]}], ["独自の外交", {"stab": 10, "favor": 10}]]},
	"新潟県": {"r": "オーストリア", "ideo": "neutral", "pop": {"fascism": 25, "democracy": 10, "communism": 6}, "sp": [["祖国戦線", "安定度 -5", {"stab": -5.0}]],
		"chain": [["オーストリアの独立", {"stab": 10}], ["イタリアとの友好", {"favor": 15}], ["帝国の記憶", {"ideo": ["neutral", 15]}]],
		"fin": [["合邦への道", {"ideo": ["fascism", 30]}], ["独立の堅持", {"sp": ["独立の堅持", "防御 +8%", {"def": 0.08}], "ws": 10}]]},
	"富山県": {"r": "ルーマニア", "ideo": "neutral", "pop": {"fascism": 15, "democracy": 10}, "sp": [["石油の国", "ゴールド +10%", {"gold": 0.10}]],
		"chain": [["油田の開発", {"cf": 1, "gold": 3000}], ["鉄衛団の台頭", {"ideo": ["fascism", 20]}], ["国境の要塞", {"sp": ["国境の要塞線", "砦の防御 +15%", {"fort": 0.15}]}]],
		"fin": [["枢軸への加盟", {"joinFac": "枢軸"}], ["小協商の維持", {"favor": 15, "stab": 10}]]},
	"石川県": {"r": "ブルガリア", "ideo": "neutral", "pop": {"fascism": 12, "communism": 10}, "sp": [["失地回復", "戦争支持 +10", {"ws": 10.0}]],
		"chain": [["皇帝の権威", {"stab": 10}], ["失地の主張", {"claimOn": ["福井県"]}], ["農業の振興", {"sp": ["農業の振興", "食料 +10%", {"food": 0.10}]}]],
		"fin": [["枢軸への加盟", {"joinFac": "枢軸"}], ["中立の維持", {"stab": 10}]]},
	"福井県": {"r": "ギリシャ", "ideo": "neutral", "pop": {"democracy": 15, "communism": 6}, "sp": [["八月四日体制", "安定度 +5・戦争支持 +5", {"stab": 5.0, "ws": 5.0}]],
		"chain": [["要塞線の建設", {"sp": ["要塞線", "砦の防御 +20%", {"fort": 0.20}]}], ["海運の国", {"gold": 3000, "cf": 1}], ["イギリスとの友好", {"favor": 15}]],
		"fin": [["連合国への加盟", {"joinFac": "連合国"}], ["山岳の抵抗", {"sp": ["山岳の抵抗", "防御 +10%", {"def": 0.10}]}]]},
	"山梨県": {"r": "スイス", "ideo": "democracy", "pop": {"neutral": 6}, "sp": [["武装中立", "防御 +10%・砦の防御 +15%", {"def": 0.10, "fort": 0.15}]],
		"chain": [["銀行の国", {"sp": ["銀行の国", "ゴールド +15%", {"gold": 0.15}]}], ["国民皆兵", {"sp": ["国民皆兵", "兵の生産 +10%", {"troop": 0.10}]}], ["アルプスの要塞", {"sp": ["アルプスの要塞", "砦の防御 +20%", {"fort": 0.20}]}]],
		"fin": [["永世中立", {"stab": 20}], ["精密工業", {"mf": 1, "cf": 1}]]},
	"岐阜県": {"r": "ハンガリー", "ideo": "neutral", "pop": {"fascism": 18, "democracy": 8}, "sp": [["トリアノンの傷", "戦争支持 +10", {"ws": 10.0}]],
		"chain": [["失地回復運動", {"claimOn": ["富山県"]}], ["軍備制限の撤廃", {"mf": 1}], ["矢十字党の台頭", {"ideo": ["fascism", 20]}]],
		"fin": [["枢軸への加盟", {"joinFac": "枢軸"}], ["摂政の中立", {"stab": 15}]]},
	"静岡県": {"r": "ユーゴスラビア", "ideo": "neutral", "pop": {"communism": 12, "democracy": 10, "fascism": 6}, "sp": [["民族の対立", "安定度 -10", {"stab": -10.0}]],
		"chain": [["王国の統一", {"stab": 10}], ["鉱山の開発", {"cf": 1, "mf": 1}], ["小協商", {"favor": 15}]],
		"fin": [["枢軸への接近", {"joinFac": "枢軸"}], ["パルチザンの伝統", {"sp": ["パルチザン", "防御 +10%", {"def": 0.10}]}]]},
	"三重県": {"r": "アルバニア", "ideo": "neutral", "pop": {"fascism": 8, "democracy": 6}, "sp": [["山岳の小国", "防御 +10%", {"def": 0.10}]],
		"chain": [["王国の近代化", {"cf": 1}], ["イタリアへの依存", {"favor": 20}], ["山の民兵", {"sp": ["山の民兵", "兵の生産 +10%", {"troop": 0.10}]}]],
		"fin": [["独立の維持", {"sp": ["独立の維持", "防御 +10%", {"def": 0.10}]}], ["バルカンの夢", {"claimOn": ["福井県"]}]]},
	"滋賀県": {"r": "ポルトガル", "ideo": "neutral", "pop": {"democracy": 8, "fascism": 10}, "sp": [["新国家体制", "安定度 +10", {"stab": 10.0}]],
		"chain": [["植民地の富", {"gold": 4000}], ["イギリスとの古い同盟", {"favor": 15}], ["大西洋の島々", {"cf": 1}]],
		"fin": [["中立の堅持", {"stab": 10}], ["イベリア協定", {"favor": 15, "sp": ["イベリア協定", "防御 +5%", {"def": 0.05}]}]]},
	"奈良県": {"r": "アイルランド", "ideo": "democracy", "pop": {"neutral": 8, "fascism": 5}, "sp": [["自由国", "戦争支持 -10", {"ws": -10.0}]],
		"chain": [["新憲法", {"stab": 10}], ["経済戦争の終結", {"cf": 1}], ["国防軍の拡張", {"mf": 1}]],
		"fin": [["厳正中立", {"stab": 15}], ["連合国への加盟", {"joinFac": "連合国"}]]},
	"兵庫県": {"r": "メキシコ", "ideo": "neutral", "pop": {"communism": 12, "democracy": 10}, "sp": [["革命の遺産", "人口の伸び +5%", {"grow": 0.05}]],
		"chain": [["石油の国有化", {"gold": 4000, "cf": 1}], ["農地改革", {"sp": ["農地改革", "食料 +10%", {"food": 0.10}]}], ["社会主義教育", {"ideo": ["communism", 15]}]],
		"fin": [["連合国への加盟", {"joinFac": "連合国"}], ["ラテンアメリカの盟主", {"sp": ["ラテンの盟主", "ゴールド +10%", {"gold": 0.10}]}]]},
	"和歌山県": {"r": "ブラジル", "ideo": "neutral", "pop": {"fascism": 12, "democracy": 8}, "sp": [["新国家", "安定度 +5", {"stab": 5.0}]],
		"chain": [["コーヒーの国", {"gold": 4000}], ["鉄鋼の国産化", {"mf": 1, "cf": 1}], ["統合主義", {"ideo": ["fascism", 15]}]],
		"fin": [["連合国への加盟", {"joinFac": "連合国"}], ["南米の大国", {"sp": ["南米の大国", "兵の生産 +10%", {"troop": 0.10}]}]]},
	"鳥取県": {"r": "モンゴル", "ideo": "communism", "pop": {"neutral": 10}, "sp": [["草原の騎兵", "攻撃 +5%", {"atk": 0.05}]],
		"chain": [["ソ連との相互援助", {"favor": 20}], ["騎兵の近代化", {"sp": ["騎兵の近代化", "攻撃 +5%", {"atk": 0.05}]}], ["牧畜の振興", {"sp": ["牧畜", "食料 +10%", {"food": 0.10}]}]],
		"fin": [["コミンテルンへの加盟", {"joinFac": "コミンテルン"}], ["草原の独立", {"stab": 10}]]},
	"島根県": {"r": "満洲国", "ideo": "neutral", "pop": {"fascism": 15, "communism": 8}, "sp": [["傀儡の国", "安定度 -10", {"stab": -10.0}]],
		"chain": [["工業化", {"mf": 1, "cf": 1}], ["鉄道の整備", {"infra": 3}], ["国家の体裁", {"stab": 10}]],
		"fin": [["日本への従属", {"joinFac": "枢軸"}], ["自主独立", {"stab": 10, "ws": 10}]]},
	"岡山県": {"r": "中国共産党", "ideo": "communism", "pop": {"neutral": 10, "democracy": 5}, "sp": [["長征の記憶", "防御 +5%・戦争支持 +10", {"def": 0.05, "ws": 10.0}]],
		"chain": [["延安の根拠地", {"cf": 1}], ["ゲリラ戦術", {"sp": ["ゲリラ戦術", "防御 +10%", {"def": 0.10}]}], ["人民の軍", {"sp": ["人民の軍", "兵の生産 +10%", {"troop": 0.10}]}]],
		"fin": [["国共合作", {"favor": 20, "stab": 10}], ["コミンテルンへの加盟", {"joinFac": "コミンテルン"}]]},
	"山口県": {"r": "雲南（軍閥）", "ideo": "neutral", "pop": {"communism": 8, "democracy": 6}, "sp": [["軍閥", "安定度 -10", {"stab": -10.0}]],
		"chain": [["雲南の鉱山", {"cf": 1, "gold": 3000}], ["滇緬公路", {"infra": 2}], ["講武堂", {"sp": ["講武堂", "攻撃 +5%", {"atk": 0.05}]}]],
		"fin": [["国民政府への合流", {"stab": 10, "favor": 20}], ["独立軍閥", {"sp": ["独立軍閥", "防御 +10%", {"def": 0.10}]}]]},
	"徳島県": {"r": "南アフリカ", "ideo": "democracy", "pop": {"neutral": 10, "fascism": 8}, "sp": [["金の国", "ゴールド +15%", {"gold": 0.15}]],
		"chain": [["金鉱の開発", {"gold": 4000}], ["英連邦への忠誠", {"joinFac": "連合国"}], ["工業の拡張", {"mf": 1}]],
		"fin": [["大陸の盾", {"sp": ["大陸の盾", "防御 +5%", {"def": 0.05}]}], ["国民党の台頭", {"ideo": ["neutral", 20]}]]},
	"香川県": {"r": "ニュージーランド", "ideo": "democracy", "pop": {"neutral": 5}, "sp": [["遠い自治領", "戦争支持 -10", {"ws": -10.0}]],
		"chain": [["酪農の輸出", {"sp": ["酪農の輸出", "食料 +10%", {"food": 0.10}]}], ["英連邦への忠誠", {"joinFac": "連合国"}], ["遠征軍の編成", {"mf": 1}]],
		"fin": [["太平洋の防衛", {"sp": ["太平洋の防衛", "防御 +5%", {"def": 0.05}]}], ["社会保障の充実", {"stab": 15}]]},
	"愛媛県": {"r": "オーストラリア", "ideo": "democracy", "pop": {"neutral": 6}, "sp": [["広大な大陸", "ゴールド +5%", {"gold": 0.05}]],
		"chain": [["鉱山の開発", {"cf": 1}], ["英連邦への忠誠", {"joinFac": "連合国"}], ["陸軍の拡張", {"mf": 1}]],
		"fin": [["太平洋の守り", {"sp": ["太平洋の守り", "防御 +5%", {"def": 0.05}], "ws": 10}], ["独自の外交", {"stab": 10}]]},
	"高知県": {"r": "インド", "ideo": "democracy", "pop": {"neutral": 20, "communism": 6}, "sp": [["独立運動", "安定度 -15", {"stab": -15.0}]],
		"chain": [["地方自治の拡大", {"stab": 10}], ["インドの工業", {"mf": 1, "cf": 1}], ["インド軍の拡張", {"sp": ["インド軍", "兵の生産 +10%", {"troop": 0.10}]}]],
		"fin": [["英連邦への協力", {"joinFac": "連合国"}], ["完全独立", {"stab": 10, "ideo": ["neutral", 25]}]]},
	"佐賀県": {"r": "タイ", "ideo": "neutral", "pop": {"fascism": 10, "democracy": 8}, "sp": [["緩衝国", "戦争支持 -5", {"ws": -5.0}]],
		"chain": [["立憲革命の遺産", {"stab": 10}], ["軍の近代化", {"mf": 1}], ["失地の主張", {"claimOn": ["長崎県"]}]],
		"fin": [["日本への接近", {"joinFac": "枢軸"}], ["中立の堅持", {"stab": 10}]]},
	"長崎県": {"r": "蘭印", "ideo": "democracy", "pop": {"neutral": 15, "communism": 5}, "sp": [["植民地の資源", "ゴールド +10%", {"gold": 0.10}]],
		"chain": [["油田の防衛", {"sp": ["油田の防衛", "砦の防御 +15%", {"fort": 0.15}]}], ["現地軍の編成", {"sp": ["現地軍", "兵の生産 +5%", {"troop": 0.05}]}], ["ゴムと錫", {"gold": 4000}]],
		"fin": [["連合国への加盟", {"joinFac": "連合国"}], ["独立の機運", {"ideo": ["neutral", 20], "stab": 5}]]},
	"沖縄県": {"r": "フィリピン", "ideo": "democracy", "pop": {"neutral": 10}, "sp": [["独立準備政府", "戦争支持 -5", {"ws": -5.0}]],
		"chain": [["コモンウェルスの成立", {"stab": 10}], ["国軍の創設", {"mf": 1}], ["島々の防衛", {"sp": ["島々の防衛", "防御 +10%", {"def": 0.10}]}]],
		"fin": [["アメリカとの同盟", {"joinFac": "連合国"}], ["完全独立", {"stab": 10}]]},
	"熊本県": {"r": "トルコ", "ideo": "neutral", "pop": {"democracy": 10, "fascism": 5}, "sp": [["共和国の改革", "安定度 +5", {"stab": 5.0}]],
		"chain": [["海峡の再武装", {"sp": ["海峡の要塞", "砦の防御 +20%", {"fort": 0.20}]}], ["工業化計画", {"mf": 1, "cf": 1}], ["ハタイ問題", {"claimOn": ["宮崎県"]}]],
		"fin": [["中立の堅持", {"stab": 10}], ["連合国への接近", {"joinFac": "連合国"}]]},
	"大分県": {"r": "イラン", "ideo": "neutral", "pop": {"fascism": 8, "communism": 6}, "sp": [["近代化の途上", "ゴールド -5%", {"gold": -0.05}]],
		"chain": [["縦貫鉄道", {"infra": 3}], ["石油の利権", {"gold": 4000, "cf": 1}], ["近代軍の創設", {"mf": 1}]],
		"fin": [["ドイツとの友好", {"ideo": ["fascism", 15]}], ["中立の宣言", {"stab": 10}]]},
	"宮崎県": {"r": "エチオピア", "ideo": "neutral", "pop": {"democracy": 5}, "sp": [["古の帝国", "防御 +10%・軍需工場の出力 -20%", {"def": 0.10, "mf": -0.20}]],
		"chain": [["近代化の試み", {"cf": 1}], ["山岳の要塞", {"sp": ["山岳の要塞", "砦の防御 +20%", {"fort": 0.20}]}], ["皇帝の親衛隊", {"sp": ["親衛隊", "攻撃 +5%", {"atk": 0.05}]}]],
		"fin": [["国際連盟への訴え", {"favor": 20}], ["最後の抵抗", {"sp": ["最後の抵抗", "防御 +10%", {"def": 0.10}], "ws": 15}]]},
	"鹿児島県": {"r": "アルゼンチン", "ideo": "neutral", "pop": {"fascism": 10, "democracy": 10}, "sp": [["汚れた十年", "安定度 -5", {"stab": -5.0}]],
		"chain": [["穀物の輸出", {"gold": 4000}], ["国産工業", {"cf": 1, "mf": 1}], ["軍部の影響", {"ideo": ["fascism", 15]}]],
		"fin": [["南米の雄", {"sp": ["南米の雄", "兵の生産 +10%", {"troop": 0.10}]}], ["中立の堅持", {"stab": 10}]]},
}

## 架空の大陸の国に配る国民精神
const GENERIC_SPIRITS := [
	["肥沃な平野", "食料 +10%", {"food": 0.10}],
	["鉄の山", "軍需工場の出力 +15%", {"mf": 0.15}],
	["商人の国", "ゴールド +10%", {"gold": 0.10}],
	["尚武の気風", "攻撃 +5%", {"atk": 0.05}],
	["堅牢な城砦", "砦の防御 +20%", {"fort": 0.20}],
	["多産の民", "人口の伸び +10%", {"grow": 0.10}],
	["勤勉な職人", "建設費 -10%", {"build": -0.10}],
	["結束した民", "安定度 +10", {"stab": 10.0}],
	["軍国の伝統", "兵の生産 +10%", {"troop": 0.10}],
	["守りの民", "防御 +8%", {"def": 0.08}],
]

## 政体による国名（大国）。ほかの国は共産主義で「〜人民共和国」
const ROLE_NAMES := {
	"群馬県": {"democracy": "ドイツ国", "fascism": "大ドイツ国", "communism": "ドイツ社会主義共和国", "neutral": "ドイツ帝国"},
	"北海道": {"communism": "ソ連", "fascism": "ロシア国", "democracy": "ロシア共和国", "neutral": "ロシア帝国"},
	"東京都": {"democracy": "イギリス", "fascism": "大英連合", "communism": "ブリテン人民共和国", "neutral": "イギリス王国"},
	"長野県": {"democracy": "フランス", "fascism": "フランス国", "communism": "フランス・コミューン", "neutral": "フランス王国"},
	"愛知県": {"fascism": "イタリア帝国", "democracy": "イタリア共和国", "communism": "イタリア人民共和国", "neutral": "イタリア王国"},
	"大阪府": {"democracy": "アメリカ", "fascism": "アメリカ国", "communism": "アメリカ人民共和国", "neutral": "アメリカ合衆国"},
	"福岡県": {"neutral": "日本帝国", "fascism": "大日本帝国", "democracy": "日本国", "communism": "日本人民共和国"},
	"広島県": {"neutral": "中華民国", "communism": "中華人民共和国", "fascism": "中華国民政府", "democracy": "中華連邦"},
	"京都府": {"democracy": "スペイン共和国", "fascism": "スペイン国", "communism": "スペイン人民共和国", "neutral": "スペイン王国"},
}
