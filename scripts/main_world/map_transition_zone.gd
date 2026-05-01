extends Area2D

@export_file("*.tscn") var target_map_path: String
@export var target_marker_name: String = "SpawnPoint"
@export var transition_type: String = "fade"

var is_transitioning: bool = false

func _ready() -> void:
	# Ensure the signal is connected
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if is_transitioning: return
	
	# Check if the colliding body is the player
	if body.name == "Player" or body.is_in_group("player"):
		is_transitioning = true
		_transition_map(body)

func _transition_map(player: Node2D) -> void:
	# Determine target map based on which transition zone was entered
	var target_map_file: String
	var spawn_marker_name: String
	
	if name == "TransitionZoneUpper":
		# Upper boundary - load goblin map
		target_map_file = "res://scenes/main_world/main_world_goblin_map.tscn"
		spawn_marker_name = "SpawnPointLower"
	elif name == "TransitionZoneLower":
		# Lower boundary - load human map
		target_map_file = "res://scenes/main_world/main_world_human_map.tscn"
		spawn_marker_name = "SpawnPointUpper"
	else:
		push_error("Unknown transition zone: " + name)
		is_transitioning = false
		return
	
	# Start transition out (using SceneSwitcher's UI elements)
	SceneSwitcher.transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	SceneSwitcher.fullscreen_ui.show()
	SceneSwitcher.transition_rect.color = Color(0, 0, 0, 0)
	SceneSwitcher.transition_rect.show()
	SceneSwitcher.animation_player.play("%s_in" % transition_type)
	await SceneSwitcher.animation_player.animation_finished
	
	# Swap Map Node
	var map_container = get_tree().current_scene.get_node_or_null("Map")
	if not map_container:
		# Fallback if map container is not directly on current_scene
		map_container = player.get_parent().get_node_or_null("Map")
		
	var target_position = player.global_position
	
	if map_container:
		# Remove old maps
		for child in map_container.get_children():
			child.queue_free()
			
		# Load and add new map
		if target_map_file != "":
			var new_map_scene = load(target_map_file)
			if new_map_scene:
				var new_map = new_map_scene.instantiate()
				map_container.add_child(new_map)
				
				# Find the marker in the newly instantiated map
				var marker = new_map.find_child(spawn_marker_name, true, false)
				if marker and marker is Node2D:
					# Keep the current X but use the marker's Y position
					target_position = Vector2(player.global_position.x, marker.global_position.y)
				else:
					push_error("Marker not found: " + spawn_marker_name)
	else:
		push_error("Map container not found!")
		
	# Teleport player
	player.global_position = target_position
	
	# Start transition in
	SceneSwitcher.animation_player.play("%s_out" % transition_type)
	await SceneSwitcher.animation_player.animation_finished
	
	SceneSwitcher.transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneSwitcher.transition_rect.hide()
	is_transitioning = false
