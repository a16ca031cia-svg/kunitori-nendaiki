# 日本地図のデータ（元の JS で作った初期状態）を圧縮バイナリにする
# 使い方: godot --headless --path . --script res://tools/convert_jp.gd -- <jp_maps.json>
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0]
	var txt := FileAccess.get_file_as_string(src)
	if txt.begins_with("\ufeff"): txt = txt.substr(1)
	var maps = JSON.parse_string(txt)
	DirAccess.make_dir_recursive_absolute("res://data/jp")
	var i := 0
	for m in maps:
		for t in m.terrs:
			var segs := []
			for sg in t.segs:
				var p := PackedVector2Array()
				for q in sg: p.append(Vector2(q[0], q[1]))
				segs.append(p)
			t.segs = segs
			for k in ["id", "owner", "dev", "infra", "pop", "sec", "link", "chaos"]:
				if t.has(k) and t[k] != null: t[k] = int(t[k])
			var sn := PackedInt32Array()
			for v in t.get("sn", []): sn.append(int(v))
			t.sn = sn
		for e in m.edges:
			e.a = int(e.a); e.b = int(e.b); e.lv = int(e.lv)
		var nb := []
		for l in m.nb:
			var a := []
			for v in l: a.append(int(v))
			nb.append(a)
		m.nb = nb
		for n in m.nat: n.capital = int(n.capital)
		var f := FileAccess.open_compressed("res://data/jp/map%d.bin" % i, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		f.store_var(m)
		f.close()
		print("map", i, " terrs=", m.terrs.size(), " edges=", m.edges.size())
		i += 1
	quit()
