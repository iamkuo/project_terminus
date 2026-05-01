extends Node2D

@export var memory_resource: MemoryData # 直接拖入對應的 .tres

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D # Corrected node reference

func _on_area_2d_body_entered(body: Node2D) -> void:
	print("touched a shard: ", memory_resource.id)
	ProgressManager.collect_memory(memory_resource.id)
	
	if memory_resource.cutscene_id != "":
		CutsceneManager.play(memory_resource.cutscene_id)
		
	# Optionally play a collection animation here before queue_free() if one exists.
	# Example: animated_sprite.play("collected")
	# await animated_sprite.animation_finished # if playing animation
	queue_free()
