# مخطّط المتاهة عند المحلّل: الجدران من الأعلى، نقطة العميل، والحرّاس — يوجّه شريكه في الظلام.
extends Control

var segs: Array = [] # [[Vector2 a, Vector2 b], ...] بإحداثيات العالم (x, z)
var area := Rect2()
var agent_p := Vector2(-999, -999)
var guards_p: Array = []
var goal := Vector2(-999, -999)


func _draw() -> void:
	var s: float = minf(size.x / area.size.x, size.y / area.size.y)
	var off := (size - area.size * s) * 0.5
	var tr := func(p: Vector2) -> Vector2: return off + (p - area.position) * s
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.06, 0.1))
	for i in 13:
		var gx := float(i) / 12.0 * size.x
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(0.1, 0.2, 0.3, 0.4), 1.0)
	for sg in segs:
		draw_line(tr.call(sg[0]), tr.call(sg[1]), Color(0.55, 0.85, 1.0), 4.0)
	if goal.x > -900:
		draw_circle(tr.call(goal), 9.0, Color(0.42, 0.85, 0.58))
	for g in guards_p:
		draw_circle(tr.call(g), 8.0, Color(0.95, 0.3, 0.3))
	if agent_p.x > -900:
		draw_circle(tr.call(agent_p), 9.0, Color(1.0, 0.75, 0.25))
		draw_arc(tr.call(agent_p), 15.0, 0, TAU, 24, Color(1.0, 0.75, 0.25, 0.5), 2.0)
