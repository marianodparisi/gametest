extends Node

func _ready() -> void:
	GameState.selected_stage = "res://scenes/stages/Circuit01.tscn"
	GameState.player_count = 2
	GameState.ai_count = 4
	GameState.time_trial = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/game/Game.tscn")
