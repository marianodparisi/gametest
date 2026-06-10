extends Node

# Ghost para Time Trial: graba la trayectoria del jugador y reproduce
# la mejor corrida anterior como un auto fantasma translúcido.

const SAMPLE_INTERVAL = 0.1  # Segundos entre muestras

var _car: RigidBody3D = null
var _recording: Array = []       # [[t, x, y, z, rot_y], ...]
var _playback: Array = []
var _ghost_node: Node3D = null
var _time: float = 0.0
var _sample_timer: float = 0.0
var _playback_index: int = 0
var _active: bool = false

var _stage_key: String = ""


func setup(car: RigidBody3D, stage_scene: String, parent_3d: Node) -> void:
	_car = car
	_stage_key = stage_scene.get_file().get_basename()
	_load_ghost()
	if not _playback.is_empty():
		_create_ghost_visual(parent_3d)


func start() -> void:
	_active = true
	_time = 0.0
	_sample_timer = 0.0
	_playback_index = 0
	_recording.clear()


func stop_and_save(finish_time: float) -> void:
	_active = false
	# Guardar solo si es la mejor corrida
	var best = GameState.get_best_time(GameState.selected_stage)
	if best < 0 or finish_time <= best:
		_save_ghost()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_record(delta)
	_play(delta)


func _record(delta: float) -> void:
	_sample_timer += delta
	if _sample_timer < SAMPLE_INTERVAL:
		return
	_sample_timer = 0.0
	var p = _car.global_position
	_recording.append([_time, p.x, p.y, p.z, _car.global_rotation.y])


func _play(_delta: float) -> void:
	if _ghost_node == null or _playback.is_empty():
		return

	# Avanzar al sample correspondiente al tiempo actual
	while _playback_index < _playback.size() - 1 and _playback[_playback_index + 1][0] < _time:
		_playback_index += 1

	if _playback_index >= _playback.size() - 1:
		return

	# Interpolar entre el sample actual y el siguiente
	var a = _playback[_playback_index]
	var b = _playback[_playback_index + 1]
	var span = b[0] - a[0]
	var t = 0.0 if span <= 0 else clamp((_time - a[0]) / span, 0.0, 1.0)

	var pos_a = Vector3(a[1], a[2], a[3])
	var pos_b = Vector3(b[1], b[2], b[3])
	_ghost_node.global_position = pos_a.lerp(pos_b, t)
	_ghost_node.global_rotation.y = lerp_angle(a[4], b[4], t)


func _create_ghost_visual(parent_3d: Node) -> void:
	_ghost_node = Node3D.new()
	_ghost_node.name = "Ghost"

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.85, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Carrocería fantasma simplificada
	var body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(1.6, 0.45, 3.6)
	body.mesh = body_mesh
	body.position.y = 0.35
	body.set_surface_override_material(0, mat)
	_ghost_node.add_child(body)

	var cabin = MeshInstance3D.new()
	var cabin_mesh = BoxMesh.new()
	cabin_mesh.size = Vector3(1.25, 0.38, 1.7)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0, 0.74, 0.25)
	cabin.set_surface_override_material(0, mat)
	_ghost_node.add_child(cabin)

	parent_3d.add_child(_ghost_node)


func _ghost_path() -> String:
	return "user://ghost_%s.json" % _stage_key


func _load_ghost() -> void:
	var path = _ghost_path()
	if not FileAccess.file_exists(path):
		return
	var f = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Array:
		_playback = data


func _save_ghost() -> void:
	var f = FileAccess.open(_ghost_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(_recording))
