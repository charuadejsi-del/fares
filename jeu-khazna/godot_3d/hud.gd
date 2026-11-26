# الواجهة والتحكّم باللمس: الإبهام الأيسر = عصا عائمة للمشي، الإبهام الأيمن = سحب للالتفات.
# ولوحات الألغاز: لوحة الأرقام، الأسلاك، الورقة، الدليل، الحاسوب، شاشة الكاميرا، وقرص الخزنة.
extends CanvasLayer

signal interact_pressed
signal switch_pressed
signal tool_pressed(kind: String)
signal mic_pressed
signal crouch_pressed
signal binoc_pressed
signal run_pressed
signal instinct_pressed
signal throw_pressed
signal act2_pressed
signal dark_pressed
signal sync_pressed
signal next_pressed

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
var _mic: Button
var _voice_lbl: Label
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
var _crouch: Button
var _cam_meter: ProgressBar
var _tip: Label
var _binoc: Button
var _run: Button
var _inst: Button
var _throw: Button
var _act2: Button
var _instinct_fx: ColorRect
var _fade: ColorRect
var _dark: Button
var _sync: Control
var _sync_lbl: Label
var _gauge_rows: Array = [] # [شريط، تسمية] لكل عدّاد
var _valve_lbls: Array = []
var _radio_freq: Label
var _radio_led: ColorRect
var _radio_code: Label
var _bp: Control
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

	# زرّ الانحناء (للعميل): فوق زرّ التفاعل
	_crouch = _round("crouch", "انحنِ", -150, -360)
	_crouch.visible = false
	_crouch.pressed.connect(func(): crouch_pressed.emit())
	_root.add_child(_crouch)

	# أزرار العميل (Hitman): ركض، حاسّة، رمي، وفعل ثانٍ (اسحب/اسرق)
	_run = _round("run", "اركض", -150, -490)
	_run.pressed.connect(func(): run_pressed.emit())
	_inst = _round("eye", "حاسّة", -150, -620)
	_inst.pressed.connect(func(): instinct_pressed.emit())
	_throw = _round("throw", "ارمِ", -280, -360)
	_throw.pressed.connect(func(): throw_pressed.emit())
	_act2 = _button("", Color(0.16, 0.2, 0.26, 0.95), Color(0.9, 0.95, 1.0), 26)
	_act2.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_act2.offset_left = -420
	_act2.offset_right = -170
	_act2.offset_top = -230
	_act2.offset_bottom = -150
	_act2.visible = false
	_act2.pressed.connect(func(): act2_pressed.emit())
	_root.add_child(_act2)
	_instinct_fx = ColorRect.new()
	_instinct_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_instinct_fx.color = Color(0.2, 0.45, 0.9, 0.0)
	_instinct_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_instinct_fx)
	_root.move_child(_instinct_fx, 1)

	# أزرار المحلّل في غرفة المراقبة ذات النافذة: منظار، وإطفاء الأضواء عند مرور الدورية
	_binoc = _button("🔭 منظار", Color(0.1, 0.13, 0.16, 0.92), Color(0.85, 0.92, 1.0), 22)
	_binoc.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_binoc.offset_left = -220
	_binoc.offset_right = -36
	_binoc.offset_top = -230
	_binoc.offset_bottom = -150
	_binoc.visible = false
	_binoc.pressed.connect(func(): binoc_pressed.emit())
	_root.add_child(_binoc)
	_dark = _button("🌑 أطفئ الأضواء", Color(0.1, 0.13, 0.16, 0.92), Color(0.85, 0.92, 1.0), 22)
	_dark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dark.offset_left = -440
	_dark.offset_right = -236
	_dark.offset_top = -230
	_dark.offset_bottom = -150
	_dark.visible = false
	_dark.pressed.connect(func(): dark_pressed.emit())
	_root.add_child(_dark)

	# عدّاد الكاميرا: يمتلئ حين تراك كاميرا
	_cam_meter = ProgressBar.new()
	_cam_meter.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_cam_meter.offset_left = -150
	_cam_meter.offset_right = 150
	_cam_meter.offset_top = 96
	_cam_meter.offset_bottom = 112
	_cam_meter.show_percentage = false
	_cam_meter.max_value = 1.0
	var fg := StyleBoxFlat.new()
	fg.bg_color = DANGER
	fg.set_corner_radius_all(6)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0, 0, 0, 0.5)
	bgs.set_corner_radius_all(6)
	_cam_meter.add_theme_stylebox_override("fill", fg)
	_cam_meter.add_theme_stylebox_override("background", bgs)
	_cam_meter.visible = false
	_cam_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cam_meter)

	# نصيحة التدريب: سطر كبير في الأسفل
	_tip = _label(26, Color(0.75, 1.0, 0.8))
	_tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tip.offset_left = -520
	_tip.offset_right = 520
	_tip.offset_top = -250
	_tip.offset_bottom = -170
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_tip)

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
	for t in [["mark", "📍 علامة على الحرّاس"], ["distract", "🔊 شتّت الحارس"], ["freeze", "📹 جمّد الكاميرات"], ["blackout", "⚡ اقطع الكهرباء"], ["warn", "⚠ حذّر العميل"]]:
		var b := _button(t[1], Color(0.1, 0.16, 0.12, 0.92), Color(0.75, 1.0, 0.8), 20)
		b.custom_minimum_size = Vector2(260, 64)
		var k: String = t[0]
		b.pressed.connect(func(): tool_pressed.emit(k))
		_tools.add_child(b)
		_tool_btns[k] = [b, t[1]]

	# الميكروفون (يظهر عند تشغيل الصوت)
	_mic = _button("🎙", Color(0.12, 0.14, 0.17), Color.WHITE, 30)
	_mic.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mic.offset_left = -300
	_mic.offset_right = -224
	_mic.offset_top = 48
	_mic.offset_bottom = 100
	_mic.visible = false
	_mic.pressed.connect(func(): mic_pressed.emit())
	_root.add_child(_mic)
	_voice_lbl = _label(16, Color(0.6, 0.64, 0.68))
	_voice_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_voice_lbl.offset_left = -520
	_voice_lbl.offset_right = -20
	_voice_lbl.offset_top = 104
	_voice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_voice_lbl)

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
			for b in [_interact, _switch, _mic, _crouch, _binoc, _dark, _run, _inst, _throw, _act2]:
				if b.visible and b.get_global_rect().has_point(event.position):
					return
			if _sync != null:
				for c3 in _sync.find_children("*", "Button", true, false):
					if (c3 as Button).get_global_rect().has_point(event.position):
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
				player.look_delta += event.relative * (1.05 if player.third else 1.5)


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
	_hack_draw(delta)
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


func set_crouch(visible_: bool, on: bool) -> void:
	_crouch.visible = visible_ and _panel == null
	_crouch.kind = "stand" if on else "crouch"
	_crouch.caption = "قِف" if on else "انحنِ"
	_crouch.set_on(on)
	_crouch.queue_redraw()


func set_cam_meter(v: float) -> void:
	_cam_meter.visible = v > 0.02
	_cam_meter.value = v


func set_tip(t: String) -> void:
	_tip.text = t


func hide_tool(k: String) -> void:
	if _tool_btns.has(k):
		(_tool_btns[k][0] as Button).queue_free()
		_tool_btns.erase(k)


# ───────── أدوات المحلّل: منظار وإطفاء الأضواء ─────────
func set_analyst_buttons(visible_: bool, binoc_on: bool, dark_on: bool) -> void:
	_binoc.visible = visible_ and _panel == null
	_dark.visible = visible_ and _panel == null
	_binoc.text = "🔭 أنزل المنظار" if binoc_on else "🔭 منظار"
	_dark.text = "💡 أشعل الأضواء" if dark_on else "🌑 أطفئ الأضواء"


## زرّ دائري بأيقونة (110 بكسل) — أسفل يمين الشاشة.
func _round(kind: String, cap: String, left: float, top: float) -> Button:
	var b = preload("res://icon_btn.gd").new()
	b.kind = kind
	b.caption = cap
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = left
	b.offset_right = left + 116
	b.offset_top = top
	b.offset_bottom = top + 116
	b.visible = false
	_root.add_child(b)
	return b


func _mk_side(t: String, l: float, r: float, top: float, bot: float) -> Button:
	var b := _button(t, Color(0.12, 0.14, 0.17, 0.9), Color(0.9, 0.91, 0.92), 22)
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = l
	b.offset_right = r
	b.offset_top = top
	b.offset_bottom = bot
	b.visible = false
	_root.add_child(b)
	return b


## أزرار العميل: تظهر فقط حين يتحكّم فيه.
func set_agent_buttons(on: bool, running: bool, inst_cd: float, cans: int, act2: String) -> void:
	var show := on and _panel == null and _vault == null
	_run.visible = show
	_run.kind = "walk" if running else "run"
	_run.caption = "امشِ" if running else "اركض"
	_run.set_on(running)
	_run.queue_redraw()
	_inst.visible = show
	_inst.disabled = inst_cd > 0.0
	_inst.caption = "حاسّة" if inst_cd <= 0.0 else str(int(ceil(inst_cd)))
	_inst.queue_redraw()
	_throw.visible = show and cans > 0
	_throw.caption = "ارمِ ×%d" % cans
	_throw.queue_redraw()
	_act2.visible = show and act2 != ""
	_act2.text = act2


## إظلام/ومضة للمشاهد السينمائية.
func fade(color: Color, to_alpha: float, secs: float) -> void:
	if _fade == null:
		_fade = ColorRect.new()
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.color = Color(color.r, color.g, color.b, 0.0)
		_root.add_child(_fade)
	_fade.color = Color(color.r, color.g, color.b, _fade.color.a)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", to_alpha, secs)


func instinct_fx(v: float) -> void:
	_instinct_fx.color.a = v * 0.22


# ───────── الاختراق السريع (المحلّل): اضغط حين يكون المؤشّر في الأخضر، 3 مرّات ─────────
var _hack_t := 0.0
var _hack_hits := 0
var _hack_bar: Control
var _hack_zone := Vector2(0.4, 0.58)
var _hack_cb: Callable
var _hack_lbl: Label


func open_hack(on_done: Callable) -> void:
	var v := _open("اختراق الباب")
	_hack_cb = on_done
	_hack_hits = 0
	_hack_t = 0.0
	var hint := _label(20, Color(0.6, 0.64, 0.68))
	hint.text = "اضغط «⏺» حين يمرّ المؤشّر في المنطقة الخضراء — 3 مرّات. الخطأ يعيدك للصفر."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_hack_lbl = _label(34, OK)
	_hack_lbl.text = "○ ○ ○"
	_hack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hack_lbl.text_direction = Control.TEXT_DIRECTION_LTR
	v.add_child(_hack_lbl)
	_hack_bar = Control.new()
	_hack_bar.custom_minimum_size = Vector2(560, 56)
	v.add_child(_hack_bar)
	var b := _button("⏺", Color(0.2, 0.45, 0.28), Color.WHITE, 40)
	b.custom_minimum_size = Vector2(0, 90)
	b.pressed.connect(_hack_press)
	v.add_child(b)
	_new_zone()


func _new_zone() -> void:
	var w := 0.18 - _hack_hits * 0.035
	var st := randf_range(0.08, 0.92 - w)
	_hack_zone = Vector2(st, st + w)


func _hack_pos() -> float:
	var sp := 0.9 + _hack_hits * 0.35
	var x := fmod(_hack_t * sp, 2.0)
	return x if x < 1.0 else 2.0 - x


func _hack_press() -> void:
	var p := _hack_pos()
	if p >= _hack_zone.x and p <= _hack_zone.y:
		_hack_hits += 1
		if _hack_hits >= 3:
			close_panel()
			_hack_bar = null
			if _hack_cb.is_valid():
				_hack_cb.call(true)
			return
		_new_zone()
	else:
		_hack_hits = 0
		hit()
		_new_zone()
	var dots := []
	for i in 3:
		dots.append("●" if i < _hack_hits else "○")
	if is_instance_valid(_hack_lbl):
		_hack_lbl.text = " ".join(dots)


func _hack_draw(delta: float) -> void:
	if _hack_bar == null or not is_instance_valid(_hack_bar):
		return
	_hack_t += delta
	for c in _hack_bar.get_children():
		c.queue_free()
	var w := _hack_bar.custom_minimum_size.x
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.13)
	bg.size = Vector2(w, 56)
	_hack_bar.add_child(bg)
	var z := ColorRect.new()
	z.color = Color(0.2, 0.65, 0.35)
	z.position = Vector2(_hack_zone.x * w, 0)
	z.size = Vector2((_hack_zone.y - _hack_zone.x) * w, 56)
	_hack_bar.add_child(z)
	var nd := ColorRect.new()
	nd.color = Color(1, 0.85, 0.3)
	nd.position = Vector2(_hack_pos() * w - 3, -6)
	nd.size = Vector2(6, 68)
	_hack_bar.add_child(nd)


# ───────── الصمّامات (العميل) ─────────
func open_valves(values: Array, tags: Array, on_turn: Callable, on_confirm: Callable) -> void:
	var v := _open("لوحة الصمّامات")
	var hint := _label(19, Color(0.6, 0.64, 0.68))
	hint.text = "كل صمّام يغيّر الضغط في أكثر من أنبوب. المحلّل يرى العدّادات: أدِر صمّاماً واحداً واسأله ماذا تغيّر. ضغط زائد = انفجار بخار وإنذار!"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_valve_lbls = []
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for i in values.size():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var t := _label(22, tags[i][1])
		t.text = str(tags[i][0])
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(t)
		var val := _label(44, Color.WHITE)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.text_direction = Control.TEXT_DIRECTION_LTR
		col.add_child(val)
		_valve_lbls.append(val)
		var idx := i
		for d in [1, -1]:
			var b := _button("⟳ +" if d > 0 else "⟲ −", Color(0.2, 0.22, 0.25), Color.WHITE, 26)
			b.custom_minimum_size = Vector2(118, 62)
			var dd: int = d
			b.pressed.connect(func(): on_turn.call(idx, dd))
			col.add_child(b)
		grid.add_child(col)
	var ok := _button("✔ ثبّت الضغط", Color(0.2, 0.45, 0.28), Color.WHITE, 28)
	ok.custom_minimum_size = Vector2(0, 70)
	ok.pressed.connect(func(): on_confirm.call())
	v.add_child(ok)
	update_valves(values)


func update_valves(values: Array) -> void:
	for i in mini(values.size(), _valve_lbls.size()):
		if is_instance_valid(_valve_lbls[i]):
			(_valve_lbls[i] as Label).text = ["◯", "◔", "◑", "◕", "●"][clampi(int(values[i]), 0, 4)] + " " + str(values[i])


# ───────── عدّادات الضغط (المحلّل) ─────────
func open_gauges(names: Array) -> void:
	var v := _open("مخطّط الضغط — مباشر")
	var hint := _label(19, Color(0.6, 0.64, 0.68))
	hint.text = "اجعل كل عدّاد داخل المنطقة الخضراء. الأحمر = خطر انفجار. لا تعرف أيّ صمّام يحرّك أيّ عدّاد: اطلب من العميل أن يجرّب صمّاماً واحداً."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_gauge_rows = []
	for n in names:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := _label(24, Color(0.85, 0.9, 0.95))
		l.text = str(n)
		l.custom_minimum_size = Vector2(130, 0)
		row.add_child(l)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(380, 40)
		row.add_child(bar)
		var num := _label(26, Color.WHITE)
		num.custom_minimum_size = Vector2(90, 0)
		num.text_direction = Control.TEXT_DIRECTION_LTR
		row.add_child(num)
		v.add_child(row)
		_gauge_rows.append([bar, num])


## يُستدعى كل إطار حين تكون لوحة العدّادات مفتوحة: القيمة، والهدف، وحدّ الخطر.
func update_gauges(values: Array, targets: Array, maxv: int) -> void:
	for i in mini(values.size(), _gauge_rows.size()):
		var bar: Control = _gauge_rows[i][0]
		var num: Label = _gauge_rows[i][1]
		if not is_instance_valid(bar):
			return
		for c in bar.get_children():
			c.queue_free()
		var w := bar.custom_minimum_size.x
		var unit := w / float(maxv)
		var bg := ColorRect.new()
		bg.color = Color(0.12, 0.13, 0.15)
		bg.size = Vector2(w, 40)
		bar.add_child(bg)
		var tgt: int = int(targets[i])
		var green := ColorRect.new()
		green.color = Color(0.2, 0.55, 0.3, 0.8)
		green.position = Vector2((tgt - 0.5) * unit, 0)
		green.size = Vector2(unit, 40)
		bar.add_child(green)
		var red := ColorRect.new()
		red.color = Color(0.6, 0.12, 0.1, 0.8)
		red.position = Vector2((tgt + 3.5) * unit, 0)
		red.size = Vector2(maxf(0.0, w - (tgt + 3.5) * unit), 40)
		bar.add_child(red)
		var needle := ColorRect.new()
		needle.color = Color(1, 0.85, 0.3)
		needle.position = Vector2(clampf(int(values[i]) * unit, 0, w - 6), -4)
		needle.size = Vector2(6, 48)
		bar.add_child(needle)
		num.text = "%d / %d" % [int(values[i]), tgt]
		num.add_theme_color_override("font_color", OK if int(values[i]) == tgt else (DANGER if int(values[i]) > tgt + 2 else Color.WHITE))


# ───────── جهاز اللاسلكي (العميل) ─────────
func open_radio(freq: float, on_tune: Callable, on_submit: Callable) -> void:
	var v := _open("جهاز اللاسلكي")
	var hint := _label(19, Color(0.6, 0.64, 0.68))
	hint.text = "اضبط التردّد الصحيح (المحلّل يقرؤه بالمنظار). ستسمع وترى إشارة مورس: قصير ● وطويل ▬. صِفها للمحلّل، فيترجمها إلى 4 أرقام."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 18)
	v.add_child(top)
	_radio_led = ColorRect.new()
	_radio_led.custom_minimum_size = Vector2(56, 56)
	_radio_led.color = Color(0.15, 0.05, 0.05)
	top.add_child(_radio_led)
	_radio_freq = _label(52, AMBER)
	_radio_freq.text_direction = Control.TEXT_DIRECTION_LTR
	top.add_child(_radio_freq)
	var tune := HBoxContainer.new()
	tune.alignment = BoxContainer.ALIGNMENT_CENTER
	tune.add_theme_constant_override("separation", 10)
	v.add_child(tune)
	for st in [[-1.0, "◀◀"], [-0.1, "◀"], [0.1, "▶"], [1.0, "▶▶"]]:
		var b := _button(str(st[1]), Color(0.2, 0.22, 0.25), Color.WHITE, 30)
		b.custom_minimum_size = Vector2(120, 66)
		var dv: float = st[0]
		b.pressed.connect(func(): on_tune.call(dv))
		tune.add_child(b)
	_radio_code = _label(40, OK)
	_radio_code.text = "____"
	_radio_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_radio_code.text_direction = Control.TEXT_DIRECTION_LTR
	v.add_child(_radio_code)
	var entered := [""]
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "⌫", "✔"]:
		var b := _button(k, Color(0.2, 0.45, 0.28) if k == "✔" else Color(0.2, 0.22, 0.25), Color.WHITE, 28)
		b.custom_minimum_size = Vector2(84, 62)
		b.pressed.connect(func():
			if k == "⌫":
				entered[0] = str(entered[0]).substr(0, maxi(0, str(entered[0]).length() - 1))
			elif k == "✔":
				on_submit.call(str(entered[0]))
				entered[0] = ""
			elif str(entered[0]).length() < 4:
				entered[0] = str(entered[0]) + k
			if is_instance_valid(_radio_code):
				_radio_code.text = (str(entered[0]) + "____").substr(0, 4)
		)
		grid.add_child(b)
	set_radio(freq, false)


func set_radio(freq: float, led: bool) -> void:
	if _radio_freq and is_instance_valid(_radio_freq):
		_radio_freq.text = "%.1f MHz" % freq
	if _radio_led and is_instance_valid(_radio_led):
		_radio_led.color = Color(1.0, 0.25, 0.15) if led else Color(0.15, 0.05, 0.05)


# ───────── الخوادم (العميل) ─────────
func open_servers(list: Array, on_pick: Callable) -> void:
	var v := _open("غرفة الخوادم — أيّها مخترَق؟")
	var hint := _label(19, Color(0.6, 0.64, 0.68))
	hint.text = "صِف للمحلّل الأضواء والحرارة. هو يملك سجلّ الاختراق، والحدّ الحراري مكتوب على البرج (يقرؤه بالمنظار). اختيار خاطئ = إنذار."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var icons := {"أخضر": "🟢", "برتقالي": "🟠", "أحمر": "🔴", "أزرق": "🔵"}
	for i in list.size():
		var e: Dictionary = list[i]
		var dots := ""
		for k in int(e.blink):
			dots += str(icons.get(e.led, "⚪"))
		var b := _button("%s\n%s  %d°" % [e.id, dots, int(e.temp)], Color(0.12, 0.14, 0.17), Color(0.9, 0.95, 1.0), 22)
		b.custom_minimum_size = Vector2(200, 84)
		var idx := i
		b.pressed.connect(func(): on_pick.call(idx))
		grid.add_child(b)


# ───────── مخطّط المتاهة (المحلّل) ─────────
func open_blueprint(segs: Array, area: Rect2, goal: Vector2) -> void:
	var v := _open("مخطّط الأنفاق — العميل في الظلام")
	var hint := _label(19, Color(0.6, 0.64, 0.68))
	hint.text = "🟠 العميل · 🔴 الحرّاس · 🟢 قاطع الكهرباء. وجّهه بالكلام: يمين، يسار، تقدّم…"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_bp = preload("res://blueprint.gd").new()
	_bp.custom_minimum_size = Vector2(640, 520)
	_bp.segs = segs
	_bp.area = area
	_bp.goal = goal
	v.add_child(_bp)


func update_blueprint(agent: Vector2, guards: Array) -> void:
	if _bp and is_instance_valid(_bp):
		_bp.agent_p = agent
		_bp.guards_p = guards
		_bp.queue_redraw()


# ───────── القفل الزمني: الضغط معاً ─────────
func sync_ui(on: bool, text := "") -> void:
	if not on:
		if _sync:
			_sync.queue_free()
			_sync = null
		return
	if _sync == null:
		_sync = VBoxContainer.new()
		_sync.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_sync.offset_left = -300
		_sync.offset_right = 300
		_sync.offset_top = -330
		_sync.offset_bottom = -150
		_root.add_child(_sync)
		_sync_lbl = _label(34, AMBER)
		_sync_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sync.add_child(_sync_lbl)
		var b := _button("🔑 اضغط الآن!", Color(0.75, 0.15, 0.12), Color.WHITE, 34)
		b.custom_minimum_size = Vector2(0, 96)
		b.pressed.connect(func(): sync_pressed.emit())
		_sync.add_child(b)
	_sync_lbl.text = text


## قاطع الليزر: يُدخل العميل ترتيب ثلاثة ألوان يمليه المحلّل.
func open_colors(title: String, colors: Array, on_submit: Callable) -> void:
	var v := _open(title)
	var hint := _label(20, Color(0.6, 0.64, 0.68))
	hint.text = "اسأل المحلّل عن ترتيب الألوان في «سجلّ الليزر»، ثم اضغطها بالترتيب"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var disp := _label(40, Color(0.9, 0.91, 0.92))
	disp.text = "○ ○ ○"
	disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disp.text_direction = Control.TEXT_DIRECTION_LTR
	v.add_child(disp)
	var picked := []
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for c in colors:
		var col: Color = c[1]
		var b := _button(str(c[0]), col, Color(0.05, 0.05, 0.05) if col.get_luminance() > 0.5 else Color.WHITE, 30)
		b.custom_minimum_size = Vector2(250, 84)
		var nm: String = c[0]
		b.pressed.connect(func():
			picked.append(nm)
			var dots := []
			for i in 3:
				dots.append("●" if i < picked.size() else "○")
			disp.text = " ".join(dots)
			if picked.size() == 3:
				on_submit.call(picked.duplicate())
				picked.clear()
				disp.text = "○ ○ ○"
		)
		grid.add_child(b)


func set_tools(on: bool, cooldowns: Dictionary) -> void:
	_tools.visible = on and _panel == null
	if not on:
		return
	for k in _tool_btns:
		var b: Button = _tool_btns[k][0]
		var cd: float = cooldowns.get(k, 0.0)
		b.disabled = cd > 0.0
		b.text = (str(_tool_btns[k][1]) + "  (%d)" % int(ceil(cd))) if cd > 0.0 else str(_tool_btns[k][1])


func set_voice(text: String, muted: bool) -> void:
	_mic.visible = true
	_mic.text = "🔇" if muted else "🎙"
	_voice_lbl.text = text


func set_speaking(me: bool, other: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.bg_color = OK.darkened(0.3) if me else Color(0.12, 0.14, 0.17)
	for st in ["normal", "hover", "pressed", "focus"]:
		_mic.add_theme_stylebox_override(st, sb)
	if other:
		_voice_lbl.text = "🗣 الشريك يتكلّم…"


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


func end_screen(won: bool, next_name := "", stats := "") -> void:
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
	if stats != "":
		var st := _label(26, Color(0.9, 0.91, 0.92))
		st.text = stats
		st.set_anchors_preset(Control.PRESET_CENTER)
		st.offset_left = -560
		st.offset_right = 560
		st.offset_top = -250
		st.offset_bottom = -90
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.add_child(st)
	var b := _button("  القائمة الرئيسية  ", AMBER, Color(0.07, 0.05, 0.01), 28)
	b.set_anchors_preset(Control.PRESET_CENTER)
	b.offset_left = -170
	b.offset_right = 170
	b.offset_top = 40
	b.offset_bottom = 112
	b.pressed.connect(func(): get_tree().reload_current_scene())
	e.add_child(b)
	if won and next_name != "":
		var n := _button("  التالية: " + next_name + "  ▶", OK, Color(0.03, 0.08, 0.04), 28)
		n.set_anchors_preset(Control.PRESET_CENTER)
		n.offset_left = -220
		n.offset_right = 220
		n.offset_top = 128
		n.offset_bottom = 200
		n.pressed.connect(func(): next_pressed.emit())
		e.add_child(n)
