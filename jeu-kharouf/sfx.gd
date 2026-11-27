extends Node
## أصوات مولّدة بالكود (باااع، ضربة، حشيش، قفزة) — بلا ملفات صوت.

const RATE := 22050
var streams := {}
var players: Array = []


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	streams["baa"] = _baa(0.55, 1.0)
	streams["baa_long"] = _baa(1.2, 0.8)
	streams["hit"] = _hit()
	streams["blip"] = _sweep(620.0, 1300.0, 0.16, 0.5)
	streams["jump"] = _sweep(280.0, 620.0, 0.14, 0.35)


func play(n: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(n):
		return
	var pick: AudioStreamPlayer = players[0]
	for p in players:
		if not p.playing:
			pick = p
			break
	pick.stream = streams[n]
	pick.volume_db = vol_db
	pick.pitch_scale = pitch
	pick.play()


func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _baa(dur: float, pitch: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := (360.0 - 90.0 * t / dur) * pitch + 22.0 * sin(TAU * 7.0 * t)
		ph += TAU * f / RATE
		var v := sin(ph) + 0.6 * sin(2.0 * ph) + 0.45 * sin(3.0 * ph) + 0.25 * sin(4.0 * ph) + 0.15 * sin(5.0 * ph)
		var env := minf(t / 0.04, 1.0) * clampf((dur - t) / 0.18, 0.0, 1.0)
		var shake := 0.6 + 0.4 * sin(TAU * 11.0 * t)
		s[i] = v * env * shake * 0.22
	return _wav(s)


func _hit() -> AudioStreamWAV:
	var dur := 0.28
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (randf_range(-1.0, 1.0) * exp(-t * 28.0) * 0.55 + sin(TAU * 85.0 * t) * exp(-t * 11.0) * 0.8) * 0.7
	return _wav(s)


func _sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * lerpf(f0, f1, t / dur) / RATE
		s[i] = sin(ph) * minf(t / 0.01, 1.0) * exp(-t * 9.0) * vol
	return _wav(s)
