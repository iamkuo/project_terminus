extends Resource
class_name TransitionConfig

@export var zone_marker: String
@export_file("*.tscn") var target_scene: String
@export var spawn_marker: String
@export var required_level: int = 1
@export var lock_cutscene_id: String = "level_lock_cutscene"
