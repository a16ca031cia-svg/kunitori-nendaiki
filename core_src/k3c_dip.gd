# 外交 続き（元 5098〜5621）：支援・併合・危うさ・欲求・陣営
extends "res://scripts/core/k3b_dip.gd"

# ---------- 属国・同盟国への支援 ----------
func aidLeft(a: int, b: int) -> int: return max(0, G.dip.aid[a][b] + DIP.aidCool - G.turn)
func canAid(a: int, b: int) -> bool:
	if a == b or b < 0 or not NAT(b).alive: return false
	if not isVassal(b, a) and not isAlly(a, b): return false
	return aidLeft(a, b) <= 0
func sendAid(a: int, b: int, kind: String) -> bool:
	var A := NAT(a)
	var B := NAT(b)
	if not canAid(a, b): return false
	var fav := 0
	var un := 0
	var what := ""
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
		var st := float(max(1, total(A.stock)))
		for k in TK:
			var n: int = min(A.stock[k], int(ceil(DIP.aidTroop * (A.stock[k] / st))), left)
			A.stock[k] -= n; B.stock[k] += n; left -= n
		fav = DIP.aidTroopFav; un = DIP.aidTroopUnrest; what = "兵 %s" % fmt(DIP.aidTroop - left)
	G.dip.aid[a][b] = G.turn
	addFavor(b, a, fav)
	if isVassal(b, a): B.unrest = clamp_f(B.get("unrest", 0) + un, 0, DIP.unrestMax)
	var msg := "%s が %s へ %s を援助（好感度 +%d%s）" % [A.name, B.name, what, fav, ("／不満 %d" % un) if isVassal(b, a) else ""]
	logMsg(msg)
	chron(msg, a, "gov")
	return true
func cpuAid(nid: int) -> void:
	var na := NAT(nid)
	for v in vassalsOf(nid):
		var B := NAT(v)
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
	var nb := NAT(b)
	var ratio := nationPower(a) / max(1.0, nationPower(b))
	var terr := 0
	for t in G.terrs:
		if t.owner == b: terr += 1
	var will: float = (ratio - DIP.annexRatio) * 10 + 12
	if isVassal(b, a): will += (DIP.unrestMax - nb.get("unrest", 0)) * 0.45 + favorOf(b, a) * 0.2
	if atWar(a, b): will += warEdge(a, b) * 0.18 + nb.get("fatigue", 0) * 0.35
	will += cpuDanger(b) * 14 - terr * 2.5
	if terr <= 3: will += 20
	return will >= 30
func annex(a: int, b: int, note := "") -> void:
	var A := NAT(a)
	var B := NAT(b)
	var terrs := []
	for t in G.terrs:
		if t.owner == b: terrs.append(t)
	for t in terrs:
		t.owner = a
		t.chaos = max(t.chaos, CFG.chaosTurns)
		t.sec = min(t.sec, CFG.secCapture + 15)
		if t.cap: t.cap = false
		invalidateTerr(t.id)
	G.ownRev = G.get("ownRev", 0) + 1
	var got := 0
	for x in B.armies:
		if x == null: continue
		for k in TK:
			var n := int(round(x.t[k] * DIP.annexTroop))
			A.stock[k] += n; got += n; x.t[k] = 0
	for k in TK:
		var n := int(round(B.stock[k] * DIP.annexTroop))
		A.stock[k] += n; got += n; B.stock[k] = 0
	for i in B.armies.size(): B.armies[i] = null; ARMY_REV += 1
	var gens := []
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
	var wasV := isVassal(b, a)
	B.lord = null; B.unrest = 0
	setRel(a, b, "peace")
	addThreat(a, DIP.annexThreat * 0.5 if wasV else DIP.annexThreat)
	for c in G.nations:
		if not c.alive or c.id == a or c.id == b: continue
		addFavor(c.id, a, DIP.annexOthers)
	var msg := "%s が %s を併合した（%d領地・兵 %s）" % [A.name, B.name, terrs.size(), fmt(got)]
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
	var msg := "%s が属国 %s の併合を始める（毎ターン少しずつ組み込む）" % [NAT(a).name, NAT(b).name]
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
		var own := []
		for t in G.terrs:
			if t.owner == na.id: own.append(t)
		if own.size() <= DIP.absorbRate:
			na.absorbBy = null
			annex(a, na.id, "属国の併合")
			continue
		var cand := []
		for t in own:
			if not t.cap: cand.append(t)
		cand.sort_custom(func(x, y): return contig(x, a) > contig(y, a))
		var pk := cand.slice(0, DIP.absorbRate)
		var names := []
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
		var pw := nationPower(na.id) / max(1.0, nationPower(lord))
		var war := inWar(na.id)
		var up: float = DIP.unrestBase + clamp_f(pw, 0, 2) * DIP.unrestPower + (DIP.unrestWar if war else 0.0)
		if na.get("fatigue", 0) >= CFG.fatMid: up += 1.5
		if hasDesire(na.id, "indep"): up += 2.5
		na.unrest = clamp_f(na.get("unrest", 0) + up, 0, DIP.unrestMax)

# ---------- 生き残りの見立て（0＝安全 / 1以上＝危機） ----------
var DG_CACHE := {}
var DG_KEY := ""
func cpuDanger(nid: int) -> float:
	var k := powKey()
	if DG_KEY != k:
		DG_CACHE = {}
		DG_KEY = k
	if DG_CACHE.has(nid): return DG_CACHE[nid]
	var na := NAT(nid)
	if not na.alive:
		DG_CACHE[nid] = 0.0
		return 0.0
	var mine: float = max(1.0, nationPower(nid))
	var foe := 0.0
	var nearFoe := 0.0
	var wars := 0
	for o in G.nations:
		if not o.alive or o.id == nid: continue
		var adj := nationsAdjacent(nid, o.id)
		if atWar(nid, o.id):
			wars += 1
			foe += nationPower(o.id) * (1.0 if adj else 0.4)
		elif adj and (isTense(nid, o.id) or isTopThreat(o.id)):
			nearFoe += nationPower(o.id) * 0.5
	var own := 0
	for t in G.terrs:
		if t.owner == nid: own += 1
	var d: float = min(1.9, (foe + nearFoe) / mine * 0.5)
	d += max(0, wars - 1) * 0.18
	d += na.get("fatigue", 0) / 180.0
	if na.food <= 0: d += 0.25
	if own <= 3: d += 0.35
	var supply: int = na.supSet.size() if na.get("supSet") is Dictionary else own
	if supply < own * 0.7: d += 0.15
	if lordOf(nid) != null: d -= 0.2
	var v := clamp_f(d, 0, 3)
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
var DES := {"max": 2, "review": 6, "life": 40, "warBonus": 45, "warChanceMul": 1.0, "noWishMul": 0.2}
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
var COAST := {}
var SEA_END := {}
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
	var out := {}
	for t in G.terrs:
		if t.owner != nid: continue
		for n in roadNbrs(t.id):
			var o: int = T(n.to).owner
			if o >= 0 and o != nid: out[n.to] = true
	return out.keys()
func _okTarget(nid: int, o: int, lord) -> bool:
	return o >= 0 and o != nid and NAT(o).alive and lordOf(o) != nid and o != lord and not isAlly(nid, o) and not sameFaction(nid, o)
func desireCands(nid: int) -> Array:
	var na := NAT(nid)
	var c := []
	var mine: float = max(1.0, nationPower(nid))
	var P: String = na.persona
	var lord = lordOf(nid)
	if lord != null:
		var pw := mine / max(1.0, nationPower(lord))
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
		var bt := borderTargets(nid)
		coastInfo()
		var ports := 0
		for t in G.terrs:
			if t.owner == nid and portValue(t) >= 10: ports += 1
		var warlike: float = 8 if P == "aggr" else (0 if P == "bal" else -15)
		for id in bt:
			var t := T(id)
			var o: int = t.owner
			if not _okTarget(nid, o, lord): continue
			var ratio := mine / max(1.0, nationPower(o))
			if ratio < 0.85 or not (atWar(nid, o) or canPrepare(nid, o) or isTense(nid, o)): continue
			var pv := portValue(t)
			if pv > 0: c.append({"k": "port", "t": id, "w": pv + (30 if ports == 0 else (8 if ports < 2 else -10)) + clamp_f(ratio - 1, -1, 1) * 15 + warlike * 0.5})
			c.append({"k": "land", "t": id, "w": landValue(t) + warlike + clamp_f(ratio - 1, -1, 1) * 18})
		for o in G.nations:
			if not _okTarget(nid, o.id, lord) or not natNear(nid, o.id): continue
			var f: int = G.dip.feud[nid][o.id]
			if f >= 2: c.append({"k": "feud", "o": o.id, "w": 25 + f * 12 + (60 - favorOf(nid, o.id)) * 0.2})
	var fat: float = na.get("fatigue", 0)
	c.append({"k": "prosper", "w": 18 + fat * 0.5 + (18 if P == "econ" else (6 if P == "def" else (-12 if P == "aggr" else 0))) + (10 if na.gold < 8000 else 0)})
	var dg := cpuDanger(nid)
	for o in G.nations:
		if not o.alive or o.id == nid or not nationsAdjacent(nid, o.id) or isAlly(nid, o.id): continue
		var r := nationPower(o.id) / mine
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
	var o := desireNat(d)
	if DESIRE[d.k].war and (o < 0 or o == nid or not NAT(o).alive): return d.k != "feud"
	if DESIRE[d.k].war and o >= 0 and (isAlly(nid, o) or lordOf(o) == nid or lordOf(nid) == o): return true
	return false
func desireLog(nid: int, msg: String, others := [], cls := "") -> void:
	chron(msg, nid, "gov")
	if concerns([nid] + others): logMsg(msg, cls)
func desireTurn(nid: int) -> void:
	var na := NAT(nid)
	if not na.alive: return
	if not na.has("desires"): na.desires = []
	for d in na.desires.duplicate():
		if desireDone(nid, d):
			na.desires.erase(d)
			var txt := desireDoneText(d)
			if txt != "": desireLog(nid, "%s、望みを果たす — %s" % [na.name, txt], [desireNat(d)], "good")
		elif desireLost(nid, d):
			na.desires.erase(d)
			if concerns([nid]): logMsg("%s は「%s」を諦めた" % [na.name, desireText(d)])
	var due: bool = (G.turn + nid) % DES.review == 0 or na.desires.is_empty()
	if not due or na.desires.size() >= DES.max: return
	var have := {}
	for d in na.desires: have[desireKey(d)] = true
	var peaceful := false
	var warlike := false
	for d in na.desires:
		if d.k == "prosper": peaceful = true
		if DESIRE[d.k].war: warlike = true
	var pool := []
	for x in desireCands(nid):
		if have.has(desireKey(x)) or x.w < 30: continue
		if peaceful and DESIRE[x.k].war: continue
		if warlike and x.k == "prosper": continue
		var dup := false
		if x.get("t") != null:
			for d in na.desires:
				if d.get("t") != null and T(d.t).owner == T(x.t).owner and d.k == x.k: dup = true
		if dup: continue
		pool.append(x)
	if pool.is_empty(): return
	pool.sort_custom(func(a, b): return a.w > b.w)
	var top3 := pool.slice(0, 3)
	var pickD: Dictionary = top3[0] if randf() < 0.6 else top3[randi() % top3.size()]
	var d := pickD.duplicate()
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
var FAC := {"ratio": 1.5, "createChance": 0.08, "inviteChance": 0.3, "leaveFavor": -20, "inviteFavor": 50}
func facOf(n):
	if n == null or n < 0: return null
	var na := NAT(n)
	var f = na.get("faction")
	if f == null or not G.has("factions"): return null
	return G.factions.get(f)
func sameFaction(a: int, b: int) -> bool:
	if a == b: return false
	var fa = facOf(a)
	return fa != null and fa == facOf(b)
func avgPower() -> float:
	var s := 0.0
	var n := 0
	for x in G.nations:
		if x.alive:
			s += nationPower(x.id)
			n += 1
	return s / max(1, n)
func canMakeFaction(n: int) -> bool:
	var na := NAT(n)
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
	var msg := "%s が「%s」を結成する" % [NAT(n).name, nm]
	logMsg(msg, "good")
	chron(msg, n, "dip")
	dipReport("faction", n, n, true, "盟主として近くの国を招きます")
func joinFaction(F: Dictionary, n: int) -> void:
	if not F.members.has(n): F.members.append(n)
	NAT(n).faction = F.id
	for m in F.members:
		if m != n:
			addFavor(m, n, 10); addFavor(n, m, 10)
	var msg := "%s が「%s」に加わる" % [NAT(n).name, F.name]
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
		var msg := "%s が「%s」を離脱する%s" % [NAT(n).name, F.name, ("（" + why + "）") if why != "" else ""]
		if concerns([n] + F.members): logMsg(msg, "war")
		chron(msg, n, "dip")
		dipReport("unfaction", n, F.leader, true, why)
	facCheck(F)
func facCheck(F: Dictionary) -> void:
	var mem := []
	for m in F.members:
		if NAT(m).alive and NAT(m).get("faction") == F.id: mem.append(m)
	F.members = mem
	if mem.is_empty():
		G.factions.erase(F.id)
		chron("「%s」が解散する" % F.name, F.leader, "dip")
		return
	if not mem.has(F.leader):
		var s := mem.duplicate()
		s.sort_custom(func(x, y): return nationPower(x) > nationPower(y))
		F.leader = s[0]
		chron("「%s」の盟主が %s に代わる" % [F.name, NAT(F.leader).name], F.leader, "dip")
func _facWorth(nid: int, F: Dictionary, o: Dictionary, facPow: float, top0) -> float:
	var w := favorOf(nid, o.id) + favorOf(o.id, nid) * 0.5
	var front := false
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
	var na := NAT(nid)
	if not na.alive: return
	if lordOf(nid) != null:
		if facOf(nid) != null: leaveFaction(nid, "quiet")
		return
	var F = facOf(nid)
	if F == null and canMakeFaction(nid) and randf() < FAC.createChance:
		makeFaction(nid)
		F = facOf(nid)
	if F != null and F.leader == nid and randf() < FAC.inviteChance:
		var cand := []
		for o in G.nations:
			if not o.alive or o.id == nid or facOf(o.id) != null or lordOf(o.id) != null: continue
			var near := false
			var war := false
			for m in F.members:
				if natNear(m, o.id): near = true
				if atWar(m, o.id): war = true
			if not near or war: continue
			if favorOf(nid, o.id) < FAC.inviteFavor - 10: continue
			cand.append(o)
		var facPow := 0.0
		for m in F.members: facPow += nationPower(m)
		var top0 = topThreat()
		var smart := smartAI(nid)
		if smart:
			var ws := {}
			for o in cand: ws[o.id] = _facWorth(nid, F, o, facPow, top0)
			cand.sort_custom(func(x, y): return ws[x.id] > ws[y.id])
		else:
			cand.sort_custom(func(x, y): return favorOf(x.id, nid) > favorOf(y.id, nid))
		var o = null
		if cand.size() and (not smart or _facWorth(nid, F, cand[0], facPow, top0) > 40): o = cand[0]
		if o != null:
			var common := false
			for c in G.nations:
				if not c.alive or not atWar(o.id, c.id): continue
				for m in F.members:
					if atWar(m, c.id): common = true
			var top = topThreat()
			var vsTop: bool = top != null and not F.members.has(top.id) and natHops(o.id, top.id) <= 2
			var sc := (favorOf(o.id, nid) - 50) * 0.8 + cpuDanger(o.id) * 35 + (20 if common else 0) + (15 if vsTop else 0) \
				+ (25 if o.get("ideo") == na.get("ideo") else -20) - (25 if nationPower(o.id) > nationPower(nid) * 0.8 else 0) + 10
			for d in desiresOf(o.id):
				if DESIRE[d.k].war and F.members.has(desireNat(d)):
					sc -= 40
					break
			if sc >= 20:
				joinFaction(F, o.id)
				dipReport("faction", nid, o.id, true, "「%s」への招待に応じた" % F.name)
			else:
				dipReport("faction", nid, o.id, false, "「%s」への招待を断った" % F.name)
				addFavor(nid, o.id, -2)
	if F != null and F.leader != nid and G.factions.has(F.id):
		var wantOut := favorOf(nid, F.leader) < 25
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
	var wid := warOf(a, b)
	var Fb = facOf(b)
	if Fb != null:
		for m in Fb.members.duplicate():
			if m == b or not NAT(m).alive or atWar(m, a) or sameFaction(m, a): continue
			enterWar(m, a, "「%s」の加盟国 %s を守るため参戦" % [Fb.name, NAT(b).name], wid)
	var Fa = facOf(a)
	if Fa != null:
		for m in Fa.members.duplicate():
			if m == a or not NAT(m).alive or atWar(m, b) or sameFaction(m, b): continue
			var ok: bool = favorOf(m, a) >= 50 and pactLeft(m, b) <= 0 and natNear(m, b) and not isAlly(m, b) and NAT(m).get("fatigue", 0) < DIP.fatiguePeace
			if ok: enterWar(m, b, "「%s」の呼びかけに応じて参戦" % Fa.name, wid)
			elif concerns([m, a]): dipReport("join", m, b, false, "「%s」の呼びかけに応じなかった" % Fa.name)
