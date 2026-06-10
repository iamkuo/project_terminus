extends Node2D

@export var memory_resource: MemoryData # 直接拖入對應的 .tres

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

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
		return
		
	# If this memory is already collected, remove the shard immediately
	if memory_resource.id in ProgressManager.unlocked_memory_ids:
		queue_free()

func _on_area_2d_body_entered(_body: Node2D) -> void:
	if _collected: return
	_collected = true
	# Notify ProgressManager that this memory was collected.
	# It handles all downstream logic (adding to unlocked list, signals, cutscene).
	ProgressManager.collect_memory(memory_resource.id)
	queue_free()
