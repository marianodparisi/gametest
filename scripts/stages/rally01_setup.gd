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
		_spawn_prop("res://assets/props/pine.glb", pos, 1.3)

	# Rocas scattered
	var rock_spots = [
		Vector3(-8, 0, -18), Vector3(45, 2, -70), Vector3(78, 3.5, -10),
		Vector3(72, 6, 75), Vector3(-20, 7.5, 88), Vector3(-42, 8, 65),
	]
	for pos in rock_spots:
		_spawn_prop("res://assets/props/rock.glb", pos)




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

