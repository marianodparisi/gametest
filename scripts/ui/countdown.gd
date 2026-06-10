extends CanvasLayer

# Countdown 3-2-1-GO al inicio de la carrera.
# Bloquea el input de los autos hasta el GO.

signal countdown_finished

@onready var label: Label = $Center/Label


func start() -> void:
	show()
	_run_countdown()


func _run_countdown() -> void:
	var steps = ["3", "2", "1", "GO!"]
	var colors = [
		Color(1, 0.4, 0.3), Color(1, 0.7, 0.3),
		Color(1, 0.95, 0.4), Color(0.4, 1, 0.5),
	]

	for i in steps.size():
		label.text = steps[i]
		label.add_theme_color_override("font_color", colors[i])
		# Pop de escala con tween
		label.scale = Vector2(1.6, 1.6)
		label.pivot_offset = label.size * 0.5
		var tween = create_tween()
		tween.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(1.0 if i < 3 else 0.7).timeout

	emit_signal("countdown_finished")
	hide()
