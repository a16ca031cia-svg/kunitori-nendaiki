extends Control
## 国家方針ツリーの絵（HOI4風：箱と線。達成＝緑、取り組み中＝金と進み具合、取れない＝暗い）

signal picked(id: String)

const BW := 92.0     # 箱の幅
const BH := 46.0     # 箱の高さ
const GX := 102.0    # 列の間隔
const GY := 84.0     # 段の間隔
const PAD := 16.0
const HEAD := 26.0   # 枝の名前を書く帯

var nid := -1
var font: Font
var fontB: Font
var tree := []
var pos := {}        # id → 箱の左上
var sel := ""
var _cols := {}

const BR_NAME := {"ind": "産業", "mil": "軍事", "pol": "政治", "dip": "外交", "uniq": "固有"}
const BR_COL := {"ind": Color("#c9a227"), "mil": Color("#c0504a"), "pol": Color("#6f9fd0"), "dip": Color("#7fae6a"), "uniq": Color("#b9a2e6")}

func setup(n: int, f: Font, fb: Font) -> void:
	nid = n
	font = f
	fontB = fb
	var na = S.NAT(nid)
	tree = S.focusTree(na)
	# 空いた列を詰める（枝と枝の間は少しだけ空ける）
	var xs := []
	for fc in tree:
		if not xs.has(float(fc.x)): xs.append(float(fc.x))
	xs.sort()
	var cx := 0.0
	var prev := -99.0
	for x in xs:
		if prev > -99.0: cx += 0.5 if x - prev == 0.5 else (1.0 if x - prev <= 1.0 else 1.35)
		_cols[x] = cx
		prev = x
	var maxY := 0
	for fc in tree:
		pos[fc.id] = Vector2(PAD + _cols[float(fc.x)] * GX, PAD + HEAD + fc.y * GY)
		maxY = max(maxY, int(fc.y))
	custom_minimum_size = Vector2(PAD * 2 + (cx + 1) * GX - (GX - BW), PAD * 2 + HEAD + maxY * GY + BH)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _state(fc: Dictionary) -> String:
	var na = S.NAT(nid)
	if na.focus.done.has(fc.id): return "done"
	if na.focus.cur == fc.id: return "cur"
	for x in fc.get("ex", []):
		if na.focus.done.has(x) or na.focus.cur == x: return "ex"
	return "open" if S.focusAvailable(na, fc) else "lock"

func _draw() -> void:
	if nid < 0: return
	var na = S.NAT(nid)
	# 枝の名前
	var seen := {}
	for fc in tree:
		if seen.has(fc.br): continue
		var minx := 1e9
		var maxx := -1e9
		for f2 in tree:
			if f2.br == fc.br:
				minx = min(minx, pos[f2.id].x)
				maxx = max(maxx, pos[f2.id].x + BW)
		seen[fc.br] = true
		var c: Color = BR_COL.get(fc.br, Color.WHITE)
		draw_rect(Rect2(minx, PAD, maxx - minx, 2), c)
		draw_string(fontB, Vector2(minx, PAD + 18), BR_NAME.get(fc.br, ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
	# 線
	for fc in tree:
		var st := _state(fc)
		for r in fc.req:
			if not pos.has(r): continue
			var a: Vector2 = pos[r] + Vector2(BW / 2, BH)
			var b: Vector2 = pos[fc.id] + Vector2(BW / 2, 0)
			var lc := Color("#6d9c63") if na.focus.done.has(r) and (st == "done" or st == "cur") else Color("#4a4f5c")
			var my := (a.y + b.y) / 2
			draw_polyline(PackedVector2Array([a, Vector2(a.x, my), Vector2(b.x, my), b]), lc, 2.0)
		# 同時に取れない方針どうしは赤い点線
		for x in fc.get("ex", []):
			if pos.has(x) and pos[x].x > pos[fc.id].x and abs(pos[x].x - pos[fc.id].x) < GX * 1.1:
				draw_dashed_line(pos[fc.id] + Vector2(BW, BH / 2), pos[x] + Vector2(0, BH / 2), Color("#c0504a"), 1.5, 4.0)
	# 箱
	for fc in tree:
		var p: Vector2 = pos[fc.id]
		var st := _state(fc)
		var bg := Color("#252b38")
		var bd := Color("#3d4352")
		var tc := Color("#eae4d6")
		match st:
			"done":
				bg = Color("#2c4a2e"); bd = Color("#6d9c63")
			"cur":
				bg = Color("#4a4020"); bd = Color("#e6c95a")
			"ex":
				bg = Color("#2a1f22"); bd = Color("#5c3436"); tc = Color("#7a6a66")
			"lock":
				bg = Color("#1d212a"); bd = Color("#333846"); tc = Color("#8a8478")
		if fc.id == sel: bd = Color("#ffffff")
		var r := Rect2(p, Vector2(BW, BH))
		draw_rect(r, bg)
		draw_rect(r, bd, false, 2.0 if st == "cur" or fc.id == sel else 1.0)
		draw_rect(Rect2(p, Vector2(4, BH)), BR_COL.get(fc.br, Color.WHITE) * Color(1, 1, 1, 0.8 if st != "lock" and st != "ex" else 0.35))
		_text(fc.n, Rect2(p + Vector2(7, 3), Vector2(BW - 10, BH - 14)), tc)
		var sub := "%dターン" % fc.t
		if st == "done": sub = "達成"
		elif st == "ex": sub = "取れない"
		draw_string(font, p + Vector2(7, BH - 5), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tc * Color(1, 1, 1, 0.7))
		if st == "cur":
			var pr: float = clamp(float(na.focus.prog) / max(1, fc.t), 0.0, 1.0)
			draw_rect(Rect2(p + Vector2(0, BH - 3), Vector2(BW * pr, 3)), Color("#e6c95a"))

## 箱の中に名前を2行まで折り返して書く
func _text(s: String, r: Rect2, c: Color) -> void:
	var fs := 12
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w <= r.size.x:
		draw_string(font, r.position + Vector2(0, 14), s, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, fs, c)
		return
	var cut := s.length()
	while cut > 1 and font.get_string_size(s.substr(0, cut), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x: cut -= 1
	draw_string(font, r.position + Vector2(0, 13), s.substr(0, cut), HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 11, c)
	draw_string(font, r.position + Vector2(0, 26), s.substr(cut), HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 11, c)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for fc in tree:
			if Rect2(pos[fc.id], Vector2(BW, BH)).has_point(ev.position):
				sel = fc.id
				picked.emit(fc.id)
				queue_redraw()
				accept_event()
				return
