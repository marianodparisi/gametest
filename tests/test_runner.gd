extends Node

func _ready() -> void:
	GameState.selected_stage = "res://scenes/stages/Circuit01.tscn"
	GameState.player_count = 1
	GameState.ai_count = 4
	GameState.time_trial = false

	var game = load("res://scenes/game/Game.tscn").instantiate()
	add_child(game)

	var prev = 0.0
	for t in [2.0, 6.0, 12.0]:
		await get_tree().create_timer(t - prev).timeout
		prev = t
		await RenderingServer.frame_post_draw
		var img = get_viewport().get_texture().get_image()
		img.save_png("/tmp/new_shot_%d.png" % int(t))
		print("SHOT_%d" % int(t))
	get_tree().quit()
