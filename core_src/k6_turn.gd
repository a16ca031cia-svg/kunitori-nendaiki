# ターン進行・生産・出来事・節目・CPUの軍（元 6439〜7218）
extends "res://scripts/core/k5_econ.gd"

signal phase_changed(nid, sub: String)   # nid=null で消す
signal refreshed                         # 画面を描き直す
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

var YIELD_AT := 0
var BEAT_SPENT := 0
var BEAT_MAX := 2500
var PROF := {}
var _TPT := 0
var _TPL := ""
func _tp(l: String) -> void:
	var now := Time.get_ticks_usec()
	if _TPL != "": PROF["dip:" + _TPL] = PROF.get("dip:" + _TPL, 0) + now - _TPT
	_TPT = now
	_TPL = l
func endTurn() -> void:
	BEAT_SPENT = 0
	if UI.busy or G == null or G.over != null: return
	UI.busy = true
	var _t0 = Time.get_ticks_msec()
	PROF = {}
	for n in G.nations.size():
		if G.over != null: break
		if not NAT(n).alive: continue
		var _a = Time.get_ticks_usec()
		setPhase(n, "")
		var _b = Time.get_ticks_usec()
		var pw := phaseWait(n)
		if pw > 0:
			PROF["n:pw"] = PROF.get("n:pw", 0) + 1000
			await sleep_ms(pw)
			YIELD_AT = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - YIELD_AT > 120:
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
	production()
	settleTurn()
	for na in G.nations:
		for a in na.armies:
			if a != null: a.moved = false
	siegeTurn()
	randomEvent()
	var nn: int = G.nations.size()
	for a in nn:
		for b2 in nn:
			if a != b2 and G.dip.score[a][b2]: G.dip.score[a][b2] *= WAR.decay
	dipTurn()
	decayThreat()
	checkMilestones()
	recordHistory()
	refreshSupply(true)
	G.turn += 1
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
	var tradeG := []
	for n in G.nations: tradeG.append(tradeIncome(n.id))
	var ownBy := {}
	for t in G.terrs:
		if t.owner >= 0:
			if not ownBy.has(t.owner): ownBy[t.owner] = []
			ownBy[t.owner].append(t)
	for na in G.nations:
		if not na.alive: continue
		var own: Array = ownBy.get(na.id, [])
		var war := inWar(na.id)
		var starve := isStarving(na)
		var fat := fatigueMul(na)
		var pGold := polMul(na, "gold")
		var pFood := polMul(na, "food")
		var pTroop := polMul(na, "troop")
		var gold := 0.0
		var food := 0.0
		var levy := 0.0
		var add := {"inf": 0.0, "spe": 0.0, "arc": 0.0, "cav": 0.0}
		var room2: float = max(0, stockCap(na.id) - total(na.stock))
		for t in own:
			var base: float = (CFG.chaosMul if t.chaos > 0 else 1.0) * secMul(t) * fat
			var gm: float = base * (1 + linkBonus(t)) * pGold
			var tm: float = base * (0.5 if starve else 1.0) * pTroop
			if t.type == "city": gold += t.pop * CFG.taxRate * gm
			var room: float = levyRoom(t)
			for b in t.bld:
				if not b: continue
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
		if na.get("badHarv", 0) > 0:
			gold *= 0.6; food *= 0.6; na.badHarv -= 1
		na.goldIn = int(round(gold))
		na.tradeIn = tradeG[na.id]
		gold += na.tradeIn
		if na.get("revoltBuff", 0) > 0: gold *= 1 + DIP.revoltProd
		var lord = lordOf(na.id)
		if lord != null:
			var pay := int(round(gold * DIP.tribute))
			gold -= pay
			NAT(lord).gold += pay
			na.tribute = pay
		else: na.tribute = 0
		na.gold += int(round(gold))
		na.levy = int(round(levy))
		for k in TK: na.stock[k] += int(round(add[k]))
		var need := foodNeed(na.id)
		na.foodIn = int(round(food))
		na.foodNeed = need
		na.food = int(clamp_f(round(na.food + food - need), -3000, foodCap(na.id)))
		for t in own: updateTerr(t, na, war)
		na.fatigue = clamp_f(na.get("fatigue", 0) + (CFG.fatWar if war else CFG.fatPeace), 0, 100)
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
	var r := []
	for t in G.terrs:
		if t.owner == nid: r.append(t)
	return r
func _evRun(na: Dictionary, ev: Dictionary, i: int) -> String:
	var own := _ownOf(na.id)
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
			var cand := []
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
			var pts := randomPts()
			pts[pick(GEN_ABIL).k] += 1
			pts[pick(GEN_ABIL).k] += 1
			var g := mkGen(G, na, pts)
			return "%s が旗下に加わった" % g.name
		"gen1": return "将は静かに去っていった"
	return ""
func randomEvent() -> void:
	if randf() > CFG.eventRate: return
	var alive := []
	for n in G.nations:
		if n.alive: alive.append(n)
	if alive.is_empty(): return
	var na: Dictionary = pick(alive)
	if _ownOf(na.id).is_empty(): return
	var pool := []
	for ev in EVENTS:
		for i in int(round(ev.w * 10)): pool.append(ev)
	var ev: Dictionary = pick(pool)
	var i := cpuEventChoice(na, ev)
	var res := _evRun(na, ev, i)
	var o: Dictionary = ev.opts[i]
	var msg := "%s — %s：%s／%s" % [ev.n, na.name, o.n, res]
	logMsg("【出来事】" + msg)
	chron("%s — %s（%s）" % [ev.n, o.n, res], na.id, "event")
func cpuEventChoice(na: Dictionary, ev: Dictionary) -> int:
	var rich: bool = na.gold > 20000
	var poor: bool = na.gold < 6000
	if not _evOk(na, ev, 0): return 1
	if ev.k == "merc": return 0 if rich and (na.persona == "aggr" or cpuDanger(na.id) >= 0.8) else 1
	if ev.k == "gen": return 0 if na.gens.size() < 6 and rich else 1
	if ev.k == "good": return 0 if na.food < foodNeed(na.id) * 6 else 1
	if poor: return 1
	return 0 if na.persona == "econ" or na.persona == "def" or rich else 1

# ---------- 年代記の節目 ----------
const TERR_MILE := [5, 10, 15, 20, 30, 40, 50, 60, 70]
const WIN_MILE := [5, 10, 20, 30, 50]
func checkMilestones() -> void:
	var cnt := {}
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
				var key := "w%d_%d" % [a.idx, m]
				if a.get("wins", 0) >= m and not na.mile.has(key):
					na.mile[key] = 1
					chron("%s %s、通算 %d 勝" % [na.name, a.name, m], na.id, "mile")
			var g = genOf(na, a.gen)
			var tot := total(a.t)
			if g == null: continue
			if tot > g.get("maxLed", 0): g.maxLed = tot
			if tot >= 8000 and tot >= na.get("recLed", 0) * 1.25:
				na.recLed = tot
				chron("%s 将軍が最大兵力 %s を率いる" % [g.name, fmt(tot)], na.id, "mile")
func recordHistory() -> void:
	var cnt := {}
	for t in G.terrs: cnt[t.owner] = cnt.get(t.owner, 0) + 1
	var o := []
	var p := []
	for n in G.nations:
		o.append(cnt.get(n.id, 0))
		p.append(nationPower(n.id))
	G.hist.append({"t": G.turn, "o": o, "p": p})
	if G.hist.size() > 600:
		var h := []
		for i in G.hist.size():
			if i % 2 == 0: h.append(G.hist[i])
		G.hist = h

# ---------- CPU ----------
func prodPerTurn(nid: int) -> int:
	var n := 0
	for t in G.terrs:
		if t.owner != nid: continue
		for b in t.bld:
			var o = BLD_OUT.get(b) if b else null
			if o == null: continue
			for k in TK:
				if o.has(k): n += o[k]
	return n
func powerOf(list: Array, t, isDef: bool) -> float:
	if list.is_empty(): return 0.0
	var s := sideStats(list, t if t != null else T(list[0].at), isDef)
	return s.tot * (s.def if isDef else s.atk) / 100.0
var FOCUS_CACHE := {}
var SPROG_MEMO := {}
func stratBonus(nid: int, t: Dictionary) -> float:
	var b := 0.0
	var W = warObj(nid, t.owner)
	if t.get("wTag") != null and t.get("wOrig") == nid: b += 30
	if W != null:
		b += vpOf(t) * 2
		var foe: int = t.wOrig if t.get("wTag") == W.id and t.get("wOrig") != null else t.owner
		var sd = sideOf(W, foe)
		if sd != null and not sd.has(nid):
			var k := "%d_%d_%d_%d" % [W.id, foe, G.turn, G.get("ownRev", 0)]
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
	var bs := INF
	for o in G.nations:
		if not o.alive or o.id == nid or not atWar(nid, o.id) or not nationsAdjacent(nid, o.id): continue
		var v := nationPower(o.id) * (1 - busyFrac(o.id) * 0.5)
		if v < bs:
			bs = v
			best = o.id
	return best
func cpuObjective(nid: int, list: Array, bfsOf: Dictionary):
	if not inWar(nid): return null
	var cands := []
	var smart := smartAI(nid)
	if smart: FOCUS_CACHE[nid] = focusFoe(nid)
	var wantT := {}
	for d in desiresOf(nid):
		if d.get("t") != null: wantT[d.t] = true
	for t in G.terrs:
		if t.owner == nid or not atWar(nid, t.owner): continue
		var stage = null
		var sd := INF
		for nb in roadNbrs(t.id):
			if T(nb.to).owner != nid: continue
			var near := INF
			for a in list:
				var dd = bget(bfsOf[a.idx], nb.to)
				if dd != null and dd < near: near = dd
			if near < sd:
				sd = near
				stage = nb.to
		if stage == null or sd == INF: continue
		var gar := []
		for x in armiesAt(t.id):
			if total(x.t) > 0: gar.append(x)
		var dp := powerOf(gar, t, true) if gar.size() else 0.0
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
	var bd := INF
	for t in G.terrs:
		if t.owner != nid: continue
		var d = bget(bs, t.id)
		if d == null: continue
		var w: float = d - (1 if t.type == "city" else 0) - (1 if t.cap else 0)
		if w < bd:
			bd = w
			best = t.id
	return best
func cpuPolicy(nid: int, P: Dictionary) -> void:
	var na := NAT(nid)
	if polLeft(na) > 0: return
	var war := inWar(nid)
	var danger := cpuDanger(nid)
	var bal := foodGain(nid) - foodNeed(nid)
	var want := "none"
	if bal < 0 and na.food < foodNeed(nid) * 5: want = "agri"
	elif danger >= 1.0: want = "total"
	elif war: want = "total" if P.army > 0 else "mil"
	elif hasDesire(nid, "guard"): want = "mil"
	elif hasDesire(nid, "prosper"): want = "trade" if na.persona == "econ" else "civil"
	elif na.persona == "econ": want = "trade"
	elif na.persona == "def": want = "civil"
	elif na.persona == "aggr": want = "mil"
	else: want = "trade" if randf() < 0.5 else "civil"
	if want != na.get("policy", "none"): setPolicy(nid, want)

func _bldN(t: Dictionary) -> int:
	var n := 0
	for b in t.bld:
		if b: n += 1
	return n
func _hasTroopBld(t: Dictionary) -> bool:
	for b in t.bld:
		if TK.has(b): return true
	return false
func _troopBldN(t: Dictionary) -> int:
	var n := 0
	for b in t.bld:
		if TK.has(b): n += 1
	return n
func _foeArmyAt(tid: int, nid: int) -> bool:
	for x in armiesAt(tid):
		if x.owner != nid and atWar(nid, x.owner) and total(x.t) > 0: return true
	return false
func _setBld(t: Dictionary, slot: int, k: String) -> void:
	while t.bld.size() <= slot: t.bld.append(null)
	t.bld[slot] = k

func cpuTurn(nid: int) -> void:
	refreshSupply()
	var na := NAT(nid)
	if not na.alive: return
	var own := _ownOf(nid)
	if own.is_empty(): return
	var P: Dictionary = PERSONA.get(na.persona, PERSONA.bal)
	var _pt := [Time.get_ticks_usec(), "方針"]
	var phase := func(msg: String):
		var now := Time.get_ticks_usec()
		PROF[_pt[1]] = PROF.get(_pt[1], 0) + now - _pt[0]
		_pt[0] = now
		_pt[1] = msg
		var shown = msg.get_slice(":", 0)
		setPhase(nid, P.n + ((" ／ " + shown) if shown != "" else ""))
	cpuPolicy(nid, P)
	phase.call("外交")
	cpuDiplomacy(nid)
	_tp("")
	await flushDip()
	if not na.alive: return
	phase.call("内政")
	cpuSettle(nid)
	# --- 内政：建物 ---
	var mk := 0
	for t in own:
		if t.bld.has("market"): mk += 1
	var troopCap: float = clamp_f(3500 + own.size() * 700, 3500, 34000) * P.goal
	var war := inWar(nid)
	var glut: bool = total(na.stock) > troopCap * 4 and not war
	var cand := []
	for t in own:
		if _bldN(t) < t.dev: cand.append(t)
	cand.sort_custom(func(a, b): return a.dev > b.dev)
	var bal := foodGain(nid) - foodNeed(nid)
	var lowSec := 0
	for x in own:
		if x.sec < 45: lowSec += 1
	for t in cand:
		if na.gold < 2500: break
		var k := ""
		if bal <= 0 or na.food < 800: k = "farm"
		elif lowSec > own.size() * 0.25 and randf() < 0.6: k = "gov"
		elif t.type == "city" and mk < max(1, own.size() * P.mkt): k = "market"
		elif t.type == "city" and popRatio(t) > 0.9 and randf() < 0.35 + P.mkt * 0.3: k = "house"
		else:
			var r := randf()
			var acc := 0.0
			k = "inf"
			for kk in TK:
				acc += P.mix[kk]
				if r <= acc:
					k = kk
					break
			if t.type == "city" and randf() < P.mkt * 0.6: k = "market"
		if TK.has(k) and levyRoom(t) < 900: k = "house" if t.type == "city" else "farm"
		if TK.has(k) and glut: k = "market" if t.type == "city" else "farm"
		if BLD[k].get("cityOnly", false) and t.type == "fort": k = "farm"
		if na.gold < BLD[k].cost: continue
		var slot := -1
		for i in t.dev:
			if i >= t.bld.size() or not t.bld[i]:
				slot = i
				break
		if slot < 0: continue
		na.gold -= BLD[k].cost
		_setBld(t, slot, k)
		if k == "market": mk += 1
		if k == "farm": bal += CFG.farmOut * terrOf(t).food
	if glut and na.gold >= BLD.market.cost * 2:
		for t3 in own:
			if _hasTroopBld(t3):
				var i := -1
				for j in t3.bld.size():
					if TK.has(t3.bld[j]):
						i = j
						break
				var k2 := "market" if t3.type == "city" else "farm"
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
	var prosper := hasDesire(nid, "prosper")
	var reserve: float = max(P.devG * (0.4 if prosper else 1.0), na.get("goldIn", 0) * (3 if prosper else 6))
	var devList := []
	for t in own:
		if t.dev < 5 and not t.get("devP", false): devList.append(t)
	devList.sort_custom(func(a, b):
		if a.cap != b.cap: return a.cap
		if (a.type == "city") != (b.type == "city"): return a.type == "city"
		if a.dev != b.dev: return a.dev < b.dev
		return a.pop > b.pop)
	var devMax: int = 1 + own.size() / 10
	var devN := 0
	for t in devList:
		if devN >= devMax or na.gold - DEV_COST[t.dev] < reserve: break
		na.gold -= DEV_COST[t.dev]
		t.devP = true
		devN += 1
	var rich: bool = na.gold > reserve * 1.3
	if na.gold > P.roadG * (0.5 if prosper else 1.0) and (rich or randf() < INFRA_RATE.get(na.persona, 0.12) * (2.5 if prosper else 1.0)):
		var myAt := {}
		for x in na.armies:
			if x != null: myAt[x.at] = true
		var front := {}
		for t in own:
			for nb in roadNbrs(t.id):
				var o: int = T(nb.to).owner
				if o >= 0 and o != nid and atWar(nid, o):
					front[t.id] = true
					break
		var score := func(t): return t.pop / 1500.0 + t.dev * 2 + (8 if t.cap else 0) + TERR_COST.get(t.terrain, 1) * 3 \
			+ (10 if front.has(t.id) else 0) + (4 if myAt.has(t.id) else 0) - t.get("infra", 1) * 4
		var lst := []
		for t in own:
			if t.get("infra", 1) < 3 and not t.get("infraP", false) and not t.get("infraBroke", 0): lst.append(t)
		lst.sort_custom(func(a, b): return score.call(a) > score.call(b))
		var nMax: int = 1 + own.size() / 20 if rich else 1
		var kk2 := 0
		for t in lst:
			if kk2 >= nMax: break
			var c: int = INFRA_COST[t.get("infra", 1) + 1]
			if na.gold - c < (reserve if rich else P.roadG * 0.5): break
			na.gold -= c
			t.infraP = true
			kk2 += 1
	# --- 将軍 ---
	var armed := 0
	for x in na.armies:
		if x != null: armed += 1
	if na.gens.size() < min(GEN_MAX, armed + 1) and na.gold > GEN_COST + 6000:
		na.gold -= GEN_COST
		mkGen(G, na, randomPts())
	# --- 軍団編成 ---
	phase.call("軍団の編成・補充")
	var maxA := int(clamp_f(2 + own.size() / 3 + P.army * 2, 1, ARMY_MAX))
	var stockTot := total(na.stock)
	var goalT: float = clamp_f(3500 + own.size() * 700, 3500, 34000) * P.goal
	if armed < maxA and stockTot > 3000:
		var slot: int = na.armies.find(null)
		if slot >= 0:
			var a := mkArmy(nid, slot, na.capital)
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
	# ============ 進軍：守りを固め、主目標に兵を集めて攻める ============
	var list := []
	for x in na.armies:
		if x != null and total(x.t) > 0: list.append(x)
	var danger := cpuDanger(nid)
	var foes := []
	for o in G.nations:
		if o.alive and atWar(nid, o.id): foes.append(o)
	var foeTerrs := []
	if foes.size():
		for t in G.terrs:
			if t.owner != nid and atWar(nid, t.owner): foeTerrs.append(t)
	var RK := {}
	var frontier := []
	for t in own:
		for nb in roadNbrs(t.id):
			if T(nb.to).owner != nid:
				frontier.append(t)
				break
	for t2 in frontier:
		var r := 0
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
	var hot := []
	for t in frontier:
		if RK[t.id] > 0: hot.append(t)
	if smartAI(nid) and foes.size():
		var cap := T(na.capital)
		if cap.owner == nid:
			var near2 := {cap.id: true}
			for nb in roadNbrs(cap.id):
				near2[nb.to] = true
				for nb2 in roadNbrs(nb.to): near2[nb2.to] = true
			var threat := false
			for id in near2:
				if _foeArmyAt(id, nid):
					threat = true
					break
			if threat:
				hot.erase(cap)
				hot.push_front(cap)
	var bfsOf := {}
	phase.call("進軍:経路")
	var bfsAt := {}
	for a in list:
		if not bfsAt.has(a.at): bfsAt[a.at] = bfsFrom(a.at, total(a.t), nid)
		bfsOf[a.idx] = bfsAt[a.at]
	phase.call("進軍:目標")
	var obj = cpuObjective(nid, list, bfsOf)
	phase.call("進軍:動かす")
	var guardRate := clamp_f(P.guard + clamp_f(danger, 0, 1.6) * DIP.guardDanger, 0.2, 0.9)
	if foes.size() and obj != null: guardRate = min(guardRate, 0.55)
	var nDef := int(round(list.size() * guardRate))
	if foes.size() and obj != null: nDef = min(nDef, max(0, list.size() - max(1, int(ceil(list.size() * 0.4)))))
	var guard := {}
	var freeA := list.duplicate()
	for t in hot:
		if guard.size() >= nDef: break
		var taken := false
		for x in armiesAt(t.id):
			if guard.has(x.idx) and x.owner == nid:
				taken = true
				break
		if taken: continue
		var bestA = null
		var bd := INF
		for a in freeA:
			var d = bget(bfsOf[a.idx], t.id)
			if d == null: continue
			if d < bd:
				bd = d
				bestA = a
		if bestA != null:
			guard[bestA.idx] = t.id
			freeA.erase(bestA)
	var order := list.duplicate()
	order.sort_custom(func(x, y):
		var sx := 0 if obj != null and x.at == obj.stage else 1
		var sy := 0 if obj != null and y.at == obj.stage else 1
		if sx != sy: return sx < sy
		return total(x.t) > total(y.t))
	var goal2 := goalT
	for a in order:
		if G.over != null: return
		if na.armies[a.idx] != a: continue
		if total(a.t) <= 0 or a.moved: continue
		if a.get("siege") != null:
			a.path = []
			continue
		var tot := total(a.t)
		UI.actArmy = a
		if not bfsOf.has(a.idx): bfsOf[a.idx] = bfsFrom(a.at, tot, nid)
		var bsA: Dictionary = bfsOf[a.idx]
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
		if tot < goal2 * 0.3 and total(na.stock) > goal2 * 0.3:
			var back = nearestOwnCity(a, bsA, nid)
			if back != null and back != a.at:
				var p = pathFrom(bsA, back)
				if p != null and p.size():
					a.path = p
					await advanceArmy(a)
					await cpuBeat(a)
					continue
		# 圧倒的な敵軍が隣に迫っていたら一歩下がる
		if smartAI(nid) and not T(a.at).cap and T(a.at).owner == nid:
			var foeA := []
			for nb in roadNbrs(a.at):
				for x in armiesAt(nb.to):
					if x.owner != nid and atWar(nid, x.owner) and total(x.t) > 0: foeA.append(x)
			if foeA.size():
				var here := []
				for x in armiesAt(a.at):
					if x.owner == nid and total(x.t) > 0: here.append(x)
				var thr := powerOf(foeA, T(a.at), false)
				var dfp := powerOf(here, T(a.at), true)
				if thr > dfp * 1.7:
					var bt = null
					var bsc := -INF
					for nb in roadNbrs(a.at):
						var u := T(nb.to)
						if u.owner != nid: continue
						var exposed := false
						for nb2 in roadNbrs(nb.to):
							if _foeArmyAt(nb2.to, nid):
								exposed = true
								break
						if exposed: continue
						var mineHere := 0.0
						for x in armiesAt(nb.to):
							if x.owner == nid: mineHere += total(x.t)
						var sc: float = (30 if u.cap else 0) + (15 if u.type == "fort" else 0) + mineHere / 1000.0
						if sc > bsc:
							bsc = sc
							bt = nb.to
					if bt != null:
						a.path = [bt]
						await advanceArmy(a)
						await cpuBeat(a)
						continue
		# 守備軍：持ち場を固める
		if guard.has(a.idx):
			var dst: int = guard[a.idx]
			if a.at == dst:
				a.path = []
				a.wait = 0
				continue
			var p2 = pathFrom(bsA, dst)
			if p2 != null and p2.size():
				a.path = p2
				await advanceArmy(a)
				await cpuBeat(a)
			continue
		# 補充待ち
		if T(a.at).owner == nid and tot < goal2 * 0.55 and total(na.stock) > 1000 and a.get("wait", 0) < 3:
			a.wait = a.get("wait", 0) + 1
			a.path = []
			continue
		# 隣に攻められる敵領地があれば取る
		var mine := powerOf([a], T(a.at), false)
		var best = null
		var bestScore := -1.0
		for nb in roadNbrs(a.at):
			var t := T(nb.to)
			if t.owner == nid or not atWar(nid, t.owner): continue
			var gar := []
			for x in armiesAt(nb.to):
				if total(x.t) > 0: gar.append(x)
			var help := []
			for x in armiesAt(a.at):
				if x != a and x.owner == nid and not x.moved and total(x.t) > 0: help.append(x)
			var dp := powerOf(gar, t, true) if gar.size() else 0.0
			var mineAll := powerOf([a] + help, T(a.at), false) if help.size() else mine
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
			await advanceArmy(a)
			await cpuBeat(a)
			continue
		# 主目標へ：集結地に集まってから攻める
		if obj != null:
			if a.at == obj.stage:
				var force := []
				for x in armiesAt(a.at):
					if x.owner == nid and not x.moved and total(x.t) > 0: force.append(x)
				var gar2 := []
				for x in armiesAt(obj.tid):
					if total(x.t) > 0: gar2.append(x)
				var dp2 := powerOf(gar2, T(obj.tid), true) if gar2.size() else 0.0
				var pw := powerOf(force, T(a.at), false) if force.size() else 0.0
				if force.has(a) and pw >= dp2 * P.atkTh:
					a.wait = 0
					a.path = [obj.tid]
					await advanceArmy(a)
					await cpuBeat(a)
					continue
				a.wait = a.get("wait", 0) + 1
				if a.wait >= 4 and pw >= dp2 * 1.05:
					a.wait = 0
					a.path = [obj.tid]
					await advanceArmy(a)
					await cpuBeat(a)
					continue
				a.path = []
				continue
			var p3 = pathFrom(bsA, obj.stage)
			if p3 != null and p3.size():
				a.wait = 0
				a.path = p3
				await advanceArmy(a)
				await cpuBeat(a)
				continue
		# 目標が無い／届かない：最寄りの敵拠点、なければ危ない国境へ
		var dest = null
		var bd2 := INF
		for t in foeTerrs:
			if t.owner == nid or not atWar(nid, t.owner): continue
			var dd = bget(bsA, t.id)
			if dd == null: continue
			var d2v: float = dd - (2 if isTopThreat(t.owner) else 0)
			if d2v < bd2:
				bd2 = d2v
				dest = t.id
		if dest == null:
			for t in frontier:
				if not bhas(bsA, t.id): continue
				var other := false
				for x in armiesAt(t.id):
					if x.owner == nid and x != a:
						other = true
						break
				if other: continue
				dest = t.id
				break
		if dest != null and dest != a.at:
			var p4 = pathFrom(bsA, dest)
			if p4 != null and p4.size():
				a.path = p4
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
	if BEAT_SPENT >= BEAT_MAX: return
	refreshed.emit()
	var d: int = min(CFG.cpuDelay, BEAT_MAX - BEAT_SPENT)
	BEAT_SPENT += d
	await sleep_ms(d)
