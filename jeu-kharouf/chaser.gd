extends CharacterBody3D
## المطاردين: عمي السعيد (بطيء وما يحبسش) والدراري (سراع بصح يعياو).

const B := preload("res://build.gd")
enum S { RUN, TIRED, KNOCKED, DOWN, GETUP, PILE, WINDUP, DIVE }
const GRAV := 22.0
const SAID_LINES := ["حبسوووه!", "أرواح هنا يا الخروف!", "راني جاي!", "الخروف هرب!!"]
const KID_LINES := ["هههه شدّو!", "راهو هنا!", "جيبوووه!"]
const OUCH := ["آآآي!", "يا ويلي!", "وووي!", "أمّا!"]

var kind := "said"
var game
var font: Font
var state: int = S.RUN
var speed := 5.2
var path: Array = []
var path_i := 0
var repath := 0.0
var t := 0.0
var stamina := 4.0
var anim_t := 0.0
var shout_cd := 2.0
var spin_axis := Vector3.RIGHT
var hit_list: Array = []
var rig: Node3D
var legs: Array = []
var arms: Array = []
var stars: Node3D
var bubble: Label3D
var bubble_t := 0.0
var pose_tw: Tween
var dive_cd := 3.0
var dive_target := Vector3.ZERO
var dive_min := 99.0
var ring: MeshInstance3D


func setup(k: String, g, f: Font) -> void:
	kind = k
	game = g
	font = f
	speed = 5.2 if k == "said" else 6.6
	stamina = randf_range(3.5, 5.0)
	shout_cd = randf_range(1.0, 3.0)
	dive_cd = randf_range(2.0, 4.0) if k == "kid" else randf_range(4.0, 6.0)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	floor_snap_length = 0.3
	var sc := 1.0 if kind == "said" else 0.78
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38 * sc
	cap.height = 1.75 * sc
	cs.shape = cap
	cs.position = Vector3(0, 0.875 * sc, 0)
	add_child(cs)
	rig = Node3D.new()
	add_child(rig)
	var model := Node3D.new()
	rig.add_child(model)
	model.scale = Vector3.ONE * sc
	if kind == "said":
		_build_said(model)
	else:
		_build_kid(model)
	stars = Node3D.new()
	add_child(stars)
	stars.position = Vector3(0, 0.9, -0.6)
	stars.visible = false
	for i in 3:
		var s := B.sphere(0.1, Color("ffd93b"), 6)
		s.material_override = B.mat(Color("ffd93b"), 1.5)
		B.put(stars, s, Vector3(cos(i * TAU / 3.0) * 0.45, 0, sin(i * TAU / 3.0) * 0.45))
	# الدائرة الحمرا وين راح يطيح (تبان وقت التحضير)
	ring = B.torus(0.55, 0.72, Color("ff3b30"))
	ring.material_override = B.mat(Color("ff3b30"), 1.2)
	add_child(ring)
	ring.top_level = true
	ring.visible = false
	bubble = B.label3d("", font, 64, Color.WHITE)
	add_child(bubble)
	bubble.position = Vector3(0, 2.5 * sc, 0)
	bubble.visible = false


func _build_said(m: Node3D) -> void:
	var robe := Color("7a5636")
	var skin := Color("d9a47c")
	for s in [-1.0, 1.0]:
		var pv := B.pivot(m, Vector3(0.14 * s, 0.5, 0))
		B.put(pv, B.cyl(0.08, 0.08, 0.5, Color("3b3b3b"), 6), Vector3(0, -0.25, 0))
		B.put(pv, B.box(Vector3(0.16, 0.08, 0.26), Color("2a2420")), Vector3(0, -0.48, -0.04))
		legs.append(pv)
	B.put(m, B.cyl(0.28, 0.42, 1.1, robe, 10), Vector3(0, 1.0, 0))
	B.put(m, B.cyl(0.22, 0.28, 0.2, robe.darkened(0.15), 10), Vector3(0, 1.5, 0))
	B.put(m, B.sphere(0.2, robe.darkened(0.1), 8), Vector3(0, 1.62, 0.16))
	B.put(m, B.sphere(0.21, skin, 10), Vector3(0, 1.76, 0))
	B.put(m, B.box(Vector3(0.26, 0.2, 0.12), Color("e8e4dc")), Vector3(0, 1.66, -0.15))
	B.put(m, B.cyl(0.15, 0.17, 0.13, Color("b3322c"), 10), Vector3(0, 1.95, 0))
	B.put(m, B.sphere(0.045, skin.darkened(0.1), 6), Vector3(0, 1.75, -0.21))
	for s in [-1.0, 1.0]:
		B.put(m, B.sphere(0.035, Color.BLACK, 6), Vector3(0.08 * s, 1.8, -0.19))
		var pv := B.pivot(m, Vector3(0.36 * s, 1.48, 0))
		B.put(pv, B.cyl(0.08, 0.09, 0.6, robe, 6), Vector3(0, -0.3, 0))
		B.put(pv, B.sphere(0.08, skin, 6), Vector3(0, -0.62, 0))
		arms.append(pv)


func _build_kid(m: Node3D) -> void:
	var shirts: Array[Color] = [Color("e84a3a"), Color("2e86de"), Color("f5b800"), Color("27ae60"), Color("8e44ad")]
	var shirt: Color = shirts[randi() % shirts.size()]
	var skin := Color("c98e66")
	for s in [-1.0, 1.0]:
		var pv := B.pivot(m, Vector3(0.12 * s, 0.75, 0))
		B.put(pv, B.cyl(0.07, 0.07, 0.7, skin, 6), Vector3(0, -0.35, 0))
		B.put(pv, B.box(Vector3(0.15, 0.1, 0.26), Color("f4f4f4")), Vector3(0, -0.7, -0.03))
		legs.append(pv)
	B.put(m, B.box(Vector3(0.42, 0.28, 0.26), Color("2c3e66")), Vector3(0, 0.82, 0))
	B.put(m, B.box(Vector3(0.46, 0.55, 0.28), shirt), Vector3(0, 1.22, 0))
	B.put(m, B.sphere(0.24, skin, 10), Vector3(0, 1.72, 0))
	B.put(m, B.sphere(0.245, Color("1e1a18"), 10), Vector3(0, 1.8, 0.03), Vector3.ZERO, Vector3(1, 0.65, 1))
	B.put(m, B.sphere(0.045, skin.darkened(0.1), 6), Vector3(0, 1.7, -0.24))
	for s in [-1.0, 1.0]:
		B.put(m, B.sphere(0.04, Color.BLACK, 6), Vector3(0.09 * s, 1.76, -0.21))
		var pv := B.pivot(m, Vector3(0.3 * s, 1.45, 0))
		B.put(pv, B.box(Vector3(0.14, 0.18, 0.16), shirt), Vector3(0, -0.06, 0))
		B.put(pv, B.cyl(0.055, 0.055, 0.45, skin, 6), Vector3(0, -0.33, 0))
		arms.append(pv)


# ---------- الحالة ----------

func can_be_hit() -> bool:
	return state == S.RUN or state == S.TIRED or state == S.GETUP or state == S.WINDUP or state == S.DIVE


func can_catch() -> bool:
	return state == S.RUN or state == S.TIRED or state == S.DIVE


func catch_radius() -> float:
	return 1.25 if state == S.DIVE else 1.05


func is_diving() -> bool:
	return state == S.WINDUP or state == S.DIVE


# ---------- الـ Dive ----------

func start_windup() -> void:
	if pose_tw:
		pose_tw.kill()
	state = S.WINDUP
	t = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	_aim()
	ring.visible = true
	pose_tw = create_tween()
	pose_tw.set_parallel(true)
	pose_tw.tween_property(rig, "rotation", Vector3(0.3, 0.0, 0.0), 0.2)
	for a in arms:
		pose_tw.tween_property(a, "rotation", Vector3(-0.9, 0.0, 0.0), 0.2)
	say("هاهو!")


func _windup_time() -> float:
	return 0.55 if kind == "said" else 0.42


func _aim() -> void:
	var sp: Vector3 = game.sheep.global_position
	var sv: Vector3 = game.sheep.velocity
	dive_target = Vector3(sp.x + sv.x * 0.2, 0.0, sp.z + sv.z * 0.2)
	ring.global_position = Vector3(dive_target.x, 0.06, dive_target.z)
	var to := dive_target - global_position
	to.y = 0.0
	if to.length() > 0.01:
		rotation.y = atan2(-to.x, -to.z)


func _launch() -> void:
	state = S.DIVE
	t = 0.0
	var to := dive_target - global_position
	to.y = 0.0
	var dist := maxf(to.length(), 0.5)
	var spd := 12.5 if kind == "kid" else 10.5
	var flight := clampf(dist / spd, 0.3, 0.6)
	var hv := to / dist * (dist / flight) * 1.15
	velocity = Vector3(hv.x, GRAV * flight * 0.5, hv.z)
	dive_min = 99.0
	if pose_tw:
		pose_tw.kill()
	pose_tw = create_tween()
	pose_tw.set_parallel(true)
	pose_tw.tween_property(rig, "rotation", Vector3(-1.35, 0.0, 0.0), 0.12)
	for a in arms:
		pose_tw.tween_property(a, "rotation", Vector3(1.6, 0.0, 0.0), 0.12)
	game.sfx.play("jump", -4.0, 0.6)


func _dive_land() -> void:
	ring.visible = false
	dive_cd = randf_range(3.5, 5.5) if kind == "kid" else randf_range(5.0, 7.0)
	state = S.DOWN
	t = 0.8
	if pose_tw:
		pose_tw.kill()
	pose_tw = create_tween()
	pose_tw.set_parallel(true)
	pose_tw.tween_property(rig, "rotation", Vector3(-PI / 2.0, 0.0, 0.0), 0.12)
	pose_tw.tween_property(rig, "position", Vector3(0, 0.28, 0), 0.12)
	game.sfx.play("hit", -6.0, 0.6)
	if game.is_playing() and dive_min < 2.2:
		game.on_dodge(self)


func is_knocked() -> bool:
	return state == S.KNOCKED or state == S.DOWN


## الكلام ما يبانش كتابة (باش تكون واقعية). نخليو الجملة هنا باش تولي صوت من بعد.
var last_line := ""


func say(txt: String) -> void:
	last_line = txt


func knock(dir: Vector3, power: float = 1.0) -> void:
	if pose_tw:
		pose_tw.kill()
	state = S.KNOCKED
	t = 0.0
	ring.visible = false
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3(0, 0, -1)
	flat = flat.normalized()
	var f := (11.0 if kind == "kid" else 8.5) * power
	var up := (7.5 if kind == "kid" else 6.0) * power
	velocity = flat * f + Vector3.UP * up
	spin_axis = (Vector3(flat.z, 0.0, -flat.x) + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), 0.0)).normalized()
	hit_list = [self]
	stars.visible = false
	path.clear()
	say(OUCH.pick_random())


func _land() -> void:
	state = S.DOWN
	t = 0.0
	if pose_tw:
		pose_tw.kill()
	pose_tw = create_tween()
	pose_tw.set_parallel(true)
	pose_tw.tween_property(rig, "rotation", Vector3(-PI / 2.0, randf_range(-0.6, 0.6), 0.0), 0.18)
	pose_tw.tween_property(rig, "position", Vector3(0, 0.28, 0), 0.18)
	if game:
		game.sfx.play("hit", -8.0, 0.7)


func _get_up() -> void:
	state = S.GETUP
	t = 0.0
	stars.visible = false
	if pose_tw:
		pose_tw.kill()
	pose_tw = create_tween()
	pose_tw.set_parallel(true)
	pose_tw.tween_property(rig, "rotation", Vector3.ZERO, 0.4)
	pose_tw.tween_property(rig, "position", Vector3.ZERO, 0.4)


func body_height() -> float:
	return 2.0 if kind == "said" else 1.52


## يطيح على الخروف: ينقز للبلاصة dest، يشوف للخروف، ويميل عليه بزاوية pitch (بلا ما يدخل فيه).
func pile_on(dest: Vector3, look_at_pos: Vector3, pitch: float = 1.2) -> void:
	state = S.PILE
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	stars.visible = false
	ring.visible = false
	if pose_tw:
		pose_tw.kill()
	var to := look_at_pos - dest
	to.y = 0.0
	if to.length() > 0.01:
		rotation.y = atan2(-to.x, -to.z)
	var mid := (global_position + dest) * 0.5 + Vector3.UP * 1.6
	var tw := create_tween()
	tw.tween_property(self, "global_position", mid, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", dest, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pose_tw = create_tween()
	pose_tw.set_parallel(true)
	pose_tw.tween_property(rig, "rotation", Vector3(-pitch, 0.0, 0.0), 0.35)
	pose_tw.tween_property(rig, "position", Vector3.ZERO, 0.35)
	for i in arms.size():
		pose_tw.tween_property(arms[i], "rotation", Vector3(1.55, 0.0, 0.25 if i == 0 else -0.25), 0.3)
	say("حكمتو!!" if kind == "said" else "شديتو!")


## الخروف تفلّت: يرجع يتصادم ويطير بعيد.
func release_knock(dir: Vector3) -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	for a in arms:
		a.rotation = Vector3.ZERO
	knock(dir, 1.2)


# ---------- الحركة ----------

func _physics_process(delta: float) -> void:
	if state == S.PILE or game == null:
		return
	t += delta
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	match state:
		S.RUN, S.TIRED:
			if game.chasers_active():
				var want: Vector3 = _chase(delta)
				hv = hv.lerp(want, clampf(delta * 8.0, 0.0, 1.0))
				dive_cd -= delta
				if state == S.RUN and game.is_playing() and dive_cd <= 0.0 and is_on_floor():
					var dd: Vector3 = game.sheep.global_position - global_position
					var fd := Vector2(dd.x, dd.z).length()
					if fd > 2.6 and fd < 6.5:
						start_windup()
						hv = Vector3.ZERO
					elif fd <= 2.6:
						dive_cd = 0.5
			else:
				hv = hv.lerp(Vector3.ZERO, clampf(delta * 6.0, 0.0, 1.0))
			if state == S.TIRED:
				rig.rotation.x = lerpf(rig.rotation.x, -0.35, 0.1)
			else:
				rig.rotation.x = lerpf(rig.rotation.x, 0.0, 0.1)
		S.KNOCKED:
			rig.rotate(spin_axis, delta * 13.0)
			_chain_hits()
			if (is_on_floor() and t > 0.3) or t > 2.5:
				_land()
		S.DOWN:
			hv = hv.lerp(Vector3.ZERO, clampf(delta * 6.0, 0.0, 1.0))
			stars.rotate_y(delta * 5.0)
			if t > 2.0:
				_get_up()
		S.WINDUP:
			hv = Vector3.ZERO
			if t < _windup_time() * 0.6:
				_aim()
			ring.scale = Vector3.ONE * (1.0 + sin(t * 30.0) * 0.12)
			if t >= _windup_time():
				_launch()
				hv = Vector3(velocity.x, 0.0, velocity.z)
		S.DIVE:
			var ds: Vector3 = game.sheep.global_position - global_position
			dive_min = minf(dive_min, Vector2(ds.x, ds.z).length())
			if (is_on_floor() and t > 0.15) or t > 1.2:
				_dive_land()
		S.GETUP:
			hv = Vector3.ZERO
			if t > 0.45:
				state = S.RUN
				t = 0.0
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAV * delta
	move_and_slide()
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var rb := col.get_collider() as RigidBody3D
		if rb:
			rb.apply_central_impulse(-col.get_normal() * (3.0 if state == S.KNOCKED else 0.8))
	_animate(delta)


func _process(delta: float) -> void:
	if bubble_t > 0.0:
		bubble_t -= delta
		if bubble_t <= 0.0:
			bubble.visible = false


func _chase(delta: float) -> Vector3:
	var sp: Vector3 = game.sheep.global_position
	var me := global_position
	var to := sp - me
	to.y = 0.0
	var dist := to.length()
	var spd: float = speed * game.difficulty()
	if kind == "kid":
		if state == S.RUN:
			stamina -= delta
			if stamina <= 0.0:
				state = S.TIRED
				t = 0.0
				say("هف… هف…")
		elif t > 1.4:
			state = S.RUN
			stamina = randf_range(3.5, 5.0)
		if state == S.TIRED:
			spd = 3.0
	var dir := Vector3.ZERO
	if dist < 3.5:
		dir = to / maxf(dist, 0.001)
	else:
		repath -= delta
		if repath <= 0.0 or path_i >= path.size():
			repath = randf_range(0.35, 0.6)
			path = game.world.find_path(me, sp)
			path_i = 1 if path.size() > 1 else 0
		if path_i < path.size():
			var wp: Vector3 = game.world.cell_to_world(path[path_i])
			var d := wp - me
			d.y = 0.0
			if d.length() < 0.75:
				path_i += 1
			if d.length() > 0.01:
				dir = d.normalized()
		else:
			dir = to / maxf(dist, 0.001)
	if is_on_floor() and dist < 2.8 and sp.y - me.y > 0.6:
		velocity.y = 7.5
	if dir.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 10.0, 0.0, 1.0))
	shout_cd -= delta
	if shout_cd <= 0.0 and dist < 15.0:
		shout_cd = randf_range(4.0, 7.0)
		if kind == "said":
			say(SAID_LINES.pick_random())
		else:
			say(KID_LINES.pick_random())
	return dir * spd


func _chain_hits() -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 2.0:
		return
	for c in game.chasers:
		if c in hit_list or not c.can_be_hit():
			continue
		var d: Vector3 = c.global_position - global_position
		if d.length() < 1.4:
			hit_list.append(c)
			c.knock(flat.normalized(), 0.8)
			c.hit_list.append(self)
			game.on_knock_chaser(c, true)
	for p in game.world.props:
		if p in hit_list:
			continue
		var dp: Vector3 = p.global_position - global_position
		if dp.length() < 1.1:
			hit_list.append(p)
			p.sleeping = false
			p.apply_central_impulse(flat.normalized() * 4.0 + Vector3.UP * 2.0)
			game.on_prop_hit(p)


func _animate(delta: float) -> void:
	var spd := Vector2(velocity.x, velocity.z).length()
	anim_t += delta * (4.0 + spd * 2.0)
	if state == S.RUN or state == S.TIRED:
		var a := sin(anim_t) * clampf(spd / 5.0, 0.0, 1.0) * 0.9
		legs[0].rotation.x = a
		legs[1].rotation.x = -a
		var reach := false
		if game and game.sheep:
			var d: Vector3 = game.sheep.global_position - global_position
			reach = d.length() < 4.0
		for i in arms.size():
			var sgn := 1.0 if i == 0 else -1.0
			arms[i].rotation.z = 0.0
			if reach:
				arms[i].rotation.x = 1.5 + sin(anim_t * 2.0 + i) * 0.25
			else:
				arms[i].rotation.x = -a * 1.1 * sgn
		rig.position.y = absf(sin(anim_t)) * 0.07
	elif state == S.KNOCKED:
		for i in arms.size():
			arms[i].rotation.z = sin(anim_t * 3.0 + i) * 1.3
