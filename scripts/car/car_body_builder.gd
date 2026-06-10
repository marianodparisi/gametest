extends RefCounted

# Genera carrocerías low-poly distintas por variante.
# Cada variante reconstruye los hijos de CarMesh manteniendo los nombres
# "Body", "Hood", "SpoilerWing" para que set_color() siga funcionando.

const GLASS_COLOR = Color(0.12, 0.14, 0.18, 1)
const LIGHT_COLOR = Color(1, 0.95, 0.7, 1)
const TAIL_COLOR = Color(0.9, 0.1, 0.1, 1)

const STYLE_NAMES = ["Rally Hatch", "Muscle", "Buggy", "Classic", "Van", "Wedge"]

# Stats por estilo: { engine: multiplicador de potencia, rear_grip: grip trasero }
# Balanceados: más potencia = menos grip (más difícil de controlar)
const STYLE_STATS = [
	{"engine": 1.0, "rear_grip": 1.8},    # Rally Hatch — balanceado
	{"engine": 1.15, "rear_grip": 1.5},   # Muscle — potente, derrapa mucho
	{"engine": 0.95, "rear_grip": 2.2},   # Buggy — ágil, agarra bien
	{"engine": 0.9, "rear_grip": 2.0},    # Classic — tranquilo
	{"engine": 0.85, "rear_grip": 2.4},   # Van — lento pero estable
	{"engine": 1.2, "rear_grip": 1.6},    # Wedge — el más rápido, exigente
]


static func build(car_mesh_root: Node3D, style: int) -> void:
	# Limpiar la carrocería default
	for child in car_mesh_root.get_children():
		child.queue_free()

	match style % 6:
		0: _build_rally_hatch(car_mesh_root)
		1: _build_muscle(car_mesh_root)
		2: _build_buggy(car_mesh_root)
		3: _build_classic(car_mesh_root)
		4: _build_van(car_mesh_root)
		5: _build_wedge(car_mesh_root)


# ── HELPERS ──────────────────────────────────────────────────────────────────

static func _mat(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, color: Color, rot_x: float = 0.0) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var mi = MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.x = rot_x
	mi.set_surface_override_material(0, _mat(color))
	if color == BASE:
		mi.set_meta("paintable", true)
	parent.add_child(mi)
	return mi


static func _prism(parent: Node3D, name: String, size: Vector3, pos: Vector3, color: Color, flip: bool = false) -> MeshInstance3D:
	var mesh = PrismMesh.new()
	mesh.size = size
	var mi = MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.position = pos
	if flip:
		mi.rotation.y = PI
	mi.set_surface_override_material(0, _mat(color))
	if color == BASE:
		mi.set_meta("paintable", true)
	parent.add_child(mi)
	return mi


static func _lights(parent: Node3D, front_z: float, rear_z: float, y: float = 0.42) -> void:
	for side in [-0.5, 0.5]:
		_box(parent, "HL%s" % side, Vector3(0.26, 0.12, 0.06), Vector3(side, y, front_z), LIGHT_COLOR)
		_box(parent, "TL%s" % side, Vector3(0.3, 0.1, 0.06), Vector3(side, y, rear_z), TAIL_COLOR)


# Placeholder rojo — game.gd lo pinta con set_color() después
const BASE = Color(0.8, 0.2, 0.2, 1)


# ── VARIANTE 0: RALLY HATCH (compacto, alerón grande) ────────────────────────

static func _build_rally_hatch(root: Node3D) -> void:
	_box(root, "Body", Vector3(1.6, 0.45, 3.2), Vector3(0, 0.35, 0), BASE)
	_box(root, "Hood", Vector3(1.45, 0.16, 0.8), Vector3(0, 0.58, -1.1), BASE, 0.12)
	_box(root, "Cabin", Vector3(1.3, 0.42, 1.8), Vector3(0, 0.76, 0.35), GLASS_COLOR)
	_box(root, "SpoilerWing", Vector3(1.55, 0.07, 0.4), Vector3(0, 0.95, 1.5), BASE)
	_box(root, "StrutL", Vector3(0.08, 0.3, 0.08), Vector3(-0.55, 0.75, 1.5), GLASS_COLOR)
	_box(root, "StrutR", Vector3(0.08, 0.3, 0.08), Vector3(0.55, 0.75, 1.5), GLASS_COLOR)
	_lights(root, -1.59, 1.59)


# ── VARIANTE 1: MUSCLE (capot largo, cola ducktail) ──────────────────────────

static func _build_muscle(root: Node3D) -> void:
	_box(root, "Body", Vector3(1.7, 0.42, 3.9), Vector3(0, 0.34, 0), BASE)
	_box(root, "Hood", Vector3(1.55, 0.14, 1.5), Vector3(0, 0.55, -1.0), BASE)
	_box(root, "Scoop", Vector3(0.5, 0.12, 0.6), Vector3(0, 0.66, -1.0), GLASS_COLOR)
	_box(root, "Cabin", Vector3(1.4, 0.36, 1.4), Vector3(0, 0.72, 0.55), GLASS_COLOR)
	_box(root, "SpoilerWing", Vector3(1.7, 0.1, 0.3), Vector3(0, 0.62, 1.85), BASE, -0.25)
	_lights(root, -1.94, 1.94)


# ── VARIANTE 2: BUGGY (abierto, rollbar) ─────────────────────────────────────

static func _build_buggy(root: Node3D) -> void:
	_box(root, "Body", Vector3(1.5, 0.4, 2.9), Vector3(0, 0.35, 0), BASE)
	_box(root, "Hood", Vector3(1.3, 0.14, 0.7), Vector3(0, 0.55, -1.0), BASE, 0.18)
	# Rollbar en lugar de cabina
	_box(root, "RollbarL", Vector3(0.1, 0.7, 0.1), Vector3(-0.55, 0.85, 0.4), GLASS_COLOR)
	_box(root, "RollbarR", Vector3(0.1, 0.7, 0.1), Vector3(0.55, 0.85, 0.4), GLASS_COLOR)
	_box(root, "RollbarTop", Vector3(1.25, 0.1, 0.1), Vector3(0, 1.22, 0.4), GLASS_COLOR)
	_box(root, "Seat", Vector3(0.9, 0.35, 0.5), Vector3(0, 0.65, 0.5), Color(0.2, 0.2, 0.22, 1))
	_box(root, "SpoilerWing", Vector3(1.2, 0.06, 0.25), Vector3(0, 0.6, 1.4), BASE)
	_lights(root, -1.44, 1.44)


# ── VARIANTE 3: CLASSIC (cabina alta, sin alerón) ────────────────────────────

static func _build_classic(root: Node3D) -> void:
	_box(root, "Body", Vector3(1.65, 0.5, 3.5), Vector3(0, 0.38, 0), BASE)
	_box(root, "Hood", Vector3(1.4, 0.2, 1.0), Vector3(0, 0.6, -1.2), BASE)
	_box(root, "Cabin", Vector3(1.35, 0.55, 1.6), Vector3(0, 0.9, 0.3), GLASS_COLOR)
	_box(root, "Trunk", Vector3(1.4, 0.18, 0.8), Vector3(0, 0.6, 1.3), BASE)
	# Alerón mínimo para mantener el nombre del nodo
	_box(root, "SpoilerWing", Vector3(0.01, 0.01, 0.01), Vector3(0, 0.3, 1.7), BASE)
	# Paragolpes cromados
	_box(root, "BumperF", Vector3(1.7, 0.12, 0.12), Vector3(0, 0.22, -1.78), Color(0.8, 0.8, 0.85, 1))
	_box(root, "BumperR", Vector3(1.7, 0.12, 0.12), Vector3(0, 0.22, 1.78), Color(0.8, 0.8, 0.85, 1))
	_lights(root, -1.74, 1.74, 0.5)


# ── VARIANTE 4: VAN (caja alta) ──────────────────────────────────────────────

static func _build_van(root: Node3D) -> void:
	_box(root, "Body", Vector3(1.7, 0.5, 3.6), Vector3(0, 0.38, 0), BASE)
	_box(root, "Box", Vector3(1.7, 0.85, 2.6), Vector3(0, 1.0, 0.4), BASE)
	_box(root, "Hood", Vector3(1.6, 0.3, 0.7), Vector3(0, 0.55, -1.55), BASE)
	_box(root, "Cabin", Vector3(1.6, 0.5, 0.1), Vector3(0, 1.05, -0.93), GLASS_COLOR)
	_box(root, "WindowL", Vector3(0.05, 0.4, 1.6), Vector3(-0.86, 1.1, 0.4), GLASS_COLOR)
	_box(root, "WindowR", Vector3(0.05, 0.4, 1.6), Vector3(0.86, 1.1, 0.4), GLASS_COLOR)
	_box(root, "SpoilerWing", Vector3(0.01, 0.01, 0.01), Vector3(0, 1.45, 1.7), BASE)
	_lights(root, -1.89, 1.79, 0.45)


# ── VARIANTE 5: WEDGE (supercar bajo y ancho) ────────────────────────────────

static func _build_wedge(root: Node3D) -> void:
	_box(root, "Body", Vector3(1.85, 0.32, 3.7), Vector3(0, 0.3, 0), BASE)
	# Nariz en cuña con prisma rotado
	var nose = _prism(root, "Hood", Vector3(1.7, 0.35, 1.3), Vector3(0, 0.48, -1.2), BASE)
	nose.rotation.x = deg_to_rad(90)
	_box(root, "Cabin", Vector3(1.35, 0.3, 1.3), Vector3(0, 0.6, 0.3), GLASS_COLOR)
	_box(root, "SpoilerWing", Vector3(1.85, 0.06, 0.45), Vector3(0, 0.78, 1.7), BASE)
	_box(root, "StrutL", Vector3(0.07, 0.25, 0.07), Vector3(-0.7, 0.6, 1.7), GLASS_COLOR)
	_box(root, "StrutR", Vector3(0.07, 0.25, 0.07), Vector3(0.7, 0.6, 1.7), GLASS_COLOR)
	_box(root, "Intake", Vector3(1.0, 0.1, 0.4), Vector3(0, 0.5, 1.2), GLASS_COLOR)
	_lights(root, -1.84, 1.84, 0.35)
