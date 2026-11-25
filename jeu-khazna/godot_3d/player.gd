# العميل: منظور الشخص الأول، مصباح يدوي بظلال حقيقية، واهتزاز خفيف مع المشي.
extends CharacterBody3D

const SPEED := 3.2

var cam: Camera3D
var flash: SpotLight3D
var yaw := 0.0
var pitch := 0.0
var move_input := Vector2.ZERO # من العصا: x جانبي، y أمام
var look_delta := Vector2.ZERO # من سحب الإصبع أو الفأرة (يُطبَّق بنعومة)
var sens := 1.0
var _bob := 0.0


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)

	cam = Camera3D.new()
	cam.position = Vector3(0, 1.62, 0)
	cam.fov = 72
	cam.near = 0.05
	cam.far = 60
	add_child(cam)
	cam.current = true

	flash = SpotLight3D.new()
	flash.position = Vector3(0.18, -0.15, 0.05)
	flash.light_color = Color(1.0, 0.94, 0.82)
	flash.light_energy = 3.2
	flash.spot_range = 15.0
	flash.spot_angle = 27.0
	flash.spot_attenuation = 0.9
	flash.shadow_enabled = true
	cam.add_child(flash)


func _unhandled_input(event) -> void:
	if OS.has_feature("mobile"):
		return
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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


func _physics_process(delta: float) -> void:
	var mv := move_input + _keys()
	if mv.length() > 1.0:
		mv = mv.normalized()

	# الالتفات بنعومة
	var applied := look_delta * minf(1.0, delta * 18.0)
	look_delta -= applied
	yaw -= applied.x * 0.0042 * sens
	pitch = clampf(pitch - applied.y * 0.0042 * sens, -1.25, 1.25)
	rotation.y = yaw

	var fwd := -transform.basis.z
	var right := transform.basis.x
	var dir := fwd * mv.y + right * mv.x
	var speed := SPEED * (0.75 if mv.y < -0.3 else 1.0)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 9.8 * delta
	move_and_slide()

	# اهتزاز الرأس والمصباح مع الخطوات
	var moving := Vector2(velocity.x, velocity.z).length()
	if moving > 0.2:
		_bob += delta * moving * 2.6
	else:
		_bob = lerpf(_bob, round(_bob / PI) * PI, delta * 6.0)
	cam.position.y = 1.62 + sin(_bob * 2.0) * 0.035
	cam.position.x = cos(_bob) * 0.025
	cam.rotation.x = pitch
	cam.rotation.z = cos(_bob) * 0.006
