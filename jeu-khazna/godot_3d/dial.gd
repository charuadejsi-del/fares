# قرص الخزنة على الشاشة: كبير وواضح، 40 تدريجة وأرقام كل 5، ومؤشّر أحمر في الأعلى.
# يدور بنعومة نحو الرقم المختار، ويرسم 3 مصابيح للأرقام المؤكَّدة.
extends Control

var number := 0
var done := 0 # عدد الأرقام الصحيحة المؤكَّدة
var flash_red := 0.0 # وميض أحمر عند الخطأ
var font: Font
var _angle := 0.0


func _process(delta: float) -> void:
	var target := -number * TAU / 40.0
	_angle = lerp_angle(_angle, target, minf(1.0, delta * 14.0))
	flash_red = maxf(0.0, flash_red - delta * 1.5)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.42
	# الإطار المعدني
	draw_circle(c, r * 1.12, Color(0.12, 0.13, 0.15))
	draw_arc(c, r * 1.12, 0, TAU, 96, Color(0.45, 0.48, 0.52), 4.0)
	draw_circle(c, r, Color(0.07, 0.075, 0.085))
	draw_arc(c, r, 0, TAU, 96, Color(0.3, 0.32, 0.35), 3.0)
	# التدريجات والأرقام (تدور)
	for n in 40:
		var a := _angle + n * TAU / 40.0 - PI / 2.0
		var dir := Vector2(cos(a), sin(a))
		var big := n % 5 == 0
		draw_line(c + dir * r * (0.80 if big else 0.87), c + dir * r * 0.97, Color(0.9, 0.9, 0.86), 3.0 if big else 1.5)
		if big and font:
			var s := str(n)
			var fs := int(r * 0.16)
			var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(font, c + dir * r * 0.66 - Vector2(tw.x / 2.0, -fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.92, 0.92, 0.88))
	# المقبض المركزي
	draw_circle(c, r * 0.32, Color(0.22, 0.24, 0.27))
	draw_arc(c, r * 0.32, 0, TAU, 48, Color(0.55, 0.58, 0.62), 3.0)
	for k in 4:
		var a2 := _angle + k * PI / 2.0
		draw_line(c, c + Vector2(cos(a2), sin(a2)) * r * 0.3, Color(0.4, 0.43, 0.47), 6.0)
	# المؤشّر الأحمر الثابت في الأعلى
	var tip := c + Vector2(0, -r * 1.02)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -26), tip + Vector2(14, -26)]), Color(0.95, 0.2, 0.15))
	# المصابيح الثلاثة
	for i in 3:
		var p := c + Vector2((i - 1) * r * 0.45, r * 1.32)
		var col := Color(0.42, 0.85, 0.58) if i < done else Color(0.2, 0.22, 0.25)
		if flash_red > 0.0 and i >= done:
			col = Color(0.95, 0.2, 0.15).lerp(col, 1.0 - flash_red)
		draw_circle(p, r * 0.08, col)
		draw_arc(p, r * 0.08, 0, TAU, 24, Color(0.5, 0.52, 0.56), 2.0)
