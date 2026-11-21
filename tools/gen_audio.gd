# BGM と効果音を合成して audio/*.wav に書き出す（素材は使わず、すべてこのスクリプトで作る）
# 使い方: godot --headless --path . --script res://tools/gen_audio.gd
extends SceneTree

const SR := 22050
var rng := RandomNumberGenerator.new()

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://audio")
	rng.seed = 20261121
	_save("bgm_peace", _bgmPeace())
	_save("bgm_war", _bgmWar())
	_save("sfx_click", _click())
	_save("sfx_turn", _bell(784.0, 1.2, 0.35))
	_save("sfx_notice", _bell(587.33, 1.0, 0.3))
	_save("sfx_war", _gong(98.0, 2.6, 0.75))
	_save("sfx_fall", _gong(65.0, 3.2, 0.7))
	_save("sfx_battle", _battle())
	_save("sfx_capture", _capture())
	_save("sfx_peace", _chime())
	print("done")
	quit()

func _save(name: String, buf: PackedFloat32Array) -> void:
	var peak := 0.0
	for v in buf: peak = max(peak, abs(v))
	var g: float = 0.89 / peak if peak > 0.89 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var s := int(clamp(buf[i] * g, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	w.save_to_wav("res://audio/%s.wav" % name)
	print(name, " ", buf.size() / float(SR), "s")

func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * SR))
	return b
## 長さ L の輪の中に足す（ループの継ぎ目で音が途切れないように、はみ出した分は頭へ回す）
func _mixLoop(dst: PackedFloat32Array, src: PackedFloat32Array, at: int, gain: float) -> void:
	var L := dst.size()
	for i in src.size(): dst[(at + i) % L] += src[i] * gain
func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at: int, gain: float) -> void:
	for i in src.size():
		if at + i < dst.size(): dst[at + i] += src[i] * gain

# ---------- 音の部品 ----------
## 弦をはじく音（Karplus-Strong）。bright が大きいほど明るい
func _pluck(freq: float, sec: float, bright: float, decay: float) -> PackedFloat32Array:
	var out := _buf(sec)
	var n := int(SR / freq)
	var ring := PackedFloat32Array()
	ring.resize(n)
	for i in n: ring[i] = rng.randf_range(-1, 1)
	# 少しなめらかにして角を取る
	for k in int(3 - bright * 2):
		for i in n: ring[i] = (ring[i] + ring[(i + 1) % n]) * 0.5
	var idx := 0
	for i in out.size():
		var a := ring[idx]
		var b := ring[(idx + 1) % n]
		var v := (a * (0.5 + bright * 0.25) + b * (0.5 - bright * 0.25)) * decay
		ring[idx] = v
		out[i] = a
		idx = (idx + 1) % n
	# 立ち上がりのはじく音
	for i in min(80, out.size()): out[i] *= i / 80.0
	return out
## 太鼓：低い音程が下がりながら消える胴の音＋皮のざらつき
func _taiko(freq: float, sec: float, noise: float) -> PackedFloat32Array:
	var out := _buf(sec)
	var ph := 0.0
	for i in out.size():
		var t := i / float(SR)
		var f := freq * (1.0 + 1.4 * exp(-t * 28.0))
		ph += TAU * f / SR
		var env := exp(-t * 7.0)
		out[i] = sin(ph) * env + rng.randf_range(-1, 1) * noise * exp(-t * 45.0)
	return out
## 鐘：倍音がずれた正弦波の重ね合わせ
func _bell(freq: float, sec: float, gain: float) -> PackedFloat32Array:
	var out := _buf(sec)
	var parts := [[1.0, 1.0, 3.0], [2.76, 0.5, 5.0], [5.4, 0.25, 8.0], [8.93, 0.12, 12.0]]
	for i in out.size():
		var t := i / float(SR)
		var v := 0.0
		for p in parts: v += sin(TAU * freq * p[0] * t) * p[1] * exp(-t * p[2])
		out[i] = v * gain * min(1.0, i / 60.0)
	return out
## 銅鑼：うなる低い倍音と長い余韻
func _gong(freq: float, sec: float, gain: float) -> PackedFloat32Array:
	var out := _buf(sec)
	var parts := [[1.0, 1.0], [1.47, 0.6], [2.09, 0.5], [2.56, 0.35], [3.13, 0.3], [4.2, 0.2]]
	for i in out.size():
		var t := i / float(SR)
		var v := 0.0
		for k in parts.size():
			var p: Array = parts[k]
			v += sin(TAU * freq * p[0] * t + sin(t * (3 + k)) * 0.6) * p[1]
		var env := (1.0 - exp(-t * 40.0)) * exp(-t * 1.3)
		out[i] = v * env * gain + rng.randf_range(-1, 1) * exp(-t * 30.0) * 0.25
	return out

# ---------- 効果音 ----------
func _click() -> PackedFloat32Array:
	var out := _buf(0.09)
	for i in out.size():
		var t := i / float(SR)
		out[i] = (sin(TAU * 1800 * t) * 0.6 + sin(TAU * 2900 * t) * 0.3) * exp(-t * 90.0)
	return out
func _battle() -> PackedFloat32Array:
	var out := _buf(1.3)
	_mix(out, _taiko(70, 1.0, 0.5), 0, 1.0)
	_mix(out, _taiko(90, 0.8, 0.6), int(0.16 * SR), 0.8)
	# 刃の打ち合う音
	for k in 3:
		var at := int((0.3 + k * 0.17) * SR)
		var b := _buf(0.25)
		for i in b.size():
			var t := i / float(SR)
			b[i] = (sin(TAU * 2350 * t) + sin(TAU * 3170 * t) * 0.7 + rng.randf_range(-1, 1) * 0.5) * exp(-t * 25.0)
		_mix(out, b, at, 0.35)
	return out
func _capture() -> PackedFloat32Array:
	var out := _buf(0.9)
	_mix(out, _taiko(80, 0.7, 0.4), 0, 1.0)
	_mix(out, _taiko(80, 0.7, 0.4), int(0.2 * SR), 1.0)
	return out
func _chime() -> PackedFloat32Array:
	var out := _buf(1.8)
	var notes := [587.33, 698.46, 880.0, 1174.66]
	for k in notes.size(): _mix(out, _bell(notes[k], 1.2, 0.3), int(k * 0.12 * SR), 1.0)
	return out

# ---------- BGM ----------
## 都節の音階（D・E♭・G・A・B♭）の周波数
func _scale(base: float) -> Array:
	var semis := [0, 1, 5, 7, 8]
	var out := []
	for o in 3:
		for s in semis: out.append(base * pow(2.0, (s + 12 * o) / 12.0))
	return out
## 平時：ゆったりした箏の旋律と持続音（72拍/分・16小節）
func _bgmPeace() -> PackedFloat32Array:
	var bpm := 72.0
	var beat := 60.0 / bpm
	var bars := 16
	var out := _buf(bars * 4 * beat)
	var sc := _scale(146.83)   # D3
	# 持続音（D と A、ゆっくり揺れる）
	for i in out.size():
		var t := i / float(SR)
		var sw := 0.5 + 0.5 * sin(TAU * t / (bars * 4 * beat) * 2.0)
		out[i] += (sin(TAU * 73.42 * t) * 0.10 + sin(TAU * 110.0 * t) * 0.06 * sw) * (0.85 + 0.15 * sin(TAU * 0.25 * t))
	# 旋律：4小節ずつの句。句の終わりは長く伸ばす
	var pos := 5
	for bar in bars:
		var rhythm := [[0, 1.0], [1, 0.5], [1.5, 0.5], [2, 1.0], [3, 1.0]] if bar % 4 != 3 else [[0, 1.0], [1, 1.0], [2, 2.0]]
		for r in rhythm:
			if rng.randf() < 0.18 and r[0] > 0: continue
			pos = clamp(pos + rng.randi_range(-2, 2), 3, 11)
			if bar % 4 == 3 and r[0] == 2: pos = 5 if bar % 8 == 7 else 7
			var at := int((bar * 4 + r[0]) * beat * SR)
			_mixLoop(out, _pluck(sc[pos], 3.0, 0.35, 0.996), at, 0.42)
			# 時々、下で和音を添える
			if r[0] == 0 and bar % 2 == 0:
				_mixLoop(out, _pluck(sc[max(0, pos - 5)], 3.0, 0.2, 0.995), at + int(0.03 * SR), 0.22)
	# 句の頭に柔らかい太鼓
	for bar in range(0, bars, 2):
		_mixLoop(out, _taiko(55, 1.2, 0.05), int(bar * 4 * beat * SR), 0.28)
	return out
## 戦時：太鼓の拍子と三味線風の鋭い撥音（100拍/分・16小節）
func _bgmWar() -> PackedFloat32Array:
	var bpm := 100.0
	var beat := 60.0 / bpm
	var bars := 16
	var out := _buf(bars * 4 * beat)
	var sc := _scale(146.83)
	# 太鼓：ドン・ドドン・カッ
	var pat := [[0.0, 60.0, 1.0], [1.5, 75.0, 0.6], [2.0, 60.0, 0.9], [2.5, 60.0, 0.5], [3.0, 90.0, 0.7]]
	for bar in bars:
		for p in pat:
			_mixLoop(out, _taiko(p[1], 0.9, 0.35), int((bar * 4 + p[0]) * beat * SR), 0.5 * p[2])
		if bar % 4 == 3:
			for k in 4: _mixLoop(out, _taiko(110, 0.4, 0.5), int((bar * 4 + 3 + k * 0.25) * beat * SR), 0.3)
	# 撥音の旋律（8分音符の動き、低めの音域）
	var pos := 4
	for bar in bars:
		for e in 8:
			if rng.randf() < 0.35: continue
			pos = clamp(pos + rng.randi_range(-2, 2), 0, 9)
			if e == 0: pos = 0 if bar % 4 == 0 else pos
			_mixLoop(out, _pluck(sc[pos] * 2.0, 0.9, 0.8, 0.985), int((bar * 4 + e * 0.5) * beat * SR), 0.33)
	# 低い持続音
	for i in out.size():
		var t := i / float(SR)
		out[i] += sin(TAU * 73.42 * t) * 0.07 + sin(TAU * 77.78 * t) * 0.03
	return out
