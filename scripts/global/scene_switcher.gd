extends Node

var current_scene : Node = null
@onready var scene_container = get_node("/root/Game/SceneContainer") # Corrected path based on common Godot structure
@onready var animation_player = get_node("/root/Game/GUI/FullscreenUI/AnimationPlayer")
# Updated to reference the renamed ColorRect
@onready var transition_rect = get_node("/root/Game/GUI/FullscreenUI/TransitionColorRect") 
@onready var fullscreen_ui = get_node("/root/Game/GUI/FullscreenUI")

# Signal to be emitted when a scene transition is fully completed
signal scene_transition_finished(scene_name: String)

func _ready() -> void: 
	await get_tree().process_frame
	if scene_container.get_child_count() > 0:
		current_scene = scene_container.get_child(0)

func switch_scene(scene_name: String, transition_type: String):
	call_deferred("_deferred_switch_scene", scene_name, transition_type)

func switch_to_preloaded_scene(preloaded_scene: PackedScene, scene_name: String, transition_type: String):
	call_deferred("_deferred_switch_to_preloaded", preloaded_scene, scene_name, transition_type)

func switch_to_scene_instance(scene_instance: Node, scene_name: String, transition_type: String):
	call_deferred("_deferred_switch_to_instance", scene_instance, scene_name, transition_type)

func _deferred_switch_scene(scene_name: String, transition_type: String):
	# Use GUIManager for fade out transition
	await GuiManager.transition_out(transition_type)
	
	current_scene.queue_free()
	
	var direct_path = "res://scenes/%s.tscn" % scene_name
	var new_scene
	if ResourceLoader.exists(direct_path):
		new_scene = load(direct_path)
	else:
		var search_name = scene_name.get_file()
		var scene_path = _find_scene_path("res://scenes", search_name)
		if scene_path == "":
			push_error("Scene not found: " + scene_name)
			return
		new_scene = load(scene_path)
		
	current_scene = new_scene.instantiate()
	scene_container.add_child(current_scene)  # Add to the fixed container
	
	# Use GUIManager for fade in transition
	await GuiManager.transition_in(transition_type)
	
	# Emit signal that transition is complete
	scene_transition_finished.emit(scene_name)

func _deferred_switch_to_preloaded(preloaded_scene: PackedScene, scene_name: String, transition_type: String):
	# Use GUIManager for fade out transition
	await GuiManager.transition_out(transition_type)
	
	current_scene.queue_free()
	
	current_scene = preloaded_scene.instantiate()
	scene_container.add_child(current_scene)
	
	# Use GUIManager for fade in transition
	await GuiManager.transition_in(transition_type)
	
	# Emit signal that transition is complete
	scene_transition_finished.emit(scene_name)

func _deferred_switch_to_instance(scene_instance: Node, scene_name: String, transition_type: String):
	# Use GUIManager for fade out transition
	await GuiManager.transition_out(transition_type)
	
	current_scene.queue_free()
	
	current_scene = scene_instance
	scene_container.add_child(current_scene)
	
	# Use GUIManager for fade in transition
	await GuiManager.transition_in(transition_type)
	
	# Emit signal that transition is complete
	scene_transition_finished.emit(scene_name)

func _find_scene_path(path: String, scene_name: String) -> String:
	var target_file = scene_name + ".tscn"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					var found_path = _find_scene_path(path + "/" + file_name, scene_name)
					if found_path != "":
						return found_path
			else:
				if file_name.trim_suffix(".remap") == target_file:
					return path + "/" + target_file
			file_name = dir.get_next()
	return ""
