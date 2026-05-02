extends Node2D

@export var transitions: Array[TransitionConfig] = []
var is_transitioning: bool = false
var previous_map_path: String = ""

@onready var map_container: Node = $MapContainer

func _ready() -> void:
	_connect_current_map_zones()

## Public API to change maps externally (e.g. from BattleManager)
func load_map(target_scene_path: String) -> Node:
	var new_map = _swap_map_scene(target_scene_path)
	_connect_current_map_zones()
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
	if not _is_valid_player(body):
		return
		
	_execute_map_transition(body, transition)

func _is_valid_player(body: Node2D) -> bool:
	return body.name == "Player" or body.is_in_group("player")

func _execute_map_transition(player: Node2D, transition: TransitionConfig) -> void:
	is_transitioning = true
	
	# Store current map as previous before swapping
	var current_map_path = ""
	if map_container.get_child_count() > 0:
		var current_map = map_container.get_child(0)
		current_map_path = current_map.scene_file_path
	
	# Execute transition sequence
	await GuiManager.transition_out("fade")
	var new_map = _swap_map_scene(transition.target_scene)
	previous_map_path = current_map_path
	_teleport_player(player, new_map, transition.spawn_marker)
	_connect_current_map_zones()
	await GuiManager.transition_in("fade")
	
	is_transitioning = false

func _swap_map_scene(target_scene_path: String) -> Node:
	# Remove old maps immediately
	for child in map_container.get_children():
		map_container.remove_child(child)
		child.queue_free()
	
	# Load and instantiate new map
	var new_map = load(target_scene_path).instantiate()
	map_container.add_child(new_map)
	return new_map

func _teleport_player(player: Node2D, current_map: Node, spawn_marker_path: String) -> void:
	var spawn_point = current_map.get_node_or_null(spawn_marker_path)
	if spawn_point:
		player.global_position = Vector2(player.global_position.x, spawn_point.global_position.y)
	else:
		push_error("Spawn point not found: ", spawn_marker_path)
 
