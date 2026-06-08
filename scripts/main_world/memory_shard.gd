extends Node2D

@export var memory_resource: MemoryData # 直接拖入對應的 .tres

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D # Corrected node reference

var _collected := false # Guard against duplicate collection before queue_free()

func _ready() -> void:
	# Remove this shard if its memory ID is not registered in the current mode.
	# This handles mismatches between scene placements and the active memory_order.
	if not memory_resource:
		push_warning("[MemoryShard] No memory_resource assigned — removing shard.")
		queue_free()
		return
	var known_ids: Array = ProgressManager.active_memories.map(func(m): return m.id)
	if memory_resource.id not in known_ids:
		push_warning("[MemoryShard] Memory ID '%s' not found in active_memories — removing shard." % memory_resource.id)
		queue_free()

func _on_area_2d_body_entered(_body: Node2D) -> void:
	if _collected: return
	_collected = true
	
	ProgressManager.collect_memory(memory_resource.id)
	
	if memory_resource.cutscene_id != "":
		CutsceneManager.play(memory_resource.cutscene_id)
	queue_free()
