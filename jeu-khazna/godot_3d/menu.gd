# الشاشة الأولى: لعب فردي للتجربة، أو إنشاء غرفة بكود، أو الانضمام بكود.
extends CanvasLayer

signal solo
signal host(role: String)
signal join(code: String)

var _root: Control
var _info: Label
var _code: LineEdit
var _box: VBoxContainer


func _ready() -> void:
	# نطلب إذن الميكروفون من الشاشة الأولى حتى يكون جاهزاً قبل بدء الصوت.
	if OS.get_name() == "Android" and not OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
		OS.request_permission("android.permission.RECORD_AUDIO")
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.02, 0.025, 0.03, 0.97)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_box.custom_minimum_size = Vector2(520, 0)
	center.add_child(_box)

	_box.add_child(_title("الخزنة 3D", 64, Color(0.91, 0.63, 0.23)))
	_box.add_child(_title("عميل يتسلّل · محلّل يبحث · خزنة لا تُفتح إلا معاً", 22, Color(0.64, 0.67, 0.7)))
	_box.add_child(_btn("🕵️  إنشاء غرفة — أنا العميل", func(): host.emit("agent")))
	_box.add_child(_btn("🖥️  إنشاء غرفة — أنا المحلّل", func(): host.emit("analyst")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_code = LineEdit.new()
	_code.placeholder_text = "كود الغرفة"
	_code.max_length = 4
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_code.custom_minimum_size = Vector2(200, 72)
	_code.add_theme_font_size_override("font_size", 34)
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_code)
	var jb := _btn("انضمام", func(): _try_join())
	jb.custom_minimum_size = Vector2(200, 72)
	row.add_child(jb)
	_box.add_child(row)
	_box.add_child(_btn("🎮  تجربة وحدي (أبدّل بين الدورين)", func(): solo.emit()))
	_info = _title("", 24, Color(0.42, 0.85, 0.58))
	_box.add_child(_info)


func _title(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.12)
	sb.border_color = Color(0.91, 0.63, 0.23, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var sp := sb.duplicate()
	(sp as StyleBoxFlat).bg_color = Color(0.2, 0.15, 0.06)
	b.add_theme_stylebox_override("pressed", sp)
	b.pressed.connect(cb)
	return b


func _try_join() -> void:
	var c := _code.text.strip_edges()
	if c.length() != 4 or not c.is_valid_int():
		show_info("اكتب كود الغرفة (4 أرقام)", Color(0.9, 0.28, 0.3))
		return
	join.emit(c)


func show_info(t: String, c := Color(0.42, 0.85, 0.58)) -> void:
	_info.text = t
	_info.add_theme_color_override("font_color", c)


func waiting(code: String, role: String) -> void:
	for ch in _box.get_children():
		ch.visible = false
	_box.get_child(0).visible = true
	_info.visible = true
	var r := "العميل" if role == "agent" else "المحلّل"
	show_info("كود الغرفة: %s\nأنت %s — أعطِ الكود لشريكك وانتظره…" % [code, r], Color(0.91, 0.63, 0.23))
	_info.add_theme_font_size_override("font_size", 34)
