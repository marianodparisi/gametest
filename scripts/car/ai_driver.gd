extends Node

# IA simple por waypoints. Los waypoints se inyectan vía set_waypoints()
# o se toman del path si se configura en el editor.

@export var waypoints_path: NodePath
@export var speed_factor: float = 1.0   # 0.8 = fácil, 1.1 = agresivo
@export var lookahead: int = 2          # Waypoints adelante para anticipar curvas
@export var is_linear_stage: bool = false  # true = no loop en waypoints

var _car: RigidBody3D
var _waypoints: Array[Node3D] = []
var _current_wp: int = 0
var _finished: bool = false


func _ready() -> void:
	_car = get_parent()
	if not waypoints_path.is_empty():
		_load_from_path()


func set_waypoints(wps: Array[Node3D]) -> void:
	_waypoints = wps
	_current_wp = 0


func _load_from_path() -> void:
	var container = get_node_or_null(waypoints_path)
	if not container:
		return
	var wps: Array[Node3D] = []
	for child in container.get_children():
		if child is Node3D:
			wps.append(child)
	set_waypoints(wps)


func _physics_process(_delta: float) -> void:
	if _waypoints.is_empty() or _finished:
		_car.set_ai_input(0, 0, 0)
		return

	_advance_waypoint()

	var steer = _calculate_steer()
	var throttle = _calculate_throttle(steer)

	_car.set_ai_input(throttle * speed_factor, steer, 0.0)


func _advance_waypoint() -> void:
	if _current_wp >= _waypoints.size():
		return
	var dist = _car.global_position.distance_to(_waypoints[_current_wp].global_position)
	if dist < 6.5:
		_current_wp += 1
		if _current_wp >= _waypoints.size():
			if is_linear_stage:
				_finished = true
			else:
				_current_wp = 0


func _calculate_steer() -> float:
	if _current_wp >= _waypoints.size():
		return 0.0
	var target_index = min(_current_wp + lookahead, _waypoints.size() - 1)
	if not is_linear_stage:
		target_index = (_current_wp + lookahead) % _waypoints.size()

	var target = _waypoints[target_index].global_position
	var local_target = _car.global_transform.affine_inverse() * target
	var steer = local_target.x / (abs(local_target.x) + abs(local_target.z) + 0.001)
	return clamp(steer * 2.2, -1.0, 1.0)


func _calculate_throttle(steer: float) -> float:
	# Frenar en curvas cerradas
	var curve_penalty = abs(steer) * 0.55
	return clamp(1.0 - curve_penalty, 0.15, 1.0)
