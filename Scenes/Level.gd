extends Node3D
class_name Level

signal ready_for_players

func _ready():
	emit_signal("ready_for_players")
