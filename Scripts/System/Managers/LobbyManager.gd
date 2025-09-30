extends Node

## INFO: Export variables
@export var network_manager : Node
@export var map_spawner 	: MultiplayerSpawner
@export var map_manager 	: Node
@export var menu_manager 	: Node

@export_category("Local Lobby")
var local_lobby_id : int = 1
@export var local_addr : String = "127.0.0.1"
@export var local_port : int = 5000
@export var local_max_players : int = 4
@export var debug_local : bool = false
@export_category("Local Lobby Filtering")
@export var max_players_local_filter: SpinBox

@export_category("Steam Lobby")
var steam_lobby_id = 1
@export var lobby_v_box_container : VBoxContainer
@export var steam_max_players : int = 4
@export var debug_steam : bool = false
@export_group("Steam Lobby Filtering")
@export var name_filter_edit: LineEdit
@export var max_players_filter: SpinBox
@export var has_password_filter: CheckBox
@export var distance_filter: OptionButton
@export var friends_only_filter: CheckBox 
@export_group("Steam Host Settings")
@export var host_max_players: SpinBox
@export var host_friends_only: CheckBox
@export var host_password_protected: CheckBox
@export var host_password_input: LineEdit

# Filter settings
var current_filters = {
	"name": "",
	"max_players": 0,
	"has_password": false,
	"friends_only": false,
	"distance": Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE
}

# Distance filter options
const DISTANCE_FILTERS = {
	"Worldwide": Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE,
	"Close": Steam.LOBBY_DISTANCE_FILTER_CLOSE,
	"Far": Steam.LOBBY_DISTANCE_FILTER_FAR,
}

const LOBBY_TYPES = {
	"PUBLIC": Steam.LOBBY_TYPE_PUBLIC,
	"FRIENDS_ONLY": Steam.LOBBY_TYPE_FRIENDS_ONLY,
	"PRIVATE": Steam.LOBBY_TYPE_PRIVATE
}

## INFO: Signals
signal on_singleplayer_lobby_created
signal on_local_lobby_created
signal on_steam_lobby_created
signal password_submitted(password: String)

func _ready():
	map_spawner.spawn_function = map_manager.spawn_map
	setup_filters()
	setup_steam_lobbies()

# -------------------------
# SETUP
# -------------------------

func setup_filters():
	name_filter_edit.text_changed.connect(_on_name_filter_changed)
	max_players_filter.value_changed.connect(_on_max_players_filter_changed)
	has_password_filter.toggled.connect(_on_password_filter_changed)
	friends_only_filter.toggled.connect(_on_friends_only_filter_changed)
	max_players_local_filter.value_changed.connect(_on_max_local_players_filter_changed)
	
	for key in DISTANCE_FILTERS.keys():
		distance_filter.add_item(key)
	
	distance_filter.item_selected.connect(_on_distance_filter_changed)

func setup_singleplayer_lobby():
	network_manager.reset_peer()

func setup_local_lobbies():
	network_manager.set_peer_mode(network_manager.PeerMode.LOCAL)
	network_manager.get_peer().peer_connected.connect(_on_local_player_connect_lobby)
	network_manager.get_peer().peer_disconnected.connect(_on_local_player_disconnect_lobby)

func setup_steam_lobbies():
	network_manager.set_peer_mode(network_manager.PeerMode.STEAM)
	Steam.lobby_created.connect(_on_steam_lobby_created)
	Steam.lobby_match_list.connect(_on_steam_lobby_match_list)
	Steam.lobby_joined.connect(_on_steam_lobby_joined) # ✅ added
	refresh_steam_lobby_list()

# -------------------------
# FILTER CALLBACKS
# -------------------------

func get_lobbies_with_friends() -> Dictionary:
	var results: Dictionary = {}
	for i in range(0, Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)):
		var steam_id: int = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		var game_info: Dictionary = Steam.getFriendGamePlayed(steam_id)
		if game_info.is_empty():
			continue
		var app_id: int = game_info['id']
		var lobby = game_info['lobby']
		if app_id != Steam.getAppID() or lobby is String:
			continue
		if not results.has(lobby):
			results[lobby] = []
		results[lobby].append(steam_id)
	return results

func is_friend_in_lobby(steam_id: int, lobby_id: int) -> bool:
	var game_info: Dictionary = Steam.getFriendGamePlayed(steam_id)
	if game_info.is_empty():
		return false
	var app_id: int = game_info.id
	var lobby = game_info.lobby
	return app_id == Steam.getAppID() and lobby is int and lobby == lobby_id

func _on_friends_only_filter_changed(toggled: bool):
	current_filters["friends_only"] = toggled
	apply_filters()

func _on_name_filter_changed(new_text: String):
	current_filters["name"] = new_text
	apply_filters()

func _on_max_players_filter_changed(value: int):
	current_filters["max_players"] = value
	apply_filters()
	
func _on_max_local_players_filter_changed(value: int):
	local_max_players = value
		
func _on_password_filter_changed(toggled: bool):
	current_filters["has_password"] = toggled
	apply_filters()

func _on_distance_filter_changed(index: int):
	var selected = distance_filter.get_item_text(index)
	current_filters["distance"] = DISTANCE_FILTERS[selected]
	apply_filters()

func apply_filters():
	for lobby in lobby_v_box_container.get_children():
		lobby.queue_free()
	
	if current_filters["friends_only"]:
		var friend_lobbies = get_lobbies_with_friends()
		for lobby_id in friend_lobbies.keys():
			var lobby_name = Steam.getLobbyData(lobby_id, "name")
			var max_players = Steam.getLobbyData(lobby_id, "max_players")
			var current_players = Steam.getNumLobbyMembers(lobby_id)
			var has_password = Steam.getLobbyData(lobby_id, "has_password") == "1"
			create_lobby_button(lobby_id, lobby_name, current_players, int(max_players), has_password, true)
	else:
		Steam.addRequestLobbyListDistanceFilter(current_filters["distance"])
		if current_filters["name"] != "":
			Steam.addRequestLobbyListStringFilter("name", current_filters["name"], Steam.LOBBY_COMPARISON_EQUAL)
		if current_filters["max_players"] > 0:
			Steam.addRequestLobbyListNumericalFilter("max_players", current_filters["max_players"], Steam.LOBBY_COMPARISON_EQUAL)
		if current_filters["has_password"]:
			Steam.addRequestLobbyListStringFilter("has_password", "1", Steam.LOBBY_COMPARISON_EQUAL)
		Steam.requestLobbyList()

# -------------------------
# CREATION
# -------------------------

func create_singleplayer_lobby():
	map_spawner.spawn(map_manager.lobby_scene_path)
	on_singleplayer_lobby_created.emit()

func create_local_lobby():	
	var err = network_manager.get_peer().create_server(local_port, local_max_players)
	if err != OK: print(err)
	network_manager.update_multiplayer_peer()
	map_spawner.spawn(map_manager.lobby_scene_path)
	on_local_lobby_created.emit()

func create_steam_lobby():
	var lobby_type = LOBBY_TYPES.PUBLIC
	var is_password_protected = host_password_protected.button_pressed
	var password = host_password_input.text if is_password_protected else ""
	if host_friends_only.button_pressed:
		lobby_type = LOBBY_TYPES.FRIENDS_ONLY
	elif is_password_protected:
		lobby_type = LOBBY_TYPES.PRIVATE
	var max_players = host_max_players.value
	Steam.createLobby(lobby_type, max_players)
	print("Requesting Steam to create lobby...")

# -------------------------
# JOIN
# -------------------------

func join_local_lobby():
	var err = network_manager.get_peer().create_client(local_addr, local_port)
	if err != OK: print(err)
	network_manager.update_multiplayer_peer()

func join_steam_lobby(id: int) -> void:
	if await validate_lobby_join(id):
		print("Requesting Steam to join lobby:", id)
		Steam.joinLobby(id) # ✅ changed
	else:
		print("Invalid password or cancelled")

func _on_steam_lobby_joined(lobby_id: int, chat_permissions: int, locked: bool, response: int) -> void:
	if response != OK:
		push_error("Failed to join Steam lobby. Result code: %s" % response)
		return

	print("Steam confirmed join, now connecting MultiplayerPeer...")

	var err = network_manager.get_peer().connect_to_lobby(lobby_id)
	if err != OK:
		push_error("Failed to connect to Steam lobby: %s" % err)
		return

	network_manager.update_multiplayer_peer()
	steam_lobby_id = lobby_id

	if menu_manager:
		menu_manager.hide_main_canvas()

	map_spawner.spawn(map_manager.lobby_scene_path)

	while not get_tree().root.find_child("Players", true, false):
		await get_tree().process_frame

	_on_joined_session()
	print("Joined Steam lobby:", lobby_id)

	var num_members = Steam.getNumLobbyMembers(lobby_id)
	print("Lobby", lobby_id, "has", num_members, "members:")
	for i in range(num_members):
		var member_id = Steam.getLobbyMemberByIndex(lobby_id, i)
		print(" - Member:", member_id)

func _on_joined_session() -> void:
	var my_id = multiplayer.get_unique_id()
	var player_scene = preload("res://scenes/Player.tscn")
	var player = player_scene.instantiate()
	player.name = "Player_%s" % my_id
	player.set_multiplayer_authority(my_id)
	var players_node = get_tree().root.find_child("Players", true, false)
	if players_node:
		players_node.add_child(player)
		print("Spawned into session as", my_id)
	else:
		push_error("Could not find 'Players' node after joining session")

# -------------------------
# LOCAL CALLBACKS
# -------------------------

func _on_local_player_connect_lobby(id):
	local_lobby_id = id
	print_rich("Player [color=green]", id, " Joined [/color]")
	
func _on_local_player_disconnect_lobby(id):
	print_rich("Player [color=red]", id, " Disconnected [/color]")

# -------------------------
# STEAM CREATION CALLBACK
# -------------------------

func _on_steam_lobby_created(connect: int, lobby_id: int) -> void:
	if connect == OK or connect == 1:
		steam_lobby_id = lobby_id
		print("Steam lobby created! ID:", steam_lobby_id)
		var err = network_manager.get_peer().host_with_lobby(lobby_id)
		if err != OK:
			push_error("Failed to host Steam lobby: %s" % err)
			return
		network_manager.update_multiplayer_peer()
		map_spawner.spawn(map_manager.lobby_scene_path)
		on_steam_lobby_created.emit()
		update_lobby_name()
		Steam.setLobbyData(lobby_id, "max_players", str(host_max_players.value))
		if host_password_protected.button_pressed:
			Steam.setLobbyData(lobby_id, "has_password", "1")
			Steam.setLobbyData(lobby_id, "password", host_password_input.text)
		else:
			Steam.setLobbyData(lobby_id, "has_password", "0")
		Steam.setLobbyMemberLimit(lobby_id, host_max_players.value)
		Steam.setLobbyJoinable(lobby_id, true)
		print("Lobby setup complete and joinable.")
	else:
		push_error("Steam lobby creation failed: %s" % connect)

func update_lobby_name():
	if steam_lobby_id != 0:
		var current_players = Steam.getNumLobbyMembers(steam_lobby_id)
		var max_players = host_max_players.value
		var base_name = Steam.getPersonaName() + "'s Lobby"
		var formatted_name = "%s (%d/%d)" % [base_name, current_players, max_players]
		Steam.setLobbyData(steam_lobby_id, "name", formatted_name)

# -------------------------
# REFRESH
# -------------------------

func refresh_steam_lobby_list():
	for lobby in lobby_v_box_container.get_children(): 
		lobby.queue_free()
	if current_filters["friends_only"]:
		var friend_lobbies = get_lobbies_with_friends()
		for lobby_id in friend_lobbies.keys():
			var lobby_name = Steam.getLobbyData(lobby_id, "name")
			var max_players = Steam.getLobbyData(lobby_id, "max_players")
			var current_players = Steam.getNumLobbyMembers(lobby_id)
			var has_password = Steam.getLobbyData(lobby_id, "has_password") == "1"
			if should_display_lobby(lobby_name, max_players, has_password):
				create_lobby_button(lobby_id, lobby_name, current_players, int(max_players), has_password, true)
	else:
		Steam.addRequestLobbyListDistanceFilter(current_filters["distance"])
		if current_filters["name"] != "":
			Steam.addRequestLobbyListStringFilter("name", current_filters["name"], Steam.LOBBY_COMPARISON_EQUAL)
		if current_filters["max_players"] > 0:
			Steam.addRequestLobbyListNumericalFilter("max_players", current_filters["max_players"], Steam.LOBBY_COMPARISON_EQUAL)
		if current_filters["has_password"]:
			Steam.addRequestLobbyListStringFilter("has_password", "1", Steam.LOBBY_COMPARISON_EQUAL)
		Steam.requestLobbyList()

func should_display_lobby(lobby_name: String, max_players: String, has_password: bool) -> bool:
	if current_filters["name"] != "" and not lobby_name.to_lower().contains(current_filters["name"].to_lower()):
		return false
	if current_filters["max_players"] > 0 and int(max_players) != current_filters["max_players"]:
		return false
	if current_filters["has_password"] and not has_password:
		return false
	return true

func _on_steam_lobby_match_list(lobbies):
	for lobby in lobbies:
		var lobby_name = Steam.getLobbyData(lobby, "name")
		var max_players = Steam.getLobbyData(lobby, "max_players")
		var current_players = Steam.getNumLobbyMembers(lobby)
		var has_password = Steam.getLobbyData(lobby, "has_password") == "1"
		create_lobby_button(lobby, lobby_name, current_players, int(max_players), has_password)

# -------------------------
# LOBBY UI
# -------------------------

func create_lobby_button(lobby_id: int, lobby_name: String, current_players: int, max_players: int, has_password: bool, is_friend_lobby: bool = false):
	var button = Button.new()
	var button_text = str(lobby_name) + " [" + str(current_players) + "/" + str(max_players) + "]"
	if has_password:
		button_text += " 🔒"
	if is_friend_lobby:
		button_text += " 👥"
	button.set_text(button_text)
	button.set_size(Vector2(100, 5))
	if is_friend_lobby:
		button.connect("pressed", Callable(self, "_on_friend_lobby_button_pressed").bind(lobby_id))
	else:
		button.connect("pressed", Callable(self, "join_steam_lobby").bind(lobby_id))
	lobby_v_box_container.add_child(button)

func _on_friend_lobby_button_pressed(lobby_id: int):
	var friend_lobbies = get_lobbies_with_friends()
	if friend_lobbies.has(lobby_id):
		var steam_id = friend_lobbies[lobby_id][0]
		if is_friend_in_lobby(steam_id, lobby_id):
			join_steam_lobby(lobby_id)
		else:
			print("Friend is no longer in this lobby")
	else:
		print("Lobby no longer exists")

# -------------------------
# PASSWORD
# -------------------------

func prompt_for_password() -> String:
	# TODO: Implement in UI
	return ""

func validate_lobby_join(lobby_id: int) -> bool:
	var has_password = Steam.getLobbyData(lobby_id, "has_password") == "1"
	if has_password:
		var correct_password = Steam.getLobbyData(lobby_id, "password")
		var entered_password = await prompt_for_password()
		return entered_password == correct_password
	return true
