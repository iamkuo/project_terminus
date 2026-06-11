extends TextureRect

## World Minimap Widget (Static Image & Cutscene Unlock)
## Displays the map for the active sub-map, gated by cutscene playback.

@export_group("Map Textures")
@export var goblin_map_texture: Texture2D
@export var human_map_texture: Texture2D
@export var locked_map_texture: Texture2D

@export_group("Cutscene Lock Config")
@export var goblin_cutscene_id: String = ""
@export var human_cutscene_id: String = ""

func _ready() -> void:
	if not CutsceneManager.cutscene_finished.is_connected(_on_cutscene_finished):
		CutsceneManager.cutscene_finished.connect(_on_cutscene_finished)
	_connect_map_manager()
	_update_current_map()

func _connect_map_manager() -> void:
	var root := SceneSwitcher.current_scene
	if root and root.has_signal("map_changed"):
		if not root.map_changed.is_connected(_on_world_map_changed):
			root.map_changed.connect(_on_world_map_changed)
	if not SceneSwitcher.scene_added.is_connected(_on_scene_added):
		SceneSwitcher.scene_added.connect(_on_scene_added)

func _on_scene_added(_scene_name: String) -> void:
	call_deferred("_connect_map_manager")
	call_deferred("_update_current_map")

func _on_world_map_changed(_map_path: String) -> void:
	_update_current_map()

func _on_cutscene_finished(_cutscene_id: String) -> void:
	_update_current_map()

func _update_current_map() -> void:
	var path := _get_current_map_path()
	var is_human_map := path.contains("human")
	var target_tex := human_map_texture if is_human_map else goblin_map_texture
	var unlock_cutscene_id := human_cutscene_id if is_human_map else goblin_cutscene_id

	if not unlock_cutscene_id.is_empty():
		if not CutsceneManager.played_cutscenes.has(unlock_cutscene_id):
			target_tex = locked_map_texture

	if texture != target_tex:
		texture = target_tex

func _get_current_map_path() -> String:
	var root := SceneSwitcher.current_scene
	if root and root.has_method("get_current_map_path"):
		var tracked_path: String = root.get_current_map_path()
		if not tracked_path.is_empty():
			return tracked_path

	if root:
		var container = root.get_node_or_null("MapContainer")
		if container and container.get_child_count() > 0:
			var current_map = container.get_child(0)
			if current_map and not current_map.scene_file_path.is_empty():
				return current_map.scene_file_path
	return ""
