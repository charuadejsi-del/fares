# الواجهة والتحكّم باللمس: الإبهام الأيسر = عصا عائمة للمشي، الإبهام الأيمن = سحب للالتفات.
# ولوحات الألغاز: لوحة الأرقام، الأسلاك، الورقة، الدليل، الحاسوب، شاشة الكاميرا، وقرص الخزنة.
extends CanvasLayer

signal interact_pressed
signal switch_pressed
signal tool_pressed(kind: String)

var player
var look_only := false # وضع القرص: كل سحب = دوران
var _vault_hint: Label
var _dial: Control
var _on_step: Callable
var _hold := 0 # زرّ مضغوط باستمرار: ‎-1 أو 1
var _hold_t := 0.0
var _drag_acc := 0.0
var _tools: VBoxContainer
var _tool_btns := {}
var _loading: Control
var _load_bar: ProgressBar
var _load_txt: Label
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

	# أدوات المحلّل
	_tools = VBoxContainer.new()
	_tools.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_tools.offset_left = 20
	_tools.offset_top = -150
	_tools.offset_right = 290
	_tools.add_theme_constant_override("separation", 10)
	_tools.visible = false
	_root.add_child(_tools)
	for t in [["mark", "📍 علامة على الحرّاس"], ["distract", "🔊 شتّت الحارس"], ["warn", "⚠ حذّر العميل"]]:
		var b := _button(t[1], Color(0.1, 0.16, 0.12, 0.92), Color(0.75, 1.0, 0.8), 20)
		b.custom_minimum_size = Vector2(260, 64)
		var k: String = t[0]
		b.pressed.connect(func(): tool_pressed.emit(k))
		_tools.add_child(b)
		_tool_btns[k] = [b, t[1]]

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
			for c2 in _tools.get_children():
				if _tools.visible and (c2 as Control).get_global_rect().has_point(event.position):
					return
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
			if look_only:
				# سحب أفقي على القرص: كل 22 بكسل = رقم واحد
				_drag_acc += event.relative.x
				while absf(_drag_acc) >= 22.0:
					var st := 1 if _drag_acc > 0.0 else -1
					_drag_acc -= st * 22.0
					if _on_step.is_valid():
						_on_step.call(st)
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
	# الضغط المستمر على ◀ ▶ يدير القرص بسرعة
	if _hold != 0 and _on_step.is_valid():
		_hold_t -= delta
		if _hold_t <= 0.0:
			_hold_t = 0.09
			_on_step.call(_hold)
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


func set_tools(on: bool, cooldowns: Dictionary) -> void:
	_tools.visible = on and _panel == null
	if not on:
		return
	for k in _tool_btns:
		var b: Button = _tool_btns[k][0]
		var cd: float = cooldowns.get(k, 0.0)
		b.disabled = cd > 0.0
		b.text = (str(_tool_btns[k][1]) + "  (%d)" % int(ceil(cd))) if cd > 0.0 else str(_tool_btns[k][1])


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
func vault_ui(on: bool, on_step: Callable, on_confirm: Callable, on_exit: Callable) -> void:
	look_only = on
	_hold = 0
	_drag_acc = 0.0
	release_touches()
	if _vault:
		_vault.queue_free()
		_vault = null
	if not on:
		_on_step = Callable()
		return
	_on_step = on_step
	_interact.visible = false
	_vault = Control.new()
	_vault.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vault.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vault)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vault.add_child(shade)
	# القرص الكبير في الوسط
	_dial = preload("res://dial.gd").new()
	_dial.set_anchors_preset(Control.PRESET_CENTER)
	_dial.offset_left = -230
	_dial.offset_right = 230
	_dial.offset_top = -260
	_dial.offset_bottom = 200
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://fonts/Tajawal-Bold.ttf"):
		_dial.font = load("res://fonts/Tajawal-Bold.ttf")
	_vault.add_child(_dial)
	_vault_num = _label(70, AMBER)
	_vault_num.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_vault_num.offset_left = 40
	_vault_num.offset_right = 240
	_vault_num.offset_top = -60
	_vault_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vault_num.text_direction = Control.TEXT_DIRECTION_LTR
	_vault.add_child(_vault_num)
	_vault_hint = _label(22, Color(0.88, 0.9, 0.92))
	_vault_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_vault_hint.offset_top = 70
	_vault_hint.offset_left = 120
	_vault_hint.offset_right = -120
	_vault_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vault_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vault.add_child(_vault_hint)
	# ◀ ▶ (ضغطة = رقم، ضغط مستمر = دوران سريع)
	var left := _button("◀", Color(0.18, 0.2, 0.23), Color.WHITE, 46)
	left.set_anchors_preset(Control.PRESET_CENTER)
	left.offset_left = -400
	left.offset_right = -270
	left.offset_top = -40
	left.offset_bottom = 70
	_vault.add_child(left)
	var right := _button("▶", Color(0.18, 0.2, 0.23), Color.WHITE, 46)
	right.set_anchors_preset(Control.PRESET_CENTER)
	right.offset_left = 270
	right.offset_right = 400
	right.offset_top = -40
	right.offset_bottom = 70
	_vault.add_child(right)
	for pair in [[left, -1], [right, 1]]:
		var b: Button = pair[0]
		var st: int = pair[1]
		b.button_down.connect(func():
			on_step.call(st)
			_hold = st
			_hold_t = 0.35
		)
		b.button_up.connect(func(): _hold = 0)
	var ok := _button("  ✔ تأكيد الرقم  ", AMBER, Color(0.07, 0.05, 0.01), 30)
	ok.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ok.offset_left = -360
	ok.offset_top = -120
	ok.offset_right = -36
	ok.offset_bottom = -36
	ok.pressed.connect(on_confirm)
	_vault.add_child(ok)
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
	_dial.number = number
	_dial.done = done
	_vault_hint.text = "الرقم %d من 3 — أدِر القرص بـ ◀ ▶ (أو اسحب) حتى الرقم الذي يقوله المحلّل، ثم «تأكيد الرقم»" % (done + 1) if done < 3 else "المقبض يدور…"


func vault_wrong() -> void:
	if _dial:
		_dial.flash_red = 1.0


# ───────── شاشة التحميل ─────────
func loading(on: bool, progress := 0.0, text := "") -> void:
	if not on:
		if _loading:
			var tw := create_tween()
			tw.tween_property(_loading, "modulate:a", 0.0, 0.5)
			tw.tween_callback(_loading.queue_free)
			_loading = null
		return
	if _loading == null:
		_loading = ColorRect.new()
		(_loading as ColorRect).color = Color(0.02, 0.025, 0.03)
		_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_loading)
		var title := _label(72, AMBER)
		title.text = "الخزنة"
		title.set_anchors_preset(Control.PRESET_CENTER)
		title.offset_left = -400
		title.offset_right = 400
		title.offset_top = -170
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_loading.add_child(title)
		_load_bar = ProgressBar.new()
		_load_bar.set_anchors_preset(Control.PRESET_CENTER)
		_load_bar.offset_left = -300
		_load_bar.offset_right = 300
		_load_bar.offset_top = 0
		_load_bar.offset_bottom = 22
		_load_bar.max_value = 1.0
		_load_bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = AMBER
		fill.set_corner_radius_all(6)
		_load_bar.add_theme_stylebox_override("fill", fill)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.12, 0.13, 0.15)
		bg.set_corner_radius_all(6)
		_load_bar.add_theme_stylebox_override("background", bg)
		_loading.add_child(_load_bar)
		_load_txt = _label(22, Color(0.65, 0.68, 0.72))
		_load_txt.set_anchors_preset(Control.PRESET_CENTER)
		_load_txt.offset_left = -500
		_load_txt.offset_right = 500
		_load_txt.offset_top = 50
		_load_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_loading.add_child(_load_txt)
		var tip := _label(20, Color(0.5, 0.53, 0.57))
		tip.text = "نصيحة: الحرّاس يرونك في ضوء مصابيحهم فقط — ابقَ في الظلام وخلف الصناديق"
		tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		tip.offset_left = -560
		tip.offset_right = 560
		tip.offset_top = -90
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_loading.add_child(tip)
	_load_bar.value = progress
	_load_txt.text = text


func end_screen(won: bool) -> void:
	close_panel()
	vault_ui(false, Callable(), Callable(), Callable())
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
