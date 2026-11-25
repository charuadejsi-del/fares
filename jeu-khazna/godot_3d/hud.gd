# الواجهة والتحكّم باللمس: الإبهام الأيسر = عصا عائمة للمشي، الإبهام الأيمن = سحب للالتفات.
extends CanvasLayer

signal hack_pressed

var player
var _move_touch := -1
var _move_origin := Vector2.ZERO
var _move_pos := Vector2.ZERO
var _look_touch := -1

var _pad: Control
var _objective: Label
var _flash: Label
var _timer: Label
var _hack: Button
var _bar: ProgressBar
var _alert: ColorRect
var _alert_mat: ShaderMaterial
var _hit := 0.0
var _end: Control

const PAD_R := 70.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# إطار سينمائي داكن + وهج أحمر عند الاكتشاف
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var vm := ShaderMaterial.new()
	vm.shader = sh
	vig.material = vm
	root.add_child(vig)

	_alert = ColorRect.new()
	_alert.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_mat = ShaderMaterial.new()
	_alert_mat.shader = sh
	_alert_mat.set_shader_parameter("tint", Vector3(0.9, 0.1, 0.1))
	_alert_mat.set_shader_parameter("strength", 0.0)
	_alert_mat.set_shader_parameter("inner", 0.3)
	_alert.material = _alert_mat
	root.add_child(_alert)

	_objective = _label(22, Color(0.9, 0.91, 0.92))
	_objective.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective.offset_top = 18
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_objective)

	_timer = _label(46, Color(0.9, 0.28, 0.3))
	_timer.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_timer.offset_top = 56
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.visible = false
	root.add_child(_timer)

	_flash = _label(34, Color.WHITE)
	_flash.set_anchors_preset(Control.PRESET_CENTER)
	_flash.offset_left = -400
	_flash.offset_right = 400
	_flash.offset_top = -140
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.modulate.a = 0.0
	root.add_child(_flash)

	_hack = Button.new()
	_hack.text = "  اخترق الجهاز  "
	_hack.add_theme_font_size_override("font_size", 30)
	_hack.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hack.offset_left = -330
	_hack.offset_top = -130
	_hack.offset_right = -40
	_hack.offset_bottom = -40
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.91, 0.63, 0.23)
	sb.set_corner_radius_all(10)
	_hack.add_theme_stylebox_override("normal", sb)
	_hack.add_theme_stylebox_override("hover", sb)
	_hack.add_theme_stylebox_override("pressed", sb)
	_hack.add_theme_color_override("font_color", Color(0.07, 0.05, 0.01))
	_hack.add_theme_color_override("font_hover_color", Color(0.07, 0.05, 0.01))
	_hack.visible = false
	_hack.pressed.connect(func(): hack_pressed.emit())
	root.add_child(_hack)

	_bar = ProgressBar.new()
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.offset_left = -220
	_bar.offset_right = 220
	_bar.offset_top = -200
	_bar.offset_bottom = -176
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.visible = false
	root.add_child(_bar)

	_pad = preload("res://pad.gd").new()
	_pad.hud = self
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pad)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _input(event) -> void:
	if player == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if _hack.visible and _hack.get_global_rect().has_point(event.position):
				return
			if event.position.x < vp.x * 0.45 and _move_touch == -1:
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
			player.look_delta += event.relative * 1.5


func pad_state() -> Dictionary:
	return {"active": _move_touch != -1, "origin": _move_origin, "pos": _move_pos}


func _process(delta: float) -> void:
	_hit = maxf(0.0, _hit - delta * 1.5)
	if _flash.modulate.a > 0.0:
		_flash.modulate.a = maxf(0.0, _flash.modulate.a - delta * 0.45)


func set_objective(t: String) -> void:
	_objective.text = t


func set_alert(v: float) -> void:
	_alert_mat.set_shader_parameter("strength", clampf(maxf(v * 0.75, _hit), 0.0, 0.9))


func hit() -> void:
	_hit = 0.9


func flash(t: String, c: Color) -> void:
	_flash.text = t
	_flash.add_theme_color_override("font_color", c)
	_flash.modulate.a = 1.0


func show_hack(v: bool) -> void:
	_hack.visible = v


func set_progress(v: float) -> void:
	_bar.visible = v >= 0.0
	_bar.value = clampf(v, 0.0, 1.0)


func set_timer(sec: float) -> void:
	_timer.visible = true
	var s := int(ceil(maxf(sec, 0.0)))
	_timer.text = "%02d:%02d" % [s / 60, s % 60]


func end_screen(won: bool) -> void:
	_timer.visible = false
	_end = ColorRect.new()
	(_end as ColorRect).color = Color(0, 0, 0, 0.72)
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_end)
	var l := _label(48, Color(0.42, 0.85, 0.58) if won else Color(0.9, 0.28, 0.3))
	l.text = "نجحت المهمّة! هربتَ بالكنز 🏆" if won else "أُغلقت الأبواب… قُبض عليك"
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.offset_left = -500
	l.offset_right = 500
	l.offset_top = -60
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end.add_child(l)
	var b := Button.new()
	b.text = "  العب من جديد  "
	b.add_theme_font_size_override("font_size", 28)
	b.set_anchors_preset(Control.PRESET_CENTER)
	b.offset_left = -150
	b.offset_right = 150
	b.offset_top = 40
	b.offset_bottom = 110
	b.pressed.connect(func(): get_tree().reload_current_scene())
	_end.add_child(b)
