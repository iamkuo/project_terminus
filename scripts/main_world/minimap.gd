extends TextureRect

## World Minimap Widget (Static Image & Memory Unlock)
## Displays the active level map directly on this TextureRect, checking for memory unlocks.

@export_group("Map Textures")
@export var goblin_map_texture: Texture2D
@export var human_map_texture: Texture2D
@export var locked_map_texture: Texture2D

@export_group("Cutscene Lock Config")
@export var goblin_cutscene_id: String = ""
@export var human_cutscene_id: String = ""

func _ready() -> void:
	if CutsceneManager.has_signal("cutscene_finished"):
		CutsceneManager.cutscene_finished.connect(_on_cutscene_finished)
	_update_current_map()

func _process(_delta: float) -> void:
	_update_current_map()

func _on_cutscene_finished(_cutscene_id: String) -> void:
	_update_current_map()

func _update_current_map() -> void:
	var path := _get_current_map_path()
	var is_human := path.contains("human")
	
	var target_tex = human_map_texture if is_human else goblin_map_texture
	var cutscene_id = human_cutscene_id if is_human else goblin_cutscene_id

	# Watch for cutscene unlock condition
	if not cutscene_id.is_empty():
		if not CutsceneManager.played_cutscenes.has(cutscene_id):
			target_tex = locked_map_texture

	if texture != target_tex:
		texture = target_tex

func _get_current_map_path() -> String:
	var root := SceneSwitcher.current_scene
	if root:
		var container = root.get_node_or_null("MapContainer")
		if container and container.get_child_count() > 0:
			var current_map = container.get_child(0)
			if current_map:
				return current_map.scene_file_path
	return ""
