# «الخزنة 3D» — لعب تعاوني بين هاتفين.
# العميل يتسلّل في مبنى الميناء (ثلاث غرف + حجرة الكنز)، والمحلّل في غرفة أرشيف مظلمة بعيدة:
# يرى العميل والحرّاس على شاشات المراقبة، ويجد نصف كل حلّ في الأدراج والدليل والحاسوب.
# العميل يملك تقدّم المهمّة ويرسله؛ المحلّل يعكسه. الحرّاس يتحرّكون محلياً عند الاثنين.
extends Node3D

const WALL_H := 3.2
var SPAWN := Vector3(2.0, 0.0, 6.0)
var ARCHIVE := Vector3(100.0, 0.0, 0.0) # ركن غرفة المحلّل
const ESCAPE_SECONDS := 50.0
const MISSION_SECONDS := 720.0
const SYMBOLS := ["▲", "●", "■", "★", "◆", "✚"]
const WIRES := [
	["أحمر", Color(0.85, 0.15, 0.15)], ["أزرق", Color(0.2, 0.42, 0.95)], ["أصفر", Color(0.95, 0.8, 0.15)],
	["أخضر", Color(0.2, 0.72, 0.3)], ["أبيض", Color(0.92, 0.92, 0.92)],
]
const VAULT_C := Vector3(27.5, 0.0, 5.0) # دائرة الوقوف أمام الخزنة (في إحداثيات الخزنة الأصلية)
var VAULT_FRONT := VAULT_C
# ───── بيانات الخريطة (قيم الميناء؛ كل خريطة تغيّرها في maps.gd) ─────
var vault_xf := Transform3D.IDENTITY # مكان الخزنة وحجرة الكنز واتّجاهها
var spawn_yaw := -PI / 2.0
var analyst_spawn := Vector3(105.0, 0.0, 6.2)
var analyst_yaw := 0.0
var term_specs: Array = [[Vector3(7.4, 0, 1.3), 1.0, "لوحة الأرقام"], [Vector3(19.4, 0, 8.7), -1.0, "لوحة الأسلاك"]]
var door_specs: Array = [[Vector3(8, 0, 4.5), 0.0, Vector3(1, 0, 0)], [Vector3(20, 0, 5), 0.0, Vector3(1, 0, 0)]]
var checkpoints: Array = [Vector3(2, 0, 6), Vector3(9.2, 0, 4.5), Vector3(21.2, 0, 5)]
var guard_routes: Array = [
	[[Vector3(9.5, 0, 8.6), Vector3(18.5, 0, 8.6), Vector3(18.5, 0, 1.3), Vector3(9.5, 0, 1.3)], 1.25, Rect2(8.5, 0.5, 11.0, 9.0)],
	[[Vector3(22, 0, 8.2), Vector3(27.2, 0, 8.2), Vector3(27.2, 0, 1.6), Vector3(22, 0, 1.6)], 1.0, Rect2(20.5, 0.5, 8.6, 9.0)],
	[[Vector3(18.5, 0, 1.3), Vector3(18.5, 0, 8.6), Vector3(9.5, 0, 8.6), Vector3(9.5, 0, 1.3)], 1.1, Rect2(8.5, 0.5, 11.0, 9.0)],
]
var reach_rect := Rect2(0, 0, 30, 10)
var feed_cams: Array = [
	[Vector3(0.6, 2.9, 0.6), Vector3(5, 0.8, 5), "كاميرا 1 · المدخل"],
	[Vector3(8.6, 2.9, 9.4), Vector3(15, 0.6, 3), "كاميرا 2 · المخزن"],
	[Vector3(20.6, 2.9, 0.6), Vector3(28, 0.8, 6), "كاميرا 3 · الخزنة"],
]
var alarm_spots: Array = [Vector3(4, 3.0, 4), Vector3(14, 3.0, 5), Vector3(25, 3.0, 5)]
var gate_types: Array = ["keypad", "wires"] # نوع لغز كل بوّابة
var analyst_kind := "archive" # archive | cabin | hut
const Levels := preload("res://levels.gd")
const LCOLORS := [["أحمر", Color(0.85, 0.15, 0.12)], ["أزرق", Color(0.15, 0.4, 0.9)], ["أخضر", Color(0.2, 0.7, 0.3)], ["أصفر", Color(0.95, 0.8, 0.2)]]
var KILL_POS := Vector3(8.3, 0.0, 1.2) # قاطع الليزر
const LASER_OFF := 20.0

var role := "solo" # agent | analyst | solo
var level_i := 1
var lv: Dictionary = {}
var lasers: Array = []
var cctvs: Array = []
var htime := 0.0 # زمن العوائق المشترك (الليزر والكاميرات)
var kill_node: Node3D
var kill_lamp: OmniLight3D
var laserdoc_node: Node3D
var _laser_cd := 0.0
var _laser_warned := false
var _beep_t := 0.0
var s_beep: AudioStreamPlayer
var s_hazard_amb: AudioStreamPlayer
var _tut := 0
var _tut_moved := 0.0
var _breath_t := 3.0
var breath: CPUParticles3D
var maps # بنّاء خرائط النهر والجبل (maps.gd)
# ───── ألغاز النهر والجبل ─────
const VALVE_TAGS := [["صمّام أحمر", Color(0.95, 0.35, 0.3)], ["صمّام أزرق", Color(0.4, 0.6, 1.0)], ["صمّام أصفر", Color(1.0, 0.85, 0.3)], ["صمّام أخضر", Color(0.4, 0.9, 0.5)]]
const GAUGE_NAMES := ["أنبوب A", "أنبوب B", "أنبوب C", "أنبوب D"]
const MORSE := {"0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-", "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----."}
var valves := [0, 0, 0, 0]
var radio_cur := 150.0
var _radio_open := false
var _gauges_open := false
var _bp_open := false
var _bp_t := 0.0
var _dark_warned := false
var _gauge_t := 0.0
var _morse_units: Array = []
var s_morse: AudioStreamPlayer
var _morse_pb: AudioStreamGeneratorPlayback
var _morse_phase := 0.0
var analyst_targets: Array = [] # ما يضيء للمحلّل في كل مرحلة
var analyst_dark := false
var analyst_locked := 0.0
var binoc := false
var cabin_lights: Array = []
var _patrol_warned := false
var sync_go := -1.0
var sync_a := -1.0
var sync_b := -1.0
# ───── Hitman ─────
var disguised := false
var has_card := false # بطاقة الدخول (الباب الأول)
var has_chief_card := false # بطاقة الرئيس (الباب الثاني)
var cans := 0
var can_nodes: Array = []
var drag_g = null # الحارس الذي يُسحب
var hide_spots: Array = [] # [موضع، اسم]
var instinct_t := 0.0
var instinct_cd := 0.0
var _act := "" # الفعل الأساسي القريب (زرّ التفاعل)
var _act2 := "" # الفعل الثاني
var _act_g = null
var stats := {"seen": 0, "ko": 0, "found": 0, "start": 0.0}
var _found_alarm := false
var _tip_t := 0.0
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
var room_code := ""
var voice
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
var dial_entered: Array = [] # الأرقام الصحيحة المؤكَّدة
var s_clunk: AudioStreamPlayer
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
var shake := 0.0
var vault_lamp: OmniLight3D
var vault_barrier: StaticBody3D
var vault_ring: MeshInstance3D
var ready_world := false
var building_lights: Array = []
var feed_mats: Array = []
var _fear_t := 120.0
var _creep_t := 25.0
var _glitch_t := 30.0
var blackout := 0.0
var shutters_closed: Array = [false, false]
var s_creep: AudioStreamPlayer3D
var s_music: AudioStreamPlayer
var tool_cd := {"mark": 0.0, "distract": 0.0, "freeze": 0.0, "blackout": 0.0, "warn": 0.0}
const TOOL_CD := {"mark": 20.0, "distract": 20.0, "freeze": 30.0, "blackout": 35.0, "warn": 5.0}
var steam: CPUParticles3D
var _prop_log: Array = []
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
	menu.solo.connect(func():
		level_i = menu.level
		_start("solo", randi() % 1000000))
	menu.host.connect(func(r):
		level_i = menu.level
		_host(r))
	menu.join.connect(_join)
	# اختبار التشغيل في GitHub: يبدأ الوضع الفردي مباشرة ويجرّب الألغاز
	if OS.get_environment("KHAZNA_SMOKE") == "1":
		var lid := OS.get_environment("KHAZNA_LEVEL")
		level_i = Levels.index_of(lid if lid != "" else "port")
		_start("solo", 1234)
		_smoke.call_deferred()
	elif _deep_link_code() != "":
		# فُتحت من تطبيق الخزنة الأصلي مع كود غرفة: انضمام مباشر
		_join(_deep_link_code())
	elif Levels.pending >= 0:
		# «المرحلة التالية» من شاشة الفوز
		level_i = Levels.pending
		Levels.pending = -1
		_start("solo", randi() % 1000000)


## كود الغرفة من رابط khazna3d://join?code=1234 (أندرويد فقط).
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


func _smoke() -> void:
	while not ready_world:
		await get_tree().process_frame
	hud.close_panel()
	await get_tree().create_timer(0.5).timeout
	print("SMOKE level: ", lv.id, " guards=", guards.size(), " lasers=", lasers.size(), " cams=", cctvs.size())
	await _smoke_hazards()
	if lv.id == "port":
		await _smoke_hitman()
	print("SMOKE agent clip=", agent.body.clip, " has_run=", agent.body.has_clip("run"), " has_crouch=", agent.body.has_clip("c_left"), " has_hook=", agent.body.has_clip("hook"))
	var space := get_world_3d().direct_space_state
	var sh := SphereShape3D.new()
	sh.radius = 0.25
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.exclude = [agent.get_rid()]
	var solid := true
	for pnt in [Vector3(29.62, 1.2, 5), Vector3(29.9, 1.5, 3.7), Vector3(29.9, 1.5, 6.3), Vector3(29.9, 0.4, 4.0), Vector3(29.9, 2.6, 6.0), Vector3(29.62, 0.5, 5.6)]:
		q.transform = Transform3D(Basis(), vault_xf * pnt)
		if space.intersect_shape(q, 1).is_empty():
			solid = false
			print("SMOKE hole at ", pnt)
	q.transform = Transform3D(Basis(), vault_xf * Vector3(27.5, 1.2, 5))
	var front_free := space.intersect_shape(q, 1).is_empty()
	q.transform = Transform3D(Basis(), vault_xf * Vector3(28.45, 1.2, 5))
	var barrier := not space.intersect_shape(q, 1).is_empty()
	if solid and front_free and barrier:
		print("SMOKE vault solid ok")
	await _smoke_gate(0)
	await _smoke_gate(1)
	print("SMOKE stage after puzzles: ", stage, " gates=", gate_types)
	print("SMOKE guard: ", guards[0].debug)
	await get_tree().create_timer(1.0).timeout
	var pose_s := str(guards[0].pose_report())
	print("SMOKE pose: ", pose_s)
	if pose_s.contains("moved=true"):
		print("SMOKE guard animated ok")
	for pr in _prop_log:
		print("SMOKE prop: ", pr)
	await get_tree().create_timer(2.4).timeout
	var r := _reach_test()
	print("SMOKE reach: ", r)
	if r.spawn and r.t0 and r.t1 and r.vault:
		print("SMOKE reach ok")
	_on_switch()
	analyst.set_meta("looking", analyst_targets[0])
	_analyst_interact()
	_analyst_interact()
	print("SMOKE symbols: ", _check_symbols(puzzle.symbols.duplicate()))
	_on_tool("mark")
	_on_tool("distract")
	_on_tool("warn")
	var st0: String = guards[0].state_name()
	var g0 = guards[guards.size() - 1]
	g0.remote = true
	g0.apply_remote(Vector3(12, 0, 5), 1.0, "alert")
	await get_tree().create_timer(0.6).timeout
	if (g0.global_position as Vector3).distance_to(Vector3(12, 0, 5)) < 0.2 and g0.state_name() == "alert":
		print("SMOKE sync ok")
	g0.remote = false
	print("SMOKE tools ok ", st0)
	var vch: String = preload("res://voice.gd").channel_for("1234")
	var rx := RegEx.create_from_string("^khazna-\\d{4}(-[a-f0-9]{8})?$")
	if rx.search(vch) and vch == preload("res://voice.gd").channel_for("1234") and vch != preload("res://voice.gd").channel_for("1235"):
		print("SMOKE voice channel ok ", vch)
	hud.close_panel()
	_on_switch()
	# الإمساك أمام القرص ثم إكمال المهمّة
	agent.global_position = VAULT_FRONT
	_enter_vault()
	await get_tree().create_timer(0.7).timeout
	_spotted()
	await get_tree().create_timer(0.2).timeout
	if not vault_mode and agent.cam_ok():
		print("SMOKE caught ok")
	agent.global_position = VAULT_FRONT
	_enter_vault()
	var c: Array = puzzle.combo
	dial_number = (int(c[0]) + 1) % 40
	_dial_confirm() # خطأ مقصود: يبقى أمام القرص
	if vault_mode and dial_entered.is_empty():
		print("SMOKE wrong stays ok")
	for n in c:
		dial_number = int(n)
		_dial_confirm()
	if sync_go > 0.0:
		# القفل الزمني: نضغط في النافذة
		while htime < sync_go + 0.2:
			await get_tree().process_frame
		_sync_press()
		while sync_go > 0.0:
			await get_tree().process_frame
		print("SMOKE sync lock ok")
	await get_tree().create_timer(3.5).timeout
	print("SMOKE final stage: ", stage, " escape: ", escape_left, " door=", rad_to_deg(vault_pivot.rotation.y))
	get_tree().quit()


## يتحقّق أن العميل يستطيع المشي من البداية إلى كل جهاز وإلى الخزنة (بعد فتح الأبواب).
## يضع العميل أمام جهاز المرحلة ويضغط التفاعل (كما يفعل اللاعب).
func _on_gate_smoke() -> void:
	_act = ""
	agent.global_position = terminals[stage].pos + Vector3(0, 0, 0.9)
	var keep := _act
	_on_interact()
	_act = keep


## اختبار Hitman: إسقاط من الخلف، سرقة البطاقة، التنكّر، السحب والإخفاء، والرمي.
func _smoke_hitman() -> void:
	var g = guards[0]
	var gp: Vector3 = g.global_position
	var back: Vector3 = (g.global_transform.basis.z as Vector3).normalized()
	agent.global_position = gp + back * 1.0
	await get_tree().physics_frame
	_hitman_update(0.016)
	var saw_ko: bool = _act.begins_with("👊")
	var had_card: bool = g.has_card
	if _act2.begins_with("🤏"):
		_do_act(true)
	var card_ok: bool = (not had_card) or has_card or has_chief_card
	_takedown(g)
	await get_tree().create_timer(0.5).timeout
	var ko_ok: bool = g.ko and g.state_name() == "ko"
	agent.global_position = g.global_position + Vector3(0.6, 0, 0)
	_hitman_update(0.016)
	var strip_ok: bool = _act.begins_with("👕")
	_do_act(false)
	var dis_ok: bool = disguised and agent.body.disguised
	_hitman_update(0.016)
	_do_act(false) # اسحب
	var drag_ok: bool = drag_g == g and agent.dragging
	if hide_spots.size() > 0:
		agent.global_position = (hide_spots[0][0] as Vector3) + Vector3(0.9, 0, 0)
		for k in 5:
			await get_tree().process_frame
		_hitman_update(0.016)
		_do_act(false)
	var hide_ok: bool = g.hidden and drag_g == null
	# الرمي: حارس قريب يذهب ليفحص الصوت
	cans = 1
	var other = guards[1] if guards.size() > 1 else null
	if other:
		agent.global_position = (other.global_position as Vector3) + Vector3(3.5, 0, 0)
		agent.yaw = PI / 2.0
		await get_tree().physics_frame
		await _do_throw()
	var throw_ok: bool = cans == 0 and (other == null or other.state_name() == "investigate" or other.state_name() == "search")
	disguised = false
	agent.body.set_disguised(false)
	print("SMOKE hitman sawko=", saw_ko, " card=", card_ok, " ko=", ko_ok, " strip=", strip_ok, " disguise=", dis_ok, " drag=", drag_ok, " hide=", hide_ok, " throw=", throw_ok, " body=", agent.body.debug)
	if saw_ko and card_ok and ko_ok and strip_ok and dis_ok and drag_ok and hide_ok and throw_ok:
		print("SMOKE hitman ok")


## حلّ بوّابة في الاختبار الآلي (ويجرّب الخطأ أولاً حيث يفيد).
func _smoke_gate(i: int) -> void:
	match str(gate_types[i]):
		"keycard":
			_on_gate_smoke()
			var blocked := stage == i
			has_card = true
			_on_gate_smoke()
			print("SMOKE keycard blocked=", blocked, " stage=", stage)
			if blocked and stage == i + 1:
				print("SMOKE keycard ok")
		"checkpoint":
			disguised = false
			has_chief_card = false
			_on_gate_smoke()
			var blocked2 := stage == i
			disguised = true
			_on_gate_smoke()
			disguised = false
			print("SMOKE checkpoint blocked=", blocked2, " stage=", stage)
			if blocked2 and stage == i + 1:
				print("SMOKE checkpoint ok")
		"keypad":
			_submit_code(str(puzzle.code))
		"wires":
			_cut_wire(str(WIRES[int(puzzle.answer)][0]))
		"valves":
			# ضغط زائد يُفجّر البخار ويعيد الصمّامات إلى الصفر
			var burst := false
			for k in 5:
				for v in 4:
					_turn_valve(v, 1)
					if int(valves[0]) == 0 and int(valves[1]) == 0 and int(valves[2]) == 0 and int(valves[3]) == 0:
						burst = true
			hud.close_panel()
			_confirm_valves() # خطأ: يجب ألّا يفتح
			var blocked := stage == i
			for k in 4:
				valves[k] = int(puzzle.vsol[k])
			_confirm_valves()
			print("SMOKE valves burst=", burst, " blocked=", blocked, " stage=", stage)
			if stage == i + 1 and blocked:
				print("SMOKE valves ok")
		"servers":
			_pick_server((int(puzzle.hacked) + 1) % 12)
			var blocked := stage == i
			lockout = 0.0
			_pick_server(int(puzzle.hacked))
			# الحلّ وحيد: لا خادم آخر يطابق الشروط الثلاثة
			var matches := 0
			for e in puzzle.servers:
				if e.led == puzzle.srv_led and int(e.blink) == int(puzzle.srv_blink) and int(e.temp) > int(puzzle.srv_t):
					matches += 1
			print("SMOKE servers blocked=", blocked, " unique=", matches, " stage=", stage)
			if blocked and matches == 1 and stage == i + 1:
				print("SMOKE servers ok")
		"maze":
			_advance()
			print("SMOKE maze ok segs=", maps.maze_segments().size())
		"radio":
			radio_cur = 150.0
			_radio_open = true
			hud.open_radio(radio_cur, _tune_radio, _submit_morse)
			_tune_radio(float(puzzle.freq) - 150.0)
			await get_tree().create_timer(0.4).timeout
			var tuned := _radio_tuned()
			_build_morse()
			_submit_morse(str(puzzle.morse))
			print("SMOKE radio tuned=", tuned, " units=", _morse_units.size(), " stage=", stage)
			if stage == i + 1 and tuned and _morse_units.size() > 20:
				print("SMOKE radio ok")


## اختبارات العوائق: الليزر يلمس الواقف ويُعبَر (انحناء أو توقيت)، الكاميرا ترى ثم تعمى عند التجميد، والقاطع يطفئ الليزر.
func _smoke_hazards() -> void:
	var ok_l := true
	for l in lasers:
		var mid := Vector3(l.x, 0, (l.z0 + l.z1) * 0.5)
		var touched := false
		var passable := false
		var tt := 0.0
		while tt < 12.0:
			l.update(tt, 0.0)
			if l.hits(mid, false):
				touched = true
			if not l.hits(mid, true):
				passable = true
			tt += 0.05
		print("SMOKE laser ", l.mode, " touch=", touched, " pass=", passable)
		ok_l = ok_l and touched and passable
	if not lasers.is_empty() and ok_l:
		print("SMOKE laser ok")
	if not cctvs.is_empty():
		var c = cctvs[cctvs.size() - 1]
		c.update(0.0, 0.0)
		await get_tree().physics_frame
		var fwd: Vector3 = -(c._head.global_transform.basis.z)
		var e: Vector3 = c.eye()
		# نقطة على الأرض داخل المخروط
		var hit := e + fwd * ((e.y - 1.2) / maxf(0.2, -fwd.y))
		hit.y = 0.0
		var space0 := get_world_3d().direct_space_state
		var saw: bool = c.sees(hit, false, space0, [agent.get_rid()])
		c.frozen_t = 3.0
		var blind: bool = not c.sees(hit, false, space0, [agent.get_rid()])
		c.frozen_t = 0.0
		print("SMOKE cam saw=", saw, " blind=", blind, " at ", hit)
		if saw and blind:
			print("SMOKE cam ok")
	if kill_node:
		_submit_colors(["?", "?", "?"])
		var wrong_blocked := _laser_off() <= 0.0
		lockout = 0.0
		_submit_colors(puzzle.laser.duplicate())
		if wrong_blocked and _laser_off() > 15.0 and lasers[0].beams_at(htime).is_empty():
			print("SMOKE killswitch ok")
		hud.close_panel()
	# بقية الاختبار تخصّ الألغاز: نوقف العوائق
	for l in lasers:
		l.off_t = 1e6
	for c in cctvs:
		c.frozen_t = 1e6


func _reach_test() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var sh := SphereShape3D.new()
	sh.radius = 0.28
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.exclude = [agent.get_rid()]
	var step := 0.25
	var free := {}
	for ix in int(reach_rect.size.x / step):
		for iz in int(reach_rect.size.y / step):
			var p := Vector3(reach_rect.position.x + ix * step + step / 2.0, 0, reach_rect.position.y + iz * step + step / 2.0)
			var ok := true
			for y in [0.45, 1.25]:
				q.transform = Transform3D(Basis(), p + Vector3(0, y, 0))
				if not space.intersect_shape(q, 1).is_empty():
					ok = false
					break
			if ok:
				free[Vector2i(ix, iz)] = true
	var start := Vector2i(int((SPAWN.x - reach_rect.position.x) / step), int((SPAWN.z - reach_rect.position.y) / step))
	var seen := {start: true}
	var queue := [start]
	var qi := 0
	while qi < queue.size():
		var c: Vector2i = queue[qi]
		qi += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2: Vector2i = c + d
			if free.has(n2) and not seen.has(n2):
				seen[n2] = true
				queue.append(n2)
	var near := func(target: Vector3, rad: float) -> bool:
		for k in seen:
			var cell: Vector2i = k
			if Vector2(reach_rect.position.x + cell.x * step + step / 2.0 - target.x, reach_rect.position.y + cell.y * step + step / 2.0 - target.z).length() < rad:
				return true
		return false
	return {"spawn": free.has(start), "t0": near.call(terminals[0].pos, 1.5), "t1": near.call(terminals[1].pos, 1.5), "vault": near.call(VAULT_FRONT, 1.2), "cells": seen.size()}


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
	room_code = code
	_net()
	net.open(code)
	menu.waiting(code, r)


func _join(code: String) -> void:
	room_code = code
	_net()
	net.open(code)
	menu.show_info("جارٍ الانضمام إلى الغرفة %s…" % code)


func _on_msg(m: Dictionary) -> void:
	_partner_seen = Time.get_ticks_msec() / 1000.0
	var t := str(m.get("t", ""))
	if t == "join" and host_role != "":
		net.send({"t": "hello", "role": host_role, "seed": seed_value, "lv": level_i})
		if not started:
			_start(host_role, seed_value)
	elif t == "hello" and host_role == "" and not started:
		var r := "analyst" if str(m.get("role", "")) == "agent" else "agent"
		level_i = int(m.get("lv", 1))
		_start(r, int(m.get("seed", 0)))
	elif t == "pos" and avatar:
		avatar.set_meta("target", Vector3(float(m.get("x", 0)), 0, float(m.get("z", 0))))
		avatar.set_meta("yaw", float(m.get("y", 0)))
		avatar.play(str(m.get("a", "idle")))
		if bool(m.get("d", false)) != avatar.disguised:
			avatar.set_disguised(bool(m.get("d", false)))
		_apply_hazard_sync(float(m.get("ht", htime)), float(m.get("lz", 0.0)), float(m.get("cf", 0.0)))
		var gl = m.get("g", [])
		if typeof(gl) == TYPE_ARRAY and ready_world:
			for i in mini(gl.size(), guards.size()):
				var e = gl[i]
				if typeof(e) == TYPE_ARRAY and e.size() >= 4:
					guards[i].apply_remote(Vector3(float(e[0]), 0, float(e[1])), float(e[2]), str(e[3]))
	elif t == "valves" and role == "analyst":
		var vv = m.get("v", [])
		if typeof(vv) == TYPE_ARRAY and vv.size() == 4:
			valves = vv
	elif t == "sync" and role == "analyst":
		sync_go = float(m.get("go", -1.0))
		sync_b = -1.0
	elif t == "hack" and role == "agent" and ready_world and stage == 0:
		hud.flash("🔓 المحلّل اخترق الباب!", Color(0.42, 0.85, 0.58))
		_advance()
	elif t == "press" and role == "agent":
		sync_b = float(m.get("h", -1.0))
	elif t == "spotted" and role == "agent" and ready_world and agent:
		hud.flash("🚨 الدورية كشفت المحلّل! حارس قادم نحوك", Color(0.9, 0.28, 0.3))
		var gs = _nearest_guard(agent.global_position)
		if gs and not gs.is_chasing():
			gs.chase(agent)
	elif t == "tool" and role == "agent" and ready_world:
		_do_tool(str(m.get("k", "")))
	elif t == "prog" and role == "analyst" and ready_world:
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
	lv = Levels.get_level(level_i)
	mission_left = float(lv.mission)
	maps = preload("res://maps.gd").new(self)
	maps.data(str(lv.get("theme", "port")))
	puzzle = _make_puzzle(s)
	if menu:
		menu.queue_free()
		menu = null
	hud = preload("res://hud.gd").new()
	add_child(hud)
	# البناء على خطوات خلف شاشة تحميل (لا تتجمّد الشاشة)
	var steps := [
		["المواد والخامات", _materials], ["الخامات الواقعية", _realistic], ["الإضاءة والضباب", _environment],
		["المبنى: " + str(lv.name), _build_building], ["غرفة الأرشيف", _build_archive], ["الأثاث والأشياء", _props],
		["الجوّ والطقس", _theme], ["الليزر والكاميرات", _build_hazards],
		["الحرّاس", _spawn_guards], ["الأصوات", _sounds], ["اللمسات الأخيرة", _hints],
	]
	for i in steps.size():
		hud.loading(true, float(i) / (steps.size() + 2), str(steps[i][0]) + "…")
		await get_tree().process_frame
		(steps[i][1] as Callable).call()
	hud.interact_pressed.connect(_on_interact)
	hud.tool_pressed.connect(_on_tool)
	hud.switch_pressed.connect(_on_switch)
	hud.binoc_pressed.connect(_toggle_binoc)
	hud.run_pressed.connect(func():
		if agent and active == agent:
			agent.set_running(not agent.running))
	hud.instinct_pressed.connect(_instinct)
	hud.throw_pressed.connect(_do_throw)
	hud.act2_pressed.connect(func(): _do_act(true))
	hud.dark_pressed.connect(_toggle_dark)
	hud.sync_pressed.connect(_sync_press)
	hud.crouch_pressed.connect(func():
		if agent and active == agent and not vault_mode:
			agent.set_crouch(not agent.crouch))
	hud.next_pressed.connect(func():
		Levels.pending = level_i + 1
		get_tree().reload_current_scene())
	if cctvs.is_empty():
		hud.hide_tool("freeze")
	hud.set_switch_visible(role == "solo")
	if role != "analyst":
		agent = _make_player(SPAWN, spawn_yaw, true)
	if role != "agent":
		analyst = _make_player(analyst_spawn, analyst_yaw)
		if role == "analyst":
			avatar = _make_avatar()
		_build_feeds()
	_set_active(analyst if role == "analyst" else agent)
	hud.set_status("وضع فردي" if net == null else "")
	if Levels.low_quality() or OS.get_environment("KHAZNA_LOW") == "1":
		_apply_low_quality()
	# تحضير المؤثّرات خلف شاشة التحميل: الكاميرا تلتفت حولها فتُجهَّز كل المواد
	hud.loading(true, 0.85, "تحضير المؤثّرات…")
	if active:
		var y0: float = active.yaw
		for k in 8:
			active.yaw = y0 + k * TAU / 8.0
			active.rotation.y = active.yaw
			await get_tree().process_frame
		active.yaw = y0
		active.rotation.y = y0
	hud.loading(true, 1.0, "جاهز")
	await get_tree().process_frame
	hud.loading(false)
	ready_world = true
	stats.start = Time.get_ticks_msec() / 1000.0
	_intro()
	# الصوت داخل اللعبة (أونلاين فقط)
	if net and room_code != "":
		voice = preload("res://voice.gd").new()
		add_child(voice)
		voice.status.connect(func(t): hud.set_voice(t, voice.muted))
		voice.speaking.connect(func(me, other): hud.set_speaking(me, other))
		hud.mic_pressed.connect(func():
			voice.toggle_mute()
			hud.set_voice("🔇 الميكروفون مكتوم" if voice.muted else "🎙 الميكروفون يعمل", voice.muted))
		if voice.available:
			voice.start(room_code)
		else:
			hud.set_voice("الصوت داخل اللعبة متاح على أندرويد — استعمل مكالمة هنا", false)


func _intro() -> void:
	var a := "أنت العميل داخل مخزن الميناء.\n\n١. اتبع السهم البرتقالي إلى الجهاز، وابتعد عن ضوء مصابيح الحرّاس.\n٢. الرموز والأجوبة ليست عندك: هي عند شريكك المحلّل. صِف له ما تراه واسأله.\n٣. افتح الخزنة، ثم اهرب إلى نقطة البداية قبل انتهاء الإنذار."
	var b := "أنت المحلّل في غرفة الأرشيف.\n\n١. راقب العميل والحرّاس على شاشات المراقبة.\n٢. الشيء المضيء والسهم فوقه = ما تبحث فيه الآن (درج، دليل، حاسوب).\n٣. انظر إليه واضغط الزر، ثم أخبر العميل بما وجدت."
	var title := "المرحلة: %s — %s" % [lv.name, lv.sub]
	if lv.id == "tutorial":
		hud.open_text("التدريب", "مرحباً بك في التدريب.\n\nستتعلّم: المشي والالتفات، الانحناء تحت الليزر، تجنّب الكاميرات، ولعب دور المحلّل.\nاتبع السطر الأخضر في أسفل الشاشة خطوة بخطوة.\n\nالحارس هنا بطيء وبصره ضعيف — لا تخف.")
		return
	if not lasers.is_empty() or not cctvs.is_empty():
		var extra := "\n\n⚠ في هذه المرحلة:"
		if not lasers.is_empty():
			extra += "\n• ليزر: لا تلمسه. انحنِ (🧎) تحت العالي، وانتظر الفراغ في المتحرّك."
		if lv.get("killswitch", false):
			extra += "\n• قاطع الليزر قرب باب الغرفة الثانية: ترتيب ألوانه في «سجلّ الليزر» عند المحلّل."
		if not cctvs.is_empty():
			extra += "\n• كاميرات: ابقَ خارج المخروط الأحمر. المحلّل يستطيع تجميدها."
		a += extra
		b += extra
	if role == "agent":
		hud.open_text(title, a)
	elif role == "analyst":
		hud.open_text(title, b)
	else:
		hud.open_text(title, a + "\n\n(زر 👁 أعلى الشاشة يبدّلك إلى المحلّل)")


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


func _make_player(at: Vector3, yaw: float, third := false):
	var p = preload("res://player.gd").new()
	p.third = third
	p.position = at
	add_child(p)
	p.yaw = yaw
	p.face = yaw
	if not third:
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
		_reset_agent_cam()
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
	var r2 := RandomNumberGenerator.new()
	r2.seed = s + 7919
	var cl := [0, 1, 2, 3]
	for i in range(cl.size() - 1, 0, -1):
		var j := r2.randi_range(0, i)
		var tmp = cl[i]
		cl[i] = cl[j]
		cl[j] = tmp
	var laser := []
	for i in 3:
		laser.append(str(LCOLORS[cl[i]][0]))
	# الصمّامات: كل صمّام يحرّك عدّة أنابيب؛ الحلّ موجود دائماً (نولّده ثم نحسب الأهداف منه)
	var r3 := RandomNumberGenerator.new()
	r3.seed = s + 31337
	var mat := []
	for j in 4:
		var row := []
		for i in 4:
			row.append(r3.randi_range(1, 2) if i == j else (r3.randi_range(0, 2) if r3.randf() < 0.55 else 0))
		mat.append(row)
	var sol := []
	for i in 4:
		sol.append(r3.randi_range(1, 4))
	var base := []
	var target := []
	for j in 4:
		base.append(r3.randi_range(1, 3))
		var t := int(base[j])
		for i in 4:
			t += int(mat[j][i]) * int(sol[i])
		target.append(t)
	var freq := snappedf(140.0 + r3.randi_range(0, 199) * 0.1, 0.1)
	var morse := ""
	for i in 4:
		morse += str(r3.randi_range(0, 9))
	# الخوادم: واحد مخترَق؛ يُعرف بلون ضوئه وعدد ومضاته (سجلّ المحلّل) وحرارته فوق حدّ (لوحة البرج)
	var r4 := RandomNumberGenerator.new()
	r4.seed = s + 4242
	var leds := ["أخضر", "برتقالي", "أحمر", "أزرق"]
	var led_t: String = leds[r4.randi_range(0, 3)]
	var blink_t := r4.randi_range(1, 3)
	var srv_t := r4.randi_range(55, 68)
	var ids := []
	for k in range(1, 25):
		ids.append(k)
	for k in range(ids.size() - 1, 0, -1):
		var j := r4.randi_range(0, k)
		var tmp = ids[k]
		ids[k] = ids[j]
		ids[j] = tmp
	var servers := []
	var hacked := r4.randi_range(0, 11)
	for k in 12:
		var e := {"id": "SRV-%02d" % int(ids[k]), "led": leds[r4.randi_range(0, 3)], "blink": r4.randi_range(1, 3), "temp": r4.randi_range(38, 84)}
		var role_k := (k - hacked + 12) % 12
		if role_k == 0:
			e.led = led_t
			e.blink = blink_t
			e.temp = srv_t + r4.randi_range(3, 12)
		elif role_k <= 2:
			e.led = led_t # يشبهه في الضوء والومضات… لكنه بارد
			e.blink = blink_t
			e.temp = srv_t - r4.randi_range(1, 12)
		elif role_k <= 4:
			e.led = led_t # نفس اللون وحارّ… لكن ومضاته مختلفة
			e.blink = (blink_t % 3) + 1
			e.temp = srv_t + r4.randi_range(2, 14)
		elif e.led == led_t and e.blink == blink_t and e.temp > srv_t:
			e.temp = srv_t - r4.randi_range(2, 10)
		servers.append(e)
	# المتاهة: شجرة ممرّات (DFS) على شبكة 6×5 تبدأ من الصفّ 2 غرباً
	var r5 := RandomNumberGenerator.new()
	r5.seed = s + 777
	var W := 6
	var H := 5
	var vw := []
	var hw := []
	for k in W * H:
		vw.append(true)
		hw.append(true)
	var seen := {Vector2i(0, 2): true}
	var stack := [Vector2i(0, 2)]
	while not stack.is_empty():
		var c: Vector2i = stack[stack.size() - 1]
		var nb := []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2: Vector2i = c + d
			if n2.x >= 0 and n2.x < W and n2.y >= 0 and n2.y < H and not seen.has(n2):
				nb.append(n2)
		if nb.is_empty():
			stack.pop_back()
			continue
		var nx: Vector2i = nb[r5.randi_range(0, nb.size() - 1)]
		if nx.x != c.x:
			vw[c.y * W + mini(c.x, nx.x)] = false
		else:
			hw[mini(c.y, nx.y) * W + c.x] = false
		seen[nx] = true
		stack.append(nx)
	return {"code": code, "serial": serial, "table": table, "answer": answer, "wires": wires, "symbols": syms, "combo": combo, "laser": laser,
		"vmat": mat, "vsol": sol, "vbase": base, "vtarget": target, "freq": freq, "morse": morse,
		"servers": servers, "hacked": hacked, "srv_led": led_t, "srv_blink": blink_t, "srv_t": srv_t, "maze": {"v": vw, "h": hw}}


func _gauges() -> Array:
	var out := []
	for j in 4:
		var g := int(puzzle.vbase[j])
		for i in 4:
			g += int(puzzle.vmat[j][i]) * int(valves[i])
		out.append(g)
	return out


func _gauge_max() -> int:
	var m := 0
	for t in puzzle.vtarget:
		m = maxi(m, int(t))
	return m + 8


# ───────── المواد والجوّ ─────────
func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _noise_normal(freq: float, strength: float) -> NoiseTexture2D:
	if _have_pbr():
		return null
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


func _have_pbr() -> bool:
	return ResourceLoader.exists("res://ph/tex/concrete_wall_008_diff.jpg")


func _noise_tex(freq: float, a: Color, b: Color) -> NoiseTexture2D:
	if _have_pbr():
		return null
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
	_prop_log.append("%s size=%s" % [id, box.size])
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
	# المبنى: براميل وصناديق ورفوف وكاميرات حقيقية وطفّاية حريق (الميناء والتدريب فقط؛ النهر والجبل لهما أثاثهما)
	if str(lv.get("theme", "port")) == "port":
		_props_port()
	_props_archive()


func _props_port() -> void:
	_prop("Barrel_01", Vector3(15.6, 0, 1.0))
	_prop("Barrel_01", Vector3(16.4, 0, 1.25), 40)
	_prop("barrel_03", Vector3(26.6, 0, 9.2))
	_prop("cardboard_box_01", Vector3(5.6, 0, 7.4))
	_prop("cardboard_box_01", Vector3(6.3, 0, 7.5), 25)
	_prop("cardboard_box_01", Vector3(17.6, 0, 9.4), -15, false)
	_prop("korean_fire_extinguisher_01", Vector3(7.6, 0, 7.6), 0, false)
	_prop("power_box_01", Vector3(19.75, 1.1, 2.6), -90, false)
	for c in [Vector3(0.6, 2.7, 0.6), Vector3(8.6, 2.7, 9.4), Vector3(20.6, 2.7, 0.6)]:
		_prop("security_camera_01", c, 0, false)
	for l in [Vector3(4, 2.75, 4), Vector3(14, 2.75, 5), Vector3(25, 2.75, 5), ARCHIVE + Vector3(5, 2.75, 5)]:
		_prop("caged_hanging_light", l, 0, false)


func _props_archive() -> void:
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
	s_clunk = _snd("click", false, 4.0)
	s_clunk.pitch_scale = 0.45
	s_door = _snd3d("door", Vector3(8, 1.5, 4.5), 2.0)
	s_creep = _snd3d("door", Vector3.ZERO, -2.0)
	s_music = _snd("chase", true, -40.0)
	s_vault = _snd3d("vault_open", vault_xf * Vector3(29.6, 1.5, 5), 4.0)
	s_beep = _snd("cam_beep", false, -4.0)


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
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.15
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.035, 0.045)
	env.fog_density = 0.035
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 0.85
	match str(lv.get("theme", "port")):
		"river":
			# رطوبة: ضباب مائل للأخضر، ضوء بارد خافت
			env.fog_light_color = Color(0.02, 0.045, 0.05)
			env.fog_density = 0.045
			env.ambient_light_color = Color(0.25, 0.42, 0.45)
			env.adjustment_saturation = 0.8
		"mountain":
			# برد: ضباب أزرق شاحب، ألوان باهتة
			env.fog_light_color = Color(0.07, 0.085, 0.11)
			env.fog_density = 0.03
			env.ambient_light_color = Color(0.5, 0.6, 0.8)
			env.ambient_light_energy = 0.45
			env.adjustment_saturation = 0.62
			env.adjustment_contrast = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## الجودة المنخفضة: بلا ظلال ولا انعكاسات ولا توهّج، جزيئات أقلّ، ودقّة ثلاثية الأبعاد أقلّ قليلاً.
func _apply_low_quality() -> void:
	get_viewport().scaling_3d_scale = 0.72
	for n in find_children("*", "Light3D", true, false):
		(n as Light3D).shadow_enabled = false
	for n in find_children("*", "ReflectionProbe", true, false):
		n.queue_free()
	for n in find_children("*", "CPUParticles3D", true, false):
		(n as CPUParticles3D).amount = maxi(4, int((n as CPUParticles3D).amount / 2))
	for n in find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		env.glow_enabled = false
		env.fog_density *= 0.9
	for f in feeds:
		(f[0] as SubViewport).size = Vector2i(200, 112)
	print("QUALITY: low")


# ═════════ Hitman: الإسقاط، الإخفاء، التنكّر، الرمي، الحاسّة ═════════
func _behind(g) -> bool:
	var to: Vector3 = agent.global_position - (g.global_position as Vector3)
	to.y = 0.0
	var fwd: Vector3 = -(g.global_transform.basis.z as Vector3)
	return to.length() < 1.5 and fwd.dot(to.normalized()) < -0.25


func _hitman_update(delta: float) -> void:
	instinct_t = maxf(0.0, instinct_t - delta)
	instinct_cd = maxf(0.0, instinct_cd - delta)
	hud.instinct_fx(clampf(instinct_t, 0.0, 1.0) if active == agent else 0.0)
	var p: Vector3 = agent.global_position
	# الجسم المسحوب يتبع العميل
	if drag_g:
		var back := Basis(Vector3.UP, agent.face).z
		drag_g.position = drag_g.position.lerp(p + back * 0.95, minf(1.0, delta * 10.0))
	_act = ""
	_act2 = ""
	_act_g = null
	if vault_mode or result != "":
		return
	if drag_g:
		var spot := _near_hide(p)
		_act = "📦 أخفِ الجسم في " + spot if spot != "" else ""
		_act2 = "✋ اترك الجسم"
		_act_g = drag_g
		return
	for g in guards:
		if g.ko or g.is_chasing():
			continue
		if _behind(g):
			_act = "👊 أسقطه"
			_act2 = "🤏 اسرق البطاقة" if g.has_card else ""
			_act_g = g
			return
	for g in guards:
		if g.ko and not g.hidden and (g.global_position as Vector3).distance_to(p) < 1.6:
			_act_g = g
			if not g.stripped and not disguised:
				_act = "👕 خذ بدلته"
				_act2 = "🫳 اسحب الجسم"
			else:
				_act = "🫳 اسحب الجسم"
			return
	for c in can_nodes:
		if (c as Node3D).visible and (c as Node3D).global_position.distance_to(p) < 1.3:
			_act = "🥫 التقط العلبة"
			_act_g = c
			return


func _near_hide(p: Vector3) -> String:
	for h in hide_spots:
		if (h[0] as Vector3).distance_to(p) < 1.8:
			return str(h[1])
	return ""


func _do_act(second: bool) -> void:
	var a := _act2 if second else _act
	var g = _act_g
	if a == "" or g == null:
		return
	if a.begins_with("👊"):
		_takedown(g)
	elif a.begins_with("🤏"):
		_take_card_from(g)
		hud.flash("🤏 سرقتَ البطاقة دون أن يشعر", Color(0.42, 0.85, 0.58))
	elif a.begins_with("👕"):
		g.stripped = true
		disguised = true
		agent.body.set_disguised(true)
		_take_card_from(g)
		hud.flash("👕 أنت الآن بزيّ الحارس — الحرّاس لا يشكّون إلا إن ركضت أو انحنيت. الرئيس (قبّعة حمراء) يكشفك!", Color(0.6, 0.85, 1.0))
	elif a.begins_with("🫳"):
		drag_g = g
		agent.dragging = true
		agent.set_running(false)
		_take_card_from(g)
	elif a.begins_with("✋"):
		_drop_body()
	elif a.begins_with("📦"):
		g.hide_body()
		_drop_body()
		hud.flash("📦 أخفيتَ الجسم — لن يجده أحد", Color(0.42, 0.85, 0.58))
		if s_door.stream:
			s_door.global_position = agent.global_position
			s_door.play()
	elif a.begins_with("🥫"):
		(g as Node3D).visible = false
		cans += 1
		hud.flash("🥫 علبة — ارمِها لتشتيت حارس", Color(0.9, 0.85, 0.6))


func _drop_body() -> void:
	drag_g = null
	agent.dragging = false


func _take_card_from(g) -> void:
	if g.has_card:
		g.take_card()
		if g.chief:
			has_chief_card = true
			hud.flash("💳 أخذتَ بطاقة الرئيس — تفتح نقطة التفتيش", Color(0.42, 0.85, 0.58))
		else:
			has_card = true
			hud.flash("💳 أخذتَ بطاقة الدخول — تفتح الباب الأول", Color(0.42, 0.85, 0.58))


func _takedown(g) -> void:
	agent.body.one_shot("hook", 0.75)
	agent.face = atan2(-((g.global_position as Vector3) - agent.global_position).x, -((g.global_position as Vector3) - agent.global_position).z)
	await get_tree().create_timer(0.3).timeout
	if g.ko:
		return
	g.knock_out()
	stats.ko += 1
	shake = 0.25
	Input.vibrate_handheld(60)
	if s_clunk.stream:
		s_clunk.play()
	hud.flash("👊 أسقطتَه — أخفِ الجسم قبل أن يراه أحد", Color(0.9, 0.85, 0.6))


func _do_throw() -> void:
	if cans <= 0 or agent == null:
		return
	cans -= 1
	agent.face = agent.yaw
	agent.body.one_shot("throw", 1.0)
	var fwd := -Basis(Vector3.UP, agent.yaw).z
	var from: Vector3 = agent.global_position + Vector3(0, 1.4, 0)
	var to := from + fwd * 8.0 + Vector3(0, -1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [agent.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var land: Vector3 = (hit.position as Vector3) - fwd * 0.3 if not hit.is_empty() else to
	land.y = 0.05
	await get_tree().create_timer(0.5).timeout
	var can := _can_mesh(land)
	get_tree().create_timer(6.0).timeout.connect(func(): can.queue_free())
	if s_creep.stream:
		s_creep.global_position = land + Vector3(0, 0.3, 0)
		s_creep.pitch_scale = 1.6
		s_creep.play()
	var n := 0
	for g in guards:
		if not g.ko and not g.is_chasing() and (g.global_position as Vector3).distance_to(land) < 10.0:
			g.investigate(land)
			n += 1
	hud.flash("🥫 صوت! %s" % ("حارس يذهب ليرى" if n > 0 else "لا أحد قريب"), Color(0.9, 0.85, 0.6))


func _can_mesh(at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.045
	cm.height = 0.13
	m.mesh = cm
	m.material_override = _glow(Color(0.85, 0.2, 0.15), 0.6)
	m.position = at
	add_child(m)
	return m


func _instinct() -> void:
	if instinct_cd > 0.0 or agent == null:
		return
	instinct_t = 5.0
	instinct_cd = 25.0
	for g in guards:
		if not g.ko:
			g.mark(5.0)
	hud.flash("👁 الحاسّة: ترى الحرّاس عبر الجدران", Color(0.6, 0.8, 1.0))


func _body_found(g, b) -> void:
	if _found_alarm:
		return
	_found_alarm = true
	stats.found += 1
	b.hidden = true # لا نكرّر الإنذار لنفس الجسم
	g.investigate(b.global_position)
	for o in guards:
		if not o.ko:
			o.sus = maxf(o.sus, 0.5)
			o.speed *= 1.15
	if active == agent:
		hud.flash("🚨 وجدوا جسم الحارس! الحرّاس متأهّبون", Color(0.9, 0.28, 0.3))
		hud.hit()
	if s_beep.stream:
		s_beep.play()
	get_tree().create_timer(3.0).timeout.connect(func(): _found_alarm = false)


## «فرص» يقرؤها المحلّل ويخبر بها شريكه (مثل ديانا في Hitman).
func _analyst_tips(delta: float) -> void:
	if analyst == null or active != analyst or lv.id == "tutorial":
		return
	_tip_t -= delta
	if _tip_t > 0.0:
		return
	_tip_t = 6.0
	var tip := ""
	if stage < gate_types.size():
		match str(gate_types[stage]):
			"keycard":
				tip = "💡 الحارس في غرفة المدخل يحمل بطاقة الدخول على حزامه — العميل يسرقها من الخلف. أو اخترق الباب من جهازك."
			"checkpoint":
				tip = "💡 نقطة التفتيش تسمح للحرّاس: إن لبس العميل زيّ حارس يمرّ. الرئيس بالقبّعة الحمراء يكشفه — أطفئ الكهرباء ⚡ أو شتّته."
	elif stage == 2:
		tip = "💡 أدخل رموز باب الخزنة في الحاسوب، ثم استعدّا للقفل الزمني."
	elif stage >= 3:
		tip = "💡 الإنذار! وجّه العميل إلى المخرج — شتّت الحرّاس في طريقه."
	if tip != "":
		hud.set_tip(tip)


func _stars() -> Array:
	var used: float = (Time.get_ticks_msec() / 1000.0) - float(stats.start)
	var st := 1
	var title := "عميل"
	if stats.seen == 0 and stats.found == 0:
		st = 3
		title = "👻 شبح"
	elif stats.seen <= 2 and stats.found == 0:
		st = 2
		title = "محترف"
	return [st, title, used]


# ═════════ ألغاز البوّابات الجديدة ═════════
func _turn_valve(i: int, d: int) -> void:
	valves[i] = clampi(int(valves[i]) + d, 0, 4)
	Input.vibrate_handheld(10)
	if s_click.stream:
		s_click.play()
	hud.update_valves(valves)
	_send_valves()
	var g := _gauges()
	for j in 4:
		if int(g[j]) > int(puzzle.vtarget[j]) + 3:
			_valve_burst(j)
			return


func _send_valves() -> void:
	if net and role == "agent":
		net.send({"t": "valves", "v": valves})


func _valve_burst(j: int) -> void:
	hud.close_panel()
	hud.flash("💥 انفجر البخار في %s! الحارس سمع — اختبئ" % GAUGE_NAMES[j], Color(0.9, 0.28, 0.3))
	hud.hit()
	shake = 0.6
	Input.vibrate_handheld(400)
	if s_beep.stream:
		s_beep.play()
	if s_clunk.stream:
		s_clunk.play()
	for i in 4:
		valves[i] = 0
	_send_valves()
	var g = _nearest_guard(agent.global_position)
	if g and not g.is_chasing():
		g.chase(agent)


func _confirm_valves() -> void:
	var g := _gauges()
	var off := 0
	for j in 4:
		if int(g[j]) != int(puzzle.vtarget[j]):
			off += 1
	if off == 0:
		hud.close_panel()
		hud.flash("✔ الضغط متوازن — الباب الهيدروليكي يُفتح", Color(0.42, 0.85, 0.58))
		_advance()
	else:
		mission_left = maxf(10.0, mission_left - 10.0)
		hud.flash("✖ %d أنابيب غير متوازنة (−10 ث)" % off, Color(0.9, 0.28, 0.3))
		hud.hit()


func _tune_radio(dv: float) -> void:
	radio_cur = clampf(snappedf(radio_cur + dv, 0.1), 140.0, 160.0)
	if s_click.stream:
		s_click.play()
	hud.set_radio(radio_cur, false)


func _radio_tuned() -> bool:
	return absf(radio_cur - float(puzzle.freq)) < 0.05


func _submit_morse(v: String) -> void:
	if lockout > 0.0:
		hud.flash("الجهاز مقفل… انتظر", Color(0.9, 0.28, 0.3))
		return
	if v == str(puzzle.morse):
		hud.close_panel()
		_radio_open = false
		hud.flash("✔ الرمز صحيح — باب القبو يُفتح", Color(0.42, 0.85, 0.58))
		_advance()
	else:
		lockout = 5.0
		mission_left = maxf(10.0, mission_left - 15.0)
		hud.flash("✖ رمز خاطئ — الجهاز مقفل 5 ث (−15 ث)", Color(0.9, 0.28, 0.3))
		hud.hit()


## إشارة مورس: سلسلة وحدات زمنية (1 = صوت). قصير = وحدة، طويل = 3، بين الإشارات وحدة، بين الأرقام 3، وفي النهاية 8.
func _build_morse() -> void:
	_morse_units = []
	for ch in str(puzzle.morse):
		var pat: String = MORSE[ch]
		for k in pat.length():
			var n := 1 if pat[k] == "." else 3
			for u in n:
				_morse_units.append(1)
			_morse_units.append(0)
		_morse_units.append(0)
		_morse_units.append(0)
	for u in 6:
		_morse_units.append(0)


func _morse_update() -> void:
	if not (_radio_open and hud.panel_open()):
		_radio_open = false
		if s_morse and s_morse.playing:
			s_morse.stop()
		return
	var tuned := _radio_tuned()
	var on := false
	if tuned:
		if _morse_units.is_empty():
			_build_morse()
		var u := int(Time.get_ticks_msec() / 140.0) % _morse_units.size()
		on = int(_morse_units[u]) == 1
	hud.set_radio(radio_cur, on)
	if s_morse == null:
		s_morse = AudioStreamPlayer.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.15
		s_morse.stream = gen
		s_morse.volume_db = -6.0
		add_child(s_morse)
	if not s_morse.playing:
		s_morse.play()
		_morse_pb = s_morse.get_stream_playback()
	if _morse_pb == null:
		return
	# نغمة 700 هرتز عند الإشارة، وتشويش راديو يخفّ كلّما اقترب التردّد
	var noise := clampf(absf(radio_cur - float(puzzle.freq)) / 3.0, 0.08, 0.5) if not tuned else 0.04
	var frames := _morse_pb.get_frames_available()
	for f in frames:
		_morse_phase = fmod(_morse_phase + 700.0 / 22050.0, 1.0)
		var v := (sin(_morse_phase * TAU) * 0.45 if on else 0.0) + randf_range(-noise, noise)
		_morse_pb.push_frame(Vector2(v, v))


func _pick_server(i: int) -> void:
	if lockout > 0.0:
		hud.flash("اللوحة مقفلة… انتظر", Color(0.9, 0.28, 0.3))
		return
	if i == int(puzzle.hacked):
		hud.close_panel()
		hud.flash("✔ سحبتَ قرص الخادم المخترَق — باب الأنفاق يُفتح", Color(0.42, 0.85, 0.58))
		_advance()
	else:
		lockout = 6.0
		mission_left = maxf(10.0, mission_left - 20.0)
		hud.close_panel()
		hud.flash("✖ خادم خاطئ! إنذار — الحارس قادم (−20 ث)", Color(0.9, 0.28, 0.3))
		hud.hit()
		shake = 0.4
		if s_beep.stream:
			s_beep.play()
		var g = _nearest_guard(agent.global_position)
		if g and not g.is_chasing():
			g.chase(agent)


## الأنفاق مظلمة قبل إعادة التيار: مصباح العميل يموت داخلها، فيعتمد على مخطّط المحلّل.
func _maze_dark() -> void:
	if agent == null or not gate_types.has("maze"):
		return
	var p: Vector3 = agent.global_position
	var inside := stage == 1 and p.x > 18.2 and p.x < 29.9 and p.z > 0.0 and p.z < 10.0
	agent.flash.visible = (not inside) and active == agent
	if inside and not _dark_warned and active == agent:
		_dark_warned = true
		hud.flash("🔦 فرغت بطارية المصباح… اطلب من المحلّل أن يوجّهك بالمخطّط", Color(0.9, 0.6, 0.3))
		if s_creep.stream:
			s_creep.global_position = p + Vector3(0, 1.5, -3)
			s_creep.play()


# ═════════ المحلّل: منظار، أضواء، ودورية ═════════
func _toggle_binoc() -> void:
	binoc = not binoc
	var tw := create_tween()
	tw.tween_property(analyst.cam, "fov", 13.0 if binoc else 72.0, 0.35).set_trans(Tween.TRANS_CUBIC)
	analyst.sens = 0.22 if binoc else 1.0


func _toggle_dark() -> void:
	analyst_dark = not analyst_dark
	_apply_dark()
	hud.flash("🌑 أطفأت الأضواء — لن تراك الدورية، لكنك لا ترى الشاشات" if analyst_dark else "💡 الأضواء تعمل", Color(0.6, 0.75, 0.95))


func _apply_dark() -> void:
	for l in cabin_lights:
		(l as Light3D).visible = not analyst_dark
	for mm in feed_mats:
		(mm as ShaderMaterial).set_shader_parameter("glitch", 1.0 if analyst_dark else 0.0)
	if analyst_dark:
		hud.close_panel()


func _patrol_update(delta: float) -> void:
	if not maps.has_method("patrol_update"):
		return
	var st: Dictionary = maps.patrol_update(htime)
	analyst_locked = maxf(0.0, analyst_locked - delta)
	if role == "agent" or analyst == null:
		return
	if st.get("warn", false) and not _patrol_warned and active == analyst:
		_patrol_warned = true
		hud.flash("🚤 الدورية تقترب من نافذتك — أطفئ الأضواء 🌑", Color(1.0, 0.63, 0.23))
		Input.vibrate_handheld(150)
	if not st.get("warn", false) and not st.get("lit", false):
		_patrol_warned = false
	if st.get("lit", false) and not analyst_dark and analyst_locked <= 0.0 and role == "analyst":
		analyst_locked = 20.0
		hud.close_panel()
		hud.flash("🚨 كشّاف الدورية رآك! أدواتك معطّلة 20 ث، والحارس انتبه", Color(0.9, 0.28, 0.3))
		hud.hit()
		if net:
			net.send({"t": "spotted"})


# ═════════ القفل الزمني: الضغط معاً ═════════
func _start_sync() -> void:
	sync_go = htime + 4.0
	sync_a = -1.0
	sync_b = -1.0
	if net and role == "agent":
		net.send({"t": "sync", "go": sync_go})
	hud.flash("⏱ قفل زمني! اضغطا الزرّ معاً عند «الآن»", Color(1.0, 0.63, 0.23))


func _sync_press() -> void:
	if sync_go < 0.0:
		return
	if role == "analyst":
		sync_b = htime
		if net:
			net.send({"t": "press", "h": htime})
	else:
		sync_a = htime
		if role == "solo":
			sync_b = htime
	Input.vibrate_handheld(30)


func _sync_update() -> void:
	if sync_go < 0.0:
		hud.sync_ui(false)
		return
	var rem := sync_go - htime
	var inwin := func(x: float) -> bool: return x >= sync_go - 0.15 and x <= sync_go + 1.3
	if rem > 0.0:
		hud.sync_ui(true, "استعدّا… %d" % int(ceil(rem)))
	elif rem > -1.3:
		hud.sync_ui(true, "🔴 الآن!")
	elif role != "analyst":
		var ok: bool = inwin.call(sync_a) and inwin.call(sync_b)
		sync_go = -1.0
		hud.sync_ui(false)
		if ok:
			hud.flash("✔ ضغطتما معاً — الأقفال تتحرّك…", Color(0.42, 0.85, 0.58))
			if net:
				net.send({"t": "sync", "go": -1.0})
			_spin_wheel()
		else:
			hud.flash("✖ لم تضغطا في نفس اللحظة — إعادة بعد 4 ث", Color(0.9, 0.28, 0.3))
			hud.hit()
			shake = 0.3
			for g in guards:
				if not g.is_chasing():
					g.set_alert(true, agent.global_position)
			get_tree().create_timer(4.0).timeout.connect(func():
				if result == "" and stage == 2:
					_start_sync())
	else:
		hud.sync_ui(true, "…")


# ───────── جوّ المرحلة ─────────
func _theme() -> void:
	# أصوات الطقس (الخرائط نفسها تبني المطر والثلج والماء)
	match str(lv.get("theme", "port")):
		"river":
			s_hazard_amb = _snd("rain", true, -7.0)
		"mountain":
			s_hazard_amb = _snd("wind", true, -7.0)
	if s_hazard_amb and s_hazard_amb.stream:
		s_hazard_amb.play()


func _drips(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = 10
	p.lifetime = 1.1
	p.direction = Vector3.DOWN
	p.spread = 2.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0, -9.8, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.5, 0.02, 0.5)
	var m := QuadMesh.new()
	m.size = Vector2(0.012, 0.09)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.8, 0.85, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.material = mat
	p.mesh = m
	add_child(p)


func _snowfall(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = 90
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.direction = Vector3(1, -0.4, 0)
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.25, -0.35, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(4.5, 0.05, 4.0)
	var m := QuadMesh.new()
	m.size = Vector2(0.025, 0.025)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.97, 1.0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.material = mat
	p.mesh = m
	add_child(p)


# ───────── الليزر والكاميرات ─────────
func _build_hazards() -> void:
	var hum := _stream("laser", true)
	for L in lv.get("lasers", []):
		var l = preload("res://laser.gd").new()
		add_child(l)
		l.setup(float(L[0]), float(L[1]), float(L[2]), str(L[3]), L[4], float(L[5]), hum)
		lasers.append(l)
	for C in lv.get("cams", []):
		var c = preload("res://cctv.gd").new()
		add_child(c)
		c.setup(C[0], float(C[1]), float(C[2]), float(C[3]))
		cctvs.append(c)
	if lv.get("killswitch", false):
		# صندوق القاطع: لوح معدني على الجدار، أربعة أزرار ملوّنة، ولمبة تبيّن حالة الليزر
		kill_node = _box(KILL_POS + Vector3(0.06, 1.25, 0), Vector3(0.12, 0.7, 0.55), mat_steel, false)
		for k in LCOLORS.size():
			_box(KILL_POS + Vector3(0.14, 1.36 - floor(k / 2.0) * 0.2, -0.1 + (k % 2) * 0.2), Vector3(0.04, 0.1, 0.1), _glow(LCOLORS[k][1], 1.6), false)
		var lab := _label3d("قاطع الليزر", KILL_POS + Vector3(0.15, 1.72, 0), 26, Color(1.0, 0.4, 0.35))
		lab.rotation_degrees.y = 90
		kill_lamp = OmniLight3D.new()
		kill_lamp.position = KILL_POS + Vector3(0.5, 1.4, 0)
		kill_lamp.light_color = Color(1.0, 0.15, 0.1)
		kill_lamp.light_energy = 0.8
		kill_lamp.omni_range = 2.0
		add_child(kill_lamp)


func _laser_off() -> float:
	var v := 0.0
	for l in lasers:
		v = maxf(v, l.off_t)
	return v


func _cam_frozen() -> float:
	var v := 0.0
	for c in cctvs:
		v = maxf(v, c.frozen_t)
	return v


## المحلّل يتبع زمن العوائق عند العميل (المرجع).
func _apply_hazard_sync(ht: float, lz: float, cf: float) -> void:
	if role != "analyst":
		return
	htime = ht if absf(ht - htime) > 0.4 else lerpf(htime, ht, 0.3)
	for l in lasers:
		l.off_t = lz
	for c in cctvs:
		c.frozen_t = cf


func _hazards_update(delta: float) -> void:
	if role != "analyst":
		htime += delta
	for l in lasers:
		l.update(htime, delta)
	for c in cctvs:
		c.update(htime, delta)
	if kill_lamp:
		var off := _laser_off() > 0.0
		kill_lamp.light_color = Color(0.3, 1.0, 0.45) if off else Color(1.0, 0.15, 0.1)


## العميل فقط: هل لمس الليزر؟ هل رأته كاميرا؟
func _agent_hazards(delta: float) -> void:
	_laser_cd = maxf(0.0, _laser_cd - delta)
	var p: Vector3 = agent.global_position
	if invuln <= 0.0 and _laser_cd <= 0.0 and stage < 4 and not vault_mode:
		for l in lasers:
			if l.hits(p, agent.crouch):
				_laser_tripped()
				break
	var space := get_world_3d().direct_space_state
	var top := 0.0
	for c in cctvs:
		if c.cooldown <= 0.0 and invuln <= 0.0 and c.sees(p, agent.crouch, space, [agent.get_rid()]):
			c.fill = minf(1.0, c.fill + delta / (0.7 if stage >= 3 else 1.0))
			if c.fill >= 1.0:
				_cam_alarm(c)
		else:
			c.fill = maxf(0.0, c.fill - delta * 0.5)
		top = maxf(top, c.fill)
	if active == agent:
		hud.set_cam_meter(top)
		if top > 0.05:
			_beep_t -= delta
			if _beep_t <= 0.0 and s_click.stream:
				_beep_t = lerpf(0.5, 0.12, top)
				s_click.play()
	# تحذير قبل أن يعود الليزر بعد القطع
	var off := _laser_off()
	if off > 0.0 and off < 5.0 and not _laser_warned and active == agent:
		_laser_warned = true
		hud.flash("⚠ الليزر يعود خلال 5 ثوانٍ!", Color(1.0, 0.63, 0.23))
	elif off <= 0.0:
		_laser_warned = false


func _nearest_guard(p: Vector3):
	var best = null
	var bd := 1e9
	for g in guards:
		var d: float = (g.global_position as Vector3).distance_to(p)
		if d < bd:
			bd = d
			best = g
	return best


func _laser_tripped() -> void:
	_laser_cd = 4.0
	if active == agent:
		hud.flash("🚨 لمستَ الليزر! الحارس قادم — اختبئ", Color(0.9, 0.28, 0.3))
		hud.hit()
		Input.vibrate_handheld(250)
	shake = 0.35
	if s_beep.stream:
		s_beep.play()
	var g = _nearest_guard(agent.global_position)
	if g and not g.is_chasing():
		g.chase(agent)


func _cam_alarm(c) -> void:
	c.fill = 0.0
	c.cooldown = 8.0
	if active == agent:
		hud.flash("📹 رصدتك الكاميرا! الحارس في الطريق", Color(0.9, 0.28, 0.3))
		hud.hit()
		Input.vibrate_handheld(200)
	if s_beep.stream:
		s_beep.play()
	var g = _nearest_guard(agent.global_position)
	if g and not g.is_chasing():
		g.chase(agent)


func _submit_colors(picked: Array) -> void:
	if lockout > 0.0:
		hud.flash("القاطع مقفل… انتظر", Color(0.9, 0.28, 0.3))
		return
	if picked == puzzle.laser:
		hud.close_panel()
		for l in lasers:
			l.off_t = LASER_OFF
		_laser_warned = false
		hud.flash("✔ قُطع الليزر لمدّة %d ثانية — أسرع!" % int(LASER_OFF), Color(0.42, 0.85, 0.58))
		if s_clunk.stream:
			s_clunk.play()
	else:
		lockout = 4.0
		hud.flash("✖ ترتيب خاطئ — القاطع مقفل 4 ثوانٍ", Color(0.9, 0.28, 0.3))
		hud.hit()
		if s_beep.stream:
			s_beep.play()


# ───────── التدريب: سطر إرشاد يتغيّر مع تقدّم اللاعب ─────────
func _tutorial_update(delta: float) -> void:
	if agent == null:
		return
	var p: Vector3 = agent.global_position
	var tip := ""
	if active == analyst:
		match stage:
			0:
				tip = "أنت الآن المحلّل. انظر إلى الدرج المضيء واضغط الزر لتقرأ الرمز، ثم بدّل الدور (👁)"
			1:
				tip = "اقرأ «دليل الأسلاك» الأحمر: ابحث عن آخر رقم من الرقم التسلسلي. جرّب أيضاً «📹 جمّد الكاميرات»"
			2:
				tip = "شغّل الحاسوب وأدخل الرموز الثلاثة التي على باب الخزنة، واحفظ التركيبة"
			_:
				tip = "عُد إلى العميل (👁) واهرب!"
		hud.set_tip(tip)
		return
	_tut_moved += Vector2(agent.velocity.x, agent.velocity.z).length() * delta
	if _tut == 0:
		tip = "١. حرّك العصا اليسرى للمشي، واسحب يمين الشاشة لتلتفت (على الحاسوب: WASD والفأرة)"
		if _tut_moved > 3.0:
			_tut = 1
	if _tut == 1 and stage == 0:
		if p.x < 5.8:
			tip = "٢. 🔴 أمامك ليزر عالٍ! اضغط «🧎 انحنِ» (أو C) ومُرّ تحته ببطء" if p.x > 2.6 else "٢. تقدّم نحو الليزر الأحمر"
		else:
			tip = "٣. ممتاز! قِف واذهب إلى الجهاز (السهم البرتقالي). الرمز ليس عندك: اضغط «👁 بدّل الدور» لتصبح المحلّل"
	elif stage == 1:
		tip = "٤. 📹 كاميرا في الغرفة التالية: ابقَ خارج المخروط الأحمر، أو انحنِ وراء الصناديق. عدّاد أحمر = تراك"
	elif stage == 2:
		tip = "٥. صِف رموز باب الخزنة (أو بدّل الدور وأدخلها في الحاسوب)، ثم أدِر القرص على التركيبة"
	elif stage >= 3:
		tip = "٦. 🚨 اهرب إلى نقطة البداية! لا تنسَ الانحناء تحت الليزر"
	hud.set_tip(tip)


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
	l.light_energy = energy * 1.9
	l.omni_range = 9.0
	l.omni_attenuation = 1.5
	add_child(l)
	if flicker:
		flickers.append(l)
	if pos.x < 50.0:
		building_lights.append(l)
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
	# كل مرحلة مكانها الخاص؛ ونقاط اللعب (البداية، الأجهزة، البابان، الخزنة) في نفس الإحداثيات
	match str(lv.get("theme", "port")):
		"river":
			maps.river()
		"mountain":
			maps.mountain()
		_:
			_map_port()
	_build_core()


## المبنى الأصلي (الميناء والتدريب): ثلاث غرف خرسانية.
func _map_port() -> void:
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
	# الغرفة 3 (قاعة الخزنة): x 20..30
	_wall_x(0, 20, 30)
	_wall_x(10, 20, 30)
	_vault_wall(mat_wall)
	for p in [Vector3(11, 0, 2), Vector3(11.9, 0, 2), Vector3(11.45, 0.9, 2), Vector3(16, 0, 7.5), Vector3(14, 0, 4.8), Vector3(23.5, 0, 2.2), Vector3(1.3, 0, 1.3), Vector3(24.4, 0, 2.2)]:
		_box(p + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), mat_crate)
	# إضاءة مخيفة: مصباح خافت + مصابيح ترتعش + مصباح طوارئ أحمر
	_lamp(Vector3(4, WALL_H, 4), Color(1.0, 0.82, 0.58), 1.0)
	_lamp(Vector3(14, WALL_H, 5), Color(1.0, 0.86, 0.62), 1.2, true)
	vault_lamp = _lamp(Vector3(25, WALL_H, 5), Color(0.6, 0.75, 1.0), 0.8, true)
	var red := OmniLight3D.new()
	red.position = Vector3(19.6, 2.6, 1.0)
	red.light_color = Color(1.0, 0.12, 0.08)
	red.light_energy = 1.4
	red.omni_range = 5.0
	add_child(red)
	_box(Vector3(19.8, 2.6, 1.0), Vector3(0.12, 0.18, 0.18), _glow(Color(1.0, 0.15, 0.1), 3.0), false)
	for c in [Vector3(4, 1.6, 4), Vector3(14, 1.6, 5), Vector3(25, 1.6, 5)]:
		_probe(c, Vector3(12, WALL_H, 10.5))
	_dust(Vector3(15, 1.6, 5), Vector3(15, 1.5, 5))
	if lv.id == "tutorial":
		# قاعة تدريب: أرضية بخطوط صفراء وأرقام المحطّات
		var tape := _glow(Color(0.95, 0.75, 0.15), 0.6)
		for x in [3.6, 6.4]:
			_box(Vector3(x, 0.005, 4.0), Vector3(0.08, 0.01, 7.6), tape, false)
		for st in [["١ امشِ", Vector3(1.0, 2.4, 6.0)], ["٢ انحنِ تحت الليزر", Vector3(4.9, 2.6, 7.7)], ["٣ لوحة الأرقام", Vector3(7.4, 2.4, 0.4)], ["٤ الكاميرا", Vector3(14.0, 2.5, 9.7)], ["٥ الخزنة", Vector3(25.0, 2.6, 9.7)]]:
			var lb := _label3d(str(st[0]), st[1], 40, Color(0.95, 0.75, 0.15))
			if (st[1] as Vector3).z > 5.0:
				lb.rotation_degrees.y = 180


## يبني شيئاً في إحداثيات الخزنة الأصلية ثم ينقله مع الخزنة (جدارها في كل خريطة).
func _in_vault_frame(f: Callable) -> void:
	var before := get_child_count()
	f.call()
	var root := Node3D.new()
	var moved := []
	for i in range(before, get_child_count()):
		moved.append(get_child(i))
	add_child(root)
	for n in moved:
		n.reparent(root, false)
	root.transform = vault_xf


func _probe(c: Vector3, size: Vector3) -> void:
	var rp := ReflectionProbe.new()
	rp.position = c
	rp.size = size
	rp.box_projection = true
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	rp.intensity = 0.7
	add_child(rp)


## الجدار الشرقي لقاعة الخزنة (فتحة للإطار الفولاذي).
func _vault_wall(mat: Material) -> void:
	_wall_z(30, 0, 3.6, mat)
	_wall_z(30, 6.4, 10, mat)
	_box(Vector3(30, 2.95, 5), Vector3(0.3, 0.5, 2.8), mat)


## ما تشترك فيه كل المراحل: حجرة الكنز، البابان، الجهازان، الخزنة، والسهم.
func _build_core() -> void:
	# الخزنة وحجرة الكنز تُبنى في إحداثياتها الأصلية ثم تُنقل كلّها إلى مكانها في الخريطة
	var before := get_child_count()
	_wall_x(3.4, 30, 33.3, mat_steel)
	_wall_x(6.6, 30, 33.3, mat_steel)
	_wall_z(33.3, 3.4, 6.6, mat_steel)
	if str(lv.get("theme", "port")) != "port":
		_box(Vector3(31.65, -0.1, 5), Vector3(3.6, 0.2, 3.6), mat_steel)
		_box(Vector3(31.65, WALL_H + 0.1, 5), Vector3(3.6, 0.2, 3.6), mat_steel)
	for i in 6:
		var gold := _box(Vector3(31.4 + (i % 3) * 0.45, 0.08 + float(i / 3) * 0.16, 4.85 + (i % 2) * 0.3), Vector3(0.4, 0.15, 0.22), _glow(Color(1.0, 0.75, 0.25), 1.6), false)
		gold.rotation.y = 0.05 * i
	var treasure := OmniLight3D.new()
	treasure.position = Vector3(31.8, 1.2, 5)
	treasure.light_color = Color(1.0, 0.78, 0.35)
	treasure.light_energy = 2.5
	treasure.omni_range = 4.0
	add_child(treasure)

	_build_vault()
	var vroot := Node3D.new()
	vroot.name = "VaultRoot"
	var moved := []
	for i in range(before, get_child_count()):
		moved.append(get_child(i))
	add_child(vroot)
	for n in moved:
		n.reparent(vroot, false)
	vroot.transform = vault_xf
	VAULT_FRONT = vault_xf * VAULT_C
	for ds in door_specs:
		var d := _door(ds[0])
		(d.body as Node3D).rotation.y = float(ds[1])
		d["dir"] = ds[2]
		doors.append(d)
	for ts in term_specs:
		terminals.append(_terminal(ts[0], str(ts[2]), float(ts[1])))

	marker = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.22, 0.3, 0.22)
	marker.mesh = pm
	marker.material_override = _glow(Color(1.0, 0.63, 0.23), 4.0)
	marker.rotation_degrees.x = 180
	add_child(marker)


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


func _terminal(pos: Vector3, title: String, facing := 0.0) -> Dictionary:
	var root := _box(pos + Vector3(0, 0.75, 0), Vector3(0.6, 1.5, 0.45), mat_dark)
	var screen := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.44, 0.3)
	screen.mesh = qm
	screen.material_override = _glow(Color(1.0, 0.63, 0.23), 3.0)
	var front := facing if facing != 0.0 else (1.0 if pos.z < 5 else -1.0)
	var face := Vector3(0, 0.35, 0.231 * front)
	screen.position = face
	if front < 0.0:
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
	# أجسام تصادم صريحة حول الفتحة: لا يمكن الدخول في الإطار أبداً
	for bx in [[Vector3(29.9, 2.83, 5), Vector3(0.55, 0.34, 3.0)], [Vector3(29.9, 0.17, 5), Vector3(0.55, 0.34, 3.0)], [Vector3(29.9, 1.5, 3.67), Vector3(0.55, 2.4, 0.34)], [Vector3(29.9, 1.5, 6.33), Vector3(0.55, 2.4, 0.34)]]:
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var bsh := BoxShape3D.new()
		bsh.size = bx[1]
		col.shape = bsh
		sb.add_child(col)
		sb.position = bx[0]
		add_child(sb)
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
	# بخار يخرج من حواف الباب عند الفتح
	steam = CPUParticles3D.new()
	steam.position = Vector3(29.45, 1.5, 5)
	steam.emitting = false
	steam.one_shot = true
	steam.explosiveness = 0.5
	steam.amount = 140
	steam.lifetime = 2.6
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	steam.emission_ring_axis = Vector3(1, 0, 0)
	steam.emission_ring_radius = 1.12
	steam.emission_ring_inner_radius = 1.0
	steam.emission_ring_height = 0.05
	steam.direction = Vector3(-1, 0.2, 0)
	steam.spread = 35
	steam.gravity = Vector3(0, 0.35, 0)
	steam.initial_velocity_min = 0.5
	steam.initial_velocity_max = 1.3
	steam.scale_amount_min = 0.6
	steam.scale_amount_max = 1.6
	var sq := QuadMesh.new()
	sq.size = Vector2(0.35, 0.35)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.9, 0.92, 0.95, 0.18)
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sq.material = smat
	steam.mesh = sq
	add_child(steam)
	# حاجز غير مرئي: لا يمكن الاقتراب من الباب أكثر من متر ونصف (فلا تدخل في الجدار أبداً)
	var bar := StaticBody3D.new()
	var bcol := CollisionShape3D.new()
	var bbox := BoxShape3D.new()
	bbox.size = Vector3(0.2, WALL_H, 3.4)
	bcol.shape = bbox
	bar.add_child(bcol)
	bar.position = Vector3(28.4, WALL_H / 2.0, 5)
	add_child(bar)
	vault_barrier = bar
	# دائرة مضيئة على الأرض: «قف هنا»
	var stand := MeshInstance3D.new()
	var rt := TorusMesh.new()
	rt.inner_radius = 0.62
	rt.outer_radius = 0.72
	stand.mesh = rt
	stand.material_override = _glow(Color(1.0, 0.63, 0.23), 2.5)
	stand.position = VAULT_C + Vector3(0, 0.02, 0)
	add_child(stand)
	vault_ring = stand
	var light := SpotLight3D.new()
	add_child(light)
	light.look_at_from_position(Vector3(26.5, 3.0, 5), Vector3(29.8, 1.3, 5))
	light.light_color = Color(0.8, 0.88, 1.0)
	light.light_energy = 3.0
	light.spot_angle = 28
	light.spot_range = 8
	light.shadow_enabled = true


func _spawn_guards() -> void:
	var n := 1 if lv.id == "tutorial" else (3 if lv.get("extra_guard", false) else 2)
	for k in mini(n, guard_routes.size()):
		var r: Array = guard_routes[k]
		var g = preload("res://guard.gd").new()
		add_child(g)
		g.setup(r[0], float(r[1]), r[2])
		if r.size() > 3:
			g.chief = bool((r[3] as Dictionary).get("chief", false))
			g.has_card = bool((r[3] as Dictionary).get("card", false))
		guards.append(g)
	for gg in guards:
		gg.speed *= float(lv.guard_speed)
		gg.sight = float(lv.guard_sight)
		gg.remote = role == "analyst"
		gg.apply_remote(gg.position, gg.rotation.y, "walk")
		gg.decorate()
	# خزائن وصناديق لإخفاء الأجسام، وعلب للرمي
	for h in hide_spots:
		var hp: Vector3 = h[0]
		var lk := _box(hp + Vector3(0, 1.0, 0), Vector3(0.7, 2.0, 0.55), mat_steel)
		lk.set_meta("hide", true)
		var hl := _label3d("📦 " + str(h[1]), hp + Vector3(0, 2.25, 0), 26, Color(0.75, 0.85, 1.0))
		hl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var rngc := RandomNumberGenerator.new()
	rngc.seed = seed_value + 99
	for cp in [checkpoints[0] + Vector3(1.2, 0, -1.4), checkpoints[1] + Vector3(1.0, 0, 3.0), checkpoints[2] + Vector3(1.2, 0, 3.4)]:
		var cn := _can_mesh(cp + Vector3(rngc.randf_range(-0.4, 0.4), 0.06, rngc.randf_range(-0.4, 0.4)))
		can_nodes.append(cn)


func _make_avatar() -> Node3D:
	# صورة العميل عند المحلّل: نفس الشخصية وحركاتها (تتحرّك بما يرسله هاتف العميل)
	var a = preload("res://agent_body.gd").new()
	a.position = SPAWN
	add_child(a)
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0.15, 1.4, -0.3)
	lamp.light_color = Color(1.0, 0.94, 0.82)
	lamp.light_energy = 2.0
	lamp.spot_range = 9.0
	lamp.spot_angle = 25.0
	a.add_child(lamp)
	return a


# ───────── غرفة المحلّل (الأرشيف) ─────────
func _build_archive() -> void:
	var o := ARCHIVE
	_box(o + Vector3(5, -0.1, 4), Vector3(10.6, 0.2, 8.6), mat_wood)
	_box(o + Vector3(5, WALL_H + 0.1, 4), Vector3(10.6, 0.2, 8.6), mat_ceil)
	_wall_x(o.z + 0, o.x, o.x + 10, mat_wall_dark)
	if analyst_kind == "archive":
		_wall_x(o.z + 8, o.x, o.x + 10, mat_wall_dark)
	else:
		# غرفة مراقبة بنافذة عريضة تطلّ على الهدف (المنظار 🔭 يقرّب الرؤية)
		_box(Vector3(o.x + 5, 0.5, o.z + 8), Vector3(10.3, 1.0, 0.3), mat_wall_dark)
		_box(Vector3(o.x + 5, WALL_H - 0.3, o.z + 8), Vector3(10.3, 0.6, 0.3), mat_wall_dark)
		_box(Vector3(o.x + 5, 1.6, o.z + 8), Vector3(10.0, 1.2, 0.05), null, true).visible = false
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.5, 0.6, 0.7, 0.12)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.metallic = 0.6
		glass.roughness = 0.05
		_box(Vector3(o.x + 5, 1.6, o.z + 8), Vector3(10.0, 1.2, 0.02), glass, false)
		for k in 5:
			_box(Vector3(o.x + 0.1 + k * 2.45, 1.6, o.z + 8), Vector3(0.12, 1.25, 0.14), mat_steel, false)
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
	var morse_book: bool = gate_types.has("radio")
	book.set_meta("kind", "morse" if morse_book else "book")
	book_node = book
	var bl := _label3d("دليل مورس" if morse_book else "دليل الأسلاك", o + Vector3(3.2, 0.875, 1.3), 24, Color(1.0, 0.9, 0.8))
	bl.rotation_degrees.x = -90
	# خزانة الأدراج: الدرج العلوي يُفتح وفيه ورقة
	_box(o + Vector3(9.4, 0.6, 4.5), Vector3(0.7, 1.2, 0.9), mat_crate)
	drawer = _box(o + Vector3(9.1, 1.0, 4.5), Vector3(0.12, 0.3, 0.8), mat_steel)
	if gate_types.has("keypad"):
		drawer.set_meta("kind", "drawer")
	var gauge_node: Node3D = null
	if gate_types.has("valves"):
		gauge_node = _box(o + Vector3(7.3, 1.08, 0.95), Vector3(0.75, 0.5, 0.08), mat_dark)
		gauge_node.set_meta("kind", "gauges")
		var gs := MeshInstance3D.new()
		var gq := QuadMesh.new()
		gq.size = Vector2(0.68, 0.42)
		gs.mesh = gq
		gs.material_override = _glow(Color(0.25, 0.7, 0.95), 1.4)
		gs.position = Vector3(0, 0, 0.045)
		gauge_node.add_child(gs)
		_label3d("ضغط المضخّات", o + Vector3(7.3, 1.42, 1.0), 24, Color(0.7, 0.9, 1.0))
	var hack_node: Node3D = null
	if gate_types.has("keycard"):
		hack_node = _box(o + Vector3(7.3, 0.88, 1.0), Vector3(0.6, 0.04, 0.42), mat_dark)
		hack_node.set_meta("kind", "hack")
		var lid := _box(o + Vector3(7.3, 1.08, 0.8), Vector3(0.6, 0.4, 0.03), mat_dark, false)
		lid.rotation.x = -0.25
		var lsc := MeshInstance3D.new()
		var lsq := QuadMesh.new()
		lsq.size = Vector2(0.54, 0.34)
		lsc.mesh = lsq
		lsc.material_override = _glow(Color(0.2, 0.95, 0.45), 1.6)
		lsc.position = Vector3(0, 0, 0.02)
		lid.add_child(lsc)
		_label3d("جهاز الاختراق", o + Vector3(7.3, 1.42, 0.9), 24, Color(0.6, 1.0, 0.7))
	var log_node: Node3D = null
	if gate_types.has("servers"):
		log_node = _box(o + Vector3(7.3, 1.08, 0.95), Vector3(0.75, 0.5, 0.08), mat_dark)
		log_node.set_meta("kind", "serverlog")
		var ls := MeshInstance3D.new()
		var lq := QuadMesh.new()
		lq.size = Vector2(0.68, 0.42)
		ls.mesh = lq
		ls.material_override = _glow(Color(0.85, 0.25, 0.2), 1.4)
		ls.position = Vector3(0, 0, 0.045)
		log_node.add_child(ls)
		_label3d("سجلّ الاختراق", o + Vector3(7.3, 1.42, 1.0), 24, Color(1.0, 0.7, 0.6))
	var bp_node: Node3D = null
	if gate_types.has("maze"):
		bp_node = _box(o + Vector3(0.25, 1.6, 6.3), Vector3(0.06, 1.0, 1.4), _glow(Color(0.1, 0.3, 0.6), 0.9))
		bp_node.set_meta("kind", "blueprint")
		var bpl := _label3d("مخطّط الأنفاق", o + Vector3(0.3, 2.25, 6.3), 26, Color(0.6, 0.85, 1.0))
		bpl.rotation_degrees.y = 90
	for gt in gate_types:
		match str(gt):
			"keycard":
				analyst_targets.append(hack_node)
			"checkpoint":
				analyst_targets.append(null)
			"servers":
				analyst_targets.append(log_node)
			"maze":
				analyst_targets.append(bp_node)
			"keypad":
				analyst_targets.append(drawer)
			"wires", "radio":
				analyst_targets.append(book_node)
			"valves":
				analyst_targets.append(gauge_node)
	analyst_targets.append(pc_node)
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
	# سجلّ الليزر (في المراحل التي فيها قاطع): لوح على الجدار الشرقي
	if lv.get("killswitch", false):
		laserdoc_node = _box(o + Vector3(9.85, 1.6, 2.2), Vector3(0.08, 0.9, 1.2), _glow(Color(0.18, 0.05, 0.05), 0.6))
		laserdoc_node.set_meta("kind", "laserdoc")
		var ll := _label3d("سجلّ الليزر", o + Vector3(9.8, 2.2, 2.2), 30, Color(1.0, 0.35, 0.3))
		ll.rotation_degrees.y = -90
		for k in 3:
			_box(o + Vector3(9.8, 1.35 + k * 0.22, 2.2), Vector3(0.02, 0.05, 0.9), _glow(Color(0.9, 0.85, 0.75), 0.25), false)
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
	cabin_lights.append(desk)
	cabin_lights.append(_lamp(o + Vector3(5, WALL_H, 5), Color(0.75, 0.82, 1.0), 0.7, true))
	var red := OmniLight3D.new()
	red.position = o + Vector3(9.5, 2.7, 7.5)
	red.light_color = Color(1.0, 0.1, 0.08)
	red.light_energy = 1.0
	red.omni_range = 4.0
	add_child(red)
	cabin_lights.append(red)
	_dust(o + Vector3(5, 1.5, 4), Vector3(5, 1.4, 4))


func _build_feeds() -> void:
	# ثلاث كاميرات مراقبة حيّة في المبنى، معروضة على شاشات الأرشيف بفلتر قديم
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D feed : source_color;
uniform float glitch = 0.0;
void fragment() {
	vec2 uv = UV;
	uv.x += glitch * (fract(sin(floor(UV.y * 40.0) + TIME * 30.0) * 9.0) - 0.5) * 0.15;
	vec3 c = texture(feed, uv).rgb;
	float g = dot(c, vec3(0.3, 0.59, 0.11)) * 1.8 * (1.0 - glitch * 0.7);
	g *= 0.86 + 0.14 * sin(UV.y * 420.0 + TIME * 9.0);
	float n = fract(sin(dot(UV * (TIME + 1.0), vec2(12.9898, 78.233))) * 43758.5453);
	g += (n - 0.5) * 0.09;
	vec2 d = UV - 0.5;
	g *= 1.0 - dot(d, d) * 1.4;
	g += glitch * fract(sin(dot(UV * TIME, vec2(91.7, 37.3))) * 4375.5) * 0.8;
	ALBEDO = vec3(g * 0.7, g * 1.0, g * 0.75);
}
"""
	var cams := feed_cams
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
		feed_mats.append(mm)
		quad.position = Vector3(0, 0, 0.055)
		mon.add_child(quad)
		_label3d(cams[i][2], ARCHIVE + Vector3(2.6 + i * 2.4, 1.28, 0.37), 26, Color(0.6, 0.9, 0.65))
		var glow := OmniLight3D.new()
		glow.position = ARCHIVE + Vector3(2.6 + i * 2.4, 1.9, 0.9)
		glow.light_color = Color(0.5, 0.9, 0.6)
		glow.light_energy = 0.5
		glow.omni_range = 2.5
		add_child(glow)
		cabin_lights.append(glow)


# ───────── اللعب ─────────
func _process(delta: float) -> void:
	if started and not ready_world:
		return
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
		if avatar.has_meta("target"):
			avatar.position = avatar.position.lerp(avatar.get_meta("target"), minf(1.0, delta * 8.0))
			avatar.rotation.y = lerp_angle(avatar.rotation.y, float(avatar.get_meta("yaw")), minf(1.0, delta * 8.0))

	if net:
		if role == "agent" and agent:
			_send_t -= delta
			if _send_t <= 0.0:
				_send_t = 0.1
				var gl := []
				for g in guards:
					var gp: Vector3 = g.global_position
					gl.append([snappedf(gp.x, 0.01), snappedf(gp.z, 0.01), snappedf(g.rotation.y, 0.01), g.state_name()])
				net.send({"t": "pos", "x": snappedf(agent.global_position.x, 0.01), "z": snappedf(agent.global_position.z, 0.01), "y": snappedf(agent.face, 0.01), "a": agent.body.clip if agent.body else "idle", "d": disguised, "g": gl, "ht": snappedf(htime, 0.01), "lz": snappedf(_laser_off(), 0.1), "cf": snappedf(_cam_frozen(), 0.1)})
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

	_hazards_update(delta)
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
	_morse_update()
	_sync_update()
	_patrol_update(delta)
	if maps.has_method("tick"):
		maps.tick(htime)
	_maze_dark()
	if _bp_open:
		if hud.panel_open():
			_bp_t -= delta
			if _bp_t <= 0.0:
				_bp_t = 0.15
				var ap: Vector3 = agent.global_position if agent else (avatar.position if avatar else Vector3(-999, 0, -999))
				var gp := []
				for g in guards:
					gp.append(Vector2((g.global_position as Vector3).x, (g.global_position as Vector3).z))
				hud.update_blueprint(Vector2(ap.x, ap.z), gp)
		else:
			_bp_open = false
	if _gauges_open:
		if hud.panel_open():
			_gauge_t -= delta
			if _gauge_t <= 0.0:
				_gauge_t = 0.2
				hud.update_gauges(_gauges(), puzzle.vtarget, _gauge_max())
		else:
			_gauges_open = false
	var win_room := analyst_kind != "archive"
	hud.set_analyst_buttons(win_room and analyst != null and active == analyst and result == "", binoc, analyst_dark)
	if lv.id == "tutorial":
		_tutorial_update(delta)
	hud.set_crouch(agent != null and active == agent and not vault_mode and result == "", agent != null and agent.crouch)
	if active != agent:
		hud.set_cam_meter(0.0)
	_audio_update(delta)
	_fear_update(delta, t)
	for k in tool_cd:
		tool_cd[k] = maxf(0.0, float(tool_cd[k]) - delta)
	hud.set_tools(analyst != null and active == analyst and result == "" and not analyst_dark and analyst_locked <= 0.0, tool_cd)
	_music_update(delta)
	if agent:
		var cam: Camera3D = agent.cam
		if shake > 0.0 and active == agent:
			shake = maxf(0.0, shake - delta)
			var k := minf(shake, 1.0) * 0.06
			cam.h_offset = randf_range(-k, k)
			cam.v_offset = randf_range(-k, k)
		else:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
	if agent:
		_agent_logic(delta, t)
		if active == agent and _act != "" and not vault_mode and result == "":
			hud.show_interact(_act)
		hud.set_agent_buttons(active == agent and result == "" and not vault_mode, agent.running, instinct_cd, cans, _act2 if active == agent else "")
	else:
		hud.set_agent_buttons(false, false, 0.0, 0, "")
	_analyst_tips(delta)
	if analyst and active == analyst:
		_analyst_logic()
	_apply_stage()


## مفاجآت مخيفة: انقطاع الكهرباء، أصوات خلفك، مصباح يرتعش، شاشات تتشوّش، ومصاريع الهروب.
func _fear_update(delta: float, t: float) -> void:
	var in_play := result == "" and stage < 3
	# انقطاع الكهرباء كل 45–75 ثانية لمدّة 4 ثوانٍ (الحسّ للطرفين: الكاميرات تنقطع أيضاً)
	if in_play:
		_fear_t -= delta
		if _fear_t <= 0.0 and blackout <= 0.0:
			_fear_t = randf_range(110.0, 160.0)
			blackout = 4.0
			if s_clunk.stream:
				s_clunk.play()
			shake = 0.2
			if active == agent:
				hud.flash("⚡ انقطعت الكهرباء…", Color(0.7, 0.75, 0.85))
	if blackout > 0.0:
		blackout -= delta
		var dark := blackout > 0.3
		for l in building_lights:
			(l as OmniLight3D).visible = not dark or (blackout < 0.9 and fmod(t * 17.0, 1.0) > 0.6)
		for m in feed_mats:
			(m as ShaderMaterial).set_shader_parameter("glitch", 1.0 if dark else 0.0)
		if blackout <= 0.0:
			for l in building_lights:
				(l as OmniLight3D).visible = true
	# أصوات خلف العميل (ضربة حديد، باب يُصفق) كل 20–40 ثانية
	if agent and active == agent and in_play:
		_creep_t -= delta
		if _creep_t <= 0.0 and s_creep.stream:
			_creep_t = randf_range(20.0, 40.0)
			var ab := Basis(Vector3.UP, agent.yaw)
			var back: Vector3 = ab.z * 5.0 + ab.x * randf_range(-3.0, 3.0)
			s_creep.global_position = agent.global_position + back + Vector3(0, 1.5, 0)
			s_creep.pitch_scale = randf_range(0.55, 0.8)
			s_creep.play()
	# مصباح العميل يرتعش عندما يقترب حارس
	if agent:
		var near := 99.0
		for g in guards:
			near = minf(near, (g.global_position as Vector3).distance_to(agent.global_position))
		var base := 3.2
		agent.flash.light_energy = base * (0.15 if near < 5.0 and fmod(t * 11.0 + sin(t * 3.0), 1.0) > 0.82 else 1.0)
	# شاشات المراقبة تتشوّش أحياناً عند المحلّل
	if feed_mats.size() > 0 and blackout <= 0.0:
		_glitch_t -= delta
		if _glitch_t <= 0.0:
			_glitch_t = randf_range(25.0, 45.0)
			var m: ShaderMaterial = feed_mats[randi() % feed_mats.size()]
			m.set_shader_parameter("glitch", 1.0)
			get_tree().create_timer(2.5).timeout.connect(func(): m.set_shader_parameter("glitch", 0.0))
	# الهروب: المصاريع تنزل واحداً بعد الآخر (الباب الثاني بعد 22 ث، الأول بعد 36 ث من الإنذار)
	if stage >= 3 and escape_left >= 0.0:
		var since := ESCAPE_SECONDS - escape_left
		for i in [1, 0]:
			var at := 22.0 if i == 1 else 36.0
			if since > at - 5.0 and since < at and int(since * 4.0) % 2 == 0 and active == agent:
				hud.flash("⚠ الباب يُغلق خلال %d ث!" % int(ceil(at - since)), Color(1.0, 0.63, 0.23))
			if since >= at and not shutters_closed[i]:
				shutters_closed[i] = true
				_close_shutter(i)


func _close_shutter(i: int) -> void:
	var d: Dictionary = doors[i]
	(d.stripe as MeshInstance3D).material_override = _glow(Color(0.95, 0.2, 0.2), 3.0)
	if s_door.stream:
		s_door.global_position = (d.body as Node3D).global_position
		s_door.play()
	var tw := create_tween()
	tw.tween_property(d.body, "position:y", WALL_H / 2.0, 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	# العميل بقي خلف الباب المغلق ← حُبس
	var dpos: Vector3 = (d.body as Node3D).global_position
	var inward: Vector3 = d.get("dir", Vector3(1, 0, 0))
	if agent and role != "analyst" and result == "" and (agent.global_position - dpos).dot(inward) > 0.2:
		hud.flash("⛓ حُبستَ خلف الباب!", Color(0.9, 0.28, 0.3))
		_end(false)


## أدوات المحلّل: تُرسَل إلى هاتف العميل (مرجع الحرّاس)، أو تُنفَّذ محلياً في الوضع الفردي.
func _on_tool(kind: String) -> void:
	if float(tool_cd.get(kind, 0.0)) > 0.0:
		return
	tool_cd[kind] = TOOL_CD[kind]
	if kind == "mark":
		for g in guards:
			g.mark(6.0)
	if kind == "freeze":
		for c in cctvs:
			c.frozen_t = 8.0
	if role == "analyst" and net:
		net.send({"t": "tool", "k": kind})
		hud.flash({"mark": "📍 حُدِّد الحرّاس للعميل", "distract": "🔊 شُتِّت أقرب حارس", "freeze": "📹 جُمّدت الكاميرات 8 ثوانٍ", "blackout": "⚡ قطعتَ الكهرباء 6 ثوانٍ", "warn": "⚠ وصل التحذير"}[kind], Color(0.6, 0.95, 0.7))
	else:
		_do_tool(kind)


func _do_tool(kind: String) -> void:
	match kind:
		"mark":
			for g in guards:
				g.mark(6.0)
			hud.flash("📍 المحلّل حدّد الحرّاس — تراهم عبر الجدران", Color(1.0, 0.45, 0.35))
		"distract":
			var best = null
			var bd := 1e9
			for g in guards:
				var d: float = (g.global_position as Vector3).distance_to(agent.global_position) if agent else 0.0
				if d < bd:
					bd = d
					best = g
			if best:
				# إنذار كاذب بعيداً عن العميل: الحارس يذهب ليفحصه
				var away: Vector3 = (best.global_position as Vector3) - agent.global_position
				away.y = 0.0
				best.investigate((best.global_position as Vector3) + away.normalized() * 5.0)
			hud.flash("🔊 المحلّل أطلق إنذاراً كاذباً — الحارس يذهب بعيداً!", Color(0.6, 0.95, 0.7))
		"blackout":
			blackout = 6.0
			for g in guards:
				if not g.ko and not g.is_chasing():
					g.distract()
					g.sus = 0.0
			hud.flash("⚡ المحلّل قطع الكهرباء — الحرّاس لا يرون، تحرّك!", Color(0.6, 0.95, 0.7))
		"freeze":
			for c in cctvs:
				c.frozen_t = 8.0
				c.fill = 0.0
			hud.flash("📹 المحلّل جمّد الكاميرات — 8 ثوانٍ!", Color(0.6, 0.95, 0.7))
		"warn":
			hud.flash("⚠ المحلّل: حارس قريب منك!", Color(1.0, 0.63, 0.23))
			hud.hit()
			if s_clunk.stream:
				s_clunk.play()
			Input.vibrate_handheld(300)


func _hint_update(t: float) -> void:
	var target: Node3D = null
	if stage < analyst_targets.size():
		target = analyst_targets[stage]
	var on: bool = target != null and analyst != null and active == analyst and not hud.panel_open()
	hint_light.visible = on
	hint_arrow.visible = on
	if on:
		var p := target.global_position
		hint_light.global_position = p + Vector3(0, 0.4, 0)
		hint_light.light_energy = 1.2 + 0.8 * sin(t * 5.0)
		hint_arrow.global_position = p + Vector3(0, 0.6 + 0.08 * sin(t * 4.0), 0)
		hint_arrow.rotation.y = t * 2.0


## موسيقى التوتر: تعلو مع المطاردة والإنذار، وتهدأ عند الاختباء.
func _music_update(delta: float) -> void:
	if s_music == null or s_music.stream == null:
		return
	var chasing := false
	for g in guards:
		if g.is_chasing():
			chasing = true
	var target := -40.0
	if chasing or (stage >= 3 and result == ""):
		target = -3.0
	elif seen_time > 0.0:
		target = -14.0
	s_music.volume_db = move_toward(s_music.volume_db, target, delta * (40.0 if target > s_music.volume_db else 10.0))
	if s_music.volume_db > -39.0 and not s_music.playing:
		s_music.play()
	elif s_music.volume_db <= -39.5 and s_music.playing:
		s_music.stop()


func _audio_update(delta: float) -> void:
	if agent == null or active != agent:
		if s_steps.playing:
			s_steps.stop()
		s_heart.volume_db = move_toward(s_heart.volume_db, -40.0, delta * 30.0)
		return
	var moving: bool = Vector2(agent.velocity.x, agent.velocity.z).length() > 0.5
	s_steps.volume_db = -20.0 if agent.crouch else -10.0
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
	for g in guards:
		if g.is_chasing():
			danger = 1.0
	if s_heart.stream:
		if danger > 0.05 and not s_heart.playing:
			s_heart.play()
		s_heart.volume_db = lerpf(-30.0, 2.0, danger)
		if danger <= 0.05 and s_heart.playing:
			s_heart.stop()


func _agent_logic(delta: float, t: float) -> void:
	var goal: Vector3 = SPAWN if stage >= 3 else (VAULT_FRONT if stage == 2 else (terminals[stage].pos as Vector3))
	if active == agent and not vault_mode:
		var local: Vector3 = (Basis(Vector3.UP, agent.yaw).inverse() * (goal - agent.global_position))
		hud.set_compass(atan2(local.x, -local.z), Vector2(local.x, local.z).length(), stage >= 3)
	else:
		hud.set_compass(0.0, -1.0, false)
	marker.position = goal + Vector3(0, 2.1 + 0.08 * sin(t * 3.0), 0)
	marker.rotation.y = t * 1.5
	marker.visible = active == agent

	invuln = maxf(0.0, invuln - delta)
	lockout = maxf(0.0, lockout - delta)
	var space := get_world_3d().direct_space_state
	var top_sus := 0.0
	_seer = null
	var ap: Vector3 = agent.global_position
	for g in guards:
		if g.ko:
			continue
		var sees_now: bool = invuln <= 0.0 and g.sees(agent, space)
		g.saw = sees_now
		var dist: float = (g.global_position as Vector3).distance_to(ap)
		# الشكّ: بلا تنكّر يمتلئ بسرعة؛ بالتنكّر لا يشكّ الحارس إلا إن ركضت أو انحنيت أمامه أو التصقت به، والرئيس يكشفك
		var rate := 0.0
		if sees_now:
			if not disguised:
				rate = 1.0 / 0.6
			elif g.chief:
				rate = 1.1 if dist < 7.0 else 0.35
			elif agent.running:
				rate = 0.9
			elif agent.crouch or agent.dragging:
				rate = 0.6
			elif dist < 2.0:
				rate = 0.25
			if (active == agent and hud.panel_open()) or vault_mode:
				rate *= 1.4
		if rate > 0.0:
			g.sus = minf(1.0, g.sus + rate * delta)
			_seer = g
		else:
			g.sus = maxf(0.0, g.sus - delta * 0.5)
		# الركض يُسمع: الحارس القريب يذهب ليرى
		if agent.running and not disguised and dist < 6.5 and not g.is_chasing() and g.state_name() == "walk":
			g.investigate(ap)
		if not g.is_chasing():
			if g.sus >= 1.0:
				g.chase(agent)
				g.sus = 1.0
				stats.seen += 1
				if active == agent:
					hud.flash("🏃 كشفك الحارس! اهرب واختبئ" if not disguised else "🎭 كُشف تنكّرك! اهرب", Color(0.9, 0.28, 0.3))
					hud.hit()
					hud.close_panel()
				if vault_mode:
					_exit_vault()
			else:
				g.set_alert(sees_now and g.sus > 0.25, ap)
		# أمسكه الحارس
		elif invuln <= 0.0 and dist < 1.15:
			_seer = g
			_spotted()
			return
		top_sus = maxf(top_sus, g.sus)
		# جسم حارس ساقط ومكشوف؟
		for b in guards:
			if b.ko and not b.hidden and b != g and g.sees_point(b.global_position, space):
				_body_found(g, b)
	seen_time = top_sus * 0.6
	if active == agent:
		hud.set_alert(top_sus)
	_agent_hazards(delta)
	_hitman_update(delta)

	if vault_mode:
		agent.look_delta = Vector2.ZERO
		# القرص ثلاثي الأبعاد يدور بنعومة نحو الرقم المختار
		vault_dial.rotation.x = lerp_angle(vault_dial.rotation.x, -dial_number * TAU / 40.0, minf(1.0, delta * 14.0))
		return

	if active != agent:
		return
	if stage >= 3:
		hud.show_interact("قاطع الليزر" if _near_kill() and _laser_off() <= 0.0 else "")
		if agent.global_position.distance_to(SPAWN) < 1.4:
			_end(true)
		return
	if _near_kill():
		hud.show_interact("قاطع الليزر" if _laser_off() <= 0.0 else "الليزر مقطوع (%d ث)" % int(ceil(_laser_off())))
	elif stage < 2:
		var near: bool = agent.global_position.distance_to(terminals[stage].pos) < 1.7
		hud.show_interact(("استعمل " + str(terminals[stage].title)) if near else "")
	else:
		var near2: bool = Vector2(agent.global_position.x - VAULT_FRONT.x, agent.global_position.z - VAULT_FRONT.z).length() < 1.3
		hud.show_interact("افتح الخزنة" if near2 else "")


func _near_kill() -> bool:
	return kill_node != null and Vector2(agent.global_position.x - KILL_POS.x, agent.global_position.z - KILL_POS.z).length() < 1.5


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
	var labels := {"drawer": "اقرأ الورقة" if drawer_open else "افتح الدرج", "book": "اقرأ دليل الأسلاك", "computer": "شغّل الحاسوب", "monitor": "كبّر الشاشة", "laserdoc": "اقرأ سجلّ الليزر", "gauges": "افتح مخطّط الضغط", "morse": "اقرأ دليل مورس", "serverlog": "اقرأ سجلّ الاختراق", "blueprint": "افتح مخطّط الأنفاق", "hack": "اخترق الباب"}
	hud.show_interact(str(labels.get(kind, "")))
	analyst.set_meta("looking", obj)


func _on_interact() -> void:
	if active == analyst:
		_analyst_interact()
		return
	if _act != "" and not vault_mode:
		_do_act(false)
		return
	if _near_kill():
		if _laser_off() <= 0.0:
			hud.open_colors("قاطع الليزر", LCOLORS, _submit_colors)
		return
	if stage >= 3:
		return
	if stage == 2:
		_enter_vault()
		return
	match str(gate_types[stage]):
		"keypad":
			hud.open_keypad("لوحة الأرقام — الرمز في درج مكتب المحلّل", _submit_code)
		"wires":
			var wl := []
			for w in puzzle.wires:
				wl.append(WIRES[w])
			hud.open_wires(str(puzzle.serial), wl, _cut_wire)
		"valves":
			hud.open_valves(valves, VALVE_TAGS, _turn_valve, _confirm_valves)
		"radio":
			_radio_open = true
			hud.open_radio(radio_cur, _tune_radio, _submit_morse)
		"keycard":
			if has_card:
				hud.flash("💳 مرّرتَ بطاقة الدخول — الباب يُفتح", Color(0.42, 0.85, 0.58))
				_advance()
			else:
				hud.flash("🔒 تحتاج بطاقة الدخول (يحملها حارس) — أو اطلب من المحلّل اختراق الباب", Color(1.0, 0.63, 0.23))
		"checkpoint":
			if disguised or has_chief_card:
				hud.flash("✔ " + ("الحارس المناوب يظنّك منهم — مُرّ" if disguised else "بطاقة الرئيس مقبولة"), Color(0.42, 0.85, 0.58))
				_advance()
			else:
				hud.flash("🛂 نقطة تفتيش: تحتاج زيّ حارس أو بطاقة الرئيس (قبّعة حمراء)", Color(1.0, 0.63, 0.23))
		"servers":
			hud.open_servers(puzzle.servers, _pick_server)
		"maze":
			hud.close_panel()
			hud.flash("⚡ أعدتَ التيار — الأنفاق تضيء والباب يُفتح", Color(0.42, 0.85, 0.58))
			if s_clunk.stream:
				s_clunk.play()
			_advance()


func _analyst_interact() -> void:
	var obj = analyst.get_meta("looking", null)
	if obj == null:
		return
	var kind := str(obj.get_meta("kind", ""))
	if analyst_dark or analyst_locked > 0.0:
		hud.flash("🌑 الأضواء مطفأة — لا ترى شيئاً" if analyst_dark else "🚨 رأتك الدورية — انتظر %d ث" % int(ceil(analyst_locked)), Color(0.9, 0.28, 0.3))
		return
	if kind == "gauges":
		hud.open_gauges(GAUGE_NAMES)
		_gauges_open = true
		_gauge_t = 0.0
		return
	if kind == "hack":
		if stage != 0 or not gate_types.has("keycard"):
			hud.flash("الباب الأول مفتوح بالفعل", Color(0.6, 0.64, 0.68))
			return
		hud.open_hack(func(ok):
			if ok and stage == 0:
				hud.flash("🔓 اخترقتَ الباب الأول!", Color(0.42, 0.85, 0.58))
				if role == "analyst" and net:
					net.send({"t": "hack"})
				else:
					_advance())
		return
	if kind == "serverlog":
		var icons := {"أخضر": "🟢", "برتقالي": "🟠", "أحمر": "🔴", "أزرق": "🔵"}
		var dots := ""
		for k in int(puzzle.srv_blink):
			dots += str(icons.get(puzzle.srv_led, ""))
		hud.open_text("🛰 سجلّ الاختراق", "الخادم المصاب:\n• ضوؤه %s يومض %d مرّة في كل دورة  %s\n• حرارته أعلى من حدّ الإنذار — الحدّ مكتوب على لوحة برج الحراسة (استعمل المنظار 🔭 من النافذة)\n\n⚠ خوادم كثيرة تشبهه في الضوء أو الحرارة. اسأل العميل عن الثلاثة معاً." % [puzzle.srv_led, int(puzzle.srv_blink), dots])
		return
	if kind == "blueprint":
		hud.open_blueprint(maps.maze_segments(), Rect2(17.5, -0.5, 13.0, 11.0), Vector2(terminals[1].pos.x, terminals[1].pos.z))
		_bp_open = true
		return
	if kind == "morse":
		var lines := []
		for d in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]:
			lines.append(d + "   " + str(MORSE[d]).replace(".", "●").replace("-", "▬"))
		hud.open_text("دليل مورس — الأرقام", "● قصير    ▬ طويل\n\n" + "\n".join(lines) + "\n\nالتردّد مكتوب على جدار المضخّات المقابل: انظر من النافذة بالمنظار 🔭")
		return
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
	elif kind == "laserdoc":
		var dots := {"أحمر": "🔴", "أزرق": "🔵", "أخضر": "🟢", "أصفر": "🟡"}
		var seq := []
		for c in puzzle.laser:
			seq.append(str(dots.get(c, "")) + " " + str(c))
		hud.open_text("سجلّ الليزر", "ترتيب أزرار قاطع الليزر اليوم:\n\n" + "   ←   ".join(seq) + "\n\nالقاطع يطفئ الليزر %d ثانية فقط. أمْلِ الترتيب على العميل حين يصل إلى القاطع." % int(LASER_OFF))
	elif kind == "monitor":
		var i := int(obj.get_meta("index"))
		hud.open_feed(str(feeds[i][1]), (feeds[i][0] as SubViewport).get_texture())


func _check_symbols(picked: Array) -> String:
	if picked == puzzle.symbols:
		var c: Array = puzzle.combo
		return "> تمّ فكّ التشفير ✔\nتركيبة القرص (بالترتيب):\n%02d   ←   %02d   ←   %02d" % [c[0], c[1], c[2]]
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
	if stage != _applied_stage:
		if maps and maps.has_method("on_stage"):
			maps.on_stage(stage)
		_applied_stage = stage
		_update_objective()


func _update_objective() -> void:
	if hud == null:
		return
	var agent_side: bool = active == agent
	var txt := ""
	var OBJ := {
		"keypad": ["اذهب إلى الجهاز (السهم البرتقالي) — رمزه المكوّن من 4 أرقام في درج المحلّل، اطلبه منه", "افتح الدرج المضيء، اقرأ الرمز وأمْلِه على العميل"],
		"wires": ["افتح لوحة الأسلاك، اقرأ الرقم التسلسلي لشريكك، واقطع السلك الذي يقوله", "اسأل العميل عن آخر رقم في الرقم التسلسلي، وابحث عنه في الدليل الأحمر المضيء"],
		"valves": ["في بيت المضخّات: أدِر الصمّامات الأربعة حتى يقول المحلّل إن كل العدّادات خضراء، ثم ثبّت الضغط", "افتح «مخطّط الضغط» المضيء: اطلب من العميل أن يدير صمّاماً واحداً، وراقب أيّ عدّاد يتحرّك"],
		"radio": ["في غرفة اللاسلكي: اضبط التردّد الذي يقوله المحلّل، صِف له إشارات مورس، وأدخل الأرقام", "انظر من النافذة بالمنظار 🔭 إلى جدار المضخّات واقرأ التردّد، ثم ترجم إشارات العميل بدليل مورس"],
		"keycard": ["افتح الباب الأول: اسرق بطاقة الدخول من الحارس (من الخلف)، أو أسقطه وخذها — أو اطلب من المحلّل الاختراق", "اخترق الباب الأول من «جهاز الاختراق» المضيء، أو ساعد العميل ليسرق البطاقة"],
		"checkpoint": ["نقطة التفتيش: البس زيّ حارس (أسقطه وخذ بدلته) أو خذ بطاقة الرئيس — احذر الرئيس بالقبّعة الحمراء", "راقب الرئيس (قبّعة حمراء) — هو وحده يكشف التنكّر. أطفئ الكهرباء أو شتّت الحرّاس لتفتح الطريق"],
		"servers": ["في غرفة الخوادم: صِف لكل خادم ضوءه وومضاته وحرارته، واسحب قرص الذي يحدّده المحلّل", "اقرأ «سجلّ الاختراق»، وبالمنظار 🔭 اقرأ حدّ الحرارة على لوحة البرج، ثم حدّد الخادم المخترَق"],
		"maze": ["الأنفاق مظلمة ومصباحك فارغ: اتبع كلام المحلّل حتى قاطع الكهرباء", "افتح «مخطّط الأنفاق»: ترى العميل والحرّاس — وجّهه بالكلام إلى قاطع الكهرباء الأخضر"],
	}
	if stage < 2 and stage < gate_types.size():
		var pair: Array = OBJ.get(str(gate_types[stage]), ["", ""])
		txt = ("١. " if stage == 0 else "٢. ") + str(pair[0] if agent_side else pair[1])
	match stage:
		2:
			txt = "٣. صِف لشريكك الرموز الثلاثة على باب الخزنة، ثم أدِر القرص على الأرقام التي يقولها" if agent_side else "٣. أدخل في الحاسوب المضيء الرموز التي يصفها العميل، وأمْلِه التركيبة"
			if lv.get("sync", false):
				txt += " — ثم قفل زمني: اضغطا معاً!"
		3, 4, 5:
			txt = "🚨 اهرب إلى نقطة البداية!" if agent_side else "🚨 وجّه العميل إلى المخرج عبر الكاميرات!"
	if lv.get("killswitch", false) and stage == 1:
		txt += "\n🔴 الليزر يسدّ الطريق: انحنِ وانتظر الفراغ، أو استعمل القاطع (الترتيب في «سجلّ الليزر» عند المحلّل)" if agent_side else "\n🔴 العميل يحتاج ترتيب قاطع الليزر: اقرأه من «سجلّ الليزر» على الجدار"
	if role == "solo" and agent_side and stage < 3:
		txt += "\n(وضع التجربة: اضغط «بدّل الدور» لتصبح المحلّل وتجد الجواب)"
	hud.set_objective(txt)


# ───────── الخزنة ─────────
func _enter_vault() -> void:
	agent.set_crouch(false)
	vault_mode = true
	agent.locked = true
	dial_entered = []
	_cam_saved = agent.cam.global_transform
	var target := Transform3D.IDENTITY.looking_at(Vector3(1, 0, 0), Vector3.UP)
	target.origin = Vector3(28.6, 1.72, 5.0)
	target = vault_xf * target
	var tw := create_tween()
	tw.tween_property(agent.cam, "global_transform", target, 0.6).set_trans(Tween.TRANS_CUBIC)
	hud.vault_ui(true, _dial_step, _dial_confirm, _exit_vault)
	hud.vault_state(dial_number, 0)


func _exit_vault() -> void:
	if not vault_mode:
		return
	vault_mode = false
	hud.vault_ui(false, Callable(), Callable(), Callable())
	var tw := create_tween()
	tw.tween_interval(0.05)
	tw.tween_callback(func(): agent.reset_cam())


## إعادة الكاميرا فوراً (عند الإمساك بالعميل أو تبديل الدور).
func _reset_agent_cam() -> void:
	vault_mode = false
	hud.vault_ui(false, Callable(), Callable(), Callable())
	agent.reset_cam()


func _dial_step(st: int) -> void:
	dial_number = posmod(dial_number + st, 40)
	Input.vibrate_handheld(5)
	if s_click.stream:
		s_click.play()
	hud.vault_state(dial_number, dial_entered.size())


func _dial_confirm() -> void:
	var i := dial_entered.size()
	if i >= 3:
		return
	if dial_number == int(puzzle.combo[i]):
		dial_entered.append(dial_number)
		Input.vibrate_handheld(40)
		if s_clunk.stream:
			s_clunk.play()
		shake = 0.15
		hud.vault_state(dial_number, dial_entered.size())
		if dial_entered.size() == 3:
			if lv.get("sync", false):
				_start_sync()
			else:
				hud.flash("✔ الأقفال تتحرّك…", Color(0.42, 0.85, 0.58))
				_spin_wheel()
	else:
		# خطأ: ارتجاج وضوء أحمر، ونعيد من الرقم الأول دون الخروج
		hud.flash("✖ رقم خاطئ — أعد من الرقم الأول", Color(0.9, 0.28, 0.3))
		hud.hit()
		hud.vault_wrong()
		Input.vibrate_handheld(200)
		shake = 0.3
		dial_entered = []
		hud.vault_state(dial_number, 0)
		var tw := create_tween()
		tw.tween_property(vault_wheel, "rotation:x", vault_wheel.rotation.x + 0.25, 0.08)
		tw.tween_property(vault_wheel, "rotation:x", vault_wheel.rotation.x, 0.12)


func _spin_wheel() -> void:
	# المقبض يدور ثقيلاً مع طقطقات، ثم تبدأ لحظة الفتح
	var tw := create_tween()
	tw.tween_property(vault_wheel, "rotation:x", vault_wheel.rotation.x + TAU * 1.5, 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for i in 8:
		await get_tree().create_timer(0.24).timeout
		if s_click.stream:
			s_click.play()
		shake = 0.12
	await tw.finished
	_vault_opened()


func _vault_opened() -> void:
	_exit_vault()
	stage = 3
	escape_left = ESCAPE_SECONDS
	_apply_stage()
	_send_prog()


func _open_vault_door() -> void:
	# ١) الأقفال تنسحب واحداً بعد الآخر ٢) الأضواء ترتعش وتنطفئ ٣) بخار واهتزاز ٤) الباب الثقيل ينفتح ٥) الإنذار
	for b in vault_bolts:
		var a: float = b[1]
		var t1 := create_tween()
		t1.tween_property(b[0], "position", Vector3(0, cos(a) * 0.86, sin(a) * 0.86), 0.25).set_trans(Tween.TRANS_BACK)
		if s_click.stream:
			s_click.play()
		shake = 0.1
		await get_tree().create_timer(0.14).timeout
	flickers.erase(vault_lamp)
	for k in 6:
		vault_lamp.light_energy = 0.05 if k % 2 == 0 else 1.0
		await get_tree().create_timer(0.09).timeout
	vault_lamp.light_energy = 0.0
	await get_tree().create_timer(0.6).timeout
	if s_vault.stream:
		s_vault.play()
	steam.restart()
	steam.emitting = true
	shake = 1.2
	var tw := create_tween()
	tw.tween_property(vault_pivot, "rotation:y", deg_to_rad(-100), 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(1.2).timeout
	_alarm()


func _alarm() -> void:
	hud.flash("🚨 الخزنة مفتوحة — الإنذار!", Color(0.9, 0.28, 0.3))
	if s_alarm.stream:
		s_alarm.play()
	for g in guards:
		g.speed *= 1.6
		g.alarm = true
		if agent and g.sees(agent, get_world_3d().direct_space_state):
			g.chase(agent)
	for c in alarm_spots + [ARCHIVE + Vector3(5, WALL_H - 0.2, 4)]:
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
		hud.flash("⛓ أمسك بك الحارس!", Color(0.9, 0.28, 0.3))
		hud.hit()
		hud.close_panel()
	shake = 0.5
	if vault_mode or agent.locked:
		_reset_agent_cam()
	agent.velocity = Vector3.ZERO
	agent.move_input = Vector2.ZERO
	agent.set_crouch(false)
	hud.release_touches()
	if stage >= 3:
		escape_left = maxf(1.0, escape_left - 8.0)
		return
	agent.global_position = checkpoints[clampi(stage, 0, checkpoints.size() - 1)]


func _end(won: bool) -> void:
	result = "win" if won else "lose"
	_send_prog()
	_finish(won)


func _finish(won: bool) -> void:
	result = "win" if won else "lose"
	hud.show_interact("")
	hud.set_tip("")
	hud.set_crouch(false, false)
	hud.set_cam_meter(0.0)
	var next_name := ""
	if won:
		Levels.complete(level_i)
		if net == null and level_i + 1 < Levels.count():
			next_name = str(Levels.get_level(level_i + 1).name)
	var info := ""
	if won:
		var r := _stars()
		info = "%s   %s\nالوقت %d:%02d · رآك الحرّاس %d · أسقطت %d · وُجدت أجسام %d" % ["⭐".repeat(int(r[0])), r[1], int(r[2]) / 60, int(r[2]) % 60, int(stats.seen), int(stats.ko), int(stats.found)]
		Levels.save_best(str(lv.id), int(r[0]), float(r[2]))
	hud.end_screen(won, next_name, info)
