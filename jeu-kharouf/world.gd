extends Node3D
## خريطة «الحومة»: شوارع، ديار، سوق، جنينة، طوموبيلات وصناديق تطيح.
## فيها شبكة AStar باش المطاردين يلقاو الطريق بين الديار.

const B := preload("res://build.gd")
const HALF := 44
const WALLS: Array[Color] = [Color("f2efe6"), Color("e9cf9f"), Color("cfe0ea"), Color("eed2c4"), Color("dcc7a0"), Color("f5e6c8")]
const DOORS: Array[Color] = [Color("2f6b4f"), Color("2b5c8a"), Color("7a4a2a"), Color("8a2b2b")]
const SHUTTERS: Array[Color] = [Color("2f7d5a"), Color("3a74b0")]
const CARS: Array[Color] = [Color("f4f4f2"), Color("d8b21c"), Color("b8312f"), Color("3a5f8f"), Color("6d6f73"), Color("2c2c2e")]
const PRODUCE: Array[Color] = [Color("d8342b"), Color("f08a1c"), Color("3c9a3a"), Color("f2c230"), Color("7b2d6b")]

var astar := AStarGrid2D.new()
var props: Array = []
var prop_starts: Array = []
var obstacles: Array = []
var free_cells: Array = []
var start_pos := Vector3(0.5, 0.2, 0.5)
var said_pos := Vector3(0.5, 0.2, -18.5)
var rng := RandomNumberGenerator.new()


func build() -> void:
	rng.seed = 2026
	astar.region = Rect2i(-HALF, -HALF, HALF * 2, HALF * 2)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	_ground()
	_boundary()
	var centers: Array[int] = [-36, -12, 12, 36]
	for bx in centers:
		for bz in centers:
			var c := Vector3(bx, 0, bz)
			B.put(self, B.box(Vector3(16.6, 0.04, 16.6), Color("b9b2a4")), c + Vector3(0, 0.02, 0))
			match _block_type(bx, bz):
				"market":
					_market(c)
				"garden":
					_garden(c)
				_:
					_houses(c)
	_street_props(centers)
	_mark_obstacles()


func _block_type(bx: int, bz: int) -> String:
	if (bx == 12 and bz == -12) or (bx == -36 and bz == 12) or (bx == 36 and bz == 36):
		return "market"
	if (bx == -12 and bz == 12) or (bx == 36 and bz == -36) or (bx == -36 and bz == -36):
		return "garden"
	return "houses"


# ---------- أدوات ----------

func solid(size: Vector3, pos: Vector3, col: Color, register: bool = true) -> StaticBody3D:
	var b := StaticBody3D.new()
	add_child(b)
	b.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	b.add_child(B.box(size, col))
	if register:
		obstacles.append([Vector2(pos.x, pos.z), Vector2(size.x * 0.5, size.z * 0.5)])
	return b


func deco(n: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Node3D:
	return B.put(self, n, pos, rot, scl)


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, 0.0, c.y + 0.5)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(floori(p.x), -HALF, HALF - 1), clampi(floori(p.z), -HALF, HALF - 1))


func nearest_free(c: Vector2i) -> Vector2i:
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var p := c + Vector2i(dx, dy)
				if astar.is_in_boundsv(p) and not astar.is_point_solid(p):
					return p
	return c


func find_path(from: Vector3, to: Vector3) -> Array:
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	if astar.is_point_solid(a):
		a = nearest_free(a)
	if astar.is_point_solid(b):
		b = nearest_free(b)
	if a == b or astar.is_point_solid(a) or astar.is_point_solid(b):
		return []
	return astar.get_id_path(a, b)


func reset_props() -> void:
	for i in props.size():
		var rb: RigidBody3D = props[i]
		if not is_instance_valid(rb):
			continue
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.transform = prop_starts[i]
		rb.set_meta("hit", false)
		rb.sleeping = true


func _add_prop(rb: RigidBody3D) -> void:
	rb.collision_layer = 8
	rb.collision_mask = 1 | 2 | 4 | 8
	rb.set_meta("hit", false)
	props.append(rb)
	prop_starts.append(rb.transform)
	rb.sleeping = true


# ---------- الأرض والحيطان ----------

func _ground() -> void:
	var g := StaticBody3D.new()
	add_child(g)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(HALF * 2 + 30, 1, HALF * 2 + 30)
	cs.shape = bs
	cs.position = Vector3(0, -0.5, 0)
	g.add_child(cs)
	B.put(g, B.box(Vector3(HALF * 2 + 30, 0.1, HALF * 2 + 30), Color("55595e")), Vector3(0, -0.05, 0))
	# خطوط الطريق
	var streets: Array[int] = [-24, 0, 24]
	for s in streets:
		for i in range(-HALF + 2, HALF - 2, 4):
			if absi(i - (-24)) < 5 or absi(i) < 5 or absi(i - 24) < 5:
				continue
			deco(B.box(Vector3(0.18, 0.02, 1.8), Color("e9e6dc")), Vector3(s, 0.02, i + 1))
			deco(B.box(Vector3(1.8, 0.02, 0.18), Color("e9e6dc")), Vector3(i + 1, 0.02, s))


func _boundary() -> void:
	var col := Color("e0d6c2")
	var L := HALF * 2 + 1.0
	solid(Vector3(L, 3.2, 1), Vector3(0, 1.6, -HALF - 0.5), col)
	solid(Vector3(L, 3.2, 1), Vector3(0, 1.6, HALF + 0.5), col)
	solid(Vector3(1, 3.2, L), Vector3(-HALF - 0.5, 1.6, 0), col)
	solid(Vector3(1, 3.2, L), Vector3(HALF + 0.5, 1.6, 0), col)
	for z in [-HALF - 0.5, HALF + 0.5]:
		deco(B.box(Vector3(L, 0.25, 1.2), Color("c9b48e")), Vector3(0, 3.3, z))
	for x in [-HALF - 0.5, HALF + 0.5]:
		deco(B.box(Vector3(1.2, 0.25, L), Color("c9b48e")), Vector3(x, 3.3, 0))


# ---------- الديار ----------

func _houses(c: Vector3) -> void:
	var offs: Array[int] = [-4, 4]
	for ox in offs:
		for oz in offs:
			var lot := c + Vector3(ox, 0, oz)
			if rng.randf() < 0.18:
				_courtyard(lot)
			else:
				_house(lot, Vector3(signf(ox), 0, signf(oz)))


func _house(lot: Vector3, out: Vector3) -> void:
	var w := rng.randf_range(5.6, 7.4)
	var d := rng.randf_range(5.6, 7.4)
	var floors := rng.randi_range(1, 2)
	var h := floors * 3.0 + 0.4
	var col: Color = WALLS[rng.randi() % WALLS.size()]
	var pos := lot + Vector3(out.x * (7.6 - w) * 0.5, h * 0.5, out.z * (7.6 - d) * 0.5)
	solid(Vector3(w, h, d), pos, col)
	var fz := pos.z + out.z * (d * 0.5 + 0.06)
	var bz := pos.z - out.z * (d * 0.5 + 0.06)
	var door_x := pos.x + rng.randf_range(-w * 0.22, w * 0.22)
	deco(B.box(Vector3(1.1, 2.1, 0.12), DOORS[rng.randi() % DOORS.size()]), Vector3(door_x, 1.05, fz))
	deco(B.box(Vector3(1.5, 0.12, 0.5), Color("a59d8f")), Vector3(door_x, 0.06, fz + out.z * 0.25))
	var sh: Color = SHUTTERS[rng.randi() % SHUTTERS.size()]
	for f in floors:
		var wy := 1.7 + f * 3.0
		for k in [-1.0, 1.0]:
			var wx: float = pos.x + k * w * 0.28
			if f == 0 and absf(wx - door_x) < 1.2:
				continue
			_window(Vector3(wx, wy, fz), out.z, sh)
		_window(Vector3(pos.x, wy, bz), -out.z, sh)
	# الحافة فوق السطح
	var top := h
	deco(B.box(Vector3(w, 0.4, 0.2), col.darkened(0.06)), Vector3(pos.x, top + 0.2, pos.z + d * 0.5 - 0.1))
	deco(B.box(Vector3(w, 0.4, 0.2), col.darkened(0.06)), Vector3(pos.x, top + 0.2, pos.z - d * 0.5 + 0.1))
	deco(B.box(Vector3(0.2, 0.4, d), col.darkened(0.06)), Vector3(pos.x + w * 0.5 - 0.1, top + 0.2, pos.z))
	deco(B.box(Vector3(0.2, 0.4, d), col.darkened(0.06)), Vector3(pos.x - w * 0.5 + 0.1, top + 0.2, pos.z))
	if rng.randf() < 0.65:
		var tank_col := Color("f0f0ee") if rng.randf() < 0.5 else Color("3d7fb5")
		deco(B.cyl(0.45, 0.45, 0.9, tank_col, 10), Vector3(pos.x + rng.randf_range(-1.5, 1.5), top + 0.45, pos.z + rng.randf_range(-1.5, 1.5)))
	if rng.randf() < 0.4:
		deco(B.sphere(0.4, Color("d8d8d8"), 10), Vector3(pos.x - w * 0.3, top + 0.5, pos.z), Vector3(0, 0, 35), Vector3(1, 0.35, 1))
	if rng.randf() < 0.35 and floors > 1:
		deco(B.box(Vector3(0.8, 0.5, 0.35), Color("cfcfcf")), Vector3(pos.x + w * 0.3, 3.9, fz + out.z * 0.15))


func _window(p: Vector3, dir_z: float, shutter: Color) -> void:
	deco(B.box(Vector3(0.95, 1.05, 0.1), Color("6f8fa8")), p)
	deco(B.box(Vector3(1.15, 0.1, 0.22), Color("f4f2ec")), p + Vector3(0, -0.58, dir_z * 0.05))
	if rng.randf() < 0.5:
		deco(B.box(Vector3(0.32, 1.05, 0.06), shutter), p + Vector3(0.66, 0, dir_z * 0.02))
		deco(B.box(Vector3(0.32, 1.05, 0.06), shutter), p + Vector3(-0.66, 0, dir_z * 0.02))


func _courtyard(lot: Vector3) -> void:
	_olive(lot + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5)))
	for i in 3:
		_crate(lot + Vector3(rng.randf_range(-3, 3), 0.36, rng.randf_range(-3, 3)))
	_bin(lot + Vector3(rng.randf_range(-3, 3), 0.46, rng.randf_range(-3, 3)))


func _olive(p: Vector3) -> void:
	solid(Vector3(0.5, 1.7, 0.5), p + Vector3(0, 0.85, 0), Color("6b4f36"))
	deco(B.sphere(1.4, Color("7f9c55"), 10), p + Vector3(0, 2.5, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	deco(B.sphere(0.9, Color("6f8f48"), 8), p + Vector3(0.8, 2.9, 0.3))
	deco(B.sphere(0.8, Color("8aa862"), 8), p + Vector3(-0.7, 2.8, -0.4))


func _palm(p: Vector3) -> void:
	solid(Vector3(0.5, 4.6, 0.5), p + Vector3(0, 2.3, 0), Color("8a6a45"))
	for i in 7:
		var a := i * 360.0 / 7.0
		deco(B.box(Vector3(0.45, 0.06, 2.4), Color("4f8a3a")), p + Vector3(sin(deg_to_rad(a)) * 1.0, 4.55, cos(deg_to_rad(a)) * 1.0), Vector3(-25, a, 0))


# ---------- السوق ----------

func _market(c: Vector3) -> void:
	deco(B.box(Vector3(16, 0.03, 16), Color("cbb894")), c + Vector3(0, 0.05, 0))
	var xs: Array[float] = [-5.0, 0.0, 5.0]
	for x in xs:
		_stall(c + Vector3(x, 0, -5.0))
		_stall(c + Vector3(x, 0, 5.0))
	# هرم صناديق في الوسط
	for row in 3:
		for k in 3 - row:
			_crate(c + Vector3((k - (2 - row) * 0.5) * 0.72, 0.35 + row * 0.71, 0))
	for i in 4:
		var mx := rng.randf_range(2.5, 6.0) * (1.0 if i % 2 == 0 else -1.0)
		_melon(c + Vector3(mx, 0.4, rng.randf_range(-2.0, 2.0)))
	_palm(c + Vector3(-7, 0, -7))
	_palm(c + Vector3(7, 0, 7))


func _stall(p: Vector3) -> void:
	solid(Vector3(2.6, 0.9, 1.1), p + Vector3(0, 0.45, 0), Color("8a5a34"))
	for sx in [-1.2, 1.2]:
		for sz in [-0.5, 0.5]:
			deco(B.cyl(0.05, 0.05, 2.3, Color("5a4630"), 6), p + Vector3(sx, 1.15, sz))
	var a := Color("d8342b") if rng.randf() < 0.5 else Color("2f7d5a")
	for i in 4:
		deco(B.box(Vector3(0.75, 0.06, 1.6), a if i % 2 == 0 else Color("f4f2ec")), p + Vector3(-1.125 + i * 0.75, 2.32, 0))
	var pc: Color = PRODUCE[rng.randi() % PRODUCE.size()]
	for i in 9:
		deco(B.sphere(0.14, pc, 6), p + Vector3(rng.randf_range(-1.1, 1.1), 1.0, rng.randf_range(-0.4, 0.4)))
	_crate(p + Vector3(1.75, 0.36, rng.randf_range(-0.6, 0.6)))
	_crate(p + Vector3(-1.75, 0.36, rng.randf_range(-0.6, 0.6)))


# ---------- الجنينة ----------

func _garden(c: Vector3) -> void:
	deco(B.box(Vector3(15.4, 0.04, 15.4), Color("6f9e4c")), c + Vector3(0, 0.06, 0))
	var wc := Color("e8dcc6")
	for s in [-1.0, 1.0]:
		solid(Vector3(6.3, 0.8, 0.35), c + Vector3(-4.65, 0.4, 7.8 * s), wc)
		solid(Vector3(6.3, 0.8, 0.35), c + Vector3(4.65, 0.4, 7.8 * s), wc)
		solid(Vector3(0.35, 0.8, 6.3), c + Vector3(7.8 * s, 0.4, -4.65), wc)
		solid(Vector3(0.35, 0.8, 6.3), c + Vector3(7.8 * s, 0.4, 4.65), wc)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_olive(c + Vector3(4.5 * sx, 0, 4.5 * sz))
	# الفوارة
	var f := StaticBody3D.new()
	add_child(f)
	f.position = c + Vector3(0, 0.3, 0)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 1.4
	cy.height = 0.6
	cs.shape = cy
	f.add_child(cs)
	f.add_child(B.cyl(1.4, 1.5, 0.6, Color("d9cdb4"), 16))
	B.put(f, B.cyl(1.2, 1.2, 0.05, Color("5aa9d6"), 16), Vector3(0, 0.29, 0))
	obstacles.append([Vector2(c.x, c.z), Vector2(1.4, 1.4)])
	for s in [-1.0, 1.0]:
		deco(B.box(Vector3(2.0, 0.12, 0.6), Color("8a5a34")), c + Vector3(3.2 * s, 0.5, 0))


# ---------- الحوايج اللي تطيح ----------

func _crate(p: Vector3) -> void:
	var rb := RigidBody3D.new()
	add_child(rb)
	rb.position = p
	rb.mass = 1.2
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.7, 0.7, 0.7)
	cs.shape = bs
	rb.add_child(cs)
	rb.add_child(B.box(Vector3(0.7, 0.7, 0.7), Color("b5804a")))
	B.put(rb, B.box(Vector3(0.72, 0.1, 0.72), Color("8c5a2e")), Vector3(0, 0.2, 0))
	B.put(rb, B.box(Vector3(0.72, 0.1, 0.72), Color("8c5a2e")), Vector3(0, -0.2, 0))
	_add_prop(rb)


func _melon(p: Vector3) -> void:
	var rb := RigidBody3D.new()
	add_child(rb)
	rb.position = p
	rb.mass = 2.5
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.38
	cs.shape = sp
	rb.add_child(cs)
	B.put(rb, B.sphere(0.4, Color("2f7d32"), 10), Vector3.ZERO, Vector3.ZERO, Vector3(1.15, 0.95, 0.95))
	_add_prop(rb)


func _bin(p: Vector3) -> void:
	var rb := RigidBody3D.new()
	add_child(rb)
	rb.position = p
	rb.mass = 1.5
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.33
	cy.height = 0.9
	cs.shape = cy
	rb.add_child(cs)
	rb.add_child(B.cyl(0.33, 0.28, 0.9, Color("2e6f4a"), 10))
	B.put(rb, B.cyl(0.36, 0.36, 0.08, Color("245a3c"), 10), Vector3(0, 0.47, 0))
	_add_prop(rb)


func _street_props(centers: Array[int]) -> void:
	var sides: Array[Vector3] = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]
	for bx in centers:
		for bz in centers:
			var c := Vector3(bx, 0, bz)
			for s in sides:
				var edge := c + s * 9.8
				if absf(edge.x) > HALF - 2 or absf(edge.z) > HALF - 2:
					continue
				var along := Vector3(absf(s.z), 0, absf(s.x))
				if rng.randf() < 0.45:
					_car(edge + along * rng.randf_range(-4.0, 4.0), s.x == 0.0)
				if rng.randf() < 0.55:
					_crate(c + s * 8.4 + along * rng.randf_range(-6.0, 6.0) + Vector3(0, 0.36, 0))
				if rng.randf() < 0.3:
					_bin(c + s * 8.45 + along * rng.randf_range(-6.0, 6.0) + Vector3(0, 0.46, 0))


func _car(pos: Vector3, along_x: bool) -> void:
	var col: Color = CARS[rng.randi() % CARS.size()]
	var size := Vector3(4.0, 0.9, 1.85) if along_x else Vector3(1.85, 0.9, 4.0)
	var cab := Vector3(2.0, 0.7, 1.65) if along_x else Vector3(1.65, 0.7, 2.0)
	solid(size, pos + Vector3(0, 0.55, 0), col)
	solid(cab, pos + Vector3(0, 1.35, 0), Color("33424f"), false)
	deco(B.box(Vector3(cab.x * 0.92, 0.08, cab.z * 0.92), col), pos + Vector3(0, 1.74, 0))
	for a in [-1.3, 1.3]:
		for b in [-0.93, 0.93]:
			var wp := Vector3(a, 0.33, b) if along_x else Vector3(b, 0.33, a)
			var rot := Vector3(90, 0, 0) if along_x else Vector3(0, 0, 90)
			deco(B.cyl(0.33, 0.33, 0.25, Color("1d1d1f"), 10), pos + wp, rot)


# ---------- شبكة الطريق ----------

func _mark_obstacles() -> void:
	for o in obstacles:
		var ctr: Vector2 = o[0]
		var hf: Vector2 = o[1] + Vector2(0.45, 0.45)
		for x in range(floori(ctr.x - hf.x), ceili(ctr.x + hf.x) + 1):
			for z in range(floori(ctr.y - hf.y), ceili(ctr.y + hf.y) + 1):
				var cc := Vector2(x + 0.5, z + 0.5)
				if absf(cc.x - ctr.x) <= hf.x and absf(cc.y - ctr.y) <= hf.y:
					var id := Vector2i(x, z)
					if astar.is_in_boundsv(id):
						astar.set_point_solid(id, true)
	for x in range(-HALF, HALF):
		for z in range(-HALF, HALF):
			var id := Vector2i(x, z)
			if not astar.is_point_solid(id):
				free_cells.append(id)
