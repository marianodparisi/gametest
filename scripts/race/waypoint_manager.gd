extends Node3D

# Herramienta de editor: dibuja las líneas entre waypoints para visualizarlos
# Adjuntar al nodo "Waypoints" del stage

@tool
@export var show_path: bool = true
@export var path_color: Color = Color(1, 1, 0, 0.8)

var _waypoints: Array[Node3D] = []


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	_waypoints.clear()
	for child in get_children():
		if child is Node3D:
			_waypoints.append(child)


func get_waypoints() -> Array[Node3D]:
	_refresh()
	return _waypoints


func get_nearest_waypoint_index(pos: Vector3) -> int:
	var best = 0
	var best_dist = INF
	for i in _waypoints.size():
		var d = pos.distance_to(_waypoints[i].global_position)
		if d < best_dist:
			best_dist = d
			best = i
	return best


# Dibuja el path en el editor (solo en modo @tool)
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or not show_path:
		return
	_refresh()
	if _waypoints.size() < 2:
		return
	for i in _waypoints.size():
		var a = _waypoints[i].global_position
		var b = _waypoints[(i + 1) % _waypoints.size()].global_position
		DebugDraw3D.draw_line(a, b, path_color) if ClassDB.class_exists("DebugDraw3D") else null
