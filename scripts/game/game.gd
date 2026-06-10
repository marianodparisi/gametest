extends Node

# Orquestador principal. Carga el stage, spawna autos, arma split-screen.
# Técnica: world_3d compartido entre SubViewports — un solo motor de física,
# dos cámaras que ven el mismo mundo.

const CAR_SCENE = preload("res://scenes/car/Car.tscn")
const CarBodyBuilder = preload("res://scripts/car/car_body_builder.gd")

@onready var vp1_container: SubViewportContainer = $Screen/Left/VPContainer
@onready var vp2_container: SubViewportContainer = $Screen/Right/VPContainer
@onready var vp1: SubViewport = $Screen/Left/VPContainer/VP1
@onready var vp2: SubViewport = $Screen/Right/VPContainer/VP2
@onready var right_panel: Control = $Screen/Right
@onready var hud_p1 = $HUD_P1
@onready var hud_p2 = $HUD_P2
@onready var countdown = $Countdown
@onready var results_screen = $ResultsScreen

var stage: Node3D = null
var cars: Array = []
var cam1: Camera3D
var cam2: Camera3D
var race_manager: Node = null
var ghost_system: Node = null

# Offsets de cámara (estilo Art of Rally — vista alta y levemente atrás)
# Paleta de autos: P1 amarillo, P2 celeste, IA en tonos variados
const CAR_COLORS = [
	Color(0.95, 0.8, 0.15),   # P1 — amarillo
	Color(0.3, 0.7, 0.95),    # P2 — celeste
	Color(0.85, 0.25, 0.2),   # CPU — rojo
	Color(0.9, 0.9, 0.92),    # CPU — blanco
	Color(0.25, 0.6, 0.3),    # CPU — verde
	Color(0.6, 0.35, 0.75),   # CPU — violeta
]

const CAM_OFFSET = Vector3(0, 4.5, 9.0)
const CAM_FOV = 65.0
const CAM_SMOOTH = 8.0

# Transform deseado para cada cámara (smoothed)
var _cam1_target: Transform3D
var _cam2_target: Transform3D


func _ready() -> void:
	var stage_path = GameState.selected_stage
	var player_count = GameState.player_count

	_load_stage(stage_path)
	_spawn_cars(player_count)
	_setup_cameras(player_count)
	_setup_huds(player_count)

	# Autos frenados en la grilla hasta el GO
	for car in cars:
		car.controls_enabled = false

	if race_manager:
		race_manager.race_finished.connect(_on_race_finished)

	# Ghost solo en time trial
	if GameState.time_trial and cars.size() > 0:
		ghost_system = load("res://scripts/race/ghost_system.gd").new()
		ghost_system.name = "GhostSystem"
		add_child(ghost_system)
		ghost_system.setup(cars[0], GameState.selected_stage, vp1)

	countdown.countdown_finished.connect(_on_countdown_done)
	countdown.start()


func _on_countdown_done() -> void:
	for car in cars:
		car.controls_enabled = true
	if race_manager:
		race_manager.start_race(cars)
	if ghost_system:
		ghost_system.start()


func _on_race_finished(results: Array) -> void:
	# Guardar récord del jugador 1
	for entry in results:
		if entry["car_index"] == 0 and entry["finish_time"] > 0:
			var is_record = GameState.record_time(GameState.selected_stage, entry["finish_time"])
			if ghost_system:
				ghost_system.stop_and_save(entry["finish_time"])
			results_screen.new_record = is_record
			break

	results_screen.show_results(results, GameState.player_count)


func _load_stage(path: String) -> void:
	var scene = load(path)
	if not scene:
		push_error("Stage not found: " + path)
		return

	stage = scene.instantiate()
	# El stage vive en VP1 para que sus objetos sean parte de ese world_3d
	vp1.add_child(stage)

	# VP2 comparte el mismo mundo físico — un solo motor de física para ambas pantallas
	vp2.world_3d = vp1.world_3d

	race_manager = stage.get_node_or_null("RaceManager")


func _spawn_cars(player_count: int) -> void:
	if not stage:
		return

	var grid = stage.get_node_or_null("GridStart")
	var wp_container = stage.get_node_or_null("Waypoints")

	var wp_list: Array[Node3D] = []
	if wp_container:
		for child in wp_container.get_children():
			if child is Node3D:
				wp_list.append(child)

	var total = player_count + GameState.ai_count
	for i in total:
		var car = CAR_SCENE.instantiate()
		vp1.add_child(car)  # Todos los autos viven en VP1's scene tree

		# Grilla de largada: 2 columnas
		var col = i % 2
		var row = i / 2
		var offset = Vector3((col - 0.5) * 2.6, 0.5, row * 4.5)
		var base_transform = grid.global_transform if grid else Transform3D()
		car.global_position = base_transform.origin + base_transform.basis * offset
		car.global_rotation = base_transform.basis.get_euler()

		var stage_data = GameState.STAGES.filter(
			func(s): return s["scene"] == GameState.selected_stage
		)
		var is_linear = stage_data.size() > 0 and stage_data[0]["type"] == "linear"

		if i < player_count:
			car.player_index = i
			# Desactivar la cámara interna del auto — usamos las cámaras del game orchestrator
			var internal_cam = car.get_node_or_null("Camera/Camera3D")
			if internal_cam:
				internal_cam.current = false
		else:
			car.player_index = -1
			var ai = load("res://scripts/car/ai_driver.gd").new()
			ai.name = "AIDriver"
			var diff_range = GameState.DIFFICULTY_RANGES[GameState.difficulty]
			ai.speed_factor = randf_range(diff_range[0], diff_range[1])
			ai.is_linear_stage = is_linear
			car.add_child(ai)
			ai.set_waypoints(wp_list)

		# Cada auto tiene modelo y stats propios
		var style = i % CarBodyBuilder.STYLE_NAMES.size()
		car.set_style(style)
		var stats = CarBodyBuilder.STYLE_STATS[style]
		car.engine_force *= stats["engine"]
		car.rear_grip = stats["rear_grip"]

		car.set_color(CAR_COLORS[i % CAR_COLORS.size()])
		cars.append(car)


func _setup_cameras(player_count: int) -> void:
	# Cámara P1 — vive en VP1
	cam1 = Camera3D.new()
	cam1.fov = CAM_FOV
	cam1.current = true
	vp1.add_child(cam1)

	if player_count == 1:
		# Pantalla completa: ocultar el panel derecho
		right_panel.hide()
		vp1_container.get_parent().custom_minimum_size = Vector2.ZERO
		return

	# Cámara P2 — vive en VP2, comparte el world_3d de VP1
	cam2 = Camera3D.new()
	cam2.fov = CAM_FOV
	cam2.current = true
	vp2.add_child(cam2)

	# Inicializar targets
	if cars.size() > 0:
		_cam1_target = _get_camera_target(cars[0])
		cam1.global_transform = _cam1_target
	if cars.size() > 1:
		_cam2_target = _get_camera_target(cars[1])
		cam2.global_transform = _cam2_target


func _setup_huds(player_count: int) -> void:
	if race_manager and cars.size() > 0:
		hud_p1.set_car(cars[0])
		hud_p1.race_manager = race_manager
		hud_p1.player_index = 0

	if player_count > 1 and cars.size() > 1:
		hud_p2.show()
		hud_p2.set_car(cars[1])
		hud_p2.race_manager = race_manager
		hud_p2.player_index = 1
	else:
		hud_p2.hide()


func _physics_process(delta: float) -> void:
	_sync_cameras(delta)


func _sync_cameras(delta: float) -> void:
	if cars.size() > 0 and is_instance_valid(cam1):
		_cam1_target = _get_camera_target(cars[0])
		cam1.global_transform = cam1.global_transform.interpolate_with(
			_cam1_target, CAM_SMOOTH * delta
		)

	if cam2 and cars.size() > 1 and is_instance_valid(cam2):
		_cam2_target = _get_camera_target(cars[1])
		cam2.global_transform = cam2.global_transform.interpolate_with(
			_cam2_target, CAM_SMOOTH * delta
		)


func _get_camera_target(car: RigidBody3D) -> Transform3D:
	# Cámara alta y atrás estilo Art of Rally
	var basis = car.global_transform.basis
	var pos = car.global_position + basis * CAM_OFFSET
	var t = Transform3D()
	t.origin = pos
	t = t.looking_at(car.global_position + Vector3(0, 0.5, 0), Vector3.UP)
	return t
