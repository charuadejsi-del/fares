# الحارس: نموذج ثلاثي الأبعاد يمشي في مسار، يحمل مصباحاً بظلال حقيقية، ويرى ضمن مخروط أمامه.
extends Node3D

var path: Array = []
var speed := 1.25
var alarm := false
var _idx := 0
var _anim: AnimationPlayer
var _light: SpotLight3D

const RANGE := 7.5
const HALF_ANGLE := 32.0


func setup(points: Array, spd: float) -> void:
	path = points
	speed = spd
	position = points[0]
	if points.size() > 1:
		var d: Vector3 = points[1] - points[0]
		rotation.y = atan2(-d.x, -d.z)


func _ready() -> void:
	var model: Node3D = null
	if ResourceLoader.exists("res://models/CesiumMan.glb"):
		var scn = load("res://models/CesiumMan.glb")
		if scn is PackedScene:
			model = scn.instantiate() as Node3D
	if model:
		# نماذج glTF تنظر نحو +Z؛ نديرها لتنظر نحو −Z (أمام الحارس)
		model.rotation_degrees.y = 180
		model.scale = Vector3.ONE * 1.15
		add_child(model)
		_anim = _find_anim(model)
		if _anim and _anim.get_animation_list().size() > 0:
			var a: StringName = _anim.get_animation_list()[0]
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
			_anim.play(a)
	else:
		# بديل بسيط إن لم يتوفّر النموذج
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.28
		cap.height = 1.75
		body.mesh = cap
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.13, 0.18, 0.3)
		body.material_override = m
		body.position.y = 0.88
		add_child(body)

	_light = SpotLight3D.new()
	_light.position = Vector3(0.22, 1.25, -0.35)
	_light.rotation_degrees.x = -12
	_light.light_color = Color(1.0, 0.92, 0.7)
	_light.light_energy = 5.0
	_light.spot_range = 9.0
	_light.spot_angle = HALF_ANGLE
	_light.shadow_enabled = true
	add_child(_light)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var f := _find_anim(c)
		if f:
			return f
	return null


func _process(delta: float) -> void:
	if path.size() < 2:
		return
	var target: Vector3 = path[(_idx + 1) % path.size()]
	var to := target - position
	to.y = 0.0
	if to.length() < 0.08:
		_idx = (_idx + 1) % path.size()
		return
	var step := to.normalized() * speed * delta
	position += step if step.length() < to.length() else to
	var want := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * 5.0))
	if _anim:
		_anim.speed_scale = speed / 1.25
	if alarm:
		_light.light_color = Color(1.0, 0.55, 0.45)


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
