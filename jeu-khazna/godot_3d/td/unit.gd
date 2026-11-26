# شخصية متحرّكة (Mixamo): نموذج + مكتبة حركات مشتركة. تُستعمل للعميل والحرّاس ودمى الشبكة.
# الحركات مأخوذة من ملفات FBX مختلفة؛ نصحّح ارتفاع الحوض حسب هيكل كل نموذج حتى لا "يطير" الجسم.
extends Node3D

const CLIPS := {
	"idle": "res://characters/idle_sweat.fbx",
	"idle2": "res://characters/idle_bugs.fbx",
	"walk": "res://characters/walk.fbx",
	"run": "res://characters/agent/run.fbx",
	"sneak": "res://characters/agent/c_fwd.fbx",
	"c_idle": "res://characters/agent/c_idle.fbx",
	"alert": "res://characters/alert.fbx",
	"hook": "res://characters/agent/hook.fbx",
	"ko": "res://characters/agent/ko.fbx",
	"pick": "res://characters/agent/pick.fbx",
	"open": "res://characters/agent/open.fbx",
	"drag": "res://characters/agent/drag.fbx",
	"throw": "res://characters/agent/throw.fbx",
}
const LOOPED := ["idle", "idle2", "walk", "run", "sneak", "c_idle", "alert", "drag"]
const AGENT_MODEL := "res://characters/agent/agent.fbx"
const GUARD_MODEL := "res://characters/walk.fbx"

static var _clip_cache := {}

var clip := ""
var model: Node3D
var _ap: AnimationPlayer
var _hold := 0.0
var _body_meshes: Array = []


func setup(path: String) -> void:
	model = _load(path)
	if model == null:
		model = _capsule()
	play("idle", 0.0)


## بدلة العميل: رمادي فحمي مطفأ (لا يلمع تحت الضوء) مع أكتاف أفتح قليلاً.
func suit_look() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.085, 0.09, 0.11)
	m.roughness = 0.95
	m.metallic = 0.0
	for mi in _body_meshes:
		(mi as MeshInstance3D).material_override = m


## الحارس بعد نزع بدلته: لون جلد (يبقى بملابسه الداخلية).
func skin_look() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.8, 0.6, 0.47)
	skin.roughness = 0.75
	for mi in _body_meshes:
		var m := mi as MeshInstance3D
		if str(m.name).to_lower().contains("head"):
			continue
		m.material_override = skin


func play(c: String, blend := 0.2, speed := 1.0) -> void:
	if _hold > 0.0 and c != "ko":
		return
	if _ap == null or not _ap.has_animation("g/" + c):
		return
	if c == clip and _ap.is_playing():
		_ap.speed_scale = speed
		return
	clip = c
	_ap.play("g/" + c, blend)
	_ap.speed_scale = speed


## حركة مرّة واحدة (لكمة، التقاط، فتح باب) تمنع تغيير الحركة حتى تنتهي.
func one_shot(c: String, secs: float, speed := 1.0) -> void:
	_hold = 0.0
	play(c, 0.1, speed)
	_hold = secs


## يبقى على آخر لقطة (الإغماء على الأرض).
func freeze_end() -> void:
	if _ap and _ap.current_animation != "":
		_ap.seek(_ap.current_animation_length - 0.01, true)
		_ap.pause()


func has_clip(c: String) -> bool:
	return _ap != null and _ap.has_animation("g/" + c)


func _process(delta: float) -> void:
	if _hold > 0.0:
		_hold -= delta


# ───────── التحميل ─────────
func _load(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scn = load(path)
	if not scn is PackedScene:
		return null
	var m := (scn as PackedScene).instantiate() as Node3D
	m.rotation_degrees.y = 180 # Mixamo ينظر نحو +Z، ونحن نعتبر الأمام −Z
	add_child(m)
	_fit(m)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		_body_meshes.append(mi)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_ap = _find(m, "AnimationPlayer") as AnimationPlayer
	var skel := _find(m, "Skeleton3D") as Skeleton3D
	if _ap == null:
		_ap = AnimationPlayer.new()
		m.add_child(_ap)
	if skel == null:
		return m
	var root := _ap.get_node(_ap.root_node)
	var skel_path := str(root.get_path_to(skel))
	var hips := -1
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).ends_with("Hips"):
			hips = i
			break
	var rest := Vector3.ZERO
	if hips >= 0:
		rest = skel.get_bone_rest(hips).origin
	var lib := AnimationLibrary.new()
	for key in CLIPS:
		var src := _clip(str(CLIPS[key]))
		if src == null:
			continue
		var a := src.duplicate(true) as Animation
		for t in a.get_track_count():
			var p := str(a.track_get_path(t))
			var colon := p.find(":")
			if colon >= 0:
				a.track_set_path(t, NodePath(skel_path + p.substr(colon)))
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D and p.contains("Hips") and a.track_get_key_count(t) > 0:
				# الحوض: في المكان أفقياً (الكود يحرّك الجسم)، وارتفاعه مضبوط على هيكل هذا النموذج
				var first: Vector3 = a.track_get_key_value(t, 0)
				var k := 1.0
				if hips >= 0 and absf(first.y) > 0.0001 and absf(rest.y) > 0.0001:
					k = rest.y / first.y
				for j in a.track_get_key_count(t):
					var v: Vector3 = a.track_get_key_value(t, j)
					a.track_set_key_value(t, j, Vector3(rest.x if hips >= 0 else first.x, v.y * k, rest.z if hips >= 0 else first.z))
		a.loop_mode = Animation.LOOP_LINEAR if LOOPED.has(key) else Animation.LOOP_NONE
		lib.add_animation(key, a)
	if _ap.has_animation_library("g"):
		_ap.remove_animation_library("g")
	_ap.add_animation_library("g", lib)
	return m


static func _clip(res_path: String) -> Animation:
	if _clip_cache.has(res_path):
		return _clip_cache[res_path]
	var out: Animation = null
	if ResourceLoader.exists(res_path):
		var scn = load(res_path)
		if scn is PackedScene:
			var inst := (scn as PackedScene).instantiate()
			var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
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
	_clip_cache[res_path] = out
	return out


static func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f:
			return f
	return null


func _fit(m: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		var b := mm.global_transform * mm.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.size.y <= 0.01:
		return
	var k := 1.8 / box.size.y
	m.scale *= k
	m.position.y -= (box.position.y - global_position.y) * k


func _capsule() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.75
	body.mesh = cap
	body.position.y = 0.88
	n.add_child(body)
	add_child(n)
	_body_meshes.append(body)
	return n
