extends Node

# Suite de tests del juego. Correr con:
#   godot --headless res://tests/TestSuite.tscn   (lógica/física)
#   godot res://tests/TestSuite.tscn              (incluye render)
# Imprime PASS/FAIL por test y un resumen final.

const CarBodyBuilder = preload("res://scripts/car/car_body_builder.gd")
const CAR_SCENE = preload("res://scenes/car/Car.tscn")

var passed := 0
var failed := 0


func _ready() -> void:
	print("=== RALLY GAME TEST SUITE ===")

	_test_input_actions()
	_test_stages_structure()
	_test_car_styles()
	_test_leaderboard()
	_test_settings()
	await _test_car_physics()
	await _test_race_per_stage()

	print("=== RESULT: %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("PASS  %s" % name)
	else:
		failed += 1
		print("FAIL  %s %s" % [name, detail])


# ── TEST: acciones de input definidas ────────────────────────────────────────

func _test_input_actions() -> void:
	for action in ["throttle", "brake", "steer_left", "steer_right", "handbrake",
			"throttle_p2", "brake_p2", "steer_left_p2", "steer_right_p2", "handbrake_p2"]:
		_check("input:%s" % action, InputMap.has_action(action))
		if InputMap.has_action(action):
			var events = InputMap.action_get_events(action)
			_check("input:%s:has_key+pad" % action, events.size() >= 2,
				"(%d events)" % events.size())


# ── TEST: estructura de cada stage ───────────────────────────────────────────

func _test_stages_structure() -> void:
	for stage_info in GameState.STAGES:
		var sname = stage_info["name"]
		var scene = load(stage_info["scene"])
		_check("stage:%s:loads" % sname, scene != null)
		if scene == null:
			continue

		var inst = scene.instantiate()
		# Agregar al árbol para que los global_position sean válidos
		add_child(inst)

		var wps = inst.get_node_or_null("Waypoints")
		_check("stage:%s:waypoints" % sname, wps != null and wps.get_child_count() >= 3,
			"(%d wps)" % (wps.get_child_count() if wps else 0))

		var rm = inst.get_node_or_null("RaceManager")
		_check("stage:%s:race_manager" % sname, rm != null)
		if rm:
			var expected_circuit = stage_info["type"] == "circuit"
			_check("stage:%s:circuit_flag" % sname, rm.is_circuit == expected_circuit)

		_check("stage:%s:track_builder" % sname, inst.get_node_or_null("TrackBuilder") != null)

		# Waypoints consecutivos a distancia razonable (la IA puede seguirlos)
		if wps and wps.get_child_count() >= 3:
			var max_gap = 0.0
			var children = wps.get_children()
			for i in children.size():
				var j = (i + 1) % children.size()
				if stage_info["type"] == "linear" and j == 0:
					break
				max_gap = maxf(max_gap, children[i].global_position.distance_to(children[j].global_position))
			_check("stage:%s:wp_spacing" % sname, max_gap < 45.0, "(max gap %.0fm)" % max_gap)

		inst.queue_free()


# ── TEST: los 6 estilos de auto se construyen ────────────────────────────────

func _test_car_styles() -> void:
	for style in CarBodyBuilder.STYLE_NAMES.size():
		var car = CAR_SCENE.instantiate()
		add_child(car)
		car.set_style(style)
		car.set_color(Color.BLUE)

		# Debe tener al menos una parte pintable
		var paintable = 0
		for child in car.get_node("CarMesh").get_children():
			if child.has_meta("paintable"):
				paintable += 1
		_check("car:%s:paintable_parts" % CarBodyBuilder.STYLE_NAMES[style], paintable >= 1,
			"(%d parts)" % paintable)

		var stats = CarBodyBuilder.STYLE_STATS[style]
		_check("car:%s:stats_valid" % CarBodyBuilder.STYLE_NAMES[style],
			stats["engine"] > 0.5 and stats["rear_grip"] > 0.5)

		car.queue_free()


# ── TEST: leaderboard ────────────────────────────────────────────────────────

func _test_leaderboard() -> void:
	var key = "res://__test_stage__.tscn"
	GameState.best_times.erase(key)
	var r1 = GameState.record_time(key, 100.0)
	var r2 = GameState.record_time(key, 90.0)
	var r3 = GameState.record_time(key, 95.0)
	_check("leaderboard:first_is_record", r1 == true)
	_check("leaderboard:better_is_record", r2 == true)
	_check("leaderboard:worse_not_record", r3 == false)
	_check("leaderboard:best_correct", absf(GameState.get_best_time(key) - 90.0) < 0.01)
	# Limpiar
	GameState.best_times.erase(key)
	var f = FileAccess.open(GameState.TIMES_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(GameState.best_times))


# ── TEST: settings persisten ─────────────────────────────────────────────────

func _test_settings() -> void:
	var original = GameState.settings["music_volume"]
	GameState.settings["music_volume"] = 0.33
	GameState.save_settings()
	GameState.settings["music_volume"] = 0.99
	GameState._load_settings()
	_check("settings:persist", absf(GameState.settings["music_volume"] - 0.33) < 0.01)
	GameState.settings["music_volume"] = original
	GameState.save_settings()
	GameState.apply_settings()


# ── TEST: física del auto en plano abierto ───────────────────────────────────

func _test_car_physics() -> void:
	# Plano de prueba
	var world = Node3D.new()
	add_child(world)
	var floor_body = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(500, 1, 500)
	cs.shape = shape
	floor_body.add_child(cs)
	floor_body.position.y = -0.5
	world.add_child(floor_body)

	var car = CAR_SCENE.instantiate()
	world.add_child(car)
	car.player_index = -1  # Sin input de teclado
	car.global_position = Vector3(0, 0.6, 0)

	# Asentarse en la suspensión
	await get_tree().create_timer(1.0).timeout
	_check("physics:settles_upright", car.global_transform.basis.y.y > 0.95,
		"(up.y=%.2f)" % car.global_transform.basis.y.y)

	# Acelerar en línea recta 3s
	var t = 0.0
	while t < 3.0:
		car.set_ai_input(1.0, 0.0, 0.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	var straight_speed = car.linear_velocity.length()
	_check("physics:accelerates", straight_speed > 10.0, "(%.1f m/s)" % straight_speed)

	# Giro a la derecha 1.5s: debe rotar hacia la derecha (yaw negativo en Godot)
	var heading_before = car.global_rotation.y
	t = 0.0
	while t < 1.5:
		car.set_ai_input(0.6, 1.0, 0.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	var yaw_delta = wrapf(car.global_rotation.y - heading_before, -PI, PI)
	_check("physics:steers_right", yaw_delta < -0.15, "(yaw %.2f rad)" % yaw_delta)

	# Frenar hasta detenerse
	t = 0.0
	while t < 3.0:
		car.set_ai_input(0.0, 0.0, 1.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check("physics:brakes", car.linear_velocity.length() < 3.0,
		"(%.1f m/s)" % car.linear_velocity.length())

	# Drift: con freno de mano y giro, debe generar velocidad lateral
	t = 0.0
	while t < 2.5:
		car.set_ai_input(1.0, 0.0, 0.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	t = 0.0
	var max_lateral = 0.0
	while t < 1.5:
		car.set_ai_input(0.8, 1.0, 0.0, true)  # handbrake + giro
		var lateral = absf(car.linear_velocity.dot(car.global_transform.basis.x))
		max_lateral = maxf(max_lateral, lateral)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check("physics:drifts", max_lateral > 3.0, "(lat %.1f m/s)" % max_lateral)

	world.queue_free()


# ── TEST: carrera con IA en cada stage ───────────────────────────────────────

func _test_race_per_stage() -> void:
	for stage_info in GameState.STAGES:
		var sname = stage_info["name"]
		GameState.selected_stage = stage_info["scene"]
		GameState.player_count = 1
		GameState.ai_count = 3
		GameState.time_trial = false
		GameState.difficulty = "normal"

		var game = load("res://scenes/game/Game.tscn").instantiate()
		add_child(game)

		# Countdown (~3.7s) + 14s de carrera
		await get_tree().create_timer(4.0).timeout
		var starts = []
		for car in game.cars:
			starts.append(car.global_position)

		await get_tree().create_timer(14.0).timeout

		var rm = game.race_manager
		var ai_moving = 0
		var total_checkpoints = 0
		for i in range(1, game.cars.size()):
			var traveled = game.cars[i].global_position.distance_to(starts[i])
			if traveled > 40.0:
				ai_moving += 1
			if rm and i < rm.car_data.size():
				total_checkpoints += rm.car_data[i]["checkpoint"]

		_check("race:%s:ai_progresses" % sname, ai_moving >= 2,
			"(%d/3 viajaron >40m)" % ai_moving)
		_check("race:%s:checkpoints" % sname, total_checkpoints >= 6,
			"(%d checkpoints entre las 3 IA)" % total_checkpoints)
		_check("race:%s:cars_upright" % sname,
			game.cars.all(func(c): return c.global_transform.basis.y.y > 0.7))

		game.queue_free()
		await get_tree().process_frame
