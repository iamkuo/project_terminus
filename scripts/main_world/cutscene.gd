extends Node2D

## World story-event trigger area.
## When the player walks in, this node announces the event to ProgressManager,
## which decides what to do (e.g. play an associated cutscene).
@export var script_id: String

func _on_area_2d_body_entered(_body: Node2D) -> void:
	ProgressManager.trigger_story_event(script_id)
	queue_free()
