extends CanvasLayer

const CarBodyBuilder = preload("res://scripts/car/car_body_builder.gd")

# Pantalla de resultados post-carrera. Se muestra sobre el juego al terminar.

@onready var results_list: VBoxContainer = $Panel/VBox/Results
@onready var btn_retry: Button = $Panel/VBox/Buttons/BtnRetry
@onready var btn_menu: Button = $Panel/VBox/Buttons/BtnMenu

var new_record: bool = false


func _ready() -> void:
	hide()
	btn_retry.pressed.connect(_on_retry)
	btn_menu.pressed.connect(_on_menu)


func show_results(results: Array, player_count: int) -> void:
	# Limpiar lista anterior
	for child in results_list.get_children():
		child.queue_free()

	# Banner de récord
	if new_record:
		var record_label = Label.new()
		record_label.text = "★ NEW RECORD ★"
		record_label.add_theme_font_size_override("font_size", 24)
		record_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		results_list.add_child(record_label)

	# Mejor tiempo histórico del stage
	var best = GameState.get_best_time(GameState.selected_stage)
	if best > 0:
		var best_label = Label.new()
		best_label.text = "Stage best: %s" % _format_time(best)
		best_label.add_theme_font_size_override("font_size", 14)
		best_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		results_list.add_child(best_label)

	for entry in results:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)

		var pos_label = Label.new()
		pos_label.text = "P%d" % entry["position"]
		pos_label.add_theme_font_size_override("font_size", 22)
		pos_label.custom_minimum_size = Vector2(50, 0)

		var name_label = Label.new()
		var idx = entry["car_index"]
		var style_name = CarBodyBuilder.STYLE_NAMES[idx % CarBodyBuilder.STYLE_NAMES.size()]
		if idx < player_count:
			name_label.text = "Player %d · %s" % [idx + 1, style_name]
			name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2))
		else:
			name_label.text = "CPU %d · %s" % [idx - player_count + 1, style_name]
			name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.custom_minimum_size = Vector2(160, 0)

		var time_label = Label.new()
		time_label.text = _format_time(entry["finish_time"])
		time_label.add_theme_font_size_override("font_size", 22)
		time_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6))

		row.add_child(pos_label)
		row.add_child(name_label)
		row.add_child(time_label)
		results_list.add_child(row)

	show()
	get_tree().paused = true


func _format_time(t: float) -> String:
	if t <= 0.0:
		return "DNF"
	var minutes = int(t) / 60
	var seconds = int(t) % 60
	var ms = int(fmod(t, 1.0) * 100)
	return "%d:%02d.%02d" % [minutes, seconds, ms]


func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
