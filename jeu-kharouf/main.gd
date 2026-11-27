extends Node3D
## «خروف العيد هارب» — المرحلة 1 (نسخة تجريبية).
## كل شيء يتبنى بالكود: الخريطة، الشخصيات، الأصوات والواجهة.

const B := preload("res://build.gd")
const WorldScript := preload("res://world.gd")
const SheepScript := preload("res://sheep.gd")
const ChaserScript := preload("res://chaser.gd")
const PadScript := preload("res://pad.gd")
const SfxScript := preload("res://sfx.gd")
const SAVE := "user://kharouf.cfg"
const CAM_OFF := Vector3(0, 12.5, 6.0)

enum State { MENU, PLAYING, CAUGHT, RESULT, GRAB }
const GRAB_TAPS := 8
const GRAB_TIME := 2.2

var state: int = State.MENU
var world
var sheep
var sfx
var cam: Camera3D
var font: Font
var chasers: Array = []
var grasses: Array = []
var score := 0.0
var survive := 0.0
var said_out := false
var next_kid := 30.0
var kids := 0
var combo := 0
var combo_t := 0.0
var best := 0
var coins := 0
var auto_spawn := true
var cam_angle := 0.0
var cam_locked := false
var smoke := false
var shot := false
var smoke_ok := true
var escapes_left := 1
var grab_by = null
var grab_left := 0.0
var grab_taps := 0
var invuln := 0.0
var escape_box: Control
var escape_lbl: Label
var escape_bar: ProgressBar

var pad
var ui_layer: CanvasLayer
var hud: Control
var lbl_score: Label
var lbl_time: Label
var lbl_combo: Label
var lbl_banner: Label
var lbl_big: Label
var big_tw: Tween
var score_tw: Tween
var banner_tw: Tween
var energy_bar: ProgressBar
var menu: Control
var menu_best: Label
var result: Control
var res_lines: Label
var res_record: Label


func _ready() -> void:
	smoke = OS.get_environment("KHAROUF_SMOKE") == "1"
	shot = OS.get_environment("KHAROUF_SHOT") == "1"
	auto_spawn = not smoke
	_load_save()
	if ResourceLoader.exists("res://fonts/Tajawal-Bold.ttf"):
		font = load("res://fonts/Tajawal-Bold.ttf")
	_setup_env()
	world = WorldScript.new()
	add_child(world)
	world.build()
	sheep = SheepScript.new()
	sheep.game = self
	add_child(sheep)
	sheep.reset_to(world.start_pos)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	cam.global_position = world.start_pos + Vector3(10, 9, 10)
	sfx = SfxScript.new()
	add_child(sfx)
	_build_ui()
	_show_menu()
	if smoke:
		_run_smoke.call_deferred()
	elif shot:
		_run_shots.call_deferred()


func is_playing() -> bool:
	return state == State.PLAYING


func chasers_active() -> bool:
	return state == State.PLAYING or state == State.GRAB


func difficulty() -> float:
	return 1.0 + minf(survive / 60.0 * 0.06, 0.4)


func _input(ev: InputEvent) -> void:
	if state != State.GRAB:
		return
	if ev is InputEventScreenTouch and ev.is_pressed():
		escape_tap()
	elif ev is InputEventKey and ev.is_pressed() and not ev.is_echo():
		escape_tap()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == State.MENU:
			get_tree().quit()
		else:
			_show_menu()


# ---------- الجو ----------

func _setup_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4f9fe0")
	sm.sky_horizon_color = Color("bfe2f5")
	sm.ground_horizon_color = Color("d9cdb4")
	sm.ground_bottom_color = Color("8f8570")
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4b9c2")
	env.ambient_light_energy = 0.42
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.8
	sun.light_color = Color("fff1d6")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


# ---------- الواجهة ----------

func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", maxi(fs / 6, 4))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 84)
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var names: Array[String] = ["normal", "hover", "pressed", "focus"]
	for n in names:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.darkened(0.15) if n == "pressed" else (col.lightened(0.08) if n == "hover" else col)
		sb.set_corner_radius_all(22)
		sb.set_content_margin_all(12)
		if n == "focus":
			sb.draw_center = false
			sb.border_color = Color(1, 1, 1, 0.6)
			sb.set_border_width_all(3)
		b.add_theme_stylebox_override(n, sb)
	return b


func _panel_bg() -> Control:
	var p := ColorRect.new()
	p.color = Color(0.04, 0.07, 0.11, 0.55)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _center_box(parent: Control) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	return v


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	ui_layer = layer
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	if font:
		th.default_font = font
	th.default_font_size = 28
	root.theme = th
	layer.add_child(root)

	pad = PadScript.new()
	pad.game = self
	pad.font = font
	root.add_child(pad)

	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 8
	top.offset_bottom = 150
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	lbl_score = _label("0", 54, Color("ffe066"))
	top.add_child(lbl_score)
	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(300, 20)
	energy_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	energy_bar.show_percentage = false
	energy_bar.max_value = 100.0
	energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(10)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("7be04f")
	fg.set_corner_radius_all(10)
	energy_bar.add_theme_stylebox_override("background", bg)
	energy_bar.add_theme_stylebox_override("fill", fg)
	top.add_child(energy_bar)
	lbl_combo = _label("", 34, Color("ff9f43"))
	top.add_child(lbl_combo)
	lbl_time = _label("", 30, Color.WHITE)
	lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_time.position = Vector2(26, 18)
	hud.add_child(lbl_time)
	lbl_banner = _label("", 30, Color(1, 1, 1, 0.9))
	lbl_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl_banner.offset_top = 150
	lbl_banner.offset_bottom = 200
	lbl_banner.modulate.a = 0.0
	hud.add_child(lbl_banner)
	lbl_big = _label("", 84, Color.WHITE)
	lbl_big.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl_big.offset_top = 210
	lbl_big.offset_bottom = 320
	lbl_big.modulate.a = 0.0
	root.add_child(lbl_big)

	menu = _panel_bg()
	root.add_child(menu)
	var mv := _center_box(menu)
	mv.add_child(_label("خروف العيد هارب", 76, Color("ffe066")))
	mv.add_child(_label("اهرب من عمي السعيد والدراري… وطيّح كلش في طريقك!", 28, Color.WHITE))
	menu_best = _label("", 30, Color("bfe9ff"))
	mv.add_child(menu_best)
	var play := _button("العب", Color("2fb36d"))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(start_game)
	mv.add_child(play)
	mv.add_child(_label("يسار: الجويستيك   •   يمين: نطحة، قفز، جري", 22, Color(1, 1, 1, 0.8)))

	result = _panel_bg()
	root.add_child(result)
	var rv := _center_box(result)
	rv.add_child(_label("حكموك!", 80, Color("ff6b6b")))
	res_lines = _label("", 34, Color.WHITE)
	rv.add_child(res_lines)
	res_record = _label("", 36, Color("ffe066"))
	rv.add_child(res_record)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 24)
	var again := _button("عاود", Color("2fb36d"))
	again.pressed.connect(start_game)
	hb.add_child(again)
	var home := _button("القائمة", Color("3b7dd8"))
	home.pressed.connect(_show_menu)
	hb.add_child(home)
	rv.add_child(hb)

	# زر «اهرب!» كي يحكمك واحد: تنقر بزربة في أي بلاصة في الشاشة
	escape_box = VBoxContainer.new()
	escape_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	escape_box.anchor_left = 0.5
	escape_box.anchor_right = 0.5
	escape_box.anchor_top = 1.0
	escape_box.anchor_bottom = 1.0
	escape_box.offset_left = -260
	escape_box.offset_right = 260
	escape_box.offset_top = -250
	escape_box.offset_bottom = -40
	escape_box.add_theme_constant_override("separation", 10)
	root.add_child(escape_box)
	var ep := PanelContainer.new()
	ep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var esb := StyleBoxFlat.new()
	esb.bg_color = Color("e8452c")
	esb.set_corner_radius_all(28)
	esb.set_content_margin_all(18)
	esb.border_color = Color(1, 1, 1, 0.85)
	esb.set_border_width_all(4)
	ep.add_theme_stylebox_override("panel", esb)
	escape_box.add_child(ep)
	escape_lbl = _label("", 52, Color.WHITE)
	ep.add_child(escape_lbl)
	escape_bar = ProgressBar.new()
	escape_bar.custom_minimum_size = Vector2(0, 22)
	escape_bar.show_percentage = false
	escape_bar.max_value = 100.0
	escape_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var eb := StyleBoxFlat.new()
	eb.bg_color = Color(0, 0, 0, 0.5)
	eb.set_corner_radius_all(11)
	var ef := StyleBoxFlat.new()
	ef.bg_color = Color("ffd93b")
	ef.set_corner_radius_all(11)
	escape_bar.add_theme_stylebox_override("background", eb)
	escape_bar.add_theme_stylebox_override("fill", ef)
	escape_box.add_child(escape_bar)
	escape_box.visible = false


func show_banner(t: String) -> void:
	lbl_banner.text = t
	lbl_banner.modulate.a = 1.0
	if banner_tw:
		banner_tw.kill()
	banner_tw = create_tween()
	banner_tw.tween_interval(1.8)
	banner_tw.tween_property(lbl_banner, "modulate:a", 0.0, 0.6)


## كلمة وحدة كبيرة في وسط الشاشة، في اللحظات المهمة برك.
func big_word(t: String, col: Color) -> void:
	lbl_big.text = t
	lbl_big.add_theme_color_override("font_color", col)
	lbl_big.pivot_offset = lbl_big.size * 0.5
	lbl_big.scale = Vector2.ONE * 1.5
	lbl_big.modulate.a = 1.0
	if big_tw:
		big_tw.kill()
	big_tw = create_tween()
	big_tw.set_ignore_time_scale(true)
	big_tw.tween_property(lbl_big, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	big_tw.tween_interval(0.55)
	big_tw.tween_property(lbl_big, "modulate:a", 0.0, 0.3)


## العداد الفوقاني ينفخ شوية كي تزيد النقاط (بلاصة الأرقام اللي تطير).
func _pop_score() -> void:
	lbl_score.pivot_offset = lbl_score.size * 0.5
	if score_tw:
		score_tw.kill()
	lbl_score.scale = Vector2.ONE * 1.25
	score_tw = create_tween()
	score_tw.set_ignore_time_scale(true)
	score_tw.tween_property(lbl_score, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func float_text(pos: Vector3, txt: String, col: Color) -> void:
	var l := B.label3d(txt, font, 72, col)
	add_child(l)
	l.global_position = pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3.UP * 1.6, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _fmt_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


# ---------- الجولة ----------

func _clear_round() -> void:
	for c in chasers:
		if is_instance_valid(c):
			c.queue_free()
	chasers.clear()
	for g in grasses:
		if is_instance_valid(g):
			g.queue_free()
	grasses.clear()
	world.reset_props()


func _show_menu() -> void:
	state = State.MENU
	Engine.time_scale = 1.0
	_clear_round()
	sheep.reset_to(world.start_pos)
	pad.release_all()
	menu.visible = true
	result.visible = false
	hud.visible = false
	pad.visible = false
	escape_box.visible = false
	lbl_big.modulate.a = 0.0
	grab_by = null
	menu_best.text = "أحسن نتيجة: %d   •   دورو: %d" % [best, coins]


func start_game() -> void:
	_clear_round()
	sheep.reset_to(world.start_pos)
	pad.release_all()
	score = 0.0
	survive = 0.0
	said_out = false
	next_kid = 30.0
	kids = 0
	combo = 0
	combo_t = 0.0
	escapes_left = 1
	grab_by = null
	invuln = 0.0
	escape_box.visible = false
	Engine.time_scale = 1.0
	for i in 14:
		_spawn_grass_random()
	menu.visible = false
	result.visible = false
	hud.visible = true
	pad.visible = true
	state = State.PLAYING
	sfx.play("baa")
	if auto_spawn:
		show_banner("عمي السعيد راهو جاي…")


func spawn_chaser(kind: String, pos: Vector3):
	var c = ChaserScript.new()
	c.setup(kind, self, font)
	add_child(c)
	c.global_position = pos
	chasers.append(c)
	return c


func spawn_grass_at(p: Vector3) -> Node3D:
	var g := Node3D.new()
	add_child(g)
	g.global_position = Vector3(p.x, 0.05, p.z)
	for i in 3:
		var blade := B.cyl(0.0, 0.11, 0.55, Color("7be04f"), 6)
		blade.material_override = B.mat(Color("7be04f"), 0.6)
		B.put(g, blade, Vector3(randf_range(-0.12, 0.12), 0.27, randf_range(-0.12, 0.12)), Vector3(randf_range(-18, 18), 0, randf_range(-18, 18)))
	var ring := B.cyl(0.5, 0.5, 0.02, Color("fff3a0"), 16)
	ring.material_override = B.mat(Color("fff3a0"), 1.2)
	B.put(g, ring, Vector3(0, 0.01, 0))
	grasses.append(g)
	return g


func _spawn_grass_random() -> void:
	if grasses.size() >= 16:
		return
	spawn_grass_at(_far_point(3.0, 40.0))


func _respawn_grass() -> void:
	if state == State.PLAYING:
		_spawn_grass_random()


func _far_point(mn: float, mx: float) -> Vector3:
	var sp: Vector3 = sheep.global_position
	var cells: Array = world.free_cells
	for i in 60:
		var cell: Vector2i = cells[randi() % cells.size()]
		var p: Vector3 = world.cell_to_world(cell)
		var dist := Vector2(p.x - sp.x, p.z - sp.z).length()
		if dist >= mn and dist <= mx:
			return p + Vector3.UP * 0.2
	return world.said_pos


func _physics_process(delta: float) -> void:
	if state == State.GRAB:
		# واحد آخر يوصل وهو مشدود؟ خلاص حكموه
		for c in chasers:
			if c != grab_by and c.can_catch():
				var dg: Vector3 = c.global_position - sheep.global_position
				if Vector2(dg.x, dg.z).length() < 1.15 and absf(dg.y) < 0.9:
					_caught()
					return
		return
	if state != State.PLAYING:
		return
	survive += delta
	invuln = maxf(invuln - delta, 0.0)
	score += 10.0 * delta
	if combo_t > 0.0:
		combo_t -= delta
		if combo_t <= 0.0:
			combo = 0
	if auto_spawn:
		if not said_out and survive >= 6.0:
			said_out = true
			spawn_chaser("said", world.said_pos)
			show_banner("عمي السعيد خرج! اهرب!")
		if survive >= next_kid and kids < 4:
			kids += 1
			next_kid += 30.0
			spawn_chaser("kid", _far_point(16.0, 28.0))
			show_banner("الدراري جاو يعاونو!")
	for g in grasses.duplicate():
		var d: Vector3 = g.global_position - sheep.global_position
		if Vector2(d.x, d.z).length() < 1.25 and absf(d.y) < 1.5:
			_collect(g)
	for c in chasers:
		if c.can_catch():
			var dd: Vector3 = c.global_position - sheep.global_position
			if Vector2(dd.x, dd.z).length() < 1.05 and absf(dd.y) < 0.9 and not sheep.is_dashing() and invuln <= 0.0:
				if escapes_left > 0:
					_start_grab(c)
				else:
					grab_by = c
					_caught()
				break


func _collect(g) -> void:
	grasses.erase(g)
	var p: Vector3 = g.global_position
	g.queue_free()
	sheep.energy = minf(sheep.energy + 35.0, 100.0)
	score += 20.0
	sfx.play("blip")
	_pop_score()
	get_tree().create_timer(6.0).timeout.connect(_respawn_grass)


func on_butt() -> void:
	sfx.play("baa", -4.0, randf_range(1.1, 1.35))
	sheep.bleat()
	_vibrate(20)


func on_jump() -> void:
	sfx.play("jump", -6.0)


func on_knock_chaser(c, chain: bool = false) -> void:
	if state != State.PLAYING:
		return
	combo += 1
	combo_t = 2.5
	var mult := mini(combo, 5)
	var base := 100 if c.kind == "said" else 60
	var pts := base * mult
	score += pts
	_pop_score()
	if chain:
		big_word("دومينو!", Color("ff9f43"))
	sfx.play("hit", 0.0, randf_range(0.9, 1.15))
	_vibrate(45)


func on_prop_hit(p) -> void:
	if state != State.PLAYING or p.get_meta("hit", false):
		return
	p.set_meta("hit", true)
	combo += 1
	combo_t = 2.5
	var pts := 15 * mini(combo, 5)
	score += pts
	_pop_score()
	sfx.play("hit", -6.0, 1.4)


# ---------- الحكان ----------

## بُعد حافة الخروف (بيضاوي: عرض ~0.42، طول ~0.98) في زاوية a من القدام.
func _sheep_edge(a: float) -> float:
	return 1.0 / sqrt(pow(sin(a) / 0.42, 2.0) + pow(cos(a) / 0.98, 2.0))


func _sheep_fwd() -> Vector3:
	var f: Vector3 = -sheep.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)


func _angle_of(c) -> float:
	var f := _sheep_fwd()
	var r := f.cross(Vector3.UP)
	var d: Vector3 = c.global_position - sheep.global_position
	d.y = 0.0
	return atan2(d.dot(r), d.dot(f))


func _slot(a: float, h: float, pitch: float, extra: float = 0.0) -> Vector3:
	var f := _sheep_fwd()
	var r := f.cross(Vector3.UP)
	var dir := (f * cos(a) + r * sin(a)).normalized()
	var sp: Vector3 = sheep.global_position
	return Vector3(sp.x, sp.y, sp.z) + dir * (_sheep_edge(a) + h * sin(pitch) + extra)


func _start_grab(c) -> void:
	state = State.GRAB
	grab_by = c
	grab_taps = 0
	grab_left = GRAB_TIME
	pad.release_all()
	pad.visible = false
	Engine.time_scale = 0.5
	sheep.grabbed()
	sheep.bleat()
	sfx.play("baa", 0.0, 0.9)
	_vibrate(120)
	var a := _angle_of(c)
	c.pile_on(_slot(a, c.body_height(), 0.9), sheep.global_position, 0.9)
	escape_lbl.text = "انقر بزربة!  0/%d" % GRAB_TAPS
	escape_bar.value = 100.0
	escape_box.visible = true


func escape_tap() -> void:
	if state != State.GRAB:
		return
	grab_taps += 1
	escape_lbl.text = "انقر بزربة!  %d/%d" % [grab_taps, GRAB_TAPS]
	sfx.play("jump", -10.0, 1.0 + grab_taps * 0.08)
	_vibrate(15)
	if grab_taps >= GRAB_TAPS:
		_escape()


func _escape() -> void:
	escape_box.visible = false
	escapes_left -= 1
	state = State.PLAYING
	var g = grab_by
	grab_by = null
	sheep.release()
	invuln = 1.5
	if g and is_instance_valid(g):
		var away: Vector3 = g.global_position - sheep.global_position
		away.y = 0.0
		g.release_knock(away.normalized() if away.length() > 0.01 else Vector3(1, 0, 0))
		on_knock_chaser(g, false)
	score += 150.0
	big_word("تفلّت!", Color("7be04f"))
	_pop_score()
	sfx.play("baa", 0.0, 1.3)
	pad.visible = true
	Engine.time_scale = 0.3
	get_tree().create_timer(0.7, true, false, true).timeout.connect(_end_slowmo)


func _end_slowmo() -> void:
	if state == State.PLAYING:
		Engine.time_scale = 1.0


func _caught() -> void:
	state = State.CAUGHT
	escape_box.visible = false
	pad.release_all()
	pad.visible = false
	Engine.time_scale = 0.3
	sheep.caught()
	sheep.bleat()
	sfx.play("baa_long")
	_vibrate(250)
	# كل واحد يطيح في بلاصتو حوالين الخروف: الجناب لوّلين، ومن بعد القدام واللور
	var slots: Array[float] = [PI / 2.0, -PI / 2.0, PI / 4.0, -PI / 4.0, 3.0 * PI / 4.0, -3.0 * PI / 4.0, 0.0, PI]
	var used: Array[float] = []
	if grab_by != null and is_instance_valid(grab_by):
		var ga := _angle_of(grab_by)
		var best_i := 0
		for i in slots.size():
			if absf(angle_difference(slots[i], ga)) < absf(angle_difference(slots[best_i], ga)):
				best_i = i
		slots.remove_at(best_i)
		used.append(ga)
		grab_by.pile_on(_slot(ga, grab_by.body_height(), 1.2), sheep.global_position, 1.2)
	var n := 0
	for c in chasers:
		if c == grab_by:
			continue
		var a: float = slots[n % slots.size()]
		var layer := n / slots.size()
		c.pile_on(_slot(a, c.body_height(), 1.2, layer * 0.35), sheep.global_position, 1.2)
		n += 1
	big_word("حكموه!", Color("ff6b6b"))
	get_tree().create_timer(2.6, true, false, true).timeout.connect(_show_result)


func _show_result() -> void:
	if state != State.CAUGHT:
		return
	Engine.time_scale = 1.0
	state = State.RESULT
	var s := int(score)
	var earned := s / 25
	coins += earned
	var record := s > best
	if record:
		best = s
	_write_save()
	res_lines.text = "صمدت: %s\nالنقاط: %d\n+%d دورو" % [_fmt_time(survive), s, earned]
	res_record.text = "رقم قياسي جديد!" if record else "أحسن نتيجة: %d" % best
	hud.visible = false
	result.visible = true


func _vibrate(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# ---------- الكاميرا والواجهة كل فريم ----------

func _process(delta: float) -> void:
	if not cam_locked:
		_update_cam(delta)
	for g in grasses:
		if is_instance_valid(g):
			g.rotate_y(delta * 2.0)
	if state == State.GRAB:
		grab_left -= delta / maxf(Engine.time_scale, 0.01)
		escape_bar.value = clampf(grab_left / GRAB_TIME * 100.0, 0.0, 100.0)
		if grab_left <= 0.0:
			_caught()
	if state == State.PLAYING:
		lbl_score.text = str(int(score))
		lbl_time.text = _fmt_time(survive)
		energy_bar.value = sheep.energy
		lbl_combo.text = ("كومبو x%d" % mini(combo, 5)) if combo > 1 else ""


func _update_cam(delta: float) -> void:
	var target: Vector3 = sheep.global_position
	match state:
		State.MENU:
			cam_angle += delta * 0.18
			var off := Vector3(sin(cam_angle) * 13.0, 8.0, cos(cam_angle) * 13.0)
			cam.global_position = cam.global_position.lerp(target + off, clampf(delta * 2.0, 0.0, 1.0))
			cam.look_at(target + Vector3.UP, Vector3.UP)
		State.PLAYING:
			cam.global_position = cam.global_position.lerp(target + CAM_OFF, clampf(delta * 5.0, 0.0, 1.0))
			cam.look_at(cam.global_position - CAM_OFF, Vector3.UP)
		_:
			cam_angle += delta * 0.9
			var off2 := Vector3(sin(cam_angle) * 5.5, 4.0, cos(cam_angle) * 5.5)
			cam.global_position = cam.global_position.lerp(target + off2, clampf(delta * 3.0, 0.0, 1.0))
			cam.look_at(target + Vector3.UP * 0.8, Vector3.UP)


# ---------- الحفظ ----------

func _load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		best = int(cf.get_value("game", "best", 0))
		coins = int(cf.get_value("game", "coins", 0))


func _write_save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "best", best)
	cf.set_value("game", "coins", coins)
	cf.save(SAVE)


# ---------- اختبار تلقائي (في GitHub) ----------

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _check(what: String, cond: bool, info: String = "") -> void:
	if cond:
		print("SMOKE %s ok" % what)
	else:
		smoke_ok = false
		print("SMOKE %s FAIL %s" % [what, info])


func _run_smoke() -> void:
	print("SMOKE start")
	sheep.describe_model()
	_check("world", world.free_cells.size() > 2000 and world.props.size() > 20, "cells=%d props=%d" % [world.free_cells.size(), world.props.size()])
	start_game()
	await _wait(0.5)
	var p0: Vector3 = sheep.global_position
	sheep.use_override = true
	sheep.input_override = Vector2(1, 0)
	await _wait(1.0)
	sheep.input_override = Vector2.ZERO
	var moved := p0.distance_to(sheep.global_position)
	_check("move", moved > 2.0, "moved=%.2f" % moved)
	await _wait(0.4)
	var y0: float = sheep.global_position.y
	var top := y0
	sheep.want_jump = true
	for i in 30:
		await get_tree().physics_frame
		top = maxf(top, sheep.global_position.y)
	_check("jump", top - y0 > 0.5, "h=%.2f" % (top - y0))
	await _wait(0.6)
	var path: Array = world.find_path(world.start_pos, world.start_pos + Vector3(20, 0, 20))
	_check("path", path.size() > 5, "len=%d" % path.size())
	var fwd: Vector3 = sheep.facing
	var kid = spawn_chaser("kid", sheep.global_position + fwd * 1.6)
	await get_tree().physics_frame
	sheep.want_butt = true
	await _wait(0.4)
	_check("headbutt", kid.is_knocked(), "state=%d" % kid.state)
	_check("score", score > 50.0, "score=%.0f" % score)
	chasers.erase(kid)
	kid.queue_free()
	await _wait(0.5)
	var crate = world.props[0]
	crate.global_position = sheep.global_position + sheep.facing * 1.3 + Vector3.UP * 0.4
	crate.linear_velocity = Vector3.ZERO
	crate.sleeping = false
	await _wait(0.15)
	var c0: Vector3 = crate.global_position
	sheep.want_butt = true
	await _wait(0.4)
	var cm: float = c0.distance_to(crate.global_position)
	_check("crate", cm > 0.4, "moved=%.2f" % cm)
	sheep.energy = 10.0
	spawn_grass_at(sheep.global_position)
	await _wait(0.2)
	_check("grass", sheep.energy > 30.0, "energy=%.0f" % sheep.energy)
	# الحكان الأول: يشدّو، وننقرو 8 مرات باش نتفلتو
	var g1 = spawn_chaser("said", sheep.global_position + Vector3(0, 0, 0.9))
	await _wait(0.5)
	_check("grab", state == State.GRAB and escape_box.visible, "state=%d" % state)
	await _wait(0.4)
	var gd: Vector3 = g1.global_position - sheep.global_position
	_check("grab_no_overlap", Vector2(gd.x, gd.z).length() > 0.9, "d=%.2f" % Vector2(gd.x, gd.z).length())
	for i in GRAB_TAPS:
		escape_tap()
	await _wait(0.2)
	_check("escape", state == State.PLAYING and escapes_left == 0 and g1.is_knocked(), "state=%d esc=%d" % [state, escapes_left])
	await _wait(1.8)
	chasers.erase(g1)
	g1.queue_free()
	# الحكان الثاني: ما بقاتش فرصة → يطيحو كامل حواليه
	spawn_chaser("kid", sheep.global_position + Vector3(3, 0, 3))
	spawn_chaser("said", sheep.global_position + Vector3(0, 0, 0.9))
	await _wait(0.6)
	_check("caught", state == State.CAUGHT or state == State.RESULT, "state=%d" % state)
	await _wait(1.0)
	var inside := 0
	for c in chasers:
		var dc: Vector3 = c.global_position - sheep.global_position
		if Vector2(dc.x, dc.z).length() < 0.9:
			inside += 1
	_check("pile_no_overlap", inside == 0, "inside=%d" % inside)
	await _wait(2.4)
	_check("result", state == State.RESULT and result.visible, "state=%d" % state)
	_check("save", FileAccess.file_exists(SAVE))
	start_game()
	await _wait(0.5)
	_check("restart", state == State.PLAYING and chasers.is_empty() and escapes_left == 1, "state=%d n=%d" % [state, chasers.size()])
	# الحكان مع انتهاء الوقت (بلا نقر)
	spawn_chaser("said", sheep.global_position + Vector3(0, 0, 0.9))
	await _wait(0.5)
	_check("grab2", state == State.GRAB, "state=%d" % state)
	await _wait(2.6)
	_check("grab_timeout", state == State.CAUGHT or state == State.RESULT, "state=%d" % state)
	print("SMOKE all ok" if smoke_ok else "SMOKE FAILED")
	get_tree().quit()


func _snap(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_jpg(dir.path_join(shot_name + ".jpg"), 0.85)
		print("SHOT ", shot_name)


## لقطات قريبة للخروف من 4 جهات (بلا واجهة) باش نتأكدو من الموديل.
func _model_shots(dir: String) -> void:
	ui_layer.visible = false
	cam_locked = true
	state = State.RESULT
	sheep.reset_to(world.start_pos)
	await _wait(1.0)
	var c: Vector3 = sheep.global_position + Vector3.UP * 0.7
	var views := {"00a_front": Vector3(0, 0.3, -3.2), "00b_side": Vector3(3.2, 0.3, 0), "00c_back": Vector3(0, 0.3, 3.2), "00d_top": Vector3(2.0, 3.0, 2.0)}
	for k in views:
		var off: Vector3 = views[k]
		cam.global_position = c + off
		cam.look_at(c, Vector3.UP)
		await _wait(0.3)
		await _snap(dir, k)
	# لقطات الحركة من الجنب: جري، نقزة، نطحة
	state = State.PLAYING
	var was_auto := auto_spawn
	auto_spawn = false
	sheep.use_override = true
	sheep.input_override = Vector2(1, 0)
	var shots := {12: "00e_run1", 17: "00f_run2", 22: "00g_run3"}
	for f in 40:
		await get_tree().physics_frame
		_side_cam()
		if f == 26:
			sheep.want_jump = true
		if shots.has(f):
			await _snap(dir, shots[f])
	for f in 12:
		await get_tree().physics_frame
		_side_cam()
	await _snap(dir, "00h_jump")
	for f in 30:
		await get_tree().physics_frame
		_side_cam()
	sheep.want_butt = true
	for f in 6:
		await get_tree().physics_frame
		_side_cam()
	await _snap(dir, "00i_butt")
	auto_spawn = was_auto
	state = State.MENU
	_clear_round()
	sheep.reset_to(world.start_pos)
	cam_locked = false
	ui_layer.visible = true


func _side_cam() -> void:
	var c: Vector3 = sheep.global_position + Vector3.UP * 0.7
	cam.global_position = c + Vector3(0, 0.4, 3.6)
	cam.look_at(c, Vector3.UP)


func _run_shots() -> void:
	var dir := OS.get_environment("KHAROUF_SHOT_DIR")
	if dir == "":
		dir = OS.get_user_data_dir().path_join("shots")
	DirAccess.make_dir_recursive_absolute(dir)
	await _model_shots(dir)
	await _wait(1.0)
	await _snap(dir, "01_menu")
	start_game()
	sheep.use_override = true
	sheep.input_override = Vector2(0, -1)
	await _wait(1.2)
	await _snap(dir, "02_run")
	sheep.input_override = Vector2(0, -0.25)
	var k1 = spawn_chaser("kid", sheep.global_position + Vector3(0, 0.2, -7))
	for i in 150:
		await get_tree().physics_frame
		var d: Vector3 = k1.global_position - sheep.global_position
		if Vector2(d.x, d.z).length() < 2.3:
			break
	sheep.want_butt = true
	await _wait(0.2)
	await _snap(dir, "03_butt")
	await _wait(0.8)
	await _snap(dir, "04_down")
	sheep.input_override = Vector2(1, 0)
	await _wait(3.5)
	await _snap(dir, "05_chase")
	sheep.input_override = Vector2.ZERO
	var gs = spawn_chaser("said", sheep.global_position + Vector3(0.9, 0.2, 0))
	await _wait(0.9)
	await _snap(dir, "06_grab")
	for i in GRAB_TAPS:
		escape_tap()
	await _wait(0.25)
	await _snap(dir, "06b_escape")
	await _wait(1.6)
	chasers.erase(gs)
	gs.queue_free()
	spawn_chaser("kid", sheep.global_position + Vector3(2.5, 0.2, 2.0))
	spawn_chaser("kid", sheep.global_position + Vector3(-2.5, 0.2, 2.0))
	spawn_chaser("said", sheep.global_position + Vector3(0.9, 0.2, 0))
	await _wait(0.6)
	await _snap(dir, "06c_caught")
	await _wait(1.2)
	await _snap(dir, "07_pile")
	await _wait(2.0)
	await _snap(dir, "08_result")
	get_tree().quit()
