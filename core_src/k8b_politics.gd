# HOI4 を参考にした政治：指導者・国家法（徴兵・経済・貿易）・顧問・決定（政治力の使い道）

# ---------- 国家法 ----------
## 段階の順に並べる。need=必要な戦争支持（war=戦争中でないと選べない）
const LAWS := {
	"conscr": {"n": "徴兵法", "list": [
		{"id": "vol", "n": "志願兵制", "d": "兵の上限 -30%・人口の伸び +5%", "m": {"cap": -0.30, "grow": 0.05}, "need": 0},
		{"id": "lim", "n": "限定徴兵", "d": "標準", "m": {}, "need": 0},
		{"id": "ext", "n": "拡大徴兵", "d": "兵の上限 +30%・人口の伸び -5%・ゴールド -5%", "m": {"cap": 0.30, "grow": -0.05, "gold": -0.05}, "need": 40},
		{"id": "svc", "n": "兵役義務", "d": "兵の上限 +60%・人口の伸び -10%・ゴールド -10%", "m": {"cap": 0.60, "grow": -0.10, "gold": -0.10}, "need": 60, "war": true},
		{"id": "all", "n": "国民総動員", "d": "兵の上限 +100%・人口の伸び -20%・ゴールド -20%・食料 -10%", "m": {"cap": 1.0, "grow": -0.20, "gold": -0.20, "food": -0.10}, "need": 80, "war": true},
	]},
	"econ": {"n": "経済法", "list": [
		{"id": "civ", "n": "民間経済", "d": "消費財 35%・民需工場の出力 +15%・軍需工場の出力 -10%・安定度 +5", "m": {"cf": 0.15, "mf": -0.10, "stab": 5.0}, "need": 0, "cg": 0.35},
		{"id": "early", "n": "初期動員", "d": "消費財 30%・標準", "m": {}, "need": 0, "cg": 0.30},
		{"id": "part", "n": "部分動員", "d": "消費財 25%・軍需工場の出力 +10%・民需工場の出力 -5%", "m": {"mf": 0.10, "cf": -0.05}, "need": 30, "cg": 0.25},
		{"id": "war", "n": "戦時経済", "d": "消費財 20%・軍需工場の出力 +20%・民需工場の出力 -10%・安定度 -5", "m": {"mf": 0.20, "cf": -0.10, "stab": -5.0}, "need": 60, "cg": 0.20},
		{"id": "total", "n": "総力戦", "d": "消費財 10%・軍需工場の出力 +30%・民需工場の出力 -20%・安定度 -10", "m": {"mf": 0.30, "cf": -0.20, "stab": -10.0}, "need": 0, "war": true, "cg": 0.10},
	]},
	"trade": {"n": "貿易法", "list": [
		{"id": "free", "n": "自由貿易", "d": "ゴールド +10%・資源の輸出が多い（国内の資源 -20%）", "m": {"gold": 0.10, "res": -0.20}, "need": 0},
		{"id": "exp", "n": "輸出重視", "d": "ゴールド +5%・資源の輸出（国内の資源 -10%）", "m": {"gold": 0.05, "res": -0.10}, "need": 0},
		{"id": "lim", "n": "輸出制限", "d": "標準", "m": {}, "need": 0},
		{"id": "closed", "n": "閉鎖経済", "d": "ゴールド -10%・国内の資源 +10%・軍需工場の出力 +5%", "m": {"gold": -0.10, "res": 0.10, "mf": 0.05}, "need": 0},
	]},
}
const LAW_KEYS := ["conscr", "econ", "trade"]
const LAW_COST := 100.0

# ---------- 顧問 ----------
## slot：pol（政治顧問・2人）／staff（参謀・1人）／design（設計会社・1つ）
const ADVISORS := [
	{"id": "ind", "slot": "pol", "n": "産業の大家", "d": "民需工場の出力 +10%・建設費 -10%", "m": {"cf": 0.10, "build": -0.10}},
	{"id": "prop", "slot": "pol", "n": "宣伝相", "d": "戦争支持 +10", "m": {"ws": 10.0}},
	{"id": "mod", "slot": "pol", "n": "穏健な調停者", "d": "安定度 +10", "m": {"stab": 10.0}},
	{"id": "dipl", "slot": "pol", "n": "外交の達人", "d": "政治力 +0.5／ターン・安定度 +3", "m": {"pp": 0.5, "stab": 3.0}},
	{"id": "iron", "slot": "pol", "n": "鉄の宰相", "d": "兵の生産 +10%", "m": {"troop": 0.10}, "ideo": ["fascism", "neutral"]},
	{"id": "plan", "slot": "pol", "n": "計画経済の旗手", "d": "軍需工場の出力 +15%", "m": {"mf": 0.15}, "ideo": ["communism"]},
	{"id": "atk", "slot": "staff", "n": "攻勢の参謀", "d": "攻撃 +8%", "m": {"atk": 0.08}},
	{"id": "def", "slot": "staff", "n": "守勢の参謀", "d": "防御 +8%", "m": {"def": 0.08}},
	{"id": "log", "slot": "staff", "n": "兵站の参謀", "d": "兵の上限 +15%・消耗 -30%", "m": {"cap": 0.15, "attr": -0.30}},
	{"id": "fort", "slot": "staff", "n": "築城の参謀", "d": "砦の防御 +20%", "m": {"fort": 0.20}},
	{"id": "arms", "slot": "design", "n": "小火器工廠", "d": "攻撃 +4%・軍需工場の出力 +5%", "m": {"atk": 0.04, "mf": 0.05}},
	{"id": "art", "slot": "design", "n": "重砲工廠", "d": "攻撃 +6%", "m": {"atk": 0.06}},
	{"id": "tank", "slot": "design", "n": "装甲工廠", "d": "攻撃 +5%・防御 +3%", "m": {"atk": 0.05, "def": 0.03}},
	{"id": "aero", "slot": "design", "n": "航空機製作所", "d": "空軍力 +25%", "m": {"air": 0.25}},
]
const ADV_SLOTS := {"pol": 2, "staff": 1, "design": 1}
const ADV_COST := 150.0

# ---------- 決定 ----------
const DECISIONS := [
	{"id": "border", "n": "国境紛争をしかける", "d": "弱い隣国への大義（20ターン）・世界の緊張 +2", "pp": 60},
	{"id": "bonds", "n": "戦時公債", "d": "ゴールドを得る・安定度 -5", "pp": 40},
	{"id": "order", "n": "治安強化", "d": "全領地の治安 +15・安定度 +5", "pp": 50},
	{"id": "diplo", "n": "外交攻勢", "d": "隣国の好感度 +10・世界の緊張 -2", "pp": 50},
	{"id": "mobil", "n": "総動員令", "d": "兵の蓄え +20%・安定度 -5", "pp": 70},
]

# ---------- 指導者 ----------
const LEADER_TITLE := {"democracy": "首相", "communism": "書記長", "fascism": "総統", "neutral": "国家元首"}
const LEADER_TRAITS := [
	{"n": "カリスマ", "d": "安定度 +5・戦争支持 +5", "m": {"stab": 5.0, "ws": 5.0}},
	{"n": "能吏", "d": "政治力 +0.5／ターン", "m": {"pp": 0.5}},
	{"n": "軍人上がり", "d": "攻撃 +3%・兵の生産 +5%", "m": {"atk": 0.03, "troop": 0.05}},
	{"n": "倹約家", "d": "ゴールド +5%", "m": {"gold": 0.05}},
	{"n": "人気者", "d": "安定度 +10", "m": {"stab": 10.0}},
	{"n": "工業通", "d": "軍需・民需工場の出力 +5%", "m": {"mf": 0.05, "cf": 0.05}},
	{"n": "慎重", "d": "防御 +5%・戦争支持 -5", "m": {"def": 0.05, "ws": -5.0}},
	{"n": "野心家", "d": "戦争支持 +10・安定度 -5", "m": {"ws": 10.0, "stab": -5.0}},
]
const NAME_A := ["ハンス", "カール", "フランツ", "アントン", "ミハイル", "ニコライ", "ジョン", "エドワード", "ピエール", "ルイ", "ジュゼッペ", "マリオ", "ヨゼフ", "アレクサンデル", "ウラジミル", "トマス", "ヘンリク", "ステファン", "イシュトヴァン", "コンスタンティン", "ペドロ", "ミゲル", "グスタフ", "オスカー", "ヴィクトル", "エミール"]
const NAME_B := ["ヴェーバー", "シュミット", "ベッカー", "イワノフ", "ペトロフ", "スミス", "ウィルソン", "デュボア", "マルタン", "ロッシ", "コンティ", "ノヴァク", "コヴァルスキ", "ホルヴァート", "ポペスク", "ガルシア", "ロペス", "リンドベリ", "ハンセン", "コーホネン", "ヤンセン", "ペテルセン", "ディミトロフ", "パパドプロス", "ユルドゥズ", "モレノ"]
func newLeader(na: Dictionary) -> void:
	var tr: Dictionary = LEADER_TRAITS[randi() % LEADER_TRAITS.size()]
	na.leader = {"n": "%s・%s" % [NAME_A[randi() % NAME_A.size()], NAME_B[randi() % NAME_B.size()]], "t": tr.n, "since": G.turn if G != null else 1}
func leaderTrait(na: Dictionary):
	var l = na.get("leader")
	if l == null: return null
	for tr in LEADER_TRAITS:
		if tr.n == l.t: return tr
	return null
func leaderTitle(na: Dictionary) -> String: return LEADER_TITLE.get(na.get("ideo", "neutral"), "国家元首")

# ---------- 初期化（hoiInit から） ----------
func politicsInit(na: Dictionary) -> void:
	if not na.has("laws"):
		var lw := {"conscr": "lim", "econ": "early", "trade": "lim"}
		match na.get("ideo", "neutral"):
			"fascism": lw = {"conscr": "ext", "econ": "part", "trade": "closed"}
			"communism": lw = {"conscr": "ext", "econ": "part", "trade": "lim"}
			"democracy": lw = {"conscr": "vol", "econ": "civ", "trade": "free"}
		na.laws = lw
	if not na.has("advisors"): na.advisors = []
	if not na.has("leader"): newLeader(na)
	if not na.has("decCool"): na.decCool = {}
func lawOf(na: Dictionary, k: String) -> Dictionary:
	var id: String = na.get("laws", {}).get(k, "")
	for l in LAWS[k].list:
		if l.id == id: return l
	return LAWS[k].list[1]
func consumerShare(na: Dictionary) -> float: return lawOf(na, "econ").get("cg", 0.3)
## 国民精神・政体のほかに足す修正（hoiRecalc から）
func politicsMods(na: Dictionary, m: Dictionary) -> void:
	for k in LAW_KEYS:
		var l := lawOf(na, k)
		for x in l.m: m[x] = m.get(x, 0.0) + l.m[x]
	for aid in na.get("advisors", []):
		for a in ADVISORS:
			if a.id == aid:
				for x in a.m: m[x] = m.get(x, 0.0) + a.m[x]
	var tr = leaderTrait(na)
	if tr != null:
		for x in tr.m: m[x] = m.get(x, 0.0) + tr.m[x]

# ---------- 毎ターン：CPU が政治力を使う ----------
func politicsTurn(na: Dictionary) -> void:
	var nid: int = na.id
	var war := inWar(nid)
	var hot: bool = war or tension() >= 50
	# 1) 国家法：戦争中・緊張が高ければ段階を上げる。長い平和で疲れていれば下げる
	if na.pp >= LAW_COST + 20:
		for k in ["conscr", "econ"]:
			var lst: Array = LAWS[k].list
			var cur := 0
			for i in lst.size():
				if lst[i].id == na.laws[k]: cur = i
			var want := cur
			var arm: bool = hot or na.ideo == "fascism" or (na.ideo == "communism" and tension() >= 30)
			if arm and cur + 1 < lst.size():
				var nx: Dictionary = lst[cur + 1]
				if na.ws >= nx.need and (not nx.get("war", false) or war): want = cur + 1
			elif not war and tension() < 30 and cur > 1 and na.get("fatigue", 0) > 20: want = cur - 1
			if want != cur:
				na.laws[k] = lst[want].id
				na.pp -= LAW_COST
				hoiRecalc(na)
				var msg := "%s が%sを「%s」に改める" % [na.name, LAWS[k].n, lst[want].n]
				if concerns([nid]): logMsg(msg)
				chron(msg, nid, "gov")
				break
	# 戦争が終わったら、戦時にしか選べない段階からは戻す
	if not war:
		for k in ["conscr", "econ"]:
			var l := lawOf(na, k)
			if l.get("war", false):
				var lst: Array = LAWS[k].list
				for i in lst.size():
					if lst[i].id == l.id:
						na.laws[k] = lst[i - 1].id
						hoiRecalc(na)
	# 2) 顧問：空いた枠に雇う
	if na.pp >= ADV_COST + 30:
		var used := {"pol": 0, "staff": 0, "design": 0}
		for aid in na.advisors:
			for a in ADVISORS:
				if a.id == aid: used[a.slot] += 1
		var best = null
		var bw := 0.0
		for a in ADVISORS:
			if na.advisors.has(a.id) or used[a.slot] >= ADV_SLOTS[a.slot]: continue
			if a.has("ideo") and not a.ideo.has(na.ideo): continue
			var w := 1.0 + randf()
			if a.slot == "staff" or a.slot == "design": w += 1.5 if hot else 0.3
			if a.m.has("stab") and na.stab < 45: w += 2.0
			if a.m.has("ws") and na.ws < wsNeedOf(na) and na.ideo != "democracy": w += 1.5
			if a.m.has("cf") or a.m.has("mf"): w += 0.8
			if w > bw:
				bw = w
				best = a
		if best != null:
			na.advisors.append(best.id)
			na.pp -= ADV_COST
			hoiRecalc(na)
			var msg2 := "%s が%s「%s」を迎える" % [na.name, {"pol": "政治顧問", "staff": "参謀", "design": "設計会社"}[best.slot], best.n]
			if concerns([nid]): logMsg(msg2)
			chron(msg2, nid, "gov")
	# 3) 決定
	for dc in DECISIONS:
		# 急ぎでない決定は、法律や顧問の分を残せる時だけ
		var urgent: bool = dc.id == "bonds" or dc.id == "mobil"
		if na.pp < dc.pp + (30 if urgent else 170): continue
		if na.decCool.get(dc.id, -99) > G.turn: continue
		if not _decisionWanted(na, dc.id, war): continue
		na.pp -= dc.pp
		na.decCool[dc.id] = G.turn + 15
		_decide(na, dc)
		break
func _decisionWanted(na: Dictionary, id: String, war: bool) -> bool:
	match id:
		"border": return not war and (na.ideo == "fascism" or na.ideo == "communism") and na.ws >= wsNeedOf(na) - 10 and randf() < 0.3
		"bonds": return war and na.gold < 4000
		"order":
			var low := 0
			var own := ownList(na.id)
			for t in own:
				if t.sec < 45: low += 1
			return low > own.size() * 0.2
		"diplo": return not war and na.ideo == "democracy" and tension() > 40 and randf() < 0.2
		"mobil": return war and cpuDanger(na.id) >= 0.8
	return false
func _decide(na: Dictionary, dc: Dictionary) -> void:
	var nid: int = na.id
	match dc.id:
		"border":
			var best = null
			for o in G.nations:
				if not o.alive or o.id == nid or not nationsAdjacent(nid, o.id) or sameFaction(nid, o.id) or lordOf(o.id) == nid: continue
				if best == null or nationPower(o.id) < nationPower(best): best = o.id
			if best == null: return
			grantCB(nid, best, "国境紛争", 20)
			addTension(2)
		"bonds":
			na.gold += 3000 + ownCount(nid) * 150
			na.stab = clamp_f(na.stab - 5, 0, 100)
		"order":
			for t in ownList(nid): t.sec = clamp_f(t.sec + 15, 0, 100)
			na.stab = clamp_f(na.stab + 5, 0, 100)
		"diplo":
			for o in G.nations:
				if o.alive and o.id != nid and nationsAdjacent(nid, o.id): addFavor(o.id, nid, 10)
			addTension(-2)
		"mobil":
			for k in na.stock: na.stock[k] = int(na.stock[k] * 1.2)
			na.stab = clamp_f(na.stab - 5, 0, 100)
	var msg := "%s が決定「%s」を行う" % [na.name, dc.n]
	if concerns([nid]): logMsg(msg)
	chron(msg, nid, "gov")
