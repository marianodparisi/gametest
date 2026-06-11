extends RigidBody3D

const CarBodyBuilder = preload("res://scripts/car/car_body_builder.gd")

# --- Parámetros del auto (ajustables en el inspector) ---

@export_group("Motor")
@export var engine_force: float = 9000.0
@export var max_speed_kmh: float = 160.0      # Límite suave, no hardcoded
@export var drag_linear: float = 0.35         # Resistencia del aire (terminal ~150 km/h)
@export var drag_angular: float = 2.2         # Frena la rotación libre

@export_group("Frenos")
@export var brake_force: float = 14000.0
@export var handbrake_grip: float = 0.25      # Grip trasero durante freno de mano (muy bajo = drift fácil)
@export var handbrake_kick: float = 9000.0    # Torque extra de giro con freno de mano (el "flick" del drift)

@export_group("Dirección")
@export var max_steer_angle: float = 32.0     # Grados máximos de giro
@export var steer_speed: float = 6.0          # Qué tan rápido giran las ruedas delanteras

@export_group("Jugador")
@export var player_index: int = 0             # 0 = P1 (WASD), 1 = P2 (Flechas), -1 = IA
@export var controls_enabled: bool = true     # false durante el countdown

# --- Grip por eje (el núcleo del drift) ---
@export_group("Física")
@export var front_grip: float = 4.0
@export var rear_grip: float = 1.8            # Menor que front = sobreviraje = drift

# --- Nodos de ruedas (se asignan automáticamente) ---
@onready var wheel_fl: Node = $Wheels/FrontLeft
@onready var wheel_fr: Node = $Wheels/FrontRight
@onready var wheel_rl: Node = $Wheels/RearLeft
@onready var wheel_rr: Node = $Wheels/RearRight

# Input actual (puede ser sobreescrito por ai_driver.gd)
var input_throttle: float = 0.0
var input_steer: float = 0.0
var input_brake: float = 0.0
var input_handbrake: bool = false

var _current_steer: float = 0.0  # Steer suavizado para que no sea abrupto


func _ready() -> void:
	# Aplicar grip inicial a cada rueda
	_apply_grip_to_wheels()


# Modelos Blender (.glb). Si falta alguno, cae al builder procedural.
const CAR_MODELS = [
	"res://assets/cars/car_0_rally_hatch.glb",
	"res://assets/cars/car_1_muscle.glb",
	"res://assets/cars/car_2_buggy.glb",
	"res://assets/cars/car_3_classic.glb",
	"res://assets/cars/car_4_van.glb",
	"res://assets/cars/car_5_wedge.glb",
]


func set_style(style: int) -> void:
	var path = CAR_MODELS[style % CAR_MODELS.size()]
	var scene = load(path) if ResourceLoader.exists(path) else null
	if scene == null:
		CarBodyBuilder.build($CarMesh, style)
		return
	for child in $CarMesh.get_children():
		child.queue_free()
	var inst = scene.instantiate()
	$CarMesh.add_child(inst)


func set_color(color: Color) -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.35
	mat.metallic = 0.15

	# Modelos glb: pintar superficies cuyo material se llama "Paint"
	if _paint_by_material_name($CarMesh, mat):
		return

	# Fallback: partes del builder procedural o de la escena default
	for child in $CarMesh.get_children():
		if child.has_meta("paintable"):
			child.set_surface_override_material(0, mat)
	for part in ["Body", "Hood", "SpoilerWing"]:
		var mesh = $CarMesh.get_node_or_null(part)
		if mesh:
			mesh.set_surface_override_material(0, mat)


func _paint_by_material_name(node: Node, mat: StandardMaterial3D) -> bool:
	var painted := false
	if node is MeshInstance3D and node.mesh:
		for s in node.mesh.get_surface_count():
			var m = node.mesh.surface_get_material(s)
			if m and m.resource_name.begins_with("Paint"):
				node.set_surface_override_material(s, mat)
				painted = true
	for child in node.get_children():
		if _paint_by_material_name(child, mat):
			painted = true
	return painted


func _apply_grip_to_wheels() -> void:
	wheel_fl.grip = front_grip
	wheel_fr.grip = front_grip
	wheel_rl.grip = rear_grip
	wheel_rr.grip = rear_grip

	# Cada rueda soporta un cuarto de la masa (para escalar el grip lateral)
	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		w.mass_share = mass / 4.0

	# Durante freno de mano, el grip trasero baja aún más (se aplica en _physics_process)
	wheel_fl.is_steering = true
	wheel_fr.is_steering = true
	wheel_rl.is_driven = true
	wheel_rr.is_driven = true


func _physics_process(delta: float) -> void:
	_read_player_input()
	if not controls_enabled:
		input_throttle = 0.0
		input_brake = 1.0  # Freno activo en la grilla
		input_steer = 0.0
		input_handbrake = false
	_update_steering(delta)
	_apply_forces(delta)
	_apply_drag()


func _read_player_input() -> void:
	# Solo lee input si es un jugador humano (no IA)
	if player_index < 0:
		return

	var prefix = "" if player_index == 0 else "_p2"

	input_throttle = Input.get_action_strength("throttle" + prefix)
	input_brake = Input.get_action_strength("brake" + prefix)
	input_steer = (
		Input.get_action_strength("steer_right" + prefix)
		- Input.get_action_strength("steer_left" + prefix)
	)
	input_handbrake = Input.is_action_pressed("handbrake" + prefix)


func _update_steering(delta: float) -> void:
	# Steer se interpola suavemente para evitar giros abruptos
	_current_steer = lerp(_current_steer, input_steer, steer_speed * delta)

	# Negativo: rotation.y positivo gira a la izquierda, steer positivo = derecha
	var steer_rad = deg_to_rad(max_steer_angle * -_current_steer)
	wheel_fl.rotation.y = steer_rad
	wheel_fr.rotation.y = steer_rad


func _apply_forces(delta: float) -> void:
	# Grip trasero baja durante freno de mano para facilitar el drift
	var effective_rear_grip = handbrake_grip if input_handbrake else rear_grip
	wheel_rl.grip = effective_rear_grip
	wheel_rr.grip = effective_rear_grip

	# Kick de rotación con freno de mano: inicia el drift con un golpe de giro
	if input_handbrake and linear_velocity.length() > 5.0 and absf(input_steer) > 0.1:
		apply_torque(Vector3.UP * -input_steer * handbrake_kick)

	var all_wheels = [wheel_fl, wheel_fr, wheel_rl, wheel_rr]

	for wheel in all_wheels:
		# Suspensión
		var susp = wheel.get_suspension_force(delta)
		apply_force(susp, wheel.global_position - global_position)

		# Grip lateral (lo que genera drift)
		var lat = wheel.get_lateral_force(linear_velocity)
		apply_force(lat, wheel.global_position - global_position)

		# Motor y frenos (la potencia se divide entre las 2 ruedas motrices)
		var throttle_scaled = input_throttle * engine_force * 0.5
		var brake_scaled = input_brake * brake_force * 0.25
		var longi = wheel.get_longitudinal_force(throttle_scaled, brake_scaled, input_handbrake, linear_velocity)
		apply_force(longi, wheel.global_position - global_position)


func _apply_drag() -> void:
	# Drag lineal — sin esto el auto no tiene velocidad máxima natural
	linear_velocity -= linear_velocity * drag_linear * get_physics_process_delta_time()

	# Drag angular — evita que el auto rote indefinidamente
	angular_velocity -= angular_velocity * drag_angular * get_physics_process_delta_time()


# --- API pública para la IA (ai_driver.gd llama esto en vez de leer input) ---

func set_ai_input(throttle: float, steer: float, brake: float, handbrake: bool = false) -> void:
	input_throttle = clamp(throttle, 0.0, 1.0)
	input_steer = clamp(steer, -1.0, 1.0)
	input_brake = clamp(brake, 0.0, 1.0)
	input_handbrake = handbrake


func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6
