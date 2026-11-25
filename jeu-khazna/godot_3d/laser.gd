# بوّابة ليزر بين جدارين: باعثان معدنيان، أشعّة حمراء تتوهّج وترسم خطّاً على الغبار، وطنين كهربائي.
# الأنماط: static (ثابتة: انحنِ تحتها) · sweep (تصعد وتنزل) · blink (تنطفئ وتشتعل مع إنذار قبلها).
# الحركة تعتمد على «زمن العوائق» المشترك، فيرى المحلّل نفس ما يراه العميل.
extends Node3D

const BODY_LOW := 0.1
const HEAD_STAND := 1.8
const HEAD_CROUCH := 1.12
const HALF_WIDTH := 0.32 # نصف سُمك الجسم عبر خطّ الليزر

var x := 0.0
var z0 := 0.0
var z1 := 0.0
var mode := "static"
var heights: Array = []
var phase := 0.0
var off_t := 0.0 # >0: مقطوع بالقاطع
var _beams: Array = []
var _mat: StandardMaterial3D
var _glow_light: OmniLight3D
var _hum: AudioStreamPlayer3D
var _leds: Array = []
var _cur: Array = [] # الارتفاعات الحالية (فارغة = مطفأ)


func setup(px: float, pz0: float, pz1: float, pmode: String, ph: Array, pphase: float, hum: AudioStream) -> void:
	x = px
	z0 = pz0
	z1 = pz1
	mode = pmode
	heights = ph
	phase = pphase
	position = Vector3(x, 0, (z0 + z1) * 0.5)
	var span := z1 - z0
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1.0, 0.08, 0.05, 0.85)
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.06, 0.03)
	_mat.emission_energy_multiplier = 6.0
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.13, 0.14, 0.15)
	metal.metallic = 0.85
	metal.roughness = 0.35
	for k in heights.size():
		var b := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.009
		cm.bottom_radius = 0.009
		cm.height = span
		cm.radial_segments = 6
		cm.rings = 1
		b.mesh = cm
		b.rotation_degrees.x = 90
		b.material_override = _mat
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(b)
		# هالة ناعمة حول الشعاع
		var halo := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.035
		hm.bottom_radius = 0.035
		hm.height = span
		hm.radial_segments = 8
		hm.rings = 1
		halo.mesh = hm
		var hmat := _mat.duplicate() as StandardMaterial3D
		hmat.albedo_color = Color(1.0, 0.05, 0.02, 0.12)
		hmat.emission_energy_multiplier = 1.5
		halo.material_override = hmat
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.add_child(halo)
		_beams.append(b)
	# الباعثان على الجدارين، بصفّ من الثقوب
	for side in [-1, 1]:
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 2.1, 0.08)
		post.mesh = bm
		post.material_override = metal
		post.position = Vector3(0, 1.05, side * (span * 0.5 - 0.04))
		add_child(post)
		var led := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.022
		lm.height = 0.044
		led.mesh = lm
		led.material_override = _mat
		led.position = Vector3(0.09, 2.0, side * (span * 0.5 - 0.04))
		add_child(led)
		_leds.append(led)
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Color(1.0, 0.1, 0.06)
	_glow_light.light_energy = 0.9
	_glow_light.omni_range = 3.2
	_glow_light.position = Vector3(0, 1.0, 0)
	add_child(_glow_light)
	if hum:
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = hum
		_hum.volume_db = -14.0
		_hum.unit_size = 2.5
		_hum.max_distance = 14.0
		_hum.position = Vector3(0, 1.2, 0)
		add_child(_hum)
		_hum.play()


## الارتفاعات الفعّالة الآن (فارغة إن كان الليزر مطفأ).
func beams_at(t: float) -> Array:
	if off_t > 0.0:
		return []
	var tt := t + phase
	match mode:
		"sweep":
			# ستارة من الأشعّة تمسح صعوداً ونزولاً: انحنِ حين ترتفع، أو امشِ حين تبلغ السقف
			var out := []
			var c := 1.15 + 0.95 * sin(tt * 1.15)
			for k in heights.size():
				out.append(c + (k - (heights.size() - 1) * 0.5) * 0.12)
			return out
		"blink":
			# 2.6 ث مشتعل · 1.8 ث مطفأ
			return heights.duplicate() if fmod(tt, 4.4) < 2.6 else []
	return heights.duplicate()


## يرنّ الإنذار قبل أن يشتعل وضع blink (لتوقيت المرور).
func warning_at(t: float) -> bool:
	if mode != "blink" or off_t > 0.0:
		return false
	var m := fmod(t + phase, 4.4)
	return m > 3.8


func update(t: float, delta: float) -> void:
	off_t = maxf(0.0, off_t - delta)
	_cur = beams_at(t)
	for k in _beams.size():
		var b: MeshInstance3D = _beams[k]
		b.visible = k < _cur.size()
		if b.visible:
			b.position = Vector3(0, float(_cur[k]), 0)
	var flick := 0.85 + 0.15 * sin(t * 47.0) * sin(t * 13.0)
	var warn := warning_at(t)
	_mat.emission_energy_multiplier = 6.0 * flick
	_glow_light.visible = not _cur.is_empty() or warn
	_glow_light.light_energy = (0.9 * flick) if not _cur.is_empty() else (0.5 if fmod(t * 8.0, 1.0) > 0.5 else 0.0)
	for l in _leds:
		(l as Node3D).visible = not _cur.is_empty() or (warn and fmod(t * 8.0, 1.0) > 0.5)
	if _hum:
		_hum.volume_db = -14.0 if not _cur.is_empty() else -60.0


## هل يلمس جسمُ العميل شعاعاً؟ (الجسم أسطوانة: من الكاحل إلى الرأس، والرأس أخفض عند الانحناء)
func hits(p: Vector3, crouch: bool) -> bool:
	if _cur.is_empty():
		return false
	if absf(p.x - x) > HALF_WIDTH or p.z < z0 or p.z > z1:
		return false
	var top := HEAD_CROUCH if crouch else HEAD_STAND
	for h in _cur:
		if float(h) > BODY_LOW and float(h) < top:
			return true
	return false
