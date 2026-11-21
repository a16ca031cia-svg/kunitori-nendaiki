# 地図の表示と操作（元 1602〜2910 の描画・入力）
# 世界座標の絵は root(Node2D) の下に置き、拡大・移動は root の変形だけで行う（描き直さない）
extends Control

signal clicked(wx: float, wy: float)
signal hovered(tid: int, screen_pos: Vector2)
signal view_changed

var vx = 0.0
var vy = 0.0
var vs = 1.0

var root: Node2D
var svc: SubViewportContainer
var sv: SubViewport
var svcD: SubViewportContainer
var svD: SubViewport
var droot: Node2D
var _kickReq = true
var _kickD = true
var _fitPending = false
var _userMoved = false   # 自分で動かすまでは、大きさが変わったら全体に合わせ直す
## 次のフレームで地図（動かない層と動く層の両方）を描き直す
func kick() -> void:
	_kickReq = true
	_kickD = true
var seaL: Node2D       # 海・海岸の明るみ
var glowL: Node2D      # 海岸の明るみ（Line2D の丸い角で描く）
var landL: Node2D      # 陸の下地（日本地図）
var maskL: Node2D      # 陸の形（日本地図はこれで切り抜く）
var terrL: Node2D      # 領地の塗り（三角形の束）
var glyphL: Node2D     # 地形の記号
var riverL: Node2D     # 川
var borderL: Node2D    # 国境
var relL: Node2D       # 選んだ国との関係の縁取り
var selL: Node2D       # 選んだ領地の縁
var coastL: Node2D     # 海岸線・湖
var seaRouteL: Node2D  # 渡海路
var siteL: Node2D      # 拠点の印
var markL: Node2D      # 包囲・開拓・混乱・望みの印
var fxL: Node2D        # 軌跡・注目の輪
var armyL: Node2D      # 軍団
var labelL: Control    # 地名・国名（画面の座標で描く）

var font: Font
var fontB: Font
var fontD: Font        # 国名（明朝）

# 下ごしらえ
var G_ = null
var rings = []        # 領地ごとの輪（PackedVector2Array の配列）
var triPts = PackedVector2Array()
var triIdx = PackedInt32Array()
var triCol = PackedColorArray()
var triRange = []     # 領地ごとの [頂点の始まり, 数]
var landRings = []    # 日本：県の形（陸）
var lakeRings = []
var coastLines = []
var riverLines = []
var isJapan = false
var lblPos = {}
var lblHide = {}
var trails = []
var flashes = []
var drag = null

const SEA_COL := Color("#8fb0c1")
const LAND_COL := Color("#ddd0ac")
const INK := Color("#2a2318")
const RELC := {"self": "#f0cf55", "war": "#c94b44", "ally": "#5f9c57", "tense": "#d8a03c", "peace": "#8a8272", "vassal": "#c9a227", "lord": "#c9a227"}
const REL_JP := {"self": "選択中", "war": "戦争中", "ally": "同盟", "tense": "緊張", "peace": "平和", "vassal": "属国", "lord": "主君"}

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 地図は SubViewport に描き、変わった時だけ描き直す（毎フレーム数千の描画命令を出さない）
	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	sv = SubViewport.new()
	sv.disable_3d = true
	sv.handle_input_locally = false
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	svc.add_child(sv)
	root = Node2D.new()
	sv.add_child(root)
	seaL = _layer(root, _drawSea)
	glowL = Node2D.new()
	root.add_child(glowL)
	landL = _layer(root, _drawLand)
	maskL = _layer(root, _drawMask)
	terrL = _layer(maskL, _drawTerr)
	glyphL = _layer(maskL, _drawGlyphs)
	riverL = _layer(maskL, _drawRivers)
	borderL = _layer(maskL, _drawBorders)
	relL = _layer(maskL, _drawRel)
	selL = _layer(maskL, _drawSel)
	coastL = _layer(root, _drawCoast)
	seaRouteL = _layer(root, _drawSeaRoutes)
	siteL = _layer(root, _drawSites)
	markL = _layer(root, _drawMarks)
	# 動くもの（軍団・軌跡）は別の透明な SubViewport に描き、動いている間だけそちらを描き直す
	svcD = SubViewportContainer.new()
	svcD.stretch = true
	svcD.set_anchors_preset(Control.PRESET_FULL_RECT)
	svcD.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svcD)
	svD = SubViewport.new()
	svD.disable_3d = true
	svD.transparent_bg = true
	svD.handle_input_locally = false
	svD.render_target_update_mode = SubViewport.UPDATE_ONCE
	svcD.add_child(svD)
	droot = Node2D.new()
	svD.add_child(droot)
	fxL = _layer(droot, _drawFx)
	armyL = _layer(droot, _drawArmies)
	labelL = Control.new()
	labelL.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labelL.set_anchors_preset(Control.PRESET_FULL_RECT)
	labelL.draw.connect(_drawLabels)
	add_child(labelL)
	resized.connect(func():
		if (_fitPending or not _userMoved) and size.x >= 50 and size.y >= 50 and S.G != null: fitView()
		else: _applyView())
	S.map_changed.connect(_onMapChanged)
	S.fx.connect(_onFx)
func _layer(parent: Node, fn: Callable) -> Node2D:
	var n = Node2D.new()
	n.draw.connect(fn)
	parent.add_child(n)
	return n

# ============================================================
#   下ごしらえ
# ============================================================
func setup() -> void:
	G_ = S.G
	isJapan = S.G.has("geo")
	S.segNbrs()
	rings = []
	for t in S.G.terrs: rings.append(_ringsOf(t))
	_buildTris()
	landRings = []
	lakeRings = []
	coastLines = []
	riverLines = []
	if isJapan: _buildJapan()
	else:
		for t in S.G.terrs:
			for i in t.segs.size():
				if t.segN[i] < 0: coastLines.append(_smooth(t.segs[i]))
	maskL.clip_children = CanvasItem.CLIP_CHILDREN_ONLY if isJapan else CanvasItem.CLIP_CHILDREN_DISABLED
	_buildLabels()
	trails = []
	flashes = []
	_userMoved = false
	_buildGlow()
	kick()
	for n in [seaL, landL, maskL, glyphL, riverL, coastL, seaRouteL]: n.queue_redraw()
	refreshAll()
## 折れ線を Catmull-Rom でなめらかに（点が粗い架空の地図だけ）
func _smooth(sg: PackedVector2Array) -> PackedVector2Array:
	if isJapan or sg.size() < 3: return sg
	var out = PackedVector2Array()
	var n = sg.size()
	out.append(sg[0])
	for i in n - 1:
		var p0: Vector2 = sg[max(0, i - 1)]
		var p1: Vector2 = sg[i]
		var p2: Vector2 = sg[i + 1]
		var p3: Vector2 = sg[min(n - 1, i + 2)]
		for s in range(1, 5):
			var u = s / 4.0
			out.append(0.5 * (2 * p1 + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u))
	return out
func _ringsOf(t: Dictionary) -> Array:
	var out = []
	var cur = PackedVector2Array()
	var last = null
	for sg in t.segs:
		var pts = _smooth(sg)
		if last != null and pts[0].distance_to(last) > 1.0:
			if cur.size() >= 3: out.append(cur)
			cur = PackedVector2Array()
		for k in pts.size():
			if k == 0 and cur.size() and cur[-1].distance_to(pts[0]) < 0.01: continue
			cur.append(pts[k])
		last = pts[-1]
	if cur.size() >= 3:
		if cur[0].distance_to(cur[-1]) < 0.01: cur.remove_at(cur.size() - 1)
		out.append(cur)
	return out
func _buildTris() -> void:
	triPts = PackedVector2Array()
	triIdx = PackedInt32Array()
	triRange = []
	var fails = 0
	for i in rings.size():
		var start = triPts.size()
		for r in rings[i]:
			var idx = Geometry2D.triangulate_polygon(r)
			var parts = [[r, idx]]
			if idx.is_empty():
				fails += 1
				parts = []
				for p in Geometry2D.offset_polygon(r, 0.05):
					var ii = Geometry2D.triangulate_polygon(p)
					if ii.is_empty():
						p = Geometry2D.convex_hull(p)
						ii = Geometry2D.triangulate_polygon(p)
					parts.append([p, ii])
			for pr in parts:
				var base = triPts.size()
				triPts.append_array(pr[0])
				for k in pr[1]: triIdx.append(base + k)
		triRange.append([start, triPts.size() - start])
	triCol = PackedColorArray()
	triCol.resize(triPts.size())
	if fails: print("triangulate fallback: ", fails)

func _buildJapan() -> void:
	var geo = JSON.parse_string(FileAccess.get_file_as_string("res://data/jp_geo.json"))
	var ox: float = S.G.geo.ox
	var oy: float = S.G.geo.oy
	var k: float = S.JP.U / 10.0
	var arcs = []
	for f in geo.arcs:
		var pts = PackedVector2Array()
		var x: float = f[0]
		var y: float = f[1]
		pts.append(Vector2(x * k - ox, y * k - oy))
		var i = 2
		while i < f.size():
			x += f[i]; y += f[i + 1]
			pts.append(Vector2(x * k - ox, y * k - oy))
			i += 2
		arcs.append(pts)
	for nm in geo.prefs:
		for refs in geo.prefs[nm]:
			var ring = PackedVector2Array()
			for r in refs:
				var ri = int(r)
				var a: PackedVector2Array = arcs[ri] if ri >= 0 else _rev(arcs[~ri])
				for j in range(1 if ring.size() else 0, a.size()): ring.append(a[j])
			if ring.size() >= 3: landRings.append(ring)
	for a in geo.coast: coastLines.append(arcs[int(a)])
	_triLand()
	for lk in JpData.JP_LAKES:
		var m = PackedVector2Array()
		for p in lk:
			var q: Vector2 = S.jpProj(p[0], p[1])
			m.append(Vector2(q.x - ox, q.y - oy))
		m = _smoothRing(m, 5)
		lakeRings.append(m)
	for rv in JpData.JP_RIVERS:
		var m = PackedVector2Array()
		for p in rv[1]:
			var q: Vector2 = S.jpProj(p[0], p[1])
			m.append(Vector2(q.x - ox, q.y - oy))
		riverLines.append(_catmull(m))
func _rev(a: PackedVector2Array) -> PackedVector2Array:
	var b = a.duplicate()
	b.reverse()
	return b
func _smoothRing(r: PackedVector2Array, k: int) -> PackedVector2Array:
	var n = r.size()
	var out = PackedVector2Array()
	for i in n:
		var p0 = r[(i - 1 + n) % n]
		var p1 = r[i]
		var p2 = r[(i + 1) % n]
		var p3 = r[(i + 2) % n]
		for s in k:
			var u = float(s) / k
			out.append(0.5 * (2 * p1 + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u))
	return out
func _catmull(sg: PackedVector2Array) -> PackedVector2Array:
	var out = PackedVector2Array()
	var n = sg.size()
	if n < 3: return sg
	out.append(sg[0])
	for i in n - 1:
		var p0: Vector2 = sg[max(0, i - 1)]
		var p1: Vector2 = sg[i]
		var p2: Vector2 = sg[i + 1]
		var p3: Vector2 = sg[min(n - 1, i + 2)]
		for s in range(1, 7):
			var u = s / 6.0
			out.append(0.5 * (2 * p1 + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u))
	return out

## 地名の重なり：首都・大きな町・実在の町名を優先して置き、重なる名前は出さない（地図ごとに一度だけ決める）
const SYN_SUFFIX := ["東", "西", "南", "北", "東奥", "東外", "東新", "西奥", "西外", "西新", "南奥", "南外", "南新", "北奥", "北外", "北新"]
func _isSyn(nm: String) -> bool:
	for s in ["東", "西", "南", "北"]:
		if nm.ends_with(s): return true
	for s in ["奥", "外", "新", "二", "三"]:
		if nm.length() >= 2 and nm.ends_with(s) and "東西南北".contains(nm.substr(nm.length() - 2, 1)): return true
	return false
func rOf(t: Dictionary) -> float: return 7.0 + t.dev if t.type == "city" else 6.0 + t.dev * 0.6
func _buildLabels() -> void:
	lblPos = {}
	lblHide = {}
	var C = 48.0
	var grid = {}
	var put = func(b: Rect2, id: int):
		for gx in range(int(floor(b.position.x / C)), int(floor(b.end.x / C)) + 1):
			for gy in range(int(floor(b.position.y / C)), int(floor(b.end.y / C)) + 1):
				var key = Vector2i(gx, gy)
				if not grid.has(key): grid[key] = []
				grid[key].append([b, id])
	var hits = func(b: Rect2, self_id: int) -> bool:
		for gx in range(int(floor(b.position.x / C)), int(floor(b.end.x / C)) + 1):
			for gy in range(int(floor(b.position.y / C)), int(floor(b.end.y / C)) + 1):
				for q in grid.get(Vector2i(gx, gy), []):
					if q[1] != self_id and q[0].intersects(b): return true
		return false
	for t in S.G.terrs:
		var r = rOf(t) + 1
		put.call(Rect2(t.x - r, t.y - r, r * 2, r * 2), t.id)
	var order: Array = S.G.terrs.duplicate()
	var pri = func(t): return (1e6 if t.cap else 0.0) + (t.dev * 1e4 if t.type == "city" else 0.0) + (0.0 if _isSyn(t.name) else 5e3) + t.pop / 100.0
	order.sort_custom(func(a, b): return pri.call(a) > pri.call(b))
	for t in order:
		var w: float = font.get_string_size(t.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 4
		var r = rOf(t)
		var cand = [[0, Rect2(t.x - w / 2, t.y + r + 2, w, 15)], [1, Rect2(t.x - w / 2, t.y - r - 18, w, 15)],
			[2, Rect2(t.x + r + 12, t.y - 8, w, 15)], [3, Rect2(t.x - r - 4 - w, t.y - 8, w, 15)]]
		var got = null
		for c in cand:
			if not hits.call(c[1], t.id):
				got = c
				break
		if got == null:
			lblHide[t.id] = true
			continue
		if got[0]: lblPos[t.id] = got[0]
		put.call(got[1], t.id)

# ============================================================
#   表示の更新
# ============================================================
const Batch = preload("res://scripts/ui/batch.gd")
## 領地の持ち主が変わった：ターンの途中では描き直さず、次の refreshAll でまとめて
func _onMapChanged(kind: String, _arg) -> void:
	if S.G != G_: return
	_dirtyOwn = true
var _dirtyOwn = true
var _lastBorderScale = -1.0
func refreshAll() -> void:
	if S.G == null: return
	kick()
	if S.G != G_: setup()
	if _dirtyOwn:
		_dirtyOwn = false
		_updateColors()
		terrL.queue_redraw()
		borderL.queue_redraw()
	siteL.queue_redraw()
	markL.queue_redraw()
	relL.queue_redraw()
	selL.queue_redraw()
	armyL.queue_redraw()
	labelL.queue_redraw()
	fxL.queue_redraw()
## 軍団が一手動いた時の軽い描き直し（土地の持ち主が変わった時だけ地図の塗りと国境も）
func beatRefresh() -> void:
	if S.G == null or S.G != G_: return
	if _dirtyOwn:
		_dirtyOwn = false
		_updateColors()
		terrL.queue_redraw()
		borderL.queue_redraw()
		relL.queue_redraw()
		markL.queue_redraw()
		_kickReq = true
	armyL.queue_redraw()
	fxL.queue_redraw()
	labelL.queue_redraw()
	_kickD = true
func _mix(hex: String, base: Color, a: float) -> Color:
	var c = Color(hex)
	return Color(c.r * a + base.r * (1 - a), c.g * a + base.g * (1 - a), c.b * a + base.b * (1 - a))
func tileColor(t: Dictionary) -> Color:
	var base = Color(S.terrOf(t).c)
	if t.owner < 0: return base.lerp(Color(0.47, 0.42, 0.33), 0.22)
	return _mix(S.NAT(t.owner).color, base, 0.5 if S.G.nations.size() > 16 else 0.36)
func _updateColors() -> void:
	for t in S.G.terrs:
		var c = tileColor(t)
		var rg: Array = triRange[t.id]
		for k in range(rg[0], rg[0] + rg[1]): triCol[k] = c

# ---------- 静的な層 ----------
func _drawSea() -> void:
	if S.G == null: return
	seaL.draw_rect(Rect2(-4000, -4000, S.G.W + 8000, S.G.H + 8000), SEA_COL)
func _drawLand() -> void:
	if S.G != null and isJapan and landPts.size(): RenderingServer.canvas_item_add_triangle_array(landL.get_canvas_item(), landIdx, landPts, _fillCols(landPts.size(), LAND_COL))
## 海岸の明るみ：海岸線を丸く太らせた形を三角形にして2枚だけ描く
var glowB = Batch.new()
func _buildGlow() -> void:
	for c in glowL.get_children(): c.queue_free()
	glowB.clear()
	for w in [[19.0, 0.15], [8.5, 0.2]]:
		var col = Color(1, 1, 1, w[1])
		var parts = []
		for ln in coastLines:
			if ln.size() < 2: continue
			for p in Geometry2D.offset_polyline(ln, w[0], Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND): parts.append(p)
		# 重なりで濃くならないように、近い物どうしをまとめる
		var merged = _mergeAll(parts)
		for p in merged:
			if Geometry2D.is_polygon_clockwise(p): continue
			glowB.poly(p, col)
	var holder = Node2D.new()
	holder.draw.connect(func(): glowB.flush(holder.get_canvas_item()))
	glowL.add_child(holder)
## 多数の多角形を、格子で区切って区画ごとにまとめる（全部を一度にまとめると重いので）
func _mergeAll(parts: Array) -> Array:
	var cell = 1500.0
	var buckets = {}
	for p in parts:
		var bb = Rect2(p[0], Vector2.ZERO)
		for q in p: bb = bb.expand(q)
		var key = Vector2i(int(bb.get_center().x / cell), int(bb.get_center().y / cell))
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(p)
	var out = []
	for key in buckets:
		var acc = []
		for p in buckets[key]:
			if acc.is_empty():
				acc = [p]
				continue
			var next = []
			var cur = p
			for a in acc:
				var m = Geometry2D.merge_polygons(a, cur)
				var outer = []
				for x in m:
					if not Geometry2D.is_polygon_clockwise(x): outer.append(x)
				if outer.size() == 1:
					cur = outer[0]
				else:
					next.append(a)
			next.append(cur)
			acc = next
		out.append_array(acc)
	return out
func _drawMask() -> void:
	if S.G == null or not isJapan: return
	if landPts.size(): RenderingServer.canvas_item_add_triangle_array(maskL.get_canvas_item(), landIdx, landPts, _fillCols(landPts.size(), Color.WHITE))
func _drawTerr() -> void:
	if S.G == null or triPts.is_empty(): return
	RenderingServer.canvas_item_add_triangle_array(terrL.get_canvas_item(), triIdx, triPts, triCol)
	# 無主の地は斜線
	var b = Batch.new()
	for t in S.G.terrs:
		if t.owner >= 0: continue
		var bb: Rect2 = S.terrBounds(t)
		for r in rings[t.id]:
			var x = bb.position.x - bb.size.y
			while x < bb.end.x:
				var inside = Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x, bb.end.y), Vector2(x + bb.size.y, bb.position.y)]), r)
				for piece in inside: b.polyline(piece, 1.4, Color(0.43, 0.38, 0.29, 0.3))
				x += 26
	b.flush(terrL.get_canvas_item())
var glyphB = Batch.new()
func _drawGlyphs() -> void:
	if S.G == null: return
	glyphB.clear()
	var k = 0.72 if S.G.terrs.size() > 1500 else 1.0
	for t in S.G.terrs:
		if t.terrain == "plain": continue
		var h = func(n: int) -> float:
			var v = sin(t.id * 12.9898 + n * 78.233) * 43758.5453
			return v - floor(v)
		var spots = [Vector2(-40 + h.call(1) * 12, -34 + h.call(2) * 10), Vector2(36 + h.call(3) * 12, -30 + h.call(4) * 10), Vector2(-6 + h.call(5) * 14, -58 + h.call(6) * 8)]
		for sp in spots: _glyph(glyphB, t.terrain, Vector2(t.x, t.y) + sp * k, k)
	glyphB.flush(glyphL.get_canvas_item())
func _glyph(b, kind: String, p: Vector2, k: float) -> void:
	match kind:
		"mount":
			var A = p + Vector2(-13, 8) * k
			var B = p + Vector2(0, -11) * k
			var C = p + Vector2(13, 8) * k
			b.tri(A, B, C, Color8(120, 104, 82, 217))
			b.tri(p + Vector2(-4.5, -4) * k, B, p + Vector2(4.5, -4) * k, Color8(244, 238, 224, 242))
			b.line(A, B, 1.4 * k, Color8(62, 50, 34, 190))
			b.line(B, C, 1.4 * k, Color8(62, 50, 34, 190))
		"hill":
			b.polyline(_quad(p + Vector2(-15, 5) * k, p + Vector2(-7, -8) * k, p + Vector2(1, 5) * k), 2.4 * k, Color8(132, 100, 56, 204))
			b.polyline(_quad(p + Vector2(-3, 5) * k, p + Vector2(6, -5) * k, p + Vector2(15, 5) * k), 2.4 * k, Color8(132, 100, 56, 204))
		"forest":
			for o in [Vector2(-8, 2), Vector2(0, -4), Vector2(8, 2)]:
				b.line(p + (o + Vector2(0, 6)) * k, p + (o + Vector2(0, 11)) * k, 1.8 * k, Color8(86, 62, 36, 204))
				b.circle(p + o * k, 6 * k, Color8(76, 112, 62, 217), 10)
		"marsh":
			for i in 3:
				var yy = -4.0 + i * 5
				b.polyline(_quad(p + Vector2(-12, yy) * k, p + Vector2(-6, yy - 3) * k, p + Vector2(0, yy) * k), 1.8 * k, Color8(70, 112, 104, 204))
				b.polyline(_quad(p + Vector2(0, yy) * k, p + Vector2(6, yy + 3) * k, p + Vector2(12, yy) * k), 1.8 * k, Color8(70, 112, 104, 204))
			b.line(p + Vector2(6, -6) * k, p + Vector2(7, -15) * k, 1.8 * k, Color8(92, 110, 62, 217))
			b.line(p + Vector2(9, -6) * k, p + Vector2(12, -13) * k, 1.8 * k, Color8(92, 110, 62, 217))
		"grass":
			for ox in [-8, 0, 8]:
				b.polyline(PackedVector2Array([p + Vector2(ox - 3, -4) * k, p + Vector2(ox, 4) * k, p + Vector2(ox + 3, -5) * k]), 1.7 * k, Color8(112, 128, 60, 204))
func _quad(a: Vector2, q: Vector2, b: Vector2) -> PackedVector2Array:
	var out = PackedVector2Array()
	for i in 9:
		var t = i / 8.0
		var u = 1 - t
		out.append(u * u * a + 2 * u * t * q + t * t * b)
	return out
func _drawRivers() -> void:
	if S.G == null: return
	var b = Batch.new()
	for br in S.G.bars:
		if br.kind != "river" or br.pts.size() < 2: continue
		b.polyline(_smooth(br.pts), 5, Color8(74, 116, 148, 140), true)
	for ln in riverLines: b.polyline(ln, 6.5, Color8(78, 124, 160, 191), true)
	b.flush(riverL.get_canvas_item())
func _drawCoast() -> void:
	if S.G == null: return
	var b = Batch.new()
	var col = Color8(48, 40, 26, 166)
	if isJapan:
		for r in lakeRings:
			var li = Geometry2D.triangulate_polygon(r)
			if li.size(): b.mesh(r, li, SEA_COL)
			var c = r.duplicate()
			c.append(r[0])
			b.polyline(c, 2.4, col)
		for ln in coastLines: b.polyline(ln, 2.4, col)
	else:
		for ln in coastLines: b.polyline(ln, 3.2, col)
	var R = Rect2(-2.5, -2.5, S.G.W + 5, S.G.H + 5)
	var frame = PackedVector2Array([R.position, Vector2(R.end.x, R.position.y), R.end, Vector2(R.position.x, R.end.y), R.position])
	b.polyline(frame, 5, Color8(10, 13, 18, 217))
	b.flush(coastL.get_canvas_item())
func _roadPts(e: Dictionary, fromId: int) -> PackedVector2Array:
	var f = S.T(fromId)
	var to = S.T(e.b if fromId == e.a else e.a)
	var a = S.T(e.a)
	var b = S.T(e.b)
	var q = Vector2((a.x + b.x) / 2 + e.get("cx", 0.0), (a.y + b.y) / 2 + e.get("cy", 0.0))
	return _quad(Vector2(f.x, f.y), q, Vector2(to.x, to.y))
func _drawSeaRoutes() -> void:
	if S.G == null: return
	var b = Batch.new()
	for e in S.G.edges:
		if not e.get("sea", false): continue
		var pts = _roadPts(e, e.a)
		for i in range(0, pts.size() - 1):
			if i % 2 == 0: b.line(pts[i], pts[i + 1], 3.4, Color8(40, 86, 128, 153))
	b.flush(seaRouteL.get_canvas_item())

# ---------- 状態で変わる層 ----------
func _drawBorders() -> void:
	if S.G == null: return
	var w: float = max(3.4, 1.3 / vs)
	var under = Batch.new()
	var over = Batch.new()
	for t in S.G.terrs:
		if t.owner < 0: continue
		var c = Color(S.NAT(t.owner).color)
		for i in t.segs.size():
			var j: int = t.segN[i]
			if j >= 0 and S.T(j).owner == t.owner: continue
			if j < 0 and isJapan: continue
			var ln = _smooth(t.segs[i])
			under.polyline(ln, w * 2.05, Color(0.14, 0.11, 0.06, 0.42))
			over.polyline(ln, w, c)
	under.flush(borderL.get_canvas_item())
	over.flush(borderL.get_canvas_item())
	_lastBorderScale = vs
## 国ごとの国境の線（持ち主が変わるまで使い回す。全領地を1回だけ見る）
var _nbKey = ""
var _nbCache = {}
func natBorder(nid: int) -> Array:
	var k = str(S.G.get("ownRev", 0)) + "_" + str(S.G.terrs.size()) + "_" + str(S.G.turn)
	if k != _nbKey or G_ != S.G:
		_nbKey = k
		_nbCache = {}
		for t in S.G.terrs:
			if t.owner < 0: continue
			for i in t.segs.size():
				var j: int = t.segN[i]
				if j >= 0 and S.T(j).owner == t.owner: continue
				if not _nbCache.has(t.owner): _nbCache[t.owner] = []
				_nbCache[t.owner].append(_smooth(t.segs[i]))
	return _nbCache.get(nid, [])
func natRel(from: int, nid: int) -> String:
	if from == nid: return "self"
	if S.isVassal(nid, from): return "vassal"
	if S.isVassal(from, nid): return "lord"
	if S.sameFaction(from, nid) and S.relState(from, nid) == "peace": return "ally"
	return S.relState(from, nid)
func _drawRel() -> void:
	if S.G == null: return
	var sel = S.UI.selNat
	if sel == null or sel < 0: return
	var under = Batch.new()
	var over = Batch.new()
	for na in S.G.nations:
		if not na.alive: continue
		var rel = natRel(sel, na.id)
		if rel == "peace" and not S.canPass(sel, na.id) and not S.canPass(na.id, sel): continue
		var lines = natBorder(na.id)
		if rel != "peace":
			var c = Color(RELC[rel])
			for ln in lines:
				under.polyline(ln, (8.0 if rel == "self" else 6.0) / vs, Color(0.08, 0.06, 0.04, 0.55))
				over.polyline(ln, (4.5 if rel == "self" else 3.2) / vs, c)
		else:
			for ln in lines: _dashed(over, ln, Color("#4f7fa8"), 3.0 / vs, 10.0 / vs, 8.0 / vs)
	under.flush(relL.get_canvas_item())
	over.flush(relL.get_canvas_item())
func _dashed(b, ln: PackedVector2Array, col: Color, w: float, on: float, off: float) -> void:
	var acc = 0.0
	var drawing = true
	for i in ln.size() - 1:
		var p0 = ln[i]
		var p1 = ln[i + 1]
		var L = p0.distance_to(p1)
		var pos = 0.0
		while pos < L:
			var lim = (on if drawing else off) - acc
			var step: float = min(lim, L - pos)
			if drawing: b.line(p0.lerp(p1, pos / L), p0.lerp(p1, (pos + step) / L), w, col)
			pos += step
			acc += step
			if acc >= (on if drawing else off) - 0.001:
				acc = 0
				drawing = not drawing
func _drawSel() -> void:
	if S.G == null or S.UI.sel == null: return
	var b = Batch.new()
	for r in rings[S.UI.sel]:
		var c = r.duplicate()
		c.append(r[0])
		b.polyline(c, 4.5 / vs, Color("#3a2f14"))
		b.polyline(c, 2.4 / vs, Color("#f0cf55"))
	b.flush(selL.get_canvas_item())
func _drawSites() -> void:
	if S.G == null: return
	var lod: bool = vs < 0.25 and S.G.terrs.size() > 800
	glyphL.visible = not lod
	if lod: return
	var b = Batch.new()
	for t in S.G.terrs:
		var p = Vector2(t.x, t.y)
		var city: bool = t.type == "city"
		var r = rOf(t)
		var fill = Color("#d69e3c") if t.chaos > 0 else Color("#f2ead5")
		var edge = Color("#3a3020") if t.cap else Color8(58, 48, 32, 204)
		var ew = 3.4 if t.cap else 2.0
		if city:
			b.circle(p, r, fill, 14)
			b.ring(p, r, ew, edge, 16)
		else:
			var d = PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
			b.tri(d[0], d[1], d[2], fill)
			b.tri(d[0], d[2], d[3], fill)
			d.append(d[0])
			b.polyline(d, ew, edge)
		var inf: int = int(t.get("infra", 1))
		for k in inf - 1:
			b.rect(Rect2(t.x + r + 2.5, t.y - 4 + k * 5, 6, 3), Color8(92, 64, 30, 217))
		if t.cap:
			b.ring(p, r + 5, 1.6, Color("#3a3020"), 24)
	b.flush(siteL.get_canvas_item())
func _ring(c: CanvasItem, p: Vector2, r: float, col: Color, w: float, dash := 0.0) -> void:
	if dash <= 0:
		c.draw_arc(p, r, 0, TAU, 40, col, w)
		return
	var n = int(TAU * r / (dash * 2))
	for i in n:
		var a0 = TAU * i / n
		c.draw_arc(p, r, a0, a0 + TAU / n * 0.55, 6, col, w)
func _drawMarks() -> void:
	if S.G == null: return
	var sel = S.UI.selNat
	if sel != null and sel >= 0:
		var mk = func(tid, col: Color, txt: String):
			var t = S.T(tid)
			var r = 22.0 / min(1.0, max(0.35, vs))
			_ring(markL, Vector2(t.x, t.y), r, col, 3.0 / vs, 6.0 / vs)
			var c = Vector2(t.x + r * 0.75, t.y - r * 0.75)
			markL.draw_circle(c, 10 / vs, col)
			markL.draw_string(fontB, c + Vector2(-6, 5) / vs, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(max(1, 12 / vs)), Color("#1b1710"))
		for d in S.desiresOf(sel):
			if d.get("t") != null: mk.call(d.t, Color("#f0cf55"), "望")
		for o in S.G.nations:
			if not o.alive or o.id == sel: continue
			for d in S.desiresOf(o.id):
				if d.get("t") != null and S.T(d.t).owner == sel: mk.call(d.t, Color("#e0574e"), "狙")
	for t in S.G.terrs:
		var p = Vector2(t.x, t.y)
		if t.get("siege") != null:
			_ring(markL, p, 30, Color8(201, 75, 68, 217), 3.4, 8)
			_txt(markL, p + Vector2(0, -40), "包囲", Color("#c94b44"), 12)
		if t.get("settle") != null:
			var col = Color(S.ncol(t.settle.by))
			_ring(markL, p, 30, col, 3.2, 5)
			_txt(markL, p + Vector2(0, -40), "開拓 あと%d" % max(1, t.settle.done - S.G.turn), col, 12)
		if t.chaos:
			var c = p + Vector2(-34, -26)
			markL.draw_circle(c, 12, Color8(214, 158, 60, 235))
			markL.draw_arc(c, 12, 0, TAU, 20, Color("#2a2318"), 2)
			markL.draw_string(fontB, c + Vector2(-3, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#2a2318"))
func _txt(c: CanvasItem, p: Vector2, s: String, col: Color, size: int) -> void:
	var w = fontB.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string_outline(fontB, p + Vector2(-w / 2, size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color8(240, 232, 208, 230))
	c.draw_string(fontB, p + Vector2(-w / 2, size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# ---------- 軍団 ----------
func slotOff(i: int) -> Vector2: return Vector2(26 + (i % 3) * 30, -12 + (i / 3) * 30)
func armyPos(a: Dictionary, i: int) -> Vector2:
	var t = S.T(a.at)
	var p = Vector2(t.x, t.y) + slotOff(i)
	var an = a.get("anim")
	if an != null:
		var k: float = clamp((Time.get_ticks_msec() - an.t0) / float(an.dur), 0, 1)
		if k < 1:
			var ease = 1 - pow(1 - k, 3)
			var f = S.T(an.from)
			var fp = Vector2(f.x, f.y) + slotOff(i)
			p = fp.lerp(p, ease)
	return p
func _armySlots() -> Dictionary:
	var by = {}
	for na in S.G.nations:
		for a in na.armies:
			if a == null: continue
			if not by.has(a.at): by[a.at] = []
			by[a.at].append(a)
	return by
func mainKind(a: Dictionary) -> String:
	var best = "inf"
	var bv = -1
	for k in S.TK:
		if a.t[k] > bv:
			bv = a.t[k]
			best = k
	return best if bv > 0 else "inf"
func fmtK(tot: int) -> String:
	if tot >= 10000: return str(int(round(tot / 1000.0))) + "k"
	if tot >= 1000: return "%.1fk" % (tot / 1000.0)
	return str(tot)
## 盾の形（原点まわり・三角形に分け済み）を一度だけ作る
var _shieldPts = PackedVector2Array()
var _shieldIdx = PackedInt32Array()
var _shieldLine = PackedVector2Array()
func _shieldShape() -> void:
	if _shieldPts.size(): return
	var hw = 13.5
	var ht = 13.0
	var s = PackedVector2Array([Vector2(-hw, -ht), Vector2(hw, -ht), Vector2(hw, ht - 8)])
	s.append_array(_quad(Vector2(hw, ht - 8), Vector2(hw, ht - 1), Vector2(0, ht + 3.5)).slice(1))
	s.append_array(_quad(Vector2(0, ht + 3.5), Vector2(-hw, ht - 1), Vector2(-hw, ht - 8)).slice(1, 8))
	_shieldPts = s
	_shieldIdx = Geometry2D.triangulate_polygon(s)
	_shieldLine = s.duplicate()
	_shieldLine.append(s[0])
func _drawArmies() -> void:
	if S.G == null: return
	_shieldShape()
	var by = _armySlots()
	var vr = visRect().grow(130)
	var b = Batch.new()
	if vs < 0.18:
		var r = 2.6 / vs
		var shows = {}
		for o in S.G.nations: shows[o.id] = o.id == S.UI.selNat or S.inWar(o.id)
		for tid in by:
			var tt = S.T(tid)
			if not vr.has_point(Vector2(tt.x, tt.y)): continue
			var o: int = by[tid][0].owner
			if not shows.get(o, false): continue
			var rc = Rect2(tt.x + 26 - r, tt.y - 12 - r, r * 2, r * 2)
			b.rect(rc.grow(0.9 / vs), Color8(20, 16, 10, 217))
			b.rect(rc, Color(S.ncol(o)))
		b.flush(armyL.get_canvas_item())
		return
	var small = vs < 0.35
	var texts = []
	var edge = Color("#241d12")
	var white = Color8(255, 248, 228, 242)
	for tid in by:
		var tt = S.T(tid)
		if not vr.has_point(Vector2(tt.x, tt.y)): continue
		var all: Array = by[tid]
		if all.size() > 6:
			var rest = all.slice(6)
			var sum = 0
			for x in rest: sum += S.total(x.t)
			var txt = "+%d／%s" % [rest.size(), fmtK(sum)]
			var c = Vector2(tt.x, tt.y) + slotOff(6)
			var w = fontB.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14
			b.rect(Rect2(c.x - w / 2 - 1.6, c.y - 11.6, w + 3.2, 23.2), Color(S.ncol(rest[0].owner)))
			b.rect(Rect2(c.x - w / 2, c.y - 10, w, 20), Color8(20, 24, 32, 240))
			if not small: texts.append([c + Vector2(-w / 2 + 7, 5), txt, 12, false])
		for i in min(6, all.size()):
			var a: Dictionary = all[i]
			var p = armyPos(a, i)
			if S.UI.actArmy == a: b.ring(p, 22 + sin(Time.get_ticks_msec() / 180.0) * 3, 3, Color(1, 1, 1, 0.65), 24)
			var pts = PackedVector2Array()
			for q in _shieldPts: pts.append(q + p)
			b.mesh(pts, _shieldIdx, Color(S.ncol(a.owner)))
			var ln = PackedVector2Array()
			for q in _shieldLine: ln.append(q + p)
			b.polyline(ln, 1.8, edge)
			if small: continue
			_troopGlyph(b, mainKind(a), p + Vector2(0, -1.5), white)
			if a.path.size(): b.tri(p + Vector2(15.5, -6), p + Vector2(23, -1), p + Vector2(15.5, 4), Color("#efe7d2"))
			texts.append([p, fmtK(S.total(a.t)), 11, true])
	b.flush(armyL.get_canvas_item())
	for tx in texts:
		if tx[3]:
			var w2 = fontB.get_string_size(tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var pos = tx[0] + Vector2(-w2 / 2, 28)
			armyL.draw_string_outline(fontB, pos, tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color8(232, 222, 196, 242))
			armyL.draw_string(fontB, pos, tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
		else:
			armyL.draw_string(fontB, tx[0], tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, tx[2], Color("#efe7d2"))
func _troopGlyph(b, k: String, p: Vector2, col: Color) -> void:
	match k:
		"inf":
			b.poly(PackedVector2Array([p + Vector2(0, -8.5), p + Vector2(1.5, -5.5), p + Vector2(1.5, 1.4), p + Vector2(-1.5, 1.4), p + Vector2(-1.5, -5.5)]), col)
			b.rect(Rect2(p + Vector2(-5, 1.4), Vector2(10, 2.1)), col)
			b.rect(Rect2(p + Vector2(-1.1, 3.5), Vector2(2.2, 3.6)), col)
			b.rect(Rect2(p + Vector2(-2.6, 7.1), Vector2(5.2, 1.8)), col)
		"spe":
			b.line(p + Vector2(-5.5, 8), p + Vector2(4.4, -5), 2, col)
			b.line(p + Vector2(5.5, 8), p + Vector2(-4.4, -5), 2, col)
			b.tri(p + Vector2(5.6, -8.6), p + Vector2(6.2, -3.4), p + Vector2(2.6, -5.2), col)
			b.tri(p + Vector2(-5.6, -8.6), p + Vector2(-2.6, -5.2), p + Vector2(-6.2, -3.4), col)
		"arc":
			b.ring(p + Vector2(-3.6, 0), 7.4, 2, col, 10, -1.15, 1.15)
			b.line(p + Vector2(-0.6, -6.7), p + Vector2(-0.6, 6.7), 1.1, col)
			b.line(p + Vector2(-6.5, 0), p + Vector2(5.2, 0), 1.7, col)
			b.tri(p + Vector2(8.4, 0), p + Vector2(4, -2.4), p + Vector2(4, 2.4), col)
		_:
			b.ring(p + Vector2(0, -0.5), 6.4, 3, col, 12, PI * 0.12, PI * 0.88)
			b.circle(p + Vector2(-6.3, 1.2), 1.5, col, 6)
			b.circle(p + Vector2(6.3, 1.2), 1.5, col, 6)

# ---------- 演出 ----------
func _onFx(kind: String, arg) -> void:
	var now = Time.get_ticks_msec()
	if kind == "move":
		var a: Dictionary = arg[0]
		trails.append({"a": arg[1], "b": a.at, "col": Color(S.ncol(a.owner)), "t0": now, "dur": 1100})
		if trails.size() > 32: trails.pop_front()
	elif kind == "flash":
		flashes.append({"tid": arg, "t0": now, "dur": 950})
		if flashes.size() > 32: flashes.pop_front()
	_animLive = true
var _animLive = false
func _process(_d: float) -> void:
	if S.G != null and _animLive: _animStep()
	if _kickReq:
		_kickReq = false
		sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _kickD:
		_kickD = false
		svD.render_target_update_mode = SubViewport.UPDATE_ONCE
func _animStep() -> void:
	var now = Time.get_ticks_msec()
	var live = false
	for na in S.G.nations:
		for a in na.armies:
			if a != null and a.get("anim") != null:
				if now - a.anim.t0 > a.anim.dur: a.anim = null
				else: live = true
	trails = trails.filter(func(x): return now - x.t0 < x.dur)
	flashes = flashes.filter(func(x): return now - x.t0 < x.dur)
	if trails.size() or flashes.size() or S.UI.actArmy != null: live = true
	fxL.queue_redraw()
	armyL.queue_redraw()
	_kickD = true
	if not live: _animLive = false
func _drawFx() -> void:
	if S.G == null: return
	var now = Time.get_ticks_msec()
	for tr in trails:
		var k: float = 1 - (now - tr.t0) / float(tr.dur)
		if k <= 0: continue
		var A = S.T(tr.a)
		var B = S.T(tr.b)
		var c: Color = tr.col
		c.a = k * 0.85
		fxL.draw_line(Vector2(A.x, A.y), Vector2(B.x, B.y), c, 9)
	for fl in flashes:
		var k: float = 1 - (now - fl.t0) / float(fl.dur)
		if k <= 0: continue
		var t = S.T(fl.tid)
		fxL.draw_arc(Vector2(t.x, t.y), 20 + (1 - k) * 34, 0, TAU, 32, Color(0.94, 0.81, 0.33, k), 4)

# ---------- 地名・国名（画面の座標） ----------
func w2s(p: Vector2) -> Vector2: return (p - Vector2(vx, vy)) * vs
func s2w(p: Vector2) -> Vector2: return p / vs + Vector2(vx, vy)
func visRect() -> Rect2: return Rect2(vx, vy, size.x / vs, size.y / vs)
func _drawLabels() -> void:
	if S.G == null: return
	var vr = visRect()
	# 地名
	if vs > 0.5 and not (vs < 0.25 and S.G.terrs.size() > 800):
		var fs = int(clamp(12 * vs, 8, 30))
		for t in S.G.terrs:
			if not vr.grow(60).has_point(Vector2(t.x, t.y)): continue
			if lblHide.has(t.id): continue
			if not (vs >= 1 or t.cap or (t.type == "city" and t.dev >= 3) or not _isSyn(t.name)): continue
			var r = rOf(t)
			var pos: int = lblPos.get(t.id, 0)
			var w = font.get_string_size(t.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var lp: Vector2
			match pos:
				0: lp = Vector2(t.x - w / 2, t.y + r + 3)
				1: lp = Vector2(t.x - w / 2, t.y - r - 17)
				2: lp = Vector2(t.x + r + 14, t.y - 7)
				_: lp = Vector2(t.x - r - 6 - w, t.y - 7)
			var sp = w2s(lp) + Vector2(0, fs * 0.95)
			labelL.draw_string_outline(fontB, sp, t.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, max(2, int(3.5 * vs)), Color8(240, 234, 214, 230))
			labelL.draw_string(fontB, sp, t.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#3a3020"))
	# 国名
	var sel = S.UI.selNat
	var cnt = {}
	var sx = {}
	var sy = {}
	for t in S.G.terrs:
		if t.owner < 0: continue
		cnt[t.owner] = cnt.get(t.owner, 0) + 1
	var at = _natLabelAt()
	var boxes = []
	var many: bool = S.G.nations.size() > 16
	for na in S.G.nations:
		if not at.has(na.id): continue
		var t = S.T(at[na.id])
		var p = w2s(Vector2(t.x, t.y))
		if p.x < -120 or p.y < -60 or p.x > size.x + 120 or p.y > size.y + 60: continue
		var n: int = cnt.get(na.id, 0)
		var rel = natRel(sel, na.id) if sel != null and sel >= 0 else null
		var fsz = int(round((clamp(10 + sqrt(n) * 1.6, 11, 19) if many else clamp(12 + n * 0.5, 13, 25)) * (0.78 if size.x < 640 else 1.0)))
		var lbl: String = na.get("role", na.name)
		var w = fontD.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var badge: String = REL_JP[rel] if rel != null and rel != "peace" else ""
		boxes.append({"na": na, "lbl": lbl, "x": p.x, "y": p.y, "w": w, "bw": w + 20 + (46 if badge != "" else 0), "h": fsz * 1.56, "size": fsz, "rel": rel, "badge": badge, "n": n})
	boxes.sort_custom(func(a, b):
		var sa: bool = a.rel == "self"
		var sb: bool = b.rel == "self"
		if sa != sb: return sa
		if (a.badge != "") != (b.badge != ""): return a.badge != ""
		return a.n > b.n)
	var placed = []
	for b in boxes:
		var ok = false
		for dy in [0.0, -b.h * 0.9, b.h * 0.9]:
			var hit = false
			for B in placed:
				if abs(b.x - B.x) < (b.bw + B.bw) / 2 + 2 and abs(b.y + dy - B.y) < (b.h + B.h) / 2 + 1:
					hit = true
					break
			if not hit:
				b.y += dy
				ok = true
				break
		if ok or b.rel == "self": placed.append(b)
	for b in placed:
		var left: float = b.x - b.w / 2 - 10 - (23 if b.badge != "" else 0)
		var rc = Rect2(left, b.y - b.size * 0.78, b.bw, b.h)
		labelL.draw_rect(rc, Color8(20, 24, 32, 214))
		labelL.draw_rect(rc, Color(RELC[b.rel]) if b.badge != "" else Color(1, 1, 1, 0.18), false, 1.4)
		var nx: float = (b.x - 23 if b.badge != "" else b.x) - b.w / 2
		labelL.draw_string(fontD, Vector2(nx, b.y + b.size * 0.36), b.lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, b.size, readable(b.na.color))
		if b.badge != "":
			var bs = int(max(11, b.size * 0.62))
			labelL.draw_string(fontB, Vector2(b.x - 23 + b.w / 2 + 22 - fontB.get_string_size(b.badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x / 2, b.y + bs * 0.36), b.badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color(RELC[b.rel]))
var _natAtKey = ""
var _natAt = {}
var _natBox = {}
## 国名は一番大きなまとまりの真ん中に置く
func _natLabelAt() -> Dictionary:
	var k = str(S.G.get("ownRev", 0)) + "_" + str(S.G.terrs.size()) + "_" + str(S.G.turn)
	if k == _natAtKey and G_ == S.G: return _natAt
	_natAtKey = k
	_natAt = {}
	_natBox = {}
	var seen = {}
	var best = {}
	for t in S.G.terrs:
		if seen.has(t.id) or t.owner < 0: continue
		var grp = [t.id]
		seen[t.id] = true
		var h = 0
		while h < grp.size():
			for j in S.G.nb[grp[h]]:
				if not seen.has(j) and S.T(j).owner == t.owner:
					seen[j] = true
					grp.append(j)
			h += 1
		if not best.has(t.owner) or grp.size() > best[t.owner].size(): best[t.owner] = grp
	for o in best:
		var c = Vector2.ZERO
		var bb = Rect2()
		var first = true
		for id in best[o]:
			var t = S.T(id)
			c += Vector2(t.x, t.y)
			var tb: Rect2 = S.terrBounds(t)
			bb = tb if first else bb.merge(tb)
			first = false
		c /= best[o].size()
		var bd = INF
		for id in best[o]:
			var t = S.T(id)
			var d = Vector2(t.x, t.y).distance_squared_to(c)
			if d < bd:
				bd = d
				_natAt[o] = id
		_natBox[o] = bb
	return _natAt
var _rdCache = {}
func readable(hex: String) -> Color:
	if _rdCache.has(hex): return _rdCache[hex]
	var c = Color(hex)
	var lum = func(cc: Color) -> float: return 0.2126 * cc.srgb_to_linear().r + 0.7152 * cc.srgb_to_linear().g + 0.0722 * cc.srgb_to_linear().b
	var k = 0
	while k < 12 and lum.call(c) < 0.28:
		c = c.lerp(Color.WHITE, 0.15)
		k += 1
	_rdCache[hex] = c
	return c

# ============================================================
#   視点
# ============================================================
func _applyView() -> void:
	if root == null: return
	kick()
	root.scale = Vector2(vs, vs)
	root.position = Vector2(-vx * vs, -vy * vs)
	droot.scale = root.scale
	droot.position = root.position
	if S.G != null and abs(vs - _lastBorderScale) / max(vs, 0.0001) > 0.25:
		borderL.queue_redraw()
	relL.queue_redraw()
	selL.queue_redraw()
	markL.queue_redraw()
	siteL.queue_redraw()
	armyL.queue_redraw()
	labelL.queue_redraw()
	view_changed.emit()
func fitView() -> void:
	if S.G == null: return
	if size.x < 50 or size.y < 50:
		_fitPending = true
		return
	_fitPending = false
	var x0 = 0.0
	var y0 = 0.0
	var x1: float = S.G.W
	var y1: float = S.G.H
	if isJapan:
		var ky: float = 110.95 * S.JP.U
		var kx: float = 111.32 * cos(deg_to_rad(36.5)) * S.JP.U
		var yLim: float = (S.JP.lat1 - 30.9) * ky - S.G.geo.oy
		var xLim: float = (145.9 - S.JP.lon0) * kx - S.G.geo.ox
		x0 = INF; y0 = INF; x1 = -INF; y1 = -INF
		for t in S.G.terrs:
			if t.y > yLim or t.x > xLim: continue
			x0 = min(x0, t.x); y0 = min(y0, t.y); x1 = max(x1, t.x); y1 = max(y1, t.y)
		x0 -= 150; y0 -= 150; x1 += 150; y1 += 150
	var sw: float = max(size.x, 100)
	var sh: float = max(size.y, 100)
	vs = min(sw / (x1 - x0), sh / (y1 - y0)) * 0.96
	vx = (x0 + x1) / 2 - sw / (2 * vs)
	vy = (y0 + y1) / 2 - sh / (2 * vs)
	clampView()
func clampView() -> void:
	if S.G == null: return
	var m = 90.0
	var vw = size.x / vs
	var vh = size.y / vs
	vx = (S.G.W - vw) / 2 if vw >= S.G.W + m * 2 else clamp(vx, -m, S.G.W + m - vw)
	vy = (S.G.H - vh) / 2 if vh >= S.G.H + m * 2 else clamp(vy, -m, S.G.H + m - vh)
	_applyView()
func zoomAt(f: float, px: float, py: float) -> void:
	_userMoved = true
	if S.G == null: return
	var w = s2w(Vector2(px, py))
	vs = clamp(vs * f, min(size.x / S.G.W, size.y / S.G.H) * 0.5, 3.2)
	vx = w.x - px / vs
	vy = w.y - py / vs
	clampView()
func focusOn(tid: int) -> void:
	_userMoved = true
	var t = S.T(tid)
	vx = t.x - size.x / (2 * vs)
	vy = t.y - size.y / (2 * vs)
	clampView()
	S.flashTerr(tid)
func frameNation(nid: int) -> void:
	_userMoved = true
	_natLabelAt()
	if not _natBox.has(nid): return
	var bb: Rect2 = _natBox[nid]
	var m = 60.0
	vs = clamp(min(size.x / (bb.size.x + 2 * m), size.y / (bb.size.y + 2 * m)), min(size.x / S.G.W, size.y / S.G.H) * 0.5, 1.2)
	var c = bb.get_center()
	vx = c.x - size.x / (2 * vs)
	vy = c.y - size.y / (2 * vs)
	clampView()
func onScreen(t: Dictionary) -> bool:
	var m = 120.0
	return t.x > vx - m and t.x < vx + size.x / vs + m and t.y > vy - m and t.y < vy + size.y / vs + m

# ============================================================
#   当たり判定と入力
# ============================================================
func terrAt(w: Vector2) -> int:
	if S.G == null: return -1
	if isJapan:
		var onLand = false
		for r in landRings:
			if Geometry2D.is_point_in_polygon(w, r):
				onLand = true
				break
		if not onLand: return -1
		for r in lakeRings:
			if Geometry2D.is_point_in_polygon(w, r): return -1
	for t in S.G.terrs:
		var bb: Rect2 = S.terrBounds(t)
		if not bb.has_point(w): continue
		for r in rings[t.id]:
			if Geometry2D.is_point_in_polygon(w, r): return t.id
	if isJapan: return -1
	var best = -1
	var bd = INF
	for t in S.G.terrs:
		var d = w.distance_squared_to(Vector2(t.x, t.y))
		if d < bd:
			bd = d
			best = t.id
	return best
func armyHit(w: Vector2):
	var by = _armySlots()
	for tid in by:
		var t = S.T(tid)
		for i in by[tid].size():
			var p = Vector2(t.x, t.y) + slotOff(i)
			if abs(w.x - p.x) < 22 and w.y - p.y < 16 and p.y - w.y < 52: return by[tid][i]
	return null

var _touches = {}
var _pinch = null
func _gui_input(ev: InputEvent) -> void:
	if S.G == null: return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			zoomAt(1.15, ev.position.x, ev.position.y)
			hovered.emit(-1, ev.position)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			zoomAt(1 / 1.15, ev.position.x, ev.position.y)
			hovered.emit(-1, ev.position)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				drag = {"x": ev.position.x, "y": ev.position.y, "moved": false, "vx": vx, "vy": vy}
			else:
				if drag != null and not drag.moved:
					var w = s2w(ev.position)
					clicked.emit(w.x, w.y)
				drag = null
	elif ev is InputEventMouseMotion:
		if drag != null:
			var d = ev.position - Vector2(drag.x, drag.y)
			if abs(d.x) + abs(d.y) > 4: drag.moved = true
			if drag.moved:
				_userMoved = true
				vx = drag.vx - d.x / vs
				vy = drag.vy - d.y / vs
				clampView()
			hovered.emit(-1, ev.position)
		else:
			_hoverAt(ev.position)
	elif ev is InputEventMagnifyGesture:
		zoomAt(ev.factor, ev.position.x, ev.position.y)
	elif ev is InputEventPanGesture:
		vx += ev.delta.x * 20 / vs
		vy += ev.delta.y * 20 / vs
		clampView()
	elif ev is InputEventScreenTouch:
		if ev.pressed: _touches[ev.index] = ev.position
		else: _touches.erase(ev.index)
		if _touches.size() == 2:
			var ps: Array = _touches.values()
			_pinch = {"d": max(1.0, ps[0].distance_to(ps[1])), "s": vs}
			drag = null
		else: _pinch = null
	elif ev is InputEventScreenDrag:
		_touches[ev.index] = ev.position
		if _pinch != null and _touches.size() >= 2:
			var ps: Array = _touches.values()
			var d: float = ps[0].distance_to(ps[1])
			var mid: Vector2 = (ps[0] + ps[1]) / 2
			zoomAt((_pinch.s * d / _pinch.d) / vs, mid.x, mid.y)
var _hoverT = 0
var _hoverId = -2
func _hoverAt(p: Vector2) -> void:
	var now = Time.get_ticks_msec()
	if now - _hoverT < 50: return
	_hoverT = now
	var id = terrAt(s2w(p))
	_hoverId = id
	hovered.emit(id, p)
func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT: hovered.emit(-1, Vector2.ZERO)

# ---------- 陸の形を三角形に（自己交差などで失敗した輪は Clipper で整えてから） ----------
var landPts = PackedVector2Array()
var landIdx = PackedInt32Array()
func _triLand() -> void:
	landPts = PackedVector2Array()
	landIdx = PackedInt32Array()
	var bad = 0
	for r in landRings:
		var parts = [r]
		var idx = Geometry2D.triangulate_polygon(r)
		if idx.is_empty():
			parts = Geometry2D.offset_polygon(r, 0.05)
			bad += 1
		for p in parts:
			var ii = idx if p == r else Geometry2D.triangulate_polygon(p)
			if ii.is_empty(): continue
			var base = landPts.size()
			landPts.append_array(p)
			for k in ii: landIdx.append(base + k)
	if bad: print("land rings cleaned: ", bad)
func _fillCols(n: int, c: Color) -> PackedColorArray:
	var a = PackedColorArray()
	a.resize(n)
	a.fill(c)
	return a
## 三角形に分けられる形だけ塗る（点の重なりなどで失敗する形は凸包で代用）
var _polyWarn = 0
func _cpoly(c: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var idx = Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		if _polyWarn < 5:
			_polyWarn += 1
			print("polygon fallback n=", pts.size(), " at ", pts[0] if pts.size() else Vector2.ZERO)
		pts = Geometry2D.convex_hull(pts)
		idx = Geometry2D.triangulate_polygon(pts)
		if idx.is_empty(): return
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), idx, pts, _fillCols(pts.size(), col))
