extends Node2D

@export var transitions: Array[TransitionConfig] = []
var is_transitioning: bool = false
var transition_cooldown: float = 0.0
var _current_map_path: String = ""

@onready var map_container: Node = $MapContainer

func _ready() -> void:
	_sync_current_map_path()
	_connect_current_map_zones()

func get_current_map_path() -> String:
	return _current_map_path

func _process(delta: float) -> void:
	if transition_cooldown > 0:
		transition_cooldown -= delta

## Public API to change maps externally (e.g. from BattleManager).
## Pass player_position to restore the player before zone signals reconnect.
func load_map(target_scene_path: String, player_position: Vector2 = Vector2.INF) -> Node:
	transition_cooldown = 1.0
	is_transitioning = true

	var new_map = _swap_map_scene(target_scene_path)

	if player_position != Vector2.INF:
		var player := _find_player()
		if player:
			player.global_position = player_position

	_connect_current_map_zones()
	is_transitioning = false
	return new_map

func _connect_current_map_zones() -> void:
	if not map_container:
		push_warning("Map container not found!")
		return
	
	for transition in transitions:
		if not transition is TransitionConfig:
			push_error("Invalid transition resource: expected TransitionConfig")
			continue
		
		var current_map = map_container.get_child(0)
		var zone = current_map.get_node_or_null(transition.zone_marker)
		
		if zone and not zone.body_entered.is_connected(_on_zone_entered):
			zone.body_entered.connect(_on_zone_entered.bind(transition))

func _on_zone_entered(body: Node2D, transition: TransitionConfig) -> void:
	if transition_cooldown > 0 or is_transitioning:
		return
	if not _is_valid_player(body):
		return
		
	if ProgressManager.get_current_level() < transition.required_level:
		if not transition.lock_cutscene_id.is_empty():
			# Tell ProgressManager the player was blocked — it decides the response.
			ProgressManager.on_area_entry_blocked(transition.lock_cutscene_id)
		return
		
	_execute_map_transition(body, transition)

func _is_valid_player(body: Node2D) -> bool:
	return body.name == "Player" or body.is_in_group("player")

func _execute_map_transition(player: Node2D, transition: TransitionConfig) -> void:
	is_transitioning = true
	
	# Execute transition sequence
	await GuiManager.transition_out("fade")
	var new_map = _swap_map_scene(transition.target_scene)
	_teleport_player(player, new_map, transition.spawn_marker)
	_connect_current_map_zones()
	await GuiManager.transition_in("fade")
	
	is_transitioning = false
	transition_cooldown = 1.0

func _swap_map_scene(target_scene_path: String) -> Node:
	# Remove old maps immediately
	for child in map_container.get_children():
		map_container.remove_child(child)
		child.queue_free()
	
	# Load and instantiate new map (using preloaded cache if available)
	var new_scene = SceneSwitcher.get_preloaded_scene(target_scene_path)
	var new_map = new_scene.instantiate()
	map_container.add_child(new_map)
	_current_map_path = target_scene_path
	return new_map

func _sync_current_map_path() -> void:
	if not map_container or map_container.get_child_count() == 0:
		_current_map_path = ""
		return

	var current_map = map_container.get_child(0)
	_current_map_path = current_map.scene_file_path

func _find_player() -> Node2D:
	var player = get_node_or_null("%Player")
	if is_instance_valid(player):
		return player
	return find_child("Player", true, false) as Node2D

func _teleport_player(player: Node2D, current_map: Node, spawn_marker_path: String) -> void:
	var spawn_point = current_map.get_node_or_null(spawn_marker_path)
	if spawn_point:
		player.global_position = Vector2(player.global_position.x, spawn_point.global_position.y)
	else:
		push_error("Spawn point not found: ", spawn_marker_path)
