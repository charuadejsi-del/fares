# الواجهة والتحكّم باللمس: الإبهام الأيسر = عصا عائمة للمشي، الإبهام الأيمن = سحب للالتفات.
# ولوحات الألغاز: لوحة الأرقام، الأسلاك، الورقة، الدليل، الحاسوب، شاشة الكاميرا، وقرص الخزنة.
extends CanvasLayer

signal interact_pressed
signal switch_pressed

var player
var look_only := false # وضع القرص: كل سحب = دوران
var dial_center := Vector2(-1, -1) # موضع القرص على الشاشة
var dial_delta := 0.0 # دوران الإصبع حول القرص (راديان، موجب = مع عقارب الساعة)
var _ring: Line2D
var _vault_hint: Label
var _move_touch := -1
var _move_origin := Vector2.ZERO
var _move_pos := Vector2.ZERO
var _look_touch := -1

var _root: Control
var _pad: Control
var _objective: Label
var _flash: Label
var _timer: Label
var _status: Label
var _interact: Button
var _switch: Button
var _alert_mat: ShaderMaterial
var _hit := 0.0
var _panel: Control
var _vault: Control
var _vault_num: Label
var _vault_seq: Label
var _compass: Polygon2D
var _compass_d: Label

const PAD_R := 70.0
const AMBER := Color(0.91, 0.63, 0.23)
const OK := Color(0.42, 0.85, 0.58)
const DANGER := Color(0.9, 0.28, 0.3)


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec3 tint = vec3(0.0);
uniform float strength = 0.6;
uniform float inner = 0.45;
void fragment() {
	float d = length(UV - 0.5) * 1.42;
	COLOR = vec4(tint, smoothstep(inner, 1.0, d) * strength);
}
"""
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = sh
	vig.material = vm
	_root.add_child(vig)

	var alert := ColorRect.new()
	alert.set_anchors_preset(Control.PRESET_FULL_RECT)
	alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_mat = ShaderMaterial.new()
	_alert_mat.shader = sh
	_alert_mat.set_shader_parameter("tint", Vector3(0.9, 0.1, 0.1))
	_alert_mat.set_shader_parameter("strength", 0.0)
	_alert_mat.set_shader_parameter("inner", 0.3)
	alert.material = _alert_mat
	_root.add_child(alert)

	_objective = _label(22, Color(0.9, 0.91, 0.92))
	_objective.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective.offset_top = 16
	_objective.offset_left = 180
	_objective.offset_right = -230
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_objective)

	_timer = _label(30, Color(0.9, 0.91, 0.92))
	_timer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_timer.offset_left = 24
	_timer.offset_top = 14
	_root.add_child(_timer)

	_status = _label(17, Color(0.6, 0.64, 0.68))
	_status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status.offset_left = -320
	_status.offset_right = -20
	_status.offset_top = 16
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_status)

	_flash = _label(34, Color.WHITE)
	_flash.set_anchors_preset(Control.PRESET_CENTER)
	_flash.offset_left = -500
	_flash.offset_right = 500
	_flash.offset_top = -150
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.modulate.a = 0.0
	_root.add_child(_flash)

	_interact = _button("", AMBER, Color(0.07, 0.05, 0.01), 28)
	_interact.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_interact.offset_left = -420
	_interact.offset_top = -130
	_interact.offset_right = -36
	_interact.offset_bottom = -40
	_interact.visible = false
	_interact.pressed.connect(func(): interact_pressed.emit())
	_root.add_child(_interact)

	_switch = _button("👁 بدّل الدور", Color(0.12, 0.14, 0.17), Color(0.9, 0.91, 0.92), 20)
	_switch.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_switch.offset_left = -210
	_switch.offset_right = -20
	_switch.offset_top = 48
	_switch.offset_bottom = 100
	_switch.visible = false
	_switch.pressed.connect(func(): switch_pressed.emit())
	_root.add_child(_switch)

	# بوصلة الهدف: سهم يدور نحو الجهاز التالي، والمسافة بالأمتار
	_compass = Polygon2D.new()
	_compass.polygon = PackedVector2Array([Vector2(0, -26), Vector2(18, 14), Vector2(0, 5), Vector2(-18, 14)])
	_compass.color = AMBER
	_compass.visible = false
	_root.add_child(_compass)
	_compass_d = _label(20, AMBER)
	_compass_d.text_direction = Control.TEXT_DIRECTION_LTR
	_compass_d.visible = false
	_root.add_child(_compass_d)

	_pad = preload("res://pad.gd").new()
	_pad.hud = self
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pad)


# ───────── أدوات ─────────
func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(t: String, bg: Color, fg: Color, size: int) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	return b


# ───────── اللمس ─────────
func _input(event) -> void:
	if player == null or _panel != null:
		return
	var vp := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			for b in [_interact, _switch]:
				if b.visible and b.get_global_rect().has_point(event.position):
					return
			if _vault != null:
				for c in _vault.find_children("*", "Button", true, false):
					if (c as Button).get_global_rect().has_point(event.position):
						return
			if not look_only and event.position.x < vp.x * 0.45 and _move_touch == -1:
				_move_touch = event.index
				_move_origin = event.position
				_move_pos = event.position
			elif _look_touch == -1:
				_look_touch = event.index
		else:
			if event.index == _move_touch:
				_move_touch = -1
				player.move_input = Vector2.ZERO
			if event.index == _look_touch:
				_look_touch = -1
		_pad.queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _move_touch:
			_move_pos = event.position
			var v: Vector2 = (_move_pos - _move_origin) / PAD_R
			if v.length() > 1.0:
				v = v.normalized()
			player.move_input = Vector2(v.x, -v.y)
			_pad.queue_redraw()
		elif event.index == _look_touch:
			if look_only and dial_center.x >= 0.0:
				var p1: Vector2 = event.position - dial_center
				var p0: Vector2 = p1 - event.relative
				if p1.length() > 25.0 and p0.length() > 25.0:
					dial_delta += wrapf(p1.angle() - p0.angle(), -PI, PI)
			else:
				player.look_delta += event.relative * 1.5


func release_touches() -> void:
	_move_touch = -1
	_look_touch = -1
	if player:
		player.move_input = Vector2.ZERO
	if _pad:
		_pad.queue_redraw()


func pad_state() -> Dictionary:
	return {"active": _move_touch != -1, "origin": _move_origin, "pos": _move_pos, "hidden": look_only or _panel != null}


func _process(delta: float) -> void:
	_hit = maxf(0.0, _hit - delta * 1.5)
	if _flash.modulate.a > 0.0:
		_flash.modulate.a = maxf(0.0, _flash.modulate.a - delta * 0.45)


# ───────── المؤشّرات ─────────
func set_objective(t: String) -> void:
	_objective.text = t


func set_status(t: String) -> void:
	_status.text = t


func set_alert(v: float) -> void:
	_alert_mat.set_shader_parameter("strength", clampf(maxf(v * 0.75, _hit), 0.0, 0.9))


func hit() -> void:
	_hit = 0.9


func flash(t: String, c: Color) -> void:
	_flash.text = t
	_flash.add_theme_color_override("font_color", c)
	_flash.modulate.a = 1.0


func show_interact(t: String) -> void:
	_interact.visible = t != "" and _panel == null and _vault == null
	_interact.text = "  " + t + "  "


func set_compass(angle: float, dist: float, escape: bool) -> void:
	var on := dist >= 0.0 and _panel == null and _vault == null
	_compass.visible = on
	_compass_d.visible = on
	if not on:
		return
	var w := get_viewport().get_visible_rect().size.x
	_compass.position = Vector2(w / 2.0, 120)
	_compass.rotation = angle
	_compass.color = OK if escape else AMBER
	_compass_d.text = "%d م" % int(round(dist))
	_compass_d.position = Vector2(w / 2.0 - 30, 146)
	_compass_d.add_theme_color_override("font_color", OK if escape else AMBER)


func set_switch_visible(v: bool) -> void:
	_switch.visible = v


func set_timer(sec: float, danger: bool) -> void:
	var s := int(ceil(maxf(sec, 0.0)))
	_timer.text = "%02d:%02d" % [s / 60, s % 60]
	_timer.add_theme_color_override("font_color", DANGER if danger else Color(0.9, 0.91, 0.92))
	_timer.add_theme_font_size_override("font_size", 48 if danger else 30)


# ───────── اللوحات ─────────
func panel_open() -> bool:
	return _panel != null


func close_panel() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null


func _open(title: String) -> VBoxContainer:
	close_panel()
	release_touches()
	_interact.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_panel = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.97)
	sb.border_color = Color(0.35, 0.38, 0.42)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(22)
	pc.add_theme_stylebox_override("panel", sb)
	center.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(520, 0)
	pc.add_child(v)
	var head := HBoxContainer.new()
	var tl := _label(26, AMBER)
	tl.text = title
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var x := _button("✕", Color(0.15, 0.16, 0.18), Color.WHITE, 24)
	x.custom_minimum_size = Vector2(64, 56)
	x.pressed.connect(close_panel)
	head.add_child(x)
	v.add_child(head)
	return v


func open_keypad(title: String, on_submit: Callable) -> void:
	var v := _open(title)
	var disp := _label(48, OK)
	disp.text = "____"
	disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disp.text_direction = Control.TEXT_DIRECTION_LTR
	v.add_child(disp)
	var entered := [""]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "✔"]:
		var b := _button(k, Color(0.2, 0.45, 0.28) if k == "✔" else Color(0.2, 0.22, 0.25), Color.WHITE, 34)
		b.custom_minimum_size = Vector2(160, 78)
		b.pressed.connect(func():
			if k == "⌫":
				entered[0] = str(entered[0]).substr(0, maxi(0, str(entered[0]).length() - 1))
			elif k == "✔":
				on_submit.call(str(entered[0]))
				entered[0] = ""
			elif str(entered[0]).length() < 4:
				entered[0] = str(entered[0]) + k
			disp.text = (str(entered[0]) + "____").substr(0, 4)
		)
		grid.add_child(b)


func open_wires(serial: String, wires: Array, on_cut: Callable) -> void:
	var v := _open("لوحة الأسلاك")
	var s := _label(30, Color(0.9, 0.91, 0.92))
	s.text = "الرقم التسلسلي:  " + serial
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var hint := _label(18, Color(0.6, 0.64, 0.68))
	hint.text = "أعطِ الرقم لشريكك، واقطع السلك الذي يقوله لك"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	for w in wires:
		var col: Color = w[1]
		var b := _button("✂  سلك " + str(w[0]), col, Color(0.05, 0.05, 0.05) if col.get_luminance() > 0.5 else Color.WHITE, 28)
		b.custom_minimum_size = Vector2(0, 70)
		b.pressed.connect(func():
			b.disabled = true
			b.text = "✖  مقطوع"
			on_cut.call(str(w[0]))
		)
		v.add_child(b)


func open_text(title: String, body: String) -> void:
	var v := _open(title)
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.9, 0.86, 0.75)
	sb.set_content_margin_all(24)
	sb.set_corner_radius_all(4)
	paper.add_theme_stylebox_override("panel", sb)
	var l := _label(30, Color(0.14, 0.12, 0.09))
	l.add_theme_constant_override("outline_size", 0)
	l.text = body
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paper.add_child(l)
	v.add_child(paper)


func open_table(title: String, rows: Array) -> void:
	var v := _open(title)
	var intro := _label(20, Color(0.75, 0.78, 0.8))
	intro.text = "آخر رقم في الرقم التسلسلي ← السلك الذي يُقطع"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(intro)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for r in rows:
		var a := _label(26, AMBER)
		a.text = str(r[0])
		grid.add_child(a)
		var b := _label(26, r[2])
		b.text = str(r[1])
		grid.add_child(b)


func open_symbols(all: Array, on_done: Callable) -> void:
	var v := _open("حاسوب الأرشيف")
	var info := _label(20, Color(0.6, 0.85, 0.65))
	info.text = "> أدخل الرموز الثلاثة المنقوشة على باب الخزنة بالترتيب"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var disp := _label(46, OK)
	disp.text = "_ _ _"
	disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disp.text_direction = Control.TEXT_DIRECTION_LTR
	v.add_child(disp)
	var picked := []
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for sym in all:
		var b := _button(str(sym), Color(0.1, 0.18, 0.12), Color(0.6, 0.95, 0.7), 44)
		b.custom_minimum_size = Vector2(160, 84)
		b.pressed.connect(func():
			picked.append(str(sym))
			var shown := ""
			for p in picked:
				shown += str(p) + " "
			disp.text = shown.strip_edges()
			if picked.size() == 3:
				info.text = str(on_done.call(picked.duplicate()))
				picked.clear()
		)
		grid.add_child(b)


func open_feed(title: String, tex: Texture2D) -> void:
	var v := _open(title)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(800, 450)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(tr)


# ───────── قرص الخزنة ─────────
func vault_ui(on: bool, on_pull: Callable, on_exit: Callable) -> void:
	look_only = on
	dial_delta = 0.0
	release_touches()
	if _vault:
		_vault.queue_free()
		_vault = null
	if not on:
		dial_center = Vector2(-1, -1)
		return
	_interact.visible = false
	_vault = Control.new()
	_vault.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vault.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vault)
	# حلقة إرشاد حول القرص: أدِر إصبعك عليها
	_ring = Line2D.new()
	var pts := PackedVector2Array()
	for i in 65:
		var a := i * TAU / 64.0
		pts.append(Vector2(cos(a), sin(a)) * 190.0)
	_ring.points = pts
	_ring.width = 3.0
	_ring.default_color = Color(0.91, 0.63, 0.23, 0.35)
	_vault.add_child(_ring)
	_vault_num = _label(64, AMBER)
	_vault_num.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vault_num.offset_left = -230
	_vault_num.offset_right = -40
	_vault_num.offset_top = 110
	_vault_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vault_num.text_direction = Control.TEXT_DIRECTION_LTR
	_vault.add_child(_vault_num)
	_vault_seq = _label(40, Color(0.9, 0.91, 0.92))
	_vault_seq.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vault_seq.offset_left = -230
	_vault_seq.offset_right = -40
	_vault_seq.offset_top = 200
	_vault_seq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vault_seq.text_direction = Control.TEXT_DIRECTION_LTR
	_vault.add_child(_vault_seq)
	_vault_hint = _label(22, Color(0.85, 0.87, 0.9))
	_vault_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_vault_hint.offset_left = -520
	_vault_hint.offset_right = 520
	_vault_hint.offset_top = -190
	_vault_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vault_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vault.add_child(_vault_hint)
	var pull := _button("  اسحب المقبض  ", AMBER, Color(0.07, 0.05, 0.01), 30)
	pull.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pull.offset_left = -340
	pull.offset_top = -120
	pull.offset_right = -36
	pull.offset_bottom = -36
	pull.pressed.connect(on_pull)
	_vault.add_child(pull)
	var ex := _button("  ابتعد  ", Color(0.15, 0.16, 0.18), Color.WHITE, 24)
	ex.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ex.offset_left = 36
	ex.offset_top = -110
	ex.offset_right = 230
	ex.offset_bottom = -36
	ex.pressed.connect(on_exit)
	_vault.add_child(ex)


func vault_state(number: int, done: int) -> void:
	if _vault == null:
		return
	_vault_num.text = "%02d" % number
	var leds := ""
	for i in 3:
		leds += ("●" if i < done else "○") + " "
	_vault_seq.text = leds.strip_edges()
	_vault_seq.add_theme_color_override("font_color", OK if done > 0 else Color(0.55, 0.58, 0.62))
	match done:
		0:
			_vault_hint.text = "الخطوة ١ من ٣: أدِر القرص بإصبعك يميناً (مع عقارب الساعة) حتى الرقم الأول، ثم اعكس الاتجاه"
		1:
			_vault_hint.text = "الخطوة ٢ من ٣: الآن يساراً (عكس عقارب الساعة) حتى الرقم الثاني، ثم اعكس الاتجاه"
		_:
			_vault_hint.text = "الخطوة ٣ من ٣: يميناً حتى الرقم الأخير، ثم اسحب المقبض"
	if _ring and dial_center.x >= 0.0:
		_ring.position = dial_center


func end_screen(won: bool) -> void:
	close_panel()
	vault_ui(false, Callable(), Callable())
	_interact.visible = false
	var e := ColorRect.new()
	e.color = Color(0, 0, 0, 0.75)
	e.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(e)
	var l := _label(48, OK if won else DANGER)
	l.text = "نجحت المهمّة! هربتما بالكنز 🏆" if won else "أُغلقت الأبواب… قُبض عليكما"
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.offset_left = -560
	l.offset_right = 560
	l.offset_top = -70
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.add_child(l)
	var b := _button("  القائمة الرئيسية  ", AMBER, Color(0.07, 0.05, 0.01), 28)
	b.set_anchors_preset(Control.PRESET_CENTER)
	b.offset_left = -170
	b.offset_right = 170
	b.offset_top = 40
	b.offset_bottom = 112
	b.pressed.connect(func(): get_tree().reload_current_scene())
	e.add_child(b)
