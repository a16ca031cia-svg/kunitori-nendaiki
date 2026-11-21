# 国盗り年代記 — 画面（上の帯・地図・右の欄・窓）（元 2910〜3525・7608〜7780 の画面部分）
extends Control

const C_INK := Color("#11141a")
const C_INK2 := Color("#171b23")
const C_PANEL := Color("#1d222c")
const C_PANEL2 := Color("#252b38")
const C_LINE := Color("#39414f")
const C_LINE2 := Color("#4d5666")
const C_BRASS := Color("#c9a227")
const C_BRASS2 := Color("#e6c95a")
const C_BONE := Color("#eae4d6")
const C_MUTED := Color("#9b9484")
const C_DANGER := Color("#c0504a")
const C_OK := Color("#6d9c63")
const C_WARN := Color("#d29b3c")

var fontR: Font
var fontB: Font
var fontD: Font
var map: Control
var side: RichTextLabel
var sideScroll: ScrollContainer
var stats: RichTextLabel
var natPick: OptionButton
var spdPick: OptionButton
var btnAuto: Button
var btnEnd: Button
var menuBtn: MenuButton
var logBox: RichTextLabel
var phaseBox: PanelContainer
var phaseLbl: RichTextLabel
var toastBox: VBoxContainer
var tip: PanelContainer
var tipLbl: RichTextLabel
var modalLayer: Control
var titleScr: Control
var stage: BoxContainer
var natPickIds = []
var peaceOpen = false
var recTab = "chron"
var chronFilter = "all"
var chronNation = -1
var statSort = "pw"

func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	var si = args.find("--sim")
	if si >= 0:
		await _sim(args[si + 1] if args.size() > si + 1 else "small", int(args[si + 2]) if args.size() > si + 2 else 30)
		get_tree().quit()
		return
	_buildTheme()
	_buildUI()
	S.loadPrefs()
	_syncMenu()
	spdPick.select(S.UI.speed)
	S.log_changed.connect(_renderLog)
	S.notified.connect(_toast)
	S.refreshed.connect(refresh)
	S.beat.connect(_onBeat)
	_setupAudio()
	S.captured.connect(func(_tid, nid, old): if S.concerns([nid, old]): _sfx("capture", -5.0))
	S.nation_fell.connect(func(_n): _sfx("fall", -3.0))
	S.turn_ended.connect(func(): _sfx("turn", -15.0))
	S.phase_changed.connect(_setPhase)
	S.auto_changed.connect(func(on): btnAuto.text = "■ 停止" if on else "自動進行")
	S.game_over.connect(_onGameOver)
	S.dip_show.connect(_showDip)
	S.battle_show.connect(_showBattle)
	S.game_started.connect(_onStarted)
	S.nations_changed.connect(func(): _natPickKey = "")
	S.onScreenFn = func(t): return map.onScreen(t)
	_showTitle()
	if args.has("--autostart"): _newGame("japan")
	if OS.has_feature("web"): _debugHash()

# ============================================================
#   見た目（テーマ）
# ============================================================
func _sb(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 2, pad := 6) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s
func _buildTheme() -> void:
	fontR = load("res://fonts/ZenKakuGothicNew-Regular.ttf")
	fontB = load("res://fonts/ZenKakuGothicNew-Bold.ttf")
	fontD = load("res://fonts/ShipporiMinchoB1-SemiBold.ttf")
	var th = Theme.new()
	th.default_font = fontR
	th.default_font_size = 14
	th.set_color("font_color", "Label", C_BONE)
	th.set_color("default_color", "RichTextLabel", C_BONE)
	th.set_font("bold_font", "RichTextLabel", fontB)
	th.set_font("normal_font", "RichTextLabel", fontR)
	th.set_font_size("normal_font_size", "RichTextLabel", 13)
	th.set_font_size("bold_font_size", "RichTextLabel", 13)
	for cls in ["Button", "OptionButton", "MenuButton"]:
		th.set_stylebox("normal", cls, _sb(C_PANEL2, C_LINE2, 1, 2, 5))
		th.set_stylebox("hover", cls, _sb(Color("#31394a"), C_BRASS, 1, 2, 5))
		th.set_stylebox("pressed", cls, _sb(Color("#3a4356"), C_BRASS, 1, 2, 5))
		th.set_stylebox("disabled", cls, _sb(Color(C_PANEL2, 0.4), Color(C_LINE2, 0.4), 1, 2, 5))
		th.set_stylebox("focus", cls, _sb(Color(0, 0, 0, 0), C_BRASS, 2, 2, 5))
		th.set_color("font_color", cls, C_BONE)
		th.set_color("font_hover_color", cls, Color.WHITE)
		th.set_color("font_pressed_color", cls, Color.WHITE)
		th.set_color("font_disabled_color", cls, Color(C_BONE, 0.38))
		th.set_font_size("font_size", cls, 13)
	th.set_stylebox("panel", "PanelContainer", _sb(C_PANEL, C_LINE2, 1, 3, 8))
	th.set_stylebox("panel", "PopupMenu", _sb(C_PANEL, C_LINE2, 1, 3, 6))
	th.set_color("font_color", "PopupMenu", C_BONE)
	th.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	th.set_color("font_separator_color", "PopupMenu", C_BRASS2)
	th.set_stylebox("hover", "PopupMenu", _sb(Color("#31394a"), Color(0, 0, 0, 0), 0, 2, 4))
	th.set_font_size("font_size", "PopupMenu", 14)
	th.set_stylebox("panel", "TooltipPanel", _sb(C_PANEL, C_LINE2, 1, 3, 6))
	th.set_color("font_color", "TooltipLabel", C_BONE)
	theme = th

func _btn(text: String, cb: Callable, primary := false) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): _sfx("click", -12.0))
	b.pressed.connect(cb)
	if primary:
		b.add_theme_stylebox_override("normal", _sb(Color("#7a6219"), Color("#a98c2c"), 1, 2, 5))
		b.add_theme_stylebox_override("hover", _sb(Color("#94792a"), C_BRASS2, 1, 2, 5))
		b.add_theme_font_override("font", fontB)
		b.add_theme_color_override("font_color", Color("#fdf6dd"))
	return b
func _rtl(fit := true) -> RichTextLabel:
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = fit
	r.scroll_active = not fit
	r.selection_enabled = false
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.meta_underlined = false
	return r

# ============================================================
#   画面の組み立て
# ============================================================
func _buildUI() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = C_INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vb = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	add_child(vb)
	# 上の帯
	var top = PanelContainer.new()
	top.add_theme_stylebox_override("panel", _sb(C_INK2, Color(0, 0, 0, 0), 0, 0, 5))
	vb.add_child(top)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	top.add_child(hb)
	var ttl = Label.new()
	ttl.text = "国盗り年代記"
	ttl.add_theme_font_override("font", fontD)
	ttl.add_theme_font_size_override("font_size", 19)
	ttl.add_theme_color_override("font_color", C_BRASS2)
	hb.add_child(ttl)
	stats = _rtl(false)
	stats.custom_minimum_size = Vector2(40, 22)
	stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats.clip_contents = true
	hb.add_child(stats)
	natPick = OptionButton.new()
	natPick.custom_minimum_size = Vector2(150, 0)
	natPick.focus_mode = Control.FOCUS_NONE
	natPick.item_selected.connect(_onNatPick)
	natPick.tooltip_text = "観戦する国を選びます。選ぶと国全体が見える位置に移ります"
	hb.add_child(natPick)
	hb.add_child(_btn("記録", func(): openRecord()))
	btnAuto = _btn("自動進行", func(): S.toggleAuto())
	btnAuto.tooltip_text = "ターンを続けて進めます（A）"
	hb.add_child(btnAuto)
	spdPick = OptionButton.new()
	spdPick.focus_mode = Control.FOCUS_NONE
	for s in S.SPEEDS: spdPick.add_item(s.n)
	spdPick.item_selected.connect(func(i): S.setSpeed(i); _toast("速さ：" + S.SPEEDS[i].n, ""))
	spdPick.tooltip_text = "自動進行・演出の速さ（[ と ] でも切り替え）"
	hb.add_child(spdPick)
	menuBtn = MenuButton.new()
	menuBtn.text = "メニュー ≡"
	menuBtn.flat = false
	var pm = menuBtn.get_popup()
	pm.add_check_item("戦闘表示", 0)
	pm.add_check_item("外交報告", 1)
	pm.add_check_item("出来事の表示", 2)
	pm.add_check_item("音楽", 6)
	pm.add_check_item("効果音", 7)
	pm.add_separator()
	pm.add_item("セーブ／ロード", 3)
	pm.add_item("操作方法（?）", 4)
	pm.add_item("タイトルへ", 5)
	pm.id_pressed.connect(_onMenu)
	hb.add_child(menuBtn)
	btnEnd = _btn("ターン進行", func(): _endTurn(), true)
	btnEnd.tooltip_text = "1ターン進めます（スペース）"
	hb.add_child(btnEnd)
	# 地図と右の欄
	stage = HBoxContainer.new()
	stage.add_theme_constant_override("separation", 0)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(stage)
	var mapWrap = Control.new()
	mapWrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mapWrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mapWrap.clip_contents = true
	stage.add_child(mapWrap)
	map = preload("res://scripts/ui/map_view.gd").new()
	map.font = fontR
	map.fontB = fontB
	map.fontD = fontD
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	mapWrap.add_child(map)
	map.clicked.connect(_onMapClick)
	map.hovered.connect(_onHover)
	# 地図の上の表示
	phaseBox = PanelContainer.new()
	phaseBox.add_theme_stylebox_override("panel", _sb(Color(C_PANEL, 0.92), C_LINE2, 1, 3, 4))
	phaseBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phaseBox.position = Vector2(12, 10)
	phaseBox.visible = false
	phaseLbl = _rtl()
	phaseLbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	phaseLbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phaseBox.add_child(phaseLbl)
	mapWrap.add_child(phaseBox)
	toastBox = VBoxContainer.new()
	toastBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toastBox.position = Vector2(0, 54)
	mapWrap.add_child(toastBox)
	logBox = _rtl()
	logBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logBox.custom_minimum_size = Vector2(430, 0)
	logBox.add_theme_constant_override("outline_size", 4)
	logBox.add_theme_color_override("font_outline_color", Color(0.07, 0.08, 0.1, 0.85))
	mapWrap.add_child(logBox)
	var placeLog = func(): logBox.position = Vector2(10, mapWrap.size.y - logBox.size.y - 10)
	mapWrap.resized.connect(placeLog)
	logBox.resized.connect(placeLog)
	var zb = VBoxContainer.new()
	for d in [["+", func(): map.zoomAt(1.25, map.size.x / 2, map.size.y / 2), "拡大"], ["-", func(): map.zoomAt(0.8, map.size.x / 2, map.size.y / 2), "縮小"],
			["◎", func(): if S.UI.selNat != null: map.frameNation(S.UI.selNat), "選んだ国の全体を表示（C）"], ["全", func(): map.fitView(), "全体表示（F）"]]:
		var b = _btn(d[0], d[1])
		b.custom_minimum_size = Vector2(36, 32)
		b.tooltip_text = d[2]
		zb.add_child(b)
	mapWrap.add_child(zb)
	mapWrap.resized.connect(func(): zb.position = Vector2(mapWrap.size.x - 48, mapWrap.size.y - 160))
	tip = PanelContainer.new()
	tip.add_theme_stylebox_override("panel", _sb(Color(C_PANEL, 0.96), C_LINE2, 1, 3, 5))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = false
	tipLbl = _rtl()
	tipLbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tipLbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_child(tipLbl)
	mapWrap.add_child(tip)
	# 右の欄
	sideScroll = ScrollContainer.new()
	sideScroll.custom_minimum_size = Vector2(350, 0)
	sideScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var sideBg = PanelContainer.new()
	sideBg.add_theme_stylebox_override("panel", _sb(C_INK2, C_LINE, 0, 0, 10))
	sideBg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sideBg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sideScroll.add_child(sideBg)
	side = _rtl()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.meta_clicked.connect(_onMeta)
	sideBg.add_child(side)
	stage.add_child(sideScroll)
	resized.connect(_layout)
	# 窓
	modalLayer = Control.new()
	modalLayer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modalLayer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modalLayer)
	_layout()
## 狭い画面では右の欄を下へ
func _layout() -> void:
	if stage == null: return
	var narrow = size.x < 760
	if (narrow and stage is HBoxContainer) or (not narrow and stage is VBoxContainer):
		var parent = stage.get_parent()
		var idx = stage.get_index()
		var kids = stage.get_children()
		var nb: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
		nb.add_theme_constant_override("separation", 0)
		nb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for k in kids: stage.remove_child(k)
		parent.remove_child(stage)
		stage.queue_free()
		parent.add_child(nb)
		parent.move_child(nb, idx)
		for k in kids: nb.add_child(k)
		stage = nb
	sideScroll.custom_minimum_size = Vector2(0, size.y * 0.38) if narrow else Vector2(min(350, size.x * 0.34), 0)

# ============================================================
#   タイトル
# ============================================================
var _sizeSel = "japan"
func _showTitle() -> void:
	if titleScr != null: titleScr.queue_free()
	S.stopAuto()
	titleScr = Control.new()
	titleScr.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(titleScr)
	move_child(modalLayer, -1)
	var bg = ColorRect.new()
	bg.color = Color(0.067, 0.078, 0.102, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	titleScr.add_child(bg)
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	titleScr.add_child(cc)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(min(520, size.x - 32), 0)
	cc.add_child(box)
	var h = Label.new()
	h.text = "国盗り年代記"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", fontD)
	h.add_theme_font_size_override("font_size", 40)
	h.add_theme_color_override("font_color", C_BRASS2)
	box.add_child(h)
	var rule = ColorRect.new()
	rule.color = C_BRASS
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)
	var p = Label.new()
	p.text = "中世・群雄争覇のシミュレーション — 国々の興亡を見届ける"
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_theme_color_override("font_color", C_MUTED)
	box.add_child(p)
	var lb = Label.new()
	lb.text = "地図（日本／架空の大陸）"
	lb.add_theme_color_override("font_color", C_MUTED)
	lb.add_theme_font_size_override("font_size", 12)
	box.add_child(lb)
	var grid = GridContainer.new()
	grid.columns = 4 if size.x > 560 else 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var opts = [["japan", "日本", "47都道府県"], ["small", "小", "250領地・8国"], ["mid", "中", "400領地・10国"], ["large", "大", "600領地・12国"]]
	var group = []
	for o in opts:
		var b = Button.new()
		b.text = o[1] + "\n" + o[2]
		b.toggle_mode = true
		b.button_pressed = o[0] == _sizeSel
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(110, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("pressed", _sb(Color("#3a3218"), C_BRASS, 1, 2, 5))
		var key: String = o[0]
		b.pressed.connect(func():
			_sizeSel = key
			for x in group: x.button_pressed = x == b)
		group.append(b)
		grid.add_child(b)
	var bNew = _btn("開始（全勢力CPU）", func(): pass, true)
	bNew.custom_minimum_size = Vector2(0, 40)
	bNew.pressed.connect(func():
		bNew.text = "地図を作っています…"
		bNew.disabled = true
		await get_tree().process_frame
		await get_tree().process_frame
		_newGame(_sizeSel))
	box.add_child(bNew)
	var last: int = S.latestSlot()
	if last:
		var inf = S.slotInfo(last)
		box.add_child(_btn("続きから（スロット%d・%dターン）" % [last, int(inf.turn)], func(): _loadSlot(last)))
	box.add_child(_btn("ロード", func(): openSave(true)))
	var help = Label.new()
	help.text = "スペースで1ターン・Aで自動進行・?で操作方法\n国を押すと、その国の目線で観戦できます"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color("#6f6a5e"))
	help.add_theme_font_size_override("font_size", 12)
	box.add_child(help)
func _hideTitle() -> void:
	if titleScr != null:
		titleScr.queue_free()
		titleScr = null
func _newGame(size_: String) -> void:
	S.newGame(size_)
func _loadSlot(i: int) -> void:
	closeModal()
	if not S.loadSlot(i): _toast("読み込めませんでした", "err")
func _onStarted() -> void:
	_updateBgm(true)
	_hideTitle()
	closeModal()
	_natPickKey = ""
	map.setup()
	map.fitView()
	refresh()

# ============================================================
#   更新
# ============================================================
func refresh() -> void:
	if S.G == null: return
	if S.UI.selNat != null and not S.NAT(S.UI.selNat).alive: S.UI.selNat = null
	_syncNatPick()
	_renderTop()
	_renderSide()
	_renderLog()
	map.refreshAll()
	btnEnd.disabled = S.UI.busy or S.auto_on
	_updateBgm()
func _col(c) -> String: return c.to_html(false) if c is Color else String(c).trim_prefix("#")
func _cs(text: String, c) -> String: return "[color=#%s]%s[/color]" % [_col(c), text]
func _esc(s: String) -> String: return s.replace("[", "[lb]")
func _rd(hex: String) -> String: return map.readable(hex).to_html(false)
func _renderTop() -> void:
	var alive = 0
	for n in S.G.nations:
		if n.alive: alive += 1
	var wars: int = S.G.wars.size()
	var st = []
	st.append(["ターン", "%d / %d" % [S.G.turn, S.TURN_MAX]])
	st.append(["勢力", "%d 国" % alive])
	st.append(["戦争", _cs("%d 件" % wars, C_DANGER) if wars else _cs("なし", C_OK)])
	var wild: int = S.wildCount()
	if wild: st.append(["無主の地", str(wild)])
	var top = S.topThreat()
	if top != null: st.append(["最大の脅威", _cs(_esc(S.NAT(top.id).name), _rd(S.NAT(top.id).color))])
	if S.inCalm(): st.append(["平穏期", "あと%dT" % (S.DIP.calmTurns - S.G.turn + 1)])
	var sel = S.UI.selNat
	if sel != null and sel >= 0 and S.NAT(sel).alive:
		var na = S.NAT(sel)
		var own = 0
		for t in S.G.terrs:
			if t.owner == sel: own += 1
		st.append(["選択中", _cs(_esc(na.name), _rd(na.color))])
		st.append(["ゴールド", S.fmt(na.gold) + " G"])
		st.append(["食料", S.fmt(na.food)])
		st.append(["兵力", S.fmt(S.nationTroops(sel))])
		st.append(["領地", str(own)])
	var parts = []
	for s in st: parts.append("[font_size=10][color=#9b9484]%s[/color][/font_size] [b]%s[/b]" % s)
	stats.text = "   ".join(parts)
const LOG_BIG := ["宣戦", "滅亡", "降伏", "講和", "和平", "蜂起", "復活", "陣営", "独立", "併合", "従属", "属国", "統一", "天下", "観戦モード", "自動進行"]
func _renderLog() -> void:
	if S.G == null or not S.UI.logOn:
		logBox.text = ""
		return
	var n = 3 if size.x < 640 else 5
	var sel = S.UI.selNat
	var selName = S.NAT(sel).name if sel != null and sel >= 0 else null
	var list = []
	var i: int = S.G.log.size() - 1
	while i >= 0 and list.size() < n:
		var l: Dictionary = S.G.log[i]
		i -= 1
		if l.cls == "sep" or S.G.turn - l.get("t", 0) > 3: continue
		var keep = false
		if selName != null: keep = l.s.contains(selName)
		else:
			if l.cls == "war": keep = true
			for w in LOG_BIG:
				if l.s.contains(w): keep = true
		if keep: list.push_front(l)
	var out = []
	for l in list:
		var c = C_BONE
		if l.cls == "war": c = Color("#e8a49f")
		elif l.cls == "good": c = Color("#b5d6a8")
		out.append("[font_size=11][color=#9b9484]%dT[/color][/font_size] %s" % [l.get("t", 0), _cs(_esc(l.s), c)])
	logBox.text = "\n".join(out)
func _setPhase(nid, sub: String) -> void:
	if nid == null:
		phaseBox.visible = false
		return
	var na = S.NAT(nid)
	phaseLbl.text = "[color=#%s]●[/color] [b]%s のターン[/b]  [color=#9b9484][font_size=11]%s　%d/%d[/font_size][/color]" % [_col(na.color), _esc(na.name), _esc(sub), nid + 1, S.G.nations.size()]
	phaseBox.visible = true
	phaseBox.reset_size()
func _toast(msg: String, cls: String) -> void:
	var p = PanelContainer.new()
	var bc = C_LINE2
	if cls == "err": bc = C_DANGER
	elif cls == "good": bc = C_OK
	p.add_theme_stylebox_override("panel", _sb(Color(C_PANEL, 0.95), bc, 1, 3, 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l = Label.new()
	l.text = msg
	l.add_theme_font_size_override("font_size", 13)
	p.add_child(l)
	toastBox.add_child(p)
	while toastBox.get_child_count() > 3: toastBox.get_child(0).free()
	var tw = create_tween()
	tw.tween_interval(2.9)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)
	await get_tree().process_frame
	if is_instance_valid(toastBox):
		toastBox.reset_size()
		toastBox.position.x = (toastBox.get_parent().size.x - toastBox.size.x) / 2

# ---------- 国を選ぶ ----------
var _natPickKey = ""
const REG := [["北海道・東北", 0, 6], ["関東", 7, 13], ["中部", 14, 22], ["近畿", 23, 29], ["中国", 30, 34], ["四国", 35, 38], ["九州・沖縄", 39, 46]]
func _syncNatPick() -> void:
	var cnt = {}
	for t in S.G.terrs:
		if t.owner >= 0: cnt[t.owner] = cnt.get(t.owner, 0) + 1
	var key = ""
	for n in S.G.nations: key += (str(cnt.get(n.id, 0)) if n.alive else "-") + ","
	if key != _natPickKey:
		_natPickKey = key
		natPick.clear()
		natPickIds = []
		natPick.add_item("国を選ぶ…")
		natPickIds.append(null)
		var jp: bool = S.G.size == "japan" and S.G.nations.size() == 47
		var addN = func(n):
			natPick.add_item("%s%s" % [n.name, ("（%d）" % cnt.get(n.id, 0)) if n.alive else "（滅亡）"])
			natPick.set_item_disabled(natPick.item_count - 1, not n.alive)
			natPickIds.append(n.id)
		if jp:
			for r in REG:
				natPick.add_separator(r[0])
				natPickIds.append(null)
				for i in range(r[1], r[2] + 1): addN.call(S.G.nations[i])
		else:
			for n in S.G.nations: addN.call(n)
	if natPick.item_count == 0: return
	var want = S.UI.selNat
	natPick.select(max(0, natPickIds.find(want)) if want != null else 0)
func _onNatPick(i: int) -> void:
	selectNation(natPickIds[i], natPickIds[i] != null)
func selectNation(nid, frame := false) -> void:
	S.UI.selNat = nid
	S.UI.selArmy = null
	if nid != null: S.UI.sel = null
	if nid != null and frame: map.frameNation(nid)
	refresh()
func _onMapClick(wx: float, wy: float) -> void:
	if S.G == null: return
	var w = Vector2(wx, wy)
	var a2 = map.armyHit(w)
	var t2: int = a2.at if a2 != null else map.terrAt(w)
	if t2 < 0:
		S.UI.sel = null
		selectNation(null)
		return
	var nid: int = a2.owner if a2 != null else S.T(t2).owner
	S.UI.sel = null if nid >= 0 else t2
	selectNation(nid if nid >= 0 else null, nid >= 0 and nid == S.UI.selNat)
func _onHover(id: int, p: Vector2) -> void:
	if id < 0 or S.G == null:
		tip.visible = false
		return
	var t = S.T(id)
	var o = S.NAT(t.owner) if t.owner >= 0 else null
	var troops = 0
	var names = []
	for x in S.armiesAt(id):
		if S.total(x.t) > 0:
			troops += S.total(x.t)
			var nm: String = S.NAT(x.owner).name
			if not names.has(nm): names.append(nm)
	var s = "[b]%s[/b]%s\n%s・%s・%s 開発%d・インフラ %s" % [_esc(t.name), " [color=#c9a227]首都[/color]" if t.cap else "",
		_cs(_esc(o.name), _rd(o.color)) if o != null else "無主の地", S.terrOf(t).n, "都市" if t.type == "city" else "砦", t.dev, S.INFRA_N[int(t.get("infra", 1))]]
	if names.size(): s += "\n軍 %s %s" % ["・".join(names), S.fmt(troops)]
	tipLbl.text = "[font_size=12]" + s + "[/font_size]"
	tip.visible = true
	tip.reset_size()
	var mp: Vector2 = tip.get_parent().size
	tip.position = Vector2(min(mp.x - tip.size.x - 6, p.x + 16), min(mp.y - tip.size.y - 6, p.y + 18))

# ============================================================
#   右の欄
# ============================================================
func _renderSide() -> void:
	var h = ""
	if S.UI.selNat != null: h += natPanel(S.UI.selNat)
	if S.UI.sel != null: h += wildPanel(S.T(S.UI.sel))
	if h == "": h = worldPanel()
	side.text = h
func _h3(t: String, col := "eae4d6") -> String: return "[font=res://fonts/ShipporiMinchoB1-SemiBold.ttf][font_size=19][color=#%s]%s[/color][/font_size][/font]" % [col, t]
func _chip(t: String, col := "9b9484") -> String: return " [bgcolor=#252b38][color=#%s][font_size=11] %s [/font_size][/color][/bgcolor]" % [col, t]
func _lbl(t: String, col := "9b9484") -> String: return "\n[font_size=11][color=#%s]%s[/color][/font_size]" % [col, t]
func _kv(rows: Array) -> String:
	var s = "[table=2]"
	for r in rows:
		s += "[cell][color=#9b9484][font_size=12]%s　[/font_size][/color][/cell][cell][font_size=13]%s[/font_size][/cell]" % [r[0], r[1]]
	return s + "[/table]"
func _link(meta: String, t: String, col := "e6c95a") -> String: return "[url=%s][color=#%s]%s[/color][/url]" % [meta, col, t]
func _dot(col: String) -> String: return "[color=%s]●[/color]" % col
func _deltaTag(d: int) -> String:
	if d > 0: return " [color=#6d9c63][font_size=11]▲%d[/font_size][/color]" % d
	if d < 0: return " [color=#c0504a][font_size=11]▼%d[/font_size][/color]" % -d
	return ""
func _ownDelta(nid: int, now: int) -> int:
	var H: Array = S.G.hist
	if H.is_empty(): return 0
	var h = H[0]
	for i in range(H.size() - 1, -1, -1):
		if S.G.turn - H[i].t >= 10:
			h = H[i]
			break
	return now - (h.o[nid] if nid < h.o.size() else 0)
func _natLink(n: int) -> String: return _link("nat:%d" % n, _esc(S.NAT(n).name), _col(_rd(S.NAT(n).color)))
func worldPanel() -> String:
	var cnt = {}
	for t in S.G.terrs:
		if t.owner >= 0: cnt[t.owner] = cnt.get(t.owner, 0) + 1
	var alive = []
	for n in S.G.nations:
		if n.alive: alive.append(n)
	alive.sort_custom(func(a, b): return cnt.get(a.id, 0) > cnt.get(b.id, 0))
	var mx = 1
	for n in alive: mx = max(mx, cnt.get(n.id, 0))
	var s = _h3("天下の情勢") + _chip("%dターン目" % S.G.turn)
	s += _lbl("領地の多い国（▲▼＝この10ターンの増減）") + "\n"
	s += "[table=4]"
	for i in min(10, alive.size()):
		var n = alive[i]
		var c: int = cnt.get(n.id, 0)
		var bar = _bar(n.color, max(1, int(round(c * 10.0 / mx))))
		s += "[cell][color=#6f6a5e]%d[/color] [/cell][cell]%s %s[/cell][cell] %s[/cell][cell] [b]%d[/b]%s[/cell]" % [i + 1, _dot(n.color), _link("nat:%d" % n.id, _esc(n.name), _col(_rd(n.color))), bar, c, _deltaTag(_ownDelta(n.id, c))]
	s += "[/table]"
	if alive.size() > 10: s += _lbl("ほか %d か国" % (alive.size() - 10))
	s += "\n" + _lbl("戦争") + "\n"
	var wars: Array = S.G.wars.values()
	if wars.is_empty(): s += "[color=#9b9484]いまは戦争がありません[/color]\n"
	for k in min(8, wars.size()):
		var W = wars[k]
		s += "%s 陣営 [color=#c0504a]対[/color] %s 陣営 [color=#9b9484][font_size=11]（%dターン目・%dか国）[/font_size][/color]\n" % [_natLink(W.a), _natLink(W.b), S.G.turn - W.t0, W.sA.size() + W.sB.size()]
	if wars.size() > 8: s += "[color=#9b9484]ほか %d 件[/color]\n" % (wars.size() - 8)
	s += _lbl("陣営") + "\n"
	var facs = []
	for F in S.G.get("factions", {}).values():
		var any = false
		for m in F.members:
			if S.NAT(m).alive: any = true
		if any: facs.append(F)
	if facs.is_empty(): s += "[color=#9b9484]まだ陣営はありません[/color]\n"
	for F in facs:
		var nmem = 0
		for m in F.members:
			if S.NAT(m).alive: nmem += 1
		s += "[color=#b9a2e6][b]%s[/b][/color]　盟主 %s [color=#9b9484][font_size=11]（%dか国）[/font_size][/color]\n" % [_esc(F.name), _natLink(F.leader), nmem]
	s += "\n[color=#6f6a5e][font_size=12]国の名前か地図の国を押すと、その国の全体と情報が表示されます。選んだ国に関わる戦いや外交だけが知らされます。キー操作は「?」で確認できます。[/font_size][/color]"
	return s
func natPanel(nid: int) -> String:
	var na = S.NAT(nid)
	var own = []
	for t in S.G.terrs:
		if t.owner == nid: own.append(t)
	var city = 0
	var pop = 0
	var inf = 0.0
	var inf3 = 0
	var inf2 = 0
	for t in own:
		if t.type == "city": city += 1
		pop += t.pop
		var v: int = int(t.get("infra", 1))
		inf += v
		if v >= 3: inf3 += 1
		elif v == 2: inf2 += 1
	var thr = int(round(S.threatOf(nid)))
	var top = S.topThreat()
	var s = _h3(_esc(na.name), _col(_rd(na.color)))
	s += _chip(S.PERSONA[na.persona].n)
	if not na.alive: s += _chip("滅亡", "c0504a")
	if top != null and top.id == nid: s += _chip("最大の脅威", "c0504a")
	s += "\n"
	var rows = []
	rows.append(["領地", "%d%s ／ 都市 %d・砦 %d" % [own.size(), _deltaTag(_ownDelta(nid, own.size())), city, own.size() - city]])
	var F = S.facOf(nid)
	if F != null:
		var mem = []
		for m in F.members: mem.append(S.NAT(m).name)
		rows.append(["陣営", "[color=#b9a2e6][b]%s[/b][/color]　盟主 %s\n[font_size=11][color=#9b9484]加盟：%s[/color][/font_size]" % [_esc(F.name), _esc(S.NAT(F.leader).name), _esc("、".join(mem))]])
	if not na.alive and na.get("rebel", 0): rows.append(["旧領の不満", "%d / %d（溜まると旧領で蜂起）" % [int(na.rebel), S.REB.need]])
	if own.size(): rows.append(["インフラ", "平均 %.1f　[font_size=11][color=#9b9484]主要街道 %d・整った %d・乏しい %d[/color][/font_size]" % [inf / own.size(), inf3, inf2, own.size() - inf3 - inf2]])
	rows.append(["国力", S.fmt(S.nationPower(nid))])
	rows.append(["総兵力", S.fmt(S.nationTroops(nid))])
	rows.append(["人口", S.fmt(pop)])
	rows.append(["脅威度", _cs("%d　%s" % [thr, S.threatLabel(thr)], S.threatColor(thr))])
	var fat: float = na.get("fatigue", 0)
	rows.append(["戦争疲労", _cs("%d　%s" % [int(fat), S.fatigueLabel(fat)], C_DANGER if fat >= S.CFG.fatMid else C_BONE)])
	rows.append(["方針", S.polOf(na).n])
	rows.append(["気質", "[font_size=11]%s[/font_size]" % S.PERSONA[na.persona].dd])
	var tp: Array = S.tradePartners(nid)
	if tp.size():
		var nm = []
		for v in tp: nm.append(S.NAT(v).name)
		rows.append(["通商", _esc("、".join(nm))])
	var pacts = []
	for o in S.G.nations:
		if o.alive and S.pactLeft(nid, o.id) > 0: pacts.append(o.name)
	if pacts.size(): rows.append(["不可侵", _esc("、".join(pacts))])
	var dg: float = S.cpuDanger(nid)
	rows.append(["情勢", _cs(S.dangerLabel(dg), S.dangerColor(dg)) + " [font_size=11][color=#9b9484]（危険度 %.2f）[/color][/font_size]" % dg])
	var lord = S.lordOf(nid)
	if lord != null: rows.append(["主君", _cs("%s　不満 %d / %d" % [_esc(S.NAT(lord).name), int(na.get("unrest", 0)), S.DIP.unrestMax], C_BRASS)])
	var vsl: Array = S.vassalsOf(nid)
	if vsl.size():
		var nm = []
		for v in vsl: nm.append(S.NAT(v).name)
		rows.append(["属国", _esc("、".join(nm))])
	if na.get("revoltBuff", 0) > 0: rows.append([_cs("独立戦争", C_DANGER), _cs("あと%dターン 攻+%d%% 防+%d%%" % [na.revoltBuff, int(S.DIP.revoltAtk * 100), int(S.DIP.revoltDef * 100)], C_DANGER)])
	if S.freeLeft(nid) > 0: rows.append(["独立の余韻", _cs("あと%dターンは属国にできません" % S.freeLeft(nid), C_BRASS)])
	s += _kv(rows)
	s += "\n[font_size=11][color=#9b9484]地図の色 — [color=#f0cf55]選択中[/color]／[color=#c94b44]戦争[/color]／[color=#5f9c57]同盟[/color]／[color=#d8a03c]緊張[/color]／[color=#7fa8cf]青点線＝通行許可[/color][/color][/font_size]\n"
	s += _warPanel(nid)
	s += _desirePanel(nid)
	var rels = []
	for n in S.G.nations:
		if n.id == nid or not n.alive: continue
		var st: String = "vassal" if S.isVassal(n.id, nid) else ("lord" if S.isVassal(nid, n.id) else S.relState(nid, n.id))
		rels.append({"n": n, "st": st, "pass": S.canPass(n.id, nid) or S.canPass(nid, n.id), "f": int(round(S.favorOf(n.id, nid)))})
	rels.sort_custom(func(a, b): return a.f > b.f)
	for g in [["war", "戦争中", "c0504a"], ["tense", "緊張", "d29b3c"], ["lord", "主君", "c9a227"], ["vassal", "属国", "c9a227"], ["ally", "同盟", "6d9c63"], ["peace", "平和", "9b9484"]]:
		var list = rels.filter(func(r): return r.st == g[0])
		if list.is_empty(): continue
		var fold: bool = g[0] == "peace" and list.size() > 6
		if fold and not peaceOpen:
			s += "\n" + _link("fold:peace", "[font_size=11]%s（%d）　押して開く[/font_size]" % [g[1], list.size()], g[2]) + "\n"
			continue
		s += "\n" + (_link("fold:peace", "[font_size=11]%s（%d）　押して閉じる[/font_size]" % [g[1], list.size()], g[2]) if fold else "[font_size=11][color=#%s]%s（%d）[/color][/font_size]" % [g[2], g[1], list.size()]) + "\n"
		var chips = []
		for r in list:
			var extra = ""
			if r.st == "tense": extra = " [color=#%s][b]%s[/b][/color]" % [g[2], "準備中" if S.prepBy(nid, r.n.id) == nid else "警戒"]
			if r.pass and r.st != "ally": extra += " [color=#7fa8cf][b]通行[/b][/color]"
			chips.append("%s %s%s" % [_dot(r.n.color), _link("nat:%d" % r.n.id, _esc(r.n.name), _col(_rd(r.n.color))), extra])
		s += "　".join(chips) + "\n"
	s += "\n" + _link("act:natframe", "［国全体を表示］") + "　" + _link("act:natjump", "［首都へ移動］") + "　" + _link("act:natclear", "［選択を解除］") + "\n"
	return s
func _warPanel(nid: int) -> String:
	var ws = []
	for W in S.G.wars.values():
		if W.sA.has(nid) or W.sB.has(nid): ws.append(W)
	if ws.is_empty(): return ""
	var s = _lbl("関わっている戦争", "c0504a") + "\n"
	for W in ws:
		var sd: Array = S.sideOf(W, nid)
		var tot = 0.0
		for n in sd:
			if S.NAT(n).alive: tot += W.sc.get(n, 0)
		var role = "主戦国" if W.a == nid or W.b == nid else "加勢"
		var share = int(round(W.sc.get(nid, 0) / tot * 100)) if tot else 0
		var prog = func(n):
			if S.inThisWar(W, n): return "%s %d%%" % [S.NAT(n).name, int(round(S.surrenderProg(W, n) / S.surrenderLimit(n) * 100))]
			return "%s 降伏済" % S.NAT(n).name
		var pa = []
		for n in W.sA:
			if S.NAT(n).alive: pa.append(prog.call(n))
		var pb = []
		for n in W.sB:
			if S.NAT(n).alive: pb.append(prog.call(n))
		var mates = []
		for n in sd:
			if n != nid and S.NAT(n).alive: mates.append(S.NAT(n).name)
		s += "%s 陣営 対 %s 陣営\n[font_size=11]降伏まで：%s ／ %s\n[color=#9b9484]%s・味方 %s／戦いぶり %d（陣営の %d%%・講和会議で土地を要求する元手）[/color][/font_size]\n" % [
			_natLink(W.a), _natLink(W.b), _esc("、".join(pa)), _esc("、".join(pb)), role, _esc("、".join(mates)) if mates.size() else "なし", int(round(W.sc.get(nid, 0))), share]
	return s
func _desirePanel(nid: int) -> String:
	var s = _lbl("望み", "c9a227") + "\n"
	var mine: Array = S.desiresOf(nid)
	if mine.is_empty(): s += "[color=#9b9484]いまは特にない[/color]\n"
	for d in mine:
		s += "[color=#e0b64a][b]%s[/b][/color]　%s [font_size=11][color=#9b9484]（あと%dターンほど）[/color][/font_size]\n" % [S.DESIRE[d.k].n, _esc(S.desireText(d)), max(0, d.until - S.G.turn)]
	var aimed = []
	for o in S.G.nations:
		if not o.alive or o.id == nid: continue
		for d in S.desiresOf(o.id):
			if (S.DESIRE[d.k].war or d.k == "guard" or d.k == "protect") and S.desireNat(d) == nid: aimed.append([o, d])
	if aimed.size():
		s += _lbl("この国に向けられた望み", "c0504a") + "\n"
		for x in aimed: s += "%s %s：%s\n" % [_dot(x[0].color), _esc(x[0].name), _esc(S.desireText(x[1]))]
	return s
func wildPanel(t: Dictionary) -> String:
	var st = t.get("settle")
	var tr = S.terrOf(t)
	var s = _h3(_esc(t.name)) + _chip("都市" if t.type == "city" else "砦") + _chip("無主の地", "b9ad90") + _chip(tr.n, tr.c.trim_prefix("#"))
	if t.get("trait") != null: s += _chip(S.TRAIT[t.trait].n, S.TRAIT[t.trait].c.trim_prefix("#"))
	s += "\n[font_size=11][color=#9b9484]%s：%s%s\nどの国にも属していない土地です。自領と隣り合えば、開拓して治められます。軍団は自由に通過できますが、占領はできません。[/color][/font_size]\n" % [tr.n, tr.d, ("\n%s：%s" % [S.TRAIT[t.trait].n, S.TRAIT[t.trait].d]) if t.get("trait") != null else ""]
	var rows = [["人口", S.fmt(t.pop)], ["開発度", "%d / 5" % t.dev]]
	if st != null: rows.append(["開拓", "%s が開拓中（あと%dターン）" % [_cs(_esc(S.NAT(st.by).name), S.NAT(st.by).color), max(1, st.done - S.G.turn)]])
	s += _kv(rows)
	return s
func _onMeta(meta) -> void:
	var m = String(meta)
	if m.begins_with("nat:"):
		selectNation(int(m.substr(4)), true)
	elif m == "fold:peace":
		peaceOpen = not peaceOpen
		_renderSide()
	elif m == "act:natframe":
		if S.UI.selNat != null: map.frameNation(S.UI.selNat)
	elif m == "act:natjump":
		var na = S.NAT(S.UI.selNat)
		var cid = na.capital if S.T(na.capital).owner == na.id else null
		if cid == null:
			for t in S.G.terrs:
				if t.owner == na.id:
					cid = t.id
					break
		if cid != null: map.focusOn(cid)
	elif m == "act:natclear":
		selectNation(null)

# ============================================================
#   ターン・メニュー
# ============================================================
func _endTurn() -> void:
	if S.G == null or S.UI.busy or S.auto_on or S.G.over != null: return
	btnEnd.disabled = true
	await S.endTurn()
	btnEnd.disabled = false
	refresh()
func _onMenu(id: int) -> void:
	match id:
		0:
			S.CFG.showCpuBattle = not S.CFG.showCpuBattle
			_toast("CPU同士の戦闘画面を表示します" if S.CFG.showCpuBattle else "CPU同士の戦闘は結果のみ通知します", "")
		1:
			S.CFG.showDip = not S.CFG.showDip
			if not S.CFG.showDip: S.DIPQ = []
			_toast("外交の知らせを表示します" if S.CFG.showDip else "外交の知らせを表示しません", "")
		2:
			S.UI.logOn = not S.UI.logOn
			_renderLog()
		6:
			S.UI.bgm = not S.UI.get("bgm", true)
			_updateBgm(true)
		7: S.UI.sfx = not S.UI.get("sfx", true)
		3: if S.G != null: openSave(false)
		4: openHelp()
		5:
			if S.G != null and S.G.over == null:
				confirmModal("タイトルへ", "いまの進行（%dターン）はセーブしていなければ失われます。タイトルへ戻りますか。" % S.G.turn, func(): _showTitle())
			else: _showTitle()
	S.savePrefs()
	_syncMenu()
func _syncMenu() -> void:
	var pm = menuBtn.get_popup()
	pm.set_item_checked(pm.get_item_index(0), S.CFG.showCpuBattle)
	pm.set_item_checked(pm.get_item_index(1), S.CFG.showDip)
	pm.set_item_checked(pm.get_item_index(2), S.UI.logOn)
	pm.set_item_checked(pm.get_item_index(6), S.UI.get("bgm", true))
	pm.set_item_checked(pm.get_item_index(7), S.UI.get("sfx", true))

# ============================================================
#   窓（モーダル）
# ============================================================
var _modal: Control = null
var _modalKey = null
func closeModal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null
	_modalKey = null
func modal(title: String, body: Control, foot: Array, w := 560.0, dismiss := true) -> Control:
	closeModal()
	var ov = Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	if dismiss: dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: closeModal())
	ov.add_child(dim)
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cc)
	var pan = PanelContainer.new()
	var sb = _sb(C_PANEL, C_LINE2, 1, 3, 12)
	sb.border_width_top = 2
	pan.add_theme_stylebox_override("panel", sb)
	pan.custom_minimum_size = Vector2(min(w, size.x - 24), 0)
	cc.add_child(pan)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pan.add_child(vb)
	var hd = HBoxContainer.new()
	var h = Label.new()
	h.text = title
	h.add_theme_font_override("font", fontD)
	h.add_theme_font_size_override("font_size", 21)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(h)
	if dismiss: hd.add_child(_btn("閉じる", closeModal))
	vb.add_child(hd)
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	vb.add_child(sc)
	var fitH = func(): sc.custom_minimum_size.y = min(body.get_combined_minimum_size().y + 4, size.y * 0.66)
	body.resized.connect(fitH)
	body.minimum_size_changed.connect(fitH)
	fitH.call()
	if foot.size():
		var fb = HBoxContainer.new()
		fb.alignment = BoxContainer.ALIGNMENT_END
		fb.add_theme_constant_override("separation", 8)
		for b in foot:
			if b is Control: b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if b is RichTextLabel:
				b.autowrap_mode = TextServer.AUTOWRAP_OFF
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fb.add_child(b)
		vb.add_child(fb)
	modalLayer.add_child(ov)
	_modal = ov
	return ov
func _bodyText(bb: String) -> RichTextLabel:
	var r = _rtl()
	r.text = bb
	r.meta_clicked.connect(_onModalMeta)
	return r
func confirmModal(title: String, text: String, cb: Callable) -> void:
	modal(title, _bodyText(text), [_btn("やめる", closeModal), _btn("実行する", func(): closeModal(); cb.call(), true)], 440)
func openHelp() -> void:
	var rows = [["スペース", "1ターン進める"], ["A", "自動進行の開始／停止"], ["[　]", "速さを下げる／上げる"], ["R", "記録（年代記・統計）を開く"], ["F", "全体を表示"], ["C", "選んだ国の全体を表示"],
		["＋　－", "拡大／縮小（ホイール・二本指でも）"], ["矢印キー", "地図を動かす（ドラッグでも）"], ["Esc", "窓を閉じる・戦闘を飛ばす／国の選択を外す"], ["?", "この画面"]]
	var s = "[color=#9b9484]すべての国をCPUが動かします。気になる国を選んで、その国の目線で興亡を見届けてください。[/color]\n\n[table=2]"
	for r in rows: s += "[cell][b][color=#e6c95a]%s[/color][/b]　[/cell][cell]%s[/cell]" % [_esc(r[0]), r[1]]
	s += "[/table]\n\n[color=#9b9484]地図の国をクリックするとその国が選ばれ、もう一度押すとその国の全体が映ります。マウスを載せると領地の詳しい情報が出ます。選んだ国に関わる戦い・外交だけが知らされます。[/color]"
	modal("操作方法", _bodyText(s), [_btn("閉じる", closeModal, true)], 560)

# ---------- セーブ／ロード ----------
func openSave(loadOnly: bool) -> void:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	for i in [1, 2, 3]:
		var s = S.slotInfo(i)
		var row = PanelContainer.new()
		row.add_theme_stylebox_override("panel", _sb(C_PANEL2, C_LINE, 1, 3, 8))
		var hb = HBoxContainer.new()
		row.add_child(hb)
		var l = _rtl()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lab: String = {"small": "小", "mid": "中", "large": "大", "japan": "日本"}.get(s.size, "") if s != null else ""
		l.text = "[font=res://fonts/ShipporiMinchoB1-SemiBold.ttf][font_size=16]スロット %d[/font_size][/font]\n[color=#9b9484][font_size=12]%s[/font_size][/color]" % [i, ("%d ターン ／ 残り %d 国 ／ 領地 %d ／ マップ%s ／ %s" % [int(s.turn), int(s.nat), int(s.all), lab, s.date]) if s != null else "空き"]
		hb.add_child(l)
		var ii: int = i
		if not loadOnly:
			hb.add_child(_btn("セーブ", func():
				var doSave = func():
					if S.saveSlot(ii):
						_toast("スロット%d にセーブしました" % ii, "good")
						openSave(false)
					else: _toast("保存できませんでした", "err")
				if s != null: confirmModal("上書きの確認", "スロット%d（%dターン・%s）に上書きします。" % [ii, int(s.turn), s.date], doSave)
				else: doSave.call()))
		var lb = _btn("ロード", func():
			if S.G != null and not loadOnly and S.G.over == null:
				confirmModal("ロードの確認", "いまの進行（%dターン）はセーブしていなければ失われます。スロット%d をロードしますか。" % [S.G.turn, ii], func(): _loadSlot(ii))
			else: _loadSlot(ii))
		lb.disabled = s == null
		hb.add_child(lb)
		box.add_child(row)
	box.add_child(_bodyText("[font_size=11][color=#9b9484]データはこのブラウザ（端末）内に保存されます（3スロット・手動セーブのみ）。[/color][/font_size]"))
	modal("ロード" if loadOnly else "セーブ / ロード", box, [_btn("閉じる", closeModal)], 600)

# ---------- 記録（年代記・統計） ----------
const CHRON_F := [["all", "すべて"], ["fall", "攻防"], ["mile", "節目"], ["event", "出来事"], ["end", "興亡"]]
func openRecord(tab := "") -> void:
	if S.G == null: return
	if tab != "": recTab = tab
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var tabs = HBoxContainer.new()
	for tb in [["chron", "年代記"], ["stats", "統計"]]:
		var key: String = tb[0]
		tabs.add_child(_btn(tb[1], func(): openRecord(key), recTab == key))
	box.add_child(tabs)
	if recTab == "chron":
		var fl = HFlowContainer.new()
		for f in CHRON_F:
			var fk: String = f[0]
			fl.add_child(_btn(f[1], func(): chronFilter = fk; openRecord("chron"), chronFilter == fk))
		var op = OptionButton.new()
		op.focus_mode = Control.FOCUS_NONE
		op.add_item("全勢力")
		var ids = [-1]
		for n in S.G.nations:
			op.add_item(n.name + ("" if n.alive else "（滅亡）"))
			ids.append(n.id)
		op.select(max(0, ids.find(chronNation)))
		op.item_selected.connect(func(i): chronNation = ids[i]; openRecord("chron"))
		fl.add_child(op)
		box.add_child(fl)
		var list = []
		for e in S.G.chron:
			if chronFilter == "fall" and not (e.k == "fall" or e.k == "war"): continue
			if chronFilter != "all" and chronFilter != "fall" and e.k != chronFilter: continue
			if chronNation >= 0 and e.n != chronNation: continue
			list.append(e)
		box.add_child(_bodyText(_chronRows(list.slice(-300)) + "\n[font_size=11][color=#9b9484]全 %d 件を記録しています（古い記録から順に整理されます）。[/color][/font_size]" % S.G.chron.size()))
		modal("記録", box, [_btn("閉じる", closeModal)], 760)
	else:
		box.add_child(_bodyText(_statsText()))
		var ch = preload("res://scripts/ui/hist_chart.gd").new()
		ch.font = fontR
		ch.custom_minimum_size = Vector2(0, 300 if S.G.nations.size() > 6 else 220)
		box.add_child(ch)
		box.add_child(_bodyText("[font_size=11][color=#9b9484]国力の目安 ＝ 開発度（都市×120／砦×80）＋ 建物×60 ＋ 人口×0.006 ＋ 総兵力×0.6 ＋ ゴールド×0.05\n収入 ＝ 人口 × %s ＋ 市場 × %s　→　混乱・治安・戦争疲労・インフラ補正を掛けたもの[/color][/font_size]" % [str(S.CFG.taxRate), S.fmt(S.BLD_OUT.market.gold)]))
		modal("記録", box, [_btn("閉じる", closeModal)], 1100)
func _chronRows(list: Array) -> String:
	if list.is_empty(): return "[color=#9b9484]まだ記録がありません。[/color]"
	var out = []
	var col = {"fall": "e8a49f", "war": "e8a49f", "mile": "e6c95a", "end": "e6c95a", "dip": "b9c8e6", "event": "c8d6a8"}
	for i in range(list.size() - 1, -1, -1):
		var e = list[i]
		var dot = (_dot(S.ncol(e.n)) + " ") if e.n >= 0 else ""
		out.append("[font_size=11][color=#9b9484]第%dターン[/color][/font_size]　%s[color=#%s]%s[/color]" % [e.t, dot, col.get(e.k, "eae4d6"), _esc(e.s)])
	return "\n".join(out)
func _statsText() -> String:
	var cnt = {}
	var city = {}
	var pop = {}
	for t in S.G.terrs:
		if t.owner < 0: continue
		cnt[t.owner] = cnt.get(t.owner, 0) + 1
		if t.type == "city": city[t.owner] = city.get(t.owner, 0) + 1
		pop[t.owner] = pop.get(t.owner, 0) + t.pop
	var key = func(n):
		match statSort:
			"own": return float(cnt.get(n.id, 0))
			"troops": return float(S.nationTroops(n.id))
			"gold": return float(n.gold)
			"threat": return S.threatOf(n.id) if n.alive else -1.0
			"name": return float(-n.id)
		return S.nationPower(n.id)
	var ns: Array = S.G.nations.duplicate()
	ns.sort_custom(func(a, b):
		if a.alive != b.alive: return a.alive
		return key.call(a) > key.call(b))
	var mx = 1.0
	for n in S.G.nations: mx = max(mx, S.nationPower(n.id))
	var hd = func(k: String, t: String) -> String:
		return _link("sort:" + k, t + (" ▼" if statSort == k else ""), "e6c95a" if statSort == k else "9b9484")
	var s = "[font_size=12][table=12]"
	for h in [hd.call("name", "国"), "[color=#9b9484]性格[/color]", "[color=#9b9484]方針[/color]", "[color=#9b9484]従属・陣営[/color]", hd.call("own", "領地"), "[color=#9b9484]都市/砦[/color]",
			hd.call("troops", "総兵力"), "[color=#9b9484]人口[/color]", "[color=#9b9484]食料[/color]", hd.call("gold", "ゴールド"), hd.call("threat", "脅威度"), hd.call("pw", "国力")]:
		s += "[cell]%s　[/cell]" % h
	for n in ns:
		var dead: bool = not n.alive
		var nm = _link("nat:%d" % n.id, _esc(n.name), _col(_rd(n.color))) if n.alive else "[color=#6f6a5e]%s（滅亡）[/color]" % _esc(n.name)
		var rel = ""
		var lord = S.lordOf(n.id)
		if lord != null: rel = "%s の属国 (%d)" % [_esc(S.NAT(lord).name), int(n.get("unrest", 0))]
		elif S.vassalsOf(n.id).size(): rel = "属国 %d" % S.vassalsOf(n.id).size()
		var F = S.facOf(n.id)
		if F != null: rel += " [color=#b9a2e6]%s[/color]" % _esc(F.name)
		var pw: float = S.nationPower(n.id)
		var thr: float = S.threatOf(n.id)
		var cells = [_dot(n.color) + " " + nm, S.PERSONA[n.persona].n, S.polOf(n).n, "[color=#c9a227]%s[/color]" % rel, str(cnt.get(n.id, 0)),
			"%d / %d" % [city.get(n.id, 0), cnt.get(n.id, 0) - city.get(n.id, 0)], S.fmt(S.nationTroops(n.id)), S.fmt(pop.get(n.id, 0)),
			_cs(S.fmt(n.food), C_DANGER if n.food <= 0 else C_BONE), S.fmt(n.gold), _cs(str(int(round(thr))) if n.alive else "—", S.threatColor(thr)),
			_bar(n.color, max(1, int(round(pw / mx * 8)))) + " " + S.fmt(pw)]
		for k in cells.size():
			var c: String = cells[k]
			s += "[cell]%s　[/cell]" % (("[color=#6f6a5e]%s[/color]" % c) if dead and k > 0 else c)
	s += "[/table][/font_size]\n"
	var big = null
	for n in S.G.nations:
		for a in n.armies:
			if a != null and (big == null or S.total(a.t) > S.total(big.t)): big = a
	s += "\n[color=#9b9484][font_size=11]最大の軍団[/font_size][/color]　"
	s += ("%s %s [b]%s[/b] [color=#9b9484][font_size=11]%s ／ 通算 %d 勝[/font_size][/color]" % [_esc(S.NAT(big.owner).name), big.name, S.fmt(S.total(big.t)), _esc(S.T(big.at).name), big.get("wins", 0)]) if big != null else "なし"
	var deadL = []
	for n in S.G.nations:
		if not n.alive: deadL.append(_dot(n.color) + " " + _esc(n.name))
	s += "\n[color=#9b9484][font_size=11]滅亡した国[/font_size][/color]　" + ("　".join(deadL) if deadL.size() else "[color=#9b9484]まだありません[/color]")
	return s
func _onModalMeta(meta) -> void:
	var m = String(meta)
	if m.begins_with("sort:"):
		statSort = m.substr(5)
		openRecord("stats")
	elif m.begins_with("nat:"):
		var n = int(m.substr(4))
		if S.NAT(n).alive:
			closeModal()
			selectNation(n, true)

# ---------- 外交の知らせ ----------
func _showDip(ev: Dictionary) -> void:
	var snd = "notice"
	if ["war", "prep", "revolt", "join", "unally", "unpact", "surrender", "annex"].has(ev.kind): snd = "war"
	elif ["peace", "ally", "renew", "pact", "trade", "faction"].has(ev.kind) and ev.ok: snd = "peace"
	_sfx(snd, -4.0)
	var K: Dictionary = S.DIP_KIND.get(ev.kind, S.DIP_KIND.war)
	var A = S.NAT(ev.from)
	var B = S.NAT(ev.to)
	var st: String = S.relState(ev.from, ev.to)
	var s = "[center][font=res://fonts/ShipporiMinchoB1-SemiBold.ttf][font_size=18]%s  [color=%s]→[/color]  %s[/font_size][/font]\n[font_size=11][color=#9b9484]%s　　%s[/color][/font_size][/center]\n" % [
		_cs(_esc(A.name), _rd(A.color)), K.col, _cs(_esc(B.name), _rd(B.color)), S.PERSONA[A.persona].n, S.PERSONA[B.persona].n]
	s += "\n[font=res://fonts/ShipporiMinchoB1-SemiBold.ttf][font_size=16]%s は %s に %s[/font_size][/font]\n" % [_esc(A.name), _esc(B.name), K.v]
	s += _cs(_esc(S.dipResultText(ev)), C_BONE if ev.ok else C_MUTED) + "\n"
	if ev.note != "": s += "[font_size=11][color=#9b9484]%s[/color][/font_size]\n" % _esc(ev.note)
	s += "\n" + _kv([["いまの関係", _cs(S.REL_NAME.get(st, "—"), S.REL_COL.get(st, "#9b9484"))], ["%s の好感度" % _esc(B.name), str(int(round(S.favorOf(ev.to, ev.from))))],
		["国力", "%s 対 %s" % [S.fmt(S.nationPower(ev.from)), S.fmt(S.nationPower(ev.to))]]])
	var done = [false]
	var fin = func():
		if done[0]: return
		done[0] = true
		closeModal()
		S.dip_closed.emit()
	var foot = []
	if S.DIPQ.size(): foot.append(_bodyText("[font_size=11][color=#9b9484]ほかに %d 件[/color][/font_size]" % S.DIPQ.size()))
	foot.append(_btn("以後は表示しない", func(): S.CFG.showDip = false; S.DIPQ = []; S.savePrefs(); _syncMenu(); fin.call()))
	foot.append(_btn("OK", fin, true))
	modal(K.n + ("（不調）" if not ev.ok else "") + "　第%dターン" % ev.turn, _bodyText(s), foot, 460, false)
	_modalKey = fin

# ---------- 戦闘画面（観戦） ----------
func _showBattle(A: Array, D: Array, t: Dictionary) -> void:
	_sfx("battle", -4.0)
	var st0 = [S.sumTroops(A), S.sumTroops(D)]
	var body = _rtl()
	var speed = [int(S.UI.get("watchSpeed", 4))]
	var done = [false]
	var logs = []
	var paint = func():
		var sa: Dictionary = S.sideStats(A, t, false)
		var sd: Dictionary = S.sideStats(D, t, true)
		var side_ = func(list: Array, sst: Dictionary, k: int) -> String:
			var na = S.NAT(list[0].owner)
			var names = []
			for a in list: names.append(a.name)
			var now: float = S.sumTroops(list)
			var r = "%s [b]%s[/b]\n[font_size=11][color=#9b9484]%s ／ %s[/color][/font_size]\n[font_size=22][b]%s[/b][/font_size] [color=#c0504a]−%s[/color]\n" % [_dot(na.color), _esc("・".join(names)), _esc(na.name), "攻撃側" if k == 0 else "防衛側", S.fmt(now), S.fmt(max(0, st0[k] - now))]
			for tk in S.TK:
				var c = 0.0
				for a in list: c += a.t[tk]
				r += "[color=%s]■[/color] %s %s　" % [S.TROOP[tk].c, S.TROOP[tk].n, S.fmt(c)]
			r += "\n[font_size=11][color=#9b9484]攻撃力 %.1f　防御力 %.1f　突撃力 %.1f%%[/color][/font_size]" % [sst.atk, sst.def, sst.chg * 100]
			return r
		var ra: float = sa.tot / max(1.0, sa.tot + sd.tot)
		var na = int(round(ra * 30))
		body.text = "[table=2][cell]%s　　[/cell][cell]%s[/cell][/table]\n[center]%s%s\n戦力比 %d : %d[/center]\n[font_size=12]%s[/font_size]" % [
			side_.call(A, sa, 0), side_.call(D, sd, 1), _bar(S.NAT(A[0].owner).color, na * 2), _bar(S.NAT(D[0].owner).color, (30 - na) * 2),
			int(round(ra * 100)), 100 - int(round(ra * 100)), "\n".join(logs.slice(-6))]
	var finish = func(kind: String):
		if done[0]: return
		done[0] = true
		var res: String = S.battleFinish(A, D, kind)
		logs.append("[color=#e6c95a]%s[/color]" % ("攻撃側の勝利" if res == "A" else "防衛側が守り抜いた"))
		paint.call()
		await get_tree().create_timer(1.1).timeout
		closeModal()
		refresh()
		S.battle_done.emit(res)
	var rush = func():
		if done[0]: return
		for i in 20000:
			var r = S.battleTick(A, D, t)
			if r == null or S.sumTroops(A) <= 0 or S.sumTroops(D) <= 0: break
		finish.call("end")
	var spdBox = HBoxContainer.new()
	for sp in [1, 2, 4, 10]:
		var v: int = sp
		spdBox.add_child(_btn("×%d" % v, func(): speed[0] = v; S.UI.watchSpeed = v))
	var box = VBoxContainer.new()
	box.add_child(spdBox)
	box.add_child(body)
	var tl = "%s の戦い　%s" % [t.name, ("砦 防御+%d%%" % int(round((S.fortMul(t) - 1) * 100))) if t.type == "fort" else "都市"]
	modal(tl, box, [_bodyText("[font_size=11][color=#9b9484]観戦中：決着すると自動で閉じます[/color][/font_size]"), _btn("スキップ（Esc）", rush),
		_btn("以後は表示しない", func(): S.CFG.showCpuBattle = false; S.savePrefs(); _syncMenu(); rush.call())], 720, false)
	_modalKey = rush
	paint.call()
	while not done[0]:
		await get_tree().create_timer(0.07).timeout
		if done[0]: break
		for i in speed[0]:
			var r = S.battleTick(A, D, t)
			if r == null: break
			if r.ca: logs.append("[b]突撃！[/b] %s が敵防御を突き崩す" % A[0].name)
			if r.cd: logs.append("[b]突撃！[/b] 防衛軍が反撃に転じる")
			if S.sumTroops(A) <= 0 or S.sumTroops(D) <= 0:
				finish.call("end")
				return
		if not done[0]: paint.call()

# ---------- 決着 ----------
func _onGameOver(winner: int) -> void:
	await get_tree().create_timer(0.4).timeout
	var win = winner >= 0
	var s = "[center][font=res://fonts/ShipporiMinchoB1-SemiBold.ttf][font_size=28]%s[/font_size][/font]\n[color=#9b9484]第 %d ターン[/color][/center]\n" % [
		(_cs(_esc(S.NAT(winner).name), _rd(S.NAT(winner).color)) + " が全領地を制覇した") if win else "時代は終わった", S.G.turn]
	s += "\n[font_size=11][color=#9b9484]この世界の歴史[/color][/font_size]\n" + _chronRows(S.G.chron.slice(-60))
	modal("天下統一" if win else "終幕", _bodyText(s), [_btn("記録を開く", func(): openRecord("chron")), _btn("タイトルへ", func(): closeModal(); _showTitle(), true)], 640)

# ============================================================
#   キー操作
# ============================================================
func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo: return
	if ev.ctrl_pressed or ev.alt_pressed or ev.meta_pressed: return
	var k: int = ev.keycode
	if k == KEY_ESCAPE:
		if _modal != null:
			if _modalKey != null: _modalKey.call()
			else: closeModal()
		elif S.UI.selNat != null: selectNation(null)
		get_viewport().set_input_as_handled()
		return
	if _modal != null:
		if (k == KEY_ENTER or k == KEY_SPACE) and _modalKey != null:
			_modalKey.call()
			get_viewport().set_input_as_handled()
		return
	if S.G == null or titleScr != null: return
	var pan: float = 120 / map.vs
	match k:
		KEY_SPACE, KEY_ENTER: _endTurn()
		KEY_A: S.toggleAuto()
		KEY_R: openRecord()
		KEY_F: map.fitView()
		KEY_C: if S.UI.selNat != null: map.frameNation(S.UI.selNat)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_SEMICOLON: map.zoomAt(1.25, map.size.x / 2, map.size.y / 2)
		KEY_MINUS, KEY_KP_SUBTRACT: map.zoomAt(0.8, map.size.x / 2, map.size.y / 2)
		KEY_BRACKETLEFT:
			S.setSpeed(S.UI.speed - 1)
			spdPick.select(S.UI.speed)
			_toast("速さ：" + S.SPEEDS[S.UI.speed].n, "")
		KEY_BRACKETRIGHT:
			S.setSpeed(S.UI.speed + 1)
			spdPick.select(S.UI.speed)
			_toast("速さ：" + S.SPEEDS[S.UI.speed].n, "")
		KEY_SLASH, KEY_QUESTION: openHelp()
		KEY_LEFT:
			map.vx -= pan
			map.clampView()
		KEY_RIGHT:
			map.vx += pan
			map.clampView()
		KEY_UP:
			map.vy -= pan
			map.clampView()
		KEY_DOWN:
			map.vy += pan
			map.clampView()
		_: return
	get_viewport().set_input_as_handled()

# ============================================================
#   画面なしでターンを回して確かめる（godot --headless -- --sim japan 30）
# ============================================================
func _sim(size_: String, turns: int) -> void:
	S.CFG.showDip = false
	S.CFG.showCpuBattle = false
	S.setSpeed(3)
	var t0 = Time.get_ticks_msec()
	S.newGame(size_)
	print("new game ", size_, " terrs=", S.G.terrs.size(), " nations=", S.G.nations.size(), " ms=", Time.get_ticks_msec() - t0)
	for k in turns:
		var t1 = Time.get_ticks_msec()
		await S.endTurn()
		var alive = 0
		for n in S.G.nations:
			if n.alive: alive += 1
		print("turn ", S.G.turn, " alive=", alive, " wars=", S.G.wars.size(), " wild=", S.wildCount(), " ms=", Time.get_ticks_msec() - t1)
		if S.G.over != null:
			print("over winner=", S.G.winner)
			break
	var pol = {}
	var troops = 0
	var food = 0
	var gold = 0
	var pop = 0
	var alive2 = 0
	var vass = 0
	for n in S.G.nations:
		if not n.alive: continue
		alive2 += 1
		pol[n.policy] = pol.get(n.policy, 0) + 1
		troops += S.nationTroops(n.id)
		food += n.food
		gold += n.gold
		if S.lordOf(n.id) != null: vass += 1
	for t in S.G.terrs: pop += t.pop
	print("STATS alive=", alive2, " wars=", S.G.wars.size(), " vass=", vass, " pol=", pol, " troopsAvg=", troops / alive2, " foodAvg=", food / alive2, " goldAvg=", gold / alive2, " pop=", pop)
	for c in S.G.chron.slice(-15): print("  ", c.t, " ", c.s)
	var ks = S.PROF.keys()
	ks.sort_custom(func(a, b): return S.PROF[a] > S.PROF[b])
	for k in ks: print("PROF ", k, " ", S.PROF[k] / 1000, "ms")
## 色の帯（文字の背景色で描く）
func _bar(col: String, n: int) -> String:
	if n <= 0: return ""
	return "[bgcolor=%s][font_size=7]%s[/font_size][/bgcolor]" % [col, "　".repeat(n)]

## 動作確認用：URL の #size=small&ff=40&sel=war で、早送りしてから国を選んだ状態にする
func _debugHash() -> void:
	var h = str(JavaScriptBridge.eval("location.hash", true))
	if not h.begins_with("#") or not h.contains("ff="): return
	var q = {}
	for kv in h.substr(1).split("&"):
		var p = kv.split("=")
		if p.size() == 2: q[p[0]] = p[1]
	await get_tree().process_frame
	_newGame(q.get("size", "japan"))
	var keepDip = S.CFG.showDip
	var keepBattle = S.CFG.showCpuBattle
	var keepSpeed = S.UI.speed
	S.CFG.showDip = false
	S.CFG.showCpuBattle = false
	S.setSpeed(3, false)
	for i in int(q.get("ff", "0")):
		await S.endTurn()
		if S.G.over != null: break
	# 確認用なので、早送りの後は既定の表示（戦闘・外交の知らせあり・普通の速さ）に戻す
	S.CFG.showDip = true
	S.CFG.showCpuBattle = true
	S.setSpeed(1)
	spdPick.select(1)
	_syncMenu()
	if q.get("allbattles", "") == "1": S.UI.watchAll = true
	var sel = q.get("sel", "")
	if sel == "war":
		for W in S.G.wars.values():
			selectNation(W.a, true)
			break
	elif sel.is_valid_int(): selectNation(int(sel), true)
	refresh()
## 軍団が一手動いた時：上の帯・出来事・地図の動く層だけ描き直す（右の欄は作り直さない）
func _onBeat() -> void:
	if S.G == null: return
	_renderTop()
	_renderLog()
	map.beatRefresh()

# ============================================================
#   音（BGM・効果音）：すべて tools/gen_audio.gd で合成したもの
# ============================================================
var _bgm = {}
var _bgmPlayers = []
var _bgmCur = ""
var _sfxStreams = {}
var _sfxPlayers = []
var _sfxNext = 0
var _sfxLast = {}
func _setupAudio() -> void:
	for k in ["peace", "war"]:
		var st: AudioStreamWAV = load("res://audio/bgm_%s.wav" % k)
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = st.data.size() / 2 if st.format == AudioStreamWAV.FORMAT_16_BITS else int(st.get_length() * st.mix_rate)
		_bgm[k] = st
	for i in 2:
		var p = AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_bgmPlayers.append(p)
	for k in ["click", "turn", "notice", "war", "fall", "battle", "capture", "peace"]:
		_sfxStreams[k] = load("res://audio/sfx_%s.wav" % k)
	for i in 6:
		var p = AudioStreamPlayer.new()
		add_child(p)
		_sfxPlayers.append(p)
## 効果音（同じ音は短い間に重ねて鳴らさない）
func _sfx(name: String, db := 0.0) -> void:
	if not S.UI.get("sfx", true) or not _sfxStreams.has(name): return
	var now = Time.get_ticks_msec()
	var gap = 600 if name == "turn" else 150
	if now - int(_sfxLast.get(name, -10000)) < gap: return
	_sfxLast[name] = now
	var p: AudioStreamPlayer = _sfxPlayers[_sfxNext]
	_sfxNext = (_sfxNext + 1) % _sfxPlayers.size()
	p.stream = _sfxStreams[name]
	p.volume_db = db
	p.play()
## 選んだ国が戦争中（選んでいなければ世の中で戦が多い時）は戦の曲、それ以外は平時の曲。切り替えは重ねてゆっくり
func _updateBgm(force := false) -> void:
	if _bgmPlayers.is_empty(): return
	var want = ""
	if S.UI.get("bgm", true) and S.G != null and titleScr == null:
		var sel = S.UI.selNat
		var war: bool = S.inWar(sel) if sel != null and sel >= 0 else S.G.wars.size() >= max(3, S.G.nations.size() / 8)
		want = "war" if war else "peace"
	if want == _bgmCur and not force: return
	if want == _bgmCur and force and want != "": return
	_bgmCur = want
	var cur: AudioStreamPlayer = _bgmPlayers[0]
	var nxt: AudioStreamPlayer = _bgmPlayers[1]
	_bgmPlayers.reverse()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(cur, "volume_db", -80.0, 1.5)
	if want != "":
		nxt.stream = _bgm[want]
		nxt.volume_db = -40.0
		nxt.play()
		tw.tween_property(nxt, "volume_db", -9.0 if want == "peace" else -10.0, 1.5)
	tw.chain().tween_callback(func(): if cur.volume_db <= -79.0: cur.stop())
