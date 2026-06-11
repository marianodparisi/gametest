extends Node3D

@onready var track_builder = $TrackBuilder
@onready var waypoints_node = $Waypoints


func _ready() -> void:
	_build_terrain()
	_build_track()
	_add_props()


func _build_terrain() -> void:
	# Terreno de montaña — varias cajas en distintas alturas para dar relieve
	var rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.38, 0.36, 0.32, 1)

	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.3, 0.42, 0.22, 1)

	# Piso base
	var base = _make_static_box(Vector3(250, 0.5, 250), grass_mat)
	base.position = Vector3(20, -0.25, 40)
	add_child(base)

	# Plataformas de montaña para dar sensación de terreno irregular
	var platforms = [
		[Vector3(60, 3, 50), Vector3(30, 1.5, -60)],
		[Vector3(50, 5, 40), Vector3(60, 2.5, -20)],
		[Vector3(70, 4, 60), Vector3(65, 2.0, 30)],
		[Vector3(60, 6, 50), Vector3(50, 4.0, 70)],
		[Vector3(50, 7, 40), Vector3(10, 5.0, 90)],
	]
	for p in platforms:
		var platform = _make_static_box(p[0], rock_mat)
		platform.position = p[1]
		add_child(platform)


func _make_static_box(size: Vector3, mat: StandardMaterial3D) -> StaticBody3D:
	var sb = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)

	var mi = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	sb.add_child(mi)
	return sb


func _build_track() -> void:
	var pts: PackedVector3Array = []
	for child in waypoints_node.get_children():
		if child is Node3D:
			pts.append(child.global_position)
	track_builder.set_points(pts, false)  # false = lineal


func _add_props() -> void:
	# Pinos de montaña (más densos y altos que en el circuito)
	var tree_spots = [
		Vector3(-15, 0, -30), Vector3(40, 2, -90), Vector3(80, 3, -50),
		Vector3(85, 4, 10), Vector3(80, 5, 50), Vector3(70, 7, 85),
		Vector3(-10, 8, 100), Vector3(-40, 8, 75), Vector3(-50, 8, 55),
		Vector3(-20, 0, -15), Vector3(-30, 0, -40), Vector3(25, 1, -95),
		Vector3(95, 4, -30), Vector3(90, 5, 55), Vector3(20, 8, 105),
	]
	for pos in tree_spots:
		_spawn_pine(pos)

	# Rocas scattered
	var rock_spots = [
		Vector3(-8, 0, -18), Vector3(45, 2, -70), Vector3(78, 3.5, -10),
		Vector3(72, 6, 75), Vector3(-20, 7.5, 88), Vector3(-42, 8, 65),
	]
	for pos in rock_spots:
		_spawn_rock(pos)


func _spawn_pine(pos: Vector3) -> void:
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.28, 0.18, 0.1, 1)

	var leaf_mat = StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(
		randf_range(0.1, 0.2),
		randf_range(0.35, 0.5),
		randf_range(0.1, 0.2),
		1
	)

	var root = Node3D.new()
	root.position = pos
	root.rotation.y = randf_range(0, TAU)
	var s = randf_range(0.8, 1.8)
	root.scale = Vector3(s, s, s)

	var trunk = MeshInstance3D.new()
	var tm = CylinderMesh.new()
	tm.top_radius = 0.1
	tm.bottom_radius = 0.2
	tm.height = 3.0
	trunk.mesh = tm
	trunk.position.y = 1.5
	trunk.set_surface_override_material(0, trunk_mat)

	# 3 capas de copa para pino más realista
	for layer in 3:
		var leaves = MeshInstance3D.new()
		var lm = CylinderMesh.new()
		lm.top_radius = 0.0
		lm.bottom_radius = 1.8 - layer * 0.4
		lm.height = 2.5
		lm.radial_segments = 6
		leaves.mesh = lm
		leaves.position.y = 3.0 + layer * 1.8
		leaves.set_surface_override_material(0, leaf_mat)
		root.add_child(leaves)

	root.add_child(trunk)
	add_child(root)


func _spawn_rock(pos: Vector3) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(
		randf_range(0.4, 0.55),
		randf_range(0.38, 0.5),
		randf_range(0.35, 0.48),
		1
	)

	var mesh = SphereMesh.new()
	mesh.radius = randf_range(0.6, 1.4)
	mesh.height = mesh.radius * randf_range(0.6, 1.0)
	mesh.radial_segments = 5
	mesh.rings = 3

	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos + Vector3(0, mesh.height * 0.5, 0)
	mi.rotation = Vector3(randf_range(0, 0.3), randf_range(0, TAU), randf_range(0, 0.3))
	mi.set_surface_override_material(0, mat)
	add_child(mi)
