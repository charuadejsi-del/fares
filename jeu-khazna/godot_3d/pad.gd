# رسم العصا العائمة: تظهر حيث يلمس الإبهام الأيسر.
extends Control

var hud


func _draw() -> void:
	if hud == null:
		return
	var st: Dictionary = hud.pad_state()
	var vp := get_viewport_rect().size
	var o: Vector2 = st.origin if st.active else Vector2(140, vp.y - 150)
	var a := 0.55 if st.active else 0.25
	draw_circle(o, 70.0, Color(0, 0, 0, 0.35 * a + 0.1))
	draw_arc(o, 70.0, 0, TAU, 48, Color(1, 1, 1, 0.5 * a), 2.0)
	var k: Vector2 = o
	if st.active:
		var v: Vector2 = st.pos - st.origin
		if v.length() > 70.0:
			v = v.normalized() * 70.0
		k = o + v
	draw_circle(k, 28.0, Color(1, 1, 1, 0.3 * a + 0.05))
	draw_arc(k, 28.0, 0, TAU, 32, Color(0.91, 0.63, 0.23, 0.9 * a + 0.1), 3.0)
