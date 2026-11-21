# 領地数の推移のグラフ（線は国の色、線の端に国名）（元 3011〜3059）
extends Control

var font: Font

func _draw() -> void:
	var H: Array = S.G.hist
	draw_rect(Rect2(Vector2.ZERO, size), Color("#252b38"))
	draw_string(font, Vector2(10, 16), "領地数の推移（縦：領地数 ／ 横：ターン）", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#9b9484"))
	if H.size() < 2:
		draw_string(font, Vector2(10, 40), "領地の推移はターンを進めると記録されます。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9b9484"))
		return
	var many: bool = S.G.nations.size() > 6
	var W = size.x
	var HT = size.y
	var PL = 34.0
	var PR = 110.0
	var PT = 26.0
	var PB = 24.0
	var t0: float = H[0].t
	var t1: float = H[-1].t
	var peak = 1
	for h in H:
		for v in h.o: peak = max(peak, v)
	var step = 100
	for s in [1, 2, 5, 10, 20, 25, 50]:
		if peak / float(s) <= 4:
			step = s
			break
	var maxY: int = max(step * 2, int(ceil(peak / float(step))) * step)
	var X = func(t: float) -> float: return PL + (t - t0) / max(1.0, t1 - t0) * (W - PL - PR)
	var Y = func(v: float) -> float: return PT + (1 - v / maxY) * (HT - PT - PB)
	var v = 0
	while v <= maxY:
		var y: float = Y.call(v)
		draw_line(Vector2(PL, y), Vector2(W - PR, y), Color(0.22, 0.25, 0.31, 0.7), 1)
		draw_string(font, Vector2(PL - 30, y + 4), str(v), HORIZONTAL_ALIGNMENT_RIGHT, 24, 10, Color("#9b9484"))
		v += step
	for t in [t0, round((t0 + t1) / 2), t1]:
		draw_string(font, Vector2(X.call(t) - 20, HT - 6), "%dT" % t, HORIZONTAL_ALIGNMENT_CENTER, 40, 10, Color("#9b9484"))
	var ends = []
	for n in S.G.nations:
		var pts = PackedVector2Array()
		for h in H:
			var o: int = h.o[n.id] if n.id < h.o.size() else 0
			pts.append(Vector2(X.call(h.t), Y.call(o)))
		var c = Color(n.color)
		if not n.alive: c.a = 0.45
		draw_polyline(pts, c, 2, true)
		var last: int = H[-1].o[n.id] if n.id < H[-1].o.size() else 0
		ends.append({"n": n, "y": Y.call(last), "v": last})
	var show = ends.duplicate()
	show.sort_custom(func(a, b): return a.v > b.v)
	show = show.slice(0, 8 if many else show.size())
	show.sort_custom(func(a, b): return a.y < b.y)
	var gap = 12.0 if many else 13.0
	for i in range(1, show.size()):
		if show[i].y - show[i - 1].y < gap: show[i].y = show[i - 1].y + gap
	var over: float = (show[-1].y - (HT - PB + 4)) if show.size() else 0.0
	if over > 0:
		for e in show: e.y -= over
	for e in show:
		var c = Color(e.n.color)
		if not e.n.alive: c.a = 0.5
		draw_string(font, Vector2(W - PR + 8, e.y + 4), "%s %d" % [e.n.name.substr(0, 5), e.v], HORIZONTAL_ALIGNMENT_LEFT, -1, 10 if many else 11, c)
	if show.size() < ends.size():
		draw_string(font, Vector2(W - PR + 8, (show[-1].y if show.size() else PT) + 17), "ほか %d国" % (ends.size() - show.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#9b9484"))
