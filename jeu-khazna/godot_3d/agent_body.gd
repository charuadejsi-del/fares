# جسم العميل (شخصية Mixamo بالبدلة السوداء) وحركاته الحقيقية: وقوف، مشي، ركض، انحناء في 4 اتّجاهات،
# لكمة الإسقاط، ورمي. وعند التنكّر يظهر بزيّ الحارس (نفس الحركات على نموذج الحارس).
# يُستعمل للعميل نفسه (الكاميرا خلفه) وللصورة التي يراها المحلّل (يُحرَّك عن بعد).
extends Node3D

const CLIPS := {
	"idle": "res://characters/idle_sweat.fbx",
	"walk": "res://characters/walk.fbx",
	"run": "res://characters/agent/run.fbx",
	"c_idle": "res://characters/agent/c_idle.fbx",
	"c_fwd": "res://characters/agent/c_fwd.fbx",
	"c_back": "res://characters/agent/c_back.fbx",
	"c_left": "res://characters/agent/c_left.fbx",
	"c_right": "res://characters/agent/c_right.fbx",
	"hook": "res://characters/agent/hook.fbx",
	"throw": "res://characters/agent/throw.fbx",
}
const LOOPED := ["idle", "walk", "run", "c_idle", "c_fwd", "c_back", "c_left", "c_right"]

var clip := "idle"
var disguised := false
var _suit: Node3D
var _guard: Node3D
var _anims: Array = [] # مشغّل الحركات لكلّ نموذج
var _one_shot := 0.0
var debug := ""


func _ready() -> void:
	_suit = _load("res://characters/agent/agent.fbx")
	_guard = _load("res://characters/walk.fbx")
	if _suit == null:
		_suit = _capsule(Color(0.06, 0.07, 0.09))
	if _guard == null:
		_guard = _capsule(Color(0.15, 0.2, 0.32))
	_guard.visible = false
	play("idle")


func _capsule(c: Color) -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.75
	body.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	body.material_override = m
	body.position.y = 0.88
	n.add_child(body)
	add_child(n)
	return n


func _load(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		debug += "missing %s | " % path
		return null
	var scn = load(path)
	if not scn is PackedScene:
		return null
	var model := (scn as PackedScene).instantiate() as Node3D
	model.rotation_degrees.y = 180 # Mixamo ينظر نحو +Z
	add_child(model)
	_fit(model)
	var ap := _find(model, "AnimationPlayer") as AnimationPlayer
	var skel := _find(model, "Skeleton3D") as Skeleton3D
	if ap == null:
		ap = AnimationPlayer.new()
		model.add_child(ap)
	if skel == null:
		debug += "no skeleton %s | " % path
		return model
	var lib := AnimationLibrary.new()
	var root := ap.get_node(ap.root_node)
	var skel_path := str(root.get_path_to(skel))
	for key in CLIPS:
		var a := _first_anim(str(CLIPS[key]))
		if a == null:
			debug += "no clip %s | " % key
			continue
		a = a.duplicate(true)
		for i in a.get_track_count():
			var p := str(a.track_get_path(i))
			var c := p.find(":")
			if c >= 0:
				a.track_set_path(i, NodePath(skel_path + p.substr(c)))
			# الحركة في المكان: نلغي تقدّم الحوض أفقياً (الجسم يحرّكه الكود)
			if a.track_get_type(i) == Animation.TYPE_POSITION_3D and p.contains("Hips") and a.track_get_key_count(i) > 0:
				var first: Vector3 = a.track_get_key_value(i, 0)
				for k in a.track_get_key_count(i):
					var v: Vector3 = a.track_get_key_value(i, k)
					a.track_set_key_value(i, k, Vector3(first.x, v.y, first.z))
		a.loop_mode = Animation.LOOP_LINEAR if LOOPED.has(key) else Animation.LOOP_NONE
		lib.add_animation(key, a)
	if ap.has_animation_library("g"):
		ap.remove_animation_library("g")
	ap.add_animation_library("g", lib)
	_anims.append(ap)
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
		var best := -1.0
		for n in ap.get_animation_list():
			if str(n) == "RESET":
				continue
			var cand := ap.get_animation(n)
			if str(n) == "mixamo_com":
				out = cand
				break
			if cand.length > best:
				best = cand.length
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


func has_clip(c: String) -> bool:
	return not _anims.is_empty() and (_anims[0] as AnimationPlayer).has_animation("g/" + c)


## يشغّل حركة على النموذجين معاً (البدلة وزيّ الحارس) فيبقى التنكّر متزامناً.
func play(c: String, blend := 0.2, speed := 1.0) -> void:
	if _one_shot > 0.0 and not (c == "hook" or c == "throw"):
		return
	clip = c
	for ap in _anims:
		var p := ap as AnimationPlayer
		if p.has_animation("g/" + c):
			if p.current_animation != "g/" + c:
				p.play("g/" + c, blend)
			p.speed_scale = speed


## حركة لمرّة واحدة (لكمة، رمي) تتقدّم على حركات المشي حتى تنتهي.
func one_shot(c: String, seconds: float) -> void:
	_one_shot = 0.0
	play(c, 0.08, 1.2)
	_one_shot = seconds


func set_disguised(v: bool) -> void:
	disguised = v
	_suit.visible = not v
	_guard.visible = v


func _process(delta: float) -> void:
	_one_shot = maxf(0.0, _one_shot - delta)


## يختار الحركة من السرعة واتّجاه المشي بالنسبة للجسم.
func drive(local_vel: Vector3, crouch: bool, running: bool) -> void:
	var sp := Vector2(local_vel.x, local_vel.z).length()
	if crouch:
		if sp < 0.15:
			play("c_idle")
		elif absf(local_vel.x) > absf(local_vel.z) * 1.2:
			play("c_right" if local_vel.x > 0.0 else "c_left", 0.2, clampf(sp / 1.4, 0.7, 1.5))
		elif local_vel.z > 0.0:
			play("c_back", 0.2, clampf(sp / 1.4, 0.7, 1.5))
		else:
			play("c_fwd", 0.2, clampf(sp / 1.4, 0.7, 1.5))
	elif sp < 0.15:
		play("idle")
	elif running:
		play("run", 0.15, clampf(sp / 5.0, 0.8, 1.3))
	else:
		play("walk", 0.2, clampf(sp / 1.6, 0.8, 1.6))
