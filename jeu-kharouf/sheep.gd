extends CharacterBody3D
## الخروف: مشي، جري، قفز ونطحة — مع حركات مضحكة.

const B := preload("res://build.gd")
const WALK := 6.0
const SPRINT := 9.5
const DASH := 15.0
const GRAV := 22.0
const JUMP := 7.5

var game
var move_input := Vector2.ZERO
var input_override := Vector2.ZERO
var use_override := false
var sprinting := false
var want_jump := false
var want_butt := false
var energy := 100.0
var facing := Vector3(0, 0, -1)
var dash_t := 0.0
var butt_cd := 0.0
var frozen := false
var hits: Array = []
var rig: Node3D
var head: Node3D
var legs: Array = []
var anim_t := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.3
	cs.shape = cap
	cs.position = Vector3(0, 0.65, 0)
	add_child(cs)
	_build_rig()


func _build_rig() -> void:
	rig = Node3D.new()
	add_child(rig)
	var wool := Color("f6f3ec")
	var face := Color("3a3330")
	var horn := Color("a8834f")
	B.put(rig, B.sphere(0.55, wool, 12), Vector3(0, 0.9, 0.05), Vector3.ZERO, Vector3(1.0, 0.85, 1.3))
	var puffs: Array[Vector3] = [Vector3(0.3, 1.25, -0.2), Vector3(-0.3, 1.25, -0.15), Vector3(0.25, 1.2, 0.4),
		Vector3(-0.28, 1.22, 0.38), Vector3(0, 1.32, 0.1), Vector3(0.42, 0.95, 0.15), Vector3(-0.42, 0.95, 0.1)]
	for p in puffs:
		B.put(rig, B.sphere(0.28, wool, 8), p)
	B.put(rig, B.sphere(0.16, wool, 8), Vector3(0, 1.0, 0.75))
	var hips: Array[Vector3] = [Vector3(0.25, 0.55, -0.38), Vector3(-0.25, 0.55, -0.38), Vector3(0.25, 0.55, 0.42), Vector3(-0.25, 0.55, 0.42)]
	for lp in hips:
		var pv := B.pivot(rig, lp)
		B.put(pv, B.cyl(0.07, 0.06, 0.55, face, 6), Vector3(0, -0.27, 0))
		B.put(pv, B.box(Vector3(0.14, 0.08, 0.16), Color("221e1c")), Vector3(0, -0.54, -0.02))
		legs.append(pv)
	head = B.pivot(rig, Vector3(0, 1.08, -0.68))
	B.put(head, B.sphere(0.3, face, 10), Vector3(0, 0, -0.08), Vector3.ZERO, Vector3(0.85, 0.9, 1.2))
	B.put(head, B.sphere(0.2, wool, 8), Vector3(0, 0.24, 0.02))
	B.put(head, B.box(Vector3(0.28, 0.06, 0.12), face), Vector3(0.3, 0.06, 0.02), Vector3(0, 0, -25))
	B.put(head, B.box(Vector3(0.28, 0.06, 0.12), face), Vector3(-0.3, 0.06, 0.02), Vector3(0, 0, 25))
	B.put(head, B.torus(0.07, 0.16, horn), Vector3(0.24, 0.12, 0.05), Vector3(0, 0, 90))
	B.put(head, B.torus(0.07, 0.16, horn), Vector3(-0.24, 0.12, 0.05), Vector3(0, 0, 90))
	for s in [1.0, -1.0]:
		B.put(head, B.sphere(0.1, Color.WHITE, 8), Vector3(0.13 * s, 0.1, -0.3))
		B.put(head, B.sphere(0.05, Color.BLACK, 6), Vector3(0.14 * s, 0.1, -0.39))
	B.put(head, B.sphere(0.06, Color("d98b8b"), 6), Vector3(0, -0.08, -0.43))


func reset_to(p: Vector3) -> void:
	global_position = p
	velocity = Vector3.ZERO
	energy = 100.0
	dash_t = 0.0
	butt_cd = 0.0
	frozen = false
	facing = Vector3(0, 0, -1)
	rotation = Vector3.ZERO
	move_input = Vector2.ZERO
	use_override = false
	want_jump = false
	want_butt = false
	sprinting = false
	if rig:
		rig.scale = Vector3.ONE
		rig.rotation = Vector3.ZERO
		rig.position = Vector3.ZERO


func is_dashing() -> bool:
	return dash_t > 0.0


func caught() -> void:
	frozen = true
	dash_t = 0.0
	velocity = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(rig, "scale", Vector3(1.35, 0.55, 1.35), 0.25).set_trans(Tween.TRANS_BACK)


func _physics_process(delta: float) -> void:
	if frozen:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAV * delta
		move_and_slide()
		return
	var active: bool = game != null and game.is_playing()
	var inp: Vector2 = input_override if use_override else move_input
	if not active:
		inp = Vector2.ZERO
		want_jump = false
		want_butt = false
	var dir := Vector3(inp.x, 0.0, inp.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var moving := dir.length() > 0.1
	var spd := WALK
	if sprinting and moving and energy > 1.0:
		spd = SPRINT
		energy -= 28.0 * delta
	else:
		energy += 5.0 * delta
	energy = clampf(energy, 0.0, 100.0)
	butt_cd -= delta
	if want_butt and butt_cd <= 0.0 and energy >= 15.0 and dash_t <= 0.0:
		energy -= 15.0
		dash_t = 0.28
		butt_cd = 0.55
		hits.clear()
		if moving:
			facing = dir.normalized()
		game.on_butt()
	want_butt = false
	var hv := dir * spd
	if dash_t > 0.0:
		dash_t -= delta
		hv = facing * DASH
		_dash_hits()
	elif moving:
		facing = dir.normalized()
	var cur := Vector3(velocity.x, 0.0, velocity.z)
	cur = cur.lerp(hv, clampf(delta * (30.0 if dash_t > 0.0 else 12.0), 0.0, 1.0))
	velocity.x = cur.x
	velocity.z = cur.z
	if is_on_floor():
		if want_jump:
			velocity.y = JUMP
			game.on_jump()
	else:
		velocity.y -= GRAV * delta
	want_jump = false
	move_and_slide()
	_push_props()
	rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), clampf(delta * 14.0, 0.0, 1.0))
	_animate(delta)


func _dash_hits() -> void:
	for c in game.chasers:
		if c in hits or not c.can_be_hit():
			continue
		var to: Vector3 = c.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist < 1.9 and (dist < 0.6 or facing.dot(to / maxf(dist, 0.001)) > 0.2):
			hits.append(c)
			c.knock(facing, 1.0)
			game.on_knock_chaser(c, false)
	for p in game.world.props:
		if p in hits:
			continue
		var tp: Vector3 = p.global_position - global_position
		tp.y = 0.0
		var pd := tp.length()
		if pd < 1.7 and (pd < 0.5 or facing.dot(tp / maxf(pd, 0.001)) > 0.1):
			hits.append(p)
			p.sleeping = false
			p.apply_central_impulse(facing * 6.0 + Vector3.UP * 3.5)
			p.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.6)
			game.on_prop_hit(p)


func _push_props() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var rb := col.get_collider() as RigidBody3D
		if rb:
			rb.apply_central_impulse(-col.get_normal() * (2.5 if sprinting else 1.2))
			if sprinting or dash_t > 0.0:
				game.on_prop_hit(rb)


func _animate(delta: float) -> void:
	var spd := Vector2(velocity.x, velocity.z).length()
	anim_t += delta * (3.0 + spd * 2.2)
	var amp := clampf(spd / WALK, 0.0, 1.0) * 0.75
	for i in legs.size():
		var ph := 0.0 if (i == 0 or i == 3) else PI
		legs[i].rotation.x = sin(anim_t + ph) * amp
	rig.position.y = absf(sin(anim_t)) * 0.08 * amp
	if dash_t > 0.0:
		head.rotation.x = lerpf(head.rotation.x, -0.6, 0.5)
	else:
		head.rotation.x = lerpf(head.rotation.x, sin(anim_t * 0.5) * 0.05, 0.2)
	if not is_on_floor():
		rig.rotation.x = lerpf(rig.rotation.x, 0.25 if velocity.y > 0.0 else -0.15, 0.2)
	else:
		rig.rotation.x = lerpf(rig.rotation.x, 0.0, 0.3)
