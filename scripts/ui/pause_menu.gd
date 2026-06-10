extends CanvasLayer

# Menú de pausa — Escape para abrir/cerrar.

@onready var btn_resume: Button = $Panel/VBox/BtnResume
@onready var btn_retry: Button = $Panel/VBox/BtnRetry
@onready var btn_menu: Button = $Panel/VBox/BtnMenu


func _ready() -> void:
	hide()
	btn_resume.pressed.connect(_toggle)
	btn_retry.pressed.connect(_on_retry)
	btn_menu.pressed.connect(_on_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()


func _toggle() -> void:
	if visible:
		hide()
		get_tree().paused = false
	else:
		show()
		get_tree().paused = true


func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
