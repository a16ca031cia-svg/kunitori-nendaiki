# 外交 続き（元 4570〜5097）：講和会議・宣戦・和平・同盟・知らせ・従属
extends "res://scripts/core/k3_dip.gd"

## 戦争の終わり：講和会議。opts.winner = 勝った陣営の配列（なければ現状のままの講和）、opts.full = 相手陣営が全員降伏した
func endWar(W, opts) -> Array:
	if W == null or not G.wars.has(W.id): return []
	if opts == null: opts = {}
	var lines := []
	var got := {}
	var back := {}
	var winner = opts.get("winner")
	var full: bool = opts.get("full", false)
	for S_ in [W.sA, W.sB]:
		var O: Array = W.sB if S_ == W.sA else W.sA
		var winning: bool = winner != null and winner == S_
		var losing: bool = winner != null and winner != S_
		if losing: continue
		var mem := []
		for n in S_:
			if NAT(n).alive: mem.append(n)
		mem.sort_custom(func(x, y): return W.sc.get(x, 0) > W.sc.get(y, 0))
		if mem.is_empty(): continue
		var pool := {}
		for t in G.terrs:
			if t.get("wTag") == W.id and O.has(t.get("wOrig")) and S_.has(t.owner): pool[t.id] = t
		if winning and full:
			for t in G.terrs:
				if O.has(t.owner) and NAT(t.owner).alive and not t.cap: pool[t.id] = t
		var budget := {}
		var mine := {}
		for n in mem:
			budget[n] = W.sc.get(n, 0) * (1.0 if winning else 0.6)
			mine[n] = {}
		for round_ in 400:
			if pool.is_empty(): break
			var any := false
			for n in mem:
				var best = null
				var bs := -INF
				var bc := 0.0
				for t in pool.values():
					var held: bool = t.owner == n
					var cost: float = vpOf(t) * VP_K * (0.5 if held else 1.0)
					if cost > budget[n]: continue
					var adj := held
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
		var parts := []
		for n in got: parts.append("%s %d領地" % [NAT(n).name, got[n]])
		lines.append("講和会議：" + "、".join(parts))
	if back.size():
		var parts2 := []
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
	var sa := []
	var sb := []
	for n in W.sA:
		if NAT(n).alive: sa.append(NAT(n).name)
	for n in W.sB:
		if NAT(n).alive: sb.append(NAT(n).name)
	var head: String = ("%s 陣営の勝利" % NAT(W.a if winner == W.sA else W.b).name) if winner != null else "現状のままの講和"
	var msg := "%s と %s の戦争が終わる — %s（%s 対 %s）" % [NAT(W.a).name, NAT(W.b).name, head, "・".join(sa), "・".join(sb)]
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
	var wasAlly := isAlly(a, b)
	var why := cbOf(a, b)
	var just := warJust(a, b)
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
	var msg := "%s が %s に宣戦布告（目標：%s）" % [NAT(a).name, NAT(b).name, goalLabel(a, b)]
	if newsworthy([a, b]): headline("%s、%s に宣戦布告" % [natLabel(a), natLabel(b)], "目標：%s" % goalLabel(a, b))
	logMsg(msg, "war")
	chron(msg, a, "dip")
	var note := ("同盟を破っての開戦／" if wasAlly else "") + (("大義：" + why) if why != "" else "大義なき開戦（国内の治安・諸国の評判が大きく下がる）") + "／目標：" + goalLabel(a, b)
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
	var msg := "%s と %s が和平を結ぶ" % [NAT(a).name, NAT(b).name]
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
	var msg := "%s と %s が同盟を結ぶ" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "good")
	chron(msg, a, "dip")
	if not forced:
		dipReport("ally", a, b, true, "期限 %dターン" % DIP.allyTurns)
		shareWars(a, b)
func renewAlly(a: int, b: int) -> bool:
	if not isAlly(a, b): return false
	G.dip.allyUntil[a][b] = G.turn + DIP.allyTurns; G.dip.allyUntil[b][a] = G.turn + DIP.allyTurns
	var msg := "%s と %s が同盟を更新" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "good")
	chron(msg, a, "dip")
	dipReport("renew", a, b, true, "期限 %dターン" % DIP.allyTurns)
	return true
func expireAlly(a: int, b: int) -> void:
	if not isAlly(a, b): return
	setRel(a, b, "peace")
	G.dip.pass[a][b] = false; G.dip.pass[b][a] = false
	var msg := "%s と %s の同盟が期限切れ" % [NAT(a).name, NAT(b).name]
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
		var bound := false
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
	var msg := "%s が %s との戦争に加わる" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "war")
	chron(msg, a, "dip")
	dipReport("join", a, b, true, why)
const WAR_SIDE_MAX := 4
func _joinCamp(x: int, y: int, attacker: bool) -> void:
	for id in campOf(x):
		if id == x or id == y: continue
		if not NAT(id).alive or atWar(id, y): continue
		if isAlly(id, y) or isVassal(id, y) or isVassal(y, id): continue
		var bound := isVassal(id, x) or isVassal(x, id)
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
	var msg := "%s が %s との同盟を破棄" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "war")
	chron(msg, a, "dip")
	dipReport("unally", a, b, true, "")
func grantPass(owner: int, to: int) -> void:
	G.dip.pass[owner][to] = true
	var msg := "%s が %s に領内通行を許可" % [NAT(owner).name, NAT(to).name]
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
	var just := warJust(a, b)
	addFavor(b, a, DIP.prepFavor)
	for c in G.nations:
		if c.id == a or c.id == b or not c.alive: continue
		addFavor(c.id, a, DIP.prepOthers * just)
	addThreat(a, DIP.threatPrep * (DIP.calmThreatMul if inCalm() else 1.0) * just)
	var msg := "%s が %s に対し軍備を進めています" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "war")
	chron(msg, a, "dip")
	dipReport("prep", a, b, true, ("大義：" + cbOf(a, b)) if hasCB(a, b) else "大義なし — 宣戦すれば国内の治安と諸国の評判が大きく下がる")
	return true
func cancelWarPrep(a: int, b: int, quiet := false) -> void:
	if not isTense(a, b): return
	G.dip.state[a][b] = "peace"; G.dip.state[b][a] = "peace"
	G.dip.prepBy[a][b] = -1; G.dip.prepBy[b][a] = -1
	if quiet: return
	var msg := "%s と %s の緊張が解ける" % [NAT(a).name, NAT(b).name]
	logMsg(msg, "good")
	chron(msg, a, "dip")
func dipTurn() -> void:
	var n: int = G.nations.size()
	for a in n:
		for b in range(a + 1, n):
			if not isAlly(a, b) or isVassal(a, b) or isVassal(b, a): continue
			if allyUntil(a, b) and G.turn >= allyUntil(a, b):
				var keep := favorOf(a, b) >= DIP.allyRenewMin and favorOf(b, a) >= DIP.allyRenewMin and natNear(a, b) and ideoCompat(a, b)
				if keep: renewAlly(a, b)
				else: expireAlly(a, b)
	vassalTurn()
	fabTurn()
	peaceTiesTurn()
	if G.turn == DIP.calmTurns:
		var msg := "平穏の時代が終わる — 諸国が牙を研ぎ始める"
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
var DIPQ := []
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
	var pa := nationPower(a)
	var pb: float = max(1.0, nationPower(b))
	var need: float = DIP.vassalWarRatio if atWar(a, b) else DIP.vassalRatio
	return pa / pb >= need
func vassalAccept(a: int, b: int) -> bool:
	if isMajor(NAT(b)) and not atWar(a, b): return false
	var ratio := nationPower(a) / max(1.0, nationPower(b))
	var war := atWar(a, b)
	var fav := favorOf(b, a)
	var nb2 := NAT(b)
	var sc: float = (ratio - 1) * 45 + (nb2.get("fatigue", 0) * 0.6 if war else 0.0) + (fav - DIP.vassalFavor) * 0.4
	if war: sc += 18
	sc += cpuDanger(b) * 30
	if not war and fav < DIP.vassalFavor: sc -= 40
	var terr := 0
	for t in G.terrs:
		if t.owner == b: terr += 1
	if terr <= 2: sc += 25
	return sc >= 30
func makeVassal(lord: int, sub: int, note := "") -> void:
	var L := NAT(lord)
	var S_ := NAT(sub)
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
	var msg := "%s が %s の属国となる" % [S_.name, L.name]
	logMsg(msg, "war")
	chron(msg, lord, "gov")
	dipReport("vassal", lord, sub, true, note)
	shareWars(lord, sub)
	invalidateSupply()
func freeVassal(sub: int, why := "") -> void:
	var S_ := NAT(sub)
	if S_.lord == null: return
	var lord: int = S_.lord
	S_.lord = null; S_.unrest = 0
	if NAT(lord).alive and isAlly(lord, sub):
		G.dip.allyUntil[lord][sub] = G.turn + DIP.allyTurns; G.dip.allyUntil[sub][lord] = G.turn + DIP.allyTurns
	var msg := "%s が独立を取り戻す%s" % [S_.name, ("（" + why + "）") if why != "" else ""]
	logMsg(msg, "good")
	chron(msg, sub, "gov")
func startRevolt(sub: int) -> void:
	var S_ := NAT(sub)
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
	var msg := "%s が %s に反旗を翻す — 独立戦争" % [S_.name, NAT(lord).name]
	logMsg(msg, "war")
	chron(msg, sub, "fall")
	dipReport("revolt", sub, lord, true, "%dターンのあいだ 攻撃+%d%%・防御+%d%%・生産+%d%%／%dターンは再び属国にならない" % [DIP.revoltTurns, int(round(DIP.revoltAtk * 100)), int(round(DIP.revoltDef * 100)), int(round(DIP.revoltProd * 100)), DIP.revoltFree])
	joinWarByPact(sub, lord)
	invalidateSupply()
