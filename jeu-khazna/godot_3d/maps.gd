# خرائط المراحل: لكل مرحلة مكانها الحقيقي حول نفس نقاط اللعب
# (البداية 2,6 · لوحة الأرقام 7.4,1.3 · الباب الأول x=8 · لوحة الأسلاك 19.4,8.7 · الباب الثاني x=20 · الخزنة x=30).
#   النهر: رصيف خشبي ليلاً تحت المطر وماء يتموّج ← غرفة مضخّات ← قبو غارق ← الهروب بالقارب.
#   الجبل: ساحة ثلجية بسياج وبرج كشّاف ← غرفة خوادم داخل الجبل ← كهف صخري ← الهروب إلى مهبط المروحية.
extends RefCounted

var m # المشهد الرئيسي (main.gd)
var _water_sh: Shader


func _init(main) -> void:
	m = main


# ───────── أدوات ─────────
func _mat(id: String, fallback: StandardMaterial3D, uv: float, tint := Color.WHITE, rough := -1.0, metal := -1.0) -> StandardMaterial3D:
	var fb := fallback.duplicate() as StandardMaterial3D
	if rough >= 0.0:
		fb.roughness = rough
	if metal >= 0.0:
		fb.metallic = metal
	var r: StandardMaterial3D = m._pbr(id, fb, uv, tint)
	if r == fb:
		fb.albedo_color = fb.albedo_color * tint
	return r


func _plain(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = rough
	s.metallic = metal
	return s


func _cyl(pos: Vector3, r: float, h: float, mat: Material, collide := true, rot := Vector3.ZERO, top_r := -1.0) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r if top_r < 0.0 else top_r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = mat
	if not collide:
		mi.position = pos
		mi.rotation_degrees = rot
		m.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	body.add_child(cs)
	body.add_child(mi)
	m.add_child(body)
	return body


## جدار تصادم غير مرئي (حافّة الرصيف، السياج…)
func _invisible(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	m.add_child(body)


func _moon(color: Color, energy: float, pitch: float, yaw: float) -> DirectionalLight3D:
	var d := DirectionalLight3D.new()
	d.light_color = color
	d.light_energy = energy
	d.rotation_degrees = Vector3(pitch, yaw, 0)
	d.shadow_enabled = true
	d.directional_shadow_max_distance = 40.0
	m.add_child(d)
	return d


func _sky(top: Color, horizon: Color, ground: Color) -> void:
	for n in m.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = top
		sm.sky_horizon_color = horizon
		sm.ground_horizon_color = horizon
		sm.ground_bottom_color = ground
		sm.sun_angle_max = 0.0
		sm.sky_energy_multiplier = 1.0
		var sky := Sky.new()
		sky.sky_material = sm
		env.sky = sky
		env.background_mode = Environment.BG_SKY


func _water(center: Vector3, size: Vector2, deep: Color, shallow: Color, wave: float, alpha: float, subdiv: int) -> MeshInstance3D:
	if _water_sh == null:
		_water_sh = Shader.new()
		_water_sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;
uniform vec3 deep : source_color = vec3(0.01, 0.025, 0.03);
uniform vec3 shallow : source_color = vec3(0.05, 0.08, 0.09);
uniform float wave = 0.06;
uniform float alpha = 0.92;
uniform float ripple = 1.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(wp.x * 0.7 + TIME * 1.2) * 0.6 + sin(wp.z * 1.1 - TIME * 0.9) * 0.4) * wave;
}
void fragment() {
	vec2 p = wp.xz;
	float t = TIME;
	vec2 n = vec2(cos(p.x * 1.7 + t * 1.3) + cos(p.y * 2.3 - t), sin(p.y * 1.9 + t * 1.1) + sin(p.x * 2.9 + t * 0.7)) * 0.09;
	// دوائر قطرات المطر
	vec2 g = p * 1.6;
	vec2 cell = floor(g);
	vec2 f = fract(g) - 0.5;
	float rnd = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float ph = fract(t * 0.85 + rnd);
	float r = length(f);
	float ring = sin((r - ph * 0.5) * 42.0) * (1.0 - ph) * smoothstep(0.5, 0.05, r) * ripple;
	n += normalize(f + 0.0001) * ring * 0.3;
	NORMAL_MAP = normalize(vec3(n, 1.0)) * 0.5 + 0.5;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep, shallow, fres);
	ROUGHNESS = 0.04;
	SPECULAR = 0.85;
	ALPHA = alpha;
}
"""
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = subdiv
	pm.subdivide_depth = subdiv
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = _water_sh
	mat.set_shader_parameter("deep", Vector3(deep.r, deep.g, deep.b))
	mat.set_shader_parameter("shallow", Vector3(shallow.r, shallow.g, shallow.b))
	mat.set_shader_parameter("wave", wave)
	mat.set_shader_parameter("alpha", alpha)
	mi.material_override = mat
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(mi)
	return mi


## مطر أو ثلج فوق منطقة خارجية.
func _weather(center: Vector3, extents: Vector3, snow: bool, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = center
	p.amount = amount
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	var q := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if snow:
		p.lifetime = 7.0
		p.preprocess = 7.0
		p.direction = Vector3(1, -0.5, 0.2)
		p.spread = 30.0
		p.initial_velocity_min = 0.4
		p.initial_velocity_max = 1.3
		p.gravity = Vector3(0.6, -0.9, 0.1)
		q.size = Vector2(0.035, 0.035)
		mat.albedo_color = Color(0.95, 0.97, 1.0, 0.9)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	else:
		p.lifetime = 0.75
		p.preprocess = 1.0
		p.direction = Vector3(0.12, -1, 0)
		p.spread = 3.0
		p.initial_velocity_min = 11.0
		p.initial_velocity_max = 14.0
		p.gravity = Vector3(0, -9.8, 0)
		q.size = Vector2(0.012, 0.42)
		mat.albedo_color = Color(0.7, 0.78, 0.85, 0.32)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = mat
	p.mesh = q
	m.add_child(p)
	return p


func _lamp_post(base: Vector3, color: Color, energy: float, flicker := false) -> OmniLight3D:
	var metal := _plain(Color(0.12, 0.13, 0.14), 0.5, 0.7)
	_cyl(base + Vector3(0, 2.25, 0), 0.07, 4.5, metal, true)
	m._box(base + Vector3(0.35, 4.45, 0), Vector3(0.8, 0.08, 0.12), metal, false)
	m._box(base + Vector3(0.65, 4.35, 0), Vector3(0.36, 0.12, 0.24), m._glow(color, 3.0), false)
	var l := OmniLight3D.new()
	l.position = base + Vector3(0.65, 4.0, 0)
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 10.0
	l.omni_attenuation = 1.3
	l.shadow_enabled = true
	m.add_child(l)
	if flicker:
		m.flickers.append(l)
	return l


func _lightning(moon: DirectionalLight3D) -> void:
	var base := moon.light_energy
	var t := Timer.new()
	t.wait_time = 14.0
	t.autostart = true
	m.add_child(t)
	t.timeout.connect(func():
		t.wait_time = randf_range(12.0, 26.0)
		var tw = m.create_tween()
		for k in 2:
			tw.tween_property(moon, "light_energy", 2.6, 0.04)
			tw.tween_property(moon, "light_energy", base, 0.09)
			tw.tween_interval(0.12)
	)


# ═════════ بيانات الخرائط ═════════
## تُستدعى قبل البناء: تضبط نقاط اللعب، الحرّاس، الكاميرات، الألغاز، وغرفة المحلّل لكل خريطة.
func data(theme: String) -> void:
	match theme:
		"river":
			m.SPAWN = Vector3(-7, 0, 4)
			m.spawn_yaw = -PI / 2.0
			m.vault_xf = Transform3D(Basis(), Vector3(0, 0, 15))
			m.term_specs = [[Vector3(10.6, 0, -2.1), 1.0, "لوحة الصمّامات"], [Vector3(18.8, 0, 10.5), 1.0, "جهاز اللاسلكي"]]
			m.door_specs = [[Vector3(8, 0, 10), PI / 2.0, Vector3(0, 0, 1)], [Vector3(20, 0, 20), 0.0, Vector3(1, 0, 0)]]
			m.checkpoints = [Vector3(-7, 0, 4), Vector3(8, 0, 8.4), Vector3(18.6, 0, 20.0)]
			m.guard_routes = [
				[[Vector3(3.6, 0, 0.2), Vector3(11.0, 0, 0.2), Vector3(11.0, 0, 4.8), Vector3(3.6, 0, 4.8)], 1.15, Rect2(2.4, -2.8, 9.4, 8.6)],
				[[Vector3(5.0, 0, 19.8), Vector3(18.5, 0, 19.8), Vector3(18.5, 0, 14.6), Vector3(18.5, 0, 19.8)], 1.2, Rect2(4.2, 14.2, 15.6, 7.6)],
				[[Vector3(22, 0, 23.2), Vector3(27.2, 0, 23.2), Vector3(27.2, 0, 16.6), Vector3(22, 0, 16.6)], 1.0, Rect2(20.5, 15.5, 8.6, 9.0)],
			]
			m.reach_rect = Rect2(-10, -3, 40, 28)
			m.feed_cams = [
				[Vector3(-1.5, 3.4, -2.6), Vector3(5, 0, 6), "كاميرا 1 · الرصيف"],
				[Vector3(4.6, 4.6, 21.4), Vector3(14, 0.5, 13), "كاميرا 2 · المستودع"],
				[Vector3(20.6, 2.9, 15.6), Vector3(28, 0.8, 21), "كاميرا 3 · القبو"],
			]
			m.alarm_spots = [Vector3(7, 3.0, 1.5), Vector3(12, 4.6, 16), Vector3(25, 3.0, 20)]
			m.gate_types = ["valves", "radio"]
			m.analyst_kind = "cabin"
			m.ARCHIVE = Vector3(-24, 0, -14)
			m.analyst_spawn = m.ARCHIVE + Vector3(5, 0, 6.2)
			m.KILL_POS = Vector3(4.3, 0, 12.0)


# ═════════ النهر ═════════
# رصيف ليلي → بيت المضخّات (لغز الصمّامات) → المستودع (حاويات، ممرّان: ليزر أو كاميرا) → غرفة اللاسلكي (مورس)
# → القبو الغارق (الخزنة + قفل زمني) → الهروب بالقارب. المحلّل في غرفة مراقبة على الضفّة المقابلة،
# يرى المكان من النافذة، يقرأ التردّد بالمنظار، ويطفئ أضواءه حين يمرّ كشّاف قارب الدورية.
var _patrol: Node3D
var _patrol_lamp: SpotLight3D
var _patrol_search: Node3D


func river() -> void:
	var planks := _mat("brown_planks_04", m.mat_wood, 2.0, Color(0.55, 0.5, 0.46), 0.3)
	var iron := _mat("corrugated_iron_02", m.mat_steel, 2.5, Color(0.5, 0.55, 0.58), 0.45, 0.55)
	var factory := _mat("factory_wall", m.mat_wall, 3.0, Color(0.62, 0.64, 0.66))
	var basement := _mat("rock_embedded_concrete_wall", m.mat_wall_dark, 2.5, Color(0.5, 0.52, 0.5))
	var rust := _mat("rusty_metal_03", m.mat_rust, 1.5, Color(0.8, 0.75, 0.7))
	var box_mat := _mat("container_side", m.mat_rust, 3.0, Color(0.75, 0.4, 0.3), 0.5, 0.5)
	var box_mat2 := _mat("container_side", m.mat_rust, 3.0, Color(0.3, 0.45, 0.6), 0.5, 0.5)
	var wet = m.mat_floor.duplicate()
	wet.roughness = 0.18
	wet.albedo_color = wet.albedo_color.darkened(0.3)
	m.mat_wall = factory

	_sky(Color(0.01, 0.015, 0.025), Color(0.05, 0.07, 0.09), Color(0.01, 0.01, 0.012))
	var moon := _moon(Color(0.55, 0.65, 0.85), 0.35, -38.0, -60.0)
	_lightning(moon)
	_water(Vector3(0, -0.75, 5), Vector2(110, 110), Color(0.008, 0.02, 0.025), Color(0.06, 0.09, 0.1), 0.07, 0.96, 80)

	# ── الرصيف ──
	m._box(Vector3(-4, -0.1, 3.5), Vector3(12, 0.2, 13), planks)
	m._box(Vector3(11, -0.1, 8), Vector3(18, 0.2, 4), planks)
	m._box(Vector3(16, -0.1, 1.5), Vector3(8, 0.2, 9), planks)
	for e in [[Vector3(-10, 1, 3.5), Vector3(0.2, 2, 13)], [Vector3(5, 1, -3.1), Vector3(30, 2, 0.2)], [Vector3(20.1, 1, 3.5), Vector3(0.2, 2, 13)], [Vector3(-3, 1, 10.1), Vector3(14, 2, 0.2)]]:
		_invisible(e[0], e[1])
	var rail := _plain(Color(0.35, 0.18, 0.1), 0.6, 0.6)
	for z in range(-3, 11, 2):
		_cyl(Vector3(-9.9, 0.55, z), 0.04, 1.1, rail, false)
		_cyl(Vector3(19.9, 0.55, z), 0.04, 1.1, rail, false)
	for x in range(-10, 21, 2):
		_cyl(Vector3(x, 0.55, -2.95), 0.04, 1.1, rail, false)
	for x in range(-10, 4, 2):
		_cyl(Vector3(x, 0.55, 9.95), 0.04, 1.1, rail, false)
	m._box(Vector3(-9.9, 1.05, 3.5), Vector3(0.05, 0.05, 13), rail, false)
	m._box(Vector3(19.9, 1.05, 3.5), Vector3(0.05, 0.05, 13), rail, false)
	m._box(Vector3(5, 1.05, -2.95), Vector3(30, 0.05, 0.05), rail, false)
	m._box(Vector3(-3, 1.05, 9.95), Vector3(14, 0.05, 0.05), rail, false)
	for x in [-10.0, -6.0, -2.0, 2.0, 8.0, 14.0, 20.0]:
		_cyl(Vector3(x, -0.9, -3.0), 0.16, 1.8, rust, false)
	for p in [Vector3(-4.0, 0, 9.0), Vector3(-3.1, 0, 9.0), Vector3(-3.55, 0.9, 9.0), Vector3(0.5, 0, -2.0), Vector3(14.5, 0, -1.5), Vector3(15.4, 0, -1.5), Vector3(17.5, 0, 3.5), Vector3(-6.5, 0, -1.8)]:
		m._box(p + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), m.mat_crate)
	m._prop("Barrel_01", Vector3(-1.0, 0, 8.6))
	m._prop("barrel_03", Vector3(16.8, 0, 7.6), 30)
	m._prop("Barrel_01", Vector3(13.0, 0, 9.0), 70)
	var white := _plain(Color(0.9, 0.9, 0.88), 0.6)
	var orange := _plain(Color(0.95, 0.35, 0.08), 0.6)
	for k in 3:
		var buoy := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.22
		tm.outer_radius = 0.34
		buoy.mesh = tm
		buoy.material_override = orange if k % 2 == 0 else white
		buoy.rotation_degrees = Vector3(0, 0, 90)
		buoy.position = Vector3(-9.82, 0.75, -1.0 + k * 4.5)
		m.add_child(buoy)
	_boat(Vector3(-12.2, -0.55, 4.0), planks, white)
	var bl = m._label3d("🚤 الهروب", Vector3(-9.6, 2.2, 4.0), 44, Color(0.4, 1.0, 0.5))
	bl.rotation_degrees.y = 90
	_lamp_post(Vector3(-9.2, 0, 0.5), Color(1.0, 0.62, 0.25), 2.4)
	_lamp_post(Vector3(-9.2, 0, 8.0), Color(1.0, 0.62, 0.25), 2.0, true)
	_lamp_post(Vector3(13.0, 0, 6.6), Color(1.0, 0.62, 0.25), 1.8)
	_lamp_post(Vector3(19.2, 0, -2.2), Color(1.0, 0.62, 0.25), 1.6, true)
	_weather(Vector3(4.0, 9.0, 3.5), Vector3(15.0, 0.2, 7.5), false, 560)

	# ── بيت المضخّات x 2..12 · z −3..6 (مدخله مفتوح من الغرب) ──
	m._box(Vector3(7, -0.1, 1.5), Vector3(10, 0.2, 9), wet)
	m._box(Vector3(7, 3.35, 1.5), Vector3(10.3, 0.2, 9.3), m.mat_ceil)
	m._box(Vector3(7, 1.6, -3), Vector3(10.3, 3.2, 0.3), iron)
	m._box(Vector3(7, 1.6, 6), Vector3(10.3, 3.2, 0.3), iron)
	m._box(Vector3(12, 1.6, 1.5), Vector3(0.3, 3.2, 9.3), iron)
	m._box(Vector3(2, 1.6, -1.0), Vector3(0.3, 3.2, 4.0), iron)
	m._box(Vector3(2, 1.6, 4.5), Vector3(0.3, 3.2, 3.0), iron)
	m._box(Vector3(2, 2.9, 2.0), Vector3(0.3, 0.6, 2.0), iron)
	# التردّد مكتوب صغيراً على جدار المضخّات المطلّ على غرفة المحلّل (لا يُقرأ إلا بالمنظار)
	var fl = m._label3d("📻 تردّد الليلة\n%.1f" % float(m.puzzle.freq), Vector3(1.82, 2.2, -1.6), 20, Color(1.0, 0.95, 0.8))
	fl.rotation_degrees.y = -90
	var fb := OmniLight3D.new()
	fb.position = Vector3(1.0, 2.6, -1.6)
	fb.light_color = Color(1.0, 0.8, 0.5)
	fb.light_energy = 0.8
	fb.omni_range = 2.5
	m.add_child(fb)
	var tank := _plain(Color(0.24, 0.32, 0.3), 0.45, 0.6)
	var pipe := _plain(Color(0.3, 0.12, 0.08), 0.5, 0.7)
	_cyl(Vector3(7.3, 1.4, 2.5), 0.85, 2.8, tank, true)
	_cyl(Vector3(7.3, 2.9, 2.5), 0.7, 0.12, rust, false)
	# مشعب الصمّامات الأربعة بألوانها فوق اللوحة
	var cols := [Color(0.95, 0.3, 0.25), Color(0.35, 0.55, 1.0), Color(1.0, 0.85, 0.25), Color(0.35, 0.9, 0.45)]
	_cyl(Vector3(10.6, 2.35, -2.6), 0.14, 3.6, pipe, false, Vector3(0, 0, 90))
	for k in 4:
		var wheel := MeshInstance3D.new()
		var wm := TorusMesh.new()
		wm.inner_radius = 0.12
		wm.outer_radius = 0.17
		wheel.mesh = wm
		wheel.material_override = m._glow(cols[k], 0.9)
		wheel.rotation_degrees = Vector3(90, 0, 0)
		wheel.position = Vector3(9.4 + k * 0.8, 2.35, -2.35)
		m.add_child(wheel)
		_cyl(Vector3(9.4 + k * 0.8, 2.9, -2.6), 0.08, 1.0, pipe, false)
	for z in [-2.6, 5.6]:
		_cyl(Vector3(7.0, 3.0, z), 0.13, 10.0, pipe, false, Vector3(0, 0, 90))
	m._lamp(Vector3(5.0, 3.25, 1.5), Color(0.8, 0.95, 0.9), 1.0, true)
	m._lamp(Vector3(10.0, 3.25, 1.5), Color(0.8, 0.95, 0.9), 0.9)
	m._drips(Vector3(4.0, 3.2, 4.5))

	# ── المستودع x 4..20 · z 10..22 ──
	m._box(Vector3(12, -0.1, 16), Vector3(16, 0.2, 12), wet)
	m._box(Vector3(12, 5.1, 16), Vector3(16.3, 0.2, 12.3), m.mat_ceil)
	m._box(Vector3(5.5, 2.5, 10), Vector3(3.3, 5.0, 0.3), iron)
	m._box(Vector3(14.5, 2.5, 10), Vector3(11.3, 5.0, 0.3), iron)
	m._box(Vector3(8, 4.1, 10), Vector3(2.0, 1.8, 0.3), iron)
	m._box(Vector3(4, 2.5, 16), Vector3(0.3, 5.0, 12.3), iron)
	m._box(Vector3(12, 2.5, 22), Vector3(16.3, 5.0, 0.3), iron)
	m._box(Vector3(20, 2.5, 14.5), Vector3(0.3, 5.0, 9.3), iron)
	m._box(Vector3(20, 2.5, 23.5), Vector3(0.3, 5.0, 5.3), iron)
	m._box(Vector3(20, 4.1, 20), Vector3(0.3, 1.8, 2.0), iron)
	var ws = m._label3d("مستودع ٧", Vector3(8, 4.3, 9.82), 54, Color(0.9, 0.85, 0.7))
	ws.rotation_degrees.y = 180
	# صفّ حاويات يقسم المستودع إلى ممرّين
	m._box(Vector3(8.7, 1.3, 16.2), Vector3(5.4, 2.6, 2.4), box_mat)
	m._box(Vector3(14.2, 1.3, 16.2), Vector3(5.6, 2.6, 2.4), box_mat2)
	m._box(Vector3(9.5, 3.9, 16.2), Vector3(5.4, 2.4, 2.4), box_mat2, false)
	m._box(Vector3(5.2, 0.45, 21.2), Vector3(0.9, 0.9, 0.9), m.mat_crate)
	m._box(Vector3(9.0, 0.45, 21.3), Vector3(0.9, 0.9, 0.9), m.mat_crate)
	# غرفة اللاسلكي x 16..20 · z 10..14 (بابها من الشمال)
	m._box(Vector3(16, 1.6, 12), Vector3(0.3, 3.2, 4.3), factory)
	m._box(Vector3(16.65, 1.6, 14), Vector3(1.3, 3.2, 0.3), factory)
	m._box(Vector3(19.35, 1.6, 14), Vector3(1.3, 3.2, 0.3), factory)
	m._box(Vector3(18, 2.9, 14), Vector3(1.4, 0.6, 0.3), factory)
	m._box(Vector3(18, 3.3, 12), Vector3(4.3, 0.2, 4.3), m.mat_ceil)
	var rl = m._label3d("📻 اللاسلكي", Vector3(18, 2.45, 14.17), 30, Color(0.6, 1.0, 0.7))
	var rlight := OmniLight3D.new()
	rlight.position = Vector3(18.0, 2.6, 12.0)
	rlight.light_color = Color(0.4, 1.0, 0.55)
	rlight.light_energy = 0.9
	rlight.omni_range = 4.0
	m.add_child(rlight)
	m.flickers.append(rlight)
	m._lamp(Vector3(8.0, 5.0, 12.5), Color(0.85, 0.9, 0.8), 1.1)
	m._lamp(Vector3(12.5, 5.0, 19.6), Color(0.85, 0.9, 0.8), 1.0, true)
	m._lamp(Vector3(5.0, 5.0, 19.6), Color(0.85, 0.9, 0.8), 0.7)
	var red := OmniLight3D.new()
	red.position = Vector3(19.6, 3.6, 18.0)
	red.light_color = Color(1.0, 0.12, 0.08)
	red.light_energy = 1.4
	red.omni_range = 5.0
	m.add_child(red)
	m._drips(Vector3(11.0, 5.0, 12.5))

	# ── القبو الغارق x 20..30 · z 15..25 ──
	m._box(Vector3(25, -0.1, 20), Vector3(10.3, 0.2, 10.6), wet)
	m._box(Vector3(25, 3.3, 20), Vector3(10.3, 0.2, 10.6), m.mat_ceil)
	m._box(Vector3(25, 1.6, 15), Vector3(10.3, 3.2, 0.3), basement)
	m._box(Vector3(25, 1.6, 25), Vector3(10.3, 3.2, 0.3), basement)
	m._in_vault_frame(func(): m._vault_wall(basement))
	_water(Vector3(25, 0.13, 20), Vector2(9.7, 9.7), Color(0.02, 0.04, 0.04), Color(0.1, 0.13, 0.12), 0.012, 0.78, 40)
	for p in [Vector3(24.5, 0, 18.4), Vector3(24.5, 0, 21.6)]:
		m._box(p + Vector3(0, 1.6, 0), Vector3(0.5, 3.2, 0.5), basement)
	for d in [Vector3(22.5, 3.15, 18.0), Vector3(26.0, 3.15, 22.6), Vector3(28.5, 3.15, 17.2)]:
		m._drips(d)
	m.vault_lamp = m._lamp(Vector3(25.5, 3.2, 20), Color(0.55, 0.75, 1.0), 0.8, true)
	m._probe(Vector3(7, 1.6, 1.5), Vector3(10, 3.2, 9))
	m._probe(Vector3(12, 2.5, 16), Vector3(16, 5, 12))
	m._probe(Vector3(25, 1.6, 20), Vector3(10, 3.2, 10))
	m._dust(Vector3(12, 2.4, 16), Vector3(8, 2.2, 6))

	# ── قارب الدورية: يمرّ في القناة بين الرصيف وغرفة المحلّل ──
	_patrol = Node3D.new()
	m.add_child(_patrol)
	var hull := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(4.2, 0.9, 1.8)
	hull.mesh = hb
	hull.material_override = _plain(Color(0.08, 0.09, 0.1), 0.5, 0.4)
	_patrol.add_child(hull)
	var cab := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	cbm.size = Vector3(1.4, 1.0, 1.3)
	cab.mesh = cbm
	cab.material_override = white
	cab.position = Vector3(-0.6, 0.9, 0)
	_patrol.add_child(cab)
	var search = preload("res://cctv.gd").new()
	_patrol.add_child(search)
	search.setup_search(Vector3(0.9, 1.6, 0), 180.0, 45.0, 7.0)
	search.RANGE = 16.0
	m.cctvs.append(search)
	_patrol_search = search
	_patrol_lamp = SpotLight3D.new()
	_patrol_lamp.position = Vector3(0.9, 1.7, -0.4)
	_patrol_lamp.rotation_degrees = Vector3(-8, 0, 0)
	_patrol_lamp.light_color = Color(1.0, 0.96, 0.85)
	_patrol_lamp.light_energy = 0.0
	_patrol_lamp.spot_range = 14.0
	_patrol_lamp.spot_angle = 22.0
	_patrol.add_child(_patrol_lamp)
	var eng := OmniLight3D.new()
	eng.light_color = Color(1.0, 0.15, 0.1)
	eng.light_energy = 0.7
	eng.omni_range = 3.0
	eng.position = Vector3(-2.0, 1.0, 0)
	_patrol.add_child(eng)


## موضع القارب من «زمن العوائق» (نفسه عند اللاعبَين): ذهاب وإياب كل 70 ثانية.
## lit = كشّافه الجانبي يضيء نافذة المحلّل الآن؛ warn = سيصل خلال ثوانٍ.
func patrol_update(t: float) -> Dictionary:
	if _patrol == null:
		return {}
	var ph := fmod(t + 20.0, 70.0) / 70.0
	var k := ph * 2.0 if ph < 0.5 else 2.0 - ph * 2.0
	var x := lerpf(-34.0, 18.0, k)
	_patrol.position = Vector3(x, -0.5, -4.6)
	_patrol.rotation.y = 0.0 if ph < 0.5 else PI
	_patrol.rotation.z = sin(t * 1.3) * 0.03
	var cx: float = m.ARCHIVE.x + 5.0
	var near := absf(x - cx) < 7.0
	var soon := absf(x - cx) < 15.0 and not near
	# الكشّاف الجانبي يلتفت نحو النافذة (الجنوب) حين يقترب
	_patrol_lamp.light_energy = 7.0 if near else 0.0
	# المصباح الجانبي نحو الجنوب (النافذة) والكشّاف الكبير نحو الشمال (الرصيف) مهما كان اتّجاه القارب
	_patrol_lamp.rotation_degrees.y = 0.0 if ph < 0.5 else 180.0
	if _patrol_search:
		_patrol_search.rotation.y = 0.0 if ph < 0.5 else PI
	return {"lit": near, "warn": soon}


func _boat(at: Vector3, planks: Material, white: Material) -> void:
	var boat := Node3D.new()
	boat.position = at
	m.add_child(boat)
	var hull_mat := _plain(Color(0.12, 0.22, 0.2), 0.5, 0.3)
	var hull := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(1.9, 0.8, 5.0)
	hull.mesh = hb
	hull.material_override = hull_mat
	boat.add_child(hull)
	var bow := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(1.9, 1.4, 0.8)
	bow.mesh = pr
	bow.material_override = hull_mat
	bow.rotation_degrees = Vector3(90, 0, 0)
	bow.position = Vector3(0, 0, -2.9)
	boat.add_child(bow)
	var deck := MeshInstance3D.new()
	var db := BoxMesh.new()
	db.size = Vector3(1.7, 0.05, 4.8)
	deck.mesh = db
	deck.material_override = planks
	deck.position = Vector3(0, 0.42, 0)
	boat.add_child(deck)
	var cabin := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(1.4, 1.0, 1.4)
	cabin.mesh = cb
	cabin.material_override = white
	cabin.position = Vector3(0, 0.95, 0.9)
	boat.add_child(cabin)
	var blight := OmniLight3D.new()
	blight.light_color = Color(0.3, 1.0, 0.4)
	blight.light_energy = 1.2
	blight.omni_range = 3.5
	blight.position = Vector3(0, 1.6, 0.9)
	boat.add_child(blight)
	var tw = m.create_tween().set_loops()
	tw.tween_property(boat, "rotation_degrees:z", 3.0, 2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(boat, "rotation_degrees:z", -3.0, 2.2).set_trans(Tween.TRANS_SINE)
	m._box(Vector3(-10.6, -0.05, at.z), Vector3(1.4, 0.08, 0.8), planks, false)


# ═════════ الجبل ═════════
func mountain() -> void:
	var snow := _mat("snow_02", m.mat_floor, 4.0, Color(0.95, 0.97, 1.0), 0.9)
	var rock := _mat("rock_wall_08", m.mat_wall_dark, 3.0, Color(0.62, 0.64, 0.68))
	var rock_floor := _mat("rock_ground", m.mat_floor, 3.0, Color(0.55, 0.57, 0.6))
	var plate := _mat("metal_plate_02", m.mat_steel, 1.5, Color(0.55, 0.58, 0.62), 0.45, 0.7)
	var bunker := _mat("rusty_painted_metal", m.mat_rust, 2.0, Color(0.7, 0.75, 0.72))
	var concrete = m.mat_wall.duplicate() as StandardMaterial3D
	concrete.albedo_color = concrete.albedo_color * Color(0.8, 0.86, 0.95)
	m.mat_wall = concrete

	_sky(Color(0.03, 0.04, 0.07), Color(0.18, 0.21, 0.27), Color(0.6, 0.63, 0.7))
	_moon(Color(0.7, 0.8, 1.0), 0.55, -32.0, -130.0)

	# ── الساحة الثلجية (المنطقة أ) ──
	m._box(Vector3(0.0, -0.1, 5), Vector3(16.0, 0.2, 22.0), snow) # x -8..8 · z -6..16
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var white := _plain(Color(0.92, 0.94, 0.98), 0.95)
	for i in 14:
		var dm := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.5, 1.1)
		sm.height = sm.radius * 2.0
		dm.mesh = sm
		dm.material_override = white
		dm.scale = Vector3(rng.randf_range(1.4, 2.4), 0.25, rng.randf_range(0.8, 1.4))
		var along := rng.randf_range(-5.5, 13.5)
		dm.position = Vector3(-7.4 if i % 2 == 0 else rng.randf_range(-6.0, 5.0), 0.0, along if i % 2 == 0 else (-5.4 if i % 3 == 0 else 15.4))
		dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.add_child(dm)
	# سياج شبكي بأسلاك شائكة
	var post := _plain(Color(0.22, 0.23, 0.25), 0.5, 0.8)
	var mesh := StandardMaterial3D.new()
	mesh.albedo_color = Color(0.35, 0.37, 0.4, 0.28)
	mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.metallic = 0.7
	for seg in [[Vector3(-8, 0, -6), Vector3(-8, 0, 16)], [Vector3(-8, 0, -6), Vector3(8, 0, -6)], [Vector3(-8, 0, 16), Vector3(8, 0, 16)]]:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var length := a.distance_to(b)
		var n := int(length / 2.5)
		for k in n + 1:
			_cyl(a.lerp(b, float(k) / n) + Vector3(0, 1.4, 0), 0.05, 2.8, post, false)
		var mid := (a + b) * 0.5 + Vector3(0, 1.3, 0)
		var fence := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.02 if a.x == b.x else length, 2.6, length if a.x == b.x else 0.02)
		fence.mesh = fb
		fence.material_override = mesh
		fence.position = mid
		m.add_child(fence)
		_invisible(mid, Vector3(0.3 if a.x == b.x else length, 3.0, length if a.x == b.x else 0.3))
		m._box(mid + Vector3(0, 1.45, 0), Vector3(0.03 if a.x == b.x else length, 0.03, length if a.x == b.x else 0.03), post, false)
	# مهبط المروحية عند نقطة البداية (مخرج الهروب)
	var pad := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 2.6
	pc.bottom_radius = 2.6
	pc.height = 0.04
	pad.mesh = pc
	pad.material_override = _plain(Color(0.08, 0.09, 0.1), 0.7)
	pad.position = Vector3(2.0, 0.02, 6.0)
	m.add_child(pad)
	var yel = m._glow(Color(1.0, 0.8, 0.15), 1.2)
	m._box(Vector3(1.4, 0.045, 6.0), Vector3(0.22, 0.01, 2.0), yel, false)
	m._box(Vector3(2.6, 0.045, 6.0), Vector3(0.22, 0.01, 2.0), yel, false)
	m._box(Vector3(2.0, 0.045, 6.0), Vector3(1.2, 0.01, 0.22), yel, false)
	for k in 8:
		var a2 := k * TAU / 8.0
		m._box(Vector3(2.0 + cos(a2) * 2.5, 0.06, 6.0 + sin(a2) * 2.5), Vector3(0.12, 0.08, 0.12), m._glow(Color(0.3, 1.0, 0.4), 3.0), false)
	var pl := OmniLight3D.new()
	pl.position = Vector3(2.0, 0.6, 6.0)
	pl.light_color = Color(0.35, 1.0, 0.45)
	pl.light_energy = 0.8
	pl.omni_range = 4.0
	m.add_child(pl)
	m.flickers.append(pl)
	# زلّاجة ثلج وبراميل
	var sled := _plain(Color(0.6, 0.08, 0.06), 0.45, 0.4)
	m._box(Vector3(5.0, 0.45, 12.5), Vector3(0.9, 0.5, 2.0), sled)
	m._box(Vector3(5.0, 0.85, 12.8), Vector3(0.7, 0.3, 0.9), _plain(Color(0.08, 0.08, 0.08), 0.6))
	for sx in [-0.38, 0.38]:
		m._box(Vector3(5.0 + sx, 0.06, 12.5), Vector3(0.08, 0.06, 2.4), post, false)
	m._prop("Barrel_01", Vector3(-6.5, 0, 12.8))
	m._prop("barrel_03", Vector3(-5.8, 0, 13.4), 50)
	for p in [Vector3(5.6, 0, 9.6), Vector3(6.5, 0, 9.6), Vector3(-1.5, 0, -1.0)]:
		m._box(p + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), m.mat_crate)
	# برج الحراسة بكشّافه الدوّار (عائق جديد في الخارج)
	var tower := Vector3(-5.5, 0, -3.5)
	for dx in [-0.9, 0.9]:
		for dz in [-0.9, 0.9]:
			_cyl(tower + Vector3(dx, 3.0, dz), 0.1, 6.0, post, true)
	m._box(tower + Vector3(0, 6.05, 0), Vector3(2.4, 0.15, 2.4), plate, false)
	m._box(tower + Vector3(0, 6.6, 1.15), Vector3(2.4, 1.0, 0.06), post, false)
	m._box(tower + Vector3(-1.15, 6.6, 0), Vector3(0.06, 1.0, 2.4), post, false)
	m._box(tower + Vector3(0, 7.6, 0), Vector3(2.8, 0.12, 2.8), bunker, false)
	var search = preload("res://cctv.gd").new()
	m.add_child(search)
	search.setup_search(tower + Vector3(0.6, 6.9, 0.6), -135.0, 32.0, 11.0)
	m.cctvs.append(search)
	_weather(Vector3(0.0, 9.0, 5.0), Vector3(8.5, 0.3, 11.5), true, 420)

	# ── وجه الجبل والمخبأ على x=8 ──
	m._box(Vector3(8.2, 4.5, -3.25), Vector3(0.7, 9.0, 5.5), rock)
	m._box(Vector3(8.2, 4.5, 13.25), Vector3(0.7, 9.0, 5.5), rock)
	m._box(Vector3(8, 1.6, 1.75), Vector3(0.3, 3.2, 3.5), concrete)
	m._box(Vector3(8, 1.6, 7.75), Vector3(0.3, 3.2, 4.5), concrete)
	m._box(Vector3(8.2, 6.1, 5.0), Vector3(0.7, 5.8, 10.0), rock)
	# صخور بارزة من الجبل (بعيداً عن الباب واللوحة)
	for i in 10:
		var z := rng.randf_range(-5.5, -0.8) if i % 2 == 0 else rng.randf_range(10.2, 15.5)
		var r = m._box(Vector3(rng.randf_range(7.2, 7.7), rng.randf_range(0.4, 6.5), z), Vector3(rng.randf_range(0.8, 1.6), rng.randf_range(0.8, 2.0), rng.randf_range(1.0, 2.2)), rock, false)
		r.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.4, 0.4))
	# إطار باب المخبأ الخرساني بخطوط تحذير
	var hz = m._glow(Color(0.95, 0.75, 0.1), 0.5)
	m._box(Vector3(7.75, 1.7, 3.3), Vector3(0.3, 3.4, 0.35), concrete)
	m._box(Vector3(7.75, 1.7, 5.7), Vector3(0.3, 3.4, 0.35), concrete)
	m._box(Vector3(7.75, 3.45, 4.5), Vector3(0.3, 0.35, 2.75), concrete)
	m._box(Vector3(7.58, 3.45, 4.5), Vector3(0.02, 0.12, 2.5), hz, false)
	var bl = m._label3d("مخبأ B-7 · ممنوع الدخول", Vector3(7.55, 4.1, 4.5), 40, Color(0.95, 0.85, 0.6))
	bl.rotation_degrees.y = -90
	var flood := SpotLight3D.new()
	m.add_child(flood)
	flood.look_at_from_position(Vector3(6.5, 4.6, 4.5), Vector3(4.0, 0.0, 4.5))
	flood.light_color = Color(1.0, 0.75, 0.45)
	flood.light_energy = 3.0
	flood.spot_range = 9.0
	flood.spot_angle = 40.0
	flood.shadow_enabled = true

	# ── غرفة الخوادم داخل الجبل (المنطقة ب) ──
	m._box(Vector3(14.0, -0.1, 5), Vector3(12.3, 0.2, 10.6), plate)
	m._box(Vector3(14.0, WALL_H() + 0.1, 5), Vector3(12.3, 0.2, 10.6), m.mat_ceil)
	m._wall_x(0, 8, 20, concrete)
	m._wall_x(10, 8, 20, concrete)
	m._wall_z(20, 0, 4, concrete)
	m._wall_z(20, 6, 10, concrete)
	var rack := _plain(Color(0.06, 0.065, 0.07), 0.4, 0.7)
	var led_cols := [Color(0.2, 0.6, 1.0), Color(0.3, 1.0, 0.4), Color(1.0, 0.6, 0.15)]
	for row in [2.6, 7.4]:
		for k in 5:
			var x := 10.9 + k * 0.72
			m._box(Vector3(x, 1.0, row), Vector3(0.66, 2.0, 1.0), rack)
			var face: float = row + (0.51 if row < 5.0 else -0.51)
			for j in 6:
				m._box(Vector3(x - 0.2 + (j % 2) * 0.4, 0.4 + j * 0.27, face), Vector3(0.05, 0.03, 0.01), m._glow(led_cols[(k + j) % 3], 4.0), false)
	for row in [2.6, 7.4]:
		var gl := OmniLight3D.new()
		gl.position = Vector3(12.3, 1.2, row + (0.9 if row < 5.0 else -0.9))
		gl.light_color = Color(0.3, 0.6, 1.0)
		gl.light_energy = 0.6
		gl.omni_range = 3.0
		m.add_child(gl)
	m._box(Vector3(14.0, 3.0, 5.0), Vector3(10.0, 0.06, 0.4), post, false)
	m._prop("power_box_01", Vector3(19.75, 1.1, 2.6), -90, false)
	m._prop("korean_fire_extinguisher_01", Vector3(8.5, 0, 9.4), 0, false)
	m._lamp(Vector3(11.0, WALL_H(), 5), Color(0.82, 0.9, 1.0), 1.1)
	m._lamp(Vector3(17.0, WALL_H(), 5), Color(0.82, 0.9, 1.0), 1.0, true)

	# ── الكهف الصخري (المنطقة ج) ──
	m._box(Vector3(25.0, -0.1, 5), Vector3(10.3, 0.2, 10.6), rock_floor)
	m._box(Vector3(25.0, WALL_H() + 0.1, 5), Vector3(10.3, 0.2, 10.6), rock)
	m._box(Vector3(25.0, WALL_H() / 2.0, 0), Vector3(10.3, WALL_H(), 0.3), rock)
	m._box(Vector3(25.0, WALL_H() / 2.0, 10), Vector3(10.3, WALL_H(), 0.3), rock)
	m._vault_wall(rock)
	# جدران غير منتظمة: كتل صخرية بارزة قليلاً (لا تسدّ طريق الحرّاس)
	for i in 14:
		var zz := 0.3 if i % 2 == 0 else 9.7
		var c := Vector3(20.8 + (i / 2) * 1.3 + rng.randf_range(-0.3, 0.3), rng.randf_range(0.4, 2.8), zz)
		var b = m._box(c, Vector3(rng.randf_range(0.9, 1.6), rng.randf_range(0.7, 1.4), 0.5), rock, false)
		b.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.3))
	# هوابط صخرية وجليد يتوهّج
	var ice = m._glow(Color(0.5, 0.85, 1.0), 0.9)
	for i in 16:
		var p := Vector3(rng.randf_range(20.6, 29.4), WALL_H() - 0.25, rng.randf_range(0.6, 9.4))
		_cyl(p, rng.randf_range(0.08, 0.18), rng.randf_range(0.35, 0.75), rock, false, Vector3(180, 0, 0), 0.01)
		if i % 3 == 0:
			_cyl(Vector3(p.x, 0.25, clampf(p.z, 0.7, 9.3) if absf(p.z - 5.0) > 2.0 else 0.7), 0.1, 0.5, ice, false, Vector3.ZERO, 0.01)
	m.vault_lamp = m._lamp(Vector3(25.5, WALL_H(), 5), Color(0.55, 0.8, 1.0), 0.9, true)
	for tp in [Vector3(21.0, 0, 1.0), Vector3(28.8, 0, 9.0)]:
		var lamp := SpotLight3D.new()
		m.add_child(lamp)
		lamp.look_at_from_position(tp + Vector3(0, 1.8, 0), Vector3(25.0, 0.5, 5.0))
		lamp.light_color = Color(1.0, 0.7, 0.4)
		lamp.light_energy = 2.2
		lamp.spot_range = 10.0
		lamp.spot_angle = 35.0
		_cyl(tp + Vector3(0, 0.9, 0), 0.03, 1.8, post, false)
		m._box(tp + Vector3(0, 1.85, 0), Vector3(0.3, 0.2, 0.2), m._glow(Color(1.0, 0.8, 0.5), 2.0), false)
	m._probe(Vector3(14, 1.6, 5), Vector3(12, WALL_H(), 10.5))
	m._probe(Vector3(25, 1.6, 5), Vector3(10, WALL_H(), 10.5))
	m._dust(Vector3(19, 1.6, 5), Vector3(11, 1.5, 5))


func WALL_H() -> float:
	return 3.2
