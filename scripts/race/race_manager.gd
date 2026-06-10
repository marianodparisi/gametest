extends Node

# Orquesta la carrera: spawna autos, trackea posiciones, detecta fin

@export var car_scene: PackedScene
@export var total_laps: int = 3
@export var is_circuit: bool = true  # false = stage lineal A→B

signal race_started
signal position_changed(car_index: int, position: int)
signal race_finished(results: Array)

var cars: Array[RigidBody3D] = []
var car_data: Array[Dictionary] = []
# car_data[i] = { laps, checkpoint, distance_to_next, finished, finish_time }

var _waypoints: Array[Node3D] = []
var _race_time: float = 0.0
var _race_running: bool = false
var _finished_count: int = 0


func _ready() -> void:
	_load_waypoints()


func _load_waypoints() -> void:
	_waypoints.clear()
	var wp_container = get_node_or_null("../Waypoints")
	if wp_container:
		for child in wp_container.get_children():
			if child is Node3D:
				_waypoints.append(child)


func start_race(spawned_cars: Array) -> void:
	cars.clear()
	car_data.clear()

	for car in spawned_cars:
		cars.append(car)
		car_data.append({
			"laps": 0,
			"checkpoint": 0,
			"distance_to_next": 0.0,
			"finished": false,
			"finish_time": 0.0,
			"position": 0,
			"lap_start": 0.0,
			"last_lap": -1.0,
			"best_lap": -1.0,
		})

	_race_running = true
	_race_time = 0.0
	emit_signal("race_started")


func _physics_process(delta: float) -> void:
	if not _race_running:
		return
	_race_time += delta
	_update_checkpoints()
	_update_positions()


func _update_checkpoints() -> void:
	if _waypoints.is_empty():
		return

	for i in cars.size():
		if car_data[i]["finished"]:
			continue

		var car = cars[i]
		var cp_index = car_data[i]["checkpoint"]
		var next_wp = _waypoints[cp_index % _waypoints.size()]
		var dist = car.global_position.distance_to(next_wp.global_position)

		car_data[i]["distance_to_next"] = dist

		if dist < 7.0:
			car_data[i]["checkpoint"] += 1

			# Completó una vuelta
			if car_data[i]["checkpoint"] % _waypoints.size() == 0:
				car_data[i]["laps"] += 1
				var lap_time = _race_time - car_data[i]["lap_start"]
				car_data[i]["last_lap"] = lap_time
				car_data[i]["lap_start"] = _race_time
				if car_data[i]["best_lap"] < 0 or lap_time < car_data[i]["best_lap"]:
					car_data[i]["best_lap"] = lap_time

				if is_circuit and car_data[i]["laps"] >= total_laps:
					_finish_car(i)
				elif not is_circuit and car_data[i]["checkpoint"] >= _waypoints.size():
					_finish_car(i)


func _finish_car(index: int) -> void:
	car_data[index]["finished"] = true
	car_data[index]["finish_time"] = _race_time
	_finished_count += 1

	# La carrera termina cuando todos los JUGADORES humanos llegan
	# (no esperamos a las IA — quedan como DNF si no terminaron)
	var players_done = true
	for i in min(GameState.player_count, cars.size()):
		if not car_data[i]["finished"]:
			players_done = false
			break

	if players_done or _finished_count >= cars.size():
		_race_running = false
		emit_signal("race_finished", _build_results())


func _update_positions() -> void:
	# Ordenar por: laps desc, checkpoint desc, distancia asc
	var order = range(cars.size())
	order.sort_custom(func(a, b):
		var da = car_data[a]
		var db = car_data[b]
		if da["finished"] != db["finished"]:
			return da["finished"]  # terminados primero
		if da["laps"] != db["laps"]:
			return da["laps"] > db["laps"]
		if da["checkpoint"] != db["checkpoint"]:
			return da["checkpoint"] > db["checkpoint"]
		return da["distance_to_next"] < db["distance_to_next"]
	)

	for pos in order.size():
		car_data[order[pos]]["position"] = pos + 1


func get_position(car_index: int) -> int:
	if car_index >= car_data.size():
		return 0
	return car_data[car_index]["position"]


func get_lap(car_index: int) -> int:
	if car_index >= car_data.size():
		return 0
	return car_data[car_index]["laps"] + 1


func get_race_time() -> float:
	return _race_time


func get_last_lap(car_index: int) -> float:
	if car_index >= car_data.size():
		return -1.0
	return car_data[car_index]["last_lap"]


func get_best_lap(car_index: int) -> float:
	if car_index >= car_data.size():
		return -1.0
	return car_data[car_index]["best_lap"]


func _build_results() -> Array:
	var results = []
	for i in cars.size():
		results.append({
			"car_index": i,
			"position": car_data[i]["position"],
			"finish_time": car_data[i]["finish_time"],
		})
	results.sort_custom(func(a, b): return a["position"] < b["position"])
	return results
