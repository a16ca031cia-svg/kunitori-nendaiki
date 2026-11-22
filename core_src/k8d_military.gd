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
var _yRange := []
func _northFrac(t: Dictionary) -> float:
	if _yRange.is_empty() or _yRange[2] != G:
		var lo := INF
		var hi := -INF
		for x in G.terrs:
			lo = min(lo, x.y)
			hi = max(hi, x.y)
		_yRange = [lo, hi, G]
	return 1.0 - (t.y - _yRange[0]) / max(1.0, _yRange[1] - _yRange[0])
func isWinter() -> bool:
	var m: int = (G.turn - 1) % 12 + 1
	return m == 12 or m == 1 or m == 2
func armyUpkeepTurn() -> void:
	var winter := isWinter()
	for na in G.nations:
		if not na.alive: continue
		var attrMul: float = max(0.2, 1.0 + nmod(na.id, "attr"))
		for a in na.armies:
			if a == null or total(a.t) <= 0: continue
			var t := T(a.at)
			var home: bool = t.owner == na.id
			var sup: bool = a.get("sup", true) != false
			# 組織率の回復
			a.org = clamp_f(orgOf(a) + (12.0 if home and sup else (6.0 if sup else 1.0)), 0, 100)
			# 消耗：補給切れ・敵地の山や森や湿地・冬の北国
			var rate := 0.0
			if not sup: rate += 0.03
			if not home and (t.terrain == "mount" or t.terrain == "forest" or t.terrain == "marsh"): rate += 0.01
			if winter and _northFrac(t) > 0.7 and not home: rate += 0.02
			rate *= attrMul
			if rate > 0:
				for k in TK: a.t[k] = int(a.t[k] * (1.0 - rate))
			# 包囲：補給が5ターン続けて切れたら降伏する
			a.cutN = 0 if sup else a.get("cutN", 0) + 1
			if a.cutN >= 5 and not home:
				var lost := total(a.t)
				for k in TK: a.t[k] = 0
				if a.gen != null:
					var g = genOf(na, a.gen)
					if g != null: g.army = null
				na.armies[a.idx] = null
				ARMY_REV += 1
				var msg := "%s の %s が %s で包囲され降伏する（%s人）" % [na.name, a.name, t.name, fmt(lost)]
				logWar(msg, [na.id, t.owner], "war")
				chron(msg, na.id, "war")
				var cap = t.owner
				if cap >= 0 and cap != na.id: addFavor(na.id, cap, -5)

# ---------- 攻勢計画 ----------
## 前線全体でこちらが 1.3 倍以上強ければ「全面攻勢」。前線の守備軍も 1.2 倍以上の所から一斉に攻める
func offensiveCheck(nid: int, frontPow: float, foePow: float) -> void:
	var na := NAT(nid)
	var was: bool = na.get("offensive", false)
	var now: bool = frontPow >= foePow * 1.3 and frontPow > 0
	if was and frontPow < foePow * 1.1: now = false
	elif was: now = true
	na.offensive = now
	if now and not was:
		var msg := "%s が全面攻勢を開始する" % na.name
		if newsworthy([nid]): headline("%s、全面攻勢" % natLabel(nid), "前線の各地で一斉に攻勢へ")
		if concerns([nid]): logMsg(msg, "war")
		chron(msg, nid, "war")

# ---------- 空軍・海軍 ----------
## 空軍力：軍需工場と航空の研究から。戦いでは、制空権を取った側（1.5倍以上）の攻防 +10%
func airPower(nid: int) -> float: return factoryCount(nid)[0] * (1.0 + nmod(nid, "air"))
## 海軍力：海に面した領地と海軍の研究から。海峡を越えて攻める時、制海権が無いと攻撃 -25%
func navyPower(nid: int) -> float: return coastCount(nid) * (1.0 + nmod(nid, "navy"))
func airEdge(a: int, b: int) -> float:
	var x := airPower(a)
	var y := airPower(b)
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
				var cand := []
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
	var r := {"atk": 0.0, "def": 0.0, "chg": 0.0}
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
		var na := NAT(t.owner)
		var rate: float = 2.0 + (1.0 if na.get("ideo") == "fascism" or na.get("ideo") == "communism" else 0.0)
		t.collab = clamp_f(c + rate, 0, 100)
		if c < 30: t.sec = clamp_f(t.sec - 2, 0, 100)
