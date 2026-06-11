extends Node

# IA por waypoints con control de velocidad en curvas y recuperación de choques.

@export var waypoints_path: NodePath
@export var speed_factor: float = 1.0      # 0.8 = fácil, 1.1 = agresivo
@export var lookahead: int = 1
@export var is_linear_stage: bool = false

# Velocidades objetivo (m/s) según cuánto hay que girar
const SPEED_STRAIGHT = 26.0
const SPEED_CORNER = 6.5

var _car: RigidBody3D
var _waypoints: Array[Node3D] = []
var _current_wp: int = 0
var _finished: bool = false

# Recuperación de choques
var _stuck_timer: float = 0.0
var _reversing: float = 0.0


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


func _physics_process(delta: float) -> void:
	if _waypoints.is_empty() or _finished:
		_car.set_ai_input(0, 0, 0)
		return

	# Marcha atrás de recuperación
	if _reversing > 0.0:
		_reversing -= delta
		# Retroceder girando al lado contrario del waypoint
		var steer_back = -_calculate_steer() * 0.7
		_car.set_ai_input(0.0, steer_back, 0.0, false)
		# Empuje en reversa directo (la física no tiene marcha atrás formal)
		var back_force = _car.global_transform.basis.z * 7000.0
		_car.apply_central_force(back_force)
		return

	_detect_stuck(delta)
	_advance_waypoint()

	var steer = _calculate_steer()
	var speed = _car.linear_velocity.length()

	# Velocidad objetivo según severidad de la curva
	var target_speed = lerpf(SPEED_STRAIGHT, SPEED_CORNER, absf(steer)) * speed_factor

	var throttle = 0.0
	var brake = 0.0
	if speed < target_speed:
		throttle = 1.0
	elif speed > target_speed * 1.1:
		brake = 0.8

	_car.set_ai_input(throttle, steer, brake)


func _detect_stuck(delta: float) -> void:
	# Si controls_enabled y velocidad ~0 durante 1.5s → quedó trabado
	if not _car.controls_enabled:
		_stuck_timer = 0.0
		return
	if _car.linear_velocity.length() < 1.0:
		_stuck_timer += delta
		if _stuck_timer > 1.5:
			_reversing = 1.5
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0


func _advance_waypoint() -> void:
	if _current_wp >= _waypoints.size():
		return
	var dist = _car.global_position.distance_to(_waypoints[_current_wp].global_position)
	if dist < 8.0:
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
	var steer = local_target.x / (absf(local_target.x) + absf(local_target.z) + 0.001)
	# Si el target quedó atrás (z positivo), girar a fondo hacia el lado correcto
	if local_target.z > 0.0:
		steer = signf(steer) if absf(steer) > 0.05 else 1.0
	return clampf(steer * 2.0, -1.0, 1.0)
