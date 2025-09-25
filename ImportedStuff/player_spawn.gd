extends MultiplayerSpawner

@export var player_scene : PackedScene
@export var spawn_points : Array[Node3D]

var players = {}

func _ready():
	spawn_function = spawn_player
	await get_tree().process_frame
	if is_multiplayer_authority():
		spawn(1)
		multiplayer.peer_connected.connect(spawn)
		multiplayer.peer_disconnected.connect(remove_player)
	
func spawn_player(data):
	var player : CharacterBody3D = player_scene.instantiate()
	player.set_multiplayer_authority(data)
	players[data] = player
	
	var spawn_position : Vector3
	spawn_position = spawn_points[players.size()-1].global_position
	player.global_position = spawn_position
	return player

func remove_player(data):
	players[data].queue_free()
	players.erase(data)
