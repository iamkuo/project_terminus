extends TextureRect

## World Minimap Widget (Static Image & Memory Unlock)
## Displays the active level map directly on this TextureRect, checking for memory unlocks.

@export_group("Map Textures")
@export var goblin_map_texture: Texture2D
@export var human_map_texture: Texture2D
@export var locked_map_texture: Texture2D

@export_group("Memory Lock Config")
@export var goblin_memory_id: String = ""
@export var human_memory_id: String = ""

@export_group("Map World Bounds")
# Kept for inspector compatibility
@export var goblin_world_rect: Rect2 = Rect2(-3000, 0, 6000, 5000)
@export var human_world_rect: Rect2 = Rect2(-3000, 0, 6000, 5000)

func _ready() -> void:
	_update_current_map()

func _process(_delta: float) -> void:
	_update_current_map()

func _update_current_map() -> void:
	var path := _get_current_map_path()
	var is_human := path.contains("human")
	
	var target_tex = human_map_texture if is_human else goblin_map_texture
	var memory_id = human_memory_id if is_human else goblin_memory_id

	# Watch for memory unlock condition
	if _memory_exists(memory_id):
		if not ProgressManager.unlocked_memory_ids.has(memory_id):
			target_tex = locked_map_texture

	if texture != target_tex:
		texture = target_tex

func _memory_exists(mem_id: String) -> bool:
	if mem_id.is_empty():
		return false
	for mem in ProgressManager.active_memories:
		if mem.id == mem_id:
			return true
	return false

func _get_current_map_path() -> String:
	var root := SceneSwitcher.current_scene
	if root:
		var container = root.get_node_or_null("MapContainer")
		if container and container.get_child_count() > 0:
			var current_map = container.get_child(0)
			if current_map:
				return current_map.scene_file_path
	return ""
