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
var struggle := false
var hits: Array = []
var rig: Node3D
var head: Node3D
var legs: Array = []
var anim_t := 0.0
var model: Node3D
var model_pivot: Node3D
var skel: Skeleton3D

const MODEL_PATH := "res://models/sheep.glb"
const MODEL_HEIGHT := 1.35
const MODEL_YAW := PI  # الموديل يشوف لـ +Z، واللعبة تعتبر القدام -Z


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
	if ResourceLoader.exists(MODEL_PATH):
		var ps := load(MODEL_PATH) as PackedScene
		if ps:
			model = ps.instantiate() as Node3D
			if model:
				model_pivot = Node3D.new()
				rig.add_child(model_pivot)
				model_pivot.add_child(model)
				_fit_model()
				return
	_build_procedural()


## يحسب حجم الموديل ويضبطو: علوه ~1.35م، في الوسط، والرجلين فوق الأرض.
func _fit_model() -> void:
	model_pivot.rotation.y = MODEL_YAW
	var box := _model_aabb()
	if box.size.y > 0.001:
		var k := MODEL_HEIGHT / box.size.y
		model.scale = Vector3.ONE * k
	box = _model_aabb()
	model_pivot.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	skel = _find_skeleton(model)
	if skel:
		_setup_bones()


# ---------- العظام ----------
# كل عظم نحركو حول محور ثابت تاع الخروف (جنب = X، فوق = Y، قدام = Z)
# ونحولو لمحور العظم المحلي مرة وحدة في البداية.

var bones := {}       # اسم -> رقم العظم
var bone_axes := {}   # "اسم:محور" -> المحور المحلي
var bone_rest := {}   # اسم -> دوران الراحة


func _setup_bones() -> void:
	var to_skel := skel.global_transform.basis.orthonormalized().inverse() * model.global_transform.basis.orthonormalized()
	var axes := {"x": (to_skel * Vector3.RIGHT).normalized(), "y": (to_skel * Vector3.UP).normalized(), "z": (to_skel * Vector3.BACK).normalized()}
	var names: Array[String] = ["LeftArm", "LeftForeArm", "RightArm", "RightForeArm", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg",
		"Neck", "Head", "Jaw", "Spine1", "Tail1", "Tail2", "Tail3"]
	for n in names:
		var i := skel.find_bone(n)
		if i < 0:
			continue
		bones[n] = i
		bone_rest[n] = skel.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
		var par := skel.get_bone_parent(i)
		var pg := Basis()
		if par >= 0:
			pg = skel.get_bone_global_rest(par).basis.orthonormalized()
		for k in axes:
			bone_axes[n + ":" + k] = (pg.inverse() * axes[k]).normalized()


## يدوّر العظم بزاوية حول محور الخروف (x/y/z)، أو يرجعو للراحة كي تكون الزاوية 0.
func _bone(n: String, axis: String, ang: float) -> void:
	if not bones.has(n):
		return
	var rest: Quaternion = bone_rest[n]
	var la: Vector3 = bone_axes[n + ":" + axis]
	skel.set_bone_pose_rotation(bones[n], Quaternion(la, ang) * rest)


func _bone2(n: String, ax: String, a: float, ay: String, b: float) -> void:
	if not bones.has(n):
		return
	var rest: Quaternion = bone_rest[n]
	var q := Quaternion(bone_axes[n + ":" + ax], a) * Quaternion(bone_axes[n + ":" + ay], b)
	skel.set_bone_pose_rotation(bones[n], q * rest)


var jaw_t := 0.0


func bleat() -> void:
	jaw_t = 0.5


func _animate_bones(delta: float, spd: float) -> void:
	var amp := clampf(spd / WALK, 0.0, 1.4)
	var air := not is_on_floor()
	var ph := anim_t
	if struggle:
		# يتخبط: رجلين بزربة والجسم يرتعش
		ph = Time.get_ticks_msec() * 0.024
		amp = 1.3
		air = false
		model_pivot.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.09
	# الرجلين: كل زوج متقاطع (قدّام يسار + لور يمين) مع بعضاهم
	var swing := 0.55 * minf(amp, 1.0) + 0.15 * maxf(amp - 1.0, 0.0)
	var front_l := sin(ph) * swing
	var front_r := sin(ph + PI) * swing
	var knee_l := maxf(0.0, sin(ph + 0.6)) * 0.8 * minf(amp, 1.0)
	var knee_r := maxf(0.0, sin(ph + PI + 0.6)) * 0.8 * minf(amp, 1.0)
	if air:
		# في النقزة: القدام يتمدو لقدام واللور لور
		front_l = -0.6
		front_r = -0.6
		knee_l = 0.9
		knee_r = 0.9
	if frozen and not struggle:
		front_l = 0.9
		front_r = -0.9
		knee_l = 0.2
		knee_r = 0.2
	_bone("LeftArm", "x", -front_l)
	_bone("RightArm", "x", -front_r)
	_bone("LeftForeArm", "x", knee_l)
	_bone("RightForeArm", "x", knee_r)
	var hind_l := front_r
	var hind_r := front_l
	if air:
		hind_l = 0.6
		hind_r = 0.6
	_bone("LeftUpLeg", "x", -hind_l)
	_bone("RightUpLeg", "x", -hind_r)
	_bone("LeftLeg", "x", -(knee_r if not air else 0.9) * 0.8)
	_bone("RightLeg", "x", -(knee_l if not air else 0.9) * 0.8)
	# الراس والرقبة: يهبطو في النطحة، ويتهزو شوية في المشي
	var head_down := 0.0
	if dash_t > 0.0:
		head_down = 0.55
	elif frozen:
		head_down = -0.3 if not struggle else -0.15 + sin(Time.get_ticks_msec() * 0.02) * 0.25
	var nod := sin(ph * 2.0) * 0.06 * minf(amp, 1.0)
	head_pitch = lerpf(head_pitch, head_down, clampf(delta * 18.0, 0.0, 1.0))
	_bone("Neck", "x", head_pitch * 0.6 + nod)
	_bone("Head", "x", head_pitch * 0.5)
	_bone("Spine1", "x", -0.08 * minf(amp, 1.0) if not air else -0.15)
	# الفك: يتحل كي يبعبع
	jaw_t = maxf(jaw_t - delta, 0.0)
	_bone("Jaw", "x", 0.35 if (jaw_t > 0.0 or (frozen and not struggle)) else 0.0)
	# الذيل: يتهز، وبزربة كي يجري
	var wag := sin(Time.get_ticks_msec() * 0.001 * (8.0 + amp * 10.0)) * (0.25 + 0.35 * minf(amp, 1.0))
	_bone("Tail1", "y", wag)
	_bone("Tail2", "y", wag * 0.8)
	_bone("Tail3", "y", wag * 0.6)


var head_pitch := 0.0


func _model_aabb() -> AABB:
	var inv := rig.global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for mi in _meshes(model):
		var a: AABB = (inv * mi.global_transform) * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


func _meshes(n: Node) -> Array:
	var res: Array = []
	if n is MeshInstance3D:
		res.append(n)
	for c in n.get_children():
		res.append_array(_meshes(c))
	return res


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null


## وصف الموديل في السجل (للمراجعة): الحجم والعظام ومواقعها.
func describe_model() -> void:
	if model == null:
		print("MODEL none (procedural sheep)")
		return
	var box := _model_aabb()
	print("MODEL aabb pos=%s size=%s meshes=%d" % [box.position, box.size, _meshes(model).size()])
	if skel == null:
		print("MODEL no skeleton")
		return
	var inv := rig.global_transform.affine_inverse() * skel.global_transform
	print("MODEL bones=%d" % skel.get_bone_count())
	for i in skel.get_bone_count():
		var o: Vector3 = inv * skel.get_bone_global_rest(i).origin
		print("MODEL bone %d %s parent=%d at=(%.2f, %.2f, %.2f)" % [i, skel.get_bone_name(i), skel.get_bone_parent(i), o.x, o.y, o.z])


func _build_procedural() -> void:
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
	struggle = false
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


## مشدود: ما يتحركش، بصح يتخبط برجليه.
func grabbed() -> void:
	frozen = true
	struggle = true
	dash_t = 0.0
	velocity = Vector3.ZERO


func release() -> void:
	frozen = false
	struggle = false
	if rig:
		rig.scale = Vector3.ONE
	if model_pivot:
		model_pivot.rotation.z = 0.0


func caught() -> void:
	struggle = false
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
		_animate(delta)
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
	if head:
		if dash_t > 0.0:
			head.rotation.x = lerpf(head.rotation.x, -0.6, 0.5)
		else:
			head.rotation.x = lerpf(head.rotation.x, sin(anim_t * 0.5) * 0.05, 0.2)
	elif model_pivot:
		# الجسم يميل شوية لقدام في الجري والنطحة، والعظام تتحرك
		var pitch := -0.08 if dash_t > 0.0 else -0.03 * amp
		model_pivot.rotation.x = lerpf(model_pivot.rotation.x, pitch, 0.3)
		model_pivot.rotation.z = sin(anim_t * 0.5) * 0.03 * amp
		if skel:
			_animate_bones(delta, spd)
	if not is_on_floor():
		rig.rotation.x = lerpf(rig.rotation.x, 0.25 if velocity.y > 0.0 else -0.15, 0.2)
	else:
		rig.rotation.x = lerpf(rig.rotation.x, 0.0, 0.3)
