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


func setup(points: Array, spd: float) -> void:
	path = points
	speed = spd
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
	if _anim == null or skel == null:
		return model
	var lib := AnimationLibrary.new()
	var root := _anim.get_node(_anim.root_node)
	var skel_path := str(root.get_path_to(skel))
	for key in CLIPS:
		var a := _first_anim(str(CLIPS[key]))
		if a == null:
			continue
		a = a.duplicate(true)
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
		for n in ap.get_animation_list():
			if str(n) != "RESET":
				out = ap.get_animation(n)
				break
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


func attack() -> void:
	_state = "attack"
	_wait = 1.6
	_play("attack", 0.15)


func _process(delta: float) -> void:
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
	var tgt := player.global_position + Vector3(0, 1.2, 0)
	var d := tgt - eye
	var reach := RANGE * (1.25 if alarm else 1.0)
	if d.length() > reach:
		return false
	var fwd := -global_transform.basis.z
	if fwd.dot(d.normalized()) < cos(deg_to_rad(HALF_ANGLE)):
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, tgt)
	var hit := space.intersect_ray(q)
	return hit.is_empty() or hit.get("collider") == player
