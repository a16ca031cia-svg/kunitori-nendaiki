# 起動・速さ・セーブ／ロード・表示の好み（元 7220〜7400・7608〜7780）

signal game_started
var auto_on := false

func newGame(size: String) -> void:
	resetColors()
	G = genJapan() if size == "japan" else genMap(size)
	G.observer = true
	for t in G.terrs:
		t.home = t.owner
		t.homeCap = t.cap
	G.factions = {}
	G.ncol = NCOL.duplicate()
	hoiInit(G)
	beginGame()
func _resetCaches() -> void:
	NBR = null; NBR_G = null; SEGN_DONE = null; COAST_G = null; HOP_G = null; ADJ_G = null
	PW_KEY = ""; THR_KEY = ""; DG_KEY = ""; SUP_TERR_KEY = ""; SUP_DIRTY = true
	FOCUS_CACHE = {}; SPROG_MEMO = {}; DIPQ = []
	_treeCache = {}
func beginGame() -> void:
	_resetCaches()
	UI.sel = null; UI.selArmy = null; UI.selRoad = null; UI.busy = false; UI.auto = false; UI.selNat = null
	auto_on = false
	G.log = []
	refreshSupply(true)
	var names := []
	for n in G.nations: names.append(n.name)
	chron("%dつの国が並び立つ — %s" % [G.nations.size(), "、".join(names)], -1, "end")
	for n in G.nations: chron("%s、%s に旗を立てる（%s）" % [n.name, T(n.capital).name, PERSONA[n.persona].n], n.id, "gov")
	recordHistory()
	logMsg("観戦モード：全%dか国をCPUが操作します" % G.nations.size(), "good")
	logMsg("「自動進行」で連続再生、「戦闘表示」で戦闘画面の表示を切り替えられます")
	game_started.emit()
	refreshed.emit()

## 自動進行（もう一度呼ぶと止まる）
signal auto_changed(on: bool)
func toggleAuto() -> void:
	if G == null or G.over != null: return
	auto_on = not auto_on
	UI.auto = auto_on
	auto_changed.emit(auto_on)
	if not auto_on: return
	while auto_on and G != null and G.over == null:
		if UI.busy:
			await sleep_ms(200)
			continue
		var t0 := Time.get_ticks_msec()
		await endTurn()
		await sleep_ms(max(40, CFG.autoTurnMs - (Time.get_ticks_msec() - t0)))
	auto_on = false
	UI.auto = false
	auto_changed.emit(false)
func stopAuto() -> void:
	if auto_on:
		auto_on = false
		UI.auto = false
		auto_changed.emit(false)

# ---------- 速さ ----------
const SPEEDS := [
	{"n": "遅い", "auto": 1600, "cpu": 520, "phase": 700, "beat": 4500},
	{"n": "普通", "auto": 700, "cpu": 340, "phase": 480, "beat": 2500},
	{"n": "速い", "auto": 250, "cpu": 130, "phase": 160, "beat": 900},
	{"n": "最速", "auto": 40, "cpu": 0, "phase": 0, "beat": 0},
]
func setSpeed(i: int, save := true) -> void:
	i = int(clamp_f(i, 0, SPEEDS.size() - 1))
	var s: Dictionary = SPEEDS[i]
	CFG.autoTurnMs = s.auto; CFG.cpuDelay = s.cpu; CFG.phaseDelay = s.phase; BEAT_MAX = s.beat
	UI.speed = i
	if save: savePrefs()

# ---------- 表示の好み（この端末だけ） ----------
const PREF_PATH := "user://prefs.json"
func loadPrefs() -> void:
	var p := {}
	if FileAccess.file_exists(PREF_PATH):
		var v = JSON.parse_string(FileAccess.get_file_as_string(PREF_PATH))
		if v is Dictionary: p = v
	if p.get("battle") is bool: CFG.showCpuBattle = p.battle
	if p.get("dip") is bool: CFG.showDip = p.dip
	if p.get("log") is bool: UI.logOn = p.log
	UI.bgm = p.get("bgm", true) if p.get("bgm") is bool else true
	UI.sfx = p.get("sfx", true) if p.get("sfx") is bool else true
	setSpeed(int(p.get("speed", 1)))
func savePrefs() -> void:
	var f := FileAccess.open(PREF_PATH, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({"speed": UI.speed, "battle": CFG.showCpuBattle, "dip": CFG.showDip, "log": UI.logOn, "bgm": UI.get("bgm", true), "sfx": UI.get("sfx", true)}))
	f.close()

# ---------- セーブ／ロード（3スロット） ----------
func _slotPath(i: int) -> String: return "user://slot%d.sav" % i
func _slotInfoPath(i: int) -> String: return "user://slot%d.json" % i
func slotInfo(i: int):
	if not FileAccess.file_exists(_slotInfoPath(i)) or not FileAccess.file_exists(_slotPath(i)): return null
	var v = JSON.parse_string(FileAccess.get_file_as_string(_slotInfoPath(i)))
	return v if v is Dictionary else null
func _stripForSave(g: Dictionary) -> Dictionary:
	var c: Dictionary = g.duplicate(true)
	for na in c.nations: na.erase("supSet")
	for t in c.terrs:
		t.erase("segN"); t.erase("bb")
		if c.size == "japan":
			t.erase("segs"); t.erase("sn")
	if c.size == "japan":
		c.erase("edges"); c.erase("nb")
	for na in c.nations:
		for a in na.armies:
			if a != null: a.erase("anim")
	return c
func saveSlot(i: int) -> bool:
	if G == null: return false
	var dt := Time.get_datetime_dict_from_system()
	G.savedAt = "%02d/%02d %02d:%02d" % [dt.month, dt.day, dt.hour, dt.minute]
	G.savedTs = Time.get_unix_time_from_system()
	var f := FileAccess.open_compressed(_slotPath(i), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null: return false
	f.store_var(_stripForSave(G))
	f.close()
	var alive := 0
	for n in G.nations:
		if n.alive: alive += 1
	var inf := FileAccess.open(_slotInfoPath(i), FileAccess.WRITE)
	inf.store_string(JSON.stringify({"turn": G.turn, "size": G.size, "nat": alive, "all": G.terrs.size(), "date": G.savedAt, "ts": G.savedTs}))
	inf.close()
	logMsg("スロット%d にセーブしました" % i, "good")
	return true
func loadSlot(i: int) -> bool:
	if not FileAccess.file_exists(_slotPath(i)): return false
	var f := FileAccess.open_compressed(_slotPath(i), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null: return false
	var g = f.get_var()
	f.close()
	if not (g is Dictionary): return false
	if g.size == "japan":
		var fm := FileAccess.open_compressed("res://data/jp/map%d.bin" % int(g.get("jpMap", 0)), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		var m: Dictionary = fm.get_var()
		fm.close()
		for k in g.terrs.size():
			g.terrs[k].segs = m.terrs[k].segs
			g.terrs[k].sn = m.terrs[k].sn
		g.edges = m.edges
		g.nb = m.nb
	if g.nations.size() and not IDEO.has(g.nations[0].get("ideo", "")):
		for n in g.nations:
			n.erase("ideo")
		hoiInit(g)
	resetColors(g.get("ncol", null))
	stopAuto()
	G = g
	_resetCaches()
	UI.sel = null; UI.selArmy = null; UI.selNat = null; UI.busy = false
	refreshSupply(true)
	game_started.emit()
	refreshed.emit()
	logMsg("スロット%d をロードしました" % i, "good")
	return true
func latestSlot() -> int:
	var best := 0
	var bt := -1.0
	for i in [1, 2, 3]:
		var s = slotInfo(i)
		if s != null and float(s.get("ts", 1)) > bt:
			bt = float(s.get("ts", 1))
			best = i
	return best
