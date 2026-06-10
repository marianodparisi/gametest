extends Node3D

# Spawna los 6 autos en la grilla de largada y arranca la carrera

@export var car_scene: PackedScene
@export var player_count: int = 2       # 1 o 2 jugadores humanos
@export var ai_count: int = 4
@export var grid_spacing: Vector3 = Vector3(2.5, 0, 4.5)  # separación en grilla

@onready var race_manager: Node = $RaceManager
@onready var waypoints: Node3D = $Waypoints

var cars: Array = []


func _ready() -> void:
	_spawn_cars()
	_setup_cameras()
	race_manager.start_race(cars)


func _spawn_cars() -> void:
	var total = player_count + ai_count
	var wp_list: Array[Node3D] = []
	for child in waypoints.get_children():
		if child is Node3D:
			wp_list.append(child)

	for i in total:
		var car = car_scene.instantiate()
		add_child(car)

		# Posición en grilla: 2 columnas
		var col = i % 2
		var row = i / 2
		var offset = Vector3(
			(col - 0.5) * grid_spacing.x,
			0.5,
			row * grid_spacing.z
		)
		car.global_position = $GridStart.global_position + offset
		car.global_rotation = $GridStart.global_rotation

		if i < player_count:
			car.player_index = i
		else:
			# IA
			car.player_index = -1
			var ai = load("res://scripts/car/ai_driver.gd").new()
			ai.speed_factor = randf_range(0.85, 1.05)  # variación entre autos
			car.add_child(ai)

			# Pasar waypoints a la IA
			var wp_array = wp_list
			ai.set_meta("_waypoints_array", wp_array)
			# La IA los toma en _ready via waypoints_path o directamente
			ai.set("_waypoints", wp_array)

		cars.append(car)


func _setup_cameras() -> void:
	if player_count == 1:
		# Cámara normal, sin split
		cars[0].get_node("Camera/Camera3D").current = true
		return

	# Split-screen: cada viewport muestra la cámara del jugador correspondiente
	# (configurado en la escena SplitScreen.tscn que instancia este stage)
	pass
