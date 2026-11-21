# 地図：架空の大陸の生成（元 1048〜1418）・日本地図の読み込み・領地の形の道具
extends "res://scripts/core/k0_base.gd"

const JP := {"U": 6.5, "S": 4, "lon0": 127.6, "lat1": 45.9}
func jpProj(lon: float, lat: float) -> Vector2:
	var kx: float = 111.32 * cos(deg_to_rad(36.5)) * JP.U
	var ky: float = 110.95 * JP.U
	return Vector2((lon - JP.lon0) * kx, (JP.lat1 - lat) * ky)

# ---------- 幾何 ----------
## 多角形を長方形で切る
func clipRect(poly: Array, x0: float, y0: float, x1: float, y1: float) -> Array:
	var p := poly
	p = _clipEdge(p, 0, x0, true); if p.size() < 3: return p
	p = _clipEdge(p, 0, x1, false); if p.size() < 3: return p
	p = _clipEdge(p, 1, y0, true); if p.size() < 3: return p
	return _clipEdge(p, 1, y1, false)
func _clipEdge(pts: Array, axis: int, v: float, keepGreater: bool) -> Array:
	var out := []
	var n := pts.size()
	for i in n:
		var A: Vector2 = pts[i]
		var B: Vector2 = pts[(i + 1) % n]
		var ia: bool = (A[axis] >= v) if keepGreater else (A[axis] <= v)
		var ib: bool = (B[axis] >= v) if keepGreater else (B[axis] <= v)
		if ia: out.append(A)
		if ia != ib:
			var t: float = (v - A[axis]) / (B[axis] - A[axis])
			out.append(A + (B - A) * t)
	return out
func _circum(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if abs(d) < 1e-12: return (a + b + c) / 3.0
	var a2 := a.length_squared()
	var b2 := b.length_squared()
	var c2 := c.length_squared()
	return Vector2((a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d,
		(a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d)
## ドロネー分割から作るボロノイ（JS の voronoiD3 と同じ形で返す）
func buildVoronoi(sites: Array, W: float, H: float) -> Dictionary:
	var n := sites.size()
	var pts := PackedVector2Array()
	for s in sites: pts.append(s)
	pts.append(Vector2(-10 * W, -10 * H)); pts.append(Vector2(11 * W, -10 * H))
	pts.append(Vector2(11 * W, 11 * H)); pts.append(Vector2(-10 * W, 11 * H))
	var tri := Geometry2D.triangulate_delaunay(pts)
	var inc := []
	var nbs := []
	for i in n:
		inc.append([])
		nbs.append({})
	var cc := []
	for k in range(0, tri.size(), 3):
		var ia := tri[k]
		var ib := tri[k + 1]
		var ic := tri[k + 2]
		var c := _circum(pts[ia], pts[ib], pts[ic])
		var ti := cc.size()
		cc.append(c)
		for v in [ia, ib, ic]:
			if v < n: inc[v].append(ti)
		for e in [[ia, ib], [ib, ic], [ic, ia]]:
			if e[0] < n and e[1] < n:
				nbs[e[0]][e[1]] = true
				nbs[e[1]][e[0]] = true
	var polys := []
	var nb := []
	var edgeNb := []
	for i in n:
		var s: Vector2 = sites[i]
		var ring := []
		for ti in inc[i]: ring.append(cc[ti])
		ring.sort_custom(func(p, q): return (p - s).angle() < (q - s).angle())
		var dd := []
		for p in ring:
			if dd.is_empty() or (p - dd[-1]).length() > 1e-3: dd.append(p)
		if dd.size() > 1 and (dd[0] - dd[-1]).length() <= 1e-3: dd.pop_back()
		var poly := clipRect(dd, 0, 0, W, H)
		var clean := []
		for p in poly:
			if clean.is_empty() or (p - clean[-1]).length() > 1e-3: clean.append(p)
		if clean.size() > 1 and (clean[0] - clean[-1]).length() <= 1e-3: clean.pop_back()
		polys.append(clean)
		nb.append({})
		edgeNb.append([])
	for i in n:
		var p: Array = polys[i]
		var cand: Array = nbs[i].keys()
		for e in p.size():
			var A: Vector2 = p[e]
			var B: Vector2 = p[(e + 1) % p.size()]
			var m := (A + B) / 2.0
			var di := m.distance_squared_to(sites[i])
			var best := -1
			var bd := INF
			for j in cand:
				var dj := m.distance_squared_to(sites[j])
				if dj < bd:
					bd = dj
					best = j
			var shared: bool = best >= 0 and abs(bd - di) < max(1.0, di) * 1e-3   # Vector2 は単精度なので緩めに（候補はドロネーの隣だけ）
			edgeNb[i].append(best if shared else -1)
			if shared:
				nb[i][best] = true
				nb[best][i] = true
	return {"polys": polys, "nb": nb, "edgeNb": edgeNb}

# ---------- 境界の曲線化 ----------
func wobbleEdge(A: Vector2, B: Vector2) -> Array:
	var d := B - A
	var len: float = max(d.length(), 1.0)
	var n := int(clamp_f(round(len / 34), 2, 7))
	var pn := Vector2(-d.y / len, d.x / len)
	var amp: float = min(17.0, len * 0.14)
	var pts := [A]
	var o := 0.0
	for i in range(1, n):
		var t := float(i) / n
		o = o * 0.5 + (randf() * 2 - 1) * amp
		var w := o * sin(PI * t)
		pts.append(A + d * t + pn * w)
	pts.append(B)
	return pts
# ---------- なめらかなノイズ ----------
func waveNoise(n: int, minL: float, maxL: float) -> Callable:
	var w := []
	for i in n:
		var a := randf() * TAU
		var L := rnd(minL, maxL)
		w.append([cos(a) * TAU / L, sin(a) * TAU / L, randf() * 7, rnd(0.5, 1)])
	return func(x: float, y: float) -> float:
		var v := 0.0
		var s2 := 0.0
		for q in w:
			v += sin(x * q[0] + y * q[1] + q[2]) * q[3]
			s2 += q[3]
		return v / s2
func assignTerrain(sites: Array) -> Array:
	var n := sites.size()
	var el := waveNoise(7, 900, 2600)
	var mo := waveNoise(7, 800, 2400)
	var fine := waveNoise(5, 350, 700)
	var E := []
	var Mo := []
	for s in sites:
		E.append(el.call(s.x, s.y) + fine.call(s.x, s.y) * 0.35)
		Mo.append(mo.call(s.x, s.y) + fine.call(s.y, s.x) * 0.3)
	var res := []
	res.resize(n)
	res.fill("plain")
	var rest := range(n)
	var take := func(list: Array, cnt: int, key: Callable, kind: String) -> Array:
		list.sort_custom(func(a, b): return key.call(a) > key.call(b))
		for i in min(cnt, list.size()): res[list[i]] = kind
		return list.slice(cnt)
	rest = take.call(rest, int(round(n * 0.10)), func(i): return E[i], "mount")
	rest = take.call(rest, int(round(n * 0.15)), func(i): return E[i], "hill")
	rest = take.call(rest, int(round(n * 0.08)), func(i): return Mo[i] - E[i] * 0.8, "marsh")
	rest = take.call(rest, int(round(n * 0.20)), func(i): return Mo[i], "forest")
	rest = take.call(rest, int(round(n * 0.15)), func(i): return -Mo[i], "grass")
	return res
# ---------- 大陸の輪郭 ----------
func makeContinent() -> Callable:
	var ph := [rnd(0, 6.28), rnd(0, 6.28), rnd(0, 6.28), rnd(0, 6.28), rnd(0, 6.28)]
	var a := [rnd(0.11, 0.19), rnd(0.08, 0.15), rnd(0.05, 0.10), rnd(0.03, 0.07), rnd(0.02, 0.05)]
	var base := rnd(0.70, 0.78)
	return func(th: float) -> float:
		return clamp_f(base + a[0] * sin(th * 2 + ph[0]) + a[1] * sin(th * 3 + ph[1]) + a[2] * sin(th * 5 + ph[2]) \
			+ a[3] * sin(th * 7 + ph[3]) + a[4] * sin(th * 11 + ph[4]), 0.30, 0.985)
func inLand(shape: Callable, x: float, y: float, W: float, H: float) -> bool:
	var dx := (x - W / 2) / (W / 2)
	var dy := (y - H / 2) / (H / 2)
	return Vector2(dx, dy).length() <= shape.call(atan2(dy, dx))
func keepMainland(keep: Array, nb: Array) -> Array:
	var seen := []
	seen.resize(keep.size())
	seen.fill(false)
	var best = null
	for i in keep.size():
		if not keep[i] or seen[i]: continue
		var q := [i]
		seen[i] = true
		var h := 0
		while h < q.size():
			for j in nb[q[h]]:
				if keep[j] and not seen[j]:
					seen[j] = true
					q.append(j)
			h += 1
		if best == null or q.size() > best.size(): best = q
	if best == null: return keep
	var ok := []
	ok.resize(keep.size())
	ok.fill(false)
	for i in best: ok[i] = true
	return ok

func _newNation(k: int, name: String, color: String, capital: int, persona: String) -> Dictionary:
	var arm := []
	arm.resize(ARMY_MAX)
	return {"id": k, "name": name, "color": color, "gold": 10000, "stock": {"inf": 3000, "spe": 0, "arc": 0, "cav": 0},
		"gens": [], "armies": arm, "alive": true, "capital": capital, "player": false, "persona": persona,
		"wins": 0, "losses": 0, "recLed": 0, "badHarv": 0, "mile": {}, "threat": 0,
		"food": 0, "foodIn": 0, "foodNeed": 0, "fatigue": 0,
		"lord": null, "unrest": 0, "revoltBuff": 0, "policy": "none", "policyAt": -99}
func _newTerr(i: int, pos: Vector2, segs: Array, owner: int, cap: bool, type: String, name: String, dev: int, terrain: String) -> Dictionary:
	return {"id": i, "x": pos.x, "y": pos.y, "segs": segs, "owner": owner, "cap": cap, "type": type, "name": name,
		"dev": dev, "devP": false, "bld": [], "chaos": 0, "pop": 0, "sec": CFG.secStart, "link": 1, "trait": null,
		"terrain": terrain, "infra": 1, "siege": null}
## 最後の仕上げ：国の初期の食料・将軍と第1軍団
func _finishNations(g: Dictionary) -> void:
	var popBy := {}
	for t in g.terrs: popBy[t.owner] = popBy.get(t.owner, 0) + t.pop
	for na in g.nations:
		na.food = int(round((popBy.get(na.id, 0) / 1000.0 * CFG.foodPop + 3 * CFG.foodTroop) * 10))
	initDip(g)
	for na in g.nations:
		var gen := mkGen(g, na, randomPts())
		var a := mkArmy(na.id, 0, na.capital)
		a.t.inf = 3000
		a.target.inf = 3000
		a.gen = gen.id
		gen.army = 0
		na.armies[0] = a; ARMY_REV += 1
		na.stock.inf = 0

## 架空の大陸
func genMap(size: String) -> Dictionary:
	var SZ: Dictionary = SIZES.get(size, SIZES.mid)
	var N: int = SZ.n
	var NN: int = SZ.nat
	var shape := makeContinent()
	var mult := 1.85
	var cols := 1
	var rows := 1
	var W := 0.0
	var H := 0.0
	var pts := []
	var land := []
	for it in 9:
		var M: int = max(NN * 3, int(round(N * mult)))
		cols = int(round(sqrt(M * 2.1)))
		rows = max(3, int(round(float(M) / cols)))
		W = 190.0 * cols
		H = 190.0 * rows
		pts = []
		for r in rows:
			for c in cols:
				var cw := W / cols
				var ch := H / rows
				pts.append(Vector2(cw * (c + 0.5) + rnd(-cw * 0.32, cw * 0.32), ch * (r + 0.5) + rnd(-ch * 0.32, ch * 0.32)))
		land = []
		var k := 0
		for p in pts:
			var v := inLand(shape, p.x, p.y, W, H)
			land.append(v)
			if v: k += 1
		if abs(k - N) <= max(2, N * 0.03): break
		mult *= float(N) / max(1, k)
	var sites0 := pts
	var V := buildVoronoi(sites0, W, H)
	var polys0: Array = V.polys
	var nb0 := []
	for s in V.nb: nb0.append(s.keys())
	var edgeNb0: Array = V.edgeNb
	var n0 := sites0.size()
	# 境界線を曲線化（隣り合う領地で同じ線を共有する）
	var borders := {}
	for i in n0:
		var p: Array = polys0[i]
		for e in p.size():
			var j: int = edgeNb0[i][e]
			if j < 0 or i > j: continue
			borders[bkey(i, j)] = wobbleEdge(p[e], p[(e + 1) % p.size()])
	var outlines0 := []
	for i in n0:
		var p: Array = polys0[i]
		var segs := []
		for e in p.size():
			var A: Vector2 = p[e]
			var B: Vector2 = p[(e + 1) % p.size()]
			var j: int = edgeNb0[i][e]
			if j < 0:
				segs.append([A, B])
				continue
			var line: Array = borders[bkey(i, j)]
			if i < j: segs.append(line.duplicate())
			else:
				var r := line.duplicate()
				r.reverse()
				segs.append(r)
		outlines0.append(segs)
	# 海の部分を捨てて番号を振り直す
	var keep := keepMainland(land, nb0)
	var remap := []
	remap.resize(n0)
	remap.fill(-1)
	var pick0 := []
	for i in n0:
		if keep[i]:
			remap[i] = pick0.size()
			pick0.append(i)
	var sites := []
	var outlines := []
	var nb := []
	for i in pick0:
		sites.append(sites0[i])
		outlines.append(outlines0[i])
		var l := []
		for j in nb0[i]:
			if keep[j]: l.append(remap[j])
		nb.append(l)
	var n := sites.size()
	# 国の種（互いに離れた点）
	var seeds := [ri(0, n - 1)]
	while seeds.size() < NN:
		var best := -1
		var bd := -1.0
		for i in n:
			if seeds.has(i): continue
			var d := INF
			for s in seeds: d = min(d, sites[i].distance_squared_to(sites[s]))
			if d > bd:
				bd = d
				best = i
		seeds.append(best)
	# 多元BFSで領地を分配
	var owner := []
	owner.resize(n)
	owner.fill(-1)
	var front := []
	for k in NN:
		owner[seeds[k]] = k
		front.append([seeds[k]])
	var placed := NN
	while placed < n:
		var moved := false
		for k in NN:
			var f: Array = front[k]
			while f.size():
				var cur: int = f[0]
				var free := []
				for j in nb[cur]:
					if owner[j] < 0: free.append(j)
				if free.is_empty():
					f.pop_front()
					continue
				var j2: int = free[ri(0, free.size() - 1)]
				owner[j2] = k
				f.append(j2)
				placed += 1
				moved = true
				break
			if placed >= n: break
		if not moved:
			for i in n:
				if owner[i] < 0:
					owner[i] = ri(0, NN - 1)
					placed += 1
	# 領地
	var terrain := assignTerrain(sites)
	for sd in seeds:
		if TERRAIN[terrain[sd]].slow: terrain[sd] = "plain"
	var usedC := {}
	var usedF := {}
	var terrs := []
	for i in n:
		var border := false
		for j in nb[i]:
			if owner[j] != owner[i]: border = true
		var isCap := seeds.has(i)
		var rough: bool = terrain[i] == "mount" or terrain[i] == "hill"
		var fort: bool = not isCap and randf() < (0.55 if border else 0.20) + (0.15 if rough else 0.0)
		var nm: String = uniqName(usedF, func(): return pick(FA) + pick(FB) + "砦") if fort else uniqName(usedC, func(): return pick(CA) + pick(CB))
		var segs := []
		for sg in outlines[i]: segs.append(PackedVector2Array(sg))
		terrs.append(_newTerr(i, sites[i], segs, owner[i], isCap, "fort" if fort else "city", nm, 3 if isCap else ri(1, 2), terrain[i]))
	for t in terrs:
		t.pop = int(round((CFG.popCity if t.type == "city" else CFG.popFort) * t.dev * 0.7 * terrOf(t).pop))
		if randf() < TRAIT_RATE:
			var keys := []
			for k in TRAIT_KEYS:
				if not (TRAIT[k].get("city", false) and t.type != "city"): keys.append(k)
			t.trait = pick(keys)
	# 地形障壁（険しい山脈は越えられない）
	var bars := []
	for a in n:
		for b in nb[a]:
			if a >= b: continue
			var mt: bool = terrain[a] == "mount" or terrain[b] == "mount" or (terrain[a] == "hill" and terrain[b] == "hill")
			var kind := "mtn" if mt or randf() < 0.3 else "river"
			var line = borders.get(bkey(pick0[a], pick0[b]))
			if line == null: continue
			bars.append({"a": a, "b": b, "kind": kind, "pts": PackedVector2Array(line)})
	# 開始時は首都の周りだけを治め、残りは無主の地
	var blocked := {}
	for b in bars:
		if b.kind == "mtn": blocked[bkey(b.a, b.b)] = true
	var rn := []
	for i in n:
		var l := []
		for j in nb[i]:
			if not blocked.has(bkey(i, j)): l.append(j)
		rn.append(l)
	for k in NN:
		var keepN: int = FRONT.startTerr if FRONT.startTerr > 0 else max(4, int(round(float(N) / NN * 0.15)))
		var seen := {seeds[k]: true}
		var q := [seeds[k]]
		var i := 0
		while i < q.size() and seen.size() < keepN:
			var nx := []
			for j in rn[q[i]]:
				if terrs[j].owner == k and not seen.has(j): nx.append(j)
			var sp: Vector2 = sites[seeds[k]]
			nx.sort_custom(func(x, y): return sites[x].distance_squared_to(sp) < sites[y].distance_squared_to(sp))
			for j in nx:
				if seen.size() >= keepN: break
				seen[j] = true
				q.append(j)
			i += 1
		for t in terrs:
			if t.owner == k and not seen.has(t.id):
				t.owner = -1
				t.dev = 1
				t.bld = []
				t.pop = int(round((CFG.popCity if t.type == "city" else CFG.popFort) * 0.7 * FRONT.wildPop * terrOf(t).pop))
	# 国家
	var usedN := {}
	var nations := []
	var pk := shuffled(["aggr", "def", "econ", "bal"])
	for k in NN:
		nations.append(_newNation(k, uniqName(usedN, func(): return pick(NA) + pick(NB) + pick(NC)), NCOL[k], seeds[k], pk[k % 4]))
	# つながり：隣り合う領地はどこへでも（険しい山脈だけは越えられない）。インフラは首都と大きな町ほど高い
	var edges := []
	for a in n:
		for b in nb[a]:
			if a < b and not blocked.has(bkey(a, b)):
				edges.append({"a": a, "b": b, "lv": 3, "pend": false, "cx": 0.0, "cy": 0.0})
	var capN := {}
	for e in edges:
		if terrs[e.a].cap: capN[e.b] = true
		if terrs[e.b].cap: capN[e.a] = true
	for t in terrs:
		t.infra = 3 if t.cap else (2 if capN.has(t.id) or (t.type == "city" and t.dev >= 3) else 1)
	# 陸地に合わせて地図の広さを詰める
	var x0 := INF
	var y0 := INF
	var x1 := -INF
	var y1 := -INF
	for t in terrs:
		for sg in t.segs:
			for p in sg:
				x0 = min(x0, p.x); x1 = max(x1, p.x); y0 = min(y0, p.y); y1 = max(y1, p.y)
	var M2 := 130.0
	var off := Vector2(M2 - x0, M2 - y0)
	for t in terrs:
		t.x += off.x
		t.y += off.y
		var ns := []
		for sg in t.segs:
			var q := PackedVector2Array()
			for p in sg: q.append(p + off)
			ns.append(q)
		t.segs = ns
	for b in bars:
		var q := PackedVector2Array()
		for p in b.pts: q.append(p + off)
		b.pts = q
	W = round(x1 - x0 + M2 * 2)
	H = round(y1 - y0 + M2 * 2)
	var g := {"turn": 1, "size": size, "W": W, "H": H, "terrs": terrs, "edges": edges, "bars": bars, "nations": nations,
		"nb": nb, "gid": 1, "log": [], "over": null, "chron": [], "hist": [], "observer": true, "supply": null}
	_finishNations(g)
	return g

## 日本地図：元の JS で作った初期状態（4種類）から1つ選び、国の性格などはここで振り直す
func genJapan(which := -1) -> Dictionary:
	if which < 0: which = randi() % 4
	var f := FileAccess.open_compressed("res://data/jp/map%d.bin" % which, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var m: Dictionary = f.get_var()
	f.close()
	var terrs: Array = m.terrs
	for t in terrs:
		t.devP = false
		t.bld = []
		t.chaos = 0
		t.siege = null
		if not t.has("trait"): t.trait = null
		t.link = 1
		t.sec = CFG.secStart
	var cols := []
	for n in m.nat: cols.append(n.color)
	resetColors(cols)
	var NN: int = m.nat.size()
	var pk := []
	for i in NN: pk.append(["aggr", "def", "econ", "bal"][i % 4])
	pk.shuffle()
	var nations := []
	for k in NN:
		nations.append(_newNation(k, m.nat[k].name, m.nat[k].color, m.nat[k].capital, pk[k]))
	var g := {"turn": 1, "size": "japan", "W": m.W, "H": m.H, "terrs": terrs, "edges": m.edges, "bars": [], "nations": nations,
		"nb": m.nb, "gid": 1, "log": [], "over": null, "chron": [], "hist": [], "observer": true, "supply": null,
		"geo": m.geo, "jpMap": which}
	_finishNations(g)
	return g

# ---------- 領地の形の道具 ----------
func terrBounds(t: Dictionary) -> Rect2:
	if t.has("bb"): return t.bb
	var x0 := INF
	var y0 := INF
	var x1 := -INF
	var y1 := -INF
	for sg in t.segs:
		for p in sg:
			x0 = min(x0, p.x); x1 = max(x1, p.x); y0 = min(y0, p.y); y1 = max(y1, p.y)
	t.bb = Rect2(x0, y0, x1 - x0, y1 - y0)
	return t.bb
## 各辺がどの領地と接しているか（端点が一致する辺は同じ境）
var SEGN_DONE = null
func segNbrs() -> void:
	if SEGN_DONE == G: return
	var m := {}
	for t in G.terrs:
		if t.has("sn") and t.sn.size() == t.segs.size():
			t.segN = Array(t.sn)
			continue
		var sn := []
		sn.resize(t.segs.size())
		sn.fill(-1)
		t.segN = sn
		for i in t.segs.size():
			var sg: PackedVector2Array = t.segs[i]
			var a := "%d,%d" % [round(sg[0].x), round(sg[0].y)]
			var b := "%d,%d" % [round(sg[-1].x), round(sg[-1].y)]
			var k := (a + "|" + b) if a < b else (b + "|" + a)
			if not m.has(k): m[k] = []
			m[k].append([t, i])
	for arr in m.values():
		if arr.size() != 2: continue
		arr[0][0].segN[arr[0][1]] = arr[1][0].id
		arr[1][0].segN[arr[1][1]] = arr[0][0].id
	SEGN_DONE = G
