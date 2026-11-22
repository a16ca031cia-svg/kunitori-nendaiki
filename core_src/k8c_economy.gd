# HOI4 を参考にした経済：研究（技術）・装備の世代・資源（鉄・石油）と貿易・消費財

# ---------- 研究 ----------
## 1段階ごとの効果（5段階まで）。y=その分野の1段階目が出る年（以後1.5年ごと）
const TECHS := {
	"inf": {"n": "歩兵装備", "d": "攻撃 +3%・防御 +3%", "m": {"atk": 0.03, "def": 0.03}, "y": 1936},
	"art": {"n": "砲兵", "d": "攻撃 +5%", "m": {"atk": 0.05}, "y": 1936},
	"armor": {"n": "機甲", "d": "攻撃 +4%・突撃力 +2%", "m": {"atk": 0.04, "chg": 0.02}, "y": 1937},
	"ind": {"n": "工業", "d": "軍需・民需工場の出力 +6%", "m": {"mf": 0.06, "cf": 0.06}, "y": 1936},
	"constr": {"n": "建設", "d": "建設費 -5%", "m": {"build": -0.05}, "y": 1936},
	"fort": {"n": "築城", "d": "砦の防御 +8%・防御 +2%", "m": {"fort": 0.08, "def": 0.02}, "y": 1936},
	"log": {"n": "兵站", "d": "消耗 -15%・兵の上限 +5%", "m": {"attr": -0.15, "cap": 0.05}, "y": 1936},
	"air": {"n": "航空", "d": "空軍力 +20%", "m": {"air": 0.20}, "y": 1936},
	"naval": {"n": "海軍", "d": "海軍力 +20%", "m": {"navy": 0.20}, "y": 1936},
}
const TECH_KEYS := ["inf", "art", "armor", "ind", "constr", "fort", "log", "air", "naval"]
const TECH_MAX := 5
const RES_SLOTS := 2
func techLv(na: Dictionary, k: String) -> int: return int(na.get("tech", {}).get(k, 0))
func techYear(k: String, lv: int) -> float: return TECHS[k].y + (lv - 1) * 1.5
func curYear() -> float: return 1936.0 + (G.turn - 1) / 12.0
func techCost(na: Dictionary, k: String) -> float:
	var lv := techLv(na, k) + 1
	var c: float = 60.0 + lv * 30.0
	if techYear(k, lv) > curYear(): c *= 2.0   # 年代より先の研究は2倍かかる
	return c
## 研究の速さ（毎ターン）：民需工場が多いほど速い
func researchRate(na: Dictionary) -> float:
	var cf: int = factoryCount(na.id)[1]
	return 5.0 + cf * 0.6 + nmod(na.id, "rsch") * 10.0
## 装備の世代（歩兵装備・砲兵・機甲の平均）
func equipGen(na: Dictionary) -> float: return (techLv(na, "inf") + techLv(na, "art") + techLv(na, "armor")) / 3.0
func techMods(na: Dictionary, m: Dictionary) -> void:
	for k in TECH_KEYS:
		var lv := techLv(na, k)
		if lv <= 0: continue
		for x in TECHS[k].m: m[x] = m.get(x, 0.0) + TECHS[k].m[x] * lv
func researchTurn(na: Dictionary) -> void:
	if not na.has("tech"): na.tech = {}
	if not na.has("rsch"): na.rsch = []
	var rate := researchRate(na)
	var done := []
	for r in na.rsch:
		r.p += rate
		if r.p >= techCost(na, r.k):
			na.tech[r.k] = techLv(na, r.k) + 1
			done.append(r)
			var msg := "%s が研究「%s %d」を終える" % [na.name, TECHS[r.k].n, na.tech[r.k]]
			if concerns([na.id]): logMsg(msg)
			if isMajor(na): chron(msg, na.id, "gov")
	for r in done: na.rsch.erase(r)
	if done.size(): hoiRecalc(na)
	while na.rsch.size() < RES_SLOTS:
		var k = _pickTech(na)
		if k == null: break
		na.rsch.append({"k": k, "p": 0.0})
func _pickTech(na: Dictionary):
	var war := inWar(na.id)
	var best = null
	var bw := -1.0
	for k in TECH_KEYS:
		if techLv(na, k) >= TECH_MAX: continue
		var busy := false
		for r in na.rsch:
			if r.k == k: busy = true
		if busy: continue
		var w := 1.0 + randf() * 0.6
		match na.get("ideo", "neutral"):
			"fascism": w *= {"armor": 1.8, "art": 1.5, "air": 1.5}.get(k, 1.0)
			"communism": w *= {"inf": 1.6, "ind": 1.5, "armor": 1.4}.get(k, 1.0)
			"democracy": w *= {"ind": 1.6, "naval": 1.5, "air": 1.3}.get(k, 1.0)
			_: w *= {"ind": 1.5, "fort": 1.5, "constr": 1.3}.get(k, 1.0)
		if war and (k == "inf" or k == "art" or k == "armor"): w *= 1.5
		if techYear(k, techLv(na, k) + 1) > curYear(): w *= 0.4
		if k == "naval" and coastCount(na.id) < 3: w *= 0.2
		if w > bw:
			bw = w
			best = k
	return best

# ---------- 資源（鉄・石油）と貿易 ----------
const RES_KINDS := {"steel": "鉄", "oil": "石油"}
## 領地ごとの産出（ゲーム開始時に一度だけ決める。鉄は山や鉄の産地、石油は平地や湿地に多い）
func resourceInit(g: Dictionary) -> void:
	for t in g.terrs:
		if t.has("ress"): continue
		var r := {}
		var h: int = abs(hash(str(t.id) + "_" + str(g.get("jpMap", 0)) + "_r"))
		var tr: String = str(t.get("terrain", "plain"))
		var steelP: float = 0.10 + (0.25 if tr == "mount" or tr == "hill" else 0.0) + (0.5 if t.get("trait") == "iron" else 0.0)
		var oilP: float = 0.07 + (0.12 if tr == "plain" or tr == "marsh" else 0.0)
		if (h % 1000) / 1000.0 < steelP: r.steel = 1 + h % 3
		if ((h / 1000) % 1000) / 1000.0 < oilP: r.oil = 1 + (h / 7) % 3
		t.ress = r
## 国の資源（産出・必要・不足）。必要：軍需工場1つで鉄 1・石油 0.5、機甲の段階ごとに石油 +1
func resources(nid: int) -> Dictionary:
	var na := NAT(nid)
	var have := {"steel": 0.0, "oil": 0.0}
	for t in ownList(nid):
		for k in t.get("ress", {}): have[k] += t.ress[k]
	var mul: float = 1.0 + nmod(nid, "res")
	for k in have: have[k] *= mul
	var mf: int = factoryCount(nid)[0]
	# 人造石油：軍需工場の一部が石炭から石油を作る（ドイツは多い）
	have.oil += mf * (0.15 + nmod(nid, "synth"))
	var need := {"steel": mf * 1.0, "oil": mf * 0.5 + techLv(na, "armor") * 1.0}
	# 通商相手の余りを輸入する
	var imp := {"steel": 0.0, "oil": 0.0}
	for p in tradePartners(nid):
		var ph := {"steel": 0.0, "oil": 0.0}
		for t in ownList(p):
			for k in t.get("ress", {}): ph[k] += t.ress[k]
		var pmf: int = factoryCount(p)[0]
		var spare := {"steel": ph.steel - pmf * 1.0, "oil": ph.oil - pmf * 0.5}
		for k in imp: imp[k] += max(0.0, spare[k]) * 0.5
	var ratio := 1.0
	for k in need:
		if need[k] > 0: ratio = min(ratio, (have[k] + imp[k]) / need[k])
	return {"have": have, "need": need, "imp": imp, "ratio": clamp_f(ratio, 0, 1)}
## 資源の不足による軍需工場の倍率（足りなければ最低 0.5 倍）
func resMul(nid: int) -> float:
	var c = _resCache.get(nid)
	if c == null or c[0] != G.turn:
		c = [G.turn, 0.5 + 0.5 * resources(nid).ratio]
		_resCache[nid] = c
	return c[1]
var _resCache := {}
## その国に足りない資源を、相手が持っているか（戦の狙いに使う）
func resWant(nid: int, o: int) -> bool:
	if resMul(nid) >= 0.95: return false
	for t in ownList(o):
		if t.get("ress", {}).size(): return true
	return false
## 消費財：民需工場の出力のうち国内の消費に取られる割合（経済法で変わる）。標準（30%）で 1.0 倍
func consumerMul(na: Dictionary) -> float: return clamp_f(1.0 - (consumerShare(na) - 0.30), 0.6, 1.3)
func coastCount(nid: int) -> int:
	coastInfo()
	var n := 0
	for t in ownList(nid):
		if COAST.has(t.id): n += 1
	return n
