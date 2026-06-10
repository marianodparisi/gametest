extends Node

var player_count: int = 1
var ai_count: int = 4
var selected_stage: String = "res://scenes/stages/Circuit01.tscn"
var race_results: Array = []
var time_trial: bool = false

# Dificultad de IA: rango de speed_factor por nivel
var difficulty: String = "normal"
const DIFFICULTY_RANGES = {
	"easy": [0.65, 0.85],
	"normal": [0.82, 1.02],
	"hard": [0.95, 1.12],
}

const STAGES: Array[Dictionary] = [
	{
		"name": "Circuit — Lakeside",
		"scene": "res://scenes/stages/Circuit01.tscn",
		"type": "circuit",
		"laps": 3,
	},
	{
		"name": "Rally — Mountain Pass",
		"scene": "res://scenes/stages/RallyStage01.tscn",
		"type": "linear",
		"laps": 1,
	},
	{
		"name": "Circuit — Desert Dunes",
		"scene": "res://scenes/stages/Desert01.tscn",
		"type": "circuit",
		"laps": 3,
	},
]

# ── SETTINGS PERSISTENTES ────────────────────────────────────────────────────

const SETTINGS_PATH = "user://settings.json"
var settings: Dictionary = {
	"master_volume": 1.0,   # 0.0 a 1.0
	"music_volume": 0.7,
	"music_enabled": true,
}


func _ready() -> void:
	_load_settings()
	# Diferido: MusicPlayer es un autoload posterior y su _ready aún no corrió
	apply_settings.call_deferred()


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		settings.merge(data, true)


func save_settings() -> void:
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(settings))


func apply_settings() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_idx, linear_to_db(maxf(settings["master_volume"], 0.001)))
	MusicPlayer.set_enabled(settings["music_enabled"])
	MusicPlayer.set_volume_db(linear_to_db(maxf(settings["music_volume"], 0.001)) - 10.0)


# ── LEADERBOARDS LOCALES ─────────────────────────────────────────────────────

const TIMES_PATH = "user://best_times.json"
var best_times: Dictionary = {}  # { stage_scene: [tiempo1, tiempo2, ...] max 5 }


func load_best_times() -> void:
	if not FileAccess.file_exists(TIMES_PATH):
		return
	var f = FileAccess.open(TIMES_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		best_times = data


func record_time(stage_scene: String, time: float) -> bool:
	# Devuelve true si es nuevo récord personal (top 1)
	load_best_times()
	if not best_times.has(stage_scene):
		best_times[stage_scene] = []

	var times: Array = best_times[stage_scene]
	var is_record = times.is_empty() or time < times[0]

	times.append(time)
	times.sort()
	if times.size() > 5:
		times.resize(5)
	best_times[stage_scene] = times

	var f = FileAccess.open(TIMES_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(best_times))
	return is_record


func get_best_time(stage_scene: String) -> float:
	load_best_times()
	if best_times.has(stage_scene) and not best_times[stage_scene].is_empty():
		return best_times[stage_scene][0]
	return -1.0
