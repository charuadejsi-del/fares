# زرّ دائري بأيقونة مرسومة (لأن خطّ اللعبة لا يعرض الإيموجي) وكلمة صغيرة تحته.
extends Button

var kind := "" # crouch | stand | run | walk | eye | throw
var caption := ""
var on := false


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(999)
		sb.bg_color = Color(0.06, 0.07, 0.09, 0.55)
		sb.border_color = Color(1, 1, 1, 0.35)
		sb.set_border_width_all(3)
		if st == "pressed":
			sb.bg_color = Color(0.91, 0.63, 0.23, 0.6)
		add_theme_stylebox_override(st, sb)


func set_on(v: bool) -> void:
	if v == on:
		return
	on = v
	var sb := get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	sb.bg_color = Color(0.2, 0.5, 0.3, 0.7) if v else Color(0.06, 0.07, 0.09, 0.55)
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	queue_redraw()


func _draw() -> void:
	var c := size * Vector2(0.5, 0.42)
	var r := minf(size.x, size.y) * 0.22
	var w := Color(1, 1, 1, 0.45 if disabled else 0.95)
	var lw := maxf(3.0, r * 0.18)
	match kind:
		"crouch", "stand":
			# رأس وجسم منحنٍ (أو واقف)
			var crouched := kind == "crouch"
			var head := c + Vector2(0, -r * (0.55 if crouched else 1.0))
			draw_circle(head, r * 0.28, w)
			var hip := c + Vector2(0, r * (0.25 if crouched else 0.3))
			draw_line(head + Vector2(0, r * 0.3), hip, w, lw)
			if crouched:
				draw_line(hip, hip + Vector2(r * 0.6, r * 0.25), w, lw)
				draw_line(hip + Vector2(r * 0.6, r * 0.25), hip + Vector2(r * 0.3, r * 0.75), w, lw)
				draw_line(hip, hip + Vector2(-r * 0.4, r * 0.75), w, lw)
			else:
				draw_line(hip, hip + Vector2(r * 0.3, r * 0.9), w, lw)
				draw_line(hip, hip + Vector2(-r * 0.3, r * 0.9), w, lw)
		"run", "walk":
			# سهمان سريعان (أو سهم واحد للمشي)
			var n := 2 if kind == "run" else 1
			for k in n:
				var o := c + Vector2((k - (n - 1) * 0.5) * r * 0.7, 0)
				draw_polyline(PackedVector2Array([o + Vector2(-r * 0.35, -r * 0.7), o + Vector2(r * 0.35, 0), o + Vector2(-r * 0.35, r * 0.7)]), w, lw)
		"eye":
			var pts := PackedVector2Array()
			for k in 25:
				var a := PI * float(k) / 24.0
				pts.append(c + Vector2(cos(a) * r * 1.1, -sin(a) * r * 0.6))
			for k in 25:
				var a := PI * float(k) / 24.0
				pts.append(c + Vector2(-cos(a) * r * 1.1, sin(a) * r * 0.6))
			draw_polyline(pts, w, lw * 0.8)
			draw_circle(c, r * 0.32, w)
		"throw":
			draw_arc(c + Vector2(0, r * 0.4), r * 0.9, PI * 1.1, PI * 1.9, 16, w, lw)
			var tip := c + Vector2(r * 0.73, -r * 0.13)
			draw_line(tip, tip + Vector2(-r * 0.35, -r * 0.05), w, lw)
			draw_line(tip, tip + Vector2(-r * 0.05, r * 0.35), w, lw)
			draw_rect(Rect2(c + Vector2(-r * 0.95, r * 0.15), Vector2(r * 0.35, r * 0.55)), w)
	if caption != "":
		var f := get_theme_default_font()
		var fs := int(size.y * 0.15)
		var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((size.x - tw) * 0.5, size.y * 0.86), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, w)
