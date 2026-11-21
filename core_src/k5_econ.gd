# 内政・方針・疲労・開拓・戦争目標・講和（元 6008〜6438）
extends "res://scripts/core/k4_strat.gd"

func bldCount(t: Dictionary, k: String) -> int:
	var n := 0
	for b in t.bld:
		if b == k: n += 1
	return n
func popCap(t: Dictionary) -> int:
	var base: float = (CFG.popCity if t.type == "city" else CFG.popFort) * t.dev + bldCount(t, "house") * CFG.houseCap
	return int(round(base * (1.3 if t.get("trait") == "dense" else 1.0) * terrOf(t).pop))
func popRatio(t: Dictionary) -> float: return clamp_f(t.pop / max(1.0, popCap(t)), 0, 1.2)
func secMul(t: Dictionary) -> float:
	if t.sec >= 90: return 1.05
	if t.sec >= 60: return 1.0
	return clamp_f(0.40 + t.sec / 100.0, 0.40, 1)
func secLabel(v: float) -> String:
	return "安泰" if v >= 80 else ("平穏" if v >= 60 else ("不安" if v >= 40 else ("険悪" if v >= CFG.revoltSec else "暴動寸前")))
func secColor(v: float) -> String: return "#6d9c63" if v >= 60 else ("#d29b3c" if v >= 40 else "#c0504a")
func linkBonus(t: Dictionary) -> float:
	var l := int(clamp_f(t.get("link", 0), 0, 3))
	return CFG.roadBonus[l] + (0.10 if t.get("trait") == "road" and t.get("link", 0) else 0.0)
func foodGain(nid: int) -> int:
	var f := 0.0
	for t in G.terrs:
		if t.owner == nid: f += bldCount(t, "farm") * CFG.farmOut * (1.3 if t.get("trait") == "fertile" else 1.0) * terrOf(t).food
	return int(round(f))
func traitTroop(t: Dictionary, k: String) -> float:
	var m: float = terrOf(t).troop.get(k, 1.0)
	if t.get("trait") == "iron" and (k == "inf" or k == "spe"): m *= 1.2
	if t.get("trait") == "horse" and k == "cav": m *= 1.3
	return m
func contig(t: Dictionary, nid: int) -> int:
	var n := 0
	for nb in roadNbrs(t.id):
		if T(nb.to).owner == nid: n += 1
	return n
func reconnect(t: Dictionary, nid: int) -> int:
	var n := 0
	for nb in roadNbrs(t.id):
		var o := T(nb.to)
		if o.owner == nid and not o.get("link", 0): n += 1
	return n
func foeNbrs(t: Dictionary, nid: int) -> int:
	var n := 0
	for nb in roadNbrs(t.id):
		var o: int = T(nb.to).owner
		if o != nid and atWar(nid, o): n += 1
	return n
func _natPop(nid: int) -> float:
	var pop := 0.0
	for t in G.terrs:
		if t.owner == nid: pop += t.pop
	return pop
func stockCap(nid: int) -> int: return int(round(_natPop(nid) * CFG.stockCapPop))
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
	var na := NAT(nid)
	if not POLICY.has(key) or na.policy == key: return false
	if polLeft(na) > 0: return false
	na.policy = key
	na.policyAt = G.turn
	var msg := "%s が方針を「%s」に定める" % [na.name, POLICY[key].n]
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
	var na := NAT(nid)
	na.fatigue = clamp_f(na.get("fatigue", 0) + v, 0, 100)

# ---------- 領地の毎ターン更新 ----------
func updateTerr(t: Dictionary, na: Dictionary, war: bool) -> void:
	var starve := isStarving(na)
	var d: float = CFG.secRecover + bldCount(t, "gov") * CFG.secGov + polAdd(na, "sec")
	if t.chaos > 0: d += CFG.secChaos
	if war: d += CFG.secWar
	if starve: d += CFG.secStarve
	t.sec = clamp_f(round(t.sec + d), 0, 100)
	var cap := popCap(t)
	if starve: t.pop = int(round(t.pop * 0.97))
	elif t.chaos <= 0:
		var rate := clamp_f(CFG.popGrow * (1 + bldCount(t, "house") * 0.5) * (t.sec / 70.0) * polMul(na, "grow"), 0, 0.4)
		t.pop = int(round(t.pop + (cap - t.pop) * rate))
	if t.pop > cap: t.pop = int(round(t.pop - (t.pop - cap) * 0.25))
	t.pop = max(200, t.pop)
	if t.sec < CFG.revoltSec and randf() < CFG.revoltRate: revolt(t, na)
func revolt(t: Dictionary, na: Dictionary) -> void:
	t.sec = clamp_f(t.sec + 30, 0, 100)
	t.pop = int(round(t.pop * 0.9))
	t.chaos = max(t.chaos, 2)
	var msg := "%s で反乱 — 人口が減り、2ターン混乱" % t.name
	logMsg("【反乱】" + msg, "war")
	chron(msg, na.id, "event")

# ---------- 開拓 ----------
func settleCost(nid: int) -> int:
	var n := 0
	for t in G.terrs:
		if t.owner == nid: n += 1
	return int(round(FRONT.settleGold + n * FRONT.settleGrow))
func settlingOf(nid: int) -> Array:
	var r := []
	for t in G.terrs:
		if t.get("settle") != null and t.settle.by == nid: r.append(t)
	return r
func _nextToOwn(tid: int, nid: int) -> bool:
	for nb in roadNbrs(tid):
		if T(nb.to).owner == nid: return true
	return false
func settleReason(nid: int, tid: int) -> String:
	var t := T(tid)
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
		var na := NAT(st.by)
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
		var msg := "%s が %s を開拓" % [na.name, t.name]
		logMsg(msg)
		chron(msg, st.by, "gov")
func cpuSettle(nid: int) -> void:
	if wildCount() == 0: return
	var na := NAT(nid)
	var P: Dictionary = PERSONA.get(na.persona, PERSONA.bal)
	var slots: int = FRONT.settleMax - settlingOf(nid).size()
	if slots <= 0: return
	var war := inWar(nid)
	var reserve: float = (7000.0 if war else 1200.0) / P.settle
	var cand := []
	for t in G.terrs:
		if t.owner >= 0 or t.get("settle") != null: continue
		var nbs := roadNbrs(t.id)
		var mineN := 0
		var other := false
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
var WILD_KEY := ""
var WILD_N := 0
func wildCount() -> int:
	var k := str(G.get("ownRev", 0)) + "_" + str(G.turn) + "_" + str(G.terrs.size())
	if WILD_KEY == k and WILD_G == G: return WILD_N
	var n := 0
	for t in G.terrs:
		if t.owner < 0: n += 1
	WILD_KEY = k
	WILD_G = G
	WILD_N = n
	return n
var WILD_G = null
func terrIncome(t: Dictionary) -> int:
	if t.type != "city" or t.owner < 0: return 0
	var na := NAT(t.owner)
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
	var g := warGoal(a, b)
	var id = G.dip.capId[a][b]
	return WGOAL[g].n + (("（%s）" % T(id).name) if g == "claim" and id != null else "")
var WAR := {"scoreTerr": 14, "scoreBattle": 5, "scoreCapital": 25, "scoreArmy": 6, "decay": 0.97,
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
	var gk := warGoal(a, b)
	var g = WGOAL.get(gk)
	if g == null: return ""
	var extra := ("（%d / %d）" % [warTaken(a, b), g.need]) if gk == "cede" or gk == "three" else ""
	return g.n + extra
func peaceOptions(a: int, b: int) -> Dictionary:
	var edge := warEdge(a, b)
	var maxCede: int = max(0, min(4, floor(edge / float(WAR.cedeCost))))
	return {"edge": edge, "cede": maxCede, "vassal": edge >= WAR.vassalEdge and canAskVassal(a, b),
		"gold": int(round(NAT(b).gold * WAR.goldRate)) if edge >= WAR.goldEdge else 0}
func peaceAccept(a: int, b: int, terms: Dictionary) -> bool:
	var edge := warEdge(a, b)
	var nb := NAT(b)
	var cost: float = terms.get("cede", 0) * WAR.cedeCost + (WAR.vassalEdge if terms.get("vassal", false) else 0) + (WAR.goldEdge if terms.get("gold", 0) else 0)
	var will: float = edge + nb.get("fatigue", 0) * 0.5 + cpuDanger(b) * 25 - WAR.acceptBase
	if nb.food <= 0: will += 15
	var own := 0
	for t in G.terrs:
		if t.owner == b: own += 1
	if own <= 3: will += 20
	return will >= cost
func settlePeace(a: int, b: int, terms: Dictionary) -> Array:
	var W = warObj(a, b)
	if W != null:
		var demands: bool = terms.get("cede", 0) > 0 or terms.get("gold", 0) > 0 or terms.get("vassal", false)
		var win := otherSide(W, b)
		var alive := []
		for n in win:
			if NAT(n).alive: alive.append(n)
		alive.sort_custom(func(x, y): return W.sc.get(x, 0) > W.sc.get(y, 0))
		var top = alive[0] if alive.size() else null
		var vasTo = top if terms.get("vassal", false) and top != null and canAskVassal(top, b) else null
		if terms.get("gold", 0) and top != null:
			var g: int = min(NAT(b).gold, terms.gold)
			var tot := 0.0
			for n in win: tot += W.sc.get(n, 0)
			if tot == 0: tot = 1
			NAT(b).gold -= g
			for n in win:
				if NAT(n).alive: NAT(n).gold += int(round(g * W.sc.get(n, 0) / tot))
		var lines := endWar(W, {"winner": win, "full": false} if demands else null)
		if vasTo != null and canAskVassal(vasTo, b):
			makeVassal(vasTo, b, "講和による従属")
			lines.append("%s は %s の属国に" % [NAT(b).name, NAT(vasTo).name])
		return lines
	var lines2 := []
	if terms.get("cede", 0):
		var list := cedeTerrs(b, a, terms.cede)
		if list.size():
			var names := []
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
		var msg := "講和条件：%s は %s へ %s" % [NAT(b).name, NAT(a).name, "、".join(lines2)]
		logMsg(msg, "war")
		chron(msg, a, "gov")
	return lines2
func cedeTerrs(from: int, to: int, n: int) -> Array:
	var mine := []
	for t in G.terrs:
		if t.owner == from: mine.append(t)
	var border := []
	for t in mine:
		if _nextToOwn(t.id, to): border.append(t)
	border.sort_custom(func(x, y):
		var a1 := contig(x, to)
		var b1 := contig(y, to)
		if a1 != b1: return a1 > b1
		var a2 := contig(x, from)
		var b2 := contig(y, from)
		if a2 != b2: return a2 < b2
		return x.dev < y.dev)
	var pool := border.duplicate()
	for t in mine:
		if not border.has(t) and not t.cap: pool.append(t)
	var out := []
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
	var ratio := nationPower(a) / max(1.0, nationPower(b))
	var P: Dictionary = PERSONA.get(NAT(a).persona, PERSONA.bal)
	var dv = desireVs(a, b)
	if dv != null and dv.get("t") != null: return "claim"
	if dv != null and dv.k == "feud": return "vassal" if ratio >= DIP.vassalWarRatio else "capital"
	if dv != null and (dv.k == "protect" or dv.k == "guard"): return "defend"
	if ratio >= DIP.vassalWarRatio and randf() < 0.5: return "vassal"
	if ratio >= 1.8 and (P.army > 0 or randf() < 0.4): return "capital"
	if ratio >= 1.25: return "three"
	return "cede"
