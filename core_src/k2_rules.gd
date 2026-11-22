# 参照・経路・補給・国力（元 1443〜1600）／軍団・戦闘・占領（元 3554〜4046）
extends "res://scripts/core/k1_map.gd"

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
	var t := T(tid)
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
	var na := NAT(a.owner)
	var g = genOf(na, a.gen) if a.gen != null else null
	var tot := 0.0; var atk := 0.0; var def := 0.0; var chg := 0.0
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
	var om := orgMul(a)
	var gtm := genTraitMods(a, T(a.at))
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
var PF_KEY := ""
var PF_TO := []          # 領地ごとの PackedInt32Array（隣の領地）
var PF_EF := []          # 同じ並びの辺の印（1=海峡 2=川）
var PF_COST := PackedInt32Array()
var PF_INF3 := PackedByteArray()
var PF_OWN := PackedInt32Array()
var PF_OWN_KEY := -1
func _pfPrep() -> void:
	var key := str(G.edges.size()) + "_" + str(G.get("roadRev", 0))
	if PF_G != G or PF_KEY != key:
		var n: int = G.terrs.size()
		var to := []
		var ef := []
		for i in n:
			to.append(PackedInt32Array())
			ef.append(PackedInt32Array())
		for e in G.edges:
			var f := (1 if e.get("sea", false) else 0) | (2 if e.get("river", false) else 0)
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
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	dist[start] = 0
	var reach := 1
	var bk := [PackedInt32Array([start])]
	var free: bool = nid == null or nid < 0
	var enter := PackedInt32Array()
	if not free:
		enter.resize(G.nations.size() + 1)
		enter.fill(-1)
	var d := 0
	while d < bk.size():
		var B: PackedInt32Array = bk[d]
		var i := 0
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
	var p := []
	var c := to
	while c != b.start:
		p.push_front(c)
		c = b.prev[c]
	return p
func findPath(from: int, to: int, size = null, nid = null):
	if from == to: return []
	return pathFrom(bfsFrom(from, size, nid), to)

# ---------- 補給線（自国領を伝って首都と繋がっているか） ----------
var SUP_DIRTY := true
var SUP_TERR_KEY := ""
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
	var caps := []
	for n in G.nations: caps.append(n.capital if n.alive else -1)
	var key := "%d_%d_%s" % [G.get("ownRev", 0), G.get("roadRev", 0), caps]
	var allSets := true
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
		var set := {}
		if na.alive and T(na.capital).owner == na.id:
			set[na.capital] = true
			var q := [na.capital]
			var i := 0
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
var PW_CACHE := {}
var PW_KEY := -1
var PW_G = null
## 鍵は整数（文字列を毎回作ると重い）
func powKey() -> int: return G.turn * 1000000 + int(G.get("ownRev", 0))
## 戦略の見積もり（隣り合い・距離・脅威・危険度）の鍵：ターンの区切りごとに1回だけ作り直す（占領のたびには作り直さない。国が滅んだ時は作り直す）
var STRAT_REV := 0
var _sbOwn := -1
var _sbTurn := -1
func stratBump() -> void:
	var o: int = int(G.get("ownRev", 0))
	if o == _sbOwn and G.turn == _sbTurn: return
	_sbOwn = o
	_sbTurn = G.turn
	STRAT_REV += 1
## 国力：鍵（ターン・持ち主の変化）が変わったら、全領地を1回だけなめて全部の国をまとめて計算する
var OWN_N := {}
var OWN_L := {}
var NO_OWNL: bool = OS.get_environment("KN_NOOWNL") != ""
func _powAll() -> void:
	OWN_L = {}
	PW_CACHE = {}
	OWN_N = {}
	PW_KEY = powKey()
	PW_G = G
	var acc := {}
	for t in G.terrs:
		var o: int = t.owner
		if o < 0: continue
		if not OWN_L.has(o): OWN_L[o] = []
		OWN_L[o].append(t)
		var nb := 0
		for b in t.bld:
			if b: nb += 1
		acc[o] = acc.get(o, 0.0) + t.dev * (120 if t.type == "city" else 80) + nb * 60 + t.pop * 0.006
		OWN_N[o] = OWN_N.get(o, 0) + 1
	for na in G.nations:
		PW_CACHE[na.id] = round(acc.get(na.id, 0.0) + nationTroops(na.id) * 0.6 + na.gold * 0.05)
func nationPower(nid: int) -> float:
	if PW_KEY != powKey() or PW_G != G: _powAll()
	if PW_CACHE.has(nid): return PW_CACHE[nid]
	var v := nationPowerCalc(nid)
	PW_CACHE[nid] = v
	return v
## 自国の領地の一覧（全領地の並び順のまま。持ち主が変わると作り直す）
func ownList(nid: int) -> Array:
	if NO_OWNL:
		var r := []
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
	var p := 0.0
	for t in ownList(nid):
		var nb := 0
		for b in t.bld:
			if b: nb += 1
		p += t.dev * (120 if t.type == "city" else 80) + nb * 60 + t.pop * 0.006
	p += nationTroops(nid) * 0.6
	p += NAT(nid).gold * 0.05
	return round(p)
func nationTroops(nid: int) -> int:
	var na := NAT(nid)
	var s := total(na.stock)
	for a in na.armies:
		if a != null: s += total(a.t)
	return s

# ---------- 軍団編成・将軍 ----------
func reinforce(a: Dictionary) -> void:
	var p := NAT(a.owner)
	if T(a.at).owner != a.owner: return
	for k in TK:
		var need: int = max(0, a.target[k] - a.t[k])
		var give: int = min(need, p.stock[k])
		a.t[k] += give
		p.stock[k] -= give
func genDesc(g: Dictionary) -> String:
	var s := []
	if g.pts.atk: s.append("攻+%d%%" % (g.pts.atk * 5))
	if g.pts.def: s.append("防+%d%%" % (g.pts.def * 5))
	if g.pts.chg: s.append("突+%d%%" % (g.pts.chg * 3))
	for k in TK:
		if g.pts[k]: s.append(TROOP[k].n + "+%d%%" % (g.pts[k] * 8))
	return " ".join(s) if s.size() else "—"
func randomPts() -> Dictionary:
	var p := {"atk": 0, "def": 0, "chg": 0, "inf": 0, "spe": 0, "arc": 0, "cav": 0}
	for i in 3: p[pick(GEN_ABIL).k] += 1
	return p
func mkGen(g: Dictionary, na: Dictionary, pts: Dictionary) -> Dictionary:
	var gen := {"id": g.gid, "name": pick(GN_A) + pick(GN_B), "pts": pts, "army": null, "maxLed": 0}
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
	var r := []
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
	var t := T(next)
	if not canEnter(a.owner, next):
		a.path = []
		return
	a.moved = true
	if a.get("prog") != next:
		a.prog = next
		a.progN = 0
	a.progN = a.get("progN", 0) + 1
	var need := stepCost(next, e)
	if a.progN < need: return
	a.prog = null
	a.progN = 0
	if not canOccupy(a.owner, next):       # 自国領・通行許可のある領地を通過する
		var foes := _aliveFoes(next, a.owner)
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
	var def := _aliveFoes(next, a.owner)
	if def.is_empty():
		capture(next, a.owner, a)
		a.at = next; ARMY_REV += 1
		a.path.pop_front()
		animMove(a, from)
		return
	if t.type == "fort":
		var mode := cpuSiegeChoice(a, t, def)
		if mode == "siege":
			startSiege(a, t, from)
			return
		UI.assault = true
	var mates := joinCandidates(a, from, next, e)
	if mates.size(): mates = cpuJoiners(a, mates, def, t)
	var force := [a] + mates
	if powerOf(force, t, false) < powerOf(def, t, true) * 0.9:
		UI.assault = false
		a.path = []
		return
	for m in mates:
		m.moved = true
		m.path = []
	var res = await runBattle(force, def, t)
	UI.assault = false
	var alive := []
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
	var msg := "%s が %s を包囲した（%dターンで陥落）" % [NAT(a.owner).name, t.name, CFG.siegeTurns]
	logWar(msg, [a.owner, t.owner], "war")
	chron(msg, a.owner, "fall")
	map_changed.emit("fx", null)
func siegeArmies(t: Dictionary) -> Array:
	if t.get("siege") == null: return []
	var out := []
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
		var force := siegeArmies(t)
		if force.is_empty():
			liftSiege(t, "包囲軍が去った")
			continue
		var gar := []
		for x in armiesAt(t.id):
			if total(x.t) > 0: gar.append(x)
		for g in gar:
			for k in TK: g.t[k] = max(0, int(round(g.t[k] * (1 - CFG.siegeBleed))))
		t.sec = clamp_f(t.sec - CFG.siegeSec, 0, 100)
		var tot := 0
		for x in force: tot += total(x.t)
		NAT(by).food -= int(round(tot / 1000.0 * CFG.siegeFood))
		destroyDead(gar)
		var left := []
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
			var msg := "%s が包囲の末に陥落（%s → %s）" % [t.name, NAT(old).name, NAT(by).name]
			logWar(msg, [old, by], "war")
			chron(msg, by, "fall")
			invalidateSupply()
func liftSiege(t: Dictionary, why: String) -> void:
	if t.get("siege") == null: return
	for na in G.nations:
		for x in na.armies:
			if x != null and x.get("siege") == t.id: x.siege = null
	var msg := "%s の包囲が解かれた（%s）" % [t.name, why]
	logWar(msg, [t.owner, t.siege.by])
	chron(msg, t.owner, "gov")
	t.siege = null
func cpuSiegeChoice(a: Dictionary, t: Dictionary, def: Array) -> String:
	var list := [a]
	for x in armiesAt(a.at):
		if x != a and x.owner == a.owner and not x.moved: list.append(x)
	var mine := powerOf(list, t, false)
	var dp := powerOf(def, t, true)
	if mine >= dp * 1.6: return "assault"
	if NAT(a.owner).food < 1500: return "assault"
	return "siege"
func joinCandidates(a: Dictionary, from: int, _next: int, _e) -> Array:
	var list := []
	for x in armiesAt(from):
		if x == a or x.owner != a.owner or x.moved or total(x.t) <= 0: continue
		list.append(x)
	return list
func cpuJoiners(a: Dictionary, mates: Array, defs: Array, t: Dictionary) -> Array:
	var need := powerOf(defs, t, true) * 1.15
	var out := []
	var mine := powerOf([a], t, false)
	for m in mates:
		if mine >= need: break
		out.append(m)
		mine = powerOf([a] + out, t, false)
	return out

# ---------- 占領 ----------
func capture(tid: int, nid: int, _byArmy = null) -> void:
	var t := T(tid)
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
		var wid := warOf(nid, old)
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
		var rest := []
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
	var na := NAT(nid)
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
	var cnt := {}
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
		var side := [na.id] + vassalsOf(na.id)
		var ok := true
		var n := 0
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
	var tot := 0.0; var atk := 0.0; var def := 0.0; var chg := 0.0
	for a in list:
		var s := armyStats(a)
		tot += s.tot; atk += s.atk * s.tot; def += s.def * s.tot; chg += s.chg * s.tot
	if tot == 0: return {"tot": 0.0, "atk": 0.0, "def": 0.0, "chg": 0.0}
	atk /= tot; def /= tot; chg /= tot
	if isDef: def *= fortMul(t)
	return {"tot": tot, "atk": atk, "def": def, "chg": chg}
func sumTroops(list: Array) -> float:
	var s := 0.0
	for a in list: s += a.t.inf + a.t.spe + a.t.arc + a.t.cav
	return s
func applyLoss(list: Array, amount: float) -> void:
	var tot := sumTroops(list)
	if tot <= 0: return
	amount = min(amount, tot)
	for a in list:
		var at: float = a.t.inf + a.t.spe + a.t.arc + a.t.cav
		if at <= 0: continue
		var share := amount * at / tot
		for k in TK:
			if not a.t[k]: continue
			a.t[k] = max(0.0, a.t[k] - share * (a.t[k] / at))
func battleTick(A: Array, D: Array, t: Dictionary):
	var sa := sideStats(A, t, false)
	var sd := sideStats(D, t, true)
	if not sa.tot or not sd.tot: return null
	var ca := randf() < sa.chg
	var cd := randf() < sd.chg
	var n: float = CFG.sizeExp
	var m := 1 - n
	var powA := pow(sa.tot, n) * pow(sd.tot, m)
	var powD := pow(sd.tot, n) * pow(sa.tot, m)
	var dToD: float = powA * CFG.dmgK * (sa.atk / (sd.def * (1 - CFG.chargeIgnore if ca else 1.0))) + CFG.minDmg
	var dToA: float = powD * CFG.dmgK * (sd.atk / (sa.def * (1 - CFG.chargeIgnore if cd else 1.0))) + CFG.minDmg
	var am: float = CFG.assaultLoss if UI.get("assault", false) else 1.0
	applyLoss(D, dToD)
	applyLoss(A, dToA * am)
	return {"ca": ca, "cd": cd, "dToD": dToD, "dToA": dToA * am, "sa": sa, "sd": sd}
func recordBattle(A: Array, D: Array, res: String) -> void:
	orgAfterBattle(A, D, res)
	var bt := T(D[0].at) if D.size() and D[0] != null else (T(A[0].at) if A.size() and A[0] != null else null)
	if bt != null: genAfterBattle(A, D, res, bt)
	for x in A + D:
		if x != null: x.erase("bmod")
	var win := A if res == "A" else D
	var lose := D if res == "A" else A
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
		var na := NAT(a.owner)
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
		var opt := []
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
	var aw := sumTroops(A) > 0
	recordBattle(A, D, "A" if aw else "D")
	destroyDead(A); destroyDead(D)
	return "A" if aw else "D"

## 戦闘画面：観戦中は選んだ国の戦いだけ見せる（UI が battle_finish を呼ぶまで待つ）
signal battle_show(A: Array, D: Array, t: Dictionary)
signal battle_done(res: String)
var BATTLE_SPENT := 0
var BATTLE_N := 0
func runBattle(atts: Array, defs: Array, t: Dictionary):
	refreshSupply()
	var A := []
	for a in atts:
		if a != null and total(a.t) > 0: A.append(a)
	var lead = A[0]
	# 制空権（空軍力 1.5 倍で攻防 ±10%）と、海峡越しの攻めの制海権（無いと攻撃 -25%）
	if defs.size() and defs[0] != null:
		var ae := airEdge(lead.owner, defs[0].owner)
		var sp := seaEdgePenalty(lead.owner, defs[0].owner, lead.at, t.id)
		for x in A: x.bmod = ae + sp
		for x in defs:
			if x != null: x.bmod = -ae
	var watch: bool = CFG.showCpuBattle and UI.speed != 3 and (concerns([lead.owner, defs[0].owner]) or UI.get("watchAll", false)) and battle_show.get_connections().size() > 0
	# 自動進行中は、戦闘画面を見せる時間を1ターンあたりの上限で区切る（ターンが長く止まらないように）
	if watch and UI.get("auto", false) and BATTLE_SPENT + BEAT_SPENT + 1500 > BEAT_MAX: watch = false
	var _bt0 := Time.get_ticks_msec()
	if not watch or str(CFG.cpuStop) == "auto":
		var r := autoBattle(A, defs, t)
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
	var nb := 0
	for b in t.bld:
		if b: nb += 1
	return t.dev * (120 if t.type == "city" else 80) + nb * 60 + t.pop * 0.006
func _ownMove(t: Dictionary, old: int, nid: int) -> void:
	var valid: bool = PW_G == G and PW_KEY == powKey()
	t.owner = nid
	G.ownRev = G.get("ownRev", 0) + 1
	if not valid: return
	PW_KEY = powKey()
	var c := _terrPow(t)
	if old >= 0 and OWN_L.has(old):
		var l: Array = OWN_L[old].duplicate()
		l.erase(t)
		OWN_L[old] = l
		OWN_N[old] = OWN_N.get(old, 1) - 1
		if PW_CACHE.has(old): PW_CACHE[old] -= c
	if nid >= 0:
		var l2: Array = OWN_L.get(nid, []).duplicate()
		var i := l2.bsearch_custom(t, func(a, b): return a.id < b.id)
		l2.insert(i, t)
		OWN_L[nid] = l2
		OWN_N[nid] = OWN_N.get(nid, 0) + 1
		if PW_CACHE.has(nid): PW_CACHE[nid] += c
