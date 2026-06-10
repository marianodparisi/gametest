@tool
extends Node3D

# Genera la malla de la pista y sus colliders a partir de control points.
# Agregar como hijo de un stage y llamar build() desde el inspector o en _ready().

@export var road_width: float = 10.0
@export var road_height: float = 0.25
@export var curb_width: float = 0.8
@export var road_color: Color = Color(0.22, 0.22, 0.24, 1)
@export var curb_color_a: Color = Color(0.95, 0.95, 0.95, 1)
@export var curb_color_b: Color = Color(0.85, 0.15, 0.15, 1)
@export var grass_color: Color = Color(0.28, 0.48, 0.22, 1)

# Control points de la pista — se editan desde el editor moviendo los hijos Node3D
# O se pueden pasar por código con set_points()
var _control_points: PackedVector3Array = []
var _is_loop: bool = false


func set_points(points: PackedVector3Array, loop: bool = false) -> void:
	_control_points = points
	_is_loop = loop
	_build()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Auto-build desde hijos Node3D si no se llamó set_points()
	if _control_points.is_empty():
		_collect_children_as_points()
	if not _control_points.is_empty():
		_build()


func _collect_children_as_points() -> void:
	_control_points.clear()
	for child in get_children():
		if child is Node3D and child.name.begins_with("CP"):
			_control_points.append(child.global_position)


func _build() -> void:
	# Limpiar meshes anteriores
	for child in get_children():
		if child.name.begins_with("_track_"):
			child.queue_free()

	if _control_points.size() < 2:
		return

	var pts = _catmull_rom_subdivide(_control_points, 8, _is_loop)

	_build_road_mesh(pts)
	_build_collision(pts)
	_build_barriers(pts)


# --- Catmull-Rom spline para suavizar los control points ---

func _catmull_rom_subdivide(pts: PackedVector3Array, subdivisions: int, loop: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var n = pts.size()

	for i in (n if loop else n - 1):
		var p0 = pts[(i - 1 + n) % n]
		var p1 = pts[i]
		var p2 = pts[(i + 1) % n]
		var p3 = pts[(i + 2) % n]

		for j in subdivisions:
			var t = float(j) / float(subdivisions)
			result.append(_catmull_rom(p0, p1, p2, p3, t))

	if not loop:
		result.append(pts[n - 1])

	return result


func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 = t * t
	var t3 = t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


# --- Mesh de la pista ---

func _build_road_mesh(pts: PackedVector3Array) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mat_road = StandardMaterial3D.new()
	mat_road.albedo_color = road_color
	mat_road.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mat_curb = StandardMaterial3D.new()
	mat_curb.albedo_color = curb_color_a
	mat_curb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var n = pts.size()
	for i in n - 1:
		var a = pts[i]
		var b = pts[i + 1]
		var forward = (b - a).normalized()
		var right = forward.cross(Vector3.UP).normalized()

		var half = road_width * 0.5
		var al = a - right * half
		var ar = a + right * half
		var bl = b - right * half
		var br = b + right * half

		# Quad de asfalto
		_add_quad(st, al, ar, br, bl)

		# Bordillo alternado cada 4 segmentos (rojo/blanco)
		var curb_col = curb_color_a if (i / 4) % 2 == 0 else curb_color_b
		mat_curb.albedo_color = curb_col

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "_track_road"
	mesh_inst.mesh = st.commit()
	mesh_inst.set_surface_override_material(0, mat_road)
	add_child(mesh_inst)


func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal = Vector3.UP
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)

	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(c)
	st.set_normal(normal)
	st.add_vertex(d)


# --- Collision trimesh de la pista ---

func _build_collision(pts: PackedVector3Array) -> void:
	var static_body = StaticBody3D.new()
	static_body.name = "_track_collision"

	var n = pts.size()
	for i in n - 1:
		var a = pts[i]
		var b = pts[i + 1]
		var forward = (b - a).normalized()
		var right = forward.cross(Vector3.UP).normalized()
		var half = road_width * 0.5

		# Box shape por segmento
		var seg_len = a.distance_to(b)
		var center = (a + b) * 0.5

		var shape = BoxShape3D.new()
		shape.size = Vector3(road_width + curb_width * 2, road_height, seg_len)

		var col = CollisionShape3D.new()
		col.shape = shape

		var seg_body = StaticBody3D.new()
		seg_body.position = center
		seg_body.basis = Basis.looking_at(forward, Vector3.UP)
		seg_body.add_child(col)
		static_body.add_child(seg_body)

	add_child(static_body)


# --- Barreras laterales ---

func _build_barriers(pts: PackedVector3Array) -> void:
	var barriers = Node3D.new()
	barriers.name = "_track_barriers"

	var mat_barrier = StandardMaterial3D.new()
	mat_barrier.albedo_color = Color(0.9, 0.9, 0.9, 1)
	mat_barrier.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var n = pts.size()
	for i in n - 1:
		var a = pts[i]
		var b = pts[i + 1]
		var forward = (b - a).normalized()
		var right = forward.cross(Vector3.UP).normalized()
		var half = (road_width * 0.5) + curb_width
		var seg_len = a.distance_to(b)
		var center = (a + b) * 0.5

		for side in [-1, 1]:
			var barrier_center = center + right * half * side
			barrier_center.y += 0.5

			var mesh = BoxMesh.new()
			mesh.size = Vector3(0.4, 1.0, seg_len)

			var mi = MeshInstance3D.new()
			mi.mesh = mesh
			mi.set_surface_override_material(0, mat_barrier)

			var sb = StaticBody3D.new()
			var cs = CollisionShape3D.new()
			var bshape = BoxShape3D.new()
			bshape.size = mesh.size
			cs.shape = bshape
			sb.add_child(cs)
			sb.add_child(mi)

			sb.position = barrier_center
			sb.basis = Basis.looking_at(forward, Vector3.UP)
			barriers.add_child(sb)

	add_child(barriers)
