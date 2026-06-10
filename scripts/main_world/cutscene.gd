extends Node2D

## World story-event trigger area.
## When the player walks in, this node announces the event to ProgressManager,
## which decides what to do (e.g. play an associated cutscene).
@export var script_id: String

func _ready() -> void:
	if not script_id or script_id.is_empty():
		push_warning("[CutsceneTrigger] No script_id assigned — removing trigger.")
		queue_free()
		return
		
	# Check if the cutscene ID is registered in the active cutscenes for the current mode
	if script_id not in ProgressManager.active_cutscenes:
		push_warning("[CutsceneTrigger] Cutscene ID '%s' not found in active_cutscenes — removing trigger." % script_id)
		queue_free()
		return
		
	# If this cutscene has already been played, remove the trigger immediately
	if CutsceneManager.played_cutscenes.has(script_id):
		queue_free()

func _on_area_2d_body_entered(_body: Node2D) -> void:
	ProgressManager.trigger_story_event(script_id)
	queue_free()
