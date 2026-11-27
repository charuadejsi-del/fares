extends Control
## أزرار اللمس: جويستيك على اليسار، ونطحة/قفز/جري على اليمين (يدعم عدة أصابع).
## في الحاسوب: WASD/الأسهم للمشي، Space للقفز، E للنطحة، Shift للجري.

const JOY_R := 90.0

var game
var font: Font
var joy_idx := -1
var joy_center := Vector2.ZERO
var joy_vec := Vector2.ZERO
var sprint_idx := -1
var flash := {"butt": 0.0, "jump": 0.0}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _buttons() -> Dictionary:
	var w := size.x
	var h := size.y
	return {
		"butt": [Vector2(w - 150, h - 150), 82.0, "نطحة", Color("ff7a3d")],
		"jump": [Vector2(w - 330, h - 95), 60.0, "قفز", Color("3b8fe0")],
		"sprint": [Vector2(w - 150, h - 335), 60.0, "جري", Color("2fb36d")],
	}


func _hit(p: Vector2) -> String:
	var bs := _buttons()
	for k in bs:
		var b: Array = bs[k]
		var c: Vector2 = b[0]
		var r: float = b[1]
		if p.distance_to(c) <= r * 1.25:
			return k
	return ""


func release_all() -> void:
	joy_idx = -1
	joy_vec = Vector2.ZERO
	sprint_idx = -1


func _input(ev: InputEvent) -> void:
	if not visible or game == null:
		return
	if ev is InputEventScreenTouch:
		var tc := ev as InputEventScreenTouch
		if tc.pressed:
			var k := _hit(tc.position)
			if k == "butt":
				game.sheep.want_butt = true
				flash["butt"] = 0.15
			elif k == "jump":
				game.sheep.want_jump = true
				flash["jump"] = 0.15
			elif k == "sprint":
				sprint_idx = tc.index
			elif tc.position.x < size.x * 0.55 and joy_idx == -1:
				joy_idx = tc.index
				joy_center = tc.position
				joy_vec = Vector2.ZERO
		else:
			if tc.index == joy_idx:
				joy_idx = -1
				joy_vec = Vector2.ZERO
			if tc.index == sprint_idx:
				sprint_idx = -1
	elif ev is InputEventScreenDrag:
		var dr := ev as InputEventScreenDrag
		if dr.index == joy_idx:
			var d := dr.position - joy_center
			if d.length() > JOY_R:
				joy_center += d.normalized() * (d.length() - JOY_R)
				d = dr.position - joy_center
			joy_vec = d / JOY_R
	elif ev is InputEventKey:
		var kk := ev as InputEventKey
		if kk.pressed and not kk.echo:
			if kk.keycode == KEY_SPACE:
				game.sheep.want_jump = true
				flash["jump"] = 0.15
			elif kk.keycode == KEY_E or kk.keycode == KEY_J or kk.keycode == KEY_ENTER:
				game.sheep.want_butt = true
				flash["butt"] = 0.15


func _process(delta: float) -> void:
	flash["butt"] = maxf(float(flash["butt"]) - delta, 0.0)
	flash["jump"] = maxf(float(flash["jump"]) - delta, 0.0)
	if game and visible:
		var kb := Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			kb.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			kb.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			kb.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			kb.y += 1.0
		game.sheep.move_input = joy_vec if joy_idx != -1 else kb.limit_length(1.0)
		game.sheep.sprinting = sprint_idx != -1 or Input.is_key_pressed(KEY_SHIFT)
	queue_redraw()


func _draw() -> void:
	var f: Font = font if font else ThemeDB.fallback_font
	var base := joy_center if joy_idx != -1 else Vector2(170, size.y - 170)
	draw_circle(base, JOY_R, Color(1, 1, 1, 0.12))
	draw_arc(base, JOY_R, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0, true)
	draw_circle(base + joy_vec * JOY_R, 40.0, Color(1, 1, 1, 0.55))
	var low_energy := false
	if game and game.sheep:
		low_energy = game.sheep.energy < 15.0
	var bs := _buttons()
	for k in bs:
		var b: Array = bs[k]
		var c: Vector2 = b[0]
		var r: float = b[1]
		var col: Color = b[3]
		var on := false
		if k == "sprint":
			on = sprint_idx != -1
		else:
			on = float(flash[k]) > 0.0
		col.a = 0.92 if on else 0.62
		if k == "butt" and low_energy:
			col = col.darkened(0.5)
		draw_circle(c, r * (0.92 if on else 1.0), col)
		draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 3.0, true)
		var fs := 34 if r > 70.0 else 28
		draw_string(f, c + Vector2(-r, fs * 0.35), str(b[2]), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)
