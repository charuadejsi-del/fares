# زرّ دائري يعمل باللمس المتعدّد (يُضغط مع تحريك العصا في نفس الوقت).
extends Control

signal pressed

var text := ""
var color := Color(0.95, 0.68, 0.22)
var big := false
var down := false
var enabled := true
var cooldown := 0.0 # 0..1 (حلقة انتظار)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_text(t: String) -> void:
	if t != text:
		text = t
		queue_redraw()


func hit(p: Vector2) -> bool:
	if not visible or not enabled:
		return false
	var c := global_position + size * 0.5
	return p.distance_to(c) <= size.x * 0.55


func _draw() -> void:
	var c := size * 0.5
	var r := size.x * 0.5
	var col := color if enabled else Color(0.3, 0.3, 0.32)
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, col.darkened(0.25) if down else col)
	draw_arc(c, r - 2, 0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
	if cooldown > 0.0:
		draw_arc(c, r - 7, -PI / 2, -PI / 2 + TAU * cooldown, 40, Color(0, 0, 0, 0.55), 8.0, true)
	var f := get_theme_default_font()
	var fs := 30 if big else 22
	var lines := text.split("\n")
	var y0 := c.y - (lines.size() - 1) * fs * 0.55
	for i in lines.size():
		var w := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(f, Vector2(c.x - w / 2, y0 + i * fs * 1.1 + fs * 0.35), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.06, 0.03) if enabled else Color(0.7, 0.7, 0.7))
