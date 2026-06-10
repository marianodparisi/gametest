extends Node

# Gestiona los 2 SubViewports y mueve los autos al viewport correcto

@onready var vp1: SubViewport = $HSplitContainer/ViewportContainer_P1/SubViewport_P1
@onready var vp2: SubViewport = $HSplitContainer/ViewportContainer_P2/SubViewport_P2
@onready var hud1 = $HUD_P1
@onready var hud2 = $HUD_P2


func setup(stage_scene: Node, car_p1: RigidBody3D, car_p2: RigidBody3D, race_mgr: Node) -> void:
	# Mover el stage a cada viewport
	vp1.add_child(stage_scene)

	# P1: activar su cámara en vp1
	var cam1 = car_p1.get_node("Camera/Camera3D")
	cam1.current = true

	# P2: necesita una instancia separada del stage en vp2
	# En la práctica más simple: ambos jugadores comparten el mismo stage
	# pero cada uno tiene su cámara en su viewport
	var cam2 = car_p2.get_node("Camera/Camera3D")

	# Hack elegante: mover cámara P2 al vp2 como viewport independiente
	# Para el MVP, vp2 usa una cámara remota apuntando al auto P2
	var remote_cam = RemoteTransform3D.new()
	remote_cam.remote_path = car_p2.get_path()
	vp2.add_child(remote_cam)

	# HUDs
	hud1.set_car(car_p1)
	hud2.set_car(car_p2)
	if race_mgr:
		hud1.race_manager_path = race_mgr.get_path()
		hud2.race_manager_path = race_mgr.get_path()
		hud2.player_index = 1
