# HOI4 を参考にした外交：内戦・義勇軍・レンドリース（軍需品の供与）・陣営への加盟申請

# ---------- 内戦 ----------
## 安定度がとても低い時に政変が起きると、すぐには政権が変わらず内戦になる。
## 内戦の間は兵の生産・ゴールドが落ち、一部の領地が混乱する。終わる時、支持の多い側が政権を取る
const CIVIL_TURNS := 12
func startCivilWar(na: Dictionary, rebel: String) -> void:
	if na.has("civil"): return
	na.civil = {"side": rebel, "end": G.turn + CIVIL_TURNS}
	_addSpirit(na, "内戦", "兵の生産 -30%・ゴールド -30%・安定度 -10", {"troop": -0.30, "gold": -0.30, "stab": -10.0}, "内戦")
	var own := ownList(na.id)
	var cap := T(na.capital)
	var far := own.duplicate()
	far.sort_custom(func(a, b): return Vector2(a.x, a.y).distance_to(Vector2(cap.x, cap.y)) > Vector2(b.x, b.y).distance_to(Vector2(cap.x, cap.y)))
	for i in int(far.size() * 0.3):
		far[i].chaos = max(far[i].chaos, 4)
		far[i].sec = clamp_f(far[i].sec - 25, 0, 100)
	var msg := "%s で内戦が始まる — %s 政権 対 %s 派" % [na.name, IDEO[na.ideo].n, IDEO[rebel].n]
	headline("%s で内戦" % natLabel(na.id), "%s 政権 対 %s 派" % [IDEO[na.ideo].n, IDEO[rebel].n])
	logMsg(msg, "war")
	chron(msg, na.id, "war")
	addTension(4)
func civilWarTurn(na: Dictionary) -> void:
	var cw = na.get("civil")
	if cw == null: return
	# 同じ思想の国が反乱側・政府側を支援する（支持が動く）
	for o in G.nations:
		if not o.alive or o.id == na.id or not natNear(o.id, na.id) or not o.has("ideo"): continue
		if o.ideo == cw.side: na.ipop[cw.side] = na.ipop.get(cw.side, 0.0) + 0.6
		elif o.ideo == na.ideo: na.ipop[na.ideo] = na.ipop.get(na.ideo, 0.0) + 0.6
	_normPop(na)
	if G.turn < cw.end: return
	na.erase("civil")
	_rmSpirit(na, "内戦")
	var win: String = cw.side if na.ipop.get(cw.side, 0.0) >= na.ipop.get(na.ideo, 0.0) else na.ideo
	var msg := "%s の内戦が終わる — %s" % [na.name, ("%s 派が勝ち、政権を取る" % IDEO[win].n) if win != na.ideo else "政府が反乱を抑える"]
	logMsg(msg, "war")
	chron(msg, na.id, "war")
	if win != na.ideo: setGov(na, win, "内戦")
	else: na.ipop[cw.side] = na.ipop.get(cw.side, 0.0) * 0.5
	_normPop(na)

# ---------- 義勇軍・レンドリース ----------
## 毎ターン、国ごとに：戦争していない国が、戦争中の同じ思想の国へ義勇軍（兵）を、
## 軍需品に余裕のある国が、戦争中の同じ陣営・同じ思想の国へ軍需品を送る
func supportTurn(na: Dictionary) -> void:
	var nid: int = na.id
	if not na.has("supCool"): na.supCool = {}
	var war := inWar(nid)
	for o in G.nations:
		if not o.alive or o.id == nid or not inWar(o.id) or atWar(nid, o.id): continue
		if na.supCool.get(o.id, -99) > G.turn: continue
		var sameIdeo: bool = o.get("ideo") == na.get("ideo")
		var sameFac := sameFaction(nid, o.id)
		if not sameIdeo and not sameFac: continue
		if not natNear(nid, o.id): continue
		# 義勇軍：自分は戦争しておらず、戦争支持が 30 以上
		if not war and sameIdeo and na.ws >= 30 and total(na.stock) > 4000 and randf() < 0.10:
			var sent := 0
			for k in TK:
				var n := int(na.stock[k] * 0.08)
				na.stock[k] -= n
				o.stock[k] += n
				sent += n
			if sent > 0:
				na.supCool[o.id] = G.turn + 18
				var msg := "%s が %s へ義勇軍 %s人 を送る" % [na.name, o.name, fmt(sent)]
				if concerns([nid, o.id]): logMsg(msg)
				chron(msg, nid, "dip")
				addFavor(o.id, nid, 8)
				continue
		# レンドリース：軍需品に余裕がある
		if na.get("eq", 0) > 9000 and (sameFac or na.get("ideo") == "democracy") and randf() < 0.15:
			var give: int = int(min(na.eq * 0.2, 6000))
			na.eq -= give
			o.eq = o.get("eq", 0) + give
			na.supCool[o.id] = G.turn + 12
			var msg2 := "%s が %s へ軍需品 %s を供与する（レンドリース）" % [na.name, o.name, fmt(give)]
			if concerns([nid, o.id]): logMsg(msg2)
			chron(msg2, nid, "dip")
			addFavor(o.id, nid, 6)

# ---------- 陣営への加盟申請 ----------
## 陣営に入っていない国が、思想の合う近くの陣営に加盟を申請し、盟主が受け入れを決める
func factionApplyTurn(na: Dictionary) -> void:
	var nid: int = na.id
	if facOf(nid) != null or lordOf(nid) != null or randf() > 0.04: return
	var best = null
	var bs := -INF
	for F in G.get("factions", {}).values():
		if not NAT(F.leader).alive or not facFit(nid, F.leader): continue
		var near := false
		var war := false
		for m in F.members:
			if natNear(m, nid): near = true
			if atWar(m, nid): war = true
		if not near or war: continue
		var s: float = favorOf(nid, F.leader) + (25 if NAT(F.leader).get("ideo") == na.get("ideo") else 0) + cpuDanger(nid) * 30
		if s > bs:
			bs = s
			best = F
	if best == null or bs < 40: return
	var ok: bool = favorOf(best.leader, nid) >= 30 and best.members.size() < 8
	var msg := "%s が「%s」への加盟を申請し、%s" % [na.name, best.name, "認められる" if ok else "断られる"]
	if concerns([nid, best.leader]): logMsg(msg, "good" if ok else "")
	chron(msg, nid, "dip")
	if ok: joinFaction(best, nid)
	else: addFavor(nid, best.leader, -5)

# ---------- 新聞の見出し ----------
## 大きな出来事を「国盗り新報」の見出しとして画面に出す（止めずに流す）
signal news(head: String, sub: String)
func headline(head: String, sub := "") -> void:
	if G == null: return
	news.emit(head, sub)
## 大国（固有の大きな方針ツリーを持つ国）か、選んだ国が関わるか
func newsworthy(ids: Array) -> bool:
	for i in ids:
		if i >= 0 and i < G.nations.size() and (isMajor(NAT(i)) or concerns([i])): return true
	return false
func natLabel(nid: int) -> String:
	var na := NAT(nid)
	var r: String = na.get("role", "")
	return ("%s（%s）" % [r, na.name.trim_suffix("県").trim_suffix("都").trim_suffix("府")]) if r != "" else na.name

# ---------- 歴史イベント：ミュンヘン会談 ----------
## ドイツ（群馬）がチェコスロバキア（栃木）に併合を要求すると、イギリス（東京）が宥和か対決かを選ぶ
func munichEvent(ger: int, cze: int) -> String:
	var uk := natByName("東京都")
	var fr := natByName("長野県")
	if uk < 0 or NAT(uk).get("ideo") != "democracy": return ""
	var ukna := NAT(uk)
	var firm: float = 0.35 + (0.4 if ukna.focus.done.has("b3") else 0.0) - (0.3 if ukna.focus.done.has("b2") else 0.0) + (tension() - 40) / 200.0
	var stand: bool = randf() < clamp_f(firm, 0.05, 0.95)
	if stand:
		for g in [uk, fr]:
			if g >= 0 and not NAT(g).get("guar", []).has(cze):
				if not NAT(g).has("guar"): NAT(g).guar = []
				NAT(g).guar.append(cze)
		headline("ミュンヘン会談、決裂", "%s は %s の要求を拒み、%s の独立を保証" % [natLabel(uk), natLabel(ger), natLabel(cze)])
		chron("ミュンヘン会談：%s は宥和を拒み、%s の独立を保証する" % [NAT(uk).name, NAT(cze).name], uk, "dip")
		return "stand"
	headline("ミュンヘン会談、宥和で妥結", "%s は %s の要求を認める —「我らの時代の平和」" % [natLabel(uk), natLabel(ger)])
	chron("ミュンヘン会談：%s は %s の要求を認める（宥和）" % [NAT(uk).name, NAT(ger).name], uk, "dip")
	return "appease"
