# «الخزنة» — لعبة تسلّل تعاونية برؤية من الأعلى (على طريقة Hitman GO / Monaco).
# العميل يتحرّك في المجسّم ويُسقط الحرّاس ويتنكّر ويُخفي الأجسام؛ المحلّل يرى الخريطة كلّها،
# يعطّل الكاميرا، يفتح باب الخزنة، يشتّت الحرّاس، ويملك رمز الخزنة.
extends Node3D

const L := preload("res://td/level.gd")
const Unit := preload("res://td/unit.gd")
const Guard := preload("res://td/guard.gd")
const UI := preload("res://td/ui.gd")
const Levels := preload("res://levels.gd")

const WALL_VIS := 1.7 # ارتفاع الجدار المرئي (منخفض حتى لا يحجب الكاميرا)
const WALL_COL := 3.0 # ارتفاع التصادم (يحجب الرؤية والحركة)
const CAM_OFF := Vector3(0, 14.5, 8.0)
const LAYER_MOVE := 1
const LAYER_SIGHT := 2

static var persist := {} # لإعادة المحاولة دون فقدان الغرفة

var role := "" # solo · agent · analyst
var view := "agent" # ما يراه هذا الجهاز الآن
var room_code := ""
var host_role := ""
var seed_value := 0
var started := false
var ready_world := false
var smoke := false
var shots := false

var menu: Node
var net: Node
var voice: Node
var ui: Node
var cam: Camera3D
var map_cam: Camera3D
var astar := AStarGrid2D.new()

var agent: CharacterBody3D
var agent_unit: Node3D
var agent_face := 0.0
var disguised := false
var dragging = null
var locked := false
var running := false
var guards: Array = []
var lockers: Array = [] # {cell, pos, front, pivot, used}
var cams: Array = [] # {node, pos, look, sweep, range, mesh, imesh, t, loop}
var door_r: Dictionary = {}
var safe: Dictionary = {}
var code := "0000"
var has_docs := false
var safe_open := false
var loop_left := 0.0
var loop_cd := 0.0
var distract_cd := 0.0
var distract_mode := false
var result := ""
var stats := {"t0": 0.0, "ko": 0, "found": 0, "spotted": 0, "cam": 0}
var _send_t := 0.0
var _cam_zoom := 1.0
var _cam_zoom_t := 1.0
var _shake := 0.0
var _ping: Node3D
var _ping_t := 0.0
var _arrow: MeshInstance3D
var _ring: MeshInstance3D
var _goal_i := -1
var _warned_door := 0.0
var _partner_t := 0.0

var s_amb: AudioStreamPlayer
var s_punch: AudioStreamPlayer
var s_cloth: AudioStreamPlayer
var s_drag: AudioStreamPlayer
var s_door: AudioStreamPlayer
var s_alarm: AudioStreamPlayer
var s_chase: AudioStreamPlayer
var s_click: AudioStreamPlayer
var s_vault: AudioStreamPlayer
var s_steps: AudioStreamPlayer
var s_beep: AudioStreamPlayer

var mats := {}


# ───────── البداية ─────────
func _ready() -> void:
	smoke = OS.get_environment("KHAZNA_SMOKE") == "1"
	shots = OS.get_environment("KHAZNA_SHOT") == "1"
	if smoke or shots:
		_start("solo", 1234)
		_scenario.call_deferred()
		return
	if not persist.is_empty():
		var p := persist.duplicate()
		persist = {}
		room_code = str(p.get("code", ""))
		host_role = str(p.get("host", ""))
		if room_code != "":
			_net()
			net.open(room_code)
		_start(str(p.get("role", "solo")), int(p.get("seed", randi() % 100000)))
		return
	menu = preload("res://menu.gd").new()
	add_child(menu)
	menu.solo.connect(func(): _start("solo", randi() % 1000000))
	menu.host.connect(_host)
	menu.join.connect(_join)
	var dl := _deep_link_code()
	if dl != "":
		_join(dl)


func _deep_link_code() -> String:
	if not Engine.has_singleton("GodotAgora"):
		return ""
	var a = Engine.get_singleton("GodotAgora")
	if not a.has_method("intent_data"):
		return ""
	var d := str(a.intent_data())
	var i := d.find("code=")
	if i < 0:
		return ""
	var c := d.substr(i + 5, 4)
	return c if c.is_valid_int() and c.length() == 4 else ""


# ───────── الشبكة ─────────
func _net() -> void:
	net = preload("res://net.gd").new()
	add_child(net)
	net.message.connect(_on_msg)
	net.status.connect(func(t):
		if ui:
			ui.set_status(t)
		elif menu:
			menu.show_info(t, Color(0.6, 0.64, 0.68)))


func _host(r: String) -> void:
	host_role = r
	seed_value = randi() % 1000000
	room_code = str(randi_range(1000, 9999))
	_net()
	net.open(room_code)
	menu.waiting(room_code, r)


func _join(c: String) -> void:
	room_code = c
	_net()
	net.open(c)
	menu.show_info("جارٍ الانضمام إلى الغرفة %s…" % c)
	_join_ping()


func _join_ping() -> void:
	# نكرّر طلب الانضمام حتى يردّ صاحب الغرفة
	while not started and net:
		if net.joined:
			net.send({"t": "join"})
		await get_tree().create_timer(1.0).timeout


func _send(m: Dictionary) -> void:
	if net:
		net.send(m)


func _on_msg(m: Dictionary) -> void:
	_partner_t = Time.get_ticks_msec() / 1000.0
	var t := str(m.get("t", ""))
	match t:
		"join":
			if host_role != "":
				_send({"t": "hello", "role": host_role, "seed": seed_value})
				if not started:
					_start(host_role, seed_value)
		"hello":
			if host_role == "" and not started:
				_start("analyst" if str(m.get("role", "")) == "agent" else "agent", int(m.get("seed", 0)))
		"s":
			if role == "analyst" and ready_world:
				_apply_state(m)
		"tool":
			if role == "agent" and ready_world:
				_do_tool(str(m.get("k", "")), Vector3(float(m.get("x", 0)), 0, float(m.get("z", 0))))
		"ping":
			if ready_world:
				_show_ping(Vector3(float(m.get("x", 0)), 0, float(m.get("z", 0))), false)
		"end":
			if role == "analyst" and ready_world and result == "":
				_finish(bool(m.get("won", false)), str(m.get("why", "")), m.get("lines", []), int(m.get("stars", 0)))
		"retry":
			_retry(false)


# ───────── بناء العالم ─────────
func _start(r: String, s: int) -> void:
	if started:
		return
	started = true
	role = r
	view = "analyst" if r == "analyst" else "agent"
	seed_value = s
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	code = "%04d" % rng.randi_range(1000, 9999)
	if menu:
		menu.queue_free()
		menu = null
	ui = UI.new()
	add_child(ui)
	ui.loading(true, "جارٍ بناء المخزن…")
	await get_tree().process_frame
	_materials()
	_environment()
	_build_level()
	await get_tree().process_frame
	_build_props()
	_build_agent()
	_spawn_guards()
	_build_cams()
	_sounds()
	_cameras()
	_wire_ui()
	await get_tree().process_frame
	await get_tree().physics_frame
	ready_world = true
	stats.t0 = Time.get_ticks_msec() / 1000.0
	ui.loading(false)
	_set_view(view)
	if not smoke and not shots:
		_intro()
	if net and room_code != "":
		_start_voice()


func _wire_ui() -> void:
	ui.action_pressed.connect(func(): _do_act(false))
	ui.action2_pressed.connect(func(): _do_act(true))
	ui.switch_pressed.connect(func(): _set_view("analyst" if view == "agent" else "agent"))
	ui.code_entered.connect(_on_code)
	ui.map_tap.connect(_on_map_tap)
	ui.tool_pressed.connect(_on_tool_btn)
	ui.retry_pressed.connect(func(): _retry(true))
	ui.menu_pressed.connect(func():
		persist = {}
		get_tree().reload_current_scene())
	ui.set_switch_visible(role == "solo")
	ui.set_code(code)
	ui.set_status("وضع فردي — اضغط «بدّل الدور» لترى شاشة المحلّل" if role == "solo" else "")


func _start_voice() -> void:
	voice = preload("res://voice.gd").new()
	add_child(voice)
	voice.status.connect(func(t): ui.set_status(t))
	ui.mic_pressed.connect(func():
		voice.toggle_mute()
		ui.set_mic("🔇" if voice.muted else "🎙"))
	if voice.available:
		ui.set_mic("🎙")
		voice.start(room_code)
	else:
		ui.set_status("الصوت داخل اللعبة يعمل على أندرويد وويندوز — أو استعمل مكالمة هاتفية")


func _intro() -> void:
	if view == "agent":
		ui.intro("المهمّة: مخزن الميناء", "أنت العميل. المطلوب: وثائق داخل خزنة في الطابق الأيمن، ثم العودة إلى الشاحنة.\n\n• العصا (يسار الشاشة): ادفعها قليلاً = مشي هادئ، إلى الآخر = ركض (يُسمَع!).\n• المروحة الصفراء على الأرض = ما يراه الحارس. ابقَ خارجها.\n• من خلف الحارس يظهر زرّ «أسقطه». خذ بدلته لتمرّ بين الحرّاس، ثم أخفِ جسمه في خزانة.\n• باب الخزنة والكاميرا ورمز الخزنة عند المحلّل — كلّمه.\n• السهم الأخضر حولك يشير إلى الهدف التالي.")
	else:
		ui.intro("المهمّة: أنت المحلّل", "ترى المخزن كلّه من الأعلى: العميل (الحلقة الزرقاء)، الحرّاس ومجال رؤيتهم.\n\n• اضغط على أيّ مكان لتضع علامة يراها العميل.\n• «تشتيت حارس» ثم اضغط على مكان: أقرب حارس يذهب ليتفقّده.\n• «تعطيل الكاميرا»: تتوقّف كاميرا غرفة الخزنة 20 ثانية.\n• «باب الخزنة»: أنت وحدك تفتحه.\n• رمز الخزنة عندك فقط: أمْلِه على العميل.")


func _materials() -> void:
	mats.floor_yard = _pbr("damaged_concrete_floor_02", Color(0.36, 0.37, 0.38), 3.0, Color(0.72, 0.72, 0.74))
	mats.floor_hall = _pbr("concrete_floor_01", Color(0.55, 0.55, 0.53), 3.0, Color(0.95, 0.94, 0.9))
	mats.floor_wood = _pbr("old_wooden_floor_02", Color(0.5, 0.36, 0.24), 2.5, Color(1.0, 0.95, 0.88))
	mats.floor_office = _pbr("concrete_floor_01", Color(0.42, 0.45, 0.5), 2.0, Color(0.75, 0.8, 0.9))
	mats.floor_vault = _pbr("metal_plate", Color(0.45, 0.47, 0.5), 1.5, Color(0.85, 0.87, 0.9))
	mats.floor_vault.metallic = 0.6
	mats.wall = _pbr("factory_wall", Color(0.62, 0.6, 0.56), 2.5, Color(0.92, 0.9, 0.86))
	mats.wall_out = _pbr("corrugated_iron_02", Color(0.4, 0.45, 0.48), 2.0, Color(0.7, 0.78, 0.82))
	mats.cap = _flat(Color(0.12, 0.13, 0.15), 0.8)
	mats.crate = _pbr("brown_planks_04", Color(0.55, 0.38, 0.22), 1.0, Color(1.0, 0.92, 0.8))
	mats.steel = _pbr("metal_plate_02", Color(0.5, 0.53, 0.56), 1.2, Color(0.9, 0.92, 0.95))
	mats.steel.metallic = 0.7
	mats.dark = _flat(Color(0.07, 0.075, 0.08), 0.5)
	mats.locker = _flat(Color(0.25, 0.42, 0.5), 0.45)
	mats.locker.metallic = 0.5
	mats.red = _flat(Color(0.75, 0.12, 0.08), 0.4)
	mats.ground = _pbr("damaged_concrete_floor_02", Color(0.2, 0.21, 0.22), 4.0, Color(0.42, 0.42, 0.45))


func _flat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _pbr(id: String, fb: Color, uv: float, tint: Color) -> StandardMaterial3D:
	var d := "res://ph/tex/%s_diff.jpg" % id
	if not ResourceLoader.exists(d):
		return _flat(fb, 0.85)
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
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / uv
	return m


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.25
	sun.shadow_enabled = not Levels.low_quality()
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _box(pos: Vector3, size: Vector3, mat: Material, layers := 0, parent: Node = null) -> Node3D:
	var host: Node3D
	if layers != 0:
		var b := StaticBody3D.new()
		b.collision_layer = layers
		b.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		b.add_child(cs)
		host = b
	else:
		host = Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	host.add_child(mi)
	(parent if parent else self).add_child(host)
	host.position = pos
	return host


## جسم تصادم غير مرئي (لتمديد الجدار المنخفض إلى ارتفاع يحجب الرؤية).
func _solid(pos: Vector3, size: Vector3, layers: int) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = layers
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	add_child(b)
	b.position = pos
	return b


func _build_level() -> void:
	var w := L.width()
	var h := L.height()
	var T := L.TILE
	# أرض خارج المبنى
	_box(Vector3(w * T * 0.5, -0.06, h * T * 0.5), Vector3(w * T + 30, 0.1, h * T + 30), mats.ground)
	# أرضيات الغرف
	for rm in L.ROOMS:
		var rc: Rect2i = rm[1]
		var key := "floor_" + str(rm[2])
		var m: Material = mats.get(key, mats.floor_hall)
		_box(Vector3((rc.position.x + rc.size.x * 0.5) * T, 0.0, (rc.position.y + rc.size.y * 0.5) * T), Vector3(rc.size.x * T, 0.04, rc.size.y * T), m)
		if role != "agent":
			var lb := Label3D.new()
			lb.text = str(rm[0])
			lb.font_size = 72
			lb.outline_size = 14
			lb.modulate = Color(1, 1, 1, 0.55)
			lb.rotation_degrees.x = -90
			lb.position = Vector3((rc.position.x + rc.size.x * 0.5) * T, 0.08, (rc.position.y + rc.size.y - 0.4) * T)
			add_child(lb)
	# المداخل والأرضيات الصغيرة بين الغرف
	for r in h:
		for c in w:
			var ch := L.at(Vector2i(c, r))
			if ch == "d" or ch == "R":
				_box(L.cell_center(Vector2i(c, r)), Vector3(T, 0.045, T), mats.floor_hall)
	# الجدران: كتلة لكل خانة، الجدار الخارجي بالحديد المموّج
	var astar_region := Rect2i(0, 0, w, h)
	astar.region = astar_region
	astar.cell_size = Vector2(T, T)
	astar.offset = Vector2(T * 0.5, T * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for r in h:
		for c in w:
			var cell := Vector2i(c, r)
			var ch := L.at(cell)
			astar.set_point_solid(cell, not L.walkable(cell) or ch == "R")
			var p := L.cell_center(cell)
			match ch:
				"#":
					var outer := r == 0 or c == 0 or r == h - 1 or c == w - 1
					_box(p + Vector3(0, WALL_VIS * 0.5, 0), Vector3(T, WALL_VIS, T), mats.wall_out if outer else mats.wall)
					_box(p + Vector3(0, WALL_VIS + 0.04, 0), Vector3(T + 0.02, 0.08, T + 0.02), mats.cap)
					_solid(p + Vector3(0, WALL_COL * 0.5, 0), Vector3(T, WALL_COL, T), LAYER_MOVE | LAYER_SIGHT)
				"B":
					_crates(p)
				"b":
					_barrels(p)
				"T":
					_table(p, cell)
				"L":
					_locker(cell)
				"V":
					_safe(cell)
				"R":
					_vault_door(cell)
				"E":
					_van(p)
	_build_markers()


func _crates(p: Vector3) -> void:
	_box(p + Vector3(0, 0.62, 0), Vector3(1.8, 1.24, 1.8), mats.crate)
	var top := _box(p + Vector3(0.05, 1.62, -0.04), Vector3(1.55, 0.76, 1.6), mats.crate)
	top.rotation_degrees.y = 6
	_solid(p + Vector3(0, WALL_COL * 0.5, 0), Vector3(1.9, WALL_COL, 1.9), LAYER_MOVE | LAYER_SIGHT)


func _barrels(p: Vector3) -> void:
	for o in [Vector3(-0.45, 0, -0.4), Vector3(0.45, 0, -0.35), Vector3(0, 0, 0.45)]:
		var n := _prop("Barrel_01", p + o, randf() * 360.0)
		if n == null:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.38
			cm.bottom_radius = 0.38
			cm.height = 1.0
			mi.mesh = cm
			mi.material_override = mats.red
			add_child(mi)
			mi.position = p + o + Vector3(0, 0.5, 0)
	_solid(p + Vector3(0, 0.6, 0), Vector3(1.9, 1.2, 1.9), LAYER_MOVE)


func _table(p: Vector3, cell: Vector2i) -> void:
	if cell.x > 20:
		var d := _prop("metal_office_desk", p, 90.0, false)
		if d == null:
			_box(p + Vector3(0, 0.38, 0), Vector3(1.8, 0.76, 0.9), mats.steel)
	else:
		_box(p + Vector3(0, 0.74, 0), Vector3(1.6, 0.06, 1.0), mats.crate)
		for o in [Vector3(-0.7, 0, -0.4), Vector3(0.7, 0, -0.4), Vector3(-0.7, 0, 0.4), Vector3(0.7, 0, 0.4)]:
			_box(p + o + Vector3(0, 0.36, 0), Vector3(0.06, 0.72, 0.06), mats.dark)
		_box(p + Vector3(0.3, 0.83, 0.1), Vector3(0.1, 0.12, 0.1), mats.red) # فنجان قهوة
	_solid(p + Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 1.2), LAYER_MOVE)


## الاتّجاه نحو أقرب خانة يمكن المشي فيها (لتوجيه الخزانة والخزنة نحو الغرفة).
func _front_of(cell: Vector2i) -> Vector3:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if L.walkable(cell + d) and L.at(cell + d) != "R":
			return Vector3(d.x, 0, d.y)
	return Vector3(0, 0, 1)


func _locker(cell: Vector2i) -> void:
	var p := L.cell_center(cell)
	var front := _front_of(cell)
	var root := Node3D.new()
	add_child(root)
	root.position = p
	root.rotation.y = atan2(front.x, front.z)
	# صندوق معدني مفتوح من الأمام (+z المحلّي)
	for part in [[Vector3(0, 1.0, -0.38), Vector3(1.1, 2.0, 0.05)], [Vector3(-0.53, 1.0, 0), Vector3(0.05, 2.0, 0.8)], [Vector3(0.53, 1.0, 0), Vector3(0.05, 2.0, 0.8)], [Vector3(0, 2.0, 0), Vector3(1.1, 0.06, 0.8)], [Vector3(0, 0.03, 0), Vector3(1.1, 0.06, 0.8)]]:
		_box(part[0], part[1], mats.locker, 0, root)
	var pivot := Node3D.new()
	pivot.position = Vector3(-0.53, 0, 0.4)
	root.add_child(pivot)
	_box(Vector3(0.53, 1.0, 0.0), Vector3(1.04, 1.96, 0.04), mats.locker, 0, pivot)
	for k in 4:
		_box(Vector3(0.53, 1.6 + k * 0.07, 0.03), Vector3(0.55, 0.025, 0.01), mats.dark, 0, pivot)
	_box(Vector3(0.95, 1.0, 0.05), Vector3(0.04, 0.2, 0.04), mats.dark, 0, pivot)
	_solid(p + Vector3(0, 1.0, 0), Vector3(1.6, 2.0, 1.6), LAYER_MOVE)
	lockers.append({"cell": cell, "pos": p, "front": front, "pivot": pivot, "used": false})


func _safe(cell: Vector2i) -> void:
	var p := L.cell_center(cell)
	var front := _front_of(cell)
	var root := Node3D.new()
	add_child(root)
	root.position = p
	root.rotation.y = atan2(front.x, front.z)
	_box(Vector3(0, 0.75, 0), Vector3(1.3, 1.5, 1.1), mats.steel, 0, root)
	var pivot := Node3D.new()
	pivot.position = Vector3(-0.6, 0, 0.56)
	root.add_child(pivot)
	_box(Vector3(0.6, 0.75, 0.03), Vector3(1.16, 1.3, 0.08), mats.dark, 0, pivot)
	var dial := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.16
	cm.height = 0.06
	dial.mesh = cm
	dial.material_override = mats.steel
	dial.rotation_degrees.x = 90
	dial.position = Vector3(0.6, 0.85, 0.1)
	pivot.add_child(dial)
	# الوثائق داخل الخزنة (تظهر عند الفتح)
	var docs := _box(Vector3(0, 0.8, 0.1), Vector3(0.5, 0.08, 0.36), _flat(Color(0.95, 0.85, 0.4), 0.6), 0, root)
	_solid(p + Vector3(0, 0.75, 0), Vector3(1.6, 1.5, 1.6), LAYER_MOVE)
	safe = {"cell": cell, "pos": p, "front": front, "pivot": pivot, "docs": docs}


func _vault_door(cell: Vector2i) -> void:
	var p := L.cell_center(cell)
	var leaf := _box(p + Vector3(0, WALL_VIS * 0.5, 0), Vector3(L.TILE * 0.96, WALL_VIS, 0.3), mats.red)
	var stripe := _box(p + Vector3(0, WALL_VIS + 0.03, 0), Vector3(L.TILE, 0.06, 0.34), _glow(Color(1, 0.2, 0.1), 2.0))
	var col := _solid(p + Vector3(0, WALL_COL * 0.5, 0), Vector3(L.TILE, WALL_COL, 0.4), LAYER_MOVE | LAYER_SIGHT)
	door_r = {"cell": cell, "pos": p, "leaf": leaf, "stripe": stripe, "col": col, "open": false}


func set_door(open: bool) -> void:
	if door_r.is_empty() or bool(door_r.open) == open:
		return
	door_r.open = open
	var col: StaticBody3D = door_r.col
	col.collision_layer = 0 if open else (LAYER_MOVE | LAYER_SIGHT)
	astar.set_point_solid(door_r.cell, not open)
	var leaf: Node3D = door_r.leaf
	var tw := create_tween()
	tw.tween_property(leaf, "position:x", (door_r.pos as Vector3).x + (1.9 if open else 0.0), 0.5)
	var st := door_r.stripe as Node3D
	var mi := st.get_child(0) as MeshInstance3D
	mi.material_override = _glow(Color(0.2, 1.0, 0.4) if open else Color(1, 0.2, 0.1), 2.0)
	if s_door and s_door.stream:
		s_door.play()
	ui.set_tool("door", "🚪 أغلق باب الخزنة" if open else "🚪 افتح باب الخزنة", true)


func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


func _van(p: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = p + Vector3(-0.4, 0, 0.2)
	var white := _flat(Color(0.88, 0.89, 0.9), 0.4)
	_box(Vector3(0, 1.2, 0.4), Vector3(1.9, 1.7, 2.8), white, 0, root)
	_box(Vector3(0, 0.95, -1.5), Vector3(1.9, 1.2, 1.1), white, 0, root)
	_box(Vector3(0, 1.25, -2.02), Vector3(1.6, 0.5, 0.04), _flat(Color(0.15, 0.25, 0.35), 0.1), 0, root)
	for o in [Vector3(-0.95, 0.35, -1.3), Vector3(0.95, 0.35, -1.3), Vector3(-0.95, 0.35, 1.2), Vector3(0.95, 0.35, 1.2)]:
		_box(o, Vector3(0.25, 0.7, 0.7), mats.dark, 0, root)
	_solid(p + Vector3(-0.4, 1.0, 0.0), Vector3(2.0, 2.0, 3.8), LAYER_MOVE)


## نموذج Poly Haven: قاعدته على الأرض ومركزه في [pos].
func _prop(id: String, pos: Vector3, rot := 0.0, collide := false) -> Node3D:
	var path := "res://ph/models/%s/%s.gltf" % [id, id]
	if not ResourceLoader.exists(path):
		return null
	var scn = load(path)
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
		_solid(Vector3(pos.x, pos.y + box.size.y / 2.0, pos.z), box.size, LAYER_MOVE)
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


func _build_props() -> void:
	# لمسات: رفوف على جدران المستودع، صناديق كرتون، طفّايات، صندوق كهرباء، سلّة مهملات
	var T := L.TILE
	for x in [11.5, 14.5, 17.5]:
		_prop("steel_frame_shelves_01", Vector3(x * T, 0, 13.65 * T), 0.0, false)
	_prop("cardboard_box_01", Vector3(19.4 * T, 0, 6.5 * T), 20.0)
	_prop("cardboard_box_01", Vector3(19.7 * T, 0, 7.0 * T), -15.0)
	_prop("korean_fire_extinguisher_01", Vector3(9.75 * T, 0, 6.3 * T), 90.0)
	_prop("korean_fire_extinguisher_01", Vector3(21.75 * T, 0, 6.3 * T), 90.0)
	_prop("power_box_01", Vector3(26.7 * T, 0.9, 10.5 * T), -90.0)
	_prop("metal_trash_can", Vector3(16.6 * T, 0, 1.4 * T), 0.0)
	_prop("modern_arm_chair_01", Vector3(10.45 * T, 0, 2.3 * T), 120.0)
	_prop("vintage_cabinet_01", Vector3(26.6 * T, 0, 7.0 * T), -90.0)
	_prop("cardboard_box_01", Vector3(2.0 * T, 0, 1.6 * T), 30.0)
	_prop("cardboard_box_01", Vector3(1.6 * T, 0, 2.1 * T), -10.0)
	# مصابيح دافئة داخل الغرف
	for lp in [Vector3(13.5, 3.2, 2.5), Vector3(13, 3.6, 8), Vector3(18, 3.6, 11), Vector3(24.5, 3.2, 8.5), Vector3(22.5, 3.2, 2.5)]:
		var ol := OmniLight3D.new()
		ol.position = Vector3(lp.x * T, lp.y, lp.z * T)
		ol.light_color = Color(1.0, 0.85, 0.62)
		ol.light_energy = 1.6
		ol.omni_range = 9.0
		add_child(ol)


func _build_markers() -> void:
	# حلقة زرقاء تحت العميل، وسهم أخضر يدور حوله نحو الهدف التالي
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.48
	tm.outer_radius = 0.6
	_ring.mesh = tm
	_ring.material_override = _glow(Color(0.25, 0.65, 1.0), 1.6)
	_ring.scale = Vector3(1, 0.15, 1)
	add_child(_ring)
	_arrow = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.5, 0.6, 0.08)
	_arrow.mesh = pm
	_arrow.material_override = _glow(Color(0.3, 1.0, 0.45), 2.0)
	add_child(_arrow)
	_ping = Node3D.new()
	var pr := MeshInstance3D.new()
	var pt := TorusMesh.new()
	pt.inner_radius = 0.7
	pt.outer_radius = 0.9
	pr.mesh = pt
	pr.material_override = _glow(Color(0.3, 0.75, 1.0), 2.5)
	pr.scale = Vector3(1, 0.1, 1)
	_ping.add_child(pr)
	var pl := Label3D.new()
	pl.text = "↓"
	pl.font_size = 160
	pl.outline_size = 20
	pl.modulate = Color(0.4, 0.8, 1.0)
	pl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pl.no_depth_test = true
	pl.position.y = 2.2
	_ping.add_child(pl)
	_ping.visible = false
	add_child(_ping)


# ───────── العميل ─────────
func _build_agent() -> void:
	var start := L.cell_center((L.find("S")[0] as Vector2i))
	if role == "analyst":
		var pup := Node3D.new()
		add_child(pup)
		pup.position = start
		agent_unit = Unit.new()
		pup.add_child(agent_unit)
		agent_unit.setup(Unit.AGENT_MODEL)
		agent_unit.suit_look()
		agent = null
		_ring.set_meta("follow", pup)
		agent_unit.set_meta("pup", pup)
		return
	agent = CharacterBody3D.new()
	agent.collision_layer = 4
	agent.collision_mask = LAYER_MOVE
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	agent.add_child(cs)
	add_child(agent)
	agent.position = start
	agent_face = PI * 0.5 # ينظر يميناً نحو المخزن
	_set_agent_model(false)


func _set_agent_model(disg: bool) -> void:
	var host: Node3D = agent if agent else agent_unit.get_meta("pup")
	if agent_unit and is_instance_valid(agent_unit):
		agent_unit.queue_free()
	agent_unit = Unit.new()
	host.add_child(agent_unit)
	agent_unit.setup(Unit.GUARD_MODEL if disg else Unit.AGENT_MODEL)
	if not disg:
		agent_unit.suit_look()
	if role == "analyst":
		agent_unit.set_meta("pup", host)


func _spawn_guards() -> void:
	for def in L.GUARDS:
		var g := Guard.new()
		add_child(g)
		g.setup(self, def)
		g.puppet = role == "analyst"
		guards.append(g)


func _build_cams() -> void:
	for def in L.CAMS:
		var cell: Vector2i = def["cell"]
		var p := L.cell_center(cell) + Vector3(0, 0, -0.9)
		var mount := Node3D.new()
		add_child(mount)
		mount.position = p + Vector3(0, 1.95, 0)
		var m := _prop("security_camera_01", p + Vector3(0, 1.75, 0), 180.0 - float(def["look"]))
		if m == null:
			_box(Vector3.ZERO, Vector3(0.25, 0.2, 0.45), mats.dark, 0, mount)
		var led := _box(Vector3(0, 0.2, 0), Vector3(0.12, 0.12, 0.12), _glow(Color(1, 0.1, 0.1), 3.0), 0, mount)
		var im := ImmediateMesh.new()
		var mi := MeshInstance3D.new()
		mi.mesh = im
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		cams.append({"pos": p, "look": float(def["look"]), "sweep": float(def["sweep"]), "range": float(def["range"]), "im": im, "mat": mat, "t": 0.0, "led": led, "yaw": 0.0})


func _sounds() -> void:
	s_amb = _snd("ambience", true, -14.0)
	if s_amb.stream:
		s_amb.play()
	s_punch = _snd("punch", false, 0.0)
	s_cloth = _snd("cloth", false, -2.0)
	s_drag = _snd("drag", true, -6.0)
	s_door = _snd("door", false, -4.0)
	s_alarm = _snd("alarm", false, -6.0)
	s_chase = _snd("chase", true, -6.0)
	s_click = _snd("click", false, -3.0)
	s_vault = _snd("vault_open", false, -2.0)
	s_steps = _snd("steps", true, -12.0)
	s_beep = _snd("cam_beep", false, -6.0)


func _snd(n: String, loop: bool, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var path := "res://sounds/%s.mp3" % n
	if ResourceLoader.exists(path):
		var st = load(path)
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = loop
		p.stream = st
	p.volume_db = db
	add_child(p)
	return p


func _cameras() -> void:
	cam = Camera3D.new()
	cam.fov = 46
	add_child(cam)
	map_cam = Camera3D.new()
	map_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(map_cam)
	_fit_map_cam()
	get_viewport().size_changed.connect(_fit_map_cam)
	var p := _agent_pos()
	cam.position = p + CAM_OFF
	cam.look_at(p, Vector3.UP)


func _fit_map_cam() -> void:
	var vs := get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(1.0, vs.y)
	var mw := L.width() * L.TILE
	var mh := L.height() * L.TILE
	var frac := 1.0 - 340.0 / maxf(vs.x, 1.0)
	var size := maxf((mh + 3.0) * 1.08, (mw + 3.0) / (aspect * frac))
	map_cam.size = size
	var wv := size * aspect
	var cx := mw * 0.5 + wv * (0.5 - frac * 0.5)
	var center := Vector3(cx, 0, mh * 0.5 + 1.0)
	map_cam.rotation_degrees = Vector3(-68, 0, 0)
	map_cam.position = center + Vector3(0, sin(deg_to_rad(68)), cos(deg_to_rad(68))) * 60.0


func _set_view(v: String) -> void:
	view = v
	var an := v == "analyst"
	map_cam.current = an
	cam.current = not an
	ui.set_analyst(an)
	_refresh_tools()


func _agent_pos() -> Vector3:
	if agent:
		return agent.global_position
	if agent_unit and agent_unit.has_meta("pup"):
		return (agent_unit.get_meta("pup") as Node3D).global_position
	return Vector3.ZERO


# ───────── الحلقة ─────────
func _physics_process(delta: float) -> void:
	if not ready_world:
		return
	if agent:
		_move_agent(delta)


func _move_agent(delta: float) -> void:
	var v2: Vector2 = ui.move
	if v2.length() < 0.05:
		v2 = ui.keys()
	if locked or view != "agent" or result != "" or ui.keypad_open() or ui.intro_open():
		v2 = Vector2.ZERO
	var mag := minf(1.0, v2.length())
	var dir := Vector3(v2.x, 0, v2.y)
	if dir.length() > 0.001:
		dir = dir.normalized()
	running = mag > 0.88 and dragging == null
	var spd := 0.0
	if mag > 0.12:
		if dragging:
			spd = 1.5
		elif running:
			spd = 4.6
		else:
			spd = lerpf(1.3, 2.7, clampf((mag - 0.12) / 0.7, 0.0, 1.0))
	agent.velocity = dir * spd
	agent.move_and_slide()
	agent.global_position.y = 0.0
	if spd > 0.1:
		agent_face = lerp_angle(agent_face, atan2(-dir.x, -dir.z), minf(1.0, delta * 12.0))
	var vis := agent_face + (PI if dragging else 0.0)
	agent_unit.rotation.y = lerp_angle(agent_unit.rotation.y, vis, minf(1.0, delta * 14.0))
	var moving := agent.get_real_velocity().length() > 0.3
	if dragging:
		agent_unit.play("drag" if moving else "c_idle", 0.2)
	elif running and moving:
		agent_unit.play("run", 0.15)
	elif moving:
		agent_unit.play("walk", 0.2, clampf(spd / 1.6, 0.7, 1.7))
	else:
		agent_unit.play("idle", 0.25)
	if s_steps.stream:
		if moving and running and not s_steps.playing:
			s_steps.play()
		elif (not moving or not running) and s_steps.playing:
			s_steps.stop()


func _process(delta: float) -> void:
	if not ready_world:
		return
	var p := _agent_pos()
	var authority := role != "analyst"
	var frozen := role == "solo" and view == "analyst" # في الوضع الفردي: العالم ينتظر وأنت عند المحلّل
	if authority and result == "" and not frozen:
		_tick_world(delta, p)
	_update_cams_visual(delta, authority and not frozen and result == "")
	_update_camera(delta, p)
	_update_markers(delta, p)
	if authority:
		_check_win()
		_update_actions()
		_update_goal()
		_send_t -= delta
		if _send_t <= 0.0 and net and role == "agent":
			_send_t = 0.1
			_send_state()
	else:
		_update_goal()
	loop_cd = maxf(0.0, loop_cd - delta)
	distract_cd = maxf(0.0, distract_cd - delta)
	if loop_left > 0.0:
		loop_left = maxf(0.0, loop_left - delta)
	_refresh_tools_tick()


func _tick_world(delta: float, p: Vector3) -> void:
	var noisy := running and agent != null and agent.get_real_velocity().length() > 3.0
	var any_chase := false
	for g in guards:
		g.tick(delta, p, disguised, noisy)
		if g.state == "chase":
			any_chase = true
	# الأجسام: من يرى زميلاً مُغمى عليه يُطلق التأهّب
	for b in guards:
		if not b.ko or b.hidden or b == dragging or b.get_meta("found", false):
			continue
		for g in guards:
			if g == b or g.ko:
				continue
			if g.check_body(b):
				b.set_meta("found", true)
				stats.found += 1
				g.investigate(b.global_position, "search")
				for o in guards:
					o.alert = 40.0
				ui.flash("وجدوا زميلهم على الأرض! الحرّاس في حالة تأهّب", Color(1, 0.5, 0.2))
				if s_alarm.stream:
					s_alarm.play()
				break
	if s_chase.stream:
		if any_chase and not s_chase.playing:
			s_chase.play()
		elif not any_chase and s_chase.playing:
			s_chase.stop()
	# السحب: الجسم يتبع العميل
	if dragging:
		var back := Vector3(-sin(agent_face), 0, -cos(agent_face))
		var want := p - back * 1.05
		dragging.global_position = dragging.global_position.lerp(want, minf(1.0, delta * 9.0))
		dragging.rotation.y = lerp_angle(dragging.rotation.y, agent_face, minf(1.0, delta * 6.0))
		dragging.heading = dragging.rotation.y
		var mv: bool = agent.get_real_velocity().length() > 0.3
		if s_drag.stream:
			if mv and not s_drag.playing:
				s_drag.play()
			elif not mv and s_drag.playing:
				s_drag.stop()
	elif s_drag.playing:
		s_drag.stop()
	# الكاميرا ترى أيّ شخص في غرفة الخزنة (حتى بالزيّ)
	for c in cams:
		if loop_left > 0.0:
			continue
		if _cam_sees(c, p):
			c.t = float(c.get("seen", 0.0)) + delta
			c["seen"] = c.t
			if float(c["seen"]) > 0.6 and not c.get("fired", false):
				c["fired"] = true
				stats.cam += 1
				ui.flash("الكاميرا رأتك! الحرّاس قادمون", Color(1, 0.3, 0.25))
				if s_alarm.stream:
					s_alarm.play()
				var near := _nearest_guards(p, 2)
				for g in near:
					g.investigate(p, "search")
					g.sus = 0.7
		else:
			c["seen"] = 0.0
			c["fired"] = false


func _nearest_guards(p: Vector3, n: int) -> Array:
	var list: Array = []
	for g in guards:
		if not g.ko:
			list.append(g)
	list.sort_custom(func(a, b): return a.global_position.distance_to(p) < b.global_position.distance_to(p))
	return list.slice(0, n)


func _cam_yaw(c: Dictionary) -> float:
	var t := Time.get_ticks_msec() / 1000.0
	var deg: float = float(c.look) + float(c.sweep) * sin(t * 0.55)
	return L.yaw_of(deg)


func _cam_sees(c: Dictionary, p: Vector3) -> bool:
	var to := p - (c.pos as Vector3)
	to.y = 0.0
	if to.length() > float(c.range):
		return false
	var yaw := _cam_yaw(c)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	if rad_to_deg(fwd.angle_to(to.normalized())) > 24.0:
		return false
	return clear_line((c.pos as Vector3) + Vector3(0, 1.9, 0), p + Vector3(0, 1.0, 0))


func _update_cams_visual(_delta: float, _live: bool) -> void:
	for c in cams:
		var im: ImmediateMesh = c.im
		im.clear_surfaces()
		var looped := loop_left > 0.0
		var col := Color(0.4, 0.75, 1.0, 0.1) if looped else Color(1.0, 0.25, 0.2, 0.2)
		if float(c.get("seen", 0.0)) > 0.0 and not looped:
			col = Color(1.0, 0.1, 0.05, 0.4)
		var o := (c.pos as Vector3) + Vector3(0, 0.07, 0)
		var yaw := _cam_yaw(c)
		var n := 14
		var pts: Array = []
		for i in n + 1:
			var a := yaw + deg_to_rad(-24.0 + 48.0 * float(i) / n)
			var d := Vector3(-sin(a), 0, -cos(a))
			pts.append(o + d * ray_dist(o + Vector3(0, 1.0, 0), d, float(c.range)))
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, c.mat)
		for i in n:
			im.surface_set_color(col)
			im.surface_add_vertex(o)
			im.surface_set_color(Color(col.r, col.g, col.b, col.a * 0.4))
			im.surface_add_vertex(pts[i])
			im.surface_set_color(Color(col.r, col.g, col.b, col.a * 0.4))
			im.surface_add_vertex(pts[i + 1])
		im.surface_end()
		var led: Node3D = c.led
		led.visible = not looped and fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.2


func _update_camera(delta: float, p: Vector3) -> void:
	_cam_zoom = lerpf(_cam_zoom, _cam_zoom_t, minf(1.0, delta * 4.0))
	var target := p + CAM_OFF * _cam_zoom
	cam.position = cam.position.lerp(target, minf(1.0, delta * 5.0))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
	var look := cam.position - CAM_OFF * _cam_zoom
	cam.look_at(look + Vector3(0, 0.6 * (1.0 - _cam_zoom), 0), Vector3.UP)


func _update_markers(delta: float, p: Vector3) -> void:
	_ring.position = p + Vector3(0, 0.05, 0)
	var goal := _goal_pos()
	_arrow.visible = goal != Vector3.INF and view == "agent" and result == ""
	if _arrow.visible:
		var to := goal - p
		to.y = 0.0
		_arrow.visible = to.length() > 2.5
		var d := to.normalized()
		_arrow.position = p + d * 1.15 + Vector3(0, 0.1, 0)
		_arrow.rotation = Vector3(-PI / 2, atan2(d.x, d.z) + PI, 0)
		_arrow.rotation_degrees.x = -90
		_arrow.basis = Basis(Vector3.UP, atan2(-d.x, -d.z)) * Basis(Vector3.RIGHT, -PI / 2)
	if _ping_t > 0.0:
		_ping_t -= delta
		_ping.visible = _ping_t > 0.0
		_ping.scale = Vector3.ONE * (1.0 + 0.15 * sin(_ping_t * 8.0))


func _show_ping(p: Vector3, send: bool) -> void:
	_ping.position = p
	_ping.visible = true
	_ping_t = 6.0
	if s_beep.stream:
		s_beep.play()
	if send:
		_send({"t": "ping", "x": snappedf(p.x, 0.1), "z": snappedf(p.z, 0.1)})


# ───────── الأهداف ─────────
func _stage() -> int:
	if has_docs:
		return 3
	if _in_vault(_agent_pos()):
		return 2
	if disguised:
		return 1
	return 0


func _in_vault(p: Vector3) -> bool:
	var rc: Rect2i = L.ROOMS[4][1]
	var c := L.cell_of(p)
	return rc.has_point(c)


func _goal_pos() -> Vector3:
	match _stage():
		0:
			return (guards[3] as Node3D).global_position
		1:
			return door_r.pos
		2:
			return safe.pos
		3:
			return L.cell_center((L.find("E")[0] as Vector2i))
	return Vector3.INF


func _update_goal() -> void:
	var s := _stage()
	if s == _goal_i:
		return
	_goal_i = s
	var texts := [
		"١. ابحث عن بدلة حارس — الحارس المستريح في غرفة الاستراحة يدير ظهره للباب",
		"٢. بالزيّ امشِ (لا تركض) نحو باب الخزنة الأحمر — والمحلّل يعطّل الكاميرا ويفتح الباب",
		"٣. افتح الخزنة بالرمز الذي عند المحلّل",
		"٤. الوثائق معك! عُد إلى الشاحنة البيضاء في الساحة",
	]
	var tips := [
		"العميل يحتاج بدلة حارس. وجّهه إلى غرفة الاستراحة وراقب دوريّة الوسط. ضع علامة بالضغط على الخريطة.",
		"العميل متنكّر. عطّل الكاميرا قبل أن يدخل، ثم افتح باب الخزنة الأحمر.",
		"أمْلِ الرمز على العميل. انتبه للكاميرا.",
		"راقب الطريق إلى الشاحنة وحذّر العميل من الدوريات.",
	]
	ui.set_goal(texts[s])
	ui.set_analyst_info(tips[s])
	if s > 0 and not smoke:
		ui.flash(["", "تنكّرت! الحرّاس لن يشكّوا ما دمت تمشي بهدوء", "دخلت غرفة الخزنة", "حصلت على الوثائق! اهرب الآن"][s], Color(0.5, 1.0, 0.6))


# ───────── الأفعال ─────────
var _act_a := ""
var _act_b := ""
var _act_target: Node3D = null


func _update_actions() -> void:
	if locked or result != "" or view != "agent":
		ui.set_action("")
		return
	var p := _agent_pos()
	_act_a = ""
	_act_b = ""
	_act_target = null
	if dragging:
		var lk = _near_locker(p)
		if lk != null:
			_act_a = "hide"
		_act_b = "drop"
	else:
		for g in guards:
			if g.is_behind(p) and not g.ko:
				_act_a = "ko"
				_act_target = g
				break
		if _act_a == "":
			for g in guards:
				if g.ko and not g.hidden and g.global_position.distance_to(p) < 1.8:
					_act_target = g
					if not disguised and not g.stripped:
						_act_a = "suit"
						_act_b = "drag"
					else:
						_act_a = "drag"
					break
		if _act_a == "" and not safe_open and p.distance_to(safe.pos) < 2.1:
			_act_a = "safe"
	var names := {"ko": "أسقطه", "suit": "خذ\nبدلته", "drag": "اسحبه", "drop": "اتركه", "hide": "في\nالخزانة", "safe": "افتح\nالخزنة"}
	ui.set_action(str(names.get(_act_a, "")), str(names.get(_act_b, "")))
	# باب الخزنة مغلق؟
	_warned_door -= get_process_delta_time()
	if not bool(door_r.open) and p.distance_to(door_r.pos) < 2.6 and _warned_door <= 0.0:
		_warned_door = 6.0
		ui.flash("الباب الأحمر مغلق إلكترونياً — " + ("بدّل إلى المحلّل وافتحه" if role == "solo" else "اطلب من المحلّل فتحه"), Color(1, 0.75, 0.3))


func _do_act(second: bool) -> void:
	if locked or result != "" or view != "agent":
		return
	var a := _act_b if second else _act_a
	var g = _act_target
	match a:
		"ko":
			_takedown(g)
		"suit":
			_strip(g)
		"drag":
			dragging = g
			ui.flash("تسحبه — ابحث عن خزانة زرقاء", Color(0.8, 0.9, 1.0), 2.0)
		"drop":
			dragging = null
		"hide":
			_stuff_locker()
		"safe":
			ui.open_keypad()


func _near_locker(p: Vector3):
	for lk in lockers:
		if not lk.used and (lk.pos as Vector3).distance_to(p) < 2.3:
			return lk
	return null


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs if not smoke else 0.02, true, false, true).timeout


func _takedown(g) -> void:
	locked = true
	g.sus = 0.0
	g.state = "wait"
	var gp: Vector3 = g.global_position
	var back := -(g.forward() as Vector3)
	var spot := gp + back * 0.7
	var to := gp - spot
	agent_face = atan2(-to.x, -to.z)
	agent_unit.rotation.y = agent_face
	var tw := create_tween()
	tw.tween_property(agent, "global_position", spot, 0.12)
	_cam_zoom_t = 0.42
	agent_unit.one_shot("hook", 1.1)
	await _wait(0.32)
	if not smoke:
		Engine.time_scale = 0.35
	if s_punch.stream:
		s_punch.play()
	ui.fade(0.4, 0.03, Color.WHITE)
	g.knock_out()
	stats.ko += 1
	_shake = 0.5
	Input.vibrate_handheld(110)
	await _wait(0.05)
	ui.fade(0.0, 0.2, Color.WHITE)
	await _wait(0.35)
	Engine.time_scale = 1.0
	await _wait(0.6)
	_cam_zoom_t = 1.0
	locked = false
	if not smoke:
		ui.flash("أسقطته! خذ بدلته أو اسحبه إلى خزانة قبل أن يراه أحد", Color(1, 0.88, 0.55))


func _strip(g) -> void:
	locked = true
	var to: Vector3 = g.global_position - agent.global_position
	to.y = 0.0
	if to.length() > 0.1:
		agent_face = atan2(-to.x, -to.z)
		agent_unit.rotation.y = agent_face
	_cam_zoom_t = 0.5
	agent_unit.one_shot("pick", 2.0)
	if s_cloth.stream:
		s_cloth.play()
	await _wait(0.9)
	ui.fade(0.9, 0.2)
	await _wait(0.25)
	g.stripped = true
	g.unit.skin_look()
	disguised = true
	_set_agent_model(true)
	agent_unit.rotation.y = agent_face
	ui.fade(0.0, 0.35)
	await _wait(0.5)
	_cam_zoom_t = 1.0
	locked = false


func _stuff_locker() -> void:
	var lk = _near_locker(_agent_pos())
	var g = dragging
	if lk == null or g == null:
		return
	locked = true
	dragging = null
	lk.used = true
	var front: Vector3 = lk.front
	var lpos: Vector3 = lk.pos
	var stand := lpos + front * 1.25
	agent.global_position = stand
	agent_face = atan2(front.x, front.z)
	agent_unit.rotation.y = agent_face
	g.global_position = stand + front.rotated(Vector3.UP, PI / 2.0) * 0.9
	_cam_zoom_t = 0.5
	agent_unit.one_shot("open", 1.0)
	await _wait(0.35)
	if s_door.stream:
		s_door.play()
	var pivot: Node3D = lk.pivot
	var tw := create_tween()
	tw.tween_property(pivot, "rotation:y", deg_to_rad(-110), 0.01 if smoke else 0.35)
	await _wait(0.45)
	agent_unit.one_shot("pick", 1.0)
	var tw2 := create_tween()
	tw2.tween_property(g, "global_position", lpos + Vector3(0, 0.05, 0), 0.01 if smoke else 0.5)
	await _wait(0.6)
	g.hidden = true
	g.visible = false
	var tw3 := create_tween()
	tw3.tween_property(pivot, "rotation:y", 0.0, 0.01 if smoke else 0.25)
	await _wait(0.3)
	if s_click.stream:
		s_click.play()
	_shake = 0.15
	await _wait(0.3)
	_cam_zoom_t = 1.0
	locked = false
	if not smoke:
		ui.flash("الجسم في الخزانة — لن يجده أحد", Color(0.5, 1.0, 0.6))


func _on_code(c: String) -> void:
	if c != code:
		ui.keypad_wrong()
		return
	ui.close_keypad()
	_open_safe()


func _open_safe() -> void:
	if safe_open:
		return
	safe_open = true
	locked = true
	if s_vault.stream:
		s_vault.play()
	var tw := create_tween()
	tw.tween_property(safe.pivot, "rotation:y", deg_to_rad(-120), 0.01 if smoke else 0.8)
	agent_unit.one_shot("pick", 1.4)
	await _wait(1.0)
	(safe.docs as Node3D).visible = false
	has_docs = true
	locked = false


# ───────── المحلّل ─────────
func _on_tool_btn(kind: String) -> void:
	match kind:
		"distract":
			if distract_cd > 0.0:
				return
			distract_mode = true
			ui.flash("اضغط على مكان في الخريطة: أقرب حارس يذهب ليتفقّده", Color(0.6, 0.85, 1.0), 2.5)
		"loop":
			_tool("loop", Vector3.ZERO)
		"door":
			_tool("door", Vector3.ZERO)


func _tool(k: String, p: Vector3) -> void:
	if role == "analyst":
		_send({"t": "tool", "k": k, "x": snappedf(p.x, 0.1), "z": snappedf(p.z, 0.1)})
		# صدى فوري عند المحلّل (العميل يؤكّد عبر الحالة)
		if k == "loop" and loop_cd <= 0.0:
			loop_left = 20.0
			loop_cd = 45.0
		elif k == "distract":
			distract_cd = 15.0
		elif k == "door":
			set_door(not bool(door_r.open))
	else:
		_do_tool(k, p)


func _do_tool(k: String, p: Vector3) -> void:
	match k:
		"loop":
			if loop_cd <= 0.0:
				loop_left = 20.0
				loop_cd = 45.0
				if view == "agent":
					ui.flash("المحلّل عطّل الكاميرا 20 ثانية", Color(0.5, 0.85, 1.0))
		"door":
			set_door(not bool(door_r.open))
			if view == "agent":
				ui.flash("المحلّل " + ("فتح" if door_r.open else "أغلق") + " باب الخزنة", Color(0.5, 1.0, 0.6))
		"distract":
			distract_cd = 15.0
			var best = null
			var bd := 14.0
			for g in guards:
				if g.ko or g.state == "chase":
					continue
				var d: float = g.global_position.distance_to(p)
				if d < bd:
					bd = d
					best = g
			if best:
				best.investigate(p, "search")
				best.set("_search_t", 6.0)
				if view == "agent":
					ui.flash("المحلّل شتّت " + str(best.gname), Color(0.5, 0.85, 1.0), 2.0)


func _on_map_tap(sp: Vector2) -> void:
	if view != "analyst":
		return
	var from := map_cam.project_ray_origin(sp)
	var dir := map_cam.project_ray_normal(sp)
	if absf(dir.y) < 0.001:
		return
	var t := -from.y / dir.y
	var p := from + dir * t
	if distract_mode:
		distract_mode = false
		_tool("distract", p)
		_show_ping(p, false)
		return
	# الضغط على الباب الأحمر أو الكاميرا مباشرة
	if p.distance_to(door_r.pos) < 1.6:
		_tool("door", p)
		return
	for c in cams:
		if p.distance_to(c.pos) < 1.6:
			_tool("loop", p)
			return
	_show_ping(p, role == "analyst")


func _refresh_tools() -> void:
	_refresh_tools_tick()


func _refresh_tools_tick() -> void:
	if ui == null or view != "analyst":
		return
	if loop_left > 0.0:
		ui.set_tool("loop", "📷 الكاميرا معطّلة: %d ث" % int(ceil(loop_left)), false)
	elif loop_cd > 0.0:
		ui.set_tool("loop", "📷 جاهزة بعد %d ث" % int(ceil(loop_cd)), false)
	else:
		ui.set_tool("loop", "📷 تعطيل الكاميرا", true)
	if distract_cd > 0.0:
		ui.set_tool("distract", "📻 جاهز بعد %d ث" % int(ceil(distract_cd)), false)
	else:
		ui.set_tool("distract", "📻 اضغط هنا ثم على مكان" if distract_mode else "📻 تشتيت حارس", true)
	ui.set_tool("door", "🚪 أغلق باب الخزنة" if bool(door_r.open) else "🚪 افتح باب الخزنة", true)


# ───────── المزامنة ─────────
func _send_state() -> void:
	var gl: Array = []
	for g in guards:
		gl.append(g.net_state())
	var p := _agent_pos()
	_send({"t": "s", "a": [snappedf(p.x, 0.01), snappedf(p.z, 0.01), snappedf(agent_unit.rotation.y, 0.01), agent_unit.clip, disguised],
		"g": gl, "door": bool(door_r.open), "loop": snappedf(loop_left, 0.1), "lcd": snappedf(loop_cd, 0.1), "dcd": snappedf(distract_cd, 0.1),
		"safe": safe_open, "docs": has_docs, "lk": lockers.map(func(l): return l.used)})


func _apply_state(m: Dictionary) -> void:
	var a = m.get("a", [])
	if typeof(a) == TYPE_ARRAY and a.size() >= 5:
		var d := bool(a[4])
		if d != disguised:
			disguised = d
			_set_agent_model(d)
		var pup: Node3D = agent_unit.get_meta("pup")
		var target := Vector3(float(a[0]), 0, float(a[1]))
		pup.global_position = pup.global_position.lerp(target, 0.6)
		agent_unit.rotation.y = float(a[2])
		agent_unit.play(str(a[3]))
	var gl = m.get("g", [])
	if typeof(gl) == TYPE_ARRAY:
		for i in mini(gl.size(), guards.size()):
			var e = gl[i]
			if typeof(e) == TYPE_ARRAY and e.size() >= 6:
				guards[i].apply_net(e)
	set_door(bool(m.get("door", false)))
	loop_left = float(m.get("loop", 0.0))
	loop_cd = float(m.get("lcd", loop_cd))
	distract_cd = float(m.get("dcd", distract_cd))
	if bool(m.get("safe", false)) and not safe_open:
		safe_open = true
		(safe.pivot as Node3D).rotation.y = deg_to_rad(-120)
	if bool(m.get("docs", false)) and not has_docs:
		has_docs = true
		(safe.docs as Node3D).visible = false


# ───────── الفوز والخسارة ─────────
func on_chase_start(_g) -> void:
	stats.spotted += 1
	if not smoke:
		ui.flash("كشفك الحارس! اهرب واختبئ خلف الجدران", Color(1, 0.3, 0.25), 2.5)


func on_caught(_g) -> void:
	if result != "" or smoke:
		return
	_finish(false, "أمسك بك الحارس", ["اختبئ عن مجال الرؤية، أو تنكّر قبل أن تمرّ بينهم."], 0)


func _check_win() -> void:
	if has_docs and result == "" and _agent_pos().distance_to(L.cell_center((L.find("E")[0] as Vector2i))) < 2.6:
		var secs := Time.get_ticks_msec() / 1000.0 - float(stats.t0)
		var stars := 1
		var clean := int(stats.spotted) == 0 and int(stats.cam) == 0
		if clean:
			stars += 1
		if int(stats.found) == 0:
			stars += 1
		var lines := [
			"الوقت: %d:%02d" % [int(secs) / 60, int(secs) % 60],
			"✔ لم يكشفك أحد" if clean else "✖ كُشفتَ %d مرّة" % (int(stats.spotted) + int(stats.cam)),
			"✔ لم يُعثر على أيّ جسم" if int(stats.found) == 0 else "✖ عُثر على جسم",
		]
		Levels.save_best("port", stars, secs)
		_finish(true, "نجحت المهمّة!", lines, stars)


func _finish(won: bool, why: String, lines: Array, stars: int) -> void:
	if result != "":
		return
	result = "win" if won else "fail"
	locked = true
	if s_chase.playing:
		s_chase.stop()
	if role == "agent":
		_send({"t": "end", "won": won, "why": why, "lines": lines, "stars": stars})
	ui.end_screen(won, why, lines, stars)


func _retry(tell: bool) -> void:
	if tell and net:
		_send({"t": "retry"})
	persist = {"role": role, "seed": seed_value, "code": room_code, "host": host_role}
	if net == null:
		persist = {"role": "solo", "seed": randi() % 100000}
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# ───────── أدوات عامة (يستعملها الحرّاس) ─────────
func clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, LAYER_SIGHT)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func ray_dist(o: Vector3, dir: Vector3, r: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(o, o + dir * r, LAYER_SIGHT)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return r
	return o.distance_to(hit.position)


func find_path(from: Vector3, to: Vector3) -> Array:
	var a := L.cell_of(from)
	var b := L.cell_of(to)
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b):
		return [to]
	if astar.is_point_solid(b):
		# أقرب خانة حرّة للهدف
		var best := b
		var bd := 999.0
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var c := b + Vector2i(dx, dy)
				if astar.is_in_boundsv(c) and not astar.is_point_solid(c) and Vector2(dx, dy).length() < bd:
					bd = Vector2(dx, dy).length()
					best = c
		b = best
	if astar.is_point_solid(a):
		return [to]
	var pts := astar.get_point_path(a, b)
	var out: Array = []
	for i in pts.size():
		if i == 0:
			continue
		out.append(Vector3(pts[i].x, 0, pts[i].y))
	if L.walkable(L.cell_of(to)) and not astar.is_point_solid(L.cell_of(to)):
		if out.is_empty():
			out.append(to)
		else:
			out[out.size() - 1] = Vector3(to.x, 0, to.z)
	return out


# ───────── اختبار تلقائي (GitHub) + لقطات شاشة ─────────
func _shot(n: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("KHAZNA_SHOT_DIR")
	if dir == "":
		dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(n + ".png"))
	print("SHOT ", n)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scenario() -> void:
	while not ready_world:
		await get_tree().process_frame
	await _frames(20)
	var ok := true
	print("SMOKE world guards=%d lockers=%d cams=%d code=%s" % [guards.size(), lockers.size(), cams.size(), code])
	var vch: String = preload("res://voice.gd").channel_for("1234")
	if RegEx.create_from_string("^khazna-[0-9]{4}-[0-9a-f]{8}$").search(vch):
		print("SMOKE voice channel ok ", vch)
	await _shot("01_agent_start")
	# التحكّم: العصا لليمين تحرّك العميل يميناً
	var p0 := agent.global_position
	ui.move = Vector2(0.6, 0)
	for i in 30:
		await get_tree().physics_frame
	ui.move = Vector2.ZERO
	var moved := agent.global_position - p0
	print("SMOKE move dx=%.2f dz=%.2f" % [moved.x, moved.z])
	if moved.x > 0.8 and absf(moved.z) < 0.3:
		print("SMOKE move ok")
	else:
		ok = false
	_set_view("analyst")
	await _frames(5)
	await _shot("02_analyst_map")
	_set_view("agent")
	# الحارس يكتشف العميل غير المتنكّر أمامه
	var yard = guards[0]
	yard.set_process(true)
	var gp: Vector3 = yard.global_position
	agent.global_position = gp + (yard.forward() as Vector3) * 3.0
	await get_tree().create_timer(0.8).timeout
	print("SMOKE detect sus=%.2f state=%s" % [yard.sus, yard.state])
	if yard.sus > 0.3:
		print("SMOKE detect ok")
	else:
		ok = false
	yard.sus = 0.0
	yard.state = "patrol"
	await _shot("03_detected")
	# الإسقاط: خلف الحارس المستريح
	var rest = guards[3]
	agent.global_position = rest.global_position - (rest.forward() as Vector3) * 1.2
	await _frames(4)
	_update_actions()
	print("SMOKE behind act=", _act_a)
	await _shot("04_behind_guard")
	if _act_a != "ko":
		ok = false
	if shots:
		_takedown_shot(rest)
		await get_tree().create_timer(0.45, true, false, true).timeout
		await _shot("05_takedown")
		await get_tree().create_timer(2.0).timeout
	else:
		await _takedown(rest)
	print("SMOKE ko=", rest.ko)
	if not rest.ko:
		ok = false
	await _frames(10)
	await _shot("06_knocked_out")
	_update_actions()
	print("SMOKE after ko act=%s/%s" % [_act_a, _act_b])
	await _strip(rest)
	print("SMOKE disguised=", disguised, " stripped=", rest.stripped)
	if not (disguised and rest.stripped):
		ok = false
	await _frames(10)
	await _shot("07_disguised")
	_update_actions()
	dragging = rest
	agent.global_position = (lockers[1].pos as Vector3) + (lockers[1].front as Vector3) * 2.4
	await get_tree().create_timer(0.5).timeout
	await _shot("08_dragging")
	agent.global_position = (lockers[1].pos as Vector3) + (lockers[1].front as Vector3) * 1.3
	await _frames(3)
	_update_actions()
	print("SMOKE drag act=", _act_a)
	await _stuff_locker()
	print("SMOKE hidden=", rest.hidden, " used=", lockers[1].used)
	if not rest.hidden:
		ok = false
	await _frames(5)
	# التنكّر: حارس المكتب لا يشكّ في العميل الماشي بالزيّ
	var off = guards[4]
	agent.global_position = L.cell_center(Vector2i(22, 9))
	await get_tree().create_timer(1.2).timeout
	print("SMOKE office sus=%.2f" % off.sus)
	if off.sus < 0.2:
		print("SMOKE disguise ok")
	else:
		ok = false
	await _shot("09_office_disguised")
	# الكاميرا تكشف في غرفة الخزنة، والتعطيل يمنعها
	_do_tool("door", Vector3.ZERO)
	await _frames(30)
	var dpath := find_path(L.cell_center(Vector2i(23, 7)), L.cell_center(Vector2i(23, 3)))
	print("SMOKE door open=%s path=%d" % [door_r.open, dpath.size()])
	if bool(door_r.open) and dpath.size() > 0:
		print("SMOKE door ok")
	else:
		ok = false
	agent.global_position = (safe.pos as Vector3) + (safe.front as Vector3) * 1.3
	var seen_any := false
	var t_end := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
		if cams[0].get("fired", false):
			seen_any = true
			break
	_do_tool("loop", Vector3.ZERO)
	cams[0]["fired"] = false
	cams[0]["seen"] = 0.0
	var seen_loop := false
	t_end = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
		if cams[0].get("fired", false):
			seen_loop = true
	print("SMOKE cam seen=%s looped_seen=%s" % [seen_any, seen_loop])
	if seen_any and not seen_loop:
		print("SMOKE cam ok")
	else:
		ok = false
	for g in guards:
		if not g.ko:
			g.sus = 0.0
			g.state = "back"
	_update_actions()
	print("SMOKE safe act=", _act_a)
	ui.open_keypad()
	await _frames(3)
	await _shot("10_keypad")
	ui.close_keypad()
	_on_code("0000" if code != "0000" else "1111")
	var wrong_ok := not safe_open
	_on_code(code)
	await get_tree().create_timer(1.2 if shots else 0.2).timeout
	print("SMOKE safe wrong_rejected=%s docs=%s" % [wrong_ok, has_docs])
	if has_docs and wrong_ok:
		print("SMOKE safe ok")
	else:
		ok = false
	await _shot("11_docs")
	agent.global_position = L.cell_center((L.find("E")[0] as Vector2i)) + Vector3(1.0, 0, -1.6)
	await _frames(10)
	print("SMOKE result=", result)
	if result == "win":
		print("SMOKE win ok")
	else:
		ok = false
	await _frames(10)
	await _shot("12_win")
	print("SMOKE all ok" if ok else "SMOKE FAILED")
	get_tree().quit()


func _takedown_shot(g) -> void:
	await _takedown(g)
