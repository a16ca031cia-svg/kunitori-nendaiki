# 外交（元 4048〜）：好感度・大義・通商・不可侵・従属・脅威・戦争と講和
extends "res://scripts/core/k2_rules.gd"

var DIP := {
	"passMin": 60, "allyMin": 80, "peaceMin": 15,
	"giftCost": 5000, "giftFavor": 12, "giftCool": 3,
	"warFavor": -100, "warOthers": -26, "warAllyOthers": -8, "justMul": 0.35, "captureFavor": -6,
	"driftPeace": 0.5, "driftAlly": 1.2, "driftWar": -1.5, "driftCap": 62,
	"driftCommon": 1.6, "driftCommonCap": 95,
	"cpuWarChance": {"aggr": 0.28, "bal": 0.14, "def": 0.07, "econ": 0.05},
	"cpuWarNeed": {"aggr": 40, "bal": 58, "def": 75, "econ": 85},
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
var CASUS := {"lostTurns": 30, "betrayTurns": 30, "unjustTurns": 20, "fabGold": 6000, "fabTurns": 6, "fabKeep": 25,
	"fabSpot": 0.3, "noSec": 15, "noFat": 25, "noFavor": -20, "noThreat": 1.8, "disputeRate": 0.004, "disputeTurns": 20}
var TRADE := {"min": 30, "max": 4, "rate": 0.10, "favor": 1, "favorCap": 80}
var PACT := {"min": 40, "turns": 20, "renewMin": 50, "breakFavor": -25, "breakOthers": -10, "favor": 0.5, "favorCap": 70}
const REL_NAME := {"peace": "平和", "tense": "緊張", "war": "戦争中", "ally": "同盟"}
const REL_COL := {"peace": "#9b9484", "tense": "#d29b3c", "war": "#c0504a", "ally": "#6d9c63"}

func _mk(n: int, v) -> Array:
	var out := []
	for a in n:
		var row := []
		row.resize(n)
		row.fill(v)
		out.append(row)
	return out
func initDip(g: Dictionary) -> Dictionary:
	var n: int = g.nations.size()
	var favor := []
	for a in n:
		var row := []
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
			var spot := randf() < CASUS.fabSpot
			if spot:
				addFavor(b, a, -20)
				for c in G.nations:
					if c.alive and c.id != a and c.id != b: addFavor(c.id, a, -4)
			var msg := "%s が %s への領有権を主張%s" % [NAT(a).name, NAT(b).name, "（工作が露見）" if spot else ""]
			logMsg(msg)
			chron(msg, a, "dip")

# ---------- 通商協定 ----------
func isTrade(a: int, b: int) -> bool: return a != b and G.dip.trade[a][b]
func tradePartners(a: int) -> Array:
	var r := []
	for o in G.nations:
		if o.alive and isTrade(a, o.id): r.append(o.id)
	return r
func tradeEase(nid: int) -> float: return PERSONA.get(NAT(nid).persona, PERSONA.bal).tradeW
func tradeReason(a: int, b: int) -> String:
	if isTrade(a, b): return "すでに通商しています"
	var st := relState(a, b)
	if st == "war" or st == "tense": return "戦争・緊張中は結べません"
	if not natNear(a, b): return "遠すぎて通商できません（隣国とその隣の国まで）"
	if tradePartners(a).size() >= TRADE.max: return "通商協定は %d 国までです" % TRADE.max
	if tradePartners(b).size() >= TRADE.max: return "%s は通商相手が埋まっています" % NAT(b).name
	return ""
func tradeNeed(b: int) -> float: return TRADE.min - tradeEase(b)
func tradeSwap(b: int, a: int):
	var ps := tradePartners(b)
	if ps.size() < TRADE.max or favorOf(b, a) < tradeNeed(b) + 15: return null
	ps.sort_custom(func(x, y): return favorOf(b, x) < favorOf(b, y))
	var worst = ps[0]
	return worst if worst != null and favorOf(b, worst) < favorOf(b, a) else null
func makeTrade(a: int, b: int) -> void:
	G.dip.trade[a][b] = true; G.dip.trade[b][a] = true
	var msg := "%s と %s が通商協定を結ぶ" % [NAT(a).name, NAT(b).name]
	logMsg(msg)
	chron(msg, a, "dip")
func endTrade(a: int, b: int, why := "") -> void:
	if not isTrade(a, b): return
	G.dip.trade[a][b] = false; G.dip.trade[b][a] = false
	var msg := "%s と %s の通商が途絶える%s" % [NAT(a).name, NAT(b).name, ("（" + why + "）") if why != "" else ""]
	logMsg(msg)
	chron(msg, a, "dip")
func tradeIncome(nid: int) -> int:
	var me := NAT(nid)
	if not me.alive: return 0
	var g := 0.0
	for o in tradePartners(nid): g += min(me.get("goldIn", 0), NAT(o).get("goldIn", 0)) * TRADE.rate
	return int(round(g))

# ---------- 不可侵条約 ----------
func pactLeft(a: int, b: int) -> int: return 0 if a == b else max(0, G.dip.pact[a][b] - G.turn)
func pactEase(nid: int) -> float: return PERSONA.get(NAT(nid).persona, PERSONA.bal).pactW
func pactNeed(b: int) -> float: return PACT.min - pactEase(b)
func makePact(a: int, b: int) -> void:
	G.dip.pact[a][b] = G.turn + PACT.turns; G.dip.pact[b][a] = G.turn + PACT.turns
	var msg := "%s と %s が不可侵条約を結ぶ（%dターン）" % [NAT(a).name, NAT(b).name, PACT.turns]
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
	var msg := "%s が %s との不可侵条約を破棄" % [NAT(a).name, NAT(b).name]
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
			var fric := clamp_f(1 + (60 - (favorOf(a, b) + favorOf(b, a)) / 2) / 40, 0.4, 2.5)
			if relState(a, b) == "peace" and pactLeft(a, b) <= 0 \
					and randf() < CASUS.disputeRate * fric and nationsAdjacent(a, b):
				grantCB(a, b, "国境紛争", CASUS.disputeTurns); grantCB(b, a, "国境紛争", CASUS.disputeTurns)
				addFavor(a, b, -8); addFavor(b, a, -8)
				var msg := "%s と %s の国境で紛争 — 互いに大義を得る" % [NAT(a).name, NAT(b).name]
				logMsg(msg)
				chron(msg, a, "dip")
			var p: int = G.dip.pact[a][b]
			if p:
				if favorOf(a, b) < PACT.favorCap: addFavor(a, b, PACT.favor)
				if favorOf(b, a) < PACT.favorCap: addFavor(b, a, PACT.favor)
				if G.turn >= p - 1:
					if favorOf(a, b) >= PACT.renewMin and favorOf(b, a) >= PACT.renewMin and relState(a, b) == "peace":
						G.dip.pact[a][b] = G.turn + 1 + PACT.turns; G.dip.pact[b][a] = G.turn + 1 + PACT.turns
						chron("%s と %s が不可侵条約を更新" % [NAT(a).name, NAT(b).name], a, "dip")
					else:
						G.dip.pact[a][b] = 0; G.dip.pact[b][a] = 0
						var msg2 := "%s と %s の不可侵条約が満了" % [NAT(a).name, NAT(b).name]
						logMsg(msg2)
						chron(msg2, a, "dip")

# ---------- 同盟・従属 ----------
func lordOf(nid: int):
	if nid < 0: return null
	var n := NAT(nid)
	return n.lord if n.lord != null and NAT(n.lord).alive else null
func vassalsOf(nid: int) -> Array:
	var r := []
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
	var set := {nid: true}
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
var THR_KEY := ""
var THR_C := {"t": {}}
func thrCache() -> Dictionary:
	var k := str(G.turn) + "_" + str(G.get("ownRev", 0))
	if THR_KEY != k:
		THR_KEY = k
		THR_C = {"t": {}}
	return THR_C
func addThreat(nid: int, v: float) -> void:
	if nid < 0: return
	var n := NAT(nid)
	n.threat = clamp_f(n.get("threat", 0) + v, 0, 400)
	THR_KEY = ""
func threatOf(nid: int) -> float:
	var c := thrCache()
	if c.t.has(nid): return c.t[nid]
	var v := threatCalc(nid)
	c.t[nid] = v
	return v
func threatCalc(nid: int) -> float:
	var n := NAT(nid)
	if not n.alive: return 0.0
	var tot := 0.0
	var live := 0
	for x in G.nations:
		if x.alive:
			tot += nationPower(x.id)
			live += 1
	if tot == 0: tot = 1
	var over: float = max(0.0, nationPower(nid) / tot - 1.0 / max(1, live))
	return n.get("threat", 0) + over * DIP.threatPowerW
func topThreat():
	var c := thrCache()
	if c.has("top"): return c.top
	c.top = topThreatCalc()
	return c.top
func topThreatCalc():
	var id = null
	var v := 0.0
	for n in G.nations:
		if not n.alive: continue
		var t := threatOf(n.id)
		if t > v:
			v = t
			id = n.id
	var cur = G.topThreat
	if cur != null and NAT(cur).alive:
		var cv := threatOf(cur)
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
	THR_KEY = ""
	for n in G.nations: n.threat = max(0.0, n.get("threat", 0) * DIP.threatDecay)
	var t = topThreat()
	var cur = t.id if t != null else null
	if cur != G.topThreat:
		if cur != null:
			var msg := "%s が諸国から最大の脅威とみなされる" % NAT(cur).name
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
			var sp := surrenderProg(W, n)
			if sp >= surrenderLimit(n): capitulate(W, n, "国の %d%% を占領された" % int(round(sp * 100)))
		if not G.wars.has(W.id): continue
		warSuccession()
		if not G.wars.has(W.id): continue
		var age: int = G.turn - W.t0
		var idle: int = G.turn - W.get("act", W.t0)
		if (age >= 20 and idle >= 10) or age >= 50:
			var lines := endWar(W, null)
			dipReport("peace", W.a, W.b, true, ("長い戦に双方が疲れ果てた" if age >= 50 else "戦線が膠着した") + (("／" + "／".join(lines)) if lines.size() else ""))
func _lostSide(W: Dictionary, S_: Array) -> bool:
	for n in S_:
		if NAT(n).alive and not W.get("capd", []).has(n): return false
	return true
func _actSide(W: Dictionary, S_: Array) -> Array:
	var r := []
	for n in S_:
		if inThisWar(W, n): r.append(n)
	return r
func warSuccession() -> void:
	for W in G.wars.values().duplicate():
		if not G.wars.has(W.id): continue
		var lA := _lostSide(W, W.sA)
		var lB := _lostSide(W, W.sB)
		if lA and not lB:
			endWar(W, {"winner": W.sB, "full": true})
			continue
		if lB and not lA:
			endWar(W, {"winner": W.sA, "full": true})
			continue
		var aA := _actSide(W, W.sA)
		var aB := _actSide(W, W.sB)
		if aA.is_empty() or aB.is_empty():
			if aA.size() and aB.is_empty(): endWar(W, {"winner": W.sA, "full": lB})
			elif aB.size() and aA.is_empty(): endWar(W, {"winner": W.sB, "full": lA})
			else: endWar(W, null)
			continue
		for k in ["a", "b"]:
			if inThisWar(W, W[k]): continue
			var cand := aA if k == "a" else aB
			cand.sort_custom(func(x, y): return W.sc.get(x, 0) > W.sc.get(y, 0))
			if cand.size(): W[k] = cand[0]

# ---------- 降伏と講和会議 ----------
const VP_K := 3
func vpOf(t: Dictionary) -> float: return 1 + t.dev * 1.5 + (12 if t.cap else 0) + (1 if t.type == "city" else 0) + t.pop / 8000.0
func natVP(n: int) -> float:
	var s := 0.0
	for t in G.terrs:
		if t.owner == n: s += vpOf(t)
	return s
func surrenderLimit(n: int) -> float:
	var na := NAT(n)
	var base: float = {"def": 0.78, "aggr": 0.7, "bal": 0.66, "econ": 0.58}.get(na.persona, 0.66)
	return clamp_f(base - na.get("fatigue", 0) / 250.0, 0.35, 0.85)
func surrenderProg(W: Dictionary, n: int) -> float:
	var base: float = W.vp0.get(n, 0)
	if not base: base = natVP(n)
	if not base: base = 1
	var foe := otherSide(W, n)
	var occ := 0.0
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
	var msg := "%s が降伏する%s" % [NAT(n).name, ("（" + why + "）") if why != "" else ""]
	if concerns([n] + otherSide(W, n)): logMsg(msg, "war")
	chron(msg, n, "fall")
	dipReport("surrender", n, otherSide(W, n)[0], true, why)
	invalidateSupply()
