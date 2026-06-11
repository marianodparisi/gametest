extends RayCast3D

# Parámetros exportables — ajustables desde el editor por rueda
@export var suspension_rest_length: float = 0.35
@export var suspension_stiffness: float = 20000.0   # Debe sostener ~300kg por rueda
@export var suspension_damping: float = 2000.0
@export var wheel_radius: float = 0.28
@export var grip: float = 4.0       # Reducir en ruedas traseras para drift
@export var is_driven: bool = false
@export var is_steering: bool = false

# Masa que soporta esta rueda (mass/4) — la asigna car_controller en _ready
var mass_share: float = 300.0

const WHEEL_MODEL = "res://assets/props/wheel.glb"

var _prev_compression: float = 0.0
var is_grounded: bool = false
var _mesh: Node3D = null


func _ready() -> void:
	# Usar el modelo Blender si existe; si no, el cilindro de la escena
	if ResourceLoader.exists(WHEEL_MODEL):
		for child in get_children():
			if child is MeshInstance3D:
				child.queue_free()
		var inst = load(WHEEL_MODEL).instantiate()
		add_child(inst)
		_mesh = inst
	else:
		for child in get_children():
			if child is MeshInstance3D:
				_mesh = child
				break


func _physics_process(_delta: float) -> void:
	# La rueda visual sigue la suspensión (cuelga hasta el punto de contacto)
	if _mesh == null:
		return
	var target_y: float
	if is_colliding():
		target_y = -(get_collision_point().distance_to(global_position) - wheel_radius)
	else:
		target_y = -suspension_rest_length
	_mesh.position.y = lerpf(_mesh.position.y, target_y, 0.5)


# Devuelve la fuerza de suspensión (resorte + amortiguador) en el eje Y local
func get_suspension_force(delta: float) -> Vector3:
	if not is_colliding():
		is_grounded = false
		_prev_compression = 0.0
		return Vector3.ZERO

	is_grounded = true

	var distance_to_ground = get_collision_point().distance_to(global_position)
	var compression = (suspension_rest_length + wheel_radius) - distance_to_ground
	compression = clamp(compression, 0.0, suspension_rest_length)

	var compression_velocity = (compression - _prev_compression) / delta
	_prev_compression = compression

	var spring = compression * suspension_stiffness
	var damper = compression_velocity * suspension_damping

	return global_transform.basis.y * maxf(spring + damper, 0.0)


# Fuerza lateral (lo que produce drift cuando grip es bajo).
# Escalada por mass_share: grip es una tasa de decaimiento (1/s) independiente de la masa.
func get_lateral_force(car_velocity: Vector3) -> Vector3:
	if not is_grounded:
		return Vector3.ZERO

	var wheel_right = global_transform.basis.x
	var lateral_velocity = car_velocity.dot(wheel_right)

	return -wheel_right * lateral_velocity * grip * mass_share


# Fuerza longitudinal (aceleración / freno)
func get_longitudinal_force(throttle_force: float, brake_force: float, handbrake_input: bool, car_velocity: Vector3) -> Vector3:
	if not is_grounded:
		return Vector3.ZERO

	var force = Vector3.ZERO
	var forward = -global_transform.basis.z

	if is_driven:
		force += forward * throttle_force

	# El freno se opone a la dirección de movimiento (no empuja hacia atrás)
	if brake_force > 0.0:
		var forward_speed = car_velocity.dot(forward)
		if absf(forward_speed) > 0.3:
			force -= forward * signf(forward_speed) * brake_force

	# Freno de mano: anula tracción en ruedas traseras para que patinen
	if handbrake_input and not is_steering:
		force = Vector3.ZERO

	return force


# Punto de contacto con el suelo (o posición estimada si no hay contacto)
var hit_point: Vector3:
	get:
		if is_colliding():
			return get_collision_point()
		return global_position - global_transform.basis.y * (suspension_rest_length + wheel_radius)
