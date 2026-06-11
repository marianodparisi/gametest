@tool
extends Node3D

# Genera la pista desde control points con spline Catmull-Rom.
# Usa "miter joints": el perpendicular de cada punto promedia los segmentos
# adyacentes, así los quads comparten bordes (sin tajos) y las barreras
# siguen el borde real de la pista (no la cruzan en curvas).

@export var road_width: float = 10.0
@export var road_color: Color = Color(0.25, 0.25, 0.28, 1)
@export var barrier_color: Color = Color(0.92, 0.92, 0.92, 1)

var _control_points: PackedVector3Array = []
var _is_loop: bool = false


func set_points(points: PackedVector3Array, loop: bool = false) -> void:
	_control_points = points
	_is_loop = loop
	_build()


func _build() -> void:
	for child in get_children():
		if child.name.begins_with("_track_"):
			child.queue_free()

	if _control_points.size() < 2:
		return

	var pts = _catmull_rom_subdivide(_control_points, 8, _is_loop)
	var lift = Vector3(0, 0.08, 0)
	for i in pts.size():
		pts[i] += lift

	# Perpendicular por punto (miter): promedia dirección entrante y saliente
	var rights: Array[Vector3] = []
	var n = pts.size()
	for i in n:
		var dir_in: Vector3
		var dir_out: Vector3
		if _is_loop:
			dir_in = pts[i] - pts[(i - 1 + n) % n]
			dir_out = pts[(i + 1) % n] - pts[i]
		else:
			dir_in = pts[i] - pts[max(i - 1, 0)] if i > 0 else pts[1] - pts[0]
			dir_out = pts[min(i + 1, n - 1)] - pts[i] if i < n - 1 else pts[n - 1] - pts[n - 2]
		var avg = (dir_in.normalized() + dir_out.normalized())
		if avg.length() < 0.001:
			avg = dir_out
		avg.y = 0
		rights.append(avg.normalized().cross(Vector3.UP).normalized())

	_build_road(pts, rights)
	_build_barriers(pts, rights)


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
		(2.0 * p1) + (-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _build_road(pts: PackedVector3Array, rights: Array[Vector3]) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n = pts.size()
	var half = road_width * 0.5
	var seg_count = n if _is_loop else n - 1

	for i in seg_count:
		var j = (i + 1) % n
		var al = pts[i] - rights[i] * half
		var ar = pts[i] + rights[i] * half
		var bl = pts[j] - rights[j] * half
		var br = pts[j] + rights[j] * half
		_add_quad(st, al, ar, br, bl)

	st.generate_normals()
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "_track_road"
	mesh_inst.mesh = st.commit()

	var mat = StandardMaterial3D.new()
	mat.albedo_color = road_color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.set_surface_override_material(0, mat)
	add_child(mesh_inst)

	# Colisión exacta de la calzada (trimesh del mismo mesh)
	var body = StaticBody3D.new()
	body.name = "_track_road_col"
	var col = CollisionShape3D.new()
	col.shape = mesh_inst.mesh.create_trimesh_shape()
	body.add_child(col)
	add_child(body)


func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# Winding horario visto desde arriba
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)
	st.add_vertex(a)
	st.add_vertex(d)
	st.add_vertex(c)


func _build_barriers(pts: PackedVector3Array, rights: Array[Vector3]) -> void:
	var barriers = Node3D.new()
	barriers.name = "_track_barriers"

	var mat = StandardMaterial3D.new()
	mat.albedo_color = barrier_color

	var n = pts.size()
	var seg_count = n if _is_loop else n - 1
	var offset = road_width * 0.5 + 1.2  # 1.2m de banquina antes de la barrera

	for i in seg_count:
		var j = (i + 1) % n
		for side in [-1.0, 1.0]:
			var a = pts[i] + rights[i] * offset * side
			var b = pts[j] + rights[j] * offset * side
			var seg_vec = b - a
			var seg_len = seg_vec.length()
			if seg_len < 0.1:
				continue
			var center = (a + b) * 0.5 + Vector3(0, 0.45, 0)

			var mesh = BoxMesh.new()
			mesh.size = Vector3(0.35, 0.9, seg_len + 0.3)  # +0.3 solapa juntas

			var mi = MeshInstance3D.new()
			mi.mesh = mesh
			mi.set_surface_override_material(0, mat)

			var sb = StaticBody3D.new()
			var cs = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = mesh.size
			cs.shape = shape
			sb.add_child(cs)
			sb.add_child(mi)

			sb.position = center
			sb.basis = Basis.looking_at(seg_vec.normalized(), Vector3.UP)
			barriers.add_child(sb)

	add_child(barriers)
