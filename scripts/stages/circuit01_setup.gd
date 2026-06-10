extends Node3D

# Setup del Circuit01: construye la pista y el terreno base en _ready.

@onready var track_builder = $TrackBuilder
@onready var waypoints = $Waypoints


func _ready() -> void:
	_build_terrain()
	_build_track()
	_add_props()


func _build_terrain() -> void:
	# Piso de hierba grande
	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.26, 0.46, 0.2, 1)
	grass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh = BoxMesh.new()
	mesh.size = Vector3(200, 0.3, 200)

	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = -0.15
	mi.set_surface_override_material(0, grass_mat)
	add_child(mi)

	var sb = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(200, 0.3, 200)
	cs.shape = shape
	sb.add_child(cs)
	sb.position.y = -0.15
	add_child(sb)


func _build_track() -> void:
	# Recolectar waypoints y pasarlos al track builder (circuito cerrado)
	var pts: PackedVector3Array = []
	for child in waypoints.get_children():
		if child is Node3D:
			pts.append(child.global_position)

	track_builder.set_points(pts, true)  # true = loop


func _add_props() -> void:
	# Árboles low-poly distribuidos fuera de la pista
	var tree_positions = [
		Vector3(70, 0, 0), Vector3(-70, 0, 10), Vector3(0, 0, 75),
		Vector3(0, 0, -75), Vector3(65, 0, 60), Vector3(-65, 0, -60),
		Vector3(65, 0, -60), Vector3(-65, 0, 60),
		Vector3(80, 0, 30), Vector3(-80, 0, -30), Vector3(30, 0, 80),
		Vector3(-30, 0, -80), Vector3(55, 0, -70), Vector3(-55, 0, 70),
	]
	for pos in tree_positions:
		_spawn_tree(pos)

	# Montañas de fondo (decoración)
	_spawn_mountain(Vector3(120, 0, 0), Vector3(40, 30, 30))
	_spawn_mountain(Vector3(-120, 0, 20), Vector3(35, 25, 40))
	_spawn_mountain(Vector3(40, 0, 130), Vector3(50, 35, 30))
	_spawn_mountain(Vector3(-50, 0, -130), Vector3(45, 28, 35))


func _spawn_tree(pos: Vector3) -> void:
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.22, 0.12, 1)
	trunk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var leaf_mat = StandardMaterial3D.new()
	# Variación de color para naturalidad
	leaf_mat.albedo_color = Color(
		randf_range(0.15, 0.25),
		randf_range(0.45, 0.65),
		randf_range(0.1, 0.2),
		1
	)
	leaf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var root = Node3D.new()
	root.position = pos + Vector3(0, 0.0, 0)
	root.rotation.y = randf_range(0, TAU)
	var scale_v = randf_range(0.7, 1.4)
	root.scale = Vector3(scale_v, scale_v, scale_v)

	# Tronco
	var trunk = MeshInstance3D.new()
	var t_mesh = CylinderMesh.new()
	t_mesh.top_radius = 0.12
	t_mesh.bottom_radius = 0.18
	t_mesh.height = 1.8
	trunk.mesh = t_mesh
	trunk.position.y = 0.9
	trunk.set_surface_override_material(0, trunk_mat)

	# Copa (pirámide = prism low-poly)
	var leaves = MeshInstance3D.new()
	var l_mesh = CylinderMesh.new()
	l_mesh.top_radius = 0.0
	l_mesh.bottom_radius = 1.4
	l_mesh.height = 3.0
	l_mesh.radial_segments = 5  # Pentagonal = low-poly
	leaves.mesh = l_mesh
	leaves.position.y = 3.2
	leaves.set_surface_override_material(0, leaf_mat)

	root.add_child(trunk)
	root.add_child(leaves)
	add_child(root)


func _spawn_mountain(pos: Vector3, size: Vector3) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(
		randf_range(0.35, 0.5),
		randf_range(0.38, 0.52),
		randf_range(0.38, 0.52),
		1
	)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = size.x * 0.5
	mesh.height = size.y
	mesh.radial_segments = 6  # Hexagonal = montaña low-poly

	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos + Vector3(0, size.y * 0.5, 0)
	mi.set_surface_override_material(0, mat)
	add_child(mi)
