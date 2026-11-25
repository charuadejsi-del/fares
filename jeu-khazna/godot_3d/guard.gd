# الحارس: شخصية Mixamo (SWAT) بحركات حقيقية — يمشي في دوريّة، يتوقّف أحياناً (يمسح عرقه أو يطرد الحشرات)،
# يتأهّب ويلتفت نحو العميل حين يلمحه، ويهجم حين يكشفه. مصباح بظلال، وقع خطوات، ولاسلكي.
extends Node3D

var path: Array = []
var speed := 1.25
var alarm := false
var _idx := 0
var _anim: AnimationPlayer
var _light: SpotLight3D
var _steps: AudioStreamPlayer3D
var _radio: AudioStreamPlayer3D
var _state := "walk" # walk | idle | alert | attack
var _wait := 0.0
var _radio_t := 8.0
var _alert_target := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var debug := ""
var _skel: Skeleton3D
var bounds := Rect2() # حدود غرفته (x، z): لا يخرج منها أثناء المطاردة
var saw := false # يضبطها المشهد كل إطار: هل يرى العميل الآن؟
var _target: Node3D
var _lost := 0.0
var _turn_t := 18.0
# المزامنة: عند المحلّل يُحرَّك الحارس بما يرسله هاتف العميل (المرجع)
var remote := false
var sight := 1.0 # حدّة البصر حسب المرحلة
var _r_pos := Vector3.ZERO
var _r_rot := 0.0
var _r_state := "walk"
var _beacon: MeshInstance3D
var _beacon_t := 0.0
var _look_rot := 0.0
const CHASE_SPEED := 2.75

const RANGE := 7.5
const HALF_ANGLE := 32.0
const CLIPS := {
	"walk": "res://characters/walk.fbx",
	"idle_sweat": "res://characters/idle_sweat.fbx",
	"idle_bugs": "res://characters/idle_bugs.fbx",
	"alert": "res://characters/alert.fbx",
	"attack": "res://characters/attack.fbx",
	"back": "res://characters/back.fbx",
}
const LOOPED := ["walk", "idle_sweat", "idle_bugs", "alert", "back"]


func setup(points: Array, spd: float, room: Rect2) -> void:
	path = points
	speed = spd
	bounds = room
	position = points[0]
	if points.size() > 1:
		var d: Vector3 = points[1] - points[0]
		rotation.y = atan2(-d.x, -d.z)


func _ready() -> void:
	_rng.seed = int(position.x * 1000.0 + position.z)
	var model := _load_model()
	if model == null:
		model = _fallback()
	add_child(model)
	_fit(model)

	_light = SpotLight3D.new()
	_light.position = Vector3(0.22, 1.3, -0.35)
	_light.rotation_degrees.x = -12
	_light.light_color = Color(1.0, 0.92, 0.7)
	_light.light_energy = 5.0
	_light.spot_range = 9.0
	_light.spot_angle = HALF_ANGLE
	_light.shadow_enabled = true
	add_child(_light)

	# علامة حمراء فوق الحارس تُرى عبر الجدران (أداة المحلّل)
	_beacon = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.35, 0.45, 0.35)
	_beacon.mesh = pm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.15, 0.1)
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.15, 0.1)
	bm.emission_energy_multiplier = 4.0
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.no_depth_test = true
	bm.render_priority = 10
	_beacon.material_override = bm
	_beacon.rotation_degrees.x = 180
	_beacon.position.y = 2.4
	_beacon.visible = false
	add_child(_beacon)

	_steps = _sound("guard_steps", true, -4.0)
	_radio = _sound("radio", false, -2.0)
	_play("walk")


func _sound(sound_name: String, loop: bool, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	var path_s := "res://sounds/%s.mp3" % sound_name
	if ResourceLoader.exists(path_s):
		var st = load(path_s)
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = loop
		p.stream = st
	p.volume_db = db
	p.unit_size = 4.0
	p.max_distance = 22.0
	p.position.y = 1.0
	add_child(p)
	return p


# ───────── الشخصية والحركات ─────────
func _load_model() -> Node3D:
	if not ResourceLoader.exists(CLIPS["walk"]):
		return null
	var scn = load(CLIPS["walk"])
	if not scn is PackedScene:
		return null
	var model := (scn as PackedScene).instantiate() as Node3D
	if model == null:
		return null
	model.rotation_degrees.y = 180 # شخصيات Mixamo تنظر نحو +Z
	_anim = _find(model, "AnimationPlayer") as AnimationPlayer
	var skel := _find(model, "Skeleton3D") as Skeleton3D
	_skel = skel
	debug += "tree=%s | " % _tree(model, 0)
	if _anim == null or skel == null:
		debug += "NO anim/skel"
		return model
	debug += "root_node=%s anims=%s | " % [_anim.root_node, _anim.get_animation_list()]
	var lib := AnimationLibrary.new()
	var root := _anim.get_node(_anim.root_node)
	var skel_path := str(root.get_path_to(skel))
	for key in CLIPS:
		var a := _first_anim(str(CLIPS[key]))
		if a == null:
			continue
		a = a.duplicate(true)
		if a.get_track_count() > 0:
			debug += "%s:%d tracks first=%s | " % [key, a.get_track_count(), a.track_get_path(0)]
		# توحيد مسارات العظام مع هيكل الشخصية، وإلغاء انزلاق الحوض للأمام (المشي في المكان)
		for i in a.get_track_count():
			var p := str(a.track_get_path(i))
			var c := p.find(":")
			if c >= 0:
				a.track_set_path(i, NodePath(skel_path + p.substr(c)))
			if a.track_get_type(i) == Animation.TYPE_POSITION_3D and p.contains("Hips") and a.track_get_key_count(i) > 0:
				var first: Vector3 = a.track_get_key_value(i, 0)
				for k in a.track_get_key_count(i):
					var v: Vector3 = a.track_get_key_value(i, k)
					a.track_set_key_value(i, k, Vector3(first.x, v.y, first.z))
		a.loop_mode = Animation.LOOP_LINEAR if LOOPED.has(key) else Animation.LOOP_NONE
		lib.add_animation(key, a)
	if _anim.has_animation_library("g"):
		_anim.remove_animation_library("g")
	_anim.add_animation_library("g", lib)
	return model


func _tree(n: Node, depth: int) -> String:
	if depth > 3:
		return ""
	var out := n.name + "<" + n.get_class() + ">"
	var kids := []
	for c in n.get_children():
		if c is MeshInstance3D and depth > 1:
			continue
		kids.append(_tree(c, depth + 1))
	if kids.size() > 0:
		out += "[" + ",".join(PackedStringArray(kids)) + "]"
	return out


func pose_report() -> String:
	if _skel == null or _skel.get_bone_count() == 0:
		return "no skeleton"
	var b := _skel.find_bone("mixamorig_LeftArm")
	if b < 0:
		b = 1
	var pose := _skel.get_bone_pose_rotation(b)
	var rest := _skel.get_bone_rest(b).basis.get_rotation_quaternion()
	var moved := pose.angle_to(rest) > 0.05
	return "bone %s moved=%s anim=%s" % [_skel.get_bone_name(b), moved, _anim.current_animation if _anim else ""]


func _first_anim(res_path: String) -> Animation:
	if not ResourceLoader.exists(res_path):
		return null
	var scn = load(res_path)
	if not scn is PackedScene:
		return null
	var inst := (scn as PackedScene).instantiate()
	var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
	var out: Animation = null
	if ap:
		# «mixamo_com» هي الحركة الحقيقية؛ وإلا الأطول (لا «Take 001» الثابتة ولا RESET)
		var best_len := -1.0
		for n in ap.get_animation_list():
			if str(n) == "RESET":
				continue
			var cand := ap.get_animation(n)
			if str(n) == "mixamo_com":
				out = cand
				break
			if cand.length > best_len:
				best_len = cand.length
				out = cand
	inst.free()
	return out


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f:
			return f
	return null


func _fit(model: Node3D) -> void:
	# مقياس الشخصية: طولها ≈ 1.8 م مهما كانت وحدات الملف، وقدماها على الأرض
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.size.y <= 0.01:
		return
	var k := 1.8 / box.size.y
	model.scale *= k
	model.position.y -= (box.position.y - global_position.y) * k


func _fallback() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.75
	body.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.13, 0.18, 0.3)
	body.material_override = m
	body.position.y = 0.88
	n.add_child(body)
	return n


func _play(clip: String, blend := 0.35) -> void:
	if _anim and _anim.has_animation("g/" + clip):
		if _anim.current_animation != "g/" + clip:
			_anim.play("g/" + clip, blend)


# ───────── السلوك ─────────
func set_alert(on: bool, target: Vector3) -> void:
	if _state == "attack":
		return
	if on:
		_state = "alert"
		_alert_target = target
	elif _state == "alert":
		_state = "walk"


func chase(target: Node3D) -> void:
	if _state == "attack":
		return
	_state = "chase"
	_target = target
	_lost = 0.0
	_light.light_color = Color(1.0, 0.45, 0.35)


func is_chasing() -> bool:
	return _state == "chase"


func attack() -> void:
	_state = "attack"
	_wait = 1.6
	_play("attack", 0.15)


## اسم الحالة للإرسال عبر الشبكة.
func state_name() -> String:
	return _state


func apply_remote(p: Vector3, ry: float, st: String) -> void:
	_r_pos = p
	_r_rot = ry
	_r_state = st


func mark(seconds: float) -> void:
	_beacon_t = seconds


## تشتيت: يلتفت بعيداً ويبحث (أداة المحلّل). لا أثر أثناء المطاردة أو الهجوم.
func distract() -> void:
	if _state == "chase" or _state == "attack":
		return
	_state = "search"
	_wait = 5.0


func _process(delta: float) -> void:
	_beacon_t = maxf(0.0, _beacon_t - delta)
	_beacon.visible = _beacon_t > 0.0
	if _beacon.visible:
		_beacon.rotation.y += delta * 3.0
	if remote:
		_remote_update(delta)
		return
	if path.size() < 2:
		return
	if alarm:
		_light.light_color = Color(1.0, 0.55, 0.45)
	_radio_t -= delta
	if _radio_t <= 0.0:
		_radio_t = _rng.randf_range(14.0, 28.0)
		if _radio.stream:
			_radio.play()

	match _state:
		"chase":
			_chase(delta)
		"look":
			# التفاتة مفاجئة إلى الخلف
			_steps_on(false)
			_play("alert", 0.12)
			rotation.y = lerp_angle(rotation.y, _look_rot, minf(1.0, delta * 9.0))
			_wait -= delta
			if _wait <= 0.0:
				_state = "walk"
		"search":
			_steps_on(false)
			_play("alert")
			rotation.y += delta * 1.2
			_wait -= delta
			if _wait <= 0.0:
				_state = "walk"
				_light.light_color = Color(1.0, 0.92, 0.7)
		"attack":
			_wait -= delta
			_steps_on(false)
			if _wait <= 0.0:
				_state = "walk"
		"alert":
			_steps_on(false)
			_play("alert")
			var to := _alert_target - position
			to.y = 0.0
			if to.length() > 0.1:
				rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 4.0))
		"idle":
			_steps_on(false)
			_wait -= delta
			if _wait <= 0.0 or alarm:
				_state = "walk"
		_:
			_walk(delta)


func _walk(delta: float) -> void:
	_turn_t -= delta
	if _turn_t <= 0.0 and not alarm:
		_turn_t = _rng.randf_range(14.0, 26.0)
		_state = "look"
		_wait = 1.8
		_look_rot = rotation.y + PI
		return
	var target: Vector3 = path[(_idx + 1) % path.size()]
	var to := target - position
	to.y = 0.0
	if to.length() < 0.08:
		_idx = (_idx + 1) % path.size()
		# توقّف قصير عند بعض الزوايا
		if not alarm and _rng.randf() < 0.35:
			_state = "idle"
			_wait = _rng.randf_range(3.0, 5.0)
			_play("idle_sweat" if _rng.randf() < 0.5 else "idle_bugs")
		return
	_play("walk")
	_steps_on(true)
	var step := to.normalized() * speed * delta
	position += step if step.length() < to.length() else to
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 5.0))
	if _anim:
		_anim.speed_scale = clampf(speed / 1.25, 0.7, 1.8)


func _remote_update(delta: float) -> void:
	var k := minf(1.0, delta * 10.0)
	var moving := position.distance_to(_r_pos) > 0.02
	position = position.lerp(_r_pos, k)
	rotation.y = lerp_angle(rotation.y, _r_rot, k)
	_state = _r_state
	match _r_state:
		"idle":
			_play("idle_sweat")
		"alert", "look", "search":
			_play("alert")
		"attack":
			_play("attack", 0.15)
		_:
			_play("walk")
	if _anim:
		_anim.speed_scale = 2.1 if _r_state == "chase" else 1.0
	_steps_on(moving and (_r_state == "walk" or _r_state == "chase"))
	_light.light_color = Color(1.0, 0.45, 0.35) if _r_state == "chase" or alarm else Color(1.0, 0.92, 0.7)


func _chase(delta: float) -> void:
	if _target == null:
		_state = "walk"
		return
	var to := _target.global_position - position
	to.y = 0.0
	_play("walk", 0.15)
	_steps_on(true)
	if _anim:
		_anim.speed_scale = 2.1
	if to.length() > 0.9:
		_move_safe(to.normalized() * CHASE_SPEED * (1.2 if alarm else 1.0) * delta)
	if to.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 8.0))
	# فقد أثره: 3 ثوانٍ دون أن يراه ← يبحث قليلاً ثم يعود إلى دوريّته
	_lost = 0.0 if saw else _lost + delta
	if _lost > 3.0:
		_state = "search"
		_wait = 3.0


## يتحرّك دون اختراق الصناديق والجدران، ودون الخروج من غرفته.
func _move_safe(step: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var sh := SphereShape3D.new()
	sh.radius = 0.3
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	if _target is CollisionObject3D:
		q.exclude = [(_target as CollisionObject3D).get_rid()]
	for cand in [step, Vector3(step.x, 0, 0), Vector3(0, 0, step.z)]:
		var np: Vector3 = position + cand
		if bounds.size != Vector2.ZERO:
			np.x = clampf(np.x, bounds.position.x, bounds.end.x)
			np.z = clampf(np.z, bounds.position.y, bounds.end.y)
		q.transform = Transform3D(Basis(), np + Vector3(0, 0.9, 0))
		if space.intersect_shape(q, 1).is_empty():
			position = np
			return


func _steps_on(on: bool) -> void:
	if _steps.stream == null:
		return
	if on and not _steps.playing:
		_steps.play()
	elif not on and _steps.playing:
		_steps.stop()


## هل يرى الحارس [player]؟ مخروط أمامي + لا جدار بينهما.
func sees(player: Node3D, space: PhysicsDirectSpaceState3D) -> bool:
	var eye := global_position + Vector3(0, 1.6, 0)
	var low: bool = player.get("crouch") == true
	var tgt := player.global_position + Vector3(0, 0.7 if low else 1.2, 0)
	var d := tgt - eye
	# المنحني أصعب رؤيةً (إلا عند الإنذار)، وحدّة البصر تختلف حسب المرحلة
	var reach := RANGE * sight * (1.25 if alarm else (0.72 if low else 1.0))
	if d.length() > reach:
		return false
	var fwd := -global_transform.basis.z
	if fwd.dot(d.normalized()) < cos(deg_to_rad(HALF_ANGLE)):
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, tgt)
	var hit := space.intersect_ray(q)
	return hit.is_empty() or hit.get("collider") == player
