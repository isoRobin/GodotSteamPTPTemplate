extends Node3D

@export var mouse_sensitivity := 0.001
var player : Player
func _ready() -> void:
	player = get_parent_node_3d()
	if !is_multiplayer_authority():
		set_process_input(false)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation.x += event.relative.y * player.mouse_sensitivity
		rotation.x = clamp(rotation.x, -1.6, 1.6)
