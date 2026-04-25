extends Resource
class_name StageData

@export var id: String # Unique identifier for the stage
@export var name: String # Display name of the stage
@export var req_exp: int # Required experience to reach this stage
@export var cutscene_id: String # ID of the cutscene to play upon reaching this stage
@export var unlocks_memory_id: String # ID of the memory shard to unlock (empty if none)
