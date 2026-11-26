# واجهة اللعب: عصا تحكّم تظهر حيث تلمس (يسار)، زرّ فعل كبير يتغيّر حسب الموقف (يمين)،
# الهدف في الأعلى، رسائل، لوحة أرقام الخزنة، لوحة المحلّل، وشاشة النهاية.
extends CanvasLayer

const Btn := preload("res://td/btn.gd")

signal action_pressed
signal action2_pressed
signal switch_pressed
signal mic_pressed
signal code_entered(code: String)
signal map_tap(pos: Vector2)
signal tool_pressed(kind: String)
signal retry_pressed
signal menu_pressed

var move := Vector2.ZERO # اتّجاه العصا على الشاشة (y للأسفل)، الطول 0..1
var analyst_mode := false
var root: Control

var _pad_touch := -2 # -2 = لا شيء، -1 = الفأرة
var _pad_base := Vector2.ZERO
var _pad_pos := Vector2.ZERO
var _pad: Control
var _act: Btn
var _act2: Btn
var _switch: Button
var _mic: Button
var _goal: Label
var _status: Label
var _flash: Label
var _flash_t := 0.0
var _fade: ColorRect
var _keypad: PanelContainer
var _kp_label: Label
var _kp_code := ""
var _apanel: PanelContainer
var _acode: Label
var _ainfo: Label
var _tools := {}
var _end: Control
var _load: ColorRect
var _load_l: Label
var _intro: PanelContainer
var _tap_start := Vector2.ZERO
var _tap_touch := -2
var _dot: Control


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_pad = Control.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.draw.connect(_draw_pad)
	root.add_child(_pad)

	_act = Btn.new()
	_act.big = true
	_act.anchor_left = 1.0
	_act.anchor_top = 1.0
	_act.anchor_right = 1.0
	_act.anchor_bottom = 1.0
	_act.offset_left = -250
	_act.offset_top = -250
	_act.offset_right = -60
	_act.offset_bottom = -60
	_act.visible = false
	root.add_child(_act)
	_act2 = Btn.new()
	_act2.color = Color(0.75, 0.8, 0.86)
	_act2.anchor_left = 1.0
	_act2.anchor_top = 1.0
	_act2.anchor_right = 1.0
	_act2.anchor_bottom = 1.0
	_act2.offset_left = -390
	_act2.offset_top = -180
	_act2.offset_right = -270
	_act2.offset_bottom = -60
	_act2.visible = false
	root.add_child(_act2)

	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.45)
	top.anchor_right = 1.0
	top.offset_bottom = 64
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_goal = _label("", 26, Color(1, 0.86, 0.55))
	_goal.anchor_right = 1.0
	_goal.offset_left = 230
	_goal.offset_right = -230
	_goal.offset_top = 10
	_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_goal)
	_status = _label("", 18, Color(0.6, 0.85, 0.65))
	_status.offset_left = 16
	_status.offset_top = 18
	root.add_child(_status)

	_switch = _button("🔁 بدّل الدور", func(): switch_pressed.emit())
	_switch.anchor_left = 1.0
	_switch.anchor_right = 1.0
	_switch.offset_left = -220
	_switch.offset_right = -12
	_switch.offset_top = 8
	_switch.offset_bottom = 58
	_switch.visible = false
	root.add_child(_switch)
	_mic = _button("🎙", func(): mic_pressed.emit())
	_mic.anchor_left = 1.0
	_mic.anchor_right = 1.0
	_mic.offset_left = -300
	_mic.offset_right = -230
	_mic.offset_top = 8
	_mic.offset_bottom = 58
	_mic.visible = false
	root.add_child(_mic)

	_flash = _label("", 34, Color.WHITE)
	_flash.anchor_right = 1.0
	_flash.anchor_top = 0.2
	_flash.anchor_bottom = 0.2
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flash.offset_left = 120
	_flash.offset_right = -120
	_flash.add_theme_constant_override("outline_size", 10)
	_flash.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	root.add_child(_flash)

	_build_analyst()
	_build_keypad()

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	_load = ColorRect.new()
	_load.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load.color = Color(0.03, 0.035, 0.04)
	root.add_child(_load)
	_load_l = _label("جارٍ التحضير…", 30, Color(0.91, 0.63, 0.23))
	_load_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_load.add_child(_load_l)


# ───────── أدوات صغيرة ─────────
func _label(t: String, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(t: String, cb: Callable, fs := 22) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", fs)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.13, 0.92)
	sb.border_color = Color(0.91, 0.63, 0.23, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var sp := sb.duplicate() as StyleBoxFlat
	sp.bg_color = Color(0.3, 0.22, 0.08)
	b.add_theme_stylebox_override("pressed", sp)
	b.pressed.connect(cb)
	return b


func _panel(bg := Color(0.06, 0.07, 0.08, 0.95)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.91, 0.63, 0.23, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	return p


# ───────── اللمس: العصا والأزرار الدائرية وضغطات خريطة المحلّل ─────────
func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		_touch(t.index, t.position, t.pressed)
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		_drag(d.index, d.position)
	elif e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION:
		var m := e as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			_touch(-1, m.position, m.pressed)
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION and _pad_touch == -1:
		_drag(-1, (e as InputEventMouseMotion).position)


func _blocked() -> bool:
	return (_keypad and _keypad.visible) or (_end and _end.visible) or (_intro and _intro.visible) or _load.visible


func _touch(idx: int, p: Vector2, pressed: bool) -> void:
	if pressed:
		if _blocked():
			return
		for b in [_act, _act2]:
			if b.hit(p):
				b.down = true
				b.queue_redraw()
				if b == _act:
					action_pressed.emit()
				else:
					action2_pressed.emit()
				get_viewport().set_input_as_handled()
				return
		if p.y < 70:
			return
		var vs := root.size
		if analyst_mode:
			if _apanel.visible and _apanel.get_global_rect().has_point(p):
				return
			_tap_touch = idx
			_tap_start = p
			return
		if p.x < vs.x * 0.5 and _pad_touch == -2:
			_pad_touch = idx
			_pad_base = p
			_pad_pos = p
			move = Vector2.ZERO
			_pad.queue_redraw()
	else:
		for b in [_act, _act2]:
			if b.down:
				b.down = false
				b.queue_redraw()
		if idx == _pad_touch:
			_pad_touch = -2
			move = Vector2.ZERO
			_pad.queue_redraw()
		if idx == _tap_touch:
			_tap_touch = -2
			if p.distance_to(_tap_start) < 30 and not _blocked():
				map_tap.emit(p)


func _drag(idx: int, p: Vector2) -> void:
	if idx != _pad_touch:
		return
	_pad_pos = p
	var v := p - _pad_base
	var r := 110.0
	if v.length() > r:
		# القاعدة تتبع الإصبع (لا تضيع العصا إن ابتعد)
		_pad_base = p - v.normalized() * r
		v = v.normalized() * r
	move = v / r
	_pad.queue_redraw()


func _draw_pad() -> void:
	if _pad_touch == -2:
		return
	_pad.draw_circle(_pad_base, 110, Color(1, 1, 1, 0.08))
	_pad.draw_arc(_pad_base, 110, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	_pad.draw_arc(_pad_base, 110 * 0.75, 0, TAU, 48, Color(1, 0.8, 0.4, 0.18), 2.0, true)
	var k := _pad_base + move * 110
	_pad.draw_circle(k, 48, Color(1, 1, 1, 0.5))


## اتّجاه لوحة المفاتيح (الحاسوب): WASD/الأسهم، وShift للركض.
func keys() -> Vector2:
	var v := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if v == Vector2.ZERO:
		return v
	return v.normalized() * (1.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 0.7)


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo or _blocked():
		return
	if k.physical_keycode == KEY_E or k.physical_keycode == KEY_SPACE:
		if _act.visible:
			action_pressed.emit()
	elif k.physical_keycode == KEY_Q:
		if _act2.visible:
			action2_pressed.emit()
	elif k.physical_keycode == KEY_TAB:
		if _switch.visible:
			switch_pressed.emit()


# ───────── الواجهة العامة ─────────
func set_action(t: String, t2 := "") -> void:
	_act.visible = t != ""
	_act.set_text(t)
	_act2.visible = t2 != ""
	_act2.set_text(t2)


func set_goal(t: String) -> void:
	_goal.text = t


func set_status(t: String) -> void:
	_status.text = t


func set_switch_visible(v: bool) -> void:
	_switch.visible = v


func set_mic(t: String, visible_now := true) -> void:
	_mic.visible = visible_now
	_mic.text = t


func flash(t: String, c := Color.WHITE, secs := 3.0) -> void:
	_flash.text = t
	_flash.add_theme_color_override("font_color", c)
	_flash.modulate.a = 1.0
	_flash_t = secs


func fade(to_alpha: float, secs: float, c := Color.BLACK) -> void:
	_fade.color = Color(c.r, c.g, c.b, _fade.color.a)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", to_alpha, secs)


func loading(on: bool, t := "") -> void:
	_load.visible = on
	if t != "":
		_load_l.text = t


func set_analyst(on: bool) -> void:
	analyst_mode = on
	_apanel.visible = on
	if on:
		_pad_touch = -2
		move = Vector2.ZERO
		set_action("")
	_pad.queue_redraw()


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t < 0.6:
			_flash.modulate.a = maxf(0.0, _flash_t / 0.6)


# ───────── لوحة المحلّل ─────────
func _build_analyst() -> void:
	_apanel = _panel(Color(0.05, 0.06, 0.07, 0.88))
	_apanel.anchor_left = 1.0
	_apanel.anchor_right = 1.0
	_apanel.anchor_top = 0.0
	_apanel.offset_left = -330
	_apanel.offset_right = -10
	_apanel.offset_top = 74
	_apanel.visible = false
	root.add_child(_apanel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_apanel.add_child(v)
	v.add_child(_label("🖥️ غرفة المحلّل", 26, Color(0.91, 0.63, 0.23)))
	_acode = _label("", 30, Color(0.45, 0.95, 0.6))
	v.add_child(_acode)
	_ainfo = _label("", 19, Color(0.82, 0.84, 0.86))
	_ainfo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ainfo.custom_minimum_size = Vector2(290, 0)
	v.add_child(_ainfo)
	for k in [["distract", "📻 تشتيت حارس"], ["loop", "📷 تعطيل الكاميرا"], ["door", "🚪 باب الخزنة"]]:
		var kind := str(k[0])
		var b := _button(str(k[1]), func(): tool_pressed.emit(kind), 22)
		b.custom_minimum_size = Vector2(0, 56)
		v.add_child(b)
		_tools[kind] = b


func set_code(code: String) -> void:
	_acode.text = "رمز الخزنة: " + code


func set_analyst_info(t: String) -> void:
	_ainfo.text = t


func set_tool(kind: String, label: String, enabled: bool) -> void:
	if _tools.has(kind):
		var b: Button = _tools[kind]
		b.text = label
		b.disabled = not enabled


# ───────── لوحة أرقام الخزنة ─────────
func _build_keypad() -> void:
	_keypad = _panel()
	_keypad.set_anchors_preset(Control.PRESET_CENTER)
	_keypad.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_keypad.grow_vertical = Control.GROW_DIRECTION_BOTH
	_keypad.visible = false
	root.add_child(_keypad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_keypad.add_child(v)
	var t := _label("الخزنة — أدخل الرمز (عند المحلّل)", 24, Color(0.91, 0.63, 0.23))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_kp_label = _label("_ _ _ _", 52, Color(0.45, 0.95, 0.6))
	_kp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_kp_label)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	v.add_child(g)
	for n in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "✔"]:
		var key := str(n)
		var b := _button(key, func(): _kp(key), 34)
		b.custom_minimum_size = Vector2(110, 74)
		g.add_child(b)
	var c := _button("إغلاق", func(): _keypad.visible = false, 22)
	c.custom_minimum_size = Vector2(0, 54)
	v.add_child(c)


func open_keypad() -> void:
	_kp_code = ""
	_kp_show()
	_keypad.visible = true
	_pad_touch = -2
	move = Vector2.ZERO


func close_keypad() -> void:
	_keypad.visible = false


func keypad_open() -> bool:
	return _keypad.visible


func keypad_wrong() -> void:
	_kp_code = ""
	_kp_label.text = "خطأ ✖"
	_kp_label.add_theme_color_override("font_color", Color(1, 0.3, 0.25))


func _kp(k: String) -> void:
	_kp_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.6))
	if k == "⌫":
		_kp_code = _kp_code.substr(0, maxi(0, _kp_code.length() - 1))
	elif k == "✔":
		if _kp_code.length() == 4:
			code_entered.emit(_kp_code)
		return
	elif _kp_code.length() < 4:
		_kp_code += k
	_kp_show()


func _kp_show() -> void:
	var s := ""
	for i in 4:
		s += (_kp_code.substr(i, 1) if i < _kp_code.length() else "_") + (" " if i < 3 else "")
	_kp_label.text = s


# ───────── المقدّمة والنهاية ─────────
func intro(title: String, body: String) -> void:
	_intro = _panel()
	_intro.set_anchors_preset(Control.PRESET_CENTER)
	_intro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_intro.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_intro)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_intro.add_child(v)
	var t := _label(title, 34, Color(0.91, 0.63, 0.23))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := _label(body, 23, Color(0.9, 0.91, 0.92))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(760, 0)
	v.add_child(b)
	var ok := _button("ابدأ المهمّة", func(): _intro.visible = false, 28)
	ok.custom_minimum_size = Vector2(0, 66)
	v.add_child(ok)


func intro_open() -> bool:
	return _intro != null and _intro.visible


func close_intro() -> void:
	if _intro:
		_intro.visible = false


func end_screen(won: bool, title: String, lines: Array, stars: int) -> void:
	set_action("")
	_end = ColorRect.new()
	(_end as ColorRect).color = Color(0, 0, 0, 0.72)
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_end)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.add_child(cc)
	var p := _panel()
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := _label(title, 46, Color(0.42, 0.9, 0.58) if won else Color(1, 0.35, 0.3))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if won:
		var s := _label("★".repeat(stars) + "☆".repeat(3 - stars), 64, Color(1, 0.8, 0.25))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
	for ln in lines:
		var l := _label(str(ln), 23, Color(0.88, 0.89, 0.9))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var r := _button("↻ أعد المحاولة" if not won else "↻ العب مرّة أخرى", func(): retry_pressed.emit(), 26)
	r.custom_minimum_size = Vector2(260, 66)
	row.add_child(r)
	var m := _button("القائمة", func(): menu_pressed.emit(), 26)
	m.custom_minimum_size = Vector2(180, 66)
	row.add_child(m)
