# 滅びた国の蜂起・CPUの外交戦略（元 5622〜6006）
extends "res://scripts/core/k3c_dip.gd"

var REB := {"base": 0.6, "lowSec": 1.4, "war": 0.7, "need": 100, "minDead": 20, "takeRate": 0.25, "takeMin": 2, "takeMax": 6}
func rebelTurn() -> void:
	for D in G.nations:
		if D.alive: continue
		var home := []
		for t in G.terrs:
			if t.get("home") == D.id and t.owner >= 0 and t.owner != D.id: home.append(t)
		if home.size() < 2: continue
		var low := 0
		var war := 0
		for t in home:
			if t.sec < 50: low += 1
			if inWar(t.owner): war += 1
		D.rebel = clamp_f(D.get("rebel", 0) + REB.base + float(low) / home.size() * REB.lowSec + float(war) / home.size() * REB.war, 0, REB.need)
		if D.rebel >= REB.need and G.turn - D.get("diedAt", 0) >= REB.minDead:
			var sd = rebelSeed(home)
			if sd == null: continue
			var X: int = sd.owner
			var near := {}
			for t in home:
				if t.owner == X: near[t.id] = true
			var guard := 0
			for a in NAT(X).armies:
				if a == null: continue
				var hit: bool = near.has(a.at)
				if not hit:
					for n in roadNbrs(a.at):
						if near.has(n.to):
							hit = true
							break
				if hit: guard += total(a.t)
			var levy := 0.0
			for t in home: levy += t.pop
			levy *= REB.takeRate * 0.18
			D.rebelWait = D.get("rebelWait", 0) + 1
			if inWar(X) or guard < levy * 1.5 or D.rebelWait >= 15:
				D.rebelWait = 0
				reviveNation(D, home)
func rebelSeed(home: Array):
	for t in home:
		if t.get("homeCap", false) and not t.cap: return t
	var c := []
	for t in home:
		if not t.cap: c.append(t)
	if c.is_empty(): return null
	c.sort_custom(func(x, y): return x.dev > y.dev if x.dev != y.dev else x.pop > y.pop)
	return c[0]
func reviveNation(D: Dictionary, home: Array) -> void:
	var seed = rebelSeed(home)
	if seed == null: return
	var X: int = seed.owner
	var n := int(clamp_f(round(home.size() * REB.takeRate), REB.takeMin, REB.takeMax))
	var take := [seed]
	var seen := {seed.id: true}
	var i := 0
	while i < take.size() and take.size() < n:
		for nb in roadNbrs(take[i].id):
			var t := T(nb.to)
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
	var arm := []
	arm.resize(ARMY_MAX)
	D.armies = arm; ARMY_REV += 1
	D.gens = []
	var pop := 0.0
	for t in take: pop += t.pop
	var levy := int(round(pop * 0.18))
	var g := mkGen(G, D, randomPts())
	var a0 := mkArmy(D.id, 0, seed.id)
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
	var names := []
	for t in take: names.append(t.name)
	var msg := "%s、旧領 %s で蜂起し復活 — %s と独立戦争" % [D.name, "・".join(names), NAT(X).name]
	logMsg(msg, "war")
	chron(msg, D.id, "fall")
	dipReport("revolt", D.id, X, true, "旧領の民が立ち上がった（%d領地・兵 %s）" % [take.size(), fmt(levy)])
	nations_changed.emit()
	invalidateSupply()
signal nations_changed
func nearestOwnTerr(n: int, from: int) -> int:
	var b := bfsFrom(from)
	var best := from
	var bd := INF
	for t in G.terrs:
		if t.owner == n and bhas(b, t.id) and b.d[t.id] < bd:
			bd = b.d[t.id]
			best = t.id
	return best

# ---------- CPU の戦略：戦う前に「相手の陣営ごと」の力を見積もる ----------
func smartAI(nid: int) -> bool: return not G.has("abTest") or G.abTest == null or G.abTest.get(nid, false)
func busyFrac(o: int) -> float:
	var foe := 0.0
	for x in G.nations:
		if x.alive and x.id != o and atWar(o, x.id) and nationsAdjacent(o, x.id): foe += nationPower(x.id)
	return clamp_f(foe / max(1.0, nationPower(o) + foe), 0, 0.6) if foe else 0.0
func defCoalition(a: int, b: int) -> float:
	var p := nationPower(b) * (1 - busyFrac(b) * 0.6)
	var seen := {a: true, b: true}
	var Fb = facOf(b)
	if Fb != null:
		for m in Fb.members:
			if not seen.has(m) and NAT(m).alive and not sameFaction(m, a):
				seen[m] = true
				p += nationPower(m) * (0.8 if natNear(m, a) else 0.35)
	for id in campOf(b):
		if seen.has(id) or not NAT(id).alive or atWar(id, a) or isAlly(id, a): continue
		var bound := isVassal(id, b) or isVassal(b, id)
		if not bound and (pactLeft(id, a) > 0 or not natNear(id, a)): continue
		seen[id] = true
		p += nationPower(id) * 0.8
	return max(1.0, p)
func atkCoalition(a: int, b: int) -> float:
	var p := nationPower(a)
	var seen := {a: true, b: true}
	var Fa = facOf(a)
	if Fa != null:
		for m in Fa.members:
			if not seen.has(m) and NAT(m).alive and favorOf(m, a) >= 50 and natNear(m, b) and pactLeft(m, b) <= 0 and not isAlly(m, b):
				seen[m] = true
				p += nationPower(m) * 0.5
	for id in campOf(a):
		if seen.has(id) or not NAT(id).alive or isAlly(id, b): continue
		var bound := isVassal(id, a) or isVassal(a, id)
		if not bound and (favorOf(id, a) < 45 or not natNear(id, b) or pactLeft(id, b) > 0): continue
		seen[id] = true
		p += nationPower(id) * (0.8 if bound else 0.5)
	return p
func cpuDiplomacy(nid: int) -> void:
	var na := NAT(nid)
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
	var myTgt := {}
	for d in desiresOf(nid):
		if DESIRE[d.k].war: myTgt[desireNat(d)] = true
	var myWars := []
	for c in G.nations:
		if c.alive and atWar(nid, c.id): myWars.append(c.id)
	_tp("drift")
	await yieldMaybe()
	# 好感度の自然変動
	for o in G.nations:
		if o.id == nid or not o.alive: continue
		var st := relState(nid, o.id)
		var dvs = desireVs(o.id, nid)
		var aimsMe: bool = st != "war" and dvs != null and DESIRE[dvs.k].war
		var sameTgt := false
		if st != "war" and natNear(nid, o.id):
			for d in desiresOf(o.id):
				if DESIRE[d.k].war and myTgt.has(desireNat(d)):
					sameTgt = true
					break
		var common := false
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
		var f := favorOf(nid, o.id)
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
		var mine := nationPower(nid)
		var theirs := nationPower(o.id)
		var minT: int = 3 if goalDone(nid, o.id) else (min(4, DIP.cpuPeaceTurns) if cpuDanger(nid) >= 1.1 else DIP.cpuPeaceTurns)
		if turns < minT: continue
		var fat: float = na.get("fatigue", 0)
		var dg := cpuDanger(nid)
		var Wp = warObj(nid, o.id)
		var nearCap: bool = Wp != null and surrenderProg(Wp, nid) >= surrenderLimit(nid) * 0.7
		var fascP: bool = na.get("ideo") == "fascism"
		# ファシズムの国は負けていても粘る（国力が相手の5割を切るまで講和に応じにくい）
		var wantPeace: bool = goalDone(nid, o.id) or nearCap or mine < theirs * (0.5 if fascP else 0.8) or fat >= DIP.fatiguePeace or dg >= 0.9 \
			or (dg >= 0.6 and not isTopThreat(o.id)) \
			or randf() < (0.08 + fat / 400.0 + P.peaceW + ((G.turn - Wp.t0) / 80.0 if Wp != null else 0.0)) * (0.4 if fascP else 1.0)
		if not wantPeace: continue
		var terms := cpuPeaceTerms(nid, o.id)
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
		var common := false
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
		var sm2 := smartAI(nid)
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
	var danger := cpuDanger(nid)
	if danger >= 1.0: return
	if not hoiWarOK(nid): return
	if na.food <= 0: return
	if smartAI(nid):
		var ownN := 0
		for t in ownList(nid): ownN += 1
		var goalT: float = clamp_f(3500 + ownN * 700, 3500, 34000) * P.goal
		if nationTroops(nid) < goalT * 2: return
	var des := desiresOf(nid)
	var wantWar := false
	var guarding := false
	var fasc0: bool = na.persona == "fascism"
	for d in des:
		# 富国の望みがあると戦わない（ファシズムの国と、世界の緊張が高い時は別）
		if d.k == "prosper" and not fasc0 and tension() < 60: return
		if DESIRE[d.k].war or d.k == "protect": wantWar = true
		if d.k == "guard": guarding = true
	var chanceMul: float = DES.warChanceMul if wantWar else (0.4 if guarding else (DES.noWishMul if G.nations.size() > 16 else 0.8))
	var fasc: bool = na.persona == "fascism"
	if randf() > DIP.cpuWarChance.get(na.persona, 0.2) * (max(0.7, crowdMul()) if fasc else crowdMul()) * (max(1.0, chanceMul) if fasc else chanceMul) * (1.0 + tension() / 35.0): return
	var mine := nationPower(nid)
	var ambition: float = min(DIP.cpuAmbitionMax, G.turn * DIP.cpuAmbition)
	var needW: float = DIP.cpuWarNeed.get(na.persona, 34)
	var cand := []
	var topT = topThreat()
	for o in G.nations:
		if o.id == nid or not o.alive or not canPrepare(nid, o.id): continue
		if not nationsAdjacent(nid, o.id): continue
		var dv = desireVs(nid, o.id)
		var sm := smartAI(nid)
		var th: float = defCoalition(nid, o.id) if sm else max(1.0, nationPower(o.id))
		var mineC: float = atkCoalition(nid, o.id) if sm else mine
		# 守りを固めたい時は、望みのある相手だけを狙う（ファシズムの国は、相手より1.3倍以上強ければ構わず狙う）
		if guarding and dv == null and not (fasc0 and mineC >= th * 1.3): continue
		var cb := hasCB(nid, o.id)
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
	var n := 0
	for x in G.nations:
		if x.alive: n += 1
	return min(1.0, pow(10.0 / max(1, n), 0.65))
func cpuPeaceTies(nid: int, P: Dictionary) -> void:
	var war := inWar(nid)
	if tradePartners(nid).size() < TRADE.max and randf() < 0.12 + P.tradeW / 150.0:
		var cs := []
		for x in G.nations:
			if x.alive and x.id != nid and tradeReason(nid, x.id) == "" and favorOf(nid, x.id) >= tradeNeed(nid) - 5: cs.append(x)
		cs.sort_custom(func(x, y): return favorOf(x.id, nid) > favorOf(y.id, nid))
		if cs.size():
			var o = cs[0]
			if favorOf(o.id, nid) >= tradeNeed(o.id): makeTrade(nid, o.id)
	if P.pactW > -20 and randf() < 0.25 + P.pactW / 80.0:
		var mine := nationPower(nid)
		var cs2 := []
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
	var na := NAT(nid)
	if na.has("ideo") and na.ws < wsNeedOf(na) - 10: return
	if na.gold < CASUS.fabGold + 4000: return
	for o in G.nations:
		if o.alive and fabLeft(nid, o.id) > 0: return
	for d in desiresOf(nid):
		if not DESIRE[d.k].war: continue
		var x := desireNat(d)
		if x >= 0 and NAT(x).alive and canPrepare(nid, x) and nationsAdjacent(nid, x) and not hasCB(nid, x) and mine >= nationPower(x) * 1.1:
			startFabricate(nid, x)
			return
	var cs := []
	for x in G.nations:
		if x.alive and x.id != nid and canPrepare(nid, x.id) and nationsAdjacent(nid, x.id) \
				and not hasCB(nid, x.id) and favorOf(nid, x.id) < 45 and mine >= nationPower(x.id) * 1.25:
			cs.append(x)
	cs.sort_custom(func(x, y): return nationPower(x.id) < nationPower(y.id))
	if cs.size(): startFabricate(nid, cs[0].id)
func cpuVassal(nid: int, lord: int) -> void:
	var na := NAT(nid)
	if na.get("unrest", 0) < DIP.unrestMax: return
	var pw := nationPower(nid) / max(1.0, nationPower(lord))
	var lordWar := 0
	for o in G.nations:
		if o.alive and atWar(lord, o.id) and o.id != nid: lordWar += 1
	var ch := 0.12 + clamp_f(pw - 0.5, 0, 1.2) * 0.5 + lordWar * 0.12
	if na.persona == "aggr" or na.persona == "fascism": ch += 0.12
	if na.persona == "econ" or na.persona == "neutral": ch -= 0.06
	if hasDesire(nid, "indep"): ch += 0.15
	if randf() < ch: startRevolt(nid)
func cpuVassalOffer(nid: int) -> void:
	if inCalm(): return
	var warring := inWar(nid)
	if not warring and wildCount() > G.terrs.size() * 0.15: return
	if randf() > DIP.cpuVassalAsk: return
	var cand := []
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
var HOP_KEY := ""
var HOPS := []
func natHops(a: int, b: int) -> int:
	if a == b: return 0
	if a < 0 or b < 0: return 99
	var k := str(G.get("ownRev", 0)) + "_" + str(G.edges.size())
	if HOP_G != G or HOP_KEY != k:
		var n: int = G.nations.size()
		var adj := []
		for i in n: adj.append({})
		for e in G.edges:
			var oa: int = T(e.a).owner
			var ob: int = T(e.b).owner
			if oa >= 0 and ob >= 0 and oa != ob:
				adj[oa][ob] = true
				adj[ob][oa] = true
		HOPS = []
		for s0 in n:
			var d := []
			d.resize(n)
			d.fill(99)
			d[s0] = 0
			var q := [s0]
			var i := 0
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
var ADJ_KEY := ""
var ADJ_G = null
var ADJ_SET := {}
func nationsAdjacent(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0: return false
	var k := str(G.get("ownRev", 0)) + "_" + str(G.edges.size())
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
	var opt := peaceOptions(a, b)
	var goal := warGoal(a, b)
	var terms := {"cede": 0, "gold": 0, "vassal": false}
	if goal == "vassal" and opt.vassal: terms.vassal = true
	else:
		var want := 3 if goal == "three" else (2 if goal == "capital" else 1)
		terms.cede = min(opt.cede, want)
		if opt.gold and randf() < 0.6: terms.gold = opt.gold
	if cpuDanger(a) >= 1.0 or NAT(a).get("fatigue", 0) >= DIP.fatiguePeace:
		terms.cede = min(terms.cede, 1)
		terms.vassal = false
	return terms
