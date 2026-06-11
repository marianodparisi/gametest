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
	for i in tree_positions.size():
		var kind = "res://assets/props/tree.glb" if i % 2 == 0 else "res://assets/props/pine.glb"
		_spawn_prop(kind, tree_positions[i])

	# Montañas de fondo (decoración)
	_spawn_mountain(Vector3(120, 0, 0), Vector3(40, 30, 30))
	_spawn_mountain(Vector3(-120, 0, 20), Vector3(35, 25, 40))
	_spawn_mountain(Vector3(40, 0, 130), Vector3(50, 35, 30))
	_spawn_mountain(Vector3(-50, 0, -130), Vector3(45, 28, 35))


func _spawn_mountain(pos: Vector3, size: Vector3) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(
		randf_range(0.48, 0.58),
		randf_range(0.44, 0.52),
		randf_range(0.4, 0.48),
		1
	)

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

const PROP_SCALE_VAR = 0.35

func _spawn_prop(path: String, pos: Vector3, base_scale: float = 1.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var inst = load(path).instantiate()
	inst.position = pos
	inst.rotation.y = randf_range(0, TAU)
	var s = base_scale * randf_range(1.0 - PROP_SCALE_VAR, 1.0 + PROP_SCALE_VAR)
	inst.scale = Vector3(s, s, s)
	add_child(inst)

