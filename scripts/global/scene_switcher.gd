extends Node

var current_scene : Node = null
@onready var scene_container = get_node("/root/Game/SceneContainer")
@onready var animation_player = get_node("/root/Game/GUI/FullscreenUI/AnimationPlayer")
@onready var transition_rect = get_node("/root/Game/GUI/FullscreenUI/TransitionColorRect") 
@onready var fullscreen_ui = get_node("/root/Game/GUI/FullscreenUI")

signal scene_transition_finished(scene_name: String)
signal scene_added(scene_name: String)

const PRELOAD_SCENES: Dictionary = {
	"main_menu": "res://scenes/start_menu/main_menu.tscn",
	"main_world": "res://scenes/main_world/main_world.tscn",
	"battle_scene": "res://scenes/battle/battle_scene.tscn",
	"main_world_goblin_map": "res://scenes/main_world/main_world_goblin_map.scn",
	"main_world_human_map": "res://scenes/main_world/main_world_human_map.scn",
	"boss": "res://scenes/main_world/boss.scn",
	"final_boss": "res://scenes/main_world/final_boss.scn"
}

var preloaded_scenes: Dictionary = {}
var scene_path_cache: Dictionary = {}

func _ready() -> void: 
	# 1. Index all scenes recursively at startup so we know where every file lives
	_index_scenes_recursive("res://scenes")
	
	# 2. Preload all configured scenes to eliminate loading lag during gameplay
	for s_name in PRELOAD_SCENES:
		var path = PRELOAD_SCENES[s_name]
		if ResourceLoader.exists(path):
			var loaded_scene = load(path)
			preloaded_scenes[s_name] = loaded_scene
			preloaded_scenes[path] = loaded_scene
		else:
			push_error("SceneSwitcher: Preload path does not exist: " + path)

	await get_tree().process_frame
	if scene_container.get_child_count() > 0:
		current_scene = scene_container.get_child(0)

func _index_scenes_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_index_scenes_recursive(path + "/" + file_name)
			else:
				var clean_name = file_name.trim_suffix(".remap")
				if clean_name.ends_with(".tscn") or clean_name.ends_with(".scn"):
					var scene_name = clean_name.get_basename()
					scene_path_cache[scene_name] = path + "/" + clean_name
			file_name = dir.get_next()

func get_preloaded_scene(path_or_name: String) -> PackedScene:
	if preloaded_scenes.has(path_or_name):
		return preloaded_scenes[path_or_name]
	
	# Fallback load on-demand using the indexed path cache for nested subfolders
	var path = path_or_name
	if not ResourceLoader.exists(path):
		var base_name = path_or_name.get_file().get_basename()
		path = scene_path_cache.get(base_name, "")
		
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path)
			
	push_error("SceneSwitcher: Scene not found in cache or disk: " + path_or_name)
	return null

func switch_scene(scene_name: String, transition_type: String, setup_callback: Callable = Callable()):
	call_deferred("_deferred_switch_scene", scene_name, transition_type, setup_callback)

func switch_to_scene_instance(scene_instance: Node, scene_name: String, transition_type: String, setup_callback: Callable = Callable()):
	call_deferred("_deferred_switch_to_instance", scene_instance, scene_name, transition_type, setup_callback)

func _deferred_switch_scene(scene_name: String, transition_type: String, setup_callback: Callable):
	await GuiManager.transition_out(transition_type)
	
	# Execute heavy setup logic while the screen is black
	if setup_callback.is_valid():
		setup_callback.call()
	
	current_scene.queue_free()
	
	var new_scene = get_preloaded_scene(scene_name)
	if new_scene:
		current_scene = new_scene.instantiate()
		scene_container.add_child(current_scene)
		scene_added.emit(scene_name)
	
	await GuiManager.transition_in(transition_type)
	scene_transition_finished.emit(scene_name)

func _deferred_switch_to_instance(scene_instance: Node, scene_name: String, transition_type: String, setup_callback: Callable):
	await GuiManager.transition_out(transition_type)
	
	# Execute heavy setup logic while the screen is black
	if setup_callback.is_valid():
		setup_callback.call()
	
	current_scene.queue_free()
	
	current_scene = scene_instance
	scene_container.add_child(current_scene)
	scene_added.emit(scene_name)
	
	await GuiManager.transition_in(transition_type)
	scene_transition_finished.emit(scene_name)
