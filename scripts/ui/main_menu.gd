extends Control

var _stage_index: int = 0
var _difficulty_index: int = 1
const DIFFICULTIES = ["easy", "normal", "hard"]
const DIFFICULTY_LABELS = ["Easy", "Normal", "Hard"]

@onready var stage_label: Label = $VBox/StageRow/StageName
@onready var stage_type_label: Label = $VBox/StageType
@onready var best_time_label: Label = $VBox/BestTime
@onready var diff_label: Label = $VBox/DiffRow/DiffName
@onready var settings_panel: PanelContainer = $SettingsPanel


func _ready() -> void:
	$VBox/StageRow/BtnPrev.pressed.connect(_prev_stage)
	$VBox/StageRow/BtnNext.pressed.connect(_next_stage)
	$VBox/DiffRow/BtnDiffPrev.pressed.connect(_prev_diff)
	$VBox/DiffRow/BtnDiffNext.pressed.connect(_next_diff)
	$VBox/Btn1P.pressed.connect(_start.bind(1, false))
	$VBox/Btn2P.pressed.connect(_start.bind(2, false))
	$VBox/BtnTimeTrial.pressed.connect(_start.bind(1, true))
	$VBox/BtnSettings.pressed.connect(_toggle_settings)
	$VBox/BtnQuit.pressed.connect(get_tree().quit)

	# Settings panel
	settings_panel.hide()
	var master_slider: HSlider = $SettingsPanel/VBox/MasterRow/Slider
	var music_slider: HSlider = $SettingsPanel/VBox/MusicRow/Slider
	var music_check: CheckButton = $SettingsPanel/VBox/MusicEnabled
	master_slider.value = GameState.settings["master_volume"]
	music_slider.value = GameState.settings["music_volume"]
	music_check.button_pressed = GameState.settings["music_enabled"]
	master_slider.value_changed.connect(_on_master_volume)
	music_slider.value_changed.connect(_on_music_volume)
	music_check.toggled.connect(_on_music_toggled)
	$SettingsPanel/VBox/BtnClose.pressed.connect(_toggle_settings)

	_update_display()


func _update_display() -> void:
	var stage = GameState.STAGES[_stage_index]
	stage_label.text = stage["name"]
	stage_type_label.text = "◆ " + ("Circuit — %d laps" % stage["laps"] if stage["type"] == "circuit" else "Rally — Point to Point")

	var best = GameState.get_best_time(stage["scene"])
	if best > 0:
		best_time_label.text = "Best: %s" % _format_time(best)
	else:
		best_time_label.text = "Best: --:--"

	diff_label.text = DIFFICULTY_LABELS[_difficulty_index]


func _format_time(t: float) -> String:
	return "%d:%02d.%02d" % [int(t) / 60, int(t) % 60, int(fmod(t, 1.0) * 100)]


func _prev_stage() -> void:
	_stage_index = (_stage_index - 1 + GameState.STAGES.size()) % GameState.STAGES.size()
	_update_display()


func _next_stage() -> void:
	_stage_index = (_stage_index + 1) % GameState.STAGES.size()
	_update_display()


func _prev_diff() -> void:
	_difficulty_index = (_difficulty_index - 1 + DIFFICULTIES.size()) % DIFFICULTIES.size()
	_update_display()


func _next_diff() -> void:
	_difficulty_index = (_difficulty_index + 1) % DIFFICULTIES.size()
	_update_display()


func _start(players: int, time_trial: bool) -> void:
	GameState.player_count = players
	GameState.ai_count = 0 if time_trial else 4
	GameState.time_trial = time_trial
	GameState.difficulty = DIFFICULTIES[_difficulty_index]
	GameState.selected_stage = GameState.STAGES[_stage_index]["scene"]
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")


func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible


func _on_master_volume(v: float) -> void:
	GameState.settings["master_volume"] = v
	GameState.apply_settings()
	GameState.save_settings()


func _on_music_volume(v: float) -> void:
	GameState.settings["music_volume"] = v
	GameState.apply_settings()
	GameState.save_settings()


func _on_music_toggled(on: bool) -> void:
	GameState.settings["music_enabled"] = on
	GameState.apply_settings()
	GameState.save_settings()
