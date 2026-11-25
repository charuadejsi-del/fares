# نموذج «الخزنة 3D»: مبنى من ثلاث غرف في الميناء ليلاً.
# اخترق جهاز كل غرفة ليُفتح الباب، تجنّب الحارس ومصباحه، افتح الخزنة ثم اهرب إلى نقطة البداية قبل انتهاء الإنذار.
# كل المشهد يُبنى بالكود (لا مشاهد معقّدة) كي يسهل تطويره.
extends Node3D

const WALL_H := 3.2
const SPAWN := Vector3(2.0, 0.0, 6.0)
const ESCAPE_SECONDS := 45.0

var player
var hud
var guards: Array = []
var terminals: Array = [] # {pos, door, light, screen, done}
var doors: Array = []
var stage := 0
var hacking := -1.0
var seen_time := 0.0
var invuln := 0.0
var escape_left := -1.0
var finished := false
var alarm_lights: Array = []
var marker: MeshInstance3D
var flicker: OmniLight3D

var mat_wall: StandardMaterial3D
var mat_floor: StandardMaterial3D
var mat_ceil: StandardMaterial3D
var mat_crate: StandardMaterial3D
var mat_steel: StandardMaterial3D
var mat_dark: StandardMaterial3D


func _ready() -> void:
	_materials()
	_environment()
	_build_level()
	_spawn_player()
	_spawn_guards()
	hud = preload("res://hud.gd").new()
	hud.player = player
	add_child(hud)
	hud.hack_pressed.connect(_on_hack)
	hud.set_objective("اخترق الجهاز المضيء لفتح الباب")


# ───────── المواد ─────────
func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _noise_normal(freq: float, strength: float) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 5
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = strength
	t.noise = n
	return t


func _materials() -> void:
	mat_wall = StandardMaterial3D.new()
	mat_wall.albedo_texture = _tex("res://textures/wall_port.jpg")
	mat_wall.uv1_triplanar = true
	mat_wall.uv1_world_triplanar = true
	mat_wall.uv1_scale = Vector3.ONE / WALL_H
	mat_wall.roughness = 0.88
	mat_wall.normal_enabled = true
	mat_wall.normal_texture = _noise_normal(0.03, 3.0)
	mat_wall.normal_scale = 0.6

	# أرضية خرسانية مبلّلة: خشونة منخفضة لتعكس الأضواء
	mat_floor = StandardMaterial3D.new()
	mat_floor.albedo_texture = _tex("res://textures/floor_port.jpg")
	mat_floor.albedo_color = Color(0.55, 0.58, 0.62)
	mat_floor.uv1_triplanar = true
	mat_floor.uv1_world_triplanar = true
	mat_floor.uv1_scale = Vector3.ONE / 2.5
	mat_floor.roughness = 0.28
	mat_floor.metallic = 0.15
	mat_floor.normal_enabled = true
	mat_floor.normal_texture = _noise_normal(0.05, 5.0)
	mat_floor.normal_scale = 0.35

	mat_ceil = StandardMaterial3D.new()
	mat_ceil.albedo_color = Color(0.09, 0.1, 0.11)
	mat_ceil.roughness = 1.0

	mat_crate = StandardMaterial3D.new()
	mat_crate.albedo_color = Color(0.42, 0.29, 0.16)
	mat_crate.roughness = 0.8
	mat_crate.normal_enabled = true
	mat_crate.normal_texture = _noise_normal(0.12, 6.0)

	mat_steel = StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.42, 0.45, 0.49)
	mat_steel.metallic = 0.85
	mat_steel.roughness = 0.32
	mat_steel.normal_enabled = true
	mat_steel.normal_texture = _noise_normal(0.2, 1.5)

	mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.05, 0.055, 0.06)
	mat_dark.metallic = 0.6
	mat_dark.roughness = 0.4


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.013)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.38, 0.48)
	env.ambient_light_energy = 0.18
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.05, 0.065)
	env.fog_density = 0.045
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.92
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ───────── البناء ─────────
func _box(center: Vector3, size: Vector3, mat: Material, collide := true) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	if not collide:
		mi.position = center
		add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = center
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.add_child(mi)
	add_child(body)
	return body


func _wall_x(z: float, x0: float, x1: float) -> void:
	_box(Vector3((x0 + x1) / 2.0, WALL_H / 2.0, z), Vector3(x1 - x0 + 0.3, WALL_H, 0.3), mat_wall)


func _wall_z(x: float, z0: float, z1: float) -> void:
	_box(Vector3(x, WALL_H / 2.0, (z0 + z1) / 2.0), Vector3(0.3, WALL_H, z1 - z0 + 0.3), mat_wall)


func _lamp(pos: Vector3, color := Color(1.0, 0.86, 0.62)) -> OmniLight3D:
	_box(pos + Vector3(0, -0.03, 0), Vector3(1.2, 0.06, 0.25), _glow(color, 3.0), false)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, -0.35, 0)
	l.light_color = color
	l.light_energy = 1.3
	l.omni_range = 7.5
	l.omni_attenuation = 1.4
	add_child(l)
	return l


func _build_level() -> void:
	# الأرضية والسقف
	_box(Vector3(15, -0.1, 5), Vector3(30.6, 0.2, 10.6), mat_floor)
	_box(Vector3(15, WALL_H + 0.1, 5), Vector3(30.6, 0.2, 10.6), mat_ceil)
	# الغرفة 1 (البداية): x 0..8، z 0..8
	_wall_x(0, 0, 8)
	_wall_x(8, 0, 8)
	_wall_z(0, 0, 8)
	# الجدار المشترك x=8 بفتحة باب z 3.5..5.5
	_wall_z(8, 0, 3.5)
	_wall_z(8, 5.5, 10)
	# الغرفة 2: x 8..20، z 0..10
	_wall_x(0, 8, 20)
	_wall_x(10, 8, 20)
	_wall_z(20, 0, 4)
	_wall_z(20, 6, 10)
	# الغرفة 3 (الخزنة): x 20..30
	_wall_x(0, 20, 30)
	_wall_x(10, 20, 30)
	_wall_z(30, 0, 10)
	# حشو خلف الغرفة الأولى (z 8..10) حتى لا تظهر فجوة
	_box(Vector3(4, WALL_H / 2.0, 9.15), Vector3(8.3, WALL_H, 1.9), mat_wall)

	# الأبواب الفولاذية
	doors.append(_door(Vector3(8, 0, 4.5)))
	doors.append(_door(Vector3(20, 0, 5)))

	# الصناديق (مخابئ)
	for p in [Vector3(11, 0, 2), Vector3(11.9, 0, 2), Vector3(11.45, 0.9, 2), Vector3(16, 0, 7.5), Vector3(14, 0, 4.8), Vector3(24, 0, 2.5), Vector3(4.5, 0, 1.2)]:
		_box(p + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), mat_crate)

	# الأجهزة
	terminals.append(_terminal(Vector3(7.4, 0, 1.3), 0))
	terminals.append(_terminal(Vector3(19.4, 0, 8.7), 1))
	terminals.append(_terminal(Vector3(28.6, 0, 8.6), -1))

	# باب الخزنة الدائري على الجدار الأخير
	var vault := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 1.2
	cyl.height = 0.3
	vault.mesh = cyl
	vault.material_override = mat_steel
	vault.position = Vector3(29.7, 1.4, 5)
	vault.rotation_degrees = Vector3(0, 0, 90)
	add_child(vault)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.15
	tor.outer_radius = 1.28
	ring.mesh = tor
	ring.material_override = _glow(Color(1.0, 0.62, 0.2), 2.0)
	ring.position = Vector3(29.52, 1.4, 5)
	ring.rotation_degrees = Vector3(0, 0, 90)
	add_child(ring)

	# الإضاءة: مصابيح سقف، واحد يرتعش في غرفة الحارس
	_lamp(Vector3(4, WALL_H, 4))
	flicker = _lamp(Vector3(14, WALL_H, 5))
	_lamp(Vector3(25, WALL_H, 5), Color(0.75, 0.85, 1.0))

	# مجسّات الانعكاس: الأرضية المبلّلة تعكس الأضواء
	for c in [Vector3(4, 1.6, 4), Vector3(14, 1.6, 5), Vector3(25, 1.6, 5)]:
		var rp := ReflectionProbe.new()
		rp.position = c
		rp.size = Vector3(12, WALL_H, 10.5)
		rp.box_projection = true
		rp.update_mode = ReflectionProbe.UPDATE_ONCE
		rp.intensity = 0.8
		add_child(rp)

	# علامة الهدف العائمة
	marker = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.22, 0.3, 0.22)
	marker.mesh = pm
	marker.material_override = _glow(Color(1.0, 0.63, 0.23), 4.0)
	marker.rotation_degrees.x = 180
	add_child(marker)

	# غبار يتطاير في الهواء
	var dust := CPUParticles3D.new()
	dust.amount = 220
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(15, 1.5, 5)
	dust.position = Vector3(15, 1.6, 5)
	dust.direction = Vector3(0.3, 0.1, 0.2)
	dust.spread = 180
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 0.02
	dust.initial_velocity_max = 0.08
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.018)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(1, 0.95, 0.85, 0.35)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = dm
	dust.mesh = q
	add_child(dust)


func _door(base: Vector3) -> Dictionary:
	var body := _box(base + Vector3(0, WALL_H / 2.0, 0), Vector3(0.22, WALL_H, 2.05), mat_steel)
	var stripe := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.08, 2.0)
	stripe.mesh = bm
	stripe.material_override = _glow(Color(0.95, 0.25, 0.25), 2.5)
	stripe.position = Vector3(0, 0, 0)
	body.add_child(stripe)
	return {"body": body, "stripe": stripe}


func _terminal(pos: Vector3, door_index: int) -> Dictionary:
	var root := _box(pos + Vector3(0, 0.75, 0), Vector3(0.6, 1.5, 0.45), mat_dark)
	var screen := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.44, 0.3)
	screen.mesh = qm
	screen.material_override = _glow(Color(1.0, 0.63, 0.23), 3.0)
	# الشاشة على الوجه المقابل لمركز الغرفة
	var face := Vector3(0, 0.35, 0.231) if pos.z < 5 else Vector3(0, 0.35, -0.231)
	screen.position = face
	if pos.z >= 5:
		screen.rotation_degrees.y = 180
	root.add_child(screen)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.63, 0.23)
	l.light_energy = 1.2
	l.omni_range = 2.6
	l.position = face * 1.8
	root.add_child(l)
	return {"pos": pos, "door": door_index, "light": l, "screen": screen, "done": false}


func _spawn_player() -> void:
	player = preload("res://player.gd").new()
	player.position = SPAWN
	add_child(player)
	player.yaw = -PI / 2.0
	player.rotation.y = player.yaw


func _spawn_guards() -> void:
	var g = preload("res://guard.gd").new()
	add_child(g)
	g.setup([Vector3(9.5, 0, 8.6), Vector3(18.5, 0, 8.6), Vector3(18.5, 0, 1.3), Vector3(9.5, 0, 1.3)], 1.25)
	guards.append(g)
	var g2 = preload("res://guard.gd").new()
	add_child(g2)
	g2.setup([Vector3(22, 0, 5), Vector3(27.5, 0, 5)], 1.0)
	guards.append(g2)


# ───────── اللعب ─────────
func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if flicker:
		flicker.light_energy = 1.3 if fmod(t, 3.7) > 0.25 or fmod(t * 13.0, 1.0) > 0.5 else 0.15
	if finished:
		return

	# الهدف الحالي
	var goal := SPAWN if escape_left >= 0.0 else (terminals[stage].pos as Vector3)
	marker.position = goal + Vector3(0, 2.1 + 0.08 * sin(t * 3.0), 0)
	marker.rotation.y = t * 1.5

	# الحارس يراك؟
	invuln = max(0.0, invuln - delta)
	var space := get_world_3d().direct_space_state
	var seen := false
	for g in guards:
		if g.sees(player, space):
			seen = true
	if seen and invuln <= 0.0:
		seen_time += delta * (2.0 if hacking >= 0.0 else 1.0)
		if seen_time > 0.55:
			_spotted()
	else:
		seen_time = max(0.0, seen_time - delta * 2.0)
	hud.set_alert(seen_time / 0.55)

	# الاختراق: ثلاث ثوانٍ عند الجهاز (والحارس يواصل دورته)
	var near: bool = escape_left < 0.0 and player.global_position.distance_to(terminals[stage].pos) < 1.7
	if hacking >= 0.0:
		if not near:
			hacking = -1.0
			hud.set_progress(-1.0)
		else:
			hacking += delta
			hud.set_progress(hacking / 3.0)
			if hacking >= 3.0:
				_hacked()
	hud.show_hack(near and hacking < 0.0)

	# الهروب
	if escape_left >= 0.0:
		escape_left -= delta
		hud.set_timer(escape_left)
		for i in alarm_lights.size():
			var a: SpotLight3D = alarm_lights[i]
			a.rotation.y = t * 4.0 + i * PI
		if player.global_position.distance_to(SPAWN) < 1.4:
			_finish(true)
		elif escape_left <= 0.0:
			_finish(false)


func _on_hack() -> void:
	if hacking < 0.0:
		hacking = 0.0


func _hacked() -> void:
	hacking = -1.0
	hud.set_progress(-1.0)
	var term: Dictionary = terminals[stage]
	term.done = true
	(term.light as OmniLight3D).light_color = Color(0.42, 0.85, 0.58)
	(term.screen as MeshInstance3D).material_override = _glow(Color(0.42, 0.85, 0.58), 3.0)
	if term.door >= 0:
		var d: Dictionary = doors[term.door]
		(d.stripe as MeshInstance3D).material_override = _glow(Color(0.42, 0.85, 0.58), 2.5)
		var tw := create_tween()
		tw.tween_property(d.body, "position:y", WALL_H * 1.5, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		stage += 1
		hud.flash("🔓 فُتح الباب", Color(0.42, 0.85, 0.58))
		hud.set_objective("الجهاز التالي في الغرفة المجاورة" if stage == 1 else "افتح الخزنة في الغرفة الأخيرة")
	else:
		_start_escape()


func _start_escape() -> void:
	escape_left = ESCAPE_SECONDS
	hud.flash("🚨 الخزنة مفتوحة — الإنذار!", Color(0.9, 0.28, 0.3))
	hud.set_objective("اهرب إلى نقطة البداية قبل انتهاء الوقت!")
	for g in guards:
		g.speed *= 1.6
		g.alarm = true
	# أضواء إنذار حمراء دوّارة في كل غرفة
	for c in [Vector3(4, WALL_H - 0.2, 4), Vector3(14, WALL_H - 0.2, 5), Vector3(25, WALL_H - 0.2, 5)]:
		for k in 2:
			var s := SpotLight3D.new()
			s.position = c
			s.light_color = Color(1.0, 0.1, 0.08)
			s.light_energy = 6.0
			s.spot_range = 12.0
			s.spot_angle = 22.0
			s.rotation_degrees.x = -25
			add_child(s)
			alarm_lights.append(s)


func _spotted() -> void:
	seen_time = 0.0
	invuln = 2.5
	hud.flash("👁 رآك الحارس!", Color(0.9, 0.28, 0.3))
	hud.hit()
	hacking = -1.0
	hud.set_progress(-1.0)
	if escape_left >= 0.0:
		escape_left = max(1.0, escape_left - 8.0)
		return
	# العودة إلى مدخل الغرفة الحالية
	var back := SPAWN if stage == 0 else (Vector3(9.2, 0, 4.5) if stage == 1 else Vector3(21.2, 0, 5))
	player.global_position = back


func _finish(won: bool) -> void:
	finished = true
	hud.show_hack(false)
	hud.set_progress(-1.0)
	hud.end_screen(won)
