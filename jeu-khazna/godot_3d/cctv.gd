# كاميرا مراقبة على الجدار: تمسح يميناً ويساراً، ترسم مخروط رؤية على الأرض، ونقطة حمراء تومض.
# إن بقي العميل داخل المخروط (ولا شيء يحجبه) يمتلئ عدّادها، وعند امتلائه تنادي أقرب حارس.
# المحلّل يستطيع تجميد كل الكاميرات لثوانٍ (تصبح عمياء: يطفأ المخروط والنقطة).
extends Node3D

const RANGE := 9.5
const HALF_ANGLE := 21.0
const PITCH := -32.0

var base_yaw := 0.0
var sweep := 50.0
var period := 7.0
var frozen_t := 0.0
var fill := 0.0 # 0..1 عدّاد الرصد
var cooldown := 0.0
var _head: Node3D
var _cone: MeshInstance3D
var _cone_mat: StandardMaterial3D
var _led: MeshInstance3D
var _led_mat: StandardMaterial3D
var _spot: SpotLight3D
var _servo_t := 0.0


func setup(at: Vector3, yaw_deg: float, sweep_deg: float, per: float) -> void:
	position = at
	base_yaw = deg_to_rad(yaw_deg)
	sweep = deg_to_rad(sweep_deg)
	period = per
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.09, 0.095, 0.1)
	dark.metallic = 0.6
	dark.roughness = 0.4
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.78, 0.79, 0.8)
	shell.roughness = 0.5
	# الحامل على الجدار
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.08, 0.08, 0.32)
	arm.mesh = am
	arm.material_override = dark
	add_child(arm)
	arm.position = Vector3(0, 0.12, 0)
	arm.rotation.y = base_yaw
	arm.translate_object_local(Vector3(0, 0, -0.12))
	_head = Node3D.new()
	add_child(_head)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.17, 0.42)
	body.mesh = bm
	body.material_override = shell
	_head.add_child(body)
	var hood := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.24, 0.03, 0.48)
	hood.mesh = hm
	hood.material_override = shell
	hood.position = Vector3(0, 0.1, -0.03)
	_head.add_child(hood)
	var lens := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.055
	lm.bottom_radius = 0.06
	lm.height = 0.05
	lens.mesh = lm
	lens.rotation_degrees.x = 90
	lens.position = Vector3(0, 0, -0.23)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.02, 0.03, 0.05)
	glass.metallic = 1.0
	glass.roughness = 0.05
	lens.material_override = glass
	_head.add_child(lens)
	_led_mat = StandardMaterial3D.new()
	_led_mat.albedo_color = Color(1, 0.1, 0.08)
	_led_mat.emission_enabled = true
	_led_mat.emission = Color(1, 0.08, 0.05)
	_led_mat.emission_energy_multiplier = 5.0
	_led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_led = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.016
	sm.height = 0.032
	_led.mesh = sm
	_led.material_override = _led_mat
	_led.position = Vector3(0.07, 0.05, -0.215)
	_head.add_child(_led)
	# مخروط الرؤية: ضوء خافت + شكل شفّاف يرى اللاعبان حدوده
	_spot = SpotLight3D.new()
	_spot.light_color = Color(1.0, 0.35, 0.25)
	_spot.light_energy = 1.4
	_spot.spot_range = RANGE
	_spot.spot_angle = HALF_ANGLE
	_spot.spot_attenuation = 1.2
	_spot.position = Vector3(0, 0, -0.25)
	_head.add_child(_spot)
	_cone = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var r := tan(deg_to_rad(HALF_ANGLE)) * RANGE * 0.62
	cm.top_radius = 0.02
	cm.bottom_radius = r
	cm.height = RANGE * 0.62
	cm.radial_segments = 20
	cm.rings = 1
	cm.cap_bottom = false
	cm.cap_top = false
	_cone.mesh = cm
	_cone_mat = StandardMaterial3D.new()
	_cone_mat.albedo_color = Color(1.0, 0.3, 0.22, 0.05)
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.no_depth_test = false
	_cone.material_override = _cone_mat
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# المخروط ممتدّ أمام العدسة (−z)
	_cone.rotation_degrees.x = 90
	_cone.position = Vector3(0, 0, -0.25 - RANGE * 0.31)
	_head.add_child(_cone)
	update(0.0, 0.0)


func yaw_at(t: float) -> float:
	return base_yaw + sin(t * TAU / period) * sweep


func update(t: float, delta: float) -> void:
	frozen_t = maxf(0.0, frozen_t - delta)
	cooldown = maxf(0.0, cooldown - delta)
	if frozen_t <= 0.0:
		_head.rotation = Vector3(deg_to_rad(PITCH), yaw_at(t), 0)
	var blind := frozen_t > 0.0
	_spot.visible = not blind
	_cone.visible = not blind
	var alarm := fill > 0.05
	_led.visible = not blind and (fmod(t * (6.0 if alarm else 1.2), 1.0) > 0.5)
	_cone_mat.albedo_color = Color(1.0, 0.3, 0.22, 0.05 + 0.12 * fill)
	_spot.light_energy = 1.4 + 2.5 * fill


func eye() -> Vector3:
	return _head.global_position


## هل ترى الكاميرا هذه النقطة؟ (المسافة، الزاوية، ولا جدار بينهما)
func sees(p: Vector3, crouch: bool, space: PhysicsDirectSpaceState3D, exclude: Array) -> bool:
	if frozen_t > 0.0:
		return false
	var tgt := p + Vector3(0, 0.75 if crouch else 1.2, 0)
	var e := eye()
	var d := tgt - e
	if d.length() > RANGE:
		return false
	var fwd := -_head.global_transform.basis.z
	if fwd.dot(d.normalized()) < cos(deg_to_rad(HALF_ANGLE)):
		return false
	var q := PhysicsRayQueryParameters3D.create(e + fwd * 0.3, tgt)
	q.exclude = exclude
	return space.intersect_ray(q).is_empty()
