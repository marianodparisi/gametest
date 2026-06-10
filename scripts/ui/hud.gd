extends CanvasLayer

@export var player_index: int = 0

# Se asignan por código desde game.gd
var race_manager: Node = null

@onready var label_position: Label = $Panel/VBox/Position
@onready var label_speed: Label = $Panel/VBox/Speed
@onready var label_lap: Label = $Panel/VBox/Lap
@onready var label_time: Label = $Panel/VBox/Time

var _car: RigidBody3D = null


func set_car(car: RigidBody3D) -> void:
	_car = car


func _process(_delta: float) -> void:
	if not is_instance_valid(_car):
		return

	label_speed.text = "%d km/h" % int(_car.get_speed_kmh())

	if race_manager:
		var pos = race_manager.get_position(player_index)
		var total = race_manager.cars.size()
		label_position.text = "P%d/%d" % [pos, total]

		var lap = race_manager.get_lap(player_index)
		var max_laps = race_manager.total_laps
		var best_lap = race_manager.get_best_lap(player_index)
		if best_lap > 0:
			label_lap.text = "Lap %d/%d  ◆ %s" % [lap, max_laps, _format_time(best_lap)]
		else:
			label_lap.text = "Lap %d/%d" % [lap, max_laps]

		label_time.text = _format_time(race_manager.get_race_time())


func _format_time(t: float) -> String:
	var minutes = int(t) / 60
	var seconds = int(t) % 60
	var ms = int(fmod(t, 1.0) * 100)
	return "%d:%02d.%02d" % [minutes, seconds, ms]
