# HOI4を参考にした仕組み：政体・安定度・戦争支持・政治力・国民精神・工場と軍需品・国家方針
# （データは k9_data.gd）

## 工業の盛んな県は、最初から工場を持つ（[軍需, 民需]）
const START_IND := {"東京都": [2, 3], "大阪府": [1, 3], "愛知県": [2, 2], "神奈川県": [1, 2], "兵庫県": [1, 2], "福岡県": [1, 2],
	"京都府": [0, 2], "広島県": [1, 1], "静岡県": [1, 1], "埼玉県": [1, 1], "長崎県": [1, 1], "滋賀県": [1, 0], "鹿児島県": [1, 0]}
const EQ_PER_MF := 300       # 軍需工場1つの軍需品（毎ターン）
const CF_GOLD := 300         # 民需工場1つのゴールド
const EQ_COST := 0.5         # 兵1人に要る軍需品
const FOCUS_UNIQUE_X := 13   # 固有の枝を置く列

# ---------- 初期化 ----------
func hoiInit(g: Dictionary) -> void:
	var gen := []
	for sp in GENERIC_SPIRITS: gen.append(sp)
	gen.shuffle()
	for na in g.nations:
		if na.has("ideo"): continue
		var ideo := "kunshu"
		match na.persona:
			"aggr": ideo = "gunsei" if randf() < 0.6 else "kunshu"
			"econ": ideo = "gougi" if randf() < 0.6 else "kunshu"
			"def": ideo = "kunshu" if randf() < 0.7 else "souson"
			_: ideo = IDEO_KEYS[randi() % IDEO_KEYS.size()]
		na.ideo = ideo
		var pop := {}
		for k in IDEO_KEYS: pop[k] = 10.0 + randf() * 10.0
		pop[ideo] = 55.0
		na.ipop = pop
		_normPop(na)
		na.stab = 55.0 + IDEO[ideo].stab
		na.ws = 25.0 + IDEO[ideo].ws
		na.pp = 50.0
		na.eq = 3000
		na.spirits = []
		na.focus = {"cur": null, "prog": 0, "done": []}
		var p = PREF.get(na.name)
		if p != null: _addSpirit(na, p[0][0], p[0][1], p[0][2], "固有")
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
	for na in g.nations:
		var ind = START_IND.get(na.name, [1, 1])
		_buildFactories(na.id, "mf", ind[0], true)
		_buildFactories(na.id, "cf", ind[1], true)
	G = G0
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
	var im: Dictionary = IDEO.get(na.get("ideo", "kunshu"), IDEO.kunshu).mod
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
	for t in G.terrs:
		if t.owner == nid: cf += bldCount(t, "cf")
	return clamp_f(1.0 + nmod(nid, "build") - cf * 0.02, 0.6, 1.3)

# ---------- 工場 ----------
func _buildFactories(nid: int, kind: String, n: int, start := false) -> int:
	var made := 0
	for k in n:
		var cand := []
		for t in G.terrs:
			if t.owner != nid: continue
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
	for t in G.terrs:
		if t.owner != nid: continue
		mf += bldCount(t, "mf")
		cf += bldCount(t, "cf")
	return [mf, cf]

# ---------- 毎ターン（国ごと） ----------
func hoiTurn(nid: int) -> void:
	var na := NAT(nid)
	if not na.alive or not na.has("ideo"): return
	var ideo: Dictionary = IDEO[na.ideo]
	var war := inWar(nid)
	var dg := cpuDanger(nid)
	# 政治力
	na.pp = min(300.0, na.pp + ideo.pp + nmod(nid, "pp"))
	# 安定度と戦争支持は目標へ少しずつ寄る
	var st: float = 55.0 + ideo.stab + nmod(nid, "stab") - na.get("fatigue", 0) * 0.3 - (15 if na.food <= 0 else 0) - (5 if lordOf(nid) != null else 0)
	var ws: float = 25.0 + ideo.ws + nmod(nid, "ws") + dg * 30.0 + (10 if war else 0) - na.get("fatigue", 0) * 0.6
	var top = topThreat()
	if top != null and top.id != nid and nationsAdjacent(nid, top.id): ws += 10
	for o in G.nations:
		if o.alive and o.id != nid and isTense(nid, o.id) and prepBy(nid, o.id) == o.id:
			ws += 15
			break
	na.stab = clamp_f(na.stab + (clamp_f(st, 0, 100) - na.stab) * 0.12, 0, 100)
	na.ws = clamp_f(na.ws + (clamp_f(ws, 0, 100) - na.ws) * 0.12, 0, 100)
	# 政体の支持率：与党は安定度が高いほど伸び、隣国の政体にも引っ張られる
	na.ipop[na.ideo] = na.ipop[na.ideo] + (na.stab - 50) * 0.04
	for o in G.nations:
		if o.alive and o.id != nid and nationsAdjacent(nid, o.id) and o.has("ideo"):
			na.ipop[o.ideo] = na.ipop.get(o.ideo, 0.0) + 0.25
	_normPop(na)
	_ideoShift(na)
	# 同じ政体どうしは近づき、違う政体とは少し離れる
	for o in G.nations:
		if not o.alive or o.id == nid or not o.has("ideo") or not natNear(nid, o.id): continue
		if o.ideo == na.ideo:
			if favorOf(nid, o.id) < 70: addFavor(nid, o.id, 0.4)
		elif favorOf(nid, o.id) > 20: addFavor(nid, o.id, -0.15)
	# 国家方針
	_focusTurn(na)
## 政変：ほかの政体の支持が過半を超え、安定度が低い（または圧倒的な支持）と政体が変わる
func _ideoShift(na: Dictionary) -> void:
	var best: String = na.ideo
	for k in IDEO_KEYS:
		if na.ipop[k] > na.ipop[best]: best = k
	if best == na.ideo: return
	var p: float = na.ipop[best]
	var coup: bool = p >= 50 and na.stab < 40
	var peaceful: bool = p >= 65 and na.ideo != "gunsei"
	if not coup and not peaceful: return
	var old: String = na.ideo
	na.ideo = best
	na.ipop[best] = max(na.ipop[best], 55.0)
	_normPop(na)
	hoiRecalc(na)
	na.stab = clamp_f(na.stab - (15 if coup else 5), 0, 100)
	var msg := "%s で%s — %s から %s へ" % [na.name, "政変" if coup else "政体の移行", IDEO[old].n, IDEO[best].n]
	logMsg(msg, "war" if coup else "")
	chron(msg, na.id, "gov")

# ---------- 国家方針 ----------
var _treeCache := {}
## その国の方針ツリー（共通の枝＋固有の枝）
func focusTree(na: Dictionary) -> Array:
	if _treeCache.has(na.name): return _treeCache[na.name]
	var out := FOCUS_COMMON.duplicate(true)
	var p = PREF.get(na.name)
	if p != null:
		var chain: Array = p[1]
		var fin: Array = p[2]
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
			_applyFocus(na, f)
			var msg := "%s が国家方針「%s」を達成" % [na.name, f.n]
			if concerns([na.id]): logMsg(msg, "good")
			chron(msg, na.id, "gov")
	if fc.cur == null: _pickFocus(na)
func _pickFocus(na: Dictionary) -> void:
	var cands := []
	var war := inWar(na.id)
	for f in focusTree(na):
		if not focusAvailable(na, f): continue
		var w := 10.0
		match f.br:
			"uniq": w *= 2.5
			"ind": w *= 1.8 if na.persona == "econ" else 1.0
			"mil": w *= (1.8 if na.persona == "aggr" or na.persona == "def" else 1.0) * (2.0 if war else 1.0)
			"pol": w *= 2.0 if na.stab < 45 else 1.0
			"dip": w *= 1.4 if na.persona == "econ" or na.persona == "bal" else 0.8
		var e: Dictionary = f.e
		if e.has("ideo"):
			var k: String = e.ideo[0]
			w *= 3.0 if k == na.ideo else (0.6 + na.ipop.get(k, 0.0) / 40.0)
		if e.has("claim") and na.ws < IDEO[na.ideo].wsNeed - 15: w *= 0.4
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
	nations_changed.emit()
## 方針の効果を文で
func focusDesc(f: Dictionary) -> String:
	var e: Dictionary = f.e
	var s := []
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
	if e.has("claim"): s.append("隣国への大義（25ターン）")
	if e.has("favor"): s.append("隣国の好感度 +%d" % e.favor)
	return "・".join(s)
## 戦を始められるだけの戦争支持があるか（合議制は大義も要る）
var HOI_GATE := true
func hoiWarOK(nid: int, target := -1) -> bool:
	if not HOI_GATE: return true
	var na := NAT(nid)
	if not na.has("ideo"): return true
	if na.ws < IDEO[na.ideo].wsNeed: return false
	if na.ideo == "gougi" and target >= 0 and not hasCB(nid, target): return false
	return true
