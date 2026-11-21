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
	PW_KEY = ""
	var gen := []
	for sp in GENERIC_SPIRITS: gen.append(sp)
	gen.shuffle()
	for na in g.nations:
		if na.has("ideo"): continue
		var cd = COUNTRY.get(na.name)
		var ideo := ""
		var pop := {}
		if cd != null:
			ideo = cd.ideo
			na.role = cd.r
			for k in IDEO_KEYS: pop[k] = cd.pop.get(k, 2.0)
			var rest := 0.0
			for k in IDEO_KEYS:
				if k != ideo: rest += pop[k]
			pop[ideo] = max(40.0, 100.0 - rest)
		else:
			# 架空の大陸：思想はくじ（非同盟が多め）
			var r := randf()
			ideo = "neutral" if r < 0.4 else ("democracy" if r < 0.62 else ("fascism" if r < 0.82 else "communism"))
			for k in IDEO_KEYS: pop[k] = 8.0 + randf() * 12.0
			pop[ideo] = 55.0
		na.ideo = ideo
		na.persona = ideo
		na.ipop = pop
		_normPop(na)
		na.stab = 55.0 + IDEO[ideo].stab + (cd.get("stab", 0) if cd != null else 0)
		na.ws = 25.0 + IDEO[ideo].ws
		na.pp = 50.0
		na.eq = 3000
		na.spirits = []
		na.guar = []
		na.focus = {"cur": null, "prog": 0, "done": []}
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
	# 領地が多すぎる国は統治が行き届かない
	var cnt := {}
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
	PW_KEY = ""
	for na in g.nations:
		var ind = START_IND.get(na.name, [1, 1])
		_buildFactories(na.id, "mf", ind[0], true)
		_buildFactories(na.id, "cf", ind[1], true)
	G = G0
	PW_KEY = ""
func _normPop(na: Dictionary) -> void:
	var s := 0.0
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
	var m := {}
	for sp in na.get("spirits", []):
		for k in sp.m: m[k] = m.get(k, 0.0) + sp.m[k]
	var im: Dictionary = IDEO.get(na.get("ideo", "neutral"), IDEO.neutral).mod
	for k in im: m[k] = m.get(k, 0.0) + im[k]
	na.mods = m
## 修正の値（国民精神と政体の合計）
func nmod(nid, key: String) -> float:
	if nid == null or nid < 0: return 0.0
	return G.nations[nid].get("mods", {}).get(key, 0.0)
## 安定度による生産の倍率（50で1倍、0で0.75倍、100で1.15倍）
func stabMul(na: Dictionary) -> float: return clamp_f(0.75 + na.get("stab", 50.0) / 200.0, 0.75, 1.15)
## 建設費の倍率（民需工場が多いほど安い）
func costMul(nid: int) -> float:
	var cf := 0
	for t in ownList(nid): cf += bldCount(t, "cf")
	return clamp_f(1.0 + nmod(nid, "build") - cf * 0.02, 0.6, 1.3)

# ---------- 工場 ----------
func _buildFactories(nid: int, kind: String, n: int, start := false) -> int:
	var made := 0
	for k in n:
		var cand := []
		for t in ownList(nid):
			var used := 0
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
		var slot := -1
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
	var mf := 0
	var cf := 0
	for t in ownList(nid):
		mf += bldCount(t, "mf")
		cf += bldCount(t, "cf")
	return [mf, cf]

# ---------- 毎ターン（国ごと） ----------
func hoiTurn(nid: int) -> void:
	var na := NAT(nid)
	if not na.alive or not na.has("ideo"): return
	var ideo: Dictionary = IDEO[na.ideo]
	var _h0 := Time.get_ticks_usec()
	var war := inWar(nid)
	var dg := cpuDanger(nid)
	# 戦争中に達成した開戦の方針は、戦争が終わってから
	var pw = na.get("pendingWar", -1)
	if pw >= 0 and not war:
		na.pendingWar = -1
		if NAT(pw).alive and nationsAdjacent(nid, pw) and canPrepare(nid, pw) and hoiWarOK(nid, pw):
			_turnOn(nid, pw)
			grantCB(nid, pw, "持ち越した開戦の方針", 40)
			startWarPrep(nid, pw)
			na.forceWar = pw
	var _h1 := Time.get_ticks_usec()
	PROF["hoi:危険度"] = PROF.get("hoi:危険度", 0) + _h1 - _h0
	# 政治力
	na.pp = min(300.0, na.pp + ideo.pp + nmod(nid, "pp"))
	# 安定度と戦争支持は目標へ少しずつ寄る
	var st: float = 55.0 + ideo.stab + nmod(nid, "stab") - na.get("fatigue", 0) * 0.3 - (15 if na.food <= 0 else 0) - (5 if lordOf(nid) != null else 0)
	var ws: float = 25.0 + ideo.ws + nmod(nid, "ws") + dg * 30.0 + (10 if war else 0) - na.get("fatigue", 0) * 0.6
	var _h2 := Time.get_ticks_usec()
	var top = topThreat()
	if top != null and top.id != nid and nationsAdjacent(nid, top.id): ws += 10
	for o in G.nations:
		if o.alive and o.id != nid and isTense(nid, o.id) and prepBy(nid, o.id) == o.id:
			ws += 15
			break
	PROF["hoi:脅威・緊張"] = PROF.get("hoi:脅威・緊張", 0) + Time.get_ticks_usec() - _h2
	var _h3 := Time.get_ticks_usec()
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
	var _h4 := Time.get_ticks_usec()
	# 同じ政体どうしは近づき、違う政体とは少し離れる
	for o in G.nations:
		if not o.alive or o.id == nid or not o.has("ideo") or not natNear(nid, o.id): continue
		if o.ideo == na.ideo:
			if favorOf(nid, o.id) < 70: addFavor(nid, o.id, 0.4)
		elif favorOf(nid, o.id) > 20: addFavor(nid, o.id, -0.15)
	PROF["hoi:好感度"] = PROF.get("hoi:好感度", 0) + Time.get_ticks_usec() - _h4
	var _h5 := Time.get_ticks_usec()
	# 思想の合わない同盟は解ける
	for o in G.nations:
		if o.alive and o.id != nid and isAlly(nid, o.id) and not isVassal(o.id, nid) and not isVassal(nid, o.id) and not ideoCompat(nid, o.id) and randf() < 0.15:
			breakAlly(nid, o.id)
			chron("%s と %s の同盟が思想の違いで解消される" % [na.name, o.name], nid, "dip")
	PROF["hoi:同盟"] = PROF.get("hoi:同盟", 0) + Time.get_ticks_usec() - _h5
	var _h6 := Time.get_ticks_usec()
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
	var msg := "%s で%s — %s から %s の政権へ" % [na.name, why, IDEO[old].n, IDEO[k].n]
	logMsg(msg, "war" if k == "fascism" or why == "政変" else "")
	chron(msg, na.id, "gov")
	# 盟主と思想が違う陣営からは抜ける
	var F = facOf(na.id)
	if F != null and F.leader != na.id and NAT(F.leader).get("ideo") != k: leaveFaction(na.id, "政権交代")
## 1ターン＝1か月（1936年1月から）
func dateStr(turn: int) -> String:
	return "%d年%d月" % [1936 + (turn - 1) / 12, (turn - 1) % 12 + 1]
func natByName(nm: String) -> int:
	for o in G.nations:
		if o.alive and o.name == nm: return o.id
	return -1
func roleOf(nid: int) -> String: return NAT(nid).get("role", "")

# ---------- 国家方針 ----------
var _treeCache := {}
## その国の方針ツリー（共通の枝＋固有の枝。大国は産業・軍事の枝と大きな固有ツリー）
func focusTree(na: Dictionary) -> Array:
	if _treeCache.has(na.name): return _treeCache[na.name]
	var cd = COUNTRY.get(na.name) if G.get("size") == "japan" else null
	var major: bool = cd != null and cd.has("tree")
	var out := []
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
		var prev := ""
		for i in chain.size():
			var id := "u%d" % i
			out.append({"id": id, "n": chain[i][0], "x": FOCUS_UNIQUE_X + 0.5, "y": i, "t": 6 + i, "req": [prev] if prev != "" else [], "br": "uniq", "e": chain[i][1]})
			prev = id
		for j in fin.size():
			var id2 := "u3%s" % ["a", "b"][j]
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
		var ok := false
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
			var msg := "%s（%s）が国家方針「%s」を達成" % [na.name, na.get("role", ""), f.n] if na.get("role", "") != "" else "%s が国家方針「%s」を達成" % [na.name, f.n]
			if concerns([na.id]) or (f.br == "uniq" and isMajor(na)): logMsg(msg, "good")
			chron(msg, na.id, "gov")
			_applyFocus(na, f)
	if fc.cur == null: _pickFocus(na)
const WAR_FX := ["warOn", "claimOn", "demand", "claim"]
func _pickFocus(na: Dictionary) -> void:
	var cands := []
	var war := inWar(na.id)
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
	var sum := 0.0
	for c in cands: sum += c[1]
	var r := randf() * sum
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
		var c := []
		for t in G.terrs:
			if t.owner == nid and t.type == "city" and t.dev < 5: c.append(t)
		c.shuffle()
		for i in min(e.dev, c.size()):
			c[i].dev += 1
			invalidateTerr(c[i].id)
	if e.has("infra"):
		var c2 := []
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
		var o := natByName(e.pact)
		if o >= 0 and o != nid and relState(nid, o) == "peace":
			makePact(nid, o)
			chron("%s と %s が不可侵条約を結ぶ（%s）" % [na.name, NAT(o).name, f.n], nid, "dip")
	if e.has("claimOn"):
		for nm in e.claimOn:
			var o := natByName(nm)
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
				var o := natByName(nm)
				if o >= 0 and o != nid and facOf(o) == null and lordOf(o) == null and not atWar(nid, o) and NAT(o).get("ideo") == na.ideo:
					joinFaction(F, o)
	if e.has("guar"):
		for nm in e.guar:
			var o := natByName(nm)
			if o >= 0 and o != nid and not na.guar.has(o):
				na.guar.append(o)
				var msg := "%s が %s の独立を保証する" % [na.name, NAT(o).name]
				if concerns([nid, o]): logMsg(msg, "good")
				chron(msg, nid, "dip")
	if e.has("demand"):
		for nm in e.demand:
			var o := natByName(nm)
			if o >= 0: _demand(na, o, f.n)
	if e.has("warOn"):
		var o := natByName(e.warOn)
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
	var B := NAT(o)
	if not B.alive or o == nid or lordOf(o) == nid or sameFaction(nid, o) or atWar(nid, o): return
	var theirs := nationPower(o)
	var F = facOf(o)
	if F != null:
		for m in F.members:
			if m != o and NAT(m).alive: theirs += nationPower(m) * 0.5
	for g in G.nations:
		if g.alive and g.id != nid and g.get("guar", []).has(o): theirs += nationPower(g.id) * 0.5
	var ratio := nationPower(nid) / max(1.0, theirs)
	var same: bool = B.get("ideo") == na.ideo
	var sympathy: float = B.get("ipop", {}).get(na.ideo, 0.0)
	var annexOK: bool = not inWar(o) and (ratio >= 2.2 or (same and ratio >= 1.2) or (sympathy >= 40 and ratio >= 1.0))
	var msg := ""
	if annexOK and nationsAdjacent(nid, o):
		msg = "%s が %s の要求を受け入れ、併合される（%s）" % [B.name, na.name, why]
		logMsg(msg, "war")
		chron(msg, nid, "dip")
		annex(nid, o, why)
	elif not inWar(o) and ratio >= 1.6 and lordOf(o) == null and vassalsOf(o).is_empty():
		msg = "%s が %s の要求を受け入れ、従属する（%s）" % [B.name, na.name, why]
		logMsg(msg, "war")
		chron(msg, nid, "dip")
		makeVassal(nid, o, why)
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
	var wid := warOf(a, b)
	for g in G.nations:
		if not g.alive or g.id == a or g.id == b: continue
		if not g.get("guar", []).has(b): continue
		if atWar(g.id, a) or sameFaction(g.id, a) or isAlly(g.id, a) or lordOf(g.id) != null: continue
		enterWar(g.id, a, "%s の独立の保証により参戦" % NAT(b).name, wid)
## 方針の効果を文で
func focusDesc(f: Dictionary) -> String:
	var e: Dictionary = f.e
	var s := []
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
var HOI_GATE := true
func hoiWarOK(nid: int, target := -1) -> bool:
	if not HOI_GATE: return true
	var na := NAT(nid)
	if not na.has("ideo"): return true
	if na.ws < IDEO[na.ideo].wsNeed: return false
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
