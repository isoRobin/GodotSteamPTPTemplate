extends MultiplayerSpawner

@export var player_scene: PackedScene
@export var spawn_points: Array[Node3D] = []
@export var spawn_in_empty: bool = false  ## if true, each spawn point is only used once

var players: Dictionary = {}
var used_spawn_points: Array[Node3D] = []

func _ready() -> void:
	spawn_function = spawn_player

	if is_multiplayer_authority():
		# ✅ Delay until next idle frame so spawn_points have valid transforms
		call_deferred("_spawn_self")
		multiplayer.peer_connected.connect(spawn)
		multiplayer.peer_disconnected.connect(remove_player)


func _spawn_self() -> void:
	spawn(multiplayer.get_unique_id())

func spawn_player(peer_id: int) -> Node3D:
	var player: CharacterBody3D = player_scene.instantiate()
	player.set_multiplayer_authority(peer_id)
	players[peer_id] = player

	var spawn_position: Vector3 = Vector3.ZERO

	if spawn_in_empty:
		for spawn_point in spawn_points:
			if not used_spawn_points.has(spawn_point):
				spawn_position = spawn_point.global_position
				used_spawn_points.append(spawn_point)
				break
	else:
		if spawn_points.size() > 0:
			var idx := (players.size() - 1) % spawn_points.size()
			spawn_position = spawn_points[idx].global_position

	# ✅ Set local position before being added to tree
	player.position = spawn_position

	return player


func remove_player(peer_id: int) -> void:
	if players.has(peer_id):
		players[peer_id].queue_free()
		players.erase(peer_id)
