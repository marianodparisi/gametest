extends RayCast3D

# Parámetros exportables — ajustables desde el editor por rueda
@export var suspension_rest_length: float = 0.35
@export var suspension_stiffness: float = 900.0
@export var suspension_damping: float = 90.0
@export var wheel_radius: float = 0.28
@export var grip: float = 4.0       # Reducir en ruedas traseras para drift
@export var is_driven: bool = false  # true = esta rueda recibe potencia del motor
@export var is_steering: bool = false

var _prev_compression: float = 0.0
var is_grounded: bool = false

# Devuelve la fuerza de suspensión (resorte + amortiguador) en el eje Y local
func get_suspension_force(delta: float) -> Vector3:
	if not is_colliding():
		is_grounded = false
		_prev_compression = 0.0
		return Vector3.ZERO

	is_grounded = true

	# Distancia al suelo vs longitud en reposo
	var distance_to_ground = hit_point.distance_to(global_position)
	var compression = (suspension_rest_length + wheel_radius) - distance_to_ground
	compression = clamp(compression, 0.0, suspension_rest_length)

	# Velocidad de compresión para el amortiguador
	var compression_velocity = (compression - _prev_compression) / delta
	_prev_compression = compression

	var spring = compression * suspension_stiffness
	var damper = compression_velocity * suspension_damping

	return global_transform.basis.y * (spring + damper)


# Devuelve la fuerza lateral (lo que produce drift cuando grip es bajo)
func get_lateral_force(car_velocity: Vector3) -> Vector3:
	if not is_grounded:
		return Vector3.ZERO

	var wheel_right = global_transform.basis.x
	# Velocidad del auto proyectada sobre el eje lateral de la rueda
	var lateral_velocity = car_velocity.dot(wheel_right)

	return -wheel_right * lateral_velocity * grip


# Devuelve la fuerza longitudinal (aceleración / freno)
func get_longitudinal_force(throttle_input: float, brake_input: float, handbrake_input: bool) -> Vector3:
	if not is_grounded:
		return Vector3.ZERO

	var force = Vector3.ZERO
	var forward = -global_transform.basis.z

	if is_driven:
		force += forward * throttle_input

	if brake_input > 0.0:
		force -= forward * brake_input

	# Freno de mano: anula fuerza longitudinal para que la rueda patine
	if handbrake_input and not is_steering:
		force = Vector3.ZERO

	return force


# Punto de contacto con el suelo (o posición estimada si no hay contacto)
var hit_point: Vector3:
	get:
		if is_colliding():
			return get_collision_point()
		return global_position - global_transform.basis.y * (suspension_rest_length + wheel_radius)
