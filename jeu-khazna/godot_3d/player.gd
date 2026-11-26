# اللاعب. العميل: الكاميرا خلف كتفه (Third person) وجسم حقيقي يتحرّك (agent_body.gd)،
# يمشي ويركض وينحني في 4 اتّجاهات. المحلّل: منظور العينين في غرفته.
extends CharacterBody3D

const SPEED := 3.0
const RUN_SPEED := 5.6
const EYE_STAND := 1.62
const EYE_CROUCH := 0.98
const CAM_DIST := 3.7
const CAM_SIDE := 0.5
const CAM_UP := 0.45

var third := false # كاميرا خلف الكتف (العميل)
var cam: Camera3D
var flash: SpotLight3D
var body # agent_body.gd
var yaw := 0.0
var pitch := 0.0
var move_input := Vector2.ZERO # من العصا: x جانبي، y أمام
var look_delta := Vector2.ZERO
var sens := 1.0
var active := true
var locked := false # أمام قرص الخزنة: لا مشي، والكاميرا يحرّكها المشهد
var crouch := false
var running := false
var dragging := false # يسحب جسم حارس: أبطأ
var face := 0.0 # اتّجاه الجسم (قد يختلف عن الكاميرا)
var _bob := 0.0
var _eye := 1.62
var _col: CollisionShape3D
var _cap: CapsuleShape3D
var _pivot: Node3D
var _mv := Vector2.ZERO # حركة العصا بعد التنعيم
var _cam_d := 3.7
var _look_t := 0.0 # بعد نظر يدوي بالإصبع: الكاميرا تنتظر ثم تعود خلف الظهر
var turning := 0.0
const TURN_SPEED := 2.5


func _ready() -> void:
	_col = CollisionShape3D.new()
	_cap = CapsuleShape3D.new()
	_cap.radius = 0.3
	_cap.height = 1.7
	_col.shape = _cap
	_col.position.y = 0.85
	add_child(_col)

	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 1.55, 0)
	add_child(_pivot)
	cam = Camera3D.new()
	cam.fov = 70 if third else 72
	cam.near = 0.05
	cam.far = 70
	if third:
		_pivot.add_child(cam)
		cam.position = Vector3(CAM_SIDE, CAM_UP, CAM_DIST)
		pitch = -0.22
		body = preload("res://agent_body.gd").new()
		add_child(body)
	else:
		cam.position = Vector3(0, 1.62, 0)
		add_child(cam)
	cam.current = true

	flash = SpotLight3D.new()
	flash.light_color = Color(1.0, 0.94, 0.82)
	flash.light_energy = 2.2 if third else 3.2
	flash.spot_range = 14.0
	flash.spot_angle = 30.0
	flash.spot_attenuation = 0.9
	flash.shadow_enabled = true
	if third:
		# المصباح على صدر الشخصية، ينظر حيث تنظر الكاميرا
		flash.position = Vector3(0.15, 1.35, -0.25)
		add_child(flash)
	else:
		flash.position = Vector3(0.18, -0.15, 0.05)
		cam.add_child(flash)


func _unhandled_input(event) -> void:
	if OS.has_feature("mobile") or not active:
		return
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_C or event.keycode == KEY_CTRL):
		set_crouch(not crouch)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_delta += event.relative * 0.6


func _keys() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP):
		v.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y -= 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1
	return v


func set_crouch(v: bool) -> void:
	crouch = v
	if v:
		running = false
	_cap.height = 1.1 if v else 1.7
	_col.position.y = 0.55 if v else 0.85


func set_running(v: bool) -> void:
	running = v and not crouch and not dragging
	if running:
		set_crouch(false)


func set_active(v: bool) -> void:
	active = v
	cam.current = v
	flash.visible = v
	move_input = Vector2.ZERO
	look_delta = Vector2.ZERO


## إعادة الكاميرا إلى مكانها خلف الكتف (بعد القرص أو الإمساك).
func reset_cam() -> void:
	locked = false
	if third:
		cam.position = Vector3(CAM_SIDE, CAM_UP, CAM_DIST)
		cam.rotation = Vector3.ZERO
	else:
		cam.position = Vector3(0, EYE_STAND, 0)
		cam.rotation = Vector3(pitch, 0, 0)


func cam_ok() -> bool:
	if third:
		return not locked and cam.get_parent() == _pivot and cam.position.z > 0.3
	return not locked and cam.position.distance_to(Vector3(0, EYE_STAND, 0)) < 0.1


func _physics_process(delta: float) -> void:
	if not active or locked:
		velocity = Vector3.ZERO
		if body:
			body.drive(Vector3.ZERO, crouch, false)
		return
	var raw := move_input + _keys()
	if raw.length() > 1.0:
		raw = raw.normalized()
	if raw.length() < 0.14:
		raw = Vector2.ZERO # منطقة ميتة: لا ارتجاف
	_mv = _mv.lerp(raw, minf(1.0, delta * 11.0))
	var mv := _mv
	if not OS.has_feature("mobile"):
		set_running(Input.is_key_pressed(KEY_SHIFT) or running and mv.length() > 0.1)

	var applied := look_delta * minf(1.0, delta * 18.0)
	look_delta -= applied
	if applied.length() > 0.5:
		_look_t = 1.3
	var k_look := 0.0036 if third else 0.0042
	yaw -= applied.x * k_look * sens
	pitch = clampf(pitch - applied.y * k_look * sens, -0.95 if third else -1.25, 0.45 if third else 1.25)

	var basis_y := Basis(Vector3.UP, yaw)
	var fwd := -basis_y.z
	var right := basis_y.x
	var dir := fwd * mv.y + right * mv.x
	if third:
		# تحكّم بالعصا وحدها: أعلى/أسفل = أمام/خلف، يمين/يسار = يدور الجسم والكاميرا تتبعه
		turning = mv.x
		face -= mv.x * TURN_SPEED * (0.75 + 0.25 * absf(mv.y)) * delta
		var ff := -Basis(Vector3.UP, face).z
		dir = ff * mv.y * (0.6 if mv.y < 0.0 else 1.0)
		_look_t = maxf(0.0, _look_t - delta)
		if _look_t <= 0.0:
			yaw = lerp_angle(yaw, face, minf(1.0, delta * 5.0))
	var speed := SPEED
	if running and mv.length() > 0.3:
		speed = RUN_SPEED
	if crouch:
		speed *= 0.5
	if dragging:
		speed *= 0.45
	if not third and mv.y < -0.3:
		speed *= 0.75
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 9.8 * delta
	move_and_slide()

	if third:
		_third_update(delta, dir)
	else:
		rotation.y = yaw
		var moving := Vector2(velocity.x, velocity.z).length()
		if moving > 0.2:
			_bob += delta * moving * 2.6
		else:
			_bob = lerpf(_bob, round(_bob / PI) * PI, delta * 6.0)
		_eye = lerpf(_eye, EYE_CROUCH if crouch else EYE_STAND, minf(1.0, delta * 10.0))
		cam.position.y = _eye + sin(_bob * 2.0) * (0.02 if crouch else 0.035)
		cam.position.x = cos(_bob) * 0.025
		cam.rotation.x = pitch
		cam.rotation.z = cos(_bob) * 0.006


func _third_update(delta: float, dir: Vector3) -> void:
	# الجسم: واقفاً يلتفت نحو اتّجاه المشي؛ منحنياً يبقى نحو الكاميرا ويمشي جانبياً (حركات الاتّجاهات الأربعة)
	var flat := Vector2(velocity.x, velocity.z)
	if body:
		# عند السحب يلتفت الجسم نحو الحارس المجرور ويمشي إلى الخلف
		var vis := face + (PI if dragging else 0.0)
		body.rotation.y = lerp_angle(body.rotation.y, vis, minf(1.0, delta * 12.0))
		var local := Basis(Vector3.UP, vis).inverse() * Vector3(velocity.x, 0, velocity.z)
		body.drive(local, crouch, running and flat.length() > 3.5, dragging, turning)
	flash.rotation = Vector3(pitch * 0.6, yaw, 0)
	# الكاميرا خلف الكتف: تدور بنعومة، ولا تدخل الجدران (ثلاثة أشعّة)، تقترب بسرعة وتبتعد ببطء
	_pivot.rotation = Vector3(pitch, yaw, 0)
	_pivot.position.y = lerpf(_pivot.position.y, 1.1 if crouch else 1.6, minf(1.0, delta * 8.0))
	var from := _pivot.global_position
	var space := get_world_3d().direct_space_state
	var dist := CAM_DIST
	for side in [0.0, -0.3, 0.3]:
		var want := _pivot.global_transform * Vector3(CAM_SIDE + side, CAM_UP + absf(side) * 0.2, CAM_DIST)
		var q := PhysicsRayQueryParameters3D.create(from, want)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			dist = minf(dist, maxf(0.55, from.distance_to(hit.position) - 0.35))
	_cam_d = lerpf(_cam_d, dist, minf(1.0, delta * (22.0 if dist < _cam_d else 4.0)))
	var k := _cam_d / CAM_DIST
	cam.position = Vector3(CAM_SIDE * k, CAM_UP * k, _cam_d)
	cam.rotation = Vector3.ZERO


## هل الكاميرا داخل جسم صلب؟ (للاختبار الآلي)
func cam_inside_wall() -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = cam.global_position
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_point(q, 1).is_empty()
