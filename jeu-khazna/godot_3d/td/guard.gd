# حارس: دورية على مسار، مجال رؤية مرسوم على الأرض (يقطعه الجدار)، شكّ يتصاعد ثم مطاردة.
# عند العميل (صاحب القرار) يفكّر الحارس بنفسه؛ عند المحلّل هو دمية تتبع ما يرسله العميل.
extends Node3D

const Unit := preload("res://td/unit.gd")
const L := preload("res://td/level.gd")

const HALF := 42.0 # نصف زاوية الرؤية
const WALK := 1.7
const RUN := 4.1

var game: Node
var gname := ""
var unit: Node3D
var state := "patrol" # patrol · wait · still · sus · search · chase · back · ko
var sus := 0.0
var sight := 8.0
var ko := false
var hidden := false
var stripped := false
var puppet := false
var heading := 0.0 # الاتجاه الحالي (دوران Y)
var alert := 0.0 # بعد إنذار: يرى أبعد لفترة

var _route: Array = []
var _ri := 0
var _wait := 0.0
var _wait_t := 0.0
var _still_cell := Vector2i(-1, -1)
var _still_yaw := 0.0
var _scan := 0.0
var _scan_t := 0.0
var _idle_clip := "idle"
var _path: Array = []
var _pi := 0
var _target := Vector3.ZERO
var _lost := 0.0
var _search_t := 0.0
var _cone: MeshInstance3D
var _cone_mesh: ImmediateMesh
var _cone_mat: StandardMaterial3D
var _mark: Label3D
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0


func setup(g: Node, def: Dictionary) -> void:
	game = g
	gname = str(def.get("name", "حارس"))
	sight = float(def.get("range", 8.0))
	_idle_clip = str(def.get("idle", "idle"))
	if def.has("still"):
		_still_cell = def["still"]
		_still_yaw = L.yaw_of(float(def.get("look", 0.0)))
		_scan = float(def.get("scan", 0.0))
		position = L.cell_center(_still_cell)
		heading = _still_yaw
		state = "still"
	else:
		for c in def["path"]:
			_route.append(L.cell_center(c))
		_wait = float(def.get("wait", 1.5))
		position = _route[0]
		_ri = 0
		_next_leg()
	rotation.y = heading
	unit = Unit.new()
	add_child(unit)
	unit.setup(Unit.GUARD_MODEL)
	_build_cone()
	_mark = Label3D.new()
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.no_depth_test = true
	_mark.font_size = 150
	_mark.outline_size = 24
	_mark.position.y = 2.5
	_mark.visible = false
	add_child(_mark)
	_net_pos = position
	_net_yaw = heading


func _build_cone() -> void:
	_cone_mesh = ImmediateMesh.new()
	_cone = MeshInstance3D.new()
	_cone.mesh = _cone_mesh
	_cone_mat = StandardMaterial3D.new()
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.vertex_color_use_as_albedo = true
	_cone_mat.no_depth_test = false
	_cone.material_override = _cone_mat
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.top_level = true
	add_child(_cone)


func eye() -> Vector3:
	return global_position + Vector3(0, 1.5, 0)


func forward() -> Vector3:
	return Vector3(-sin(heading), 0, -cos(heading))


func range_now() -> float:
	return sight * (1.3 if alert > 0.0 else 1.0)


## هل يرى الحارس نقطة؟ داخل المدى والزاوية، ولا جدار ولا صناديق بينهما.
func sees(p: Vector3, h := 1.0) -> bool:
	if ko:
		return false
	var to := p - global_position
	to.y = 0.0
	var d := to.length()
	if d > range_now():
		return false
	if d > 0.6 and rad_to_deg(forward().angle_to(to.normalized())) > HALF:
		return false
	return game.clear_line(eye(), p + Vector3(0, h, 0))


## العميل خلف الحارس وقريب منه (يمكن إسقاطه).
func is_behind(p: Vector3) -> bool:
	if ko or state == "chase":
		return false
	var to := p - global_position
	to.y = 0.0
	if to.length() > 1.7:
		return false
	return rad_to_deg(forward().angle_to(to.normalized())) > 100.0


func knock_out() -> void:
	ko = true
	state = "ko"
	sus = 0.0
	_mark.visible = false
	_cone.visible = false
	unit.one_shot("ko", 9999.0)


func investigate(p: Vector3, why := "sus") -> void:
	if ko or state == "chase":
		return
	state = "sus" if why == "sus" else "search"
	_target = p
	_search_t = 4.0
	_go(p)


func chase() -> void:
	if ko:
		return
	if state != "chase":
		game.on_chase_start(self)
	state = "chase"
	sus = 1.0


# ───────── التفكير (عند العميل) ─────────
func tick(delta: float, agent_pos: Vector3, disguised: bool, noisy: bool) -> void:
	if ko:
		return
	alert = maxf(0.0, alert - delta)
	var seen := sees(agent_pos)
	var d := global_position.distance_to(agent_pos)
	# الشكّ: سرعة تصاعده حسب القرب، والتنكّر يحمي إلا من القرب الشديد مع الركض
	if seen:
		var rate := 0.0
		if not disguised:
			rate = lerpf(2.2, 0.55, clampf(d / range_now(), 0.0, 1.0))
		elif d < 2.2 and noisy:
			rate = 0.6
		if rate > 0.0:
			sus = minf(1.0, sus + rate * delta)
			_target = agent_pos
		else:
			sus = maxf(0.0, sus - 0.3 * delta)
	else:
		sus = maxf(0.0, sus - (0.12 if state == "sus" else 0.25) * delta)
	# الركض يُسمع من قريب حتى من الخلف
	if noisy and not disguised and d < 6.0 and state != "chase" and state != "sus":
		investigate(agent_pos)
		sus = maxf(sus, 0.4)
	if sus >= 1.0 and state != "chase":
		chase()
	elif sus > 0.35 and (state == "patrol" or state == "wait" or state == "still" or state == "back" or state == "search"):
		investigate(_target)
	match state:
		"chase":
			if seen:
				_lost = 0.0
				_target = agent_pos
			else:
				_lost += delta
			if _lost > 3.5:
				state = "search"
				_search_t = 4.0
				_go(_target)
				sus = 0.6
			else:
				_move_direct(agent_pos if seen else _target, RUN, delta)
				if d < 1.1 and seen:
					game.on_caught(self)
		"sus":
			# يقف ويلتفت نحو مصدر الشكّ ثم يقترب ببطء
			_face(_target, delta, 5.0)
			if sus > 0.55:
				_follow(WALK * 0.8, delta)
			else:
				unit.play("alert")
			if sus <= 0.05:
				_return()
		"search":
			if _follow(WALK, delta):
				_search_t -= delta
				heading += delta * 1.6 * sin(_search_t * 2.0)
				unit.play("alert")
				if _search_t <= 0.0:
					_return()
		"back":
			if _follow(WALK, delta):
				if _still_cell.x >= 0:
					state = "still"
				else:
					_next_leg()
		"patrol":
			if _follow(WALK, delta):
				state = "wait"
				_wait_t = _wait
		"wait":
			unit.play(_idle_clip)
			_wait_t -= delta
			if _route.is_empty():
				state = "still"
			elif _wait_t <= 0.0:
				_ri = (_ri + 1) % _route.size()
				_next_leg()
		"still":
			_scan_t += delta
			var want := _still_yaw + deg_to_rad(_scan) * sin(_scan_t * 0.7)
			heading = lerp_angle(heading, want, minf(1.0, delta * 3.0))
			unit.play(_idle_clip)
	rotation.y = heading


## يرى جسماً مُغمى عليه غير مخفيّ؟
func check_body(b: Node3D) -> bool:
	if ko or state == "chase":
		return false
	return sees(b.global_position, 0.3)


func _return() -> void:
	sus = 0.0
	state = "back"
	if _still_cell.x >= 0:
		_go(L.cell_center(_still_cell))
	else:
		_go(_route[_ri])


func _next_leg() -> void:
	state = "patrol"
	_go(_route[_ri])


func _go(p: Vector3) -> void:
	_path = game.find_path(global_position, p)
	_pi = 0


## يتبع المسار المحسوب؛ يرجع true عند الوصول.
func _follow(spd: float, delta: float) -> bool:
	if _pi >= _path.size():
		return true
	var p: Vector3 = _path[_pi]
	var to := p - global_position
	to.y = 0.0
	if to.length() < 0.15:
		_pi += 1
		return _pi >= _path.size()
	var step := minf(to.length(), spd * delta)
	global_position += to.normalized() * step
	heading = lerp_angle(heading, atan2(-to.x, -to.z), minf(1.0, delta * 8.0))
	unit.play("run" if spd > 3.0 else "walk", 0.2, spd / WALK if spd <= 3.0 else 1.0)
	return false


func _move_direct(p: Vector3, spd: float, delta: float) -> void:
	# مطاردة: مسار إن كان بينهما جدار، وإلا مباشرة
	if not game.clear_line(eye(), p + Vector3(0, 1.0, 0)):
		if _pi >= _path.size() or _path.is_empty() or (_path[_path.size() - 1] as Vector3).distance_to(p) > 2.0:
			_go(p)
		_follow(spd, delta)
		return
	var to := p - global_position
	to.y = 0.0
	if to.length() > 0.05:
		global_position += to.normalized() * minf(to.length(), spd * delta)
		heading = lerp_angle(heading, atan2(-to.x, -to.z), minf(1.0, delta * 10.0))
	unit.play("run")


func _face(p: Vector3, delta: float, k: float) -> void:
	var to := p - global_position
	if Vector2(to.x, to.z).length() > 0.1:
		heading = lerp_angle(heading, atan2(-to.x, -to.z), minf(1.0, delta * k))


# ───────── الشبكة (دمية عند المحلّل) ─────────
func net_state() -> Array:
	var st := state
	if ko:
		st = "hid" if hidden else ("ko_s" if stripped else "ko")
	return [snappedf(global_position.x, 0.01), snappedf(global_position.z, 0.01), snappedf(heading, 0.01), st, snappedf(sus, 0.01), unit.clip]


func apply_net(e: Array) -> void:
	_net_pos = Vector3(float(e[0]), 0, float(e[1]))
	_net_yaw = float(e[2])
	var st := str(e[3])
	sus = float(e[4])
	if st.begins_with("ko") or st == "hid":
		if not ko:
			knock_out()
		if st == "ko_s" and not stripped:
			stripped = true
			unit.skin_look()
		hidden = st == "hid"
		visible = not hidden
	else:
		state = st
		unit.play(str(e[5]))


func _process(delta: float) -> void:
	if puppet:
		global_position = global_position.lerp(_net_pos, minf(1.0, delta * 10.0))
		heading = lerp_angle(heading, _net_yaw, minf(1.0, delta * 10.0))
		rotation.y = heading
	_update_cone()
	_update_mark()


# ───────── مجال الرؤية المرسوم ─────────
func _update_cone() -> void:
	_cone_mesh.clear_surfaces()
	if ko or not visible:
		return
	var col := Color(1.0, 0.95, 0.75, 0.16)
	if state == "chase":
		col = Color(1.0, 0.15, 0.1, 0.32)
	elif sus > 0.05:
		col = Color(1.0, 0.95, 0.75, 0.16).lerp(Color(1.0, 0.5, 0.05, 0.3), clampf(sus * 1.4, 0.0, 1.0))
	var o := global_position + Vector3(0, 0.06, 0)
	var r := range_now()
	var n := 22
	var pts: Array = []
	for i in n + 1:
		var a := heading + deg_to_rad(-HALF + 2.0 * HALF * float(i) / n)
		var dir := Vector3(-sin(a), 0, -cos(a))
		var dist: float = game.ray_dist(o + Vector3(0, 1.0, 0), dir, r)
		pts.append(o + dir * dist)
	_cone_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _cone_mat)
	var edge := Color(col.r, col.g, col.b, col.a * 0.35)
	for i in n:
		_cone_mesh.surface_set_color(col)
		_cone_mesh.surface_add_vertex(o)
		_cone_mesh.surface_set_color(edge)
		_cone_mesh.surface_add_vertex(pts[i])
		_cone_mesh.surface_set_color(edge)
		_cone_mesh.surface_add_vertex(pts[i + 1])
	_cone_mesh.surface_end()


func _update_mark() -> void:
	if ko:
		_mark.visible = false
		return
	if state == "chase":
		_mark.visible = true
		_mark.text = "!"
		_mark.modulate = Color(1.0, 0.2, 0.15)
	elif sus > 0.2 or state == "search":
		_mark.visible = true
		_mark.text = "?"
		_mark.modulate = Color(1.0, 0.75, 0.2)
	else:
		_mark.visible = false
