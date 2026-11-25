# «الخزنة 3D» — لعب تعاوني بين هاتفين.
# العميل يتسلّل في مبنى الميناء (ثلاث غرف + حجرة الكنز)، والمحلّل في غرفة أرشيف مظلمة بعيدة:
# يرى العميل والحرّاس على شاشات المراقبة، ويجد نصف كل حلّ في الأدراج والدليل والحاسوب.
# العميل يملك تقدّم المهمّة ويرسله؛ المحلّل يعكسه. الحرّاس يتحرّكون محلياً عند الاثنين.
extends Node3D

const WALL_H := 3.2
const SPAWN := Vector3(2.0, 0.0, 6.0)
const ARCHIVE := Vector3(100.0, 0.0, 0.0) # ركن غرفة المحلّل
const ESCAPE_SECONDS := 50.0
const MISSION_SECONDS := 720.0
const SYMBOLS := ["▲", "●", "■", "★", "◆", "✚"]
const WIRES := [
	["أحمر", Color(0.85, 0.15, 0.15)], ["أزرق", Color(0.2, 0.42, 0.95)], ["أصفر", Color(0.95, 0.8, 0.15)],
	["أخضر", Color(0.2, 0.72, 0.3)], ["أبيض", Color(0.92, 0.92, 0.92)],
]
const VAULT_FRONT := Vector3(29.0, 0.0, 5.0)

var role := "solo" # agent | analyst | solo
var net
var hud
var menu
var agent # اللاعب داخل المبنى
var analyst # اللاعب في غرفة الأرشيف
var active
var avatar: Node3D
var font3d: Font
var guards: Array = []
var doors: Array = []
var terminals: Array = []
var feeds: Array = []
var puzzle := {}
var host_role := ""
var started := false
var seed_value := 0

# التقدّم (يملكه العميل)
var stage := 0 # 0 لوحة الأرقام · 1 الأسلاك · 2 الخزنة · 3 الهروب
var escape_left := -1.0
var mission_left := MISSION_SECONDS
var result := ""
var _applied_stage := 0

var seen_time := 0.0
var invuln := 0.0
var lockout := 0.0
var vault_mode := false
var dial_angle := 0.0
var dial_number := 0
var dial_entered: Array = []
var _cam_saved: Transform3D
var _partner_seen := -100.0
var _send_t := 0.0
var _prog_t := 0.0
var _ping_t := 0.0

var vault_pivot: Node3D
var vault_dial: Node3D
var vault_wheel: Node3D
var drawer: Node3D
var drawer_open := false
var book_node: Node3D
var pc_node: Node3D
var marker: MeshInstance3D
var flickers: Array = []
var alarm_lights: Array = []
var vault_bolts: Array = []
var hint_light: OmniLight3D
var hint_arrow: MeshInstance3D
var _seer = null
# الأصوات
var s_amb: AudioStreamPlayer
var s_heart: AudioStreamPlayer
var s_steps: AudioStreamPlayer
var s_alarm: AudioStreamPlayer
var s_click: AudioStreamPlayer
var s_door: AudioStreamPlayer3D
var s_vault: AudioStreamPlayer3D

var mat_wall: StandardMaterial3D
var mat_wall_dark: StandardMaterial3D
var mat_floor: StandardMaterial3D
var mat_ceil: StandardMaterial3D
var mat_crate: StandardMaterial3D
var mat_rust: StandardMaterial3D
var mat_steel: StandardMaterial3D
var mat_dark: StandardMaterial3D
var mat_wood: StandardMaterial3D


func _ready() -> void:
	if ResourceLoader.exists("res://fonts/Tajawal-Bold.ttf"):
		font3d = load("res://fonts/Tajawal-Bold.ttf")
	menu = preload("res://menu.gd").new()
	add_child(menu)
	menu.solo.connect(func(): _start("solo", randi() % 1000000))
	menu.host.connect(_host)
	menu.join.connect(_join)
	# اختبار التشغيل في GitHub: يبدأ الوضع الفردي مباشرة ويجرّب الألغاز
	if OS.get_environment("KHAZNA_SMOKE") == "1":
		_start("solo", 1234)
		_smoke.call_deferred()


func _smoke() -> void:
	await get_tree().create_timer(0.5).timeout
	_submit_code(str(puzzle.code))
	_cut_wire(str(WIRES[int(puzzle.answer)][0]))
	print("SMOKE stage after puzzles: ", stage)
	_on_switch()
	analyst.set_meta("looking", drawer)
	_analyst_interact()
	_analyst_interact()
	print("SMOKE symbols: ", _check_symbols(puzzle.symbols.duplicate()))
	hud.close_panel()
	_on_switch()
	_enter_vault()
	for n in puzzle.combo:
		dial_number = int(n)
		_record_number()
	await get_tree().create_timer(2.0).timeout
	print("SMOKE final stage: ", stage, " escape: ", escape_left)
	get_tree().quit()


# ───────── الشبكة ─────────
func _net() -> void:
	net = preload("res://net.gd").new()
	add_child(net)
	net.message.connect(_on_msg)
	net.status.connect(_on_status)


func _on_status(t: String) -> void:
	if hud:
		hud.set_status(t)
	elif menu:
		menu.show_info(t, Color(0.6, 0.64, 0.68))


func _host(r: String) -> void:
	host_role = r
	seed_value = randi() % 1000000
	var code := str(randi_range(1000, 9999))
	_net()
	net.open(code)
	menu.waiting(code, r)


func _join(code: String) -> void:
	_net()
	net.open(code)
	menu.show_info("جارٍ الانضمام إلى الغرفة %s…" % code)


func _on_msg(m: Dictionary) -> void:
	_partner_seen = Time.get_ticks_msec() / 1000.0
	var t := str(m.get("t", ""))
	if t == "join" and host_role != "":
		net.send({"t": "hello", "role": host_role, "seed": seed_value})
		if not started:
			_start(host_role, seed_value)
	elif t == "hello" and host_role == "" and not started:
		var r := "analyst" if str(m.get("role", "")) == "agent" else "agent"
		_start(r, int(m.get("seed", 0)))
	elif t == "pos" and avatar:
		avatar.set_meta("target", Vector3(float(m.get("x", 0)), 0, float(m.get("z", 0))))
		avatar.set_meta("yaw", float(m.get("y", 0)))
	elif t == "prog" and role == "analyst":
		stage = int(m.get("stage", 0))
		escape_left = float(m.get("esc", -1))
		mission_left = float(m.get("left", mission_left))
		var res := str(m.get("res", ""))
		_apply_stage()
		if res != "" and result == "":
			_finish(res == "win")


func _send_prog() -> void:
	if net and role == "agent":
		net.send({"t": "prog", "stage": stage, "esc": escape_left, "left": mission_left, "res": result})


# ───────── البداية ─────────
func _start(r: String, s: int) -> void:
	started = true
	role = r
	seed_value = s
	puzzle = _make_puzzle(s)
	if menu:
		menu.queue_free()
		menu = null
	_materials()
	_realistic()
	_environment()
	_build_building()
	_build_archive()
	_props()
	_spawn_guards()
	_sounds()
	_hints()
	hud = preload("res://hud.gd").new()
	add_child(hud)
	hud.interact_pressed.connect(_on_interact)
	hud.switch_pressed.connect(_on_switch)
	hud.set_switch_visible(role == "solo")
	if role != "analyst":
		agent = _make_player(SPAWN, -PI / 2.0)
	if role != "agent":
		analyst = _make_player(ARCHIVE + Vector3(5, 0, 6.2), 0.0)
		avatar = _make_avatar()
		_build_feeds()
	_set_active(analyst if role == "analyst" else agent)
	hud.set_status("وضع فردي" if net == null else "")
	_intro()


func _intro() -> void:
	var a := "أنت العميل داخل مخزن الميناء.\n\n١. اتبع السهم البرتقالي إلى الجهاز، وابتعد عن ضوء مصابيح الحرّاس.\n٢. الرموز والأجوبة ليست عندك: هي عند شريكك المحلّل. صِف له ما تراه واسأله.\n٣. افتح الخزنة، ثم اهرب إلى نقطة البداية قبل انتهاء الإنذار."
	var b := "أنت المحلّل في غرفة الأرشيف.\n\n١. راقب العميل والحرّاس على شاشات المراقبة.\n٢. الشيء المضيء والسهم فوقه = ما تبحث فيه الآن (درج، دليل، حاسوب).\n٣. انظر إليه واضغط الزر، ثم أخبر العميل بما وجدت."
	if role == "agent":
		hud.open_text("مهمّتك", a)
	elif role == "analyst":
		hud.open_text("مهمّتك", b)
	else:
		hud.open_text("وضع التجربة", a + "\n\n(زر 👁 أعلى الشاشة يبدّلك إلى المحلّل)")


func _hints() -> void:
	hint_light = OmniLight3D.new()
	hint_light.light_color = Color(1.0, 0.63, 0.23)
	hint_light.omni_range = 1.6
	add_child(hint_light)
	hint_arrow = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.16, 0.22, 0.16)
	hint_arrow.mesh = pm
	hint_arrow.material_override = _glow(Color(1.0, 0.63, 0.23), 4.0)
	hint_arrow.rotation_degrees.x = 180
	add_child(hint_arrow)


func _make_player(at: Vector3, yaw: float):
	var p = preload("res://player.gd").new()
	p.position = at
	add_child(p)
	p.yaw = yaw
	p.rotation.y = yaw
	return p


func _set_active(p) -> void:
	for q in [agent, analyst]:
		if q:
			q.set_active(q == p)
	active = p
	hud.player = p
	hud.release_touches()
	hud.close_panel()
	_update_objective()


func _on_switch() -> void:
	if vault_mode:
		_exit_vault()
	_set_active(analyst if active == agent else agent)


# ───────── اللغز (مشترك بالبذرة) ─────────
func _make_puzzle(s: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = s
	var code := str(r.randi_range(1000, 9999))
	var digit := r.randi_range(0, 9)
	var serial := "KZ-%d%d%d" % [r.randi_range(1, 9), r.randi_range(0, 9), digit]
	var table := []
	for i in 10:
		table.append(r.randi_range(0, WIRES.size() - 1))
	var answer: int = table[digit]
	var order := []
	for i in WIRES.size():
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var wires := [answer]
	for w in order:
		if wires.size() < 4 and w != answer:
			wires.append(w)
	for i in range(wires.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = wires[i]
		wires[i] = wires[j]
		wires[j] = tmp
	var syms := []
	while syms.size() < 3:
		var k: String = SYMBOLS[r.randi_range(0, SYMBOLS.size() - 1)]
		if not syms.has(k):
			syms.append(k)
	var combo := [r.randi_range(1, 39), r.randi_range(1, 39), r.randi_range(1, 39)]
	return {"code": code, "serial": serial, "table": table, "answer": answer, "wires": wires, "symbols": syms, "combo": combo}


# ───────── المواد والجوّ ─────────
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


func _noise_tex(freq: float, a: Color, b: Color) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 4
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	t.color_ramp = g
	return t


func _materials() -> void:
	# جدران خرسانية قديمة ومتّسخة (أغمق من الأصل لجوّ مخيف)
	mat_wall = StandardMaterial3D.new()
	mat_wall.albedo_texture = _tex("res://textures/wall_port.jpg")
	mat_wall.albedo_color = Color(0.62, 0.64, 0.66)
	mat_wall.uv1_triplanar = true
	mat_wall.uv1_world_triplanar = true
	mat_wall.uv1_scale = Vector3.ONE / WALL_H
	mat_wall.roughness = 0.9
	mat_wall.normal_enabled = true
	mat_wall.normal_texture = _noise_normal(0.03, 4.0)
	mat_wall.normal_scale = 0.8

	mat_wall_dark = mat_wall.duplicate()
	mat_wall_dark.albedo_color = Color(0.38, 0.36, 0.34)

	mat_floor = StandardMaterial3D.new()
	mat_floor.albedo_texture = _noise_tex(0.02, Color(0.09, 0.095, 0.1), Color(0.24, 0.24, 0.23))
	mat_floor.uv1_triplanar = true
	mat_floor.uv1_world_triplanar = true
	mat_floor.uv1_scale = Vector3.ONE / 6.0
	mat_floor.roughness = 0.25
	mat_floor.metallic = 0.2
	mat_floor.normal_enabled = true
	mat_floor.normal_texture = _noise_normal(0.05, 5.0)
	mat_floor.normal_scale = 0.4

	mat_ceil = StandardMaterial3D.new()
	mat_ceil.albedo_color = Color(0.07, 0.075, 0.08)
	mat_ceil.roughness = 1.0

	mat_crate = StandardMaterial3D.new()
	mat_crate.albedo_texture = _noise_tex(0.08, Color(0.25, 0.16, 0.08), Color(0.46, 0.32, 0.18))
	mat_crate.roughness = 0.85
	mat_crate.normal_enabled = true
	mat_crate.normal_texture = _noise_normal(0.12, 6.0)

	# حديد صدئ للأبواب
	mat_rust = StandardMaterial3D.new()
	mat_rust.albedo_texture = _noise_tex(0.06, Color(0.2, 0.1, 0.05), Color(0.48, 0.3, 0.18))
	mat_rust.uv1_triplanar = true
	mat_rust.uv1_world_triplanar = true
	mat_rust.metallic = 0.55
	mat_rust.roughness = 0.75
	mat_rust.normal_enabled = true
	mat_rust.normal_texture = _noise_normal(0.15, 5.0)

	mat_steel = StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.34, 0.36, 0.39)
	mat_steel.metallic = 0.9
	mat_steel.roughness = 0.38
	mat_steel.normal_enabled = true
	mat_steel.normal_texture = _noise_normal(0.25, 2.5)

	mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.05, 0.055, 0.06)
	mat_dark.metallic = 0.6
	mat_dark.roughness = 0.4

	mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_texture = _noise_tex(0.05, Color(0.16, 0.1, 0.06), Color(0.3, 0.2, 0.12))
	mat_wood.uv1_triplanar = true
	mat_wood.roughness = 0.7


func _pbr(id: String, fb: StandardMaterial3D, uv: float, tint := Color.WHITE) -> StandardMaterial3D:
	var d := "res://ph/tex/%s_diff.jpg" % id
	if not ResourceLoader.exists(d):
		return fb
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(d)
	m.albedo_color = tint
	var n := "res://ph/tex/%s_nor_gl.jpg" % id
	if ResourceLoader.exists(n):
		m.normal_enabled = true
		m.normal_texture = load(n)
	var r := "res://ph/tex/%s_rough.jpg" % id
	if ResourceLoader.exists(r):
		m.roughness_texture = load(r)
	m.roughness = fb.roughness
	m.metallic = fb.metallic
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / uv
	return m


func _realistic() -> void:
	mat_wall = _pbr("concrete_wall_008", mat_wall, 3.0, Color(0.78, 0.78, 0.8))
	mat_wall_dark = _pbr("concrete_wall_005", mat_wall_dark, 3.0, Color(0.5, 0.48, 0.46))
	mat_floor = _pbr("damaged_concrete_floor_02", mat_floor, 3.0, Color(0.75, 0.76, 0.78))
	mat_floor.roughness = 0.55 # مبلّلة قليلاً
	mat_ceil = _pbr("concrete_floor_01", mat_ceil, 3.0, Color(0.3, 0.3, 0.32))
	mat_rust = _pbr("rusty_metal_shutter", mat_rust, 2.0)
	mat_steel = _pbr("metal_plate", mat_steel, 1.2, Color(0.75, 0.78, 0.82))
	mat_steel.metallic = 0.85
	mat_wood = _pbr("old_wooden_floor_02", mat_wood, 2.0, Color(0.8, 0.75, 0.7))
	mat_crate = _pbr("rusty_metal_02", mat_crate, 1.0)


## نموذج Poly Haven: قاعدته على الأرض ومركزه في [pos]، مع جسم تصادم اختياري.
func _prop(id: String, pos: Vector3, rot := 0.0, collide := true) -> Node3D:
	var p := "res://ph/models/%s/%s.gltf" % [id, id]
	if not ResourceLoader.exists(p):
		return null
	var scn = load(p)
	if not scn is PackedScene:
		return null
	var n := (scn as PackedScene).instantiate() as Node3D
	if n == null:
		return null
	add_child(n)
	n.rotation_degrees.y = rot
	n.global_position = pos
	var box := _aabb(n)
	if box.size == Vector3.ZERO:
		return n
	var c := box.get_center()
	n.global_position += Vector3(pos.x - c.x, pos.y - box.position.y, pos.z - c.z)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = box.size
		cs.shape = sh
		body.add_child(cs)
		add_child(body)
		body.global_position = Vector3(pos.x, pos.y + box.size.y / 2.0, pos.z)
	return n


func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _props() -> void:
	# المبنى: براميل وصناديق ورفوف وكاميرات حقيقية وطفّاية حريق
	_prop("Barrel_01", Vector3(15.6, 0, 1.0))
	_prop("Barrel_01", Vector3(16.4, 0, 1.25), 40)
	_prop("barrel_03", Vector3(26.6, 0, 9.2))
	_prop("cardboard_box_01", Vector3(5.6, 0, 7.4))
	_prop("cardboard_box_01", Vector3(6.3, 0, 7.5), 25)
	_prop("cardboard_box_01", Vector3(17.6, 0, 9.4), -15)
	_prop("steel_frame_shelves_01", Vector3(12.5, 0, 9.45))
	_prop("steel_frame_shelves_01", Vector3(2.6, 0, 0.55), 180)
	_prop("korean_fire_extinguisher_01", Vector3(7.6, 0, 7.6))
	_prop("metal_trash_can", Vector3(9.0, 0, 0.6))
	_prop("power_box_01", Vector3(19.75, 1.1, 2.6), -90, false)
	for c in [Vector3(0.6, 2.7, 0.6), Vector3(8.6, 2.7, 9.4), Vector3(20.6, 2.7, 0.6)]:
		_prop("security_camera_01", c, 0, false)
	for l in [Vector3(4, 2.75, 4), Vector3(14, 2.75, 5), Vector3(25, 2.75, 5), ARCHIVE + Vector3(5, 2.75, 5)]:
		_prop("caged_hanging_light", l, 0, false)
	# الأرشيف
	_prop("modern_arm_chair_01", ARCHIVE + Vector3(5, 0, 2.4), 180)
	_prop("wooden_bookshelf_worn", ARCHIVE + Vector3(0.6, 0, 7.0), 90)
	_prop("vintage_cabinet_01", ARCHIVE + Vector3(8.6, 0, 7.4), 180)
	_prop("vintage_wooden_drawer_01", ARCHIVE + Vector3(9.3, 0, 2.2), -90)


# ───────── الأصوات ─────────
func _snd(sound_name: String, loop := false, db := 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(sound_name, loop)
	p.volume_db = db
	add_child(p)
	return p


func _snd3d(sound_name: String, at: Vector3, db := 0.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(sound_name, false)
	p.volume_db = db
	p.unit_size = 6.0
	p.max_distance = 40.0
	add_child(p)
	p.global_position = at
	return p


func _stream(sound_name: String, loop: bool) -> AudioStream:
	var path_s := "res://sounds/%s.mp3" % sound_name
	if not ResourceLoader.exists(path_s):
		return null
	var st = load(path_s)
	if st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = loop
	return st


func _sounds() -> void:
	s_amb = _snd("ambience", true, -8.0)
	if s_amb.stream:
		s_amb.play()
	s_heart = _snd("heartbeat", true, -40.0)
	s_steps = _snd("steps", true, -10.0)
	s_alarm = _snd("alarm", true, -6.0)
	s_click = _snd("click", false, -4.0)
	s_door = _snd3d("door", Vector3(8, 1.5, 4.5), 2.0)
	s_vault = _snd3d("vault_open", Vector3(29.6, 1.5, 5), 4.0)


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
	env.background_color = Color(0.004, 0.005, 0.007)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.36, 0.46)
	env.ambient_light_energy = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.15
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.035, 0.045)
	env.fog_density = 0.06
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ───────── أدوات البناء ─────────
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


func _wall_x(z: float, x0: float, x1: float, mat: Material = null) -> void:
	_box(Vector3((x0 + x1) / 2.0, WALL_H / 2.0, z), Vector3(x1 - x0 + 0.3, WALL_H, 0.3), mat if mat else mat_wall)


func _wall_z(x: float, z0: float, z1: float, mat: Material = null) -> void:
	_box(Vector3(x, WALL_H / 2.0, (z0 + z1) / 2.0), Vector3(0.3, WALL_H, z1 - z0 + 0.3), mat if mat else mat_wall)


func _lamp(pos: Vector3, color: Color, energy: float, flicker := false) -> OmniLight3D:
	_box(pos + Vector3(0, -0.03, 0), Vector3(1.1, 0.06, 0.22), _glow(color, 2.5), false)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, -0.35, 0)
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 7.0
	l.omni_attenuation = 1.5
	add_child(l)
	if flicker:
		flickers.append(l)
	return l


func _label3d(text: String, at: Vector3, size: int, color: Color, parent: Node3D = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 0
	l.position = at
	if font3d:
		l.font = font3d
	if parent:
		parent.add_child(l)
	else:
		add_child(l)
	return l


# ───────── مبنى العميل ─────────
func _build_building() -> void:
	_box(Vector3(16.5, -0.1, 5), Vector3(33.6, 0.2, 10.6), mat_floor)
	_box(Vector3(16.5, WALL_H + 0.1, 5), Vector3(33.6, 0.2, 10.6), mat_ceil)
	# الغرفة 1 (البداية): x 0..8، z 0..8
	_wall_x(0, 0, 8)
	_wall_x(8, 0, 8)
	_wall_z(0, 0, 8)
	_wall_z(8, 0, 3.5)
	_wall_z(8, 5.5, 10)
	_box(Vector3(4, WALL_H / 2.0, 9.15), Vector3(8.3, WALL_H, 1.9), mat_wall)
	# الغرفة 2: x 8..20
	_wall_x(0, 8, 20)
	_wall_x(10, 8, 20)
	_wall_z(20, 0, 4)
	_wall_z(20, 6, 10)
	# الغرفة 3 (قاعة الخزنة): x 20..30، وفتحة الخزنة z 3.6..6.4
	_wall_x(0, 20, 30)
	_wall_x(10, 20, 30)
	_wall_z(30, 0, 3.6)
	_wall_z(30, 6.4, 10)
	_box(Vector3(30, 2.95, 5), Vector3(0.3, 0.5, 2.8), mat_wall)
	# حجرة الكنز خلف الباب: x 30..33
	_wall_x(3.4, 30, 33.3, mat_steel)
	_wall_x(6.6, 30, 33.3, mat_steel)
	_wall_z(33.3, 3.4, 6.6, mat_steel)
	for i in 6:
		var gold := _box(Vector3(31.4 + (i % 3) * 0.45, 0.08 + float(i / 3) * 0.16, 4.85 + (i % 2) * 0.3), Vector3(0.4, 0.15, 0.22), _glow(Color(1.0, 0.75, 0.25), 1.6), false)
		gold.rotation.y = 0.05 * i
	var treasure := OmniLight3D.new()
	treasure.position = Vector3(31.8, 1.2, 5)
	treasure.light_color = Color(1.0, 0.78, 0.35)
	treasure.light_energy = 2.5
	treasure.omni_range = 4.0
	add_child(treasure)

	doors.append(_door(Vector3(8, 0, 4.5)))
	doors.append(_door(Vector3(20, 0, 5)))

	for p in [Vector3(11, 0, 2), Vector3(11.9, 0, 2), Vector3(11.45, 0.9, 2), Vector3(16, 0, 7.5), Vector3(14, 0, 4.8), Vector3(23.5, 0, 2.2), Vector3(4.5, 0, 1.2), Vector3(24.4, 0, 2.2)]:
		_box(p + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), mat_crate)

	terminals.append(_terminal(Vector3(7.4, 0, 1.3), "لوحة الأرقام"))
	terminals.append(_terminal(Vector3(19.4, 0, 8.7), "لوحة الأسلاك"))

	_build_vault()

	# إضاءة مخيفة: مصباح خافت، مصابيح ترتعش، ومصباح طوارئ أحمر
	_lamp(Vector3(4, WALL_H, 4), Color(1.0, 0.82, 0.58), 1.0)
	_lamp(Vector3(14, WALL_H, 5), Color(1.0, 0.86, 0.62), 1.2, true)
	_lamp(Vector3(25, WALL_H, 5), Color(0.6, 0.75, 1.0), 0.8, true)
	var red := OmniLight3D.new()
	red.position = Vector3(19.6, 2.6, 1.0)
	red.light_color = Color(1.0, 0.12, 0.08)
	red.light_energy = 1.4
	red.omni_range = 5.0
	add_child(red)
	_box(Vector3(19.8, 2.6, 1.0), Vector3(0.12, 0.18, 0.18), _glow(Color(1.0, 0.15, 0.1), 3.0), false)

	for c in [Vector3(4, 1.6, 4), Vector3(14, 1.6, 5), Vector3(25, 1.6, 5)]:
		var rp := ReflectionProbe.new()
		rp.position = c
		rp.size = Vector3(12, WALL_H, 10.5)
		rp.box_projection = true
		rp.update_mode = ReflectionProbe.UPDATE_ONCE
		rp.intensity = 0.7
		add_child(rp)

	marker = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.22, 0.3, 0.22)
	marker.mesh = pm
	marker.material_override = _glow(Color(1.0, 0.63, 0.23), 4.0)
	marker.rotation_degrees.x = 180
	add_child(marker)

	_dust(Vector3(15, 1.6, 5), Vector3(15, 1.5, 5))


func _dust(center: Vector3, extents: Vector3) -> void:
	var dust := CPUParticles3D.new()
	dust.amount = 200
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = extents
	dust.position = center
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
	dm.albedo_color = Color(1, 0.95, 0.85, 0.3)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = dm
	dust.mesh = q
	add_child(dust)


func _door(base: Vector3) -> Dictionary:
	var body := _box(base + Vector3(0, WALL_H / 2.0, 0), Vector3(0.22, WALL_H, 2.05), mat_rust)
	var stripe := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.07, 2.0)
	stripe.mesh = bm
	stripe.material_override = _glow(Color(0.95, 0.2, 0.2), 2.5)
	body.add_child(stripe)
	return {"body": body, "stripe": stripe, "open": false}


func _terminal(pos: Vector3, title: String) -> Dictionary:
	var root := _box(pos + Vector3(0, 0.75, 0), Vector3(0.6, 1.5, 0.45), mat_dark)
	var screen := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.44, 0.3)
	screen.mesh = qm
	screen.material_override = _glow(Color(1.0, 0.63, 0.23), 3.0)
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
	return {"pos": pos, "light": l, "screen": screen, "title": title}


func _build_vault() -> void:
	# إطار فولاذي سميك بفتحة دائرية (CSG)
	var frame := CSGCombiner3D.new()
	frame.use_collision = true
	frame.position = Vector3(29.9, 1.5, 5)
	add_child(frame)
	var plate := CSGBox3D.new()
	plate.size = Vector3(0.55, 3.0, 3.0)
	plate.material = mat_steel
	frame.add_child(plate)
	var hole := CSGCylinder3D.new()
	hole.radius = 1.16
	hole.height = 1.0
	hole.sides = 48
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.rotation_degrees.z = 90
	frame.add_child(hole)
	# براغي الإطار
	for i in 16:
		var a := i * TAU / 16.0
		var b := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.045
		cm.bottom_radius = 0.05
		cm.height = 0.06
		b.mesh = cm
		b.material_override = mat_steel
		b.rotation_degrees.z = 90
		b.position = Vector3(29.6, 1.5 + cos(a) * 1.36, 5 + sin(a) * 1.36)
		add_child(b)
	# المفصلات
	for y in [0.75, 2.25]:
		var h := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.09
		hm.bottom_radius = 0.09
		hm.height = 0.45
		h.mesh = hm
		h.material_override = mat_steel
		h.position = Vector3(29.55, y, 3.8)
		add_child(h)

	vault_pivot = Node3D.new()
	vault_pivot.position = Vector3(29.62, 1.5, 3.84)
	add_child(vault_pivot)
	var door := StaticBody3D.new()
	door.position = Vector3(0, 0, 1.16)
	vault_pivot.add_child(door)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.12
	shape.height = 0.42
	cs.shape = shape
	cs.rotation_degrees.z = 90
	door.add_child(cs)
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.12
	cyl.bottom_radius = 1.12
	cyl.height = 0.42
	cyl.radial_segments = 64
	body.mesh = cyl
	body.material_override = mat_steel
	body.rotation_degrees.z = 90
	door.add_child(body)
	var face := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.92
	fm.bottom_radius = 0.95
	fm.height = 0.05
	fm.radial_segments = 64
	face.mesh = fm
	face.material_override = mat_steel
	face.rotation_degrees.z = 90
	face.position = Vector3(-0.23, 0, 0)
	door.add_child(face)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.97
	tor.outer_radius = 1.03
	ring.mesh = tor
	ring.material_override = _glow(Color(0.85, 0.5, 0.15), 0.9)
	ring.position = Vector3(-0.22, 0, 0)
	ring.rotation_degrees = Vector3(0, 0, 90)
	door.add_child(ring)
	# أقفال الباب (تنسحب عند الفتح)
	for i in 10:
		var a := i * TAU / 10.0
		var bolt := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.06
		bm.bottom_radius = 0.06
		bm.height = 0.3
		bolt.mesh = bm
		bolt.material_override = mat_steel
		bolt.rotation.x = a
		bolt.position = Vector3(0, cos(a) * 1.18, sin(a) * 1.18)
		door.add_child(bolt)
		vault_bolts.append([bolt, a])
	# الرموز المنقوشة (العميل يصفها للمحلّل)
	var syms := "   ".join(PackedStringArray(puzzle.symbols))
	var sl := _label3d(syms, Vector3(-0.27, 0.68, 0), 110, Color(1.0, 0.75, 0.35), door)
	sl.rotation_degrees.y = -90
	# القرص المحفور: 40 تدريجة وأرقام كل 5
	vault_dial = Node3D.new()
	vault_dial.position = Vector3(-0.27, 0.2, 0)
	door.add_child(vault_dial)
	var dial := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.28
	dm.bottom_radius = 0.31
	dm.height = 0.09
	dm.radial_segments = 48
	dial.mesh = dm
	dial.material_override = mat_dark
	dial.rotation_degrees = Vector3(0, 0, 90)
	vault_dial.add_child(dial)
	for n in 40:
		var a := n * TAU / 40.0
		var tick := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.01, 0.05 if n % 5 == 0 else 0.025, 0.008)
		tick.mesh = tm
		tick.material_override = _glow(Color(0.85, 0.85, 0.8), 0.6)
		tick.rotation.x = a
		tick.position = Vector3(-0.05, cos(a) * 0.255, sin(a) * 0.255)
		vault_dial.add_child(tick)
		if n % 5 == 0:
			var num := _label3d(str(n), Vector3(-0.05, cos(a) * 0.19, sin(a) * 0.19), 34, Color(0.92, 0.92, 0.88), vault_dial)
			num.rotation_degrees.y = -90
	var knob := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = 0.07
	km.bottom_radius = 0.09
	km.height = 0.12
	knob.mesh = km
	knob.material_override = mat_steel
	knob.rotation_degrees.z = 90
	knob.position = Vector3(-0.08, 0, 0)
	vault_dial.add_child(knob)
	var mark := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(0.02, 0.07, 0.03)
	mark.mesh = mb
	mark.material_override = _glow(Color(1.0, 0.2, 0.15), 3.0)
	mark.position = Vector3(-0.27, 0.55, 0)
	door.add_child(mark)
	# المقبض الدوّار بأربع أذرع ومقابض كروية
	vault_wheel = Node3D.new()
	vault_wheel.position = Vector3(-0.3, -0.42, 0)
	door.add_child(vault_wheel)
	var hub := MeshInstance3D.new()
	var hm2 := CylinderMesh.new()
	hm2.top_radius = 0.1
	hm2.bottom_radius = 0.12
	hm2.height = 0.14
	hub.mesh = hm2
	hub.material_override = mat_steel
	hub.rotation_degrees.z = 90
	vault_wheel.add_child(hub)
	for k in 4:
		var a := k * PI / 2.0
		var spoke := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.025
		sm.bottom_radius = 0.03
		sm.height = 0.36
		spoke.mesh = sm
		spoke.material_override = mat_steel
		spoke.rotation.x = a
		spoke.position = Vector3(0, cos(a) * 0.18, sin(a) * 0.18)
		vault_wheel.add_child(spoke)
		var ball := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.045
		sp.height = 0.09
		ball.mesh = sp
		ball.material_override = mat_dark
		ball.position = Vector3(0, cos(a) * 0.37, sin(a) * 0.37)
		vault_wheel.add_child(ball)
	var light := SpotLight3D.new()
	add_child(light)
	light.look_at_from_position(Vector3(26.5, 3.0, 5), Vector3(29.8, 1.3, 5))
	light.light_color = Color(0.8, 0.88, 1.0)
	light.light_energy = 3.0
	light.spot_angle = 28
	light.spot_range = 8
	light.shadow_enabled = true


func _spawn_guards() -> void:
	var g = preload("res://guard.gd").new()
	add_child(g)
	g.setup([Vector3(9.5, 0, 8.6), Vector3(18.5, 0, 8.6), Vector3(18.5, 0, 1.3), Vector3(9.5, 0, 1.3)], 1.25)
	guards.append(g)
	var g2 = preload("res://guard.gd").new()
	add_child(g2)
	g2.setup([Vector3(22, 0, 8.2), Vector3(27.2, 0, 8.2), Vector3(27.2, 0, 1.6), Vector3(22, 0, 1.6)], 1.0)
	guards.append(g2)


func _make_avatar() -> Node3D:
	var a := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.75
	body.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.1, 0.12)
	m.roughness = 0.6
	body.material_override = m
	body.position.y = 0.88
	body.layers = 2
	a.add_child(body)
	if agent == null:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(0.15, 1.4, -0.3)
		lamp.light_color = Color(1.0, 0.94, 0.82)
		lamp.light_energy = 2.5
		lamp.spot_range = 9.0
		lamp.spot_angle = 25.0
		a.add_child(lamp)
	a.position = SPAWN
	add_child(a)
	return a


# ───────── غرفة المحلّل (الأرشيف) ─────────
func _build_archive() -> void:
	var o := ARCHIVE
	_box(o + Vector3(5, -0.1, 4), Vector3(10.6, 0.2, 8.6), mat_wood)
	_box(o + Vector3(5, WALL_H + 0.1, 4), Vector3(10.6, 0.2, 8.6), mat_ceil)
	_wall_x(o.z + 0, o.x, o.x + 10, mat_wall_dark)
	_wall_x(o.z + 8, o.x, o.x + 10, mat_wall_dark)
	_wall_z(o.x + 0, o.z, o.z + 8, mat_wall_dark)
	_wall_z(o.x + 10, o.z, o.z + 8, mat_wall_dark)
	# المكتب أمام جدار الشاشات
	_box(o + Vector3(5, 0.76, 1.15), Vector3(6.2, 0.07, 1.1), mat_wood)
	for x in [2.1, 7.9]:
		_box(o + Vector3(x, 0.38, 1.15), Vector3(0.08, 0.76, 1.0), mat_wood, false)
	# الحاسوب
	var pc := _box(o + Vector3(5, 1.05, 1.0), Vector3(0.7, 0.48, 0.08), mat_dark)
	pc.set_meta("kind", "computer")
	pc_node = pc
	var scr := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.62, 0.4)
	scr.mesh = q
	scr.material_override = _glow(Color(0.2, 0.6, 0.32), 1.6)
	scr.position = Vector3(0, 0, 0.045)
	pc.add_child(scr)
	_label3d("> ARCHIVE_", o + Vector3(5, 1.08, 1.06), 28, Color(0.75, 1.0, 0.8))
	# دليل الأسلاك (كتاب أحمر)
	var book := _box(o + Vector3(3.2, 0.83, 1.3), Vector3(0.38, 0.07, 0.5), _glow(Color(0.45, 0.06, 0.05), 0.4))
	book.set_meta("kind", "book")
	book_node = book
	var bl := _label3d("دليل الأسلاك", o + Vector3(3.2, 0.875, 1.3), 24, Color(1.0, 0.9, 0.8))
	bl.rotation_degrees.x = -90
	# خزانة الأدراج: الدرج العلوي يُفتح وفيه ورقة
	_box(o + Vector3(9.4, 0.6, 4.5), Vector3(0.7, 1.2, 0.9), mat_crate)
	drawer = _box(o + Vector3(9.1, 1.0, 4.5), Vector3(0.12, 0.3, 0.8), mat_steel)
	drawer.set_meta("kind", "drawer")
	var sheet := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(0.5, 0.35)
	sheet.mesh = sq
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.88, 0.84, 0.72)
	sheet.material_override = pm
	sheet.rotation_degrees = Vector3(-90, 90, 0)
	sheet.position = Vector3(-0.35, 0.16, 0)
	sheet.visible = false
	sheet.name = "Sheet"
	drawer.add_child(sheet)
	var paper := _label3d("رمز باب المخزن\n" + str(puzzle.code), Vector3(-0.35, 0.17, 0), 34, Color(0.15, 0.12, 0.08), drawer)
	paper.rotation_degrees = Vector3(-90, 90, 0)
	paper.visible = false
	paper.name = "Paper"
	# لوحة «مطلوبون» على الجدار الغربي
	_box(o + Vector3(0.2, 1.7, 4), Vector3(0.05, 1.3, 2.2), mat_wood, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 7:
		var c := Color(0.75, 0.72, 0.66) if i % 2 == 0 else Color(0.5, 0.48, 0.45)
		var ph := _box(o + Vector3(0.24, 1.25 + rng.randf() * 0.9, 3.1 + rng.randf() * 1.8), Vector3(0.02, 0.22, 0.18), _glow(c, 0.15), false)
		ph.rotation.x = rng.randf_range(-0.2, 0.2)
	var wanted := _label3d("مطلوبون", o + Vector3(0.25, 2.45, 4), 40, Color(0.75, 0.15, 0.12))
	wanted.rotation_degrees.y = 90
	# الإضاءة: مصباح مكتب خافت + مصباح سقف يرتعش + ضوء أحمر
	var desk := SpotLight3D.new()
	add_child(desk)
	desk.look_at_from_position(o + Vector3(3.6, 1.7, 1.6), o + Vector3(3.4, 0.7, 1.3))
	desk.light_color = Color(1.0, 0.8, 0.55)
	desk.light_energy = 2.0
	desk.spot_range = 3.0
	desk.spot_angle = 45
	desk.shadow_enabled = true
	_lamp(o + Vector3(5, WALL_H, 5), Color(0.75, 0.82, 1.0), 0.7, true)
	var red := OmniLight3D.new()
	red.position = o + Vector3(9.5, 2.7, 7.5)
	red.light_color = Color(1.0, 0.1, 0.08)
	red.light_energy = 1.0
	red.omni_range = 4.0
	add_child(red)
	_dust(o + Vector3(5, 1.5, 4), Vector3(5, 1.4, 4))


func _build_feeds() -> void:
	# ثلاث كاميرات مراقبة حيّة في المبنى، معروضة على شاشات الأرشيف بفلتر قديم
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D feed : source_color;
void fragment() {
	vec3 c = texture(feed, UV).rgb;
	float g = dot(c, vec3(0.3, 0.59, 0.11)) * 1.8;
	g *= 0.86 + 0.14 * sin(UV.y * 420.0 + TIME * 9.0);
	float n = fract(sin(dot(UV * (TIME + 1.0), vec2(12.9898, 78.233))) * 43758.5453);
	g += (n - 0.5) * 0.09;
	vec2 d = UV - 0.5;
	g *= 1.0 - dot(d, d) * 1.4;
	ALBEDO = vec3(g * 0.7, g * 1.0, g * 0.75);
}
"""
	var cams := [
		[Vector3(0.6, 2.9, 0.6), Vector3(5, 0.8, 5), "كاميرا 1 · المدخل"],
		[Vector3(8.6, 2.9, 9.4), Vector3(15, 0.6, 3), "كاميرا 2 · المخزن"],
		[Vector3(20.6, 2.9, 0.6), Vector3(28, 0.8, 6), "كاميرا 3 · الخزنة"],
	]
	for i in cams.size():
		var sv := SubViewport.new()
		sv.size = Vector2i(320, 180)
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		var cam := Camera3D.new()
		cam.fov = 80
		sv.add_child(cam)
		cam.look_at_from_position(cams[i][0], cams[i][1])
		feeds.append([sv, cams[i][2]])
		var mon := _box(ARCHIVE + Vector3(2.6 + i * 2.4, 1.95, 0.3), Vector3(2.0, 1.15, 0.1), mat_dark)
		mon.set_meta("kind", "monitor")
		mon.set_meta("index", i)
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.86, 1.02)
		quad.mesh = qm
		var mm := ShaderMaterial.new()
		mm.shader = sh
		mm.set_shader_parameter("feed", sv.get_texture())
		quad.material_override = mm
		quad.position = Vector3(0, 0, 0.055)
		mon.add_child(quad)
		_label3d(cams[i][2], ARCHIVE + Vector3(2.6 + i * 2.4, 1.28, 0.37), 26, Color(0.6, 0.9, 0.65))
		var glow := OmniLight3D.new()
		glow.position = ARCHIVE + Vector3(2.6 + i * 2.4, 1.9, 0.9)
		glow.light_color = Color(0.5, 0.9, 0.6)
		glow.light_energy = 0.5
		glow.omni_range = 2.5
		add_child(glow)


# ───────── اللعب ─────────
func _process(delta: float) -> void:
	if not started:
		# المنضمّ يطلب الانضمام حتى يردّ القائد
		if net and host_role == "" and net.joined:
			_ping_t -= delta
			if _ping_t <= 0.0:
				_ping_t = 1.5
				net.send({"t": "join"})
		return
	var t := Time.get_ticks_msec() / 1000.0
	for i in flickers.size():
		var l: OmniLight3D = flickers[i]
		var base := 1.1 if i == 0 else 0.8
		l.light_energy = base if fmod(t + i * 1.7, 3.9) > 0.3 or fmod(t * 13.0, 1.0) > 0.5 else 0.08

	# جسم العميل كما يظهر في كاميرات المراقبة
	if avatar:
		if agent:
			avatar.position = agent.global_position
			avatar.rotation.y = agent.yaw
		elif avatar.has_meta("target"):
			avatar.position = avatar.position.lerp(avatar.get_meta("target"), minf(1.0, delta * 8.0))
			avatar.rotation.y = lerp_angle(avatar.rotation.y, float(avatar.get_meta("yaw")), minf(1.0, delta * 8.0))

	if net:
		if role == "agent" and agent:
			_send_t -= delta
			if _send_t <= 0.0:
				_send_t = 0.1
				net.send({"t": "pos", "x": snappedf(agent.global_position.x, 0.01), "z": snappedf(agent.global_position.z, 0.01), "y": snappedf(agent.yaw, 0.01)})
			_prog_t -= delta
			if _prog_t <= 0.0:
				_prog_t = 1.0
				_send_prog()
		else:
			_ping_t -= delta
			if _ping_t <= 0.0:
				_ping_t = 2.0
				net.send({"t": "here"})
		hud.set_status("🟢 الشريك متّصل" if t - _partner_seen < 5.0 else "🔴 بانتظار الشريك…")

	if result != "":
		return

	if role != "analyst":
		mission_left -= delta
		if mission_left <= 0.0:
			_end(false)
			return
	if escape_left >= 0.0:
		if role != "analyst":
			escape_left -= delta
			if escape_left <= 0.0:
				_end(false)
				return
		hud.set_timer(escape_left, true)
		for i in alarm_lights.size():
			(alarm_lights[i] as SpotLight3D).rotation.y = t * 4.0 + i * PI
	else:
		hud.set_timer(mission_left, mission_left < 60.0)

	_hint_update(t)
	_audio_update(delta)
	if agent:
		_agent_logic(delta, t)
	if analyst and active == analyst:
		_analyst_logic()
	_apply_stage()


func _hint_update(t: float) -> void:
	var target: Node3D = null
	if stage == 0:
		target = drawer
	elif stage == 1:
		target = book_node
	elif stage == 2:
		target = pc_node
	var on: bool = target != null and analyst != null and active == analyst and not hud.panel_open()
	hint_light.visible = on
	hint_arrow.visible = on
	if on:
		var p := target.global_position
		hint_light.global_position = p + Vector3(0, 0.4, 0)
		hint_light.light_energy = 1.2 + 0.8 * sin(t * 5.0)
		hint_arrow.global_position = p + Vector3(0, 0.6 + 0.08 * sin(t * 4.0), 0)
		hint_arrow.rotation.y = t * 2.0


func _audio_update(delta: float) -> void:
	if agent == null or active != agent:
		if s_steps.playing:
			s_steps.stop()
		s_heart.volume_db = move_toward(s_heart.volume_db, -40.0, delta * 30.0)
		return
	var moving: bool = Vector2(agent.velocity.x, agent.velocity.z).length() > 0.5
	if s_steps.stream:
		if moving and not s_steps.playing:
			s_steps.play()
		elif not moving and s_steps.playing:
			s_steps.stop()
	# نبض القلب يعلو كلّما اقترب الحارس أو لمحك
	var near := 99.0
	for g in guards:
		near = minf(near, (g.global_position as Vector3).distance_to(agent.global_position))
	var danger := clampf(maxf(seen_time / 0.6, (6.0 - near) / 4.0), 0.0, 1.0)
	if s_heart.stream:
		if danger > 0.05 and not s_heart.playing:
			s_heart.play()
		s_heart.volume_db = lerpf(-30.0, 2.0, danger)
		if danger <= 0.05 and s_heart.playing:
			s_heart.stop()


func _agent_logic(delta: float, t: float) -> void:
	var goal: Vector3 = SPAWN if stage >= 3 else (VAULT_FRONT if stage == 2 else (terminals[stage].pos as Vector3))
	marker.position = goal + Vector3(0, 2.1 + 0.08 * sin(t * 3.0), 0)
	marker.rotation.y = t * 1.5
	marker.visible = active == agent

	invuln = maxf(0.0, invuln - delta)
	lockout = maxf(0.0, lockout - delta)
	var space := get_world_3d().direct_space_state
	var seen := false
	_seer = null
	for g in guards:
		var sees_now: bool = g.sees(agent, space)
		if sees_now:
			seen = true
			_seer = g
		g.set_alert(sees_now and seen_time > 0.15, agent.global_position)
	if seen and invuln <= 0.0:
		seen_time += delta * (1.6 if (active == agent and hud.panel_open()) or vault_mode else 1.0)
		if seen_time > 0.6:
			_spotted()
	else:
		seen_time = maxf(0.0, seen_time - delta * 2.0)
	if active == agent:
		hud.set_alert(seen_time / 0.6)

	if vault_mode:
		var dx: float = agent.look_delta.x
		agent.look_delta = Vector2.ZERO
		dial_angle += dx * 0.0035
		var n := posmod(int(round(-dial_angle / (TAU / 40.0))), 40)
		if n != dial_number:
			dial_number = n
			Input.vibrate_handheld(8)
			if s_click.stream:
				s_click.play()
		vault_dial.rotation.x = dial_angle
		hud.vault_state(dial_number, dial_entered)
		return

	if active != agent:
		return
	if stage >= 3:
		hud.show_interact("")
		if agent.global_position.distance_to(SPAWN) < 1.4:
			_end(true)
		return
	if stage < 2:
		var near: bool = agent.global_position.distance_to(terminals[stage].pos) < 1.7
		hud.show_interact(("استعمل " + str(terminals[stage].title)) if near else "")
	else:
		var near2: bool = agent.global_position.distance_to(VAULT_FRONT) < 1.6
		hud.show_interact("اقترب من قرص الخزنة" if near2 else "")


func _analyst_logic() -> void:
	var cam: Camera3D = analyst.cam
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 2.6
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	var obj: Object = null
	if not hit.is_empty():
		var col = hit.get("collider")
		if col is Node and (col as Node).has_meta("kind"):
			obj = col
	var kind := str((obj as Node).get_meta("kind")) if obj else ""
	var labels := {"drawer": "اقرأ الورقة" if drawer_open else "افتح الدرج", "book": "اقرأ دليل الأسلاك", "computer": "شغّل الحاسوب", "monitor": "كبّر الشاشة"}
	hud.show_interact(str(labels.get(kind, "")))
	analyst.set_meta("looking", obj)


func _on_interact() -> void:
	if active == analyst:
		_analyst_interact()
		return
	if stage == 0:
		hud.open_keypad("لوحة الأرقام — الرمز في درج مكتب المحلّل", _submit_code)
	elif stage == 1:
		var wl := []
		for w in puzzle.wires:
			wl.append(WIRES[w])
		hud.open_wires(str(puzzle.serial), wl, _cut_wire)
	elif stage == 2:
		_enter_vault()


func _analyst_interact() -> void:
	var obj = analyst.get_meta("looking", null)
	if obj == null:
		return
	var kind := str(obj.get_meta("kind"))
	if kind == "drawer":
		if not drawer_open:
			drawer_open = true
			var tw := create_tween()
			tw.tween_property(drawer, "position:x", drawer.position.x - 0.55, 0.6).set_trans(Tween.TRANS_BACK)
			(drawer.get_node("Paper") as Node3D).visible = true
			(drawer.get_node("Sheet") as Node3D).visible = true
		else:
			hud.open_text("ورقة مدسوسة في الدرج", "رمز باب المخزن:\n" + str(puzzle.code))
	elif kind == "book":
		var rows := []
		for d in 10:
			var w: Array = WIRES[int(puzzle.table[d])]
			rows.append([d, w[0], w[1]])
		hud.open_table("دليل الأسلاك", rows)
	elif kind == "computer":
		hud.open_symbols(SYMBOLS, _check_symbols)
	elif kind == "monitor":
		var i := int(obj.get_meta("index"))
		hud.open_feed(str(feeds[i][1]), (feeds[i][0] as SubViewport).get_texture())


func _check_symbols(picked: Array) -> String:
	if picked == puzzle.symbols:
		var c: Array = puzzle.combo
		return "> تمّ فكّ التشفير ✔\nتركيبة القرص:  %02d  —  %02d  —  %02d" % [c[0], c[1], c[2]]
	return "> رموز خاطئة ✖  حاول مرّة أخرى"


func _submit_code(v: String) -> void:
	if lockout > 0.0:
		hud.flash("اللوحة مقفلة… انتظر", Color(0.9, 0.28, 0.3))
		return
	if v == str(puzzle.code):
		hud.close_panel()
		_advance()
	else:
		lockout = 3.0
		hud.flash("✖ رمز خاطئ", Color(0.9, 0.28, 0.3))
		hud.hit()


func _cut_wire(wire_name: String) -> void:
	var right := str(WIRES[int(puzzle.answer)][0])
	if wire_name == right:
		hud.close_panel()
		_advance()
	else:
		hud.flash("✖ سلك خاطئ — الحرّاس انتبهوا!", Color(0.9, 0.28, 0.3))
		hud.hit()
		for g in guards:
			g.speed *= 1.15


func _advance() -> void:
	stage += 1
	var term: Dictionary = terminals[stage - 1]
	(term.light as OmniLight3D).light_color = Color(0.42, 0.85, 0.58)
	(term.screen as MeshInstance3D).material_override = _glow(Color(0.42, 0.85, 0.58), 3.0)
	hud.flash("🔓 فُتح الباب", Color(0.42, 0.85, 0.58))
	_apply_stage()
	_send_prog()


func _apply_stage() -> void:
	for i in doors.size():
		var d: Dictionary = doors[i]
		if stage > i and not d.open:
			d.open = true
			(d.stripe as MeshInstance3D).material_override = _glow(Color(0.42, 0.85, 0.58), 2.5)
			if s_door.stream:
				s_door.global_position = (d.body as Node3D).global_position
				s_door.play()
			var tw := create_tween()
			tw.tween_property(d.body, "position:y", WALL_H * 1.5, 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if stage >= 3 and _applied_stage < 3:
		_open_vault_door()
		_alarm()
	if stage != _applied_stage:
		_applied_stage = stage
		_update_objective()


func _update_objective() -> void:
	if hud == null:
		return
	var agent_side: bool = active == agent
	var txt := ""
	match stage:
		0:
			txt = "١. اذهب إلى الجهاز (السهم البرتقالي) — رمزه المكوّن من 4 أرقام في درج المحلّل، اطلبه منه" if agent_side else "١. افتح الدرج المضيء (على يمينك)، اقرأ الرمز وأمْلِه على العميل"
		1:
			txt = "٢. افتح لوحة الأسلاك، اقرأ الرقم التسلسلي لشريكك، واقطع السلك الذي يقوله" if agent_side else "٢. اسأل العميل عن آخر رقم في الرقم التسلسلي، وابحث عنه في الدليل الأحمر المضيء"
		2:
			txt = "٣. صِف لشريكك الرموز الثلاثة على باب الخزنة، ثم أدِر القرص على الأرقام التي يقولها" if agent_side else "٣. أدخل في الحاسوب المضيء الرموز التي يصفها العميل، وأمْلِه التركيبة"
		_:
			txt = "🚨 اهرب إلى نقطة البداية!" if agent_side else "🚨 وجّه العميل إلى المخرج عبر الكاميرات!"
	hud.set_objective(txt)


# ───────── الخزنة ─────────
func _enter_vault() -> void:
	vault_mode = true
	agent.locked = true
	dial_entered = []
	_cam_saved = agent.cam.global_transform
	var target := Transform3D.IDENTITY.looking_at(Vector3(1, 0, 0), Vector3.UP)
	target.origin = Vector3(28.75, 1.72, 5.0)
	var tw := create_tween()
	tw.tween_property(agent.cam, "global_transform", target, 0.6).set_trans(Tween.TRANS_CUBIC)
	hud.vault_ui(true, _record_number, _exit_vault)
	hud.vault_state(dial_number, dial_entered)


func _exit_vault() -> void:
	if not vault_mode:
		return
	vault_mode = false
	hud.vault_ui(false, Callable(), Callable())
	var tw := create_tween()
	tw.tween_property(agent.cam, "global_transform", _cam_saved, 0.4)
	tw.tween_callback(func(): agent.locked = false)


func _record_number() -> void:
	dial_entered.append(dial_number)
	hud.vault_state(dial_number, dial_entered)
	if dial_entered.size() < 3:
		return
	if dial_entered == puzzle.combo:
		hud.flash("✔ التركيبة صحيحة", Color(0.42, 0.85, 0.58))
		var tw := create_tween()
		tw.tween_property(vault_wheel, "rotation:x", vault_wheel.rotation.x + TAU, 1.4).set_trans(Tween.TRANS_CUBIC)
		tw.tween_callback(_vault_opened)
	else:
		hud.flash("✖ تركيبة خاطئة", Color(0.9, 0.28, 0.3))
		hud.hit()
		dial_entered = []


func _vault_opened() -> void:
	_exit_vault()
	stage = 3
	escape_left = ESCAPE_SECONDS
	_apply_stage()
	_send_prog()


func _open_vault_door() -> void:
	if s_vault.stream:
		s_vault.play()
	var tw := create_tween()
	tw.set_parallel(true)
	for b in vault_bolts:
		var a: float = b[1]
		tw.tween_property(b[0], "position", Vector3(0, cos(a) * 0.86, sin(a) * 0.86), 0.7).set_trans(Tween.TRANS_BACK)
	tw.set_parallel(false)
	tw.tween_interval(0.2)
	tw.tween_property(vault_pivot, "rotation:y", deg_to_rad(-100), 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _alarm() -> void:
	hud.flash("🚨 الخزنة مفتوحة — الإنذار!", Color(0.9, 0.28, 0.3))
	if s_alarm.stream:
		s_alarm.play()
	for g in guards:
		g.speed *= 1.6
		g.alarm = true
	for c in [Vector3(4, WALL_H - 0.2, 4), Vector3(14, WALL_H - 0.2, 5), Vector3(25, WALL_H - 0.2, 5), ARCHIVE + Vector3(5, WALL_H - 0.2, 4)]:
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
	if _seer:
		_seer.attack()
	invuln = 2.5
	if active == agent:
		hud.flash("👁 رآك الحارس!", Color(0.9, 0.28, 0.3))
		hud.hit()
		hud.close_panel()
	if vault_mode:
		_exit_vault()
	if stage >= 3:
		escape_left = maxf(1.0, escape_left - 8.0)
		return
	agent.global_position = SPAWN if stage == 0 else (Vector3(9.2, 0, 4.5) if stage == 1 else Vector3(21.2, 0, 5))


func _end(won: bool) -> void:
	result = "win" if won else "lose"
	_send_prog()
	_finish(won)


func _finish(won: bool) -> void:
	result = "win" if won else "lose"
	hud.show_interact("")
	hud.end_screen(won)
