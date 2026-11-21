# 三角形をまとめて1回で描くための入れ物（描画命令を減らす）
extends RefCounted

var pts := PackedVector2Array()
var idx := PackedInt32Array()
var cols := PackedColorArray()

func clear() -> void:
	pts = PackedVector2Array()
	idx = PackedInt32Array()
	cols = PackedColorArray()
func flush(item: RID) -> void:
	if idx.size(): RenderingServer.canvas_item_add_triangle_array(item, idx, pts, cols)
func tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var n := pts.size()
	pts.append(a); pts.append(b); pts.append(c)
	cols.append(col); cols.append(col); cols.append(col)
	idx.append(n); idx.append(n + 1); idx.append(n + 2)
## 線分（四角形）
func line(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.0001: return
	var nrm := Vector2(-d.y, d.x) / L * (w * 0.5)
	var n := pts.size()
	pts.append(a + nrm); pts.append(b + nrm); pts.append(b - nrm); pts.append(a - nrm)
	for i in 4: cols.append(col)
	idx.append(n); idx.append(n + 1); idx.append(n + 2)
	idx.append(n); idx.append(n + 2); idx.append(n + 3)
## 折れ線（つなぎ目は細かい円で丸める＝太い線だけ）
func polyline(p: PackedVector2Array, w: float, col: Color, roundJoins := false) -> void:
	for i in p.size() - 1: line(p[i], p[i + 1], w, col)
	if roundJoins and w > 3:
		for i in range(1, p.size() - 1): circle(p[i], w * 0.5, col, 8)
func circle(c: Vector2, r: float, col: Color, seg := 12) -> void:
	var n := pts.size()
	pts.append(c)
	cols.append(col)
	for i in seg:
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a), sin(a)) * r)
		cols.append(col)
	for i in seg:
		idx.append(n); idx.append(n + 1 + i); idx.append(n + 1 + (i + 1) % seg)
## 円の縁（輪）
func ring(c: Vector2, r: float, w: float, col: Color, seg := 20, a0 := 0.0, a1 := TAU) -> void:
	var n := pts.size()
	var ri := r - w * 0.5
	var ro := r + w * 0.5
	for i in seg + 1:
		var a := a0 + (a1 - a0) * i / seg
		var v := Vector2(cos(a), sin(a))
		pts.append(c + v * ri); pts.append(c + v * ro)
		cols.append(col); cols.append(col)
	for i in seg:
		var k := n + i * 2
		idx.append(k); idx.append(k + 1); idx.append(k + 3)
		idx.append(k); idx.append(k + 3); idx.append(k + 2)
## 多角形（三角形に分けて）
func poly(p: PackedVector2Array, col: Color) -> void:
	var ii := Geometry2D.triangulate_polygon(p)
	if ii.is_empty():
		p = Geometry2D.convex_hull(p)
		ii = Geometry2D.triangulate_polygon(p)
	var n := pts.size()
	pts.append_array(p)
	for i in p.size(): cols.append(col)
	for k in ii: idx.append(n + k)
## 三角形に分け済みの形をそのまま
func mesh(p: PackedVector2Array, ii: PackedInt32Array, col: Color) -> void:
	var n := pts.size()
	pts.append_array(p)
	for i in p.size(): cols.append(col)
	for k in ii: idx.append(n + k)
func rect(r: Rect2, col: Color) -> void:
	tri(r.position, Vector2(r.end.x, r.position.y), r.end, col)
	tri(r.position, r.end, Vector2(r.position.x, r.end.y), col)
