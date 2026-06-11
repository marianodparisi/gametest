extends Node3D

@onready var track_builder = $TrackBuilder
@onready var waypoints_node = $Waypoints


func _ready() -> void:
	_build_terrain()
	_build_track()
	_add_props()


func _build_terrain() -> void:
	var sand_mat = StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.85, 0.72, 0.5, 1)

	var mesh = BoxMesh.new()
	mesh.size = Vector3(220, 0.3, 220)

	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = -0.15
	mi.set_surface_override_material(0, sand_mat)
	add_child(mi)

	var sb = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = mesh.size
	cs.shape = shape
	sb.add_child(cs)
	sb.position.y = -0.15
	add_child(sb)


func _build_track() -> void:
	var pts: PackedVector3Array = []
	for child in waypoints_node.get_children():
		if child is Node3D:
			pts.append(child.global_position)
	track_builder.set_points(pts, true)


func _add_props() -> void:
	# Cactus
	var cactus_spots = [
		Vector3(75, 0, -20), Vector3(-70, 0, 30), Vector3(20, 0, 80),
		Vector3(-15, 0, -80), Vector3(70, 0, 50), Vector3(-65, 0, -55),
		Vector3(80, 0, 20), Vector3(-80, 0, -10), Vector3(40, 0, -80),
		Vector3(-45, 0, 75), Vector3(0, 0, 90), Vector3(5, 0, -32),
	]
	for pos in cactus_spots:
		_spawn_prop("res://assets/props/cactus.glb", pos)

	# Dunas de fondo
	_spawn_dune(Vector3(130, 0, 0), 60.0, 18.0)
	_spawn_dune(Vector3(-130, 0, 40), 55.0, 14.0)
	_spawn_dune(Vector3(30, 0, 140), 70.0, 20.0)
	_spawn_dune(Vector3(-60, 0, -140), 65.0, 16.0)

	# Rocas desérticas
	for pos in [Vector3(60, 0, -55), Vector3(-55, 0, 60), Vector3(35, 0, 70), Vector3(-30, 0, -65)]:
		_spawn_prop("res://assets/props/rock.glb", pos, 1.2)


func _spawn_dune(pos: Vector3, radius: float, height: float) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(
		randf_range(0.8, 0.9), randf_range(0.66, 0.74), randf_range(0.45, 0.55), 1
	)

	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = height * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4

	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos + Vector3(0, -height * 0.4, 0)
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

