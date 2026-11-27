extends RefCounted
## أدوات بناء الأشكال (Low-poly) بالكود — بلا ملفات رسومات خارجية.

static var _mats: Dictionary = {}


static func mat(c: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f" % [c.to_html(), emission]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


static func box(size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	m.material = mat(c)
	mi.mesh = m
	return mi


static func sphere(r: float, c: Color, seg: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = maxi(seg / 2, 3)
	m.material = mat(c)
	mi.mesh = m
	return mi


static func cyl(top: float, bottom: float, h: float, c: Color, seg: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	m.material = mat(c)
	mi.mesh = m
	return mi


static func torus(inner: float, outer: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 12
	m.ring_segments = 6
	m.material = mat(c)
	mi.mesh = m
	return mi


static func put(parent: Node, n: Node3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Node3D:
	parent.add_child(n)
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scl
	return n


static func pivot(parent: Node, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	parent.add_child(p)
	p.position = pos
	return p


static func label3d(text: String, font: Font, fs: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	if font:
		l.font = font
	l.font_size = fs
	l.outline_size = maxi(fs / 5, 6)
	l.modulate = col
	l.outline_modulate = Color(0.12, 0.08, 0.05, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.01
	return l
