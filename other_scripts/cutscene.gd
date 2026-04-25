extends Node2D

@export var script_id : String

func _on_area_2d_body_entered(_body: Node2D) -> void:
	CutsceneManager.play(script_id)
